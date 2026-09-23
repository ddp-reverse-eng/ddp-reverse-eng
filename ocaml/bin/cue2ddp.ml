let usage = "cue2ddp [-m master-id] [-t] [-c] CUESHEET DIRECTORY"

let () =
  let master_id = ref "" and with_cdtext = ref false and with_cue = ref false and positional = ref [] in
  Arg.parse
    [
      ("-m", Arg.Set_string master_id, "ID master identifier (48 ASCII characters max)");
      ("--master-id", Arg.Set_string master_id, "ID same as -m");
      ("-t", Arg.Set with_cdtext, " include CD-Text");
      ("--add-cdtext", Arg.Set with_cdtext, " same as -t");
      ("-c", Arg.Set with_cue, " embed a cue sheet for IMAGE.DAT");
      ("--add-cuesheet", Arg.Set with_cue, " same as -c");
    ]
    (fun arg -> positional := arg :: !positional)
    usage;
  match List.rev !positional with
  | [ cue_path; dir ] -> (
      try Ddp.write ~master_id:!master_id ~with_cdtext:!with_cdtext ~with_cue:!with_cue ~cue_path ~dir ()
      with Ddp.Error msg | Ddp.Cue.Error msg | Sys_error msg ->
        prerr_endline ("error: " ^ msg);
        exit 1)
  | _ ->
      prerr_endline usage;
      exit 2
