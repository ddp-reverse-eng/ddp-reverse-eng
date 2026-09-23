# Legal basis

This document explains why this project may study the DDP 2.00 file format and publish a specification and an implementation of it under the [MIT License](https://en.wikipedia.org/wiki/MIT_License) (see `LICENSE`).
It is the project's own reading of the law, not legal advice. The law differs between countries; ask a lawyer before relying on it for anything important.

DDP® is a registered trademark of DCA, Inc. This project is not affiliated with, endorsed by or certified by DCA, Inc. or by Andreas Ruge.

## What the project does

The work is **black-box [reverse engineering](https://en.wikipedia.org/wiki/Reverse_engineering)** of a data format:

1. We write our own inputs: cue sheets and generated test audio (`bin/mkwav`, `exp/*/input.cue`).
2. We run the freely distributed DDP Mastering Tools ([ddptools](http://ddp.andreasruge.de/)) on them as ordinary users, unmodified.
3. We record what they produce: the files they write and what `ddpinfo` prints about those files (`exp/*/out/`, `exp/*/*.log`, `exp/*/ddpinfo-e.txt`).
4. We change one input at a time and infer the format from the differences. Every fact in `spec/ddp2.md` cites the experiment that shows it.
5. We add publicly available information: Wikipedia, forum posts, public DCA web pages, published sample files and open-source readers (`docs/research.md`). Only facts were taken from those sources, never code or text.
6. The OCaml writer (`ocaml/`) is written from `spec/ddp2.md` and checked against the recorded outputs (`bin/compare`).

What the project does **not** do:

- It does not disassemble, decompile or modify ddptools, and it does not look inside the programs at all. It only looks at what they write.
- It does not redistribute ddptools or its manuals. `bin/fetch-tools` downloads them from the author's site, and `.gitignore` keeps them out of the repository.
- It has never requested, received or read DCA's DDP specification, and nobody on the project has signed DCA's licence agreement.
- It does not bypass any copy protection or access control. There is none involved.

## Why this is lawful

### A file format is not protected by copyright

Copyright protects expression, not ideas, methods or facts. This is the [idea–expression distinction](https://en.wikipedia.org/wiki/Idea%E2%80%93expression_distinction).

- **United States:** [17 U.S.C. § 102(b)](https://www.law.cornell.edu/uscode/text/17/102) excludes "any idea, procedure, process, system, method of operation" from copyright. [Baker v. Selden](https://en.wikipedia.org/wiki/Baker_v._Selden) (1879) holds that describing a system does not give exclusive rights over using it. [Feist v. Rural](https://en.wikipedia.org/wiki/Feist_Publications,_Inc.,_v._Rural_Telephone_Service_Co.) (1991) holds that facts cannot be copyrighted. The byte layout of a DDP file, and the names and widths of its fields, are facts about how the format works.
- **European Union:** in [SAS Institute v World Programming](https://en.wikipedia.org/wiki/SAS_Institute_Inc_v_World_Programming_Ltd) (CJEU, [C-406/10](https://curia.europa.eu/juris/liste.jsf?num=C-406/10), 2012), the court held that the functionality of a program, its programming language and the **format of its data files** are not protected by copyright in the program. Recreating them from observation is lawful.

The specification in `spec/ddp2.md` is written by this project. It contains no text taken from DCA's specification, which the project has never seen.

### Observing a program to learn how it works is allowed

- **European Union:** Article 5(3) of the [Computer Programs Directive](https://en.wikipedia.org/wiki/Computer_Programs_Directive) ([Directive 2009/24/EC](https://eur-lex.europa.eu/eli/dir/2009/24/oj)) lets anyone entitled to use a program "observe, study or test the functioning of the program in order to determine the ideas and principles which underlie any element of the program" while loading and running it. That is exactly this project's method. Article 8 makes any contract term that tries to forbid it null and void. SAS v World Programming confirmed that this right cannot be taken away by a licence.
- **United States:** [Sega v. Accolade](https://en.wikipedia.org/wiki/Sega_v._Accolade) (9th Cir. 1992) and [Sony v. Connectix](https://en.wikipedia.org/wiki/Sony_Computer_Entertainment,_Inc._v._Connectix_Corp.) (9th Cir. 2000) held that even *disassembling* a program to reach its unprotected functional elements for interoperability is fair use. This project does far less: it only runs the program and reads its output.

### Neither the DDP licence agreement nor the ddptools licence binds this project

- **DCA's DDP licence agreement:** it binds the companies and people who sign it in exchange for the specification (see `docs/research.md` §9). It restricts what *licensees* may do with DCA's materials, for example putting them in derivative works. This project never signed it and never received those materials. Under [privity of contract](https://en.wikipedia.org/wiki/Privity_of_contract), a contract cannot bind people who are not party to it.
- **ddptools:** it is distributed free of charge, with a copyright notice and a warranty disclaimer. This project does not copy, modify or redistribute it, and no part of its code is in this repository. Studying what a program does with your own inputs is not an act that its copyright controls, and in the EU no licence term can forbid it (above).
- **Output files:** the files in `exp/*/out/` are data a program generated from this project's own inputs. They are kept as the evidence behind each fact in the spec.

### Trade secrets do not cover reverse engineering

If anyone claimed the DDP layout as a [trade secret](https://en.wikipedia.org/wiki/Trade_secret), independent discovery and reverse engineering are still lawful:

- **United States:** [Kewanee Oil Co. v. Bicron Corp.](https://www.law.cornell.edu/supremecourt/text/416/470) (1974) says trade secret law "does not offer protection against discovery by fair and honest means, such as by independent invention, accidental disclosure, or by so-called reverse engineering". The [Defend Trade Secrets Act](https://en.wikipedia.org/wiki/Defend_Trade_Secrets_Act) says "improper means" does not include reverse engineering or independent derivation ([18 U.S.C. § 1839(6)(B)](https://www.law.cornell.edu/uscode/text/18/1839)).
- **European Union:** Article 3(1)(b) of the [Trade Secrets Directive (EU) 2016/943](https://eur-lex.europa.eu/eli/dir/2016/943/oj) makes acquiring information lawful when it is obtained by "observation, study, disassembly or testing of a product" that has been made available to the public, where the person has no legally valid duty to limit that acquisition.

The format is also plainly visible, as ASCII text, in every DDP fileset that mastering studios send to pressing plants.

### No technical protection is circumvented

DDP files are neither encrypted nor access-controlled, so the anti-circumvention rules of the [Digital Millennium Copyright Act](https://en.wikipedia.org/wiki/Digital_Millennium_Copyright_Act) ([17 U.S.C. § 1201](https://www.law.cornell.edu/uscode/text/17/1201)), and Article 6 of the EU [Information Society Directive](https://en.wikipedia.org/wiki/Information_Society_Directive), do not come into play. If they did, § 1201(f) still expressly allows reverse engineering for interoperability.

### Trademark

"DDP" is used only to say what format the software reads and writes. That is [nominative use](https://en.wikipedia.org/wiki/Nominative_use) of a trademark, which is allowed as long as it does not suggest sponsorship or endorsement. The project does not use DCA's logo, does not claim DCA certification, and keeps the trademark notice above.

### Patents

The project knows of no patent covering the DDP file layout, and has not searched for one. This is the one area the reasoning above does not cover.

## Rules that keep this true

- Stay black-box: learn the format only from inputs, outputs and public information. If the project ever decides to look inside the binaries, update this document first. The EU allows decompilation only under the stricter conditions of Article 6 of Directive 2009/24/EC.
- Never commit ddptools binaries or manuals, or any DCA document.
- Every fact in `spec/ddp2.md` cites the experiment or public source that shows it.
- Take facts from third-party code, never code itself, whatever its licence.
- Keep the trademark notice and the no-endorsement statement.

## Further reading

- [Disc Description Protocol](https://en.wikipedia.org/wiki/Disc_Description_Protocol) on Wikipedia
- [Reverse engineering: legality](https://en.wikipedia.org/wiki/Reverse_engineering#Legality) on Wikipedia
