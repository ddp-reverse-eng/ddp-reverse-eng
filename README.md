# ddp-reverse

An open specification and an MIT-licensed OCaml writer for DDP 2.00 audio CD masters (the Disc Description Protocol filesets that CD plants accept for replication). Both come from black-box reverse engineering of the freely available [DDP Mastering Tools](http://ddp.andreasruge.de/): we run them on our own inputs and study what they write. See [LEGAL.md](LEGAL.md) for why this is lawful.

DDP® is a trademark of DCA, Inc. This project is not affiliated with or endorsed by DCA, Inc.

## Status

- `spec/ddp2.md`: every byte of DDPID, DDPMS, SD (PQ descriptor), IMAGE.DAT and CDTEXT.BIN as written by `cue2ddp` 1.1, plus its validation rules. Each fact cites the experiment that shows it.
- `ocaml/`: a `cue2ddp`-compatible writer. On all 33 experiments it produces output byte-identical to `cue2ddp`, and it rejects the same 13 invalid inputs.

Only what `cue2ddp` can produce is covered: one audio stream, Red Book audio, CD-Text block 0 in ISO 8859-1.

## Using the writer

Requires OCaml ≥ 5.1 and dune; no other dependencies.

```
cd ocaml
dune build
./_build/default/bin/cue2ddp.exe [-m MASTER-ID] [-t] [-c] album.cue out/
```

- `-m`: master identifier, up to 48 characters
- `-t`: include CD-Text, from the cue's TITLE/PERFORMER/SONGWRITER or a `CDTEXTFILE`
- `-c`: also write IMAGE.cue, a cue sheet for IMAGE.DAT

The cue sheet names one WAVE (44.1 kHz, 16-bit, stereo), BINARY or MOTOROLA file holding the whole program.

## Testing

`dune test` (from `ocaml/`) or `bin/compare` runs the writer on every experiment in `exp/` and compares the result with the recorded `cue2ddp` output. It needs neither the ddptools nor the audio, which it regenerates.

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
