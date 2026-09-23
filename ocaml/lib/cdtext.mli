(** CD-Text lead-in packs, as stored in a DDP's CDTEXT.BIN. *)

val encode : disc:Cue.text -> tracks:Cue.track list -> string
(** Title, performer, songwriter, composer, arranger and message packs plus size
    information, block 0, ISO 8859-1. Returns [""] when neither the disc nor any
    track has text.
    @raise Diag.Error when the text needs more than the 256 packs a block holds.
*)

val bad_crc_packs : string -> int
(** Number of packs whose CRC does not match. *)

val decode : string -> (int * Cue.text) list
(** Block 0 text per track, track 0 being the disc; a TAB string stands for the
    previous track's. *)

val of_file : warn:(string -> unit) -> string -> string
(** Reads a binary CD-Text file: bare packs, no header. Packs with a wrong CRC
    are reported through [warn] and kept, as cue2ddp keeps them.
    @raise Diag.Error when it is not a whole number of packs. *)
