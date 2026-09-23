module Reader = Ddp.Reader

let usage = "ddpplay [--driver NAME] DIRECTORY"
let chunk_sectors = 4
let fps = Ddp.Cd.frames_per_second

type state = { position : int; paused : bool; quit : bool }

type command =
  | Toggle
  | Next
  | Previous
  | Seek of int  (** frames *)
  | Goto of int  (** track number *)
  | Quit

type disc = { tracks : Reader.track array; total : int }

(** A track's first index, its pregap when it has one. *)
let track_first (t : Reader.track) =
  match t.indexes with (_, time) :: _ -> time | [] -> Reader.track_start t

let current disc position =
  let found = ref 0 in
  Array.iteri
    (fun i t -> if track_first t <= position then found := i)
    disc.tracks;
  !found

(** Length from index 01 to the next track's first index, or the lead-out. *)
let track_length disc i =
  let next =
    if i + 1 < Array.length disc.tracks then track_first disc.tracks.(i + 1)
    else disc.total
  in
  next - Reader.track_start disc.tracks.(i)

let clamp disc position = max 0 (min (disc.total - 1) position)

let apply disc state = function
  | Toggle -> { state with paused = not state.paused }
  | Quit -> { state with quit = true }
  | Seek frames ->
      { state with position = clamp disc (state.position + frames) }
  | Next ->
      let i = current disc state.position in
      if i + 1 < Array.length disc.tracks then
        { state with position = Reader.track_start disc.tracks.(i + 1) }
      else state
  | Previous ->
      let i = current disc state.position in
      let start = Reader.track_start disc.tracks.(i) in
      let position =
        if state.position - start > 3 * fps || i = 0 then start
        else Reader.track_start disc.tracks.(i - 1)
      in
      { state with position }
  | Goto n ->
      if n >= 1 && n <= Array.length disc.tracks then
        { state with position = Reader.track_start disc.tracks.(n - 1) }
      else state

let rec parse = function
  | [] -> []
  | '\027' :: '[' :: 'C' :: rest -> Next :: parse rest
  | '\027' :: '[' :: 'D' :: rest -> Previous :: parse rest
  | '\027' :: '[' :: 'A' :: rest -> Seek (60 * fps) :: parse rest
  | '\027' :: '[' :: 'B' :: rest -> Seek (-60 * fps) :: parse rest
  | (' ' | 'k') :: rest -> Toggle :: parse rest
  | ('n' | '.') :: rest -> Next :: parse rest
  | ('p' | ',') :: rest -> Previous :: parse rest
  | 'f' :: rest -> Seek (10 * fps) :: parse rest
  | 'b' :: rest -> Seek (-10 * fps) :: parse rest
  | 'q' :: rest -> Quit :: parse rest
  | ('1' .. '9' as c) :: rest ->
      Goto (Char.code c - Char.code '0') :: parse rest
  | _ :: rest -> parse rest

let poll_keys ~timeout =
  match Unix.select [ Unix.stdin ] [] [] timeout with
  | [], _, _ -> []
  | _ -> (
      let buffer = Bytes.create 64 in
      match Unix.read Unix.stdin buffer 0 64 with
      | 0 -> []
      | n -> parse (List.init n (Bytes.get buffer)))

let clock frames =
  let seconds = abs frames / fps in
  Printf.sprintf "%s%02d:%02d"
    (if frames < 0 then "-" else "")
    (seconds / 60) (seconds mod 60)

let fit width s =
  if String.length s <= width then s ^ String.make (width - String.length s) ' '
  else String.sub s 0 (width - 1) ^ "~"

let describe (text : Ddp.Cue.text) ~default =
  match (text.title, text.performer) with
  | Some t, Some p -> t ^ " / " ^ p
  | Some t, None -> t
  | None, Some p -> p
  | None, None -> default

let render reader disc state =
  let i = current disc state.position in
  let track = disc.tracks.(i) in
  let buffer = Buffer.create 4096 in
  let line s = Buffer.add_string buffer (s ^ "\027[K\n") in
  line
    (describe (Reader.disc_text reader) ~default:(Filename.basename reader.dir));
  line
    (Printf.sprintf "%d tracks, %s%s" (Array.length disc.tracks)
       (clock disc.total)
       (match Reader.catalog reader with Some c -> "   UPC " ^ c | None -> ""));
  line (String.make 72 '-');
  Array.iteri
    (fun n (t : Reader.track) ->
      let marker = if n = i then "\027[7m>" else " " in
      let flags =
        String.concat " "
          (List.filter_map
             (fun (set, name) -> if set then Some name else None)
             [
               (t.flags.pre, "PRE");
               (t.flags.dcp, "DCP");
               (t.flags.four_channel, "4CH");
               (t.flags.scms, "SCMS");
             ])
      in
      line
        (Printf.sprintf "%s %02d  %s  %s %s\027[0m" marker t.number
           (clock (track_length disc n))
           (fit 48 (describe t.text ~default:""))
           flags))
    disc.tracks;
  line (String.make 72 '-');
  let into = state.position - Reader.track_start track in
  let width = 40 in
  let filled = state.position * width / max 1 disc.total in
  line
    (Printf.sprintf "%s  track %02d  %s / %s   disc %s / %s"
       (if state.paused then "||" else "> ")
       track.number (clock into)
       (clock (track_length disc i))
       (clock state.position) (clock disc.total));
  line ("[" ^ String.make filled '#' ^ String.make (width - filled) '.' ^ "]");
  line
    "space play/pause   n/p or arrows: tracks   f/b: 10 s   1-9: track   q: \
     quit";
  print_string ("\027[H" ^ Buffer.contents buffer ^ "\027[J");
  flush stdout

let with_raw_terminal f =
  if not (Unix.isatty Unix.stdin) then f ()
  else
    let saved = Unix.tcgetattr Unix.stdin in
    Unix.tcsetattr Unix.stdin Unix.TCSANOW
      { saved with c_icanon = false; c_echo = false; c_vmin = 1; c_vtime = 0 };
    print_string "\027[?25l\027[2J";
    Fun.protect
      ~finally:(fun () ->
        Unix.tcsetattr Unix.stdin Unix.TCSANOW saved;
        print_string "\027[?25h\n";
        flush stdout)
      f

let play reader ~device =
  let tracks = Array.of_list (Reader.tracks reader) in
  if tracks = [||] then raise (Ddp.Error "no tracks");
  let disc = { tracks; total = Reader.audio_sectors reader } in
  let audio = Reader.open_audio reader in
  let buffer = Bytes.create (chunk_sectors * Ddp.Cd.sector_size) in
  let interactive = Unix.isatty Unix.stdout in
  let rec loop state last_draw =
    let state =
      List.fold_left (apply disc) state
        (poll_keys ~timeout:(if state.paused then 0.1 else 0.))
    in
    let state =
      if state.paused || state.quit then state
      else
        let count =
          Reader.read_sectors audio ~sector:state.position buffer
            ~count:(min chunk_sectors (disc.total - state.position))
        in
        Ao.play device (Bytes.sub_string buffer 0 (count * Ddp.Cd.sector_size));
        let position = state.position + count in
        { state with position; quit = position >= disc.total }
    in
    let now = Unix.gettimeofday () in
    let last_draw =
      if interactive && now -. last_draw > 0.1 then (
        render reader disc state;
        now)
      else last_draw
    in
    if state.quit then state else loop state last_draw
  in
  Fun.protect
    ~finally:(fun () -> Reader.close_audio audio)
    (fun () ->
      let start =
        {
          position = Reader.track_start tracks.(0);
          paused = false;
          quit = false;
        }
      in
      let final = with_raw_terminal (fun () -> loop start 0.) in
      let i = current disc final.position in
      Printf.printf "stopped at track %02d, %s into it, disc %s\n"
        tracks.(i).number
        (clock (final.position - Reader.track_start tracks.(i)))
        (clock final.position))

let () =
  let driver = ref "" and positional = ref [] in
  Arg.parse
    [
      ( "--driver",
        Arg.Set_string driver,
        "NAME libao driver, e.g. pulse, alsa, null" );
    ]
    (fun arg -> positional := arg :: !positional)
    usage;
  match !positional with
  | [ dir ] -> (
      Sys.catch_break true;
      try
        let reader = Reader.load dir in
        let driver =
          if !driver = "" then Ao.get_default_driver ()
          else Ao.find_driver !driver
        in
        let device =
          Ao.open_live ~bits:16 ~rate:44100 ~channels:2
            ~byte_format:`LITTLE_ENDIAN ~driver ()
        in
        Fun.protect
          ~finally:(fun () -> Ao.close device)
          (fun () -> play reader ~device)
      with
      | Ddp.Error msg | Sys_error msg ->
          prerr_endline ("error: " ^ msg);
          exit 1
      | Sys.Break -> exit 130)
  | _ ->
      prerr_endline usage;
      exit 2
