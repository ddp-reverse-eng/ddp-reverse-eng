# DDP 2.0 writer: reverse-engineering plan

Target: DDP 2.00 audio CD masters (Red Book), writer side.
Reference tool: ddptools 1.1 (Andreas Ruge), `tools/ddptools-1.1/` (x86_64 ELF, not stripped, libc only).
Resume point: `STATUS.md`. Each step ends with a STATUS.md update, so work can stop after any step.

## Method

- Black box first: generate a cue/wav input, run `cue2ddp`, diff the output against a baseline. Change one variable per experiment.
- Cross-check with `ddpinfo -e` (expert view), which names every field it reads.
- Black box only: no disassembly (see LEGAL.md). `ddpinfo -e` gave the field names.
- Spec notes (`spec/ddp2.md`) cite the experiment or address that proves each field. An implementation is written later from the spec alone.

## Layout

- `exp/NNN-name/`: `input.cue`, `NOTES.md`, `out/` (DDP files; `IMAGE.DAT` and wav git-ignored, regenerable)
- `spec/ddp2.md`: the format as inferred
- `docs/`: tool manuals, public research (`docs/research.md`)

## Steps

0. Runner: `bin/ddp` (muvm + FEX, since the host kernel uses 16k pages).
1. Public research: DDP 2.0 facts from forums, open-source readers, public DCA material -> `docs/research.md`.
2. Fixture generator: script writing silence/pattern wav + cue from a short description.
3. Baseline: 1 track, 2 s pregap, minimal length. Inventory output files, hexdump each.
4. Differential experiments (one per dir):
   a. track count 1/2/3, track lengths
   b. pregap length, index 00/01/02+
   c. ISRC, UPC/EAN, master ID (`-m`?)
   d. flags: pre-emphasis, copy permit, 4ch, SCMS
   e. CD-Text from cue, then from binary CD-Text file
   f. checksum files (MD5/CRC32)
   g. audio content: confirm IMAGE.DAT is raw PCM byte order/offset
5. ~~Binary analysis~~: dropped, the project stays black-box (LEGAL.md).
6. Write `spec/ddp2.md` field by field.
7. Clean OCaml implementation + validation: `ddpinfo` accepts our output; byte-identical to `cue2ddp` for all experiments.

## Phase 2 (agreed 2026-09-23)

Steps run in order; each ends with a commit and a STATUS.md update.

8. Input robustness, black box against cue2ddp, then our writer:
   a. WAV variants: extensible format, fmt/data order, extra chunks, odd data size, mono, 8/24/32-bit, float, other rates. Our policy: normalize only when lossless (header-only differences, mono duplicated to stereo, deeper samples that are exactly 16-bit), refuse otherwise.
   b. Cue syntax: CRLF, lowercase commands, tabs, quotes inside titles, empty strings, BOM, REM lines, whitespace variants.
   c. Limits: > 80 min, 99:59:74, long CD-Text strings, CDTEXTFILE with bad CRC.
9. Multi-FILE cue sheets (our extension; cue2ddp refuses): files joined into one IMAGE.DAT, INDEX times relative to their file.
10. Extended CD-Text (composer, arranger, message, genre, disc ID, closed info, UPC/ISRC packs): encode from public CD-Text documentation, check with `cdtinfo` and with `ddpinfo` via CDTEXTFILE; confirm with the HOFA image.
11. Reader-side oracle: craft DDPID/DDPMS/SD files (user text, MSL, multiple D0 streams) and record how `ddpinfo` parses them.
12. OCaml DDP reader: parse and validate a fileset against the spec, export cue + wav. Tested by round trip on every experiment, the Sonoris sample and the HOFA image.
13. opam package and CI running `dune build` and `dune test`.
