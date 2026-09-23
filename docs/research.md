# DDP 2.00 (audio CD) — public-source research

Clean-room notes, collected 2026-09-23. Everything here is a fact with a source tag. Layout tables are
restated in our own words; no third-party code is copied. Offsets are 0-based and lengths are in bytes.
All descriptor fields are space-padded ASCII.

## Sources

| Tag | URL | What it is |
|---|---|---|
| [ddplib] | https://github.com/NonStaticEu/ddplib (`src/main/java/com/suntriprecords/ddp/{common,v101,v20}`) | Java reader, GPL-3.0, 2011–2020. Author says it was written against the DCA 1.01/2.0 spec |
| [xld] | https://github.com/gmw/xld/blob/master/XLD/XLDDDPParser.m (mirror of svn.code.sf.net/p/xld) | XLD (tmkk, 2009) Obj-C DDP reader. The mirror carries no licence, only "All rights reserved" |
| [mattcarp] | https://github.com/mattcarp/ddp-lib/blob/master/ddp_lib.js | JS analyser/validator, 2015, "all rights reserved". Comment cites "DDP Spec v2.0 page 23" |
| [distillery] | https://github.com/GarageDeveloper/audio-distillery/blob/main/src-tauri/ddp-fileset/src/lib.rs | Rust DDP 2.00 writer, MIT, 2026. Says it was cross-checked against independent readers |
| [cdda2img] | https://github.com/HomerSlated/cdda2img/blob/main/src/cdda2img/ddp_reader.py | Python reader, GPL-3.0, 2026. Its docs say it took its layouts from ddplib |
| [pastebin] | https://pastebin.com/vgJdxepj | Python 2 script "ddp-to-kunaki", reverse-engineered from a real DDP. Includes a hexdump |
| [ddptools] | http://ddp.andreasruge.de/ plus `cue2ddp.html` and `ddpinfo.html` | DDP Mastering Tools 1.1 (2018): closed binaries, "Licensed from DCA" |
| [sonoris] | https://web.archive.org/web/20151001044016/http://www.sonorissoftware.com/files/TestDDP.zip | **A real DDP 2.00 fileset** made by Sonoris DDP Creator (2011). We dumped it locally (see §6) |
| [gateway] | https://web.archive.org/web/20140206193919/http://www.gatewaymastering.com/pdf/DDP_Images.pdf | Pressing-plant intake guide |
| [dca-faq] | http://www.dcainc.com/support/faqs/index.html ("What is DDPi?") | DCA's own FAQ |
| [dca-lic] | http://www.dcainc.com/products/ddplicense/ | DCA licence page |
| [dca-la] | http://www.dcainc.com/support/documentation/docs/DDPLA1x2x.pdf | DCA licence agreement for DDP 1.x–2.10, Rev. 02/2008 |
| [loc] | https://www.loc.gov/preservation/digital/formats/fdd/fdd000630.shtml | Library of Congress format description |
| [wiki] | https://en.wikipedia.org/wiki/Disc_Description_Protocol | Wikipedia |
| [reaper1] | https://forum.cockos.com/archive/index.php/t-78922.html (read via web.archive.org) | REAPER DDP export thread, 2011 (author "Sergenious") |
| [reaper2] | https://forum.cockos.com/archive/index.php/t-78922-p-2.html (read via web.archive.org) | Page 2 of the same thread (2012), with posts from the ddptools author ("anrug") |
| [gearspace] | https://gearspace.com/board/mastering-forum/758771-extract-wavs-ddpi-files.html | Returned 403 to us. We only have the search-engine snippet |

## 1. File set composition and naming

| Fact | Source |
|---|---|
| Minimum set: DDPID, DDPMS, a subcode (PQ) descriptor, and one or more `.DAT` audio images | [wiki], [ddptools] |
| DCA's DDPi definition: DDPID (mandatory), DDPMS (mandatory), PQ_DESCR (listed as *optional*), and one or more Image.dat files (mandatory). DDPi covers Red Book CD-DA and two-session Blue Book Enhanced CD, and is "fully compliant with DCA's DDP 1.0 and 2.0" | [dca-faq] |
| "DDPi" is Universal Music's name for a DDP set stored on random-access media | [dca-faq], [ddptools] |
| Only the names **DDPID** and **DDPMS** are fixed. The PQ file and image file names "must be determined from the DDPMS file". Examples seen: `DDPPQ`, `PQ_DESCR`, `SD`, `PQDESCR` for PQ, and `IC01.TRK`, `IMAGE.DAT`, `IMAGE01.DAT` for images | [gateway], [ddptools] (cue2ddp names its PQ file `SD`), [sonoris] (`PQDESCR`), [pastebin] (`PQ_DESCR`) |
| "all file names of all DDP files are fix", so the only reliable way to name a set is its Master ID. The ddptools author means cue2ddp's own output | [ddptools] |
| The DSI (file name) field is 17 characters. REAPER silently truncates longer names | [xld], [ddplib], REAPER forum search snippet |
| CD-Text is carried as a binary Sony-style lead-in R–W pack file, usually `CDTEXT.BIN`. The DDPMS entry that declares it is `S0` with SUB=`CDTEXT` | [ddptools], [sonoris], [xld], [distillery] |
| XLD falls back to `CDTEXT.BIN` when DDPMS does not declare CD-Text | [xld] |
| Multiple image files are allowed: one per session ([sonoris] has IMAGE01/IMAGE02), or one per track (GEAR writes `TRACKnn.DAT`) | [sonoris], [cdda2img] |
| An optional arbitrary text file is allowed and has no effect on replication. cue2ddp uses one to embed `IMAGE.CUE` | [wiki], [ddptools] |
| Checksums are **not part of DDP**. The ddptools author had seen "4–5 different flavours" | [reaper2] (anrug), [ddptools] |
| Checksum names seen: `CHECKSUM.MD5` (md5sum) and `CHECKSUM.TXT` (CRC32) from cue2ddp; `MD5-Checksum.md5` (`<md5> *<file>`) from Sonoris; `Checksum.chk` from plants. ddpinfo reads the md5sum, Pyramix, Sequoia, SADiE, Sonoris, DSP Quattro and Wave Editor formats | [ddptools], [sonoris], [gateway] |
| Proposed CRC32 `CHECKSUM.TXT` shape: comment lines, `Version=1.01`, then `<file>=<crc32 hex8>` | [ddplib] README |

## 2. DDPID: 128 bytes, one packet

`PACKET_LENGTH = 128` [ddplib]. The file is exactly 128 bytes in [sonoris].

| Off | Len | Field | Meaning / observed | Source |
|---|---|---|---|---|
| 0 | 8 | DDP level | `DDP 1.01`, `DDP 2.00`, `DDP 2.10` (DVD) | [ddplib] DdpLevel, [sonoris] |
| 8 | 13 | UPC/EAN | Blank if none. [sonoris] has `0123456789104` | [ddplib], [mattcarp], [sonoris] |
| 21 | 8 | MSS map stream start | Blank for random-access media or sequential tape, depending on the source | [ddplib] comment, [distillery] |
| 29 | 8 | MSL | "Reserved" [ddplib], [mattcarp]; "map stream length in bytes" [distillery]; blank in [sonoris] | conflict |
| 37 | 1 | MED media number | Blank when there is a single input medium | [ddplib] |
| 38 | 48 | MID master ID | Free text, not written to the disc | [ddplib], [ddptools] (cue2ddp `-m`, up to 48 chars) |
| 86 | 1 | BK book specifier | ddplib: "the spec says it should be empty". [sonoris] writes `O` | [ddplib], [sonoris] |
| 87 | 2 | TY disc type | `CD` or `DV` | [ddplib], [mattcarp], [sonoris] |
| 89 | 1 | NSIDE | DVD only, blank for CD | [ddplib], [mattcarp] |
| 90 | 1 | SIDE | as above | [ddplib] |
| 91 | 1 | NLAYER | as above | [ddplib] |
| 92 | 1 | LAYER | as above | [ddplib] |
| 93 | 4 | (DVD only) direction of translation, replicate size, security-scrambling status and mode | ddplib reads these only when TY=`DV` | [ddplib] |
| 93 | 2 | TXTLEN user-text length (CD) | "blank or ≤ 33 (CD) / 29 (DVD)" | [ddplib], [distillery] |
| 95 | 33 | TXT user text (CD) | Not written to the disc | [ddplib], [mattcarp] |

**DDP 1.01 DDPID:** fields 0–85 are the same, then TXTLEN at 86 (≤ 40) and TXT from 88 [ddplib v101].

**Confidence / conflicts:**
- Offsets 0–92 agree across [ddplib], [mattcarp] and [distillery], and match [sonoris]. Confidence is high.
- MSL meaning is disputed: reserved versus map-stream length.
- The user-text position is off by one. In [sonoris], byte 93 is blank, `09` sits at 94–95 and 9 characters of text start at 96, which suggests TXTLEN is at 94. [ddplib], [mattcarp] and [distillery] all put TXTLEN at 93 and TXT at 95. This is unresolved.
- Sonoris writes BK=`O`, which contradicts "empty". The disc is an Enhanced CD, so `O` may be a book code. This is our inference, not a fact.
- [cdda2img] accepts any `DDP 2.` prefix and hard-codes the file names instead of reading DDPMS.

## 3. DDPMS map stream: N × 128-byte packets

Every packet starts with `VVVM`. XLD rejects the file on any other prefix [xld], [ddplib], [pastebin].

| Off | Len | Field | Meaning (per [ddplib] comments unless noted) |
|---|---|---|---|
| 0 | 4 | MPV | `VVVM` |
| 4 | 2 | DST data stream type | `D0` main data, `D2` lead-in, `D3` lead-out, `D4` fill (2.00), `D1` ISO (1.01 only), `T0` volume/track/index text, `T1` commentary, `T2` customer info, `T3` ITTS (2.00), `S0` subcode |
| 6 | 8 | DSP data stream pointer | Exact sector number on disc-based direct-access media, SMPTE-based on tape. Blank in all file sets we saw |
| 14 | 8 | DSL data stream length | **Sectors** for D* streams, **bytes** for S*/T* streams ([ddplib], [mattcarp], confirmed in [sonoris]) |
| 22 | 8 | DSS data stream start | Physical sector address as decimal ASCII. Blank means "record in order of appearance". [sonoris]: `00000000` for session 1 and `00024705` for session 2. [distillery] leaves it blank |
| 30 | 8 | SUB subcode descriptor | `PQ DESCR`, `CDTEXT` (2.00), `RW24XX/XI/PI/PX`, `RW18XX`, `WR24..`, `WR18XX` (2.00). 1.01 has `01RSTUVW` and `02RSTUVW` instead. Blank on D0 packets |
| 38 | 2 | CDM CD mode | `DA` CD-DA, `00`, `10` (Mode 1), `20`, `21`, `22`, `2B`, `2I`, `2R`, `2X`, `2G`. Blank for S/T streams |
| 40 | 1 | SSM source storage mode | `0` user data only, `1` 2332, `2` 2336, `3` 2340, `4` 2352 (interleaved Form 1/2), `6` incomplete 2352, `7` complete 2352, `8` complete 2352 plus R–W (2.00 only) |
| 41 | 1 | SCR scrambled | `0` or `1`, blank for S/T |
| 42 | 4 | PRE1 | Pregap part 1 included in the stream |
| 46 | 4 | PRE2 | Pregap part 2 (pause) included in the stream. [sonoris] and [distillery] both write right-aligned ` 150` on audio D0 |
| 50 | 4 | PST | Postgap included in the stream |
| 54 | 1 | MED | Media number |
| 55 | 2 | TRK | `00`–`99`, `AA` for lead-out. [sonoris] writes `00` on the CDTEXT S0 packet |
| 57 | 2 | IDX | Blank for PQ S0 and T* streams |
| 59 | 12 | ISRC | Blank for S/T and lead-in/lead-out |
| 71 | 3 | DSI size | Always `017` in practice ([pastebin] treats it as a constant) |
| 74 | 17 | DSI data stream identifier | File name, left-aligned and space-padded |
| 91 | 1 | NEW | 2.00 only. [sonoris] writes `S` on the second-session D0, so it plausibly marks a new session (our inference) |
| 92 | 4 | PRE1NXT | 2.00 only: pregap-1 of the next track included |
| 96 | 8 | PAUSEADD | 2.00 only: number of pause blocks to add |
| 104 | 9 | OFS | 2.00 only: starting file offset |
| 113 | 15 | pad | |

**DDP 1.01:** bytes 0–90 are the same and 91–127 are padding [ddplib v101]. [xld] declares the same 128-byte struct with the same 2.00 tail names.

**How readers use it:** they pick the D0 packet with CDM=`DA` (XLD refuses more than one audio D0), the S0 packet with SUB=`PQ DESCR`, and the S0 packet with SUB=`CDTEXT`, and take each file name from the DSI [xld], [mattcarp], [pastebin]. XLD skips `(150 − DSS) × 2352` bytes when DSS < 150, so audio starts at 00:02:00 [xld].

**Observed in [sonoris] (Enhanced CD):**
```
S0 DSL=235   SUB=CDTEXT   TRK=00 DSI=CDTEXT.BIN
S0 DSL=704   SUB=PQ DESCR        DSI=PQDESCR
D0 DSL=13455 DSS=0     CDM=DA SSM=7 SCR=0 PRE2=150 DSI=IMAGE01.DAT
D0 DSL=225   DSS=24705 CDM=10 SSM=0 SCR=0 PRE2=150 DSI=IMAGE02.DAT NEW=S
```
IMAGE01 is 13455 × 2352 bytes. IMAGE02 is 225 × 2048 bytes, which is Mode 1 user-data-only (SSM 0).

**Confidence / conflicts:**
- Offsets 0–90 agree across four independent readers ([ddplib], [xld], [mattcarp], [pastebin]) and match [sonoris]. Confidence is high.
- The 2.00 tail (91–127) comes from [ddplib] and [xld], and [mattcarp] matches. It is barely exercised in real data. Confidence is medium.
- SSM for audio differs: Sonoris uses `7`, [distillery] uses `0`. Both mean 2352-byte sectors for CD-DA. We do not know which one DCA expects.
- DSS for D0 differs: `00000000` (Sonoris) versus blank ([distillery]).
- DSL for S0 is the byte length of the file in both cases.

## 4. PQ descriptor: N × 64-byte packets

The file name comes from the DSI. Every packet starts with `VVVS` [ddplib], [xld], [mattcarp], [pastebin].

| Off | Len | Field | Meaning / observed |
|---|---|---|---|
| 0 | 4 | SPV | `VVVS` |
| 4 | 2 | TRK | `00` lead-in, `01`–`99`, `AA` lead-out |
| 6 | 2 | IDX | `00`, `01`, … (lead-out uses `01`) |
| 8 | 2 | HRS | Reserved. Blank in [sonoris] and [distillery], `00` in [pastebin] |
| 10 | 2 | MIN | Decimal minutes |
| 12 | 2 | SEC | Decimal seconds |
| 14 | 2 | FRM | Decimal frames (1/75 s) |
| 16 | 2 | CB1 | [ddplib]: first char is the control nibble, second char is `1` for a normal entry or `S` for SCMS. Observed `01`, `41` (data track), `0S` [pastebin]. [distillery] calls it "Control/ADR" |
| 18 | 2 | CB2 | Reserved, blank |
| 20 | 12 | ISRC | Per [ddplib], valid only on the first entry of each track > 0 |
| 32 | 13 | UPC/EAN | Only one per stream, recommended in the first packet [ddplib]. [sonoris] and [distillery] put it on the 00/00 lead-in packet |
| 45 | 19 | TXT | User comment, not written to the disc |

**Time base (from [sonoris]):** MSF counts from the start of the DSS=0 image. Track 1 INDEX 00 is at 00:00:00 and INDEX 01 at 00:02:00. Lead-out `AA` is at 02:59:30, which is 13455 sectors, exactly the end of IMAGE01. The session-2 track INDEX 00 is at 05:29:30, which is 24705 sectors and equals that D0's DSS. [distillery] uses the same convention: "absolute disc MSF (pause included)".

**Packet sequence in [sonoris]:**
```
00/00 00:00:00 CB 01 UPC=0123456789104        (lead-in)
01/00 00:00:00 ISRC=USABC1100001 ; 01/01 00:02:00 (no ISRC)
02/01 01:02:09 ISRC ; 03/01 02:02:09 ISRC ; AA/01 02:59:30
00/00 04:29:30 CB 41 ; 04/00 05:29:30 CB 41 ; 04/01 05:31:30 CB 41 ; AA/01 05:32:30 CB 41 ×2
```
The final `AA` packet appears twice, both here and in [pastebin]'s real sample. [pastebin] deduplicates it.

**Confidence / conflicts:**
- The 64-byte layout agrees across all six readers and both real samples. Confidence is high.
- ISRC placement varies:
  - Sonoris puts it on INDEX 00 only when a pregap exists.
  - [pastebin]'s sample, REAPER, Pyramix and GEAR put it on both INDEX 00 and INDEX 01.
  - The ddptools author: "Safest is certainly to write the ISRC for index 0 and index 1".
  - Sonoris DDP Creator showed duplicates when it read REAPER output [reaper2].
- The second CB1 character is read as ADR ([distillery]) or as the SCMS flag ([ddplib], [pastebin] `0S`, and cue2ddp's `SCMS` flag). Only `1` and `S` have been seen.
- ddpinfo `-f` exists because some masters put the UPC only in DDPID and not in PQ, which can yield a pressed CD without the MCN [ddptools].

## 5. Audio image and CD-Text payload

| Fact | Source |
|---|---|
| IMAGE.DAT holds raw 44.1 kHz, 16-bit, **little-endian**, interleaved stereo audio in 2352-byte sectors | [ddptools] cue2ddp manual, [xld] (`XLDLittleEndian`), [distillery], [cdda2img] README, [gearspace] snippet |
| The image usually includes the initial 150-sector (2 s) pause. REAPER originally did not add it and later did | [distillery], [reaper1], [reaper2] |
| CDTEXT.BIN is raw 18-byte lead-in packs: type, track, sequence, block/char-position, 12 text bytes, CRC16. It is Sony-style CD-Text written into the lead-in R–W subcode | [xld] struct, [distillery], [ddptools] |
| The [sonoris] CDTEXT.BIN is 235 bytes: 13 packs plus one trailing `0x00`. ddplib's pack reader would throw on the short trailing read | [sonoris], [ddplib] |
| "DDP spec does not cover CD-TEXT, DDP only includes the CD-TEXT file". DCA advertises a separate "CD-Text Addendum" for DDP 2.0 | [reaper1] (Sergenious), [dca-lic] |

**Conflict:** [cdda2img]'s docstring claims a big-endian to little-endian swap, but its code and README do not swap. We know of no source that claims big-endian DDP audio. We could not decide endianness from the Sonoris sample because its content is test noise.

## 6. Differences between 1.00, 1.01 and 2.00

| Change | Source |
|---|---|
| For Red Book audio, "the only relevant difference" is that 2.00 can include CD-Text | [ddptools] |
| 2.00 DDPID adds BK, TY, sides/layers and DVD fields, and shrinks the user text from 40 to 33 characters | [ddplib] v101 vs v20 |
| 2.00 DDPMS adds NEW, PRE1NXT, PAUSEADD and OFS in what 1.01 used as padding | [ddplib] |
| 2.00 adds DST `D4` and `T3`, and drops `D1` | [ddplib] |
| 2.00 adds SSM `8` | [ddplib] |
| 2.00 replaces SUB `01RSTUVW`/`02RSTUVW` with `RW..`/`WR..` and adds `CDTEXT` | [ddplib] |
| 1.00 vs 1.01: no public detail found. ddpinfo reads 1.00, 1.01 and 2.00 | [ddptools] |
| DDP was extended to DVD in 1996 (2.10). HD DVD came in 2006 (3.0, a superset of CMF 2.0). DVD CMF is described as a DDP 2.10 subset | [dca-lic], [loc] |
| The spec was created in 1989 | [dca-la] |

## 7. Open-source (and source-available) implementations

| Project | Lang | Licence | R/W | Fields handled | Notes |
|---|---|---|---|---|---|
| [ddplib] | Java | GPL-3.0 | R (the writer is unfinished) | Every DDPID/DDPMS/PQ field, 1.01 and 2.00, CD-Text, R–W subcode, T2 text (`IDENT.TXT`) | The most complete. Has no 2.10 support |
| [xld] | Obj-C | unclear ("All rights reserved") | R | DDPMS D0/S0, PQ, CD-Text, DSS offset | Accepts one audio D0 only |
| [mattcarp] | JS | all rights reserved | R/validate | Every field of all three files, CD-Text | Browser-based validator |
| [distillery] | Rust | MIT | **W** | DDPID, DDPMS (D0 plus S0 PQ and CDTEXT), PQ, CDTEXT.BIN, CHECKSUM.MD5 | A modern writer that fits our use case |
| [cdda2img] | Python | GPL-3.0 | R | DDPID UPC, PQ, CDTEXT.BIN | Hard-codes file names and ignores DDPMS |
| [pastebin] | Python 2 | none stated | R | DDPMS (DST/SUB/DSI), PQ | Includes a real hexdump |
| DDP-Builder https://github.com/JonasHRR/DDP-Builder | Python | MIT | W (through cue2ddp) | – | A wrapper around the ddptools binaries, not an independent writer |
| studio-duo https://github.com/mbianchidev/studio-duo | C++ | AGPL-3.0 | W (through an external encoder) | – | Chose not to put the DDP byte layout in its AGPL source because of DCA licensing (`docs/mastering.md`) |
| java-digital-audio-workstation https://github.com/Ben-Esquivel-Music/java-digital-audio-workstation | Java | GPL-3.0 | stub | – | A test fixture with an 8-byte PQDESCR, so not a real implementation |
| DDP Mastering Tools [ddptools] | C? | closed, free | R/W | Everything for Red Book | Not released as open source "due to DCA's licensing conditions" |

Closed-source readers and writers used as references: Sonoris DDP Creator/Player, HOFA DDP Player, ddpplayer.com, WaveLab, Pyramix, Sequoia, SADiE, GEAR, and REAPER, which has had built-in DDP export/import since 2011 [wiki], [reaper1].

## 8. Forum takeaways

- REAPER's DDP author (2011): "The DDP format is pretty straightforward". He tested against Sonoris DDP Creator output ("always created completely the same files"). He declined to write CD-Text without official documentation and said "not all CD plants have license from Philips or Sony to make CD TEXT discs" [reaper1].
- The same author: the Red Book first INDEX 01 must be at 00:02:00 or later. Audio between 00:00:00 and INDEX 01 is a legitimate hidden pre-track [reaper1].
- REAPER import handled one DDP D0 stream and CD-Text block 0 only, ISO-8859-1 only [reaper1].
- The ddptools author (2012): "Even for something as simple as the DDP format you can't simply read the spec and do it right, you have to find out how others do it and what the plant will accept" [reaper2].
- The ddptools author: DDPs "usually include the default two seconds of pause at the beginning". Checksums are not part of DDP [reaper2].
- A 2004 LAU list post pointed to http://www.dcainc.com/products/ddp/ and said no Linux DDP tool existed yet: https://ccrma.stanford.edu/mirrors/lalists/lau/2004/06/0627.html
- Hydrogenaudio "XLD can now read/play DDP images" (https://hydrogenaudio.org/index.php/topic,70501.0.html) and the Gearspace extraction thread both returned 403, so their content is unverified.

## 9. DCA licensing (relevant to writing DDP)

| Fact | Source |
|---|---|
| The licence is free, with "no application fee or royalty". You sign an agreement and DCA emails the spec | [dca-la], [dca-lic] |
| The grant is "limited, non-exclusive, no-cost" to create "products in the proper format". It gives no right to "transfer or further distribute the License Materials" | [dca-la] §1 |
| §2: the licensee may not "include any portion of the Licensed Material in any derivative work" without written consent. This is presumably why the ddptools are closed and studio-duo keeps the layout out of its source | [dca-la], [ddptools], studio-duo |
| §4: every embodiment, including software, must carry DCA's trademark, copyright and licence notices and the DDP logo. the ddptools author's man pages carry exactly these lines | [dca-la], [ddptools] |
| The term is one year from signing. Oklahoma law applies, with ICC arbitration in Dallas | [dca-la] §6, §12–13 |
| DDP® has been a registered trademark of DCA since March 2004 | [dca-lic] |
| Current versions: CD = DDP 2.0 (with a CD-Text addendum), DVD = 2.10, HD DVD = 3.0, Blu-ray = none | [dca-lic] |
| A clean-room implementation that never signs the agreement is not bound by it. Trademark use of "DDP" still applies. This is our reading, not legal advice | inference |

## 10. Gaps

1. The DDPID user-text offset (93 vs 94) needs another real DDPID sample from Wavelab, Pyramix, REAPER or cue2ddp.
2. The semantics of MSL, BK, CB2, NEW, PRE1NXT, PAUSEADD and OFS are guessed from names only.
3. We have no normative statement on SSM `0` vs `7` for CD-DA, or on DSS blank vs `00000000`.
4. We have no public detail on DDP 1.00 vs 1.01.
5. What plants validate (for example whether the duplicated final `AA` or ISRC on INDEX 00 vs 01 matters) is known only anecdotally.
6. The local `bin/` and `docs/*.pdf` (the ddptools) can serve as black-box oracles. Running cue2ddp and diffing its output against this document would settle gaps 1 and 3.
