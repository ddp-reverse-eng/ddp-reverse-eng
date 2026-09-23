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
| CDTEXT.BIN | 18 per pack | with `-t`; see CD-Text below |
| IMAGE.cue | text | with `-c`; `FILE "IMAGE.DAT" BINARY` cue sheet, LF line ends. Not in DDPMS, not in checksum files [012] |
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

Common layout (all records seen so far):

| Off | Len | Value | Evidence |
|-----|-----|-------|----------|
| 0 | 4 | `VVVM` | [001] |
| 4 | 2 | `S0` = subcode stream, `D0` = data stream | [001] |
| 6..? | | spaces | |
| ?..21 | ≤8 | length, right-aligned: bytes for S0 (= SD size), sectors for D0 (= IMAGE.DAT / 2352) | [001][002][008] |
| 30 | ≤8 | subcode stream kind: `PQ DESCR` (SD), `CDTEXT` (CDTEXT.BIN) | [001][011] |
| 38 | 4 | `DA71` (D0 only), meaning ? | [001] |
| ?..49 | | D0: sectors of track 1 pregap at the start of IMAGE.DAT (150 by default, 225 with INDEX 00 at 0 and INDEX 01 at 3 s) | [001][009] |
| 55 | 2 | `00` on the CDTEXT record only, meaning ? | [011] |
| 72 | 2 | `17` (meaning ?, same on all records) | [001] |
| 74 | ≤? | file name | [001] |

Record order: CDTEXT (S0, when present), SD (S0), then IMAGE.DAT (D0) [011].

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

Raw 16-bit little-endian stereo PCM, the wav data copied as-is [001]. If track 1 does not start with INDEX 00, cue2ddp prepends 150 sectors of zeros as a pregap [001]; with INDEX 00 in the file, nothing is added [009]. A last partial sector is padded with zeros to 2352 bytes [013].

## CD-Text

CDTEXT.BIN is plain CD-Text: 18-byte packs (type, track, sequence, block/char, 12 text bytes, CRC), no file header [011]. CRC is CRC-16/CCITT (poly 0x1021, init 0) over the first 16 bytes, inverted, big-endian [011]. This is the public MMC/Red Book lead-in format, not DDP-specific.
Pack types seen: 0x80 title, 0x81 performer, 0x82 songwriter, 0x8f size info [011].
From the cue: disc and track TITLE/PERFORMER/SONGWRITER, encoded as ISO 8859-1. Without `-t`, TITLE etc. are ignored [017].
`CDTEXTFILE` is copied byte for byte and overrides TITLE etc. [018]; a file with the common 4-byte length header is rejected [019].

## Validation rules seen

- DCP and SCMS together on one track: rejected [006].
- Track shorter than 4 s: rejected [015].
- Track 1 pregap shorter than 2 s: rejected [016].
- Other rules from the manual, not tested yet: CATALOG must be 13 digits with a valid EAN check digit; one FILE only; INDEX 01 required per track.

## Open questions

- DDPID bytes 21..37, 86, 89..127; DDPMS `DA71`, `17`, CDTEXT `00`, exact field widths.
- Why the lead-out packet is written twice.
- Byte order of the pack sequence and 0x8f contents: follow the public CD-Text spec when implementing.
