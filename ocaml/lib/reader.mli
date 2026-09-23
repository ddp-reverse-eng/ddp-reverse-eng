(** Reads a DDP 2.00 audio fileset, checks it against spec/ddp2.md and exports
    it as a cue/wav image. *)

type t = {
  dir : string;
  id_raw : string;
  id : Fileset.id;
  map_raw : string;
  streams : Fileset.stream list;
  pq_raw : string;
  pq : Fileset.pq list;
  cdtext : string option;  (** raw CDTEXT.BIN, when DDPMS lists one *)
}

type severity =
  | Error  (** the fileset breaks the format *)
  | Warning  (** valid, but likely to cause trouble *)
  | Note  (** a field another writer fills differently from this one *)

val load : string -> t
(** @raise Diag.Error
      when DDPID, DDPMS or the PQ descriptor is missing or malformed. *)

val check : t -> (severity * string) list

val export : t -> wav:string -> unit
(** Writes the audio from track 1 INDEX 01 to [wav] and a cue sheet beside it,
    as ddpinfo -w does. Every audio (D0 DA) stream is joined in DDPMS order. *)
