let usage = "ddp-read [--export FILE.wav] DIRECTORY"

let print_summary (r : Ddp.Reader.t) =
  Printf.printf "DDP 2.00  UPC %s  master ID %s%s\n"
    (if r.id.upc = "" then "-" else r.id.upc)
    (if r.id.master_id = "" then "-" else r.id.master_id)
    (if r.id.user_text = "" then "" else "  text " ^ r.id.user_text);
  List.iter
    (fun (s : Ddp.Fileset.stream) ->
      Printf.printf "%s %-8s %-17s %d %s\n" s.stream_type
        (if s.subcode = "" then s.cd_mode else s.subcode)
        s.name s.length
        (if s.stream_type = "D0" then "sectors" else "bytes"))
    r.streams;
  List.iter
    (fun (p : Ddp.Fileset.pq) ->
      Printf.printf "  %s %02d  %s  %s%s\n" p.track p.index
        (Ddp.Cd.format_msf ~separator:":" p.time)
        p.control
        (if p.isrc = "" then "" else "  ISRC " ^ p.isrc))
    r.pq

let () =
  let export = ref "" and positional = ref [] in
  Arg.parse
    [
      ( "--export",
        Arg.Set_string export,
        "FILE.wav write the audio and a cue sheet" );
    ]
    (fun arg -> positional := arg :: !positional)
    usage;
  match !positional with
  | [ dir ] -> (
      try
        let reader = Ddp.Reader.load dir in
        if !export <> "" then Ddp.Reader.export reader ~wav:!export
        else print_summary reader;
        let issues = Ddp.Reader.check reader in
        List.iter
          (fun (severity, message) ->
            let label =
              match severity with
              | Ddp.Reader.Error -> "error"
              | Warning -> "warning"
              | Note -> "note"
            in
            Printf.eprintf "%s: %s\n" label message)
          issues;
        if List.exists (fun (s, _) -> s = Ddp.Reader.Error) issues then exit 1
      with Ddp.Error msg | Sys_error msg ->
        prerr_endline ("error: " ^ msg);
        exit 1)
  | _ ->
      prerr_endline usage;
      exit 2
