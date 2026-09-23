type flags = { pre : bool; dcp : bool; four_channel : bool; scms : bool }

type text = {
  title : string option;
  performer : string option;
  songwriter : string option;
}

type track = {
  number : int;
  isrc : string option;
  flags : flags;
  indexes : (int * int) list;
      (** (index number, frame offset in the audio file), in cue order *)
  text : text;
}

type file_type = [ `Wave | `Binary | `Motorola ]

type t = {
  catalog : string option;
  cdtext_file : string option;
  file : string;
  file_type : file_type;
  text : text;
  tracks : track list;
}

exception Error of string

let no_flags = { pre = false; dcp = false; four_channel = false; scms = false }
let no_text = { title = None; performer = None; songwriter = None }

let fail ~path ~line fmt =
  Printf.ksprintf (fun msg -> raise (Error (Printf.sprintf "%s:%d: %s" path line msg))) fmt

(** A quoted argument runs to the last double quote of the line, so it may
    contain unescaped quotes. *)
let argument rest =
  match (String.index_opt rest '"', String.rindex_opt rest '"') with
  | Some first, Some last when last > first ->
      String.sub rest (first + 1) (last - first - 1)
  | _ -> (
      match String.split_on_char ' ' (String.trim rest) with
      | word :: _ -> word
      | [] -> "")

let words rest =
  String.split_on_char ' ' rest
  |> List.concat_map (String.split_on_char '\t')
  |> List.filter (( <> ) "")

let frames_of_time ~path ~line time =
  match String.split_on_char ':' time |> List.map int_of_string_opt with
  | [ Some m; Some s; Some f ] when s < 60 && f < 75 && m >= 0 && s >= 0 && f >= 0 ->
      (((m * 60) + s) * 75) + f
  | _ -> fail ~path ~line "invalid time '%s'" time

let set_text text command value =
  match command with
  | "TITLE" -> { text with title = Some value }
  | "PERFORMER" -> { text with performer = Some value }
  | _ -> { text with songwriter = Some value }

let parse_flags ~path ~line rest =
  List.fold_left
    (fun flags word ->
      match word with
      | "PRE" -> { flags with pre = true }
      | "DCP" -> { flags with dcp = true }
      | "4CH" -> { flags with four_channel = true }
      | "SCMS" -> { flags with scms = true }
      | _ -> fail ~path ~line "unknown flag '%s'" word)
    no_flags (words rest)

let split_command line =
  let line = String.trim line in
  match String.index_opt line ' ' with
  | Some i -> (String.uppercase_ascii (String.sub line 0 i), String.sub line (i + 1) (String.length line - i - 1))
  | None -> (String.uppercase_ascii line, "")

let parse path =
  let lines = In_channel.with_open_bin path In_channel.input_all |> String.split_on_char '\n' in
  let disc =
    ref { catalog = None; cdtext_file = None; file = ""; file_type = `Wave; text = no_text; tracks = [] }
  in
  let current = ref None in
  let finish_track () =
    Option.iter
      (fun track -> disc := { !disc with tracks = { track with indexes = List.rev track.indexes } :: !disc.tracks })
      !current;
    current := None
  in
  List.iteri
    (fun i raw ->
      let line = i + 1 in
      let raw = if String.ends_with ~suffix:"\r" raw then String.sub raw 0 (String.length raw - 1) else raw in
      let command, rest = split_command raw in
      match (command, !current) with
      | ("" | "REM"), _ -> ()
      | "CATALOG", None -> disc := { !disc with catalog = Some (argument rest) }
      | "CDTEXTFILE", None -> disc := { !disc with cdtext_file = Some (argument rest) }
      | "FILE", None ->
          if !disc.file <> "" then fail ~path ~line "only one FILE is supported";
          let file_type =
            match List.rev (words rest) with
            | "WAVE" :: _ -> `Wave
            | "BINARY" :: _ -> `Binary
            | "MOTOROLA" :: _ -> `Motorola
            | kind :: _ -> fail ~path ~line "unsupported file type '%s'" kind
            | [] -> fail ~path ~line "missing file type"
          in
          disc := { !disc with file = argument rest; file_type }
      | ("TITLE" | "PERFORMER" | "SONGWRITER"), None ->
          disc := { !disc with text = set_text !disc.text command (argument rest) }
      | ("TITLE" | "PERFORMER" | "SONGWRITER"), Some track ->
          current := Some { track with text = set_text track.text command (argument rest) }
      | "TRACK", _ ->
          finish_track ();
          if !disc.file = "" then fail ~path ~line "TRACK before FILE";
          let number, kind =
            match words rest with
            | [ number; kind ] -> (int_of_string_opt number, kind)
            | _ -> fail ~path ~line "invalid TRACK"
          in
          if kind <> "AUDIO" then fail ~path ~line "only AUDIO tracks are supported";
          let number = match number with Some n -> n | None -> fail ~path ~line "invalid track number" in
          if number <> List.length !disc.tracks + 1 then fail ~path ~line "tracks must be numbered from 01 without gaps";
          current := Some { number; isrc = None; flags = no_flags; indexes = []; text = no_text }
      | "ISRC", Some track -> current := Some { track with isrc = Some (argument rest) }
      | "FLAGS", Some track -> current := Some { track with flags = parse_flags ~path ~line rest }
      | "INDEX", Some track ->
          let index, time =
            match words rest with
            | [ index; time ] -> (int_of_string_opt index, time)
            | _ -> fail ~path ~line "invalid INDEX"
          in
          let index = match index with Some n when n >= 0 && n <= 99 -> n | _ -> fail ~path ~line "invalid index number" in
          current := Some { track with indexes = (index, frames_of_time ~path ~line time) :: track.indexes }
      | ("PREGAP" | "POSTGAP"), _ -> fail ~path ~line "%s is not supported" command
      | _ -> fail ~path ~line "unexpected '%s'" command)
    lines;
  finish_track ();
  if !disc.tracks = [] then fail ~path ~line:(List.length lines) "no tracks";
  { !disc with tracks = List.rev !disc.tracks }
