(** The DDPID, DDPMS and PQ descriptor records as values, with the one encoder
    and decoder of each. Decoding keeps only what the writer produces; fields it
    leaves blank are compared with [Record.*.all] by the reader. *)

type id = { upc : string; master_id : string; user_text : string }

type stream = {
  stream_type : string;  (** DST: [D0] data, [S0] subcode *)
  length : int;  (** DSL: sectors for D0, bytes for S0 *)
  start : int option;  (** DSS *)
  subcode : string;  (** SUB: [PQ DESCR], [CDTEXT] *)
  cd_mode : string;  (** CDM: [DA] for audio *)
  storage_mode : string;  (** SSM *)
  scrambled : string;  (** SCR *)
  pregap2 : int option;  (** PRE2: track 1 pregap sectors in the stream *)
  track : string;  (** TRK *)
  name : string;  (** DSI: the file name *)
}
(** A DDPMS packet. *)

type pq = {
  track : string;  (** [00] lead-in, [01]..[99], [AA] lead-out *)
  index : int;
  time : int;
  control : string;  (** C1 *)
  isrc : string;
  upc : string;
}
(** A PQ descriptor packet, times in frames from the start of the image. *)

val blank_stream : stream
(** Every field empty, for building packets. *)

val control_of_flags : Cue.flags -> string
(** C1: the Q control nibble in hex (PRE=1, DCP=2, 4CH=8) then ADR [1], or [S]
    for SCMS. *)

val flags_of_control : string -> Cue.flags option
(** [None] for anything {!control_of_flags} cannot produce. *)

val encode_id : id -> string
(** @raise Diag.Error when a value does not fit its field. *)

val encode_stream : stream -> string
val encode_pq : pq -> string

val decode_id : string -> id
(** @raise Diag.Error on a malformed record, naming the packet and field. *)

val decode_streams : string -> stream list
val decode_pqs : string -> pq list
