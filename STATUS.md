# Status

Current step: **4 (differential experiments)**. First batch 002-010 done, see `spec/ddp2.md`. Step 1 (public research) is running in the background and will land in `docs/research.md`.
Next batch: CD-Text (`-t`), embedded cue (`-c`), a partial last sector, 3+ tracks, short track/pregap validation. Then step 5 for the remaining unknown fields (DDPID gaps, `DA71`, `17`).

Tools: `bin/exp exp/NNN-name` runs one experiment (folder holds input.cue + run.args); `bin/recs OUTDIR` prints records one per line for diffing; `bin/ddp` runs any ddptools binary through muvm + FEX (16k-page host).
Fresh checkout: `bin/fetch-tools` first.

## Log

- 2026-09-23: step 0 done (runner), step 2 done (`bin/mkwav`), step 3 done (`exp/001-baseline`).
- 2026-09-23: batch 1 (002-010): track/index/time, UPC, ISRC, master ID, flags, pregap, IMAGE.DAT layout. Output is deterministic.
