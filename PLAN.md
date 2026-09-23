# DDP 2.0 writer: reverse-engineering plan

Target: DDP 2.00 audio CD masters (Red Book), writer side.
Reference tool: ddptools 1.1 (Andreas Ruge), `tools/ddptools-1.1/` (x86_64 ELF, not stripped, libc only).
Resume point: `STATUS.md`. Each step ends with a STATUS.md update, so work can stop after any step.

## Method

- Black box first: generate a cue/wav input, run `cue2ddp`, diff the output against a baseline. Change one variable per experiment.
- Cross-check with `ddpinfo -e` (expert view), which names every field it reads.
- Disassemble only to settle what diffs leave ambiguous (field names, validation rules, checksums).
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
5. Binary analysis for gaps: DDPID/DDPMS/PQ record builders in `cue2ddp`.
6. Write `spec/ddp2.md` field by field.
7. Clean implementation + validation: `ddpinfo` accepts our output; byte-identical to `cue2ddp` for all experiments.
