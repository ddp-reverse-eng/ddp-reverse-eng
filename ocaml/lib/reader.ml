type t = {
  dir : string;
  id_raw : string;
  id : Fileset.id;
  map_raw : string;
  streams : Fileset.stream list;
  pq_raw : string;
  pq : Fileset.pq list;
  cdtext : string option;
}

type severity = Error | Warning | Note

let read path = In_channel.with_open_bin path In_channel.input_all

let subcode_stream streams subcode =
  List.find_opt
    (fun (s : Fileset.stream) -> s.stream_type = "S0" && s.subcode = subcode)
    streams

let audio_streams streams =
  List.filter
    (fun (s : Fileset.stream) -> s.stream_type = "D0" && s.cd_mode = "DA")
    streams

let load dir =
  let path name = Filename.concat dir name in
  List.iter
    (fun name ->
      if not (Sys.file_exists (path name)) then
        Diag.error "%s: no %s file" dir name)
    [ "DDPID"; "DDPMS" ];
  let id_raw = read (path "DDPID") and map_raw = read (path "DDPMS") in
  let streams = Fileset.decode_streams map_raw in
  let stream_file (s : Fileset.stream) =
    if not (Sys.file_exists (path s.name)) then
      Diag.error "%s: DDPMS names %s, which is missing" dir s.name;
    read (path s.name)
  in
  let pq_raw =
    match subcode_stream streams "PQ DESCR" with
    | Some s -> stream_file s
    | None -> Diag.error "%s: DDPMS has no PQ DESCR stream" dir
  in
  {
    dir;
    id_raw;
    id = Fileset.decode_id id_raw;
    map_raw;
    streams;
    pq_raw;
    pq = Fileset.decode_pqs pq_raw;
    cdtext = Option.map stream_file (subcode_stream streams "CDTEXT");
  }

let audio_sectors t =
  List.fold_left
    (fun n (s : Fileset.stream) -> n + s.length)
    0 (audio_streams t.streams)

(** Fields whose raw bytes differ from what the writer would encode for the same
    decoded values: layout choices of another writer, or fields this reader does
    not model. *)
let deviations ~what ~fields ~size ~encode raw =
  List.concat
    (List.init
       (String.length raw / size)
       (fun i ->
         let packet = String.sub raw (i * size) size in
         let ours = encode i in
         List.filter_map
           (fun (name, field) ->
             let theirs = Record.get field packet
             and mine = Record.get field ours in
             if theirs = mine then None
             else
               Some
                 ( Note,
                   Printf.sprintf "%s%s: '%s', this writer uses '%s'" what
                     (if String.length raw > size then
                        Printf.sprintf " packet %d %s" i name
                      else " " ^ name)
                     theirs mine ))
           fields))

let check_files t =
  List.concat_map
    (fun (s : Fileset.stream) ->
      let path = Filename.concat t.dir s.name in
      if not (Sys.file_exists path) then
        [ (Error, Printf.sprintf "%s is missing" s.name) ]
      else
        let size =
          In_channel.with_open_bin path (fun ic ->
              Int64.to_int (In_channel.length ic))
        in
        let expected =
          if s.stream_type = "D0" && s.cd_mode = "DA" then
            s.length * Cd.sector_size
          else s.length
        in
        if s.stream_type = "D0" && s.cd_mode <> "DA" then
          [
            ( Warning,
              Printf.sprintf "%s: data stream mode %s is not audio, ignored"
                s.name s.cd_mode );
          ]
        else if size <> expected then
          [
            ( Error,
              Printf.sprintf "%s is %d bytes, DDPMS says %d" s.name size
                expected );
          ]
        else [])
    t.streams

let check_pq t =
  let issues = ref [] in
  let add severity fmt =
    Printf.ksprintf (fun m -> issues := (severity, m) :: !issues) fmt
  in
  (match t.pq with
  | first :: _ when first.track = "00" && first.index = 0 && first.time = 0 ->
      ()
  | _ -> add Error "PQ: first packet is not the lead-in 00/00 at 00:00:00");
  let rec last = function [ x ] -> Some x | _ :: r -> last r | [] -> None in
  (match last t.pq with
  | Some p when p.track = "AA" ->
      if p.time <> audio_sectors t then
        add Error "PQ: lead-out at %s, audio ends at %s"
          (Cd.format_msf ~separator:":" p.time)
          (Cd.format_msf ~separator:":" (audio_sectors t))
  | _ -> add Error "PQ: last packet is not the lead-out AA");
  let tracks =
    List.filter
      (fun (p : Fileset.pq) -> p.track <> "00" && p.track <> "AA")
      t.pq
  in
  let _ =
    List.fold_left
      (fun (track, index, time) (p : Fileset.pq) ->
        let number = Option.value (int_of_string_opt p.track) ~default:(-1) in
        if p.time < time then
          add Error "PQ: track %s index %02d goes back in time" p.track p.index;
        if number = track then (
          if p.index <> index + 1 then
            add Error "PQ: track %s index %02d out of sequence" p.track p.index)
        else if number <> track + 1 then
          add Error "PQ: track %s out of sequence" p.track
        else if p.index > 1 then
          add Error "PQ: track %s starts at index %02d" p.track p.index;
        (match Fileset.flags_of_control p.control with
        | None ->
            add Error "PQ: track %s control '%s' is not valid" p.track p.control
        | Some f when f.four_channel && f.dcp ->
            add Warning
              "PQ: track %s control '%s' (4CH with DCP) is rejected by ddpinfo"
              p.track p.control
        | Some _ -> ());
        (number, p.index, p.time))
      (0, 0, 0) tracks
  in
  List.iter
    (fun n ->
      if
        not
          (List.exists
             (fun (p : Fileset.pq) ->
               int_of_string_opt p.track = Some n && p.index = 1)
             tracks)
      then add Error "PQ: track %02d has no index 01" n)
    (List.sort_uniq compare
       (List.filter_map
          (fun (p : Fileset.pq) -> int_of_string_opt p.track)
          tracks));
  (match t.pq with
  | first :: _ when first.upc = "" && t.id.upc <> "" ->
      add Warning
        "PQ: lead-in has no UPC while DDPID has one; the pressed disc may lack \
         its MCN"
  | _ -> ());
  List.rev !issues

let check_cdtext t =
  match t.cdtext with
  | None -> []
  | Some data when String.length data mod 18 <> 0 ->
      [ (Error, "CD-Text is not a whole number of 18-byte packs") ]
  | Some data -> (
      match Cdtext.bad_crc_packs data with
      | 0 -> []
      | n ->
          [ (Warning, Printf.sprintf "CD-Text: %d pack(s) with a wrong CRC" n) ]
      )

let check_checksums t =
  List.filter_map
    (fun (algorithm, name, ok) ->
      if ok then None
      else Some (Error, Printf.sprintf "%s of %s does not match" algorithm name))
    (Checksum.verify ~dir:t.dir)

let check t =
  let streams = Array.of_list t.streams and pqs = Array.of_list t.pq in
  check_files t @ check_pq t @ check_cdtext t @ check_checksums t
  @ deviations ~what:"DDPID" ~fields:Record.Ddpid.all ~size:Record.Ddpid.size
      ~encode:(fun _ -> Fileset.encode_id t.id)
      t.id_raw
  @ deviations ~what:"DDPMS" ~fields:Record.Map.all ~size:Record.Map.size
      ~encode:(fun i -> Fileset.encode_stream streams.(i))
      t.map_raw
  @ deviations ~what:"PQ" ~fields:Record.Pq.all ~size:Record.Pq.size
      ~encode:(fun i -> Fileset.encode_pq pqs.(i))
      t.pq_raw

type track = {
  number : int;
  indexes : (int * int) list;
  isrc : string option;
  flags : Cue.flags;
  text : Cue.text;
}

let texts t = match t.cdtext with Some d -> Cdtext.decode d | None -> []
let text_of texts n = Option.value (List.assoc_opt n texts) ~default:Cue.no_text
let disc_text t = text_of (texts t) 0

let tracks t =
  let texts = texts t in
  let numbers =
    List.sort_uniq compare
      (List.filter_map (fun (p : Fileset.pq) -> int_of_string_opt p.track) t.pq)
    |> List.filter (fun n -> n > 0)
  in
  List.map
    (fun number ->
      let packets =
        List.filter
          (fun (p : Fileset.pq) -> int_of_string_opt p.track = Some number)
          t.pq
      in
      {
        number;
        indexes = List.map (fun (p : Fileset.pq) -> (p.index, p.time)) packets;
        isrc =
          List.find_map
            (fun (p : Fileset.pq) -> if p.isrc = "" then None else Some p.isrc)
            packets;
        flags =
          (match packets with
          | p :: _ ->
              Option.value
                (Fileset.flags_of_control p.control)
                ~default:Cue.no_flags
          | [] -> Cue.no_flags);
        text = text_of texts number;
      })
    numbers

let track_start track =
  match List.assoc_opt 1 track.indexes with
  | Some time -> time
  | None -> Diag.error "PQ: track %02d has no index 01" track.number

let catalog t =
  match t.pq with
  | first :: _ when first.upc <> "" -> Some first.upc
  | _ -> if t.id.upc = "" then None else Some t.id.upc

type audio = { streams : (In_channel.t * int) list  (** channel, sectors *) }

let open_audio t =
  {
    streams =
      List.map
        (fun (s : Fileset.stream) ->
          (In_channel.open_bin (Filename.concat t.dir s.name), s.length))
        (audio_streams t.streams);
  }

let close_audio audio =
  List.iter (fun (ic, _) -> In_channel.close ic) audio.streams

let read_sectors audio ~sector buffer ~count =
  let rec read sector position count = function
    | _ when count = 0 -> position
    | [] -> position
    | (_, length) :: rest when sector >= length ->
        read (sector - length) position count rest
    | (ic, length) :: rest ->
        let n = min count (length - sector) in
        In_channel.seek ic (Int64.of_int (sector * Cd.sector_size));
        (match
           In_channel.really_input ic buffer
             (position * Cd.sector_size)
             (n * Cd.sector_size)
         with
        | Some () -> ()
        | None -> Diag.error "an audio file is shorter than DDPMS says");
        read 0 (position + n) (count - n) rest
  in
  read sector 0 count audio.streams

(** The program from track 1 INDEX 01, like ddpinfo's export. *)
let program_start t =
  match tracks t with
  | first :: _ -> track_start first
  | [] -> Diag.error "PQ: no tracks"

let export_cue t ~wav =
  let start = program_start t in
  Cue.to_string
    {
      catalog = catalog t;
      cdtext_file = None;
      files = [ { path = Filename.basename wav; file_type = `Wave } ];
      text = disc_text t;
      tracks =
        List.map
          (fun track ->
            {
              Cue.number = track.number;
              isrc = track.isrc;
              flags = track.flags;
              text = track.text;
              indexes =
                List.filter_map
                  (fun (i, time) ->
                    if time < start then None
                    else Some (i, { Cue.file = 0; time = time - start }))
                  track.indexes;
            })
          (tracks t);
    }

let wave_header data_length =
  let header = Bytes.create 44 in
  let u32 o v = Bytes.set_int32_le header o (Int32.of_int v) in
  let u16 o v = Bytes.set_uint16_le header o v in
  Bytes.blit_string "RIFF" 0 header 0 4;
  u32 4 (36 + data_length);
  Bytes.blit_string "WAVEfmt " 0 header 8 8;
  u32 16 16;
  u16 20 1;
  u16 22 2;
  u32 24 44100;
  u32 28 (44100 * 4);
  u16 32 4;
  u16 34 16;
  Bytes.blit_string "data" 0 header 36 4;
  u32 40 data_length;
  Bytes.to_string header

let export t ~wav =
  let start = program_start t and total = audio_sectors t in
  let audio = open_audio t in
  Fun.protect
    ~finally:(fun () -> close_audio audio)
    (fun () ->
      Out_channel.with_open_bin wav (fun oc ->
          Out_channel.output_string oc
            (wave_header ((total - start) * Cd.sector_size));
          let block = 32 in
          let buffer = Bytes.create (block * Cd.sector_size) in
          let rec copy sector =
            if sector < total then (
              let count = min block (total - sector) in
              let read = read_sectors audio ~sector buffer ~count in
              if read < count then
                Diag.error "the audio is shorter than DDPMS says";
              Out_channel.output oc buffer 0 (count * Cd.sector_size);
              copy (sector + count))
          in
          copy start));
  let cue = Filename.remove_extension wav ^ ".cue" in
  Out_channel.with_open_bin cue (fun oc ->
      Out_channel.output_string oc (export_cue t ~wav))
