let md5_file = "CHECKSUM.MD5"
let crc32_file_name = "CHECKSUM.TXT"
let crc32_header = "[CRC32 Checksum]"

let write_file path contents =
  Out_channel.with_open_bin path (fun oc ->
      Out_channel.output_string oc contents)

let crc32_table =
  Array.init 256 (fun n ->
      let c = ref n in
      for _ = 1 to 8 do
        c := if !c land 1 <> 0 then 0xEDB88320 lxor (!c lsr 1) else !c lsr 1
      done;
      !c)

let crc32_file path =
  In_channel.with_open_bin path (fun ic ->
      let buffer = Bytes.create 65536 in
      let rec loop crc =
        match In_channel.input ic buffer 0 (Bytes.length buffer) with
        | 0 -> crc lxor 0xFFFFFFFF
        | n ->
            let crc = ref crc in
            for i = 0 to n - 1 do
              crc :=
                crc32_table.(!crc lxor Bytes.get_uint8 buffer i land 0xFF)
                lxor (!crc lsr 8)
            done;
            loop !crc
      in
      loop 0xFFFFFFFF)

let write ~dir names =
  let path name = Filename.concat dir name in
  write_file (path md5_file)
    (String.concat ""
       (List.map
          (fun n ->
            Printf.sprintf "%s *%s\n" (Digest.to_hex (Digest.file (path n))) n)
          names));
  write_file (path crc32_file_name)
    (String.concat ""
       ((crc32_header ^ "\n")
       :: List.map
            (fun n -> Printf.sprintf "%s=%08X\n" n (crc32_file (path n)))
            names))

let lines path =
  In_channel.with_open_bin path In_channel.input_all
  |> String.split_on_char '\n' |> List.map String.trim
  |> List.filter (( <> ) "")

(** Entries as (file name, expected checksum) from cue2ddp's two formats. *)
let entries ~dir =
  let path name = Filename.concat dir name in
  let md5_files =
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun f ->
        String.lowercase_ascii (Filename.extension f) = ".md5")
    |> List.sort compare
  in
  let md5 =
    md5_files
    |> List.concat_map (fun md5_file ->
        List.filter_map
          (fun line ->
            match String.index_opt line ' ' with
            | Some i ->
                let name =
                  String.trim
                    (String.sub line (i + 1) (String.length line - i - 1))
                in
                let name =
                  if String.starts_with ~prefix:"*" name then
                    String.sub name 1 (String.length name - 1)
                  else name
                in
                Some (`Md5, name, String.lowercase_ascii (String.sub line 0 i))
            | None -> None)
          (lines (path md5_file)))
  in
  let crc32 =
    if Sys.file_exists (path crc32_file_name) then
      List.filter_map
        (fun line ->
          match String.index_opt line '=' with
          | Some i when line <> crc32_header ->
              Some
                ( `Crc32,
                  String.sub line 0 i,
                  String.uppercase_ascii
                    (String.sub line (i + 1) (String.length line - i - 1)) )
          | _ -> None)
        (lines (path crc32_file_name))
    else []
  in
  md5 @ crc32

let verify ~dir =
  List.map
    (fun (kind, name, expected) ->
      let path = Filename.concat dir name in
      let actual =
        if not (Sys.file_exists path) then None
        else
          Some
            (match kind with
            | `Md5 -> Digest.to_hex (Digest.file path)
            | `Crc32 -> Printf.sprintf "%08X" (crc32_file path))
      in
      let label = match kind with `Md5 -> "MD5" | `Crc32 -> "CRC32" in
      (label, name, actual = Some expected))
    (entries ~dir)
