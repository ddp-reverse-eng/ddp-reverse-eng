type id = { upc : string; master_id : string; user_text : string }

type stream = {
  stream_type : string;
  length : int;
  start : int option;
  subcode : string;
  cd_mode : string;
  storage_mode : string;
  scrambled : string;
  pregap2 : int option;
  track : string;
  name : string;
}

type pq = {
  track : string;
  index : int;
  time : int;
  control : string;
  isrc : string;
  upc : string;
}

let blank_stream =
  {
    stream_type = "";
    length = 0;
    start = None;
    subcode = "";
    cd_mode = "";
    storage_mode = "";
    scrambled = "";
    pregap2 = None;
    track = "";
    name = "";
  }

let record size values =
  try Record.make size values
  with Record.Overflow (value, width) ->
    Diag.error "value '%s' does not fit in %d bytes" value width

let optional = function Some n -> string_of_int n | None -> ""

let encode_id (id : id) =
  let module F = Record.Ddpid in
  record F.size
    [
      (F.level, "DDP 2.00");
      (F.upc, id.upc);
      (F.master_id, id.master_id);
      (F.disc_type, "CD");
      ( F.user_text_length,
        if id.user_text = "" then ""
        else string_of_int (String.length id.user_text) );
      (F.user_text, id.user_text);
    ]

let encode_stream s =
  let module F = Record.Map in
  record F.size
    [
      (F.version, "VVVM");
      (F.stream_type, s.stream_type);
      (F.length, string_of_int s.length);
      (F.start, optional s.start);
      (F.subcode, s.subcode);
      (F.cd_mode, s.cd_mode);
      (F.storage_mode, s.storage_mode);
      (F.scrambled, s.scrambled);
      (F.pregap2, optional s.pregap2);
      (F.track, s.track);
      (F.name_size, string_of_int F.name.width);
      (F.name, s.name);
    ]

let encode_pq (pq : pq) =
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

let field f record = String.trim (Record.get f record)

let number ~what f record =
  match int_of_string_opt (field f record) with
  | Some n when n >= 0 -> n
  | _ -> Diag.error "%s: '%s' is not a number" what (Record.get f record)

let optional_number ~what f record =
  if field f record = "" then None else Some (number ~what f record)

let packets ~name ~size data =
  if String.length data mod size <> 0 then
    Diag.error "%s: %d bytes is not a whole number of %d-byte packets" name
      (String.length data) size;
  List.init
    (String.length data / size)
    (fun i -> String.sub data (i * size) size)

let expect ~what f record value =
  if Record.get f record <> value then
    Diag.error "%s: expected '%s', found '%s'" what value (Record.get f record)

let decode_id data =
  let module F = Record.Ddpid in
  if String.length data <> F.size then
    Diag.error "DDPID: %d bytes, expected %d" (String.length data) F.size;
  expect ~what:"DDPID level" F.level data "DDP 2.00";
  let user_text = Record.get F.user_text data in
  let user_text =
    match int_of_string_opt (field F.user_text_length data) with
    | Some n when n <= String.length user_text -> String.sub user_text 0 n
    | _ -> String.trim user_text
  in
  { upc = field F.upc data; master_id = field F.master_id data; user_text }

let decode_streams data =
  let module F = Record.Map in
  packets ~name:"DDPMS" ~size:F.size data
  |> List.mapi (fun i p ->
      let what name = Printf.sprintf "DDPMS packet %d %s" i name in
      expect ~what:(what "MPV") F.version p "VVVM";
      {
        stream_type = field F.stream_type p;
        length = number ~what:(what "DSL") F.length p;
        start = optional_number ~what:(what "DSS") F.start p;
        subcode = field F.subcode p;
        cd_mode = field F.cd_mode p;
        storage_mode = field F.storage_mode p;
        scrambled = field F.scrambled p;
        pregap2 = optional_number ~what:(what "PRE2") F.pregap2 p;
        track = field F.track p;
        name = field F.name p;
      })

let decode_pqs data =
  let module F = Record.Pq in
  packets ~name:"PQ descriptor" ~size:F.size data
  |> List.mapi (fun i p ->
      let what name = Printf.sprintf "PQ packet %d %s" i name in
      expect ~what:(what "SPV") F.version p "VVVS";
      let time =
        match Cd.parse_packed_msf (field F.time p) with
        | Some t -> t
        | None ->
            Diag.error "%s: '%s' is not MMSSFF" (what "A-Time")
              (Record.get F.time p)
      in
      {
        track = field F.track p;
        index = number ~what:(what "I") F.index p;
        time;
        control = field F.control p;
        isrc = field F.isrc p;
        upc = field F.upc p;
      })
