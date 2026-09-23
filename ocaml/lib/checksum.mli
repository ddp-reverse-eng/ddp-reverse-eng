(** CHECKSUM.MD5 (md5sum format) and CHECKSUM.TXT (CRC32, INI style), the
    checksum files cue2ddp writes beside a fileset. They are not part of DDP. *)

val write : dir:string -> string list -> unit
(** Writes both files for [names], in that order, inside [dir]. *)

val verify : dir:string -> (string * string * bool) list
(** Checks every entry of whichever of the two files exist in [dir]: (algorithm,
    file name, matches). A missing file does not match. *)
