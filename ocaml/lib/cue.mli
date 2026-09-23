(** CDRWin cue sheets, restricted to what a DDP audio master needs: one audio
    file, audio tracks, indexes, ISRC, flags, catalog and CD-Text. *)

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
  cdtext_file : string option;  (** as written in the cue, not resolved *)
  file : string;  (** as written in the cue, not resolved *)
  file_type : file_type;
  text : text;
  tracks : track list;  (** numbered from 1 without gaps *)
}

exception Error of string

val parse : string -> t
(** @raise Error on syntax errors, with the file name and line number. *)
