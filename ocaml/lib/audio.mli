(** Audio input for IMAGE.DAT, always delivered as 16-bit little-endian stereo
    at 44.1 kHz. Other encodings are converted only when no sample changes;
    anything else is refused. *)

type t

val of_file :
  warn:(string -> unit) -> [ `Wave | `Binary | `Motorola ] -> string -> t
(** Opens a cue sheet FILE and checks every sample converts exactly. [`Wave]
    accepts 44.1 kHz PCM of 8, 16, 24 or 32 bits or float of 32 or 64 bits, mono
    or stereo, plain or extensible header; mono is reported through [warn].
    [`Binary] and [`Motorola] are headerless 16-bit stereo, little and big
    endian.
    @raise Diag.Error
      on unsupported or damaged audio, naming the first sample that does not
      fit. *)

val output_length : t -> int
(** Length of the converted audio in bytes. *)

val iter_pcm16 : t -> (Bytes.t -> int -> unit) -> unit
(** Calls [output buffer length] with successive blocks of converted audio. *)
