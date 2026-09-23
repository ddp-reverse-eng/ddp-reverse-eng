# DDP 2.00 audio CD fileset (as written by cue2ddp 1.1)

Inferred from black-box experiments; `[NNN]` cites `exp/NNN-*`. Offsets are 0-based decimal byte offsets.
All metadata files are ASCII: numbers right-aligned and space padded, strings left-aligned and space padded, unused bytes are spaces. No terminators, no newlines.
Every run with the same input gives byte-identical output [001].

## Files

| File | Record size | Content |
|------|-------------|---------|
| DDPID | 128, one record | identifier |
| DDPMS | 128 per record | map: one record per stream |
| SD | 64 per record | PQ subcode descriptor |
| IMAGE.DAT | 2352 per sector | audio |
| CDTEXT.BIN | ? | with `-t` (not yet examined) |
| IMAGE.CUE | text | with `-c` (not yet examined); outside the DDP proper |
| CHECKSUM.MD5 / CHECKSUM.TXT | text | md5sum-style `hash *NAME`; `[CRC32 Checksum]` INI with `NAME=HEX` uppercase. Not part of DDP. |

## DDPID

| Off | Len | Value | Evidence |
|-----|-----|-------|----------|
| 0 | 8 | `DDP 2.00` level | [001] |
| 8 | 13 | UPC/EAN (CATALOG), spaces when absent | [005] |
| 21 | 17 | ? spaces | |
| 38 | 48 | master ID (`-m`), spaces when absent | [007] |
| 86 | 1 | ? space | |
| 87 | 2 | `CD` | [001] |
| 89 | 39 | ? spaces | |

## DDPMS

Common layout (both records seen so far):

| Off | Len | Value | Evidence |
|-----|-----|-------|----------|
| 0 | 4 | `VVVM` | [001] |
| 4 | 2 | `S0` = subcode stream, `D0` = data stream | [001] |
| 6..? | | spaces | |
| ?..21 | ≤8 | length, right-aligned: bytes for S0 (= SD size), sectors for D0 (= IMAGE.DAT / 2352) | [001][002][008] |
| 30 | 8 | `PQ DESCR` (S0 only) | [001] |
| 38 | 4 | `DA71` (D0 only), meaning ? | [001] |
| ?..49 | | D0: sectors of track 1 pregap at the start of IMAGE.DAT (150 by default, 225 with INDEX 00 at 0 and INDEX 01 at 3 s) | [001][009] |
| 72 | 2 | `17` (meaning ?, same on both records) | [001] |
| 74 | ≤? | file name | [001] |

Record order: S0 (SD) first, then D0 (IMAGE.DAT).

## SD (PQ descriptor)

| Off | Len | Value | Evidence |
|-----|-----|-------|----------|
| 0 | 4 | `VVVS` | [001] |
| 4 | 2 | track: `00` lead-in, `01`..`99`, `AA` lead-out | [001][002] |
| 6 | 2 | index | [001][004] |
| 8 | 2 | spaces | |
| 10 | 6 | MMSSFF time relative to IMAGE.DAT start (75 frames/s) | [004][008] |
| 16 | 1 | control nibble, hex: PRE=1, DCP=2, 4CH=8 (all three: `B`) | [006] |
| 17 | 1 | `1` (ADR?), `S` when SCMS | [010] |
| 20 | 12 | ISRC, on the track's first packet | [005] |
| 32 | 13 | UPC/EAN, on the lead-in packet | [005] |

Packet sequence:
1. `00 00` at 00:00:00 (lead-in).
2. For each track: an index 00 packet if the track has a pregap (track 1 always has one), then index 01, 02... [002][003][004]
3. `AA 01` at the end time, **written twice** [001]-[009].

Flags only affect the track's packets, not lead-in or lead-out [006]. Tracks without a pregap have no index 00 packet [002].

## IMAGE.DAT

Raw 16-bit little-endian stereo PCM, the wav data copied as-is [001]. If track 1 does not start with INDEX 00, cue2ddp prepends 150 sectors of zeros as a pregap [001]; with INDEX 00 in the file, nothing is added [009]. A wav that is not a whole number of sectors is still written as whole sectors [008] (padding not yet checked).

## Validation rules seen

- DCP and SCMS together on one track: rejected [006].

## Open questions

- DDPID bytes 21..37, 86, 89..127; DDPMS `DA71`, `17`, exact field widths.
- Why the lead-out packet is written twice.
- CD-Text (`-t`): CDTEXT.BIN and its DDPMS record. Embedded cue (`-c`).
- Padding of a partial last sector; a track shorter than 4 s; a pregap under 2 s.
