# Status

Current step: **7 (OCaml implementation)** can start: every byte cue2ddp writes is now named and located. Step 5 (disassembly) is optional, only for the meaning of constant DDPMS fields and the doubled lead-out; `ddpinfo -e` already gave all field names and widths.

Tools: `bin/exp exp/NNN-name` runs one experiment (folder holds input.cue + run.args); `bin/recs OUTDIR` prints records one per line for diffing; `bin/checkspec` checks the spec tables against real output; `bin/ddp` runs any ddptools binary through muvm + FEX (16k-page host).
Fresh checkout: `bin/fetch-tools` first.

## Log

- 2026-09-23: step 0 done (runner), step 2 done (`bin/mkwav`), step 3 done (`exp/001-baseline`).
- 2026-09-23: batch 1 (002-010): track/index/time, UPC, ISRC, master ID, flags, pregap, IMAGE.DAT layout. Output is deterministic.
- 2026-09-23: batch 2 (011-019): CD-Text (cue and CDTEXTFILE), embedded cue, padding, length rules.
- 2026-09-23: `ddpinfo -e` gives official field names/widths for DDPID, DDPMS, SD; spec rewritten, checked by `bin/checkspec`. bin/ddp fixed: muvm parsed --help itself, args now go through a file.
