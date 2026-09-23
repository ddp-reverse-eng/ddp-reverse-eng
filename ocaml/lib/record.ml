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

module Ddpid = struct
  let size = 128
  let level = text 0 8
  let upc = text 8 13
  let master_id = text 38 48
  let disc_type = text 87 2
end

module Map = struct
  let size = 128
  let version = text 0 4
  let stream_type = text 4 2
  let length = number 14 8
  let subcode = text 30 8
  let cd_mode = text 38 2
  let storage_mode = text 40 1
  let scrambled = text 41 1
  let pregap2 = number 46 4
  let track = text 55 2
  let name_size = number 71 3
  let name = text 74 17
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
end
