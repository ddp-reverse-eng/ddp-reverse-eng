(** CHECKSUM.MD5 (md5sum format) and CHECKSUM.TXT (CRC32, INI style), the
    checksum files cue2ddp writes beside a fileset. They are not part of DDP. *)

val write : dir:string -> string list -> unit
(** Writes both files for [names], in that order, inside [dir]. *)

val verify : dir:string -> (string * string * bool) list
(** Checks every entry of CHECKSUM.TXT and of every [*.md5] file in [dir] (other
    writers name theirs MD5_CHECKSUM.MD5 or MD5-Checksum.md5): (algorithm, file
    name, matches). A missing file does not match. *)
