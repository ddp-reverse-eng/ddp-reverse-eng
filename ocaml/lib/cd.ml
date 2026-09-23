let frames_per_second = 75
let sector_size = 2352
let max_frames = (((99 * 60) + 59) * frames_per_second) + 74

let of_msf ~minutes ~seconds ~frames =
  if
    minutes >= 0 && seconds >= 0 && seconds < 60 && frames >= 0
    && frames < frames_per_second
  then Some ((((minutes * 60) + seconds) * frames_per_second) + frames)
  else None

let format_msf ?(separator = "") frames =
  Printf.sprintf "%02d%s%02d%s%02d"
    (frames / (60 * frames_per_second))
    separator
    (frames / frames_per_second mod 60)
    separator
    (frames mod frames_per_second)
