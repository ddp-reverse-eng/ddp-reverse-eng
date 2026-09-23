let frames_per_second = 75
let sector_size = 2352
let max_frames = (((99 * 60) + 59) * frames_per_second) + 74

let of_msf ~minutes ~seconds ~frames =
  if
    minutes >= 0 && seconds >= 0 && seconds < 60 && frames >= 0
    && frames < frames_per_second
  then Some ((((minutes * 60) + seconds) * frames_per_second) + frames)
  else None

let parse_packed_msf s =
  let digits n = int_of_string_opt (String.sub s n 2) in
  if
    String.length s <> 6
    || not (String.for_all (fun c -> c >= '0' && c <= '9') s)
  then None
  else
    match (digits 0, digits 2, digits 4) with
    | Some minutes, Some seconds, Some frames ->
        of_msf ~minutes ~seconds ~frames
    | _ -> None

let format_msf ?(separator = "") frames =
  Printf.sprintf "%02d%s%02d%s%02d"
    (frames / (60 * frames_per_second))
    separator
    (frames / frames_per_second mod 60)
    separator
    (frames mod frames_per_second)
