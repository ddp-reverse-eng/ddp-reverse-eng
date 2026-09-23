# DDP 2.00 audio CD fileset (as written by cue2ddp 1.1)

Inferred from black-box experiments; `[NNN]` cites `exp/NNN-*`. Field names and widths come from `ddpinfo -e` (`exp/*/ddpinfo-e.txt`), offsets and values from diffs.
All metadata files are ASCII: numbers right-aligned and space padded, strings left-aligned and space padded, unset fields are all spaces. No terminators, no newlines.
The same input always gives byte-identical output [001].

## Files

| File | Record size | Content |
|------|-------------|---------|
| DDPID | 128, one record | identifier |
| DDPMS | 128 per packet | map: one packet per stream |
| SD | 64 per packet | PQ subcode descriptor |
| IMAGE.DAT | 2352 per sector | audio |
| CDTEXT.BIN | 18 per pack | with `-t`; see CD-Text below |
| IMAGE.cue | text | with `-c`; `FILE "IMAGE.DAT" BINARY` cue sheet, LF line ends. Not in DDPMS, not in checksum files [012] |
| CHECKSUM.MD5 / CHECKSUM.TXT | text | md5sum-style `hash *NAME`; `[CRC32 Checksum]` INI with `NAME=HEX` uppercase. Lists DDPID, DDPMS, [CDTEXT.BIN,] SD, IMAGE.DAT. Not part of DDP. |

## DDPID

| Off | Len | Name | cue2ddp value | Evidence |
|-----|-----|------|---------------|----------|
| 0 | 8 | DDPID | `DDP 2.00` | [001] |
| 8 | 13 | UPC | CATALOG, else spaces | [005] |
| 21 | 8 | MSS | spaces | [011] |
| 29 | 8 | MSL | spaces | [011] |
| 37 | 1 | MED | space | [011] |
| 38 | 48 | MID | master ID (`-m`), else spaces | [007] |
| 86 | 1 | BK | space | [011] |
| 87 | 2 | TYPE | `CD` | [001] |
| 89 | 1 | NSIDE | space | [011] |
| 90 | 1 | SIDE | space | [011] |
| 91 | 1 | NLAYER | space | [011] |
| 92 | 1 | LAYER | space | [011] |
| 93 | 2 | SIZ | spaces | [011] |
| 95 | 33 | TXT | spaces | [011] |

## DDPMS

| Off | Len | Name | CDTEXT packet | SD packet | IMAGE.DAT packet | Evidence |
|-----|-----|------|---------------|-----------|------------------|----------|
| 0 | 4 | MPV | `VVVM` | `VVVM` | `VVVM` | [001] |
| 4 | 2 | DST | `S0` | `S0` | `D0` | [001][011] |
| 6 | 8 | DSP | | | | |
| 14 | 8 | DSL | length in bytes | length in bytes | length in sectors | [001][002][011] |
| 22 | 8 | DSS | | | | |
| 30 | 8 | SUB | `CDTEXT` | `PQ DESCR` | | [011] |
| 38 | 2 | CDM | | | `DA` | [011] |
| 40 | 1 | SSM | | | `7` | [011] |
| 41 | 1 | SCR | | | `1` | [011] |
| 42 | 4 | PRE1 | | | | |
| 46 | 4 | PRE2 | | | track 1 pregap sectors at the start of IMAGE.DAT (150 by default) | [001][009] |
| 50 | 4 | PST | | | | |
| 54 | 1 | MED | | | | |
| 55 | 2 | TRK | `00` | | | [011] |
| 57 | 2 | IDX | | | | |
| 59 | 12 | ISRC | | | | |
| 71 | 3 | SIZ | ` 17` | ` 17` | ` 17` | [011] |
| 74 | 17 | DSI | `CDTEXT.BIN` | `SD` | `IMAGE.DAT` | [011] |
| 91 | 1 | NEW | | | | |
| 92 | 4 | PRE1NXT | | | | |
| 96 | 8 | PAUSEADD | | | | |
| 104 | 9 | OFS | | | | |
| 113 | 15 | PAD | | | | |

Blank cells are spaces. SIZ is 17, the width of DSI.
Packet order: CDTEXT (when present), SD, IMAGE.DAT [011].

## SD (PQ descriptor)

| Off | Len | Name | Value | Evidence |
|-----|-----|------|-------|----------|
| 0 | 4 | SPV | `VVVS` | [001] |
| 4 | 2 | Tk | `00` lead-in, `01`..`99`, `AA` lead-out | [001][002] |
| 6 | 2 | I | index | [001][004] |
| 8 | 8 | A-Time | 2 spaces + MMSSFF, relative to IMAGE.DAT start (75 frames/s) | [004][008] |
| 16 | 2 | C1 | Q control/ADR byte in hex: control PRE=1, DCP=2, 4CH=8, ADR=1 (all three flags: `B1`). SCMS replaces the ADR digit with `S` (`0S`). | [006][010] |
| 18 | 2 | C2 | spaces | [006] |
| 20 | 12 | ISRC | on the track's index 00 packet, or its first packet | [005] |
| 32 | 13 | UPC | on the lead-in packet | [005] |
| 45 | 19 | TXT | spaces | [005] |

Packet sequence:
1. `00 00` at 00:00:00 (lead-in).
2. For each track: an index 00 packet if the track has a pregap (track 1 always has one), then index 01, 02... [002][003][004][014]
3. `AA 01` at the end time, **written twice** [001]-[014].

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

- Meaning of the DDPMS fields: DSP, DSS, CDM `DA`, SSM `7`, SCR `1`, PRE1, PST, NEW, PRE1NXT, PAUSEADD, OFS (for a writer, cue2ddp's values are enough).
- Why the lead-out packet is written twice.
- How cue2ddp builds the 0x8f size-info packs and fills a partial last pack: follow the public CD-Text spec when implementing, and compare with [011].
