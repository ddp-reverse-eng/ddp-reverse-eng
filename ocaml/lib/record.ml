type field = { offset : int; width : int; align : [ `Left | `Right ] }

exception Overflow of string * int

let text offset width = { offset; width; align = `Left }
let number offset width = { offset; width; align = `Right }

let make size values =
  let data = Bytes.make size ' ' in
  List.iter
    (fun (field, value) ->
      let length = String.length value in
      if length > field.width then raise (Overflow (value, field.width));
      let start =
        match field.align with
        | `Left -> field.offset
        | `Right -> field.offset + field.width - length
      in
      Bytes.blit_string value 0 data start length)
    values;
  Bytes.to_string data

let get field record = String.sub record field.offset field.width

module Ddpid = struct
  let size = 128
  let level = text 0 8
  let upc = text 8 13
  let master_id = text 38 48
  let disc_type = text 87 2
  let user_text_length = number 93 2
  let user_text = text 95 33

  let all =
    [
      ("DDPID", level);
      ("UPC", upc);
      ("MSS", text 21 8);
      ("MSL", text 29 8);
      ("MED", text 37 1);
      ("MID", master_id);
      ("BK", text 86 1);
      ("TYPE", disc_type);
      ("NSIDE", text 89 1);
      ("SIDE", text 90 1);
      ("NLAYER", text 91 1);
      ("LAYER", text 92 1);
      ("SIZ", user_text_length);
      ("TXT", user_text);
    ]
end

module Map = struct
  let size = 128
  let version = text 0 4
  let stream_type = text 4 2
  let length = number 14 8
  let start = number 22 8
  let subcode = text 30 8
  let cd_mode = text 38 2
  let storage_mode = text 40 1
  let scrambled = text 41 1
  let pregap2 = number 46 4
  let track = text 55 2
  let name_size = number 71 3
  let name = text 74 17

  let all =
    [
      ("MPV", version);
      ("DST", stream_type);
      ("DSP", text 6 8);
      ("DSL", length);
      ("DSS", start);
      ("SUB", subcode);
      ("CDM", cd_mode);
      ("SSM", storage_mode);
      ("SCR", scrambled);
      ("PRE1", number 42 4);
      ("PRE2", pregap2);
      ("PST", number 50 4);
      ("MED", text 54 1);
      ("TRK", track);
      ("IDX", text 57 2);
      ("ISRC", text 59 12);
      ("SIZ", name_size);
      ("DSI", name);
      ("NEW", text 91 1);
      ("PRE1NXT", text 92 4);
      ("PAUSEADD", text 96 8);
      ("OFS", text 104 9);
      ("PAD", text 113 15);
    ]
end

module Pq = struct
  let size = 64
  let version = text 0 4
  let track = text 4 2
  let index = text 6 2
  let time = number 8 8
  let control = text 16 2
  let isrc = text 20 12
  let upc = text 32 13

  let all =
    [
      ("SPV", version);
      ("Tk", track);
      ("I", index);
      ("A-Time", time);
      ("C1", control);
      ("C2", text 18 2);
      ("ISRC", isrc);
      ("UPC", upc);
      ("TXT", text 45 19);
    ]
end
