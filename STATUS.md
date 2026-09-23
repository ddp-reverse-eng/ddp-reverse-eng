# Status

Current step: **4 (differential experiments)**. Step 1 (public research) is running in the background and will land in `docs/research.md`.

Run tools with `bin/ddp <tool> args...` (muvm + FEX; the host has a 16k-page kernel). Each call boots a microVM (~seconds).
Fresh checkout: `bin/fetch-tools` first.

## Log

- 2026-09-23: ddptools 1.1 x86_64 + manuals downloaded; plan written.
- 2026-09-23: step 0 done. `bin/ddp` wraps muvm, forwarding stdout/stderr and exit code (checked: rc 1 on a missing cue, 0 on --version).
- 2026-09-23: step 2 done (`bin/mkwav`). Step 3 done: `exp/001-baseline`. Output is fixed-width ASCII; the manual lists the file set.
