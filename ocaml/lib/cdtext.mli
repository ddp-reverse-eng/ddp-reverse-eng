(** CD-Text lead-in packs, as stored in a DDP's CDTEXT.BIN. *)

val pack_size : int

val encode : disc:Cue.text -> tracks:Cue.track list -> string
(** Title, performer and songwriter packs plus size information, block 0, ISO
    8859-1. Returns [""] when neither the disc nor any track has text. *)
