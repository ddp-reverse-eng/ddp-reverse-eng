module Reader = Ddp.Reader

let usage = "ddp-play [--driver NAME] [--buffer MS] DIRECTORY"
let chunk_sectors = 16
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
  | '\027' :: '[' :: 'A' :: rest -> Previous :: parse rest
  | '\027' :: '[' :: 'B' :: rest -> Next :: parse rest
  | '\027' :: '[' :: 'C' :: rest -> Seek (10 * fps) :: parse rest
  | '\027' :: '[' :: 'D' :: rest -> Seek (-10 * fps) :: parse rest
  | (' ' | 'k') :: rest -> Toggle :: parse rest
  | ('n' | '.') :: rest -> Next :: parse rest
  | ('p' | ',') :: rest -> Previous :: parse rest
  | 'f' :: rest -> Seek (10 * fps) :: parse rest
  | 'b' :: rest -> Seek (-10 * fps) :: parse rest
  | 'q' :: rest -> Quit :: parse rest
  | ('1' .. '9' as c) :: rest ->
      Goto (Char.code c - Char.code '0') :: parse rest
  | _ :: rest -> parse rest

(** [None] once stdin is closed, as with scripted keys. *)
let poll_keys ~timeout =
  match Unix.select [ Unix.stdin ] [] [] timeout with
  | [], _, _ -> Some []
  | _ -> (
      let buffer = Bytes.create 64 in
      match Unix.read Unix.stdin buffer 0 64 with
      | 0 -> None
      | n -> Some (parse (List.init n (Bytes.get buffer))))

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

type screen = { heading : string; summary : string; rows : string array }

(** Text is laid out in ISO 8859-1, one byte per character, then converted. *)
let screen reader disc =
  let utf8 = Ddp.Cdtext.to_utf8 in
  let flags (t : Reader.track) =
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
  {
    heading =
      utf8
        (describe (Reader.disc_text reader)
           ~default:(Filename.basename reader.dir));
    summary =
      Printf.sprintf "%d tracks, %s%s" (Array.length disc.tracks)
        (clock disc.total)
        (match Reader.catalog reader with
        | Some c -> "   UPC " ^ c
        | None -> "");
    rows =
      Array.mapi
        (fun n (t : Reader.track) ->
          Printf.sprintf "%02d  %s  %s %s" t.number
            (clock (track_length disc n))
            (utf8 (fit 48 (describe t.text ~default:"")))
            (flags t))
        disc.tracks;
  }

let render screen disc state =
  let i = current disc state.position in
  let track = disc.tracks.(i) in
  let buffer = Buffer.create 4096 in
  let line s = Buffer.add_string buffer (s ^ "\027[K\n") in
  line screen.heading;
  line screen.summary;
  line (String.make 72 '-');
  Array.iteri
    (fun n row ->
      line (if n = i then "\027[7m> " ^ row ^ "\027[0m" else "  " ^ row))
    screen.rows;
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
    "space play/pause   up/down: tracks   left/right: 10 s   1-9: track   q: \
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

type shared = {
  mutable state : state;
  lock : Mutex.t;
  resumed : Condition.t;  (** signalled on unpause and on quit *)
}
(** The audio thread owns the pace; the UI thread only reads and edits the
    state. *)

let locked shared f =
  Mutex.lock shared.lock;
  match f () with
  | result ->
      Mutex.unlock shared.lock;
      result
  | exception e ->
      Mutex.unlock shared.lock;
      raise e

let update shared commands =
  locked shared (fun () ->
      let before = shared.state in
      shared.state <- List.fold_left (fun s c -> c s) before commands;
      if (before.paused && not shared.state.paused) || shared.state.quit then
        Condition.broadcast shared.resumed)

(** Reads and plays chunk after chunk, so the device is never starved by the UI.
*)
let feed disc audio device shared =
  let buffer = Bytes.create (chunk_sectors * Ddp.Cd.sector_size) in
  let rec loop () =
    let next =
      locked shared (fun () ->
          while shared.state.paused && not shared.state.quit do
            Condition.wait shared.resumed shared.lock
          done;
          let s = shared.state in
          if s.quit then None
          else
            let count = min chunk_sectors (disc.total - s.position) in
            let position = s.position + count in
            shared.state <- { s with position; quit = position >= disc.total };
            Some (s.position, count))
    in
    match next with
    | None -> ()
    | Some (sector, count) ->
        let read = Reader.read_sectors audio ~sector buffer ~count in
        Ao.play device (Bytes.sub_string buffer 0 (read * Ddp.Cd.sector_size));
        loop ()
  in
  loop ()

let play reader ~device =
  let tracks = Array.of_list (Reader.tracks reader) in
  if tracks = [||] then raise (Ddp.Error "no tracks");
  let disc = { tracks; total = Reader.audio_sectors reader } in
  let screen = screen reader disc in
  let interactive = Unix.isatty Unix.stdout in
  let commands keys = List.map (fun key s -> apply disc s key) keys in
  let shared =
    {
      state =
        {
          position = Reader.track_start tracks.(0);
          paused = false;
          quit = false;
        };
      lock = Mutex.create ();
      resumed = Condition.create ();
    }
  in
  let audio = Reader.open_audio reader in
  Fun.protect
    ~finally:(fun () -> Reader.close_audio audio)
    (fun () ->
      with_raw_terminal (fun () ->
          (* Scripted keys are applied before any audio plays, so a run is repeatable. *)
          let open_stdin =
            match
              poll_keys ~timeout:(if Unix.isatty Unix.stdin then 0. else 1.)
            with
            | Some keys ->
                update shared (commands keys);
                true
            | None -> false
          in
          let feeder =
            Thread.create (fun () -> feed disc audio device shared) ()
          in
          let rec ui open_stdin =
            let open_stdin =
              if not open_stdin then (
                Thread.delay 0.1;
                false)
              else
                match poll_keys ~timeout:0.1 with
                | Some keys ->
                    update shared (commands keys);
                    true
                | None -> false
            in
            let state = locked shared (fun () -> shared.state) in
            if interactive then render screen disc state;
            if not state.quit then ui open_stdin
          in
          ui open_stdin;
          Thread.join feeder);
      let final = shared.state in
      let i = current disc final.position in
      Printf.printf "stopped at track %02d, %s into it, disc %s\n"
        tracks.(i).number
        (clock (final.position - Reader.track_start tracks.(i)))
        (clock final.position))

let () =
  let driver = ref "" and buffer_ms = ref 500 and positional = ref [] in
  Arg.parse
    [
      ( "--buffer",
        Arg.Set_int buffer_ms,
        "MS device buffer in milliseconds (default 500), for drivers that take \
         one" );
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
        let open_device options =
          Ao.open_live ~bits:16 ~rate:44100 ~channels:2
            ~byte_format:`LITTLE_ENDIAN ~options ~driver ()
        in
        (* pulse, alsa and oss take buffer_time; other drivers refuse unknown options. *)
        let device =
          try open_device [ ("buffer_time", string_of_int !buffer_ms) ]
          with _ -> open_device []
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
