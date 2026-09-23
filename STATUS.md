# Status

Current step: **7 (OCaml implementation)** in `ocaml/`: byte-identical to cue2ddp on 33 experiments, same rejections on 13 (`bin/compare`). Next: tidy the OCaml code (mli files, tests in dune), a README; optionally cross-check `ddpinfo` against our output for inputs cue2ddp cannot express.

Tools: `bin/exp exp/NNN-name` runs one experiment (folder holds input.cue + run.args); `bin/recs OUTDIR` prints records one per line for diffing; `bin/compare` diffs the OCaml writer against every experiment; `bin/checkspec` checks the spec tables against real output; `bin/ddp` runs any ddptools binary through muvm + FEX (16k-page host).
Fresh checkout: `bin/fetch-tools` first.

## Log

- 2026-09-23: step 0 done (runner), step 2 done (`bin/mkwav`), step 3 done (`exp/001-baseline`).
- 2026-09-23: batch 1 (002-010): track/index/time, UPC, ISRC, master ID, flags, pregap, IMAGE.DAT layout. Output is deterministic.
- 2026-09-23: batch 2 (011-019): CD-Text (cue and CDTEXTFILE), embedded cue, padding, length rules.
- 2026-09-23: `ddpinfo -e` gives official field names/widths for DDPID, DDPMS, SD; spec rewritten, checked by `bin/checkspec`. bin/ddp fixed: muvm parsed --help itself, args now go through a file.
- 2026-09-23: exp 020-026 (first-index rule, ISRC placement, CD-Text missing/long fields, full IMAGE.cue). OCaml writer in `ocaml/`, byte-identical on all experiments; compare harness checked with a planted difference.
- 2026-09-23: exp 027-043 (BINARY/MOTOROLA input, 99 tracks/indexes, >60 min, Latin-1 CD-Text, validation rules; track length is INDEX 01 to INDEX 01). OCaml writer matches all. Added LICENSE (MIT) and LEGAL.md; project is black-box only, step 5 dropped.
