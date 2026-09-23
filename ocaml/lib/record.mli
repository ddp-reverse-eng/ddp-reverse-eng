(** Fixed-width ASCII records of DDPID, DDPMS and the PQ descriptor: the one
    place that knows where each field sits, see spec/ddp2.md. Unset bytes are
    spaces. *)

type field = private { offset : int; width : int; align : [ `Left | `Right ] }

exception Overflow of string * int
(** Raised by {!make} with the value and the field width. *)

val make : int -> (field * string) list -> string

module Ddpid : sig
  val size : int
  val level : field
  val upc : field
  val master_id : field
  val disc_type : field
end

(** DDPMS packets. *)
module Map : sig
  val size : int
  val version : field
  val stream_type : field
  val length : field
  val subcode : field
  val cd_mode : field
  val storage_mode : field
  val scrambled : field
  val pregap2 : field
  val track : field

  val name_size : field
  (** Holds the width of [name]. *)

  val name : field
end

(** PQ descriptor (SD) packets. *)
module Pq : sig
  val size : int
  val version : field
  val track : field
  val index : field

  val time : field
  (** Right-aligned MMSSFF. *)

  val control : field
  val isrc : field
  val upc : field
end
