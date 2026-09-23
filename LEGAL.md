# Why we believe this project is lawful

This project studies the DDP 2.00 file format and publishes a description of it, and software that reads and writes it, under the [MIT License](https://en.wikipedia.org/wiki/MIT_License) (see `LICENSE`). This document explains how we did the work and why we believe it is lawful.

We are not lawyers, and this is not legal advice. It is our reading of the law and of published precedent, set out so that anyone can check our reasoning. The law differs between countries. If you plan to rely on this project for something important, ask a lawyer in your country.

## How the work was done

We learned the format through **black-box [reverse engineering](https://en.wikipedia.org/wiki/Reverse_engineering)**:

1. We wrote our own inputs: cue sheets and generated test audio (`bin/mkwav`, `exp/*/input.cue`).
2. We ran the freely distributed DDP Mastering Tools ([ddptools](http://ddp.andreasruge.de/)) on them as ordinary users, unmodified.
3. We recorded what they produced: the files they wrote and what `ddpinfo` printed about them (`exp/*/out/`, `exp/*/*.log`, `exp/*/ddpinfo-e.txt`).
4. We changed one input at a time and inferred the format from the differences. Every fact in `spec/ddp2.md` cites the experiment that shows it.
5. We added publicly available information: Wikipedia, forum posts, public DCA web pages, published sample files and open-source readers (`docs/research.md`). We took facts from those sources, never code or text.
6. We wrote the OCaml software (`ocaml/`) from `spec/ddp2.md`, and checked it against the recorded outputs (`bin/compare`).

What we deliberately did not do:

- We did not disassemble, decompile or modify ddptools. We only looked at what the programs write.
- We do not redistribute ddptools or its manuals. `bin/fetch-tools` downloads them from the author's site, and `.gitignore` keeps them out of the repository.
- We have never requested, received or read DCA's DDP specification, and nobody on the project has signed DCA's licence agreement.
- We did not bypass any copy protection or access control. DDP has none.

## Our reasoning

### A file format is a fact, not a work

Copyright protects expression, not ideas, methods or facts: the [idea–expression distinction](https://en.wikipedia.org/wiki/Idea%E2%80%93expression_distinction). We believe the byte layout of a DDP file, and the names and widths of its fields, are facts about how the format works.

- **United States:** [17 U.S.C. § 102(b)](https://www.law.cornell.edu/uscode/text/17/102) excludes "any idea, procedure, process, system, method of operation" from copyright. [Baker v. Selden](https://en.wikipedia.org/wiki/Baker_v._Selden) (1879) held that describing a system does not give exclusive rights over using it. [Feist v. Rural](https://en.wikipedia.org/wiki/Feist_Publications,_Inc.,_v._Rural_Telephone_Service_Co.) (1991) held that facts cannot be copyrighted.
- **European Union:** in [SAS Institute v World Programming](https://en.wikipedia.org/wiki/SAS_Institute_Inc_v_World_Programming_Ltd) (CJEU, [C-406/10](https://curia.europa.eu/juris/liste.jsf?num=C-406/10), 2012), the court held that the functionality of a program, its programming language and the format of its data files are not protected by copyright in the program.

`spec/ddp2.md` is our own writing. It contains no text from DCA's specification, which we have never seen.

### Observing a program is a recognised right

- **European Union:** Article 5(3) of the [Computer Programs Directive](https://en.wikipedia.org/wiki/Computer_Programs_Directive) ([Directive 2009/24/EC](https://eur-lex.europa.eu/eli/dir/2009/24/oj)) lets anyone entitled to use a program "observe, study or test the functioning of the program in order to determine the ideas and principles which underlie any element of the program" while running it. That describes our method. Article 8 makes contract terms that try to forbid it null and void, and SAS v World Programming confirmed that a licence cannot take this right away.
- **United States:** [Sega v. Accolade](https://en.wikipedia.org/wiki/Sega_v._Accolade) (9th Cir. 1992) and [Sony v. Connectix](https://en.wikipedia.org/wiki/Sony_Computer_Entertainment,_Inc._v._Connectix_Corp.) (9th Cir. 2000) held that even disassembling a program to reach its functional elements for interoperability was fair use. We did less than that: we only ran the programs and read their output.

### The licences involved are not ours

- **DCA's DDP licence agreement:** it governs the companies and people who sign it in exchange for the specification (see `docs/research.md` §9). We never signed it and never received those materials. Under [privity of contract](https://en.wikipedia.org/wiki/Privity_of_contract), a contract generally binds only its parties.
- **ddptools:** it is distributed free of charge with a copyright notice and a warranty disclaimer. We do not copy, modify or redistribute it, and none of its code is in this repository. As we understand it, studying what a program does with our own inputs is not an act its copyright controls.
- **Output files:** the files in `exp/*/out/` are data that ddptools generated from our own inputs. We keep them as the evidence behind the spec.

### Reverse engineering is fair means under trade secret law

If the DDP layout were claimed as a [trade secret](https://en.wikipedia.org/wiki/Trade_secret), independent discovery and reverse engineering are recognised as fair means:

- **United States:** [Kewanee Oil Co. v. Bicron Corp.](https://www.law.cornell.edu/supremecourt/text/416/470) (1974): trade secret law "does not offer protection against discovery by fair and honest means, such as by independent invention, accidental disclosure, or by so-called reverse engineering". The [Defend Trade Secrets Act](https://en.wikipedia.org/wiki/Defend_Trade_Secrets_Act) excludes reverse engineering and independent derivation from "improper means" ([18 U.S.C. § 1839(6)(B)](https://www.law.cornell.edu/uscode/text/18/1839)).
- **European Union:** Article 3(1)(b) of the [Trade Secrets Directive (EU) 2016/943](https://eur-lex.europa.eu/eli/dir/2016/943/oj) treats information obtained by "observation, study, disassembly or testing of a product" made available to the public as lawfully acquired.

The format is also plainly visible, as ASCII text, in every DDP fileset that mastering studios send to pressing plants.

### No protection measure is involved

DDP files are neither encrypted nor access-controlled. So we believe the anti-circumvention rules of the [Digital Millennium Copyright Act](https://en.wikipedia.org/wiki/Digital_Millennium_Copyright_Act) ([17 U.S.C. § 1201](https://www.law.cornell.edu/uscode/text/17/1201)) and of Article 6 of the EU [Information Society Directive](https://en.wikipedia.org/wiki/Information_Society_Directive) do not apply. Even where they do apply, § 1201(f) provides an exception for reverse engineering aimed at interoperability.

## Precedent: libdvdcss and DeCSS

The closest well-known precedent is [libdvdcss](https://www.videolan.org/developers/libdvdcss.html), the library VLC uses to play encrypted DVDs.

- **libdvdcss is a harder case than ours.** It gets around CSS, a real copy-protection scheme, which is exactly what anti-circumvention laws target. VideoLAN, a French non-profit, has nonetheless developed and distributed it openly for years, and bundles it with VLC. Its [FAQ](https://wiki.videolan.org/Frequently_Asked_Questions/) calls its status "controversial in a few countries such as the United States because of … the DMCA", and tells users to consult a lawyer. Unlike DeCSS, [no legal challenge to libdvdcss](https://en.wikipedia.org/wiki/Libdvdcss) is known.
- **DeCSS** was challenged. Jon Lech Johansen was prosecuted in Norway, [acquitted in 2003, and the acquittal was upheld on appeal](https://en.wikipedia.org/wiki/DeCSS). In the United States, the DVD CCA pursued injunctions under the DMCA, then dropped its case against Johansen in 2004.
- **In 2013, VideoLAN asked the French authority HADOPI** whether VLC could support Blu-ray discs, whose protection measures are stronger. HADOPI recognised the request as a legitimate interoperability concern. It also held that protection measures are not software as such, so the reverse engineering exceptions for software do not authorise circumventing them ([Lexing analysis](https://www.lexing.law/avocats/avis-de-hadopi-sur-les-mesures-techniques-de-protection-et-interoperabilite/2013/05/15/), [Next coverage](https://next.ink/32377/77329-droit-lire-vlc-consultation-et-premier-avis-hadopi/), both in French).

We read these cases as follows. Where interoperability work has met trouble, the trouble came from circumventing a protection measure. This project circumvents nothing: it describes a plain, unprotected data format. That limit in the HADOPI opinion therefore does not reach it, while the right it recognised, interoperability, is exactly what this project serves.

## Trademark

We use "DDP" only to say which format the software reads and writes. We believe this is [nominative use](https://en.wikipedia.org/wiki/Nominative_use) of the trademark, allowed as long as it does not suggest sponsorship or endorsement. We do not use any DDP logo and do not claim any certification.

## Patents

We know of no patent covering the DDP file layout.

## How we keep it this way

- We stay black-box: we learn the format only from inputs, outputs and public information. If we ever consider looking inside the binaries, we will revisit this document first. The EU allows decompilation only under the stricter conditions of Article 6 of Directive 2009/24/EC.
- We never commit ddptools binaries or manuals, or any DCA document.
- Every fact in `spec/ddp2.md` cites the experiment or public source that shows it.
- We take facts from third-party code, never the code itself, whatever its licence.

## Further reading

- [Disc Description Protocol](https://en.wikipedia.org/wiki/Disc_Description_Protocol) on Wikipedia
- [Reverse engineering: legality](https://en.wikipedia.org/wiki/Reverse_engineering#Legality) on Wikipedia
