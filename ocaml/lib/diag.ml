exception Error of string

let error fmt = Printf.ksprintf (fun msg -> raise (Error msg)) fmt
