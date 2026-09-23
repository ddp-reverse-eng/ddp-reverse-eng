# Status

Current step: **5 (binary analysis)** for the unknown fields in spec "Open questions". Step 4 batches 1-2 done (exp 002-019).

Tools: `bin/exp exp/NNN-name` runs one experiment (folder holds input.cue + run.args); `bin/recs OUTDIR` prints records one per line for diffing; `bin/ddp` runs any ddptools binary through muvm + FEX (16k-page host).
Fresh checkout: `bin/fetch-tools` first.

## Log

- 2026-09-23: step 0 done (runner), step 2 done (`bin/mkwav`), step 3 done (`exp/001-baseline`).
- 2026-09-23: batch 1 (002-010): track/index/time, UPC, ISRC, master ID, flags, pregap, IMAGE.DAT layout. Output is deterministic.
- 2026-09-23: batch 2 (011-019): CD-Text (cue and CDTEXTFILE), embedded cue, padding, length rules.
