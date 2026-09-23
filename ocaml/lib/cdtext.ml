(** CD-Text lead-in packs, as used by DDP's CDTEXT.BIN. *)

let pack_size = 18
let payload_size = 12

(** CRC-16/CCITT, polynomial 0x1021, initial value 0, inverted. *)
let crc16 bytes =
  let crc = ref 0 in
  Bytes.iter
    (fun byte ->
      crc := !crc lxor (Char.code byte lsl 8);
      for _ = 1 to 8 do
        crc :=
          if !crc land 0x8000 <> 0 then (!crc lsl 1) lxor 0x1021 else !crc lsl 1;
        crc := !crc land 0xFFFF
      done)
    bytes;
  !crc lxor 0xFFFF

let pack ~kind ~track ~sequence ~char_position payload =
  let data = Bytes.make pack_size '\000' in
  Bytes.set_uint8 data 0 kind;
  Bytes.set_uint8 data 1 track;
  Bytes.set_uint8 data 2 sequence;
  Bytes.set_uint8 data 3 (min 15 char_position);
  Bytes.blit payload 0 data 4 payload_size;
  Bytes.set_uint16_be data 16 (crc16 (Bytes.sub data 0 16));
  Bytes.to_string data

(** Splits NUL-terminated strings into 12-byte payloads. Each payload is tagged
    with the track owning its first byte and that byte's position. *)
let payloads strings =
  let text = Buffer.create 256 in
  let owners = ref [] in
  List.iter
    (fun (track, s) ->
      String.iteri
        (fun position _ -> owners := (track, position) :: !owners)
        (s ^ "\000");
      Buffer.add_string text s;
      Buffer.add_char text '\000')
    strings;
  let owners = Array.of_list (List.rev !owners) in
  let text = Buffer.to_bytes text in
  let length = Bytes.length text in
  List.init
    ((length + payload_size - 1) / payload_size)
    (fun i ->
      let start = i * payload_size in
      let payload = Bytes.make payload_size '\000' in
      Bytes.blit text start payload 0 (min payload_size (length - start));
      (owners.(start), payload))

let text_kinds :
    (int
    * (Cue.text -> string option)
    * (Cue.text -> string option -> Cue.text))
    list =
  [
    (0x80, (fun t -> t.title), fun t v -> { t with title = v });
    (0x81, (fun t -> t.performer), fun t v -> { t with performer = v });
    (0x82, (fun t -> t.songwriter), fun t v -> { t with songwriter = v });
    (0x83, (fun t -> t.composer), fun t v -> { t with composer = v });
    (0x84, (fun t -> t.arranger), fun t v -> { t with arranger = v });
    (0x85, (fun t -> t.message), fun t v -> { t with message = v });
  ]

(** Size information: character set, track range, pack count per kind, last
    sequence number and language of block 0. *)
let size_info ~first_track ~last_track ~counts ~last_sequence =
  let info = Bytes.make (3 * payload_size) '\000' in
  Bytes.set_uint8 info 1 first_track;
  Bytes.set_uint8 info 2 last_track;
  List.iter
    (fun (kind, count) -> Bytes.set_uint8 info (4 + kind - 0x80) count)
    counts;
  Bytes.set_uint8 info 20 last_sequence;
  (* Language code 0x09: English. *)
  Bytes.set_uint8 info 28 0x09;
  List.init 3 (fun i -> Bytes.sub info (i * payload_size) payload_size)

(** A field kind is present when the disc or any track sets it; tracks without
    it then get an empty string. Returns "" when no text is set. *)
let encode ~(disc : Cue.text) ~(tracks : Cue.track list) =
  let groups =
    List.filter_map
      (fun (kind, field, _) ->
        let strings =
          (0, field disc)
          :: List.map (fun (t : Cue.track) -> (t.number, field t.text)) tracks
        in
        if List.for_all (fun (_, s) -> s = None) strings then None
        else
          Some
            ( kind,
              payloads
                (List.map
                   (fun (n, s) -> (n, Option.value s ~default:""))
                   strings) ))
      text_kinds
  in
  if groups = [] then ""
  else
    let counts = List.map (fun (kind, p) -> (kind, List.length p)) groups in
    let text_packs = List.fold_left (fun n (_, c) -> n + c) 0 counts in
    (* Sequence numbers are one byte, so a block holds at most 256 packs. *)
    if text_packs + 3 > 256 then
      Diag.error "CD-Text needs %d packs, at most 256 fit" (text_packs + 3);
    let size_packs =
      size_info ~first_track:1 ~last_track:(List.length tracks)
        ~counts:(counts @ [ (0x8f, 3) ])
        ~last_sequence:(text_packs + 2)
      |> List.mapi (fun i payload -> (0x8f, ((i, 0), payload)))
    in
    let all =
      List.concat_map (fun (kind, p) -> List.map (fun x -> (kind, x)) p) groups
      @ size_packs
    in
    String.concat ""
      (List.mapi
         (fun sequence (kind, ((track, char_position), payload)) ->
           pack ~kind ~track ~sequence ~char_position payload)
         all)

let packs data =
  List.init
    (String.length data / pack_size)
    (fun i -> Bytes.of_string (String.sub data (i * pack_size) pack_size))

let bad_crc_packs data =
  List.filteri
    (fun _ pack -> crc16 (Bytes.sub pack 0 16) <> Bytes.get_uint16_be pack 16)
    (packs data)
  |> List.length

let first_bad_crc data =
  let rec find i = function
    | [] -> None
    | pack :: rest ->
        if crc16 (Bytes.sub pack 0 16) <> Bytes.get_uint16_be pack 16 then
          Some i
        else find (i + 1) rest
  in
  find 0 (packs data)

let of_file ~warn path =
  let data = In_channel.with_open_bin path In_channel.input_all in
  if data = "" || String.length data mod pack_size <> 0 then
    Diag.error "%s: CD-Text file size must be a multiple of %d bytes" path
      pack_size;
  Option.iter
    (fun first ->
      warn
        (Printf.sprintf
           "%s: %d CD-Text pack(s) with a wrong CRC, first is pack %d" path
           (bad_crc_packs data) first))
    (first_bad_crc data);
  data

(** Block 0 text: a TAB string repeats the previous track's string. *)
let decode data =
  let block0 =
    List.filter (fun p -> (Bytes.get_uint8 p 3 lsr 4) land 7 = 0) (packs data)
  in
  let last_track =
    match
      List.filter
        (fun p -> Bytes.get_uint8 p 0 = 0x8f && Bytes.get_uint8 p 1 = 0)
        block0
    with
    | info :: _ -> Bytes.get_uint8 info 6
    | [] -> 0
  in
  let texts = Array.make (last_track + 1) Cue.no_text in
  List.iter
    (fun (kind, _, set) ->
      match List.filter (fun p -> Bytes.get_uint8 p 0 = kind) block0 with
      | [] -> ()
      | first :: _ as kind_packs ->
          let text =
            String.concat ""
              (List.map (fun p -> Bytes.sub_string p 4 payload_size) kind_packs)
          in
          let previous = ref None in
          List.iteri
            (fun n s ->
              let track = Bytes.get_uint8 first 1 + n in
              if track <= last_track then (
                let value =
                  if s = "\t" then !previous
                  else if s = "" then None
                  else Some s
                in
                previous := value;
                texts.(track) <- set texts.(track) value))
            (String.split_on_char '\000' text))
    text_kinds;
  Array.to_list (Array.mapi (fun track text -> (track, text)) texts)
