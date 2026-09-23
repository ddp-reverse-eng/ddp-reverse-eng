let error = Diag.error

type encoding = { float : bool; bits : int; channels : int; big_endian : bool }
type t = { path : string; offset : int; length : int; encoding : encoding }

let pcm16_stereo =
  { float = false; bits = 16; channels = 2; big_endian = false }

let frame_bytes e = e.channels * e.bits / 8
let output_length t = t.length / frame_bytes t.encoding * 4

let check_frames t =
  if t.length mod frame_bytes t.encoding <> 0 then
    error "%s: audio stops in the middle of a sample frame" t.path

let raw ~big_endian path =
  let length =
    In_channel.with_open_bin path (fun ic ->
        Int64.to_int (In_channel.length ic))
  in
  let t =
    { path; offset = 0; length; encoding = { pcm16_stereo with big_endian } }
  in
  check_frames t;
  t

(** The GUID tail shared by every KSDATAFORMAT_SUBTYPE in extensible WAVE. *)
let subformat_suffix =
  "\x00\x00\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71"

let parse_fmt path fmt =
  if String.length fmt < 16 then error "%s: fmt chunk too short" path;
  let tag = String.get_uint16_le fmt 0 in
  let tag =
    if tag = 0xFFFE && String.length fmt >= 40 then (
      if String.sub fmt 26 14 <> subformat_suffix then
        error "%s: unknown extensible WAVE subformat" path;
      String.get_uint16_le fmt 24)
    else tag
  in
  let channels = String.get_uint16_le fmt 2 in
  let rate = Int32.to_int (String.get_int32_le fmt 4) in
  let block_align = String.get_uint16_le fmt 12 in
  let bits = String.get_uint16_le fmt 14 in
  let float =
    match (tag, bits) with
    | 1, (8 | 16 | 24 | 32) -> false
    | 3, (32 | 64) -> true
    | 1, _ | 3, _ -> error "%s: unsupported sample size (%d bits)" path bits
    | _ -> error "%s: not PCM or float audio (format 0x%04X)" path tag
  in
  if rate <> 44100 then
    error "%s: sample rate is %d Hz, only 44100 Hz is supported" path rate;
  if channels <> 1 && channels <> 2 then
    error "%s: %d channels, only mono and stereo are supported" path channels;
  let encoding = { float; bits; channels; big_endian = false } in
  if block_align <> frame_bytes encoding then
    error "%s: inconsistent block alignment" path;
  encoding

(** Chunks are read within the RIFF size, so a truncated header finds nothing
    rather than garbage. *)
let wave ~warn path =
  In_channel.with_open_bin path (fun ic ->
      let file_length = Int64.to_int (In_channel.length ic) in
      let read n =
        match In_channel.really_input_string ic n with
        | Some s -> s
        | None -> error "%s: truncated WAVE file" path
      in
      let u32 s = Int32.to_int (String.get_int32_le s 0) land 0xFFFFFFFF in
      let header = read 12 in
      if String.sub header 0 4 <> "RIFF" || String.sub header 8 4 <> "WAVE" then
        error "%s: not a WAVE file" path;
      let limit = min file_length (8 + u32 (String.sub header 4 4)) in
      let rec chunks position ~fmt ~data =
        if position + 8 > limit then (fmt, data)
        else (
          In_channel.seek ic (Int64.of_int position);
          let header = read 8 in
          let size = u32 (String.sub header 4 4) in
          let body = position + 8 in
          let next = body + size + (size land 1) in
          match String.sub header 0 4 with
          | "fmt " when fmt = None ->
              chunks next ~fmt:(Some (read (min size 64))) ~data
          | "data" when data = None ->
              if body + size > file_length then
                error "%s: data chunk runs past the end of the file" path;
              chunks next ~fmt ~data:(Some (body, size))
          | _ -> chunks next ~fmt ~data)
      in
      match chunks 12 ~fmt:None ~data:None with
      | None, _ -> error "%s: no fmt chunk" path
      | _, None -> error "%s: no data chunk" path
      | Some fmt, Some (offset, length) ->
          let encoding = parse_fmt path fmt in
          let t = { path; offset; length; encoding } in
          check_frames t;
          if encoding.channels = 1 then
            warn (path ^ " is mono, both channels get the same audio");
          t)

(** Decodes one sample to a signed 16-bit value, [None] when it does not fit
    exactly. *)
let sample_decoder e =
  let exact v shift =
    if v land ((1 lsl shift) - 1) = 0 then Some (v asr shift) else None
  in
  let exact_float f =
    let v = f *. 32768. in
    if Float.is_integer v && v >= -32768. && v <= 32767. then
      Some (int_of_float v)
    else None
  in
  match (e.float, e.bits) with
  | false, 8 -> fun b o -> Some ((Bytes.get_uint8 b o - 128) lsl 8)
  | false, 16 when e.big_endian -> fun b o -> Some (Bytes.get_int16_be b o)
  | false, 16 -> fun b o -> Some (Bytes.get_int16_le b o)
  | false, 24 ->
      fun b o ->
        let v = Bytes.get_uint8 b o lor (Bytes.get_int16_le b (o + 1) lsl 8) in
        exact v 8
  | false, _ -> fun b o -> exact (Int32.to_int (Bytes.get_int32_le b o)) 16
  | true, 32 ->
      fun b o -> exact_float (Int32.float_of_bits (Bytes.get_int32_le b o))
  | true, _ ->
      fun b o -> exact_float (Int64.float_of_bits (Bytes.get_int64_le b o))

(** Streams the audio as 16-bit little-endian stereo. *)
let iter_pcm16 t output =
  let e = t.encoding in
  let frame = frame_bytes e and sample = e.bits / 8 in
  let frames_per_block = 16384 in
  let input = Bytes.create (frames_per_block * frame) in
  let converted = Bytes.create (frames_per_block * 4) in
  let decode = sample_decoder e in
  In_channel.with_open_bin t.path (fun ic ->
      In_channel.seek ic (Int64.of_int t.offset);
      let rec loop first_frame remaining =
        if remaining > 0 then (
          let count = min frames_per_block remaining in
          (match In_channel.really_input ic input 0 (count * frame) with
          | Some () -> ()
          | None -> error "%s: audio data is truncated" t.path);
          for i = 0 to count - 1 do
            for channel = 0 to 1 do
              let source = min channel (e.channels - 1) in
              match decode input ((i * frame) + (source * sample)) with
              | Some v ->
                  Bytes.set_int16_le converted ((i * 4) + (channel * 2)) v
              | None ->
                  error
                    "%s: sample %d of channel %d is not exactly 16-bit; \
                     convert the file to 16-bit first"
                    t.path (first_frame + i) (source + 1)
            done
          done;
          output converted (count * 4);
          loop (first_frame + count) (remaining - count))
      in
      loop 0 (t.length / frame))

(** Only float and deeper-than-16-bit samples can fail to convert. *)
let validate t =
  if t.encoding.float || t.encoding.bits > 16 then iter_pcm16 t (fun _ _ -> ())

let of_file ~warn file_type path =
  let t =
    match file_type with
    | `Wave -> wave ~warn path
    | `Binary -> raw ~big_endian:false path
    | `Motorola -> raw ~big_endian:true path
  in
  validate t;
  t
