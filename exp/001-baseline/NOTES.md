# 001 baseline

Input: 1 track, 750 frames (10 s) position pattern, `INDEX 01 00:00:00`, no options.
Output: DDPID (128 B), DDPMS (256 B), SD (320 B), IMAGE.DAT (900 sectors), CHECKSUM.MD5, CHECKSUM.TXT.
All metadata is fixed-width ASCII, space padded. Offsets below are decimal, still to be confirmed by diffs.

## DDPID (one 128-byte record)
- 0: `DDP 2.00` (level)
- 87: `CD`
- everything else spaces

## DDPMS (128-byte packets)
Packet 0, `VVVMS0`: describes SD
- 19..21: `320` right-aligned (SD length in bytes?)
- 30: `PQ DESCR`
- 72: `17`, 74: `SD` (filename)

Packet 1, `VVVMD0`: describes IMAGE.DAT
- 19..21: `900` right-aligned (length in sectors)
- 38: `DA71`
- 47..49: `150` (2 s pregap, frames?)
- 72: `17`, 74: `IMAGE.DAT`

## SD (64-byte PQ packets)
`VVVS` + track(2) + index(2) + 2 spaces + MMSSFF(6) + `01`, then spaces.

| # | trk | idx | time | note |
|---|-----|-----|------|------|
| 0 | 00 | 00 | 00:00:00 | lead-in? |
| 1 | 01 | 00 | 00:00:00 | pregap added by cue2ddp |
| 2 | 01 | 01 | 00:02:00 | |
| 3 | AA | 01 | 00:12:00 | lead-out |
| 4 | AA | 01 | 00:12:00 | duplicate of #3, why? |

Trailing `01` looks like CONTROL/ADR (control 0, ADR 1).

## IMAGE.DAT
900 sectors = 150 of pregap + 750 of audio; cue2ddp inserted the 2 s pregap itself. The pregap's byte content still needs checking.
