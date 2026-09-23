(** DDP 2.00 audio CD fileset writer, see spec/ddp2.md. *)

module Cue = Cue
module Cdtext = Cdtext

exception Error of string

val write :
  ?master_id:string ->
  ?with_cdtext:bool ->
  ?with_cue:bool ->
  cue_path:string ->
  dir:string ->
  unit ->
  unit
(** Writes DDPID, DDPMS, SD, IMAGE.DAT, CHECKSUM.MD5 and CHECKSUM.TXT for
    [cue_path] into [dir], creating [dir] if needed. [with_cdtext] adds
    CDTEXT.BIN, [with_cue] adds IMAGE.cue.
    @raise Error on invalid input, and [Cue.Error] on cue syntax errors. *)
