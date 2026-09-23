type flags = { pre : bool; dcp : bool; four_channel : bool; scms : bool }

type text = {
  title : string option;
  performer : string option;
  songwriter : string option;
  composer : string option;
  arranger : string option;
  message : string option;
}

type position = {
  file : int;  (** position of the FILE in [t.files] *)
  time : int;  (** frames from the start of that file *)
}

type track = {
  number : int;
  isrc : string option;
  flags : flags;
  indexes : (int * position) list;
      (** (index number, position), in cue order *)
  text : text;
}

type file_type = [ `Wave | `Binary | `Motorola ]
type file = { path : string; file_type : file_type }

type t = {
  catalog : string option;
  cdtext_file : string option;
  files : file list;
  text : text;
  tracks : track list;
}

let no_flags = { pre = false; dcp = false; four_channel = false; scms = false }

let no_text =
  {
    title = None;
    performer = None;
    songwriter = None;
    composer = None;
    arranger = None;
    message = None;
  }

let fail ~path ~line fmt =
  Printf.ksprintf (fun msg -> Diag.error "%s:%d: %s" path line msg) fmt

let words rest =
  String.split_on_char ' ' rest
  |> List.concat_map (String.split_on_char '\t')
  |> List.filter (( <> ) "")

(** A quoted argument runs to the last double quote of the line, so it may
    contain unescaped quotes. *)
let argument rest =
  match (String.index_opt rest '"', String.rindex_opt rest '"') with
  | Some first, Some last when last > first ->
      String.sub rest (first + 1) (last - first - 1)
  | _ -> ( match words rest with word :: _ -> word | [] -> "")

let frames_of_time ~path ~line time =
  let frames =
    match String.split_on_char ':' time |> List.map int_of_string_opt with
    | [ Some minutes; Some seconds; Some frames ] ->
        Cd.of_msf ~minutes ~seconds ~frames
    | _ -> None
  in
  match frames with
  | Some frames -> frames
  | None -> fail ~path ~line "invalid time '%s'" time

(** CD-Text is ISO 8859-1; a UTF-8 cue sheet's text is converted when every
    character fits. *)
let latin1_of_utf8 ~path ~line value =
  let buffer = Buffer.create (String.length value) in
  let rec loop i =
    if i < String.length value then (
      let decoded = String.get_utf_8_uchar value i in
      let code = Uchar.to_int (Uchar.utf_decode_uchar decoded) in
      if code > 0xFF then
        fail ~path ~line "U+%04X is not in ISO 8859-1, which CD-Text uses" code;
      Buffer.add_char buffer (Char.chr code);
      loop (i + Uchar.utf_decode_length decoded))
  in
  loop 0;
  Buffer.contents buffer

let set_text text command value =
  match command with
  | "TITLE" -> { text with title = Some value }
  | "PERFORMER" -> { text with performer = Some value }
  | "SONGWRITER" -> { text with songwriter = Some value }
  | "COMPOSER" -> { text with composer = Some value }
  | "ARRANGER" -> { text with arranger = Some value }
  | _ -> { text with message = Some value }

let parse_flags ~path ~line rest =
  List.fold_left
    (fun flags word ->
      match String.uppercase_ascii word with
      | "PRE" -> { flags with pre = true }
      | "DCP" -> { flags with dcp = true }
      | "4CH" -> { flags with four_channel = true }
      | "SCMS" -> { flags with scms = true }
      | _ -> fail ~path ~line "unknown flag '%s'" word)
    no_flags (words rest)

let split_command line =
  let line = String.trim line in
  let space = String.index_opt line ' ' and tab = String.index_opt line '\t' in
  match
    match (space, tab) with
    | Some s, Some t -> Some (min s t)
    | Some i, None | None, Some i -> Some i
    | None, None -> None
  with
  | Some i ->
      ( String.uppercase_ascii (String.sub line 0 i),
        String.sub line (i + 1) (String.length line - i - 1) )
  | None -> (String.uppercase_ascii line, "")

let known_commands =
  [
    "CATALOG";
    "CDTEXTFILE";
    "FILE";
    "TITLE";
    "PERFORMER";
    "SONGWRITER";
    "COMPOSER";
    "ARRANGER";
    "MESSAGE";
    "TRACK";
    "ISRC";
    "FLAGS";
    "INDEX";
  ]

let file_type_name = function
  | `Wave -> "WAVE"
  | `Binary -> "BINARY"
  | `Motorola -> "MOTOROLA"

let text_lines indent (t : text) =
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

let flag_names (f : flags) =
  List.filter_map
    (fun (set, name) -> if set then Some name else None)
    [
      (f.pre, "PRE"); (f.dcp, "DCP"); (f.four_channel, "4CH"); (f.scms, "SCMS");
    ]

let to_string cue =
  let files = Array.of_list cue.files in
  let buffer = Buffer.create 1024 in
  let add = Buffer.add_string buffer in
  let current = ref (-1) in
  let file n =
    if n <> !current then (
      current := n;
      add
        (Printf.sprintf "FILE \"%s\" %s\n" files.(n).path
           (file_type_name files.(n).file_type)))
  in
  Option.iter (fun c -> add ("CATALOG " ^ c ^ "\n")) cue.catalog;
  Option.iter (fun f -> add ("CDTEXTFILE \"" ^ f ^ "\"\n")) cue.cdtext_file;
  List.iter add (text_lines "" cue.text);
  List.iter
    (fun t ->
      (match t.indexes with (_, p) :: _ -> file p.file | [] -> ());
      add (Printf.sprintf "  TRACK %02d AUDIO\n" t.number);
      List.iter add (text_lines "    " t.text);
      Option.iter (fun isrc -> add ("    ISRC " ^ isrc ^ "\n")) t.isrc;
      (match flag_names t.flags with
      | [] -> ()
      | names -> add ("    FLAGS " ^ String.concat " " names ^ "\n"));
      List.iter
        (fun (i, p) ->
          file p.file;
          add
            (Printf.sprintf "    INDEX %02d %s\n" i
               (Cd.format_msf ~separator:":" p.time)))
        t.indexes)
    cue.tracks;
  Buffer.contents buffer

let parse ~warn path =
  let contents = In_channel.with_open_bin path In_channel.input_all in
  let bom = "\xEF\xBB\xBF" in
  let contents =
    if String.starts_with ~prefix:bom contents then
      String.sub contents 3 (String.length contents - 3)
    else contents
  in
  let utf8 =
    String.is_valid_utf_8 contents
    && String.exists (fun c -> Char.code c >= 0x80) contents
  in
  let lines = String.split_on_char '\n' contents in
  let resolve file =
    if Filename.is_relative file then
      Filename.concat (Filename.dirname path) file
    else file
  in
  let disc =
    ref
      {
        catalog = None;
        cdtext_file = None;
        files = [];
        text = no_text;
        tracks = [];
      }
  in
  let current = ref None in
  let finish_track () =
    Option.iter
      (fun track ->
        disc :=
          {
            !disc with
            tracks =
              { track with indexes = List.rev track.indexes } :: !disc.tracks;
          })
      !current;
    current := None
  in
  List.iteri
    (fun i raw ->
      let line = i + 1 in
      let raw =
        if String.ends_with ~suffix:"\r" raw then
          String.sub raw 0 (String.length raw - 1)
        else raw
      in
      let command, rest = split_command raw in
      let text_argument rest =
        let value = argument rest in
        if utf8 then latin1_of_utf8 ~path ~line value else value
      in
      match (command, !current) with
      | ("" | "REM"), _ -> ()
      | "CATALOG", None -> disc := { !disc with catalog = Some (argument rest) }
      | "CDTEXTFILE", None ->
          disc := { !disc with cdtext_file = Some (resolve (argument rest)) }
      | "FILE", _ ->
          let file_type =
            match List.rev_map String.uppercase_ascii (words rest) with
            | "WAVE" :: _ -> `Wave
            | "BINARY" :: _ -> `Binary
            | "MOTOROLA" :: _ -> `Motorola
            | kind :: _ -> fail ~path ~line "unsupported file type '%s'" kind
            | [] -> fail ~path ~line "missing file type"
          in
          disc :=
            {
              !disc with
              files =
                !disc.files @ [ { path = resolve (argument rest); file_type } ];
            }
      | ( ( "TITLE" | "PERFORMER" | "SONGWRITER" | "COMPOSER" | "ARRANGER"
          | "MESSAGE" ),
          None ) ->
          disc :=
            {
              !disc with
              text = set_text !disc.text command (text_argument rest);
            }
      | ( ( "TITLE" | "PERFORMER" | "SONGWRITER" | "COMPOSER" | "ARRANGER"
          | "MESSAGE" ),
          Some track ) ->
          current :=
            Some
              {
                track with
                text = set_text track.text command (text_argument rest);
              }
      | "TRACK", _ ->
          finish_track ();
          if !disc.files = [] then fail ~path ~line "TRACK before FILE";
          let number, kind =
            match words rest with
            | [ number; kind ] -> (int_of_string_opt number, kind)
            | _ -> fail ~path ~line "invalid TRACK"
          in
          if String.uppercase_ascii kind <> "AUDIO" then
            fail ~path ~line "only AUDIO tracks are supported";
          let number =
            match number with
            | Some n -> n
            | None -> fail ~path ~line "invalid track number"
          in
          if number <> List.length !disc.tracks + 1 then
            fail ~path ~line "tracks must be numbered from 01 without gaps";
          current :=
            Some
              {
                number;
                isrc = None;
                flags = no_flags;
                indexes = [];
                text = no_text;
              }
      | "ISRC", Some track ->
          current := Some { track with isrc = Some (argument rest) }
      | "FLAGS", Some track ->
          current := Some { track with flags = parse_flags ~path ~line rest }
      | "INDEX", Some track ->
          let index, time =
            match words rest with
            | [ index; time ] -> (int_of_string_opt index, time)
            | _ -> fail ~path ~line "invalid INDEX"
          in
          let index =
            match index with
            | Some n when n >= 0 && n <= 99 -> n
            | _ -> fail ~path ~line "invalid index number"
          in
          current :=
            Some
              {
                track with
                indexes =
                  ( index,
                    {
                      file = List.length !disc.files - 1;
                      time = frames_of_time ~path ~line time;
                    } )
                  :: track.indexes;
              }
      | ("PREGAP" | "POSTGAP"), _ ->
          fail ~path ~line "%s is not supported" command
      | _ when List.mem command known_commands ->
          fail ~path ~line "%s is not allowed here" command
      | _ -> warn (Printf.sprintf "%s:%d: ignored '%s'" path line command))
    lines;
  finish_track ();
  if !disc.tracks = [] then fail ~path ~line:(List.length lines) "no tracks";
  { !disc with tracks = List.rev !disc.tracks }
