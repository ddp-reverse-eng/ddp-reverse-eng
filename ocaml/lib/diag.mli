(** The library's single error type; re-exported as [Ddp.Error]. *)

exception Error of string

val error : ('a, unit, string, 'b) format4 -> 'a
(** Raises {!Error} with a formatted message. *)
