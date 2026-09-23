# DDP 2.00 audio CD fileset

A description of the Disc Description Protocol (DDP) 2.00 fileset that carries a Red Book audio CD master, as written by DDP mastering tools and read by replication plants.

**Part I** describes the format, block by block. Where a point is uncertain it is marked ⚠ and linked to a note.
**Part II** holds the notes: evidence, the behaviour of the tools studied, and open questions.
Nothing here comes from DCA's specification; see [LEGAL.md](../LEGAL.md) and [N1](#n1).

**Contents**

- Part I: Format
  1. [Overview](#1-overview)
  2. [Conventions](#2-conventions)
  3. [DDPID: identifier](#3-ddpid-identifier)
  4. [DDPMS: map stream](#4-ddpms-map-stream)
  5. [PQ descriptor](#5-pq-descriptor)
  6. [Audio image](#6-audio-image)
  7. [CD-Text](#7-cd-text)
  8. [Constraints](#8-constraints)
  9. [Companion files](#9-companion-files)
- Part II: [Notes and comments](#part-ii-notes-and-comments)

---

# Part I: Format

## 1. Overview

A DDP fileset is a directory of files. Two have fixed names, `DDPID` and `DDPMS`. `DDPMS` names every other file.

```
DDPID          128 bytes    identifies the master
DDPMS          n × 128      one packet per stream; each names its file
 ├─ S0 PQ DESCR → SD, PQDESCR, ...   PQ descriptor: tracks, indexes, flags, ISRC, UPC
 ├─ S0 CDTEXT   → CDTEXT.BIN         CD-Text lead-in packs (optional)
 └─ D0 DA       → IMAGE.DAT          audio, 2352-byte sectors
```

A reader starts from `DDPMS`: the `D0` packet with CD mode `DA` gives the audio file, the `S0` packet with subcode `PQ DESCR` the PQ descriptor, and an `S0` packet with subcode `CDTEXT`, if any, the CD-Text.

Everything in `DDPID`, `DDPMS` and the PQ descriptor is fixed-width ASCII. The audio and CD-Text files are binary.

Example: a two-track master with a UPC, an ISRC, a track 2 pregap and CD-Text titles, as cue2ddp writes it (field by field in sections 3-5):

```
DDPID       DDP 2.000123456789012                                                                  CD
DDPMS  [0]  VVVMS0              90        CDTEXT                   00               17CDTEXT.BIN
DDPMS  [1]  VVVMS0             448        PQ DESCR                                  17SD
DDPMS  [2]  VVVMD0            1650                DA71     150                      17IMAGE.DAT
SD     [0]  VVVS0000  00000001              0123456789012
SD     [1]  VVVS0100  00000001  USABC1234567
SD     [2]  VVVS0101  00020001
SD     [3]  VVVS0200  00100001
SD     [4]  VVVS0201  00120001
SD     [5]  VVVSAA01  00220001
SD     [6]  VVVSAA01  00220001
```

## 2. Conventions

- Offsets are decimal, counted from 0. Sizes are in bytes.
- **Text fields** are ASCII, left-aligned and padded with spaces.
- **Number fields** are decimal ASCII, right-aligned. Both padding styles occur: spaces (`     900`) and zeros (`00000900`). A reader must accept both ([N6](#n6)).
- A field that is not set is all spaces. Records have no terminator and no line ends.
- **Time**: CD addresses count frames (sectors) at 75 per second. `MMSSFF` is minutes, seconds (0-59) and frames (0-74), two digits each; minutes go past 59, so the largest address is 99:59:74. Time 0 is the first sector of the audio image.
- **Sector**: 2352 bytes of audio, 1/75 s.

## 3. DDPID: identifier

One 128-byte record.

| Offset | Size | Name | Type | Content |
|--------|------|------|------|---------|
| 0 | 8 | DDPID | text | Level: `DDP 2.00` |
| 8 | 13 | UPC | text | Disc UPC/EAN (the media catalog number): 13-digit EAN-13, or 12-digit UPC-A left-aligned; blank when none ([N6](#n6)) |
| 21 | 8 | MSS | text | Map stream start; blank |
| 29 | 8 | MSL | text | Blank. ⚠ Meaning disputed ([N11](#n11)) |
| 37 | 1 | MED | text | Blank |
| 38 | 48 | MID | text | Master identifier, free text; does not reach the disc |
| 86 | 1 | BK | text | Book; blank for audio CD. ⚠ Sonoris writes `O` ([N6](#n6)) |
| 87 | 2 | TYPE | text | Disc type: `CD` |
| 89 | 1 | NSIDE | text | DVD only; blank |
| 90 | 1 | SIDE | text | DVD only; blank |
| 91 | 1 | NLAYER | text | DVD only; blank |
| 92 | 1 | LAYER | text | DVD only; blank |
| 93 | 2 | SIZ | number | Length of TXT; blank when there is no text. ⚠ Two writers put it at 94 ([N4](#n4)) |
| 95 | 33 | TXT | text | User text; does not reach the disc. ⚠ Two writers start it at 96 ([N4](#n4)) |

## 4. DDPMS: map stream

A sequence of 128-byte packets, one per stream. Each packet names its stream's file in DSI.

| Offset | Size | Name | Type | Content |
|--------|------|------|------|---------|
| 0 | 4 | MPV | text | Packet marker: `VVVM` |
| 4 | 2 | DST | text | Stream type: `D0` main data, `S0` subcode ([N12](#n12) lists others) |
| 6 | 8 | DSP | number | Stream pointer; blank |
| 14 | 8 | DSL | number | Stream length: sectors for `D0`, bytes for `S0` |
| 22 | 8 | DSS | number | Stream start sector; blank, or `0` for the first `D0` ([N6](#n6)) |
| 30 | 8 | SUB | text | Subcode kind of an `S0`: `PQ DESCR` or `CDTEXT`; blank for `D0` |
| 38 | 2 | CDM | text | CD mode of a `D0`: `DA` for audio; blank for `S0` |
| 40 | 1 | SSM | text | Source storage mode of a `D0`: `7`, complete 2352-byte sectors; blank for `S0`. ⚠ `0` is also seen ([N6](#n6)) |
| 41 | 1 | SCR | text | Scrambled flag of a `D0`: `0` or `1`. ⚠ Writers disagree ([N6](#n6)) |
| 42 | 4 | PRE1 | number | Blank |
| 46 | 4 | PRE2 | number | Sectors of track 1's pregap at the start of this `D0` stream, e.g. `150`; blank for `S0` |
| 50 | 4 | PST | number | Blank |
| 54 | 1 | MED | text | Blank |
| 55 | 2 | TRK | text | `00` on the CDTEXT packet, or blank ([N6](#n6)); otherwise blank |
| 57 | 2 | IDX | text | Blank |
| 59 | 12 | ISRC | text | Blank |
| 71 | 3 | SIZ | number | Width of DSI: `17` |
| 74 | 17 | DSI | text | File name of the stream |
| 91 | 1 | NEW | text | Blank ([N12](#n12)) |
| 92 | 4 | PRE1NXT | text | Blank |
| 96 | 8 | PAUSEADD | text | Blank |
| 104 | 9 | OFS | text | Blank |
| 113 | 15 | PAD | text | Blank |

Values per stream of an audio master:

| Field | PQ descriptor | CD-Text | Audio image |
|-------|---------------|---------|-------------|
| DST | `S0` | `S0` | `D0` |
| DSL | bytes (64 × packets) | bytes (18 × packs) | sectors |
| SUB | `PQ DESCR` | `CDTEXT` | blank |
| CDM, SSM, SCR | blank | blank | `DA`, `7`, `0` or `1` |
| PRE2 | blank | blank | track 1 pregap sectors |
| DSI | e.g. `SD`, `PQDESCR` | e.g. `CDTEXT.BIN` | e.g. `IMAGE.DAT` |

Rules:

- Exactly one `PQ DESCR` stream and at most one `CDTEXT` stream.
- An audio master has one `D0 DA` stream. ⚠ Several are possible (`IMAGE01.DAT`, `IMAGE02.DAT`), with their combination not established ([N8](#n8)).
- File names are free; only DDPID and DDPMS are fixed.
- cue2ddp writes the packets in the order CDTEXT, PQ, audio; HOFA writes the same order.

## 5. PQ descriptor

The Q-channel subcode of the program: one 64-byte packet per index, plus lead-in and lead-out.

| Offset | Size | Name | Type | Content |
|--------|------|------|------|---------|
| 0 | 4 | SPV | text | Packet marker: `VVVS` |
| 4 | 2 | Tk | text | Track: `00` lead-in, `01`-`99`, `AA` lead-out |
| 6 | 2 | I | text | Index: `00`-`99`; `01` for the lead-out |
| 8 | 8 | A-Time | number | Absolute time `MMSSFF`, right-aligned |
| 16 | 2 | C1 | text | Control and ADR, see below |
| 18 | 2 | C2 | text | Blank |
| 20 | 12 | ISRC | text | Track ISRC, on the track's first packet; blank otherwise |
| 32 | 13 | UPC | text | Disc UPC/EAN as in DDPID, on the lead-in packet at least ([N6](#n6)) |
| 45 | 19 | TXT | text | Comment; blank |

**C1** is two characters:

| Char | Content |
|------|---------|
| 0 | The Q control nibble in hexadecimal: bit 0 (`1`) pre-emphasis, bit 1 (`2`) digital copy permitted, bit 3 (`8`) four-channel audio. Bit 2 (data track) is never set for audio. So `0` none, `1` PRE, `2` DCP, `3` PRE+DCP, `8` 4CH, `9` PRE+4CH, `A` DCP+4CH, `B` all three. ⚠ `A` and `B` are disputed ([N7](#n7)) |
| 1 | `1` (ADR mode 1), or `S` for a track under SCMS copy protection |

The lead-in and lead-out carry `01`. A track's control is the same on all its packets.

**Packet sequence:**

1. The lead-in: `00`, index `00`, time `000000`, carrying the UPC.
2. For each track in order: its index `00` packet when it has a pregap, then index `01`, `02`, ... Track 1 always has an index `00` at time 0.
3. The lead-out: `AA`, index `01`, at the end of the audio, **written twice** ([N9](#n9)).

## 6. Audio image

The `D0 DA` stream's file (usually `IMAGE.DAT`) holds the whole program as raw CD audio, with no header:

| Unit | Size | Content |
|------|------|---------|
| sample | 2 | signed 16-bit little-endian |
| frame | 4 | left sample, then right sample |
| sector | 2352 | 588 frames, 1/75 s |
| file | DSL × 2352 | sectors 0 to DSL−1 |

- Sector *n* is at time *n* in the PQ descriptor: the image starts at 00:00:00.
- It starts with track 1's pregap, PRE2 sectors long and at least 150 (2 s). Mastering tools fill a pregap they insert with digital silence.
- It ends at the lead-out: DSL equals the lead-out's A-Time.
- A last partial sector is padded with digital silence.

## 7. CD-Text

The `CDTEXT` stream's file holds CD-Text as it is written in the lead-in, with no file header: a sequence of 18-byte packs.

| Offset | Size | Content |
|--------|------|---------|
| 0 | 1 | Pack type, see below |
| 1 | 1 | Track number of the string holding byte 4; `0` for the disc. For size information, the pack's position within it (0-2) |
| 2 | 1 | Sequence number, from 0 across all packs |
| 3 | 1 | Bit 7: double-byte characters (0). Bits 6-4: block (0). Bits 3-0: position of byte 4 in its string, capped at 15 |
| 4 | 12 | Payload |
| 16 | 2 | CRC-16/CCITT (polynomial 0x1021, initial 0) of bytes 0-15, inverted, big-endian |

**Pack types:**

| Type | Content |
|------|---------|
| `0x80` | Title |
| `0x81` | Performer |
| `0x82` | Songwriter |
| `0x83` | Composer |
| `0x84` | Arranger |
| `0x85` | Message |
| `0x86` | Disc identification ⚠ not studied |
| `0x87` | Genre ⚠ not studied |
| `0x8E` | UPC/EAN and ISRC ⚠ not studied |
| `0x8F` | Size information |

**Text types (0x80-0x85):**

- Types come in ascending order; a type is present when the disc or any track has that text.
- A type's strings follow each other: the disc's, then each track's, each ending with a NUL byte. A track without that text has an empty string. A string made of a single TAB stands for the previous track's string (public CD-Text documentation; no studied writer uses it).
- The strings are cut into 12-byte payloads; the type's last payload is padded with NUL bytes.
- Characters are ISO 8859-1 (character set 0).

**Size information (0x8F):** three packs whose payloads form 36 bytes:

| Offset | Size | Content |
|--------|------|---------|
| 0 | 1 | Character set: `0x00` ISO 8859-1 |
| 1 | 1 | First track |
| 2 | 1 | Last track |
| 3 | 1 | Copyright: `0` |
| 4 | 16 | Number of packs of each type `0x80` to `0x8F`, `0x8F` included (3) |
| 20 | 8 | Last sequence number of blocks 0-7 |
| 28 | 8 | Language of blocks 0-7: `0x09` English |

A block holds at most 256 packs, since the sequence number is one byte.

## 8. Constraints

A master that breaks these is not a valid Red Book audio CD, or is refused by the tools studied ([N2](#n2)):

| Rule | Detail |
|------|--------|
| Tracks | 1 to 99, numbered from 1 without gaps; each has an index `01` |
| Indexes | 0 to 99 per track, consecutive, times increasing |
| Track 1 | Starts at 00:00:00 with index `00`; its pregap (index `01` time) is at least 2 s |
| Track length | At least 4 s, from its index `01` to the next track's index `01` (or the lead-out) |
| Program | Lead-out at most 99:59:74 |
| Flags | DCP and SCMS exclude each other |
| UPC/EAN | 13-digit EAN-13 or 12-digit UPC-A; a UPC-A is the EAN-13 with a leading `0` dropped |
| ISRC | 12 characters, uppercase letters and digits |
| Master ID | At most 48 characters |
| CD-Text | At most 256 packs in the block |

## 9. Companion files

Not part of DDP, but delivered beside it and checked by plants and tools.

**Checksums.** cue2ddp writes both of these for DDPID, DDPMS, CDTEXT.BIN (when present), the PQ descriptor and the audio image, in that order:

| File | Format |
|------|--------|
| `CHECKSUM.MD5` | md5sum format: `<32 hex> *<name>`, LF line ends |
| `CHECKSUM.TXT` | `[CRC32 Checksum]`, then `<name>=<8 uppercase hex>` lines; CRC-32 as in zlib |

Other writers name the MD5 file differently ([N6](#n6)).

**Cue sheet.** cue2ddp can add `IMAGE.cue`, a CDRWin cue sheet for the audio image. It isn't listed in DDPMS or the checksum files. Its lines, LF-terminated:

```
CATALOG <UPC>
TITLE / PERFORMER / SONGWRITER / COMPOSER / ARRANGER / MESSAGE "<disc text>"
FILE "IMAGE.DAT" BINARY
  TRACK nn AUDIO
    TITLE ... "<track text>"
    ISRC <isrc>
    FLAGS PRE DCP 4CH SCMS
    INDEX nn MM:SS:FF
```

Only the lines that apply are written. Index times are absolute, and track 1 starts with `INDEX 00 00:00:00`.

---

# Part II: Notes and comments

<a id="n1"></a>
## N1. Method and evidence

- **Sources:** everything comes from black-box experiments with ddptools 1.1 (cue2ddp, ddpinfo, cdtinfo), from public information (`docs/research.md`), and from two filesets made by other software ([N6](#n6)).
- **Citations:** `[NNN]` cites an experiment in `exp/NNN-*`, with its input (`input.cue`, `run.args`), cue2ddp's output (`out/`) and log. `[name]` cites a reader experiment in `oracle/name/` ([N8](#n8)).
- **Field names and widths:** these come from `ddpinfo -e` (`exp/*/ddpinfo-e.txt`); offsets and values come from diffs between experiments. `bin/checkspec` checks the tables in sections 3-5 against real files.
- **Repeatability:** cue2ddp's output is byte-identical from run to run [001].
- **Evidence by section:**
  - DDPID [001][005][007][011]
  - DDPMS [001][002][009][011]
  - PQ descriptor [002][003][004][005][006][008][010][014][023][032]
  - audio image [001][009][013][027][028]
  - CD-Text [011][021][024][031][041][091]→[092]
  - constraints [015][016][020][022][026][029][030][034]-[043][079][081][083][084]
  - companion files [011][012][025]

<a id="n2"></a>
## N2. cue2ddp: accepted input and rejections

**Validation** (refused unless noted):

- DCP with SCMS [026]
- a track under 4 s, measured index `01` to index `01` [015][040][043]
- a track 1 pregap under 2 s [016]
- a first index not at 00:00:00 [020][022]
- a CATALOG not of 13 digits [035]; a wrong EAN check digit only warns [034]
- indexes out of sequence [036]
- a malformed ISRC [037]
- several FILE commands [038]
- a track without INDEX 01 [039]
- a master ID over 48 characters [042]
- an index at or past the end of the audio [083]
- cue times of 90 minutes or more [079]
- cue lines over 254 characters [080]

99 tracks and 99 indexes are accepted [029][030], and so are discs over 80 minutes [078].

**Input audio:**

- WAVE must be PCM (format tag 1), 16-bit, stereo, 44.1 kHz. Extensible headers are refused [044][048][049][051][052][053].
- Chunks may come in any order [045][046]. A RIFF size of 0 is refused [055].
- The data must be whole stereo frames [047][056][059].
- BINARY (raw little-endian) and MOTOROLA (raw big-endian) files give the same image as WAVE [027][028].
- When track 1 has no INDEX 00, 150 sectors of silence are prepended [001]. When it has one, nothing is added [009].

**Cue syntax:**

- Accepted: CRLF [060], tabs [062], blank lines [068], REM anywhere [066], unquoted file names [067] and one-digit numbers [071].
- A quoted argument runs to the last quote on the line [063]. An unquoted argument is its first word only [073].
- Commands must be uppercase: lowercase commands are ignored [061], and lowercase flags are dropped with a warning [069]. Unknown commands such as COMPOSER are ignored with a warning [070].
- Refused: a UTF-8 BOM [065], ISRC with dashes [072], PREGAP/POSTGAP [074][075], CATALOG inside a track [076].

**CD-Text:**

- Text comes from TITLE, PERFORMER and SONGWRITER only with `-t` [017]. It's copied byte for byte, so it must be ISO 8859-1 [031]: a UTF-8 cue sheet ends up garbled, `ö` read back as `Ã¶` [094].
- A CDTEXTFILE replaces them, copied byte for byte and only with `-t` [018][033]. A file with a 4-byte length header is refused [019]. Bad CRCs go unnoticed [082].

<a id="n3"></a>
## N3. cue2ddp writes corrupt output past two limits

- **Audio past 99:59:74:** it is accepted with only a warning, and the lead-out minutes are clamped to 99, which gives a wrong address [084].
- **CD-Text past 256 packs:** it is written with the sequence numbers and pack counts wrapped around [081].

The OCaml writer refuses both ([N10](#n10)).

<a id="n4"></a>
## N4. DDPID user text offset

- **ddpinfo:** reads SIZ at 93 and TXT at 95 [ddpid-text], as the public readers do (`docs/research.md`).
- **Sonoris and HOFA:** both leave 93 blank, write the length at 94-95 and start the text at 96. ddpinfo misreads that layout [ddpid-text-sonoris].
- **Which one DCA intends is unknown.** Two independent writers against one reader favours 94/96, which would make a 3-character SIZ field at 93. cue2ddp never writes the field.
- **What the reader does:** it accepts both layouts, and the writer writes no user text.

<a id="n5"></a>
## N5. How ddpinfo reads and exports

The `oracle/` cases are filesets cue2ddp never writes. `oracle/craft.py` builds each one from the OCaml writer's output, and then records how ddpinfo reads it.

- **Storage mode and scrambled flag:** SSM `0` and SCR `0` are accepted, and the exported audio doesn't change [storage-mode-0][scrambled-0].
- **Several `D0` streams:** they are listed, but the export refuses them ([N8](#n8)).
- **Export (`ddpinfo -w`):** it writes the image from track 1's index `01`, which leaves out the pregap, plus a cue sheet with times relative to that start [ddpid-text]. The OCaml reader's export matches it cue and PCM on every case where ddpinfo reports no error (`bin/check-oracle`).

<a id="n6"></a>
## N6. Other writers

Two filesets from other software:
- **[sonoris]:** Sonoris DDP Creator, a public sample (`docs/research.md`).
- **[hofa]:** HOFA CD-Burn.DDP.Master, a private master. Only structural facts about it are recorded here.

| Record | Field | cue2ddp | Sonoris | HOFA |
|---|---|---|---|---|
| DDPID | UPC | 13-digit EAN-13 | | a 12-digit UPC-A, left-aligned |
| DDPID | BK | blank | `O` | blank |
| DDPID | user text | none | length at 94, text at 96 | length at 94, text at 96 |
| DDPMS | numbers (DSL, SIZ) | space-padded | zero-padded | zero-padded |
| DDPMS | DSS of the first D0 | blank | `00000000` | `00000000` |
| DDPMS | SCR | `1` | `0` | `0` |
| DDPMS | TRK of CDTEXT | `00` | `00` | blank |
| DDPMS | PQ file name | `SD` | `PQDESCR` | `PQDESCR` |
| PQ | UPC | lead-in only | | every packet |
| PQ | lead-out | twice | twice | twice |
| checksums | MD5 file | `CHECKSUM.MD5`, LF | `MD5-Checksum.md5` | `MD5_CHECKSUM.MD5`, CRLF |

Both UPC forms name the same catalog number (EAN-13 = `0` + UPC-A), so they very likely coexist. The HOFA sample shows only that HOFA writes a UPC-A as given, not that it always uses 12 digits.

All three agree on CDM `DA`, SSM `7`, PRE2 `150`, C1 `01` for flagless tracks, and the time base. Distillery, an open-source writer, uses SSM `0` (`docs/research.md`).

HOFA's CDTEXT.BIN (title, performer, songwriter, composer, arranger) is byte-identical to what the OCaml encoder makes of the same strings. That confirms section 7 against an independent writer, including the 0x83 and 0x84 packs.

<a id="n7"></a>
## N7. Control values A and B

- **cue2ddp:** writes the control nibble in hexadecimal, so DCP with 4CH gives `A1`, and PRE, DCP and 4CH together give `B1` [006][025].
- **ddpinfo:** reads `0`-`9` and `0S`, but calls `A1` and `B1` an "invalid control byte", and then exports wrong flags [control-A1][control-B1][export-full].
- **Which is right is unknown.** One of the two tools is wrong. Four-channel audio is essentially never used.
- **What our tools do:** the OCaml writer keeps cue2ddp's output and warns, and the reader warns.

<a id="n8"></a>
## N8. Several audio streams

- A fileset may split the audio into several `D0` files [two-streams]. Sonoris uses a second stream, with a DSS start address, for a CD-Extra data session (`docs/research.md`).
- ddpinfo lists such streams but won't export them, with or without DSS [two-streams][two-streams-dss].
- The OCaml reader joins the `D0 DA` streams in DDPMS order. That is a choice, not an established rule.

<a id="n9"></a>
## N9. The doubled lead-out

cue2ddp, Sonoris and HOFA all write the final `AA 01` packet twice. The reason is unknown. It may be a convention that the sequence must end with a repeated packet. A reader should accept both one and two lead-out packets.

<a id="n10"></a>
## N10. OCaml writer: deliberate differences from cue2ddp

The writer in `ocaml/` produces cue2ddp's output byte for byte on every experiment cue2ddp accepts. Beyond that, it accepts or refuses input as follows. Each case has a marker in its experiment folder:
- `EXPECT`: the output must equal the named experiment's output.
- `ACCEPT`: the writer accepts what cue2ddp refuses, and there's no reference output.
- `REFUSE`: the writer refuses what cue2ddp writes corrupt.

- **Lossless audio conversion:**
  - extensible headers [044]
  - mono, duplicated to both channels with a warning [048]→[057]
  - 8-bit [053]→[058]
  - 24/32-bit integer and float, when every sample is exactly 16-bit [049][051]

  One inexact sample refuses the file [050].
- **UPC-A:** a 12-digit CATALOG is written as the equivalent EAN-13 with a leading `0`, as the cue2ddp manual advises users to do by hand [035]→[093].
- **Cue syntax:** commands, file types and flags are case-insensitive [061][069]→[077], a BOM is skipped [065], and there's no line length limit [080].
- **UTF-8 cue sheets:** the text of a cue sheet that is valid UTF-8 and not plain ASCII is converted to ISO 8859-1 [094]→[031]; a character outside ISO 8859-1 is refused [095]. FILE paths are left as they are.
- **Multiple FILE commands:** the files are joined in order, and each INDEX time counts from its own FILE, including a FILE between a track's indexes as EAC writes [085]→[086][087]→[003][088]→[002]. Every file but the last must end on a sector [089], and an index past the end of its file is refused [090].
- **CD-Text:** COMPOSER, ARRANGER and MESSAGE become packs 0x83-0x85 [070][091]→[092]. A CDTEXTFILE with bad CRCs gets a warning [082].
- **Refused instead of written corrupt:** [081][084] ([N3](#n3)).
- **Warnings:** control values `A`/`B` ([N7](#n7)).

<a id="n11"></a>
## N11. Open questions

- **Blank fields:** the meaning of MSS, MSL, MED, DSP, PRE1, PST, NEW, PRE1NXT, PAUSEADD and OFS, all blank in audio masters. MSL is either reserved or the map stream length (`docs/research.md`).
- **DDPID user text:** its offset ([N4](#n4)).
- **Disputed values:** SCR, and SSM `0` versus `7` ([N6](#n6)); control values `A`/`B` ([N7](#n7)).
- **Doubled lead-out:** why it's written twice ([N9](#n9)).
- **CD-Text types 0x86, 0x87 and 0x8E:** no studied writer produces them.
- **Several audio streams:** how they combine ([N8](#n8)).

<a id="n12"></a>
## N12. Codes beyond audio CD

From public readers (`docs/research.md`), for completeness:
- **DST:** `D1`-`D4`, `T0`-`T3`.
- **SUB:** `RW` subcode kinds.
- **CDM:** `00`, `10`, `2x` for data tracks.
- **SSM:** `0`-`8`.
- **NEW:** `S` marks a stream that begins a new session, as the Sonoris CD-Extra sample shows.

An audio master uses none of them.
