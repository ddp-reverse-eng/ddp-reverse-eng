# ddp-reverse

[![CI](https://github.com/ddp-reverse-eng/ddp-reverse-eng/actions/workflows/ci.yml/badge.svg)](https://github.com/ddp-reverse-eng/ddp-reverse-eng/actions/workflows/ci.yml)

An open specification and an MIT-licensed OCaml writer for DDP 2.00 audio CD masters (the Disc Description Protocol filesets that CD plants accept for replication). Both come from black-box reverse engineering of the freely available [DDP Mastering Tools](http://ddp.andreasruge.de/): we run them on our own inputs and study what they write. See [LEGAL.md](LEGAL.md) for why this is lawful.

DDP® is a trademark of DCA, Inc. This project is not affiliated with or endorsed by DCA, Inc.

## Status

- `spec/ddp2.md`: every byte of DDPID, DDPMS, SD (PQ descriptor), IMAGE.DAT and CDTEXT.BIN as written by `cue2ddp` 1.1, plus its validation rules. Each fact cites the experiment that shows it.
- `ocaml/`: a `cue2ddp`-compatible writer. It produces output byte-identical to `cue2ddp` on every experiment `cue2ddp` accepts, and rejects what it rejects, except where `spec/ddp2.md` documents a deliberate difference (lossless audio conversion, multiple files, refusing inputs `cue2ddp` would write corrupt).

Output is what `cue2ddp` produces: one audio stream, Red Book audio, CD-Text block 0 in ISO 8859-1.

## Install

Requires OCaml ≥ 4.14 and dune; no other dependencies.

```
opam pin add ddp git+https://github.com/ddp-reverse-eng/ddp-reverse-eng.git --subpath ocaml
```

or, from a checkout: `cd ocaml && dune build`, then use `_build/default/bin/cue2ddp.exe` and `_build/default/bin/ddpread.exe`.

## Writing a master

```
ddpwrite [-m MASTER-ID] [-t] [-c] album.cue out/
```

- `-m`: master identifier, up to 48 characters
- `-t`: include CD-Text, from the cue's TITLE/PERFORMER/SONGWRITER/COMPOSER/ARRANGER/MESSAGE or a `CDTEXTFILE`
- `-c`: also write IMAGE.cue, a cue sheet for IMAGE.DAT

The cue sheet names one or more WAVE, BINARY or MOTOROLA files, joined in order into the program. WAVE files must be 44.1 kHz; mono, 8-bit, 24/32-bit and float files are converted only when no sample changes, and refused otherwise. Every file but the last must end on a CD frame boundary.

## Reading a master

```
ddpread DIR                       summary and checks
ddpread --export out.wav DIR      audio from track 1 INDEX 01 plus out.cue, as ddpinfo -w
```

Checks report errors (the fileset breaks the format), warnings (valid but risky) and notes (fields another writer fills differently); the exit status is 1 when there is an error.

## Testing

`dune test` (from `ocaml/`) runs `bin/compare`, which runs the writer on every experiment in `exp/`, compares the result with the recorded `cue2ddp` output and reads it back with `ddpread`, and `bin/check-oracle`, which compares `ddpread`'s export with `ddpinfo`'s. Neither needs the ddptools: test audio is regenerated with python3. The tests need the repository checkout, not only the `ocaml/` package.

## Repository layout

| Path | Content |
|------|---------|
| `spec/ddp2.md` | the format |
| `exp/NNN-name/` | one experiment: `input.cue`, `run.args`, `cue2ddp`'s output in `out/`, its log, and `REJECTED` when it refused the input |
| `docs/research.md` | public information about DDP, with sources |
| `bin/` | `fetch-tools` downloads ddptools; `ddp` runs them (through muvm + FEX on aarch64 Linux); `exp` runs an experiment; `mkwav` makes test audio; `recs` prints records for diffing; `compare` and `checkspec` are the checks |
| `PLAN.md`, `STATUS.md` | the working plan and where it stands |

## Adding an experiment

1. Create `exp/NNN-name/input.cue` and `exp/NNN-name/run.args` (`FRAMES [cue2ddp options]`). `bin/mkwav` writes audio whose samples encode their own position.
2. Run `bin/fetch-tools` once, then `bin/exp exp/NNN-name`. This needs x86-64 Linux, or `muvm` with FEX on aarch64.
3. Diff against the baseline with `diff <(bin/recs exp/001-baseline/out) <(bin/recs exp/NNN-name/out)`.
4. Record the finding in `spec/ddp2.md`, then run `bin/compare`.

## License

MIT, see [LICENSE](LICENSE). The ddptools binaries and manuals are not part of this repository.
