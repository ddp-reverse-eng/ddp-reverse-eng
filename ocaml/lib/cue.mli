(** CDRWin cue sheets, restricted to what a DDP audio master needs: audio files,
    audio tracks, indexes, ISRC, flags, catalog and CD-Text, including the
    COMPOSER, ARRANGER and MESSAGE extensions. *)

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
  cdtext_file : string option;  (** resolved against the cue's directory *)
  files : file list;  (** in cue order, resolved against the cue's directory *)
  text : text;
  tracks : track list;  (** numbered from 1 without gaps *)
}

val to_string : t -> string
(** Renders a cue sheet: CATALOG, CDTEXTFILE, disc text, then each track with
    its text, ISRC, FLAGS and indexes, a FILE line wherever the file changes.
    Paths are written as they are in [t]. *)

val parse : warn:(string -> unit) -> string -> t
(** Unknown commands are reported through [warn] and ignored, as cue2ddp does; a
    UTF-8 BOM is skipped and commands, file types and flags are
    case-insensitive.
    @raise Diag.Error on syntax errors, with the file name and line number. *)
