(** Audio input for IMAGE.DAT: always delivered as 16-bit little-endian stereo
    at 44.1 kHz. Other encodings are converted only when no sample changes;
    anything else is refused. *)

type encoding = { float : bool; bits : int; channels : int; big_endian : bool }

type t = {
  path : string;
  offset : int;  (** of the sample data in the file *)
  length : int;  (** of the sample data, in source bytes *)
  encoding : encoding;
}

exception Error of string

val raw : big_endian:bool -> string -> t
(** Headerless 16-bit stereo, as cue sheet BINARY or MOTOROLA files. *)

val wave : string -> t
(** A RIFF WAVE file at 44.1 kHz: PCM of 8, 16, 24 or 32 bits or float of 32 or
    64 bits, mono or stereo, plain or extensible header. Mono prints a warning.
*)

val output_length : t -> int
(** Length of the converted audio in bytes. *)

val validate : t -> unit
(** Checks that every sample converts exactly, reading the whole file when the
    encoding could fail.
    @raise Error naming the first sample that does not fit. *)

val iter_pcm16 : t -> (Bytes.t -> int -> unit) -> unit
(** Calls [output buffer length] with successive blocks of converted audio. *)
