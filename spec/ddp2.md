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
| IMAGE.cue | text | with `-c`; cue sheet for IMAGE.DAT, see below. Not in DDPMS, not in checksum files [012] |
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
| 8 | 8 | A-Time | 2 spaces + MMSSFF, relative to IMAGE.DAT start (75 frames/s); minutes go past 59 [032] | [004][008] |
| 16 | 2 | C1 | Q control/ADR byte in hex: control PRE=1, DCP=2, 4CH=8, ADR=1 (all three flags: `B1`). SCMS replaces the ADR digit with `S` (`0S`). | [006][010] |
| 18 | 2 | C2 | spaces | [006] |
| 20 | 12 | ISRC | on the track's first packet (index 00 when it has a pregap) | [005][023] |
| 32 | 13 | UPC | on the lead-in packet | [005] |
| 45 | 19 | TXT | spaces | [005] |

Packet sequence:
1. `00 00` at 00:00:00 (lead-in).
2. For each track: an index 00 packet if the track has a pregap (track 1 always has one), then index 01, 02... [002][003][004][014]
3. `AA 01` at the end time, **written twice** [001]-[014].

Flags only affect the track's packets, not lead-in or lead-out [006]. Tracks without a pregap have no index 00 packet [002].

## IMAGE.DAT

Raw 16-bit little-endian stereo PCM, the wav data copied as-is [001]. BINARY input (raw little-endian) and MOTOROLA input (raw big-endian, byte-swapped on copy) give the same IMAGE.DAT [027][028]. If track 1 does not start with INDEX 00, cue2ddp prepends 150 sectors of zeros as a pregap [001]; with INDEX 00 in the file, nothing is added [009]. A last partial sector is padded with zeros to 2352 bytes [013].

## Input audio (cue2ddp)

- WAVE: only format tag 1 (PCM), 16-bit, 2 channels, 44100 Hz [044][048][049][051][052][053]. Extensible headers (0xFFFE) are refused even for 16-bit PCM [044].
- Chunks may come in any order and unknown chunks are skipped [045][046]. A RIFF size of 0 is refused [055].
- The data size must be whole stereo frames (multiple of 4), for WAVE and BINARY alike [047][056][059]; missing data chunk refused [054].

## Cue sheet syntax (cue2ddp)

- Accepted: CRLF line ends [060], tabs and repeated spaces [062], blank lines and trailing whitespace [068], REM lines anywhere [066], an unquoted FILE name [067], one-digit track, index and minute numbers [071].
- A quoted argument runs to the last double quote of the line, so it may contain quotes [063]; `TITLE ""` is an empty string [064]; an unquoted argument is its first word only [073].
- Commands must be uppercase: lowercase commands are ignored, leaving no TRACK [061]. Lowercase flags are dropped with a warning, so the master loses them [069]. Unknown commands such as COMPOSER are ignored with a warning [070].
- Refused: a UTF-8 BOM [065], an ISRC with dashes [072], PREGAP and POSTGAP [074][075], CATALOG inside a track [076].

## Limits (cue2ddp)

- Discs over 80 minutes are accepted [078]. Cue times with 90 or more minutes are refused as malformed [079]; an index at or past the end of the audio is refused [083].
- Audio longer than 99:59:74 is accepted, but the lead-out minutes are clamped to 99 (a wrong address) with only a warning [084].
- Cue lines are limited to 254 characters [080].
- CD-Text past 256 packs is written with the one-byte sequence number and pack counts wrapped, which is invalid CD-Text [081].
- A CDTEXTFILE with wrong pack CRCs is copied as-is, without a warning [082].

## Writer extensions (OCaml writer only)

Where cue2ddp refuses an input that converts to 16-bit stereo without changing any sample, the OCaml writer converts it and must produce the same fileset as the equivalent 16-bit stereo input (`EXPECT` in the experiment):
extensible headers [044], mono duplicated to both channels with a warning [048]→[057], 8-bit [053]→[058], 24/32-bit integer and 32/64-bit float whose samples are all exactly 16-bit [049][051]. A single inexact sample refuses the whole file [050]. Sample rates other than 44.1 kHz, more than two channels and compressed formats are refused [052].
Cue sheets: commands, file types, track modes and flags are case-insensitive [061]→[001], [069]→[077]; a UTF-8 BOM is skipped [065]→[001]. Unknown commands warn and are ignored, as in cue2ddp [070].
Limits: no cue line length limit [080]; a disc past 99:59:74 [084] or CD-Text needing more than 256 packs [081] is refused instead of written corrupt; wrong CD-Text CRCs in a CDTEXTFILE warn [082].
Experiment markers: `EXPECT` (must equal the named experiment's output), `ACCEPT` (accepted beyond cue2ddp, no reference), `REFUSE` (refused where cue2ddp writes a broken fileset).

## IMAGE.cue

LF line ends. `CATALOG`, disc TITLE/PERFORMER/SONGWRITER, `FILE "IMAGE.DAT" BINARY`, then per track: `  TRACK nn AUDIO`, text lines, `    ISRC`, `    FLAGS` (order PRE DCP 4CH SCMS), `    INDEX` lines with absolute times, track 1 starting with `INDEX 00 00:00:00` [025].

## CD-Text

CDTEXT.BIN is plain CD-Text: 18-byte packs (type, track, sequence, block/char, 12 text bytes, CRC), no file header [011]. CRC is CRC-16/CCITT (poly 0x1021, init 0) over the first 16 bytes, inverted, big-endian [011]. This is the public MMC/Red Book lead-in format, not DDP-specific.
Pack types seen: 0x80 title, 0x81 performer, 0x82 songwriter, 0x8f size info [011].
Text packs: for each type in that order, the disc string then each track's string, each NUL-terminated, cut into 12-byte payloads; the last payload of a type is zero-padded [011].
A type is written when the disc or any track sets it; tracks without it get an empty string [021]. A type nobody sets is left out [021].
Pack header: byte 1 is the track owning the payload's first byte, byte 3 that byte's position in its string, capped at 15; the NUL counts as a position [021][024]. Block 0, single-byte characters. Sequence numbers run over all packs [011].
Size info (3 packs of type 0x8f, header byte 1 = 0, 1, 2): 36 bytes: character set 0 (ISO 8859-1), first track, last track, copyright 0, pack count per type 0x80..0x8f (0x8f counts 3), last sequence number of block 0 at byte 20, language 0x09 (English) at byte 28 [011][021][024].
From the cue: disc and track TITLE/PERFORMER/SONGWRITER; the cue's bytes are copied as-is, so the cue must be ISO 8859-1 [031]. A field set only on a track still gets an empty disc string [041]. Without `-t`, TITLE etc. are ignored [017].
`CDTEXTFILE` is copied byte for byte and overrides TITLE etc. [018], but only with `-t` [033]; a file with the common 4-byte length header is rejected [019].

## Validation rules seen

- DCP and SCMS together on one track: rejected [026].
- Track shorter than 4 s, measured from its INDEX 01 to the next track's INDEX 01 (or the end), not to the next INDEX 00: rejected [015][040][043].
- Track 1 pregap shorter than 2 s: rejected [016].
- Track 1's first index (00 or 01) not at 00:00:00: rejected [020][022].
- CATALOG not 13 digits: rejected [035]. A wrong EAN check digit only warns and is written anyway [034].
- Index numbers out of sequence (01 then 03): rejected [036].
- ISRC not 12 uppercase letters/digits: rejected [037].
- More than one FILE: rejected [038].
- Track without INDEX 01: rejected [039].
- Master ID over 48 characters: rejected [042].
- 99 tracks and 99 indexes are accepted [029][030].

## Open questions

- Meaning of the DDPMS fields: DSP, DSS, CDM `DA`, SSM `7`, SCR `1`, PRE1, PST, NEW, PRE1NXT, PAUSEADD, OFS (for a writer, cue2ddp's values are enough).
- Why the lead-out packet is written twice.
