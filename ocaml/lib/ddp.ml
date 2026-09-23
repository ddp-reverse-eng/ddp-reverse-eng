(** DDP 2.00 audio CD fileset writer, see spec/ddp2.md. *)

module Cue = Cue
module Cdtext = Cdtext
module Audio = Audio

exception Error = Diag.Error

let error = Diag.error
let sector_size = Cd.sector_size
let frames_per_second = Cd.frames_per_second
let default_pregap = 2 * frames_per_second

type pq = {
  track : string;
  index : int;
  time : int;
  control : string;
  isrc : string;
  upc : string;
}
(** A PQ entry, times in frames from the start of IMAGE.DAT. *)

type layout = {
  pregap : int;  (** silent sectors prepended to the audio *)
  first_track_start : int;  (** track 1 INDEX 01, in sectors *)
  sectors : int;
  tracks : (Cue.track * (int * int) list) list;
      (** each track's (index, time) pairs, times in frames from the start of
          IMAGE.DAT *)
  pq : pq list;
}

let control (flags : Cue.flags) =
  let nibble =
    (if flags.pre then 1 else 0)
    lor (if flags.dcp then 2 else 0)
    lor if flags.four_channel then 8 else 0
  in
  Printf.sprintf "%X%c" nibble (if flags.scms then 'S' else '1')

(** Tracks with index times in frames from the start of IMAGE.DAT, track 1
    always starting with index 00; [starts] holds each file's first frame. *)
let absolute_indexes ~pregap ~starts (tracks : Cue.track list) =
  List.map
    (fun (t : Cue.track) ->
      let indexes =
        List.map
          (fun (i, (p : Cue.position)) ->
            (i, pregap + starts.(p.file) + p.time))
          t.indexes
      in
      let indexes =
        if t.number = 1 && pregap > 0 then (0, 0) :: indexes else indexes
      in
      (t, indexes))
    tracks

(** A wrong check digit only warns, as cue2ddp does. *)
let check_ean ~warn code =
  if
    String.length code <> 13
    || not (String.for_all (fun c -> c >= '0' && c <= '9') code)
  then error "UPC/EAN must be 13 digits: '%s'" code;
  let digit i = Char.code code.[i] - Char.code '0' in
  let sum =
    List.init 12 (fun i -> digit i * if i mod 2 = 0 then 1 else 3)
    |> List.fold_left ( + ) 0
  in
  if (10 - (sum mod 10)) mod 10 <> digit 12 then
    warn ("UPC/EAN check digit is wrong: " ^ code)

let validate_track ~next_start ((t : Cue.track), indexes) =
  if t.flags.dcp && t.flags.scms then
    error "track %02d: DCP and SCMS are mutually exclusive" t.number;
  Option.iter
    (fun isrc ->
      if
        String.length isrc <> 12
        || not
             (String.for_all
                (fun c -> (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z'))
                isrc)
      then error "track %02d: invalid ISRC '%s'" t.number isrc)
    t.isrc;
  let rec ascending = function
    | (i, f) :: ((i', f') :: _ as rest) ->
        i' = i + 1 && f' > f && ascending rest
    | _ -> true
  in
  if not (ascending indexes) then
    error "track %02d: indexes must be consecutive and increasing" t.number;
  let start = List.assoc 1 indexes in
  if next_start - start < 4 * frames_per_second then
    error "track %02d is shorter than 4 seconds" t.number;
  if t.number = 1 && start < default_pregap then
    error "first track's pregap is shorter than 2 seconds"

(** Each file's length in sectors. Only the last may end mid-sector: joining at
    any other point would shift every later index off the frame grid. *)
let file_sectors (files : (Cue.file * Audio.t) list) =
  let count = List.length files in
  List.mapi
    (fun n ((file : Cue.file), audio) ->
      let length = Audio.output_length audio in
      if n < count - 1 && length mod sector_size <> 0 then
        error "%s does not end on a CD frame boundary (a multiple of %d bytes)"
          file.path sector_size;
      (length + sector_size - 1) / sector_size)
    files
  |> Array.of_list

let layout ~warn (cue : Cue.t) files =
  Option.iter (check_ean ~warn) cue.catalog;
  List.iter
    (fun (t : Cue.track) ->
      if not (List.mem_assoc 1 t.indexes) then
        error "track %02d: INDEX 01 is required" t.number)
    cue.tracks;
  let first = List.hd cue.tracks in
  let pregap =
    match snd (List.hd first.indexes) with
    | { file = 0; time = 0 } ->
        if List.mem_assoc 0 first.indexes then 0 else default_pregap
    | _ ->
        error "first index in first track must be at 00:00:00 of the first FILE"
  in
  let lengths = file_sectors files in
  List.iter
    (fun (t : Cue.track) ->
      List.iter
        (fun (i, (p : Cue.position)) ->
          if p.time >= lengths.(p.file) then
            error "track %02d: INDEX %02d is past the end of %s" t.number i
              (fst (List.nth files p.file)).path)
        t.indexes)
    cue.tracks;
  let starts = Array.make (Array.length lengths) 0 in
  for n = 1 to Array.length lengths - 1 do
    starts.(n) <- starts.(n - 1) + lengths.(n - 1)
  done;
  let sectors = pregap + Array.fold_left ( + ) 0 lengths in
  if sectors > Cd.max_frames + 1 then
    error "disc is %s long, longer than the 99:59:74 CD addresses can reach"
      (Cd.format_msf ~separator:":" sectors);
  let tracks = absolute_indexes ~pregap ~starts cue.tracks in
  (* A track's minimum length runs from its INDEX 01 to the next track's INDEX 01. *)
  let starts =
    List.map (fun (_, indexes) -> List.assoc 1 indexes) (List.tl tracks)
    @ [ sectors ]
  in
  List.iter2
    (fun track next_start -> validate_track ~next_start track)
    tracks starts;
  let upc = Option.value cue.catalog ~default:"" in
  let entry ?(control = "01") ?(isrc = "") ?(upc = "") track index time =
    { track; index; time; control; isrc; upc }
  in
  let track_entries ((t : Cue.track), indexes) =
    List.mapi
      (fun n (index, time) ->
        let isrc = if n = 0 then Option.value t.isrc ~default:"" else "" in
        entry ~control:(control t.flags) ~isrc
          (Printf.sprintf "%02d" t.number)
          index time)
      indexes
  in
  let lead_out = entry "AA" 1 sectors in
  let pq =
    (entry ~upc "00" 0 0 :: List.concat_map track_entries tracks)
    @ [ lead_out; lead_out ]
  in
  let first_track_start = List.assoc 1 (snd (List.hd tracks)) in
  { pregap; first_track_start; sectors; tracks; pq }

let record size values =
  try Record.make size values
  with Record.Overflow (value, width) ->
    error "value '%s' does not fit in %d bytes" value width

let sd_packet pq =
  let module F = Record.Pq in
  record F.size
    [
      (F.version, "VVVS");
      (F.track, pq.track);
      (F.index, Printf.sprintf "%02d" pq.index);
      (F.time, Cd.format_msf pq.time);
      (F.control, pq.control);
      (F.isrc, pq.isrc);
      (F.upc, pq.upc);
    ]

let map_packet ~stream_type ~length ?(subcode = "") ?(track = "") ?(data = [])
    name =
  let module F = Record.Map in
  record F.size
    ([
       (F.version, "VVVM");
       (F.stream_type, stream_type);
       (F.length, string_of_int length);
       (F.subcode, subcode);
       (F.track, track);
     ]
    @ data
    @ [ (F.name_size, string_of_int F.name.width); (F.name, name) ])

let ddpid ~upc ~master_id =
  let module F = Record.Ddpid in
  record F.size
    [
      (F.level, "DDP 2.00");
      (F.upc, upc);
      (F.master_id, master_id);
      (F.disc_type, "CD");
    ]

let write_file path contents =
  Out_channel.with_open_bin path (fun oc ->
      Out_channel.output_string oc contents)

let write_image ~dir ~pregap audios =
  Out_channel.with_open_bin (Filename.concat dir "IMAGE.DAT") (fun oc ->
      Out_channel.output_string oc (String.make (pregap * sector_size) '\000');
      List.iter
        (fun audio ->
          Audio.iter_pcm16 audio (fun buffer length ->
              Out_channel.output oc buffer 0 length))
        audios;
      let tail =
        List.fold_left (fun n a -> n + Audio.output_length a) 0 audios
        mod sector_size
      in
      if tail > 0 then
        Out_channel.output_string oc (String.make (sector_size - tail) '\000'))

let crc32_table =
  Array.init 256 (fun n ->
      let c = ref n in
      for _ = 1 to 8 do
        c := if !c land 1 <> 0 then 0xEDB88320 lxor (!c lsr 1) else !c lsr 1
      done;
      !c)

let crc32_file path =
  In_channel.with_open_bin path (fun ic ->
      let buffer = Bytes.create 65536 in
      let rec loop crc =
        match In_channel.input ic buffer 0 (Bytes.length buffer) with
        | 0 -> crc lxor 0xFFFFFFFF
        | n ->
            let crc = ref crc in
            for i = 0 to n - 1 do
              crc :=
                crc32_table.(!crc lxor Bytes.get_uint8 buffer i land 0xFF)
                lxor (!crc lsr 8)
            done;
            loop !crc
      in
      loop 0xFFFFFFFF)

let write_checksums ~dir names =
  let path name = Filename.concat dir name in
  write_file (path "CHECKSUM.MD5")
    (String.concat ""
       (List.map
          (fun n ->
            Printf.sprintf "%s *%s\n" (Digest.to_hex (Digest.file (path n))) n)
          names));
  write_file (path "CHECKSUM.TXT")
    (String.concat ""
       ("[CRC32 Checksum]\n"
       :: List.map
            (fun n -> Printf.sprintf "%s=%08X\n" n (crc32_file (path n)))
            names))

let text_lines indent (t : Cue.text) =
  List.filter_map
    (fun (command, value) ->
      Option.map
        (fun v -> Printf.sprintf "%s%s \"%s\"\n" indent command v)
        value)
    [
      ("TITLE", t.title);
      ("PERFORMER", t.performer);
      ("SONGWRITER", t.songwriter);
      ("COMPOSER", t.composer);
      ("ARRANGER", t.arranger);
      ("MESSAGE", t.message);
    ]

(** CDRWin cue sheet for IMAGE.DAT, with absolute index times. *)
let image_cue (cue : Cue.t) (layout : layout) =
  let flags (f : Cue.flags) =
    List.filter_map
      (fun (set, name) -> if set then Some name else None)
      [
        (f.pre, "PRE"); (f.dcp, "DCP"); (f.four_channel, "4CH"); (f.scms, "SCMS");
      ]
  in
  let track ((t : Cue.track), indexes) =
    [ Printf.sprintf "  TRACK %02d AUDIO\n" t.number ]
    @ text_lines "    " t.text
    @ Option.to_list (Option.map (Printf.sprintf "    ISRC %s\n") t.isrc)
    @ (match flags t.flags with
      | [] -> []
      | names -> [ Printf.sprintf "    FLAGS %s\n" (String.concat " " names) ])
    @ List.map
        (fun (i, f) ->
          Printf.sprintf "    INDEX %02d %s\n" i
            (Cd.format_msf ~separator:":" f))
        indexes
  in
  String.concat ""
    (Option.to_list (Option.map (Printf.sprintf "CATALOG %s\n") cue.catalog)
    @ text_lines "" cue.text
    @ [ "FILE \"IMAGE.DAT\" BINARY\n" ]
    @ List.concat_map track layout.tracks)

(** Writes the fileset for [cue_path] into [dir]. *)
let write ?(warn = fun msg -> prerr_endline ("warning: " ^ msg))
    ?(master_id = "") ?(with_cdtext = false) ?(with_cue = false) ~cue_path ~dir
    () =
  let cue = Cue.parse ~warn cue_path in
  let files =
    List.map
      (fun (f : Cue.file) -> (f, Audio.of_file ~warn f.file_type f.path))
      cue.files
  in
  let layout = layout ~warn cue files in
  let cdtext =
    if not with_cdtext then ""
    else
      match cue.cdtext_file with
      | Some file -> Cdtext.of_file ~warn file
      | None -> Cdtext.encode ~disc:cue.text ~tracks:cue.tracks
  in
  let path name = Filename.concat dir name in
  let sd = String.concat "" (List.map sd_packet layout.pq) in
  let cdtext_packet =
    if cdtext = "" then []
    else
      [
        map_packet ~stream_type:"S0" ~length:(String.length cdtext)
          ~subcode:"CDTEXT" ~track:"00" "CDTEXT.BIN";
      ]
  in
  let map =
    cdtext_packet
    @ [
        map_packet ~stream_type:"S0" ~length:(String.length sd)
          ~subcode:"PQ DESCR" "SD";
        map_packet ~stream_type:"D0" ~length:layout.sectors
          ~data:
            Record.Map.
              [
                (cd_mode, "DA");
                (storage_mode, "7");
                (scrambled, "1");
                (pregap2, string_of_int layout.first_track_start);
              ]
          "IMAGE.DAT";
      ]
  in
  if not (Sys.file_exists dir) then Sys.mkdir dir 0o755;
  write_image ~dir ~pregap:layout.pregap (List.map snd files);
  if cdtext <> "" then write_file (path "CDTEXT.BIN") cdtext;
  write_file (path "SD") sd;
  write_file (path "DDPMS") (String.concat "" map);
  write_file (path "DDPID")
    (ddpid ~upc:(Option.value cue.catalog ~default:"") ~master_id);
  if with_cue then write_file (path "IMAGE.cue") (image_cue cue layout);
  write_checksums ~dir
    ([ "DDPID"; "DDPMS" ]
    @ (if cdtext = "" then [] else [ "CDTEXT.BIN" ])
    @ [ "SD"; "IMAGE.DAT" ])
