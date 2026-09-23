(** Red Book CD addressing: 75 frames (sectors) per second, 2352 bytes each. *)

val frames_per_second : int
val sector_size : int

val max_frames : int
(** 99:59:74, the last address a two-digit minute can express. *)

val of_msf : minutes:int -> seconds:int -> frames:int -> int option
(** Frame count of a minutes:seconds:frames time, [None] when out of range. *)

val format_msf : ?separator:string -> int -> string
(** [MM<sep>SS<sep>FF]; minutes go past 59 rather than into hours. *)
