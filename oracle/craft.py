#!/usr/bin/env python3
"""Builds oracle/<case>/in/ filesets from the OCaml writer's output for an
experiment, optionally altered into something cue2ddp never writes, then
records how ddpinfo reads and exports them.

Usage: oracle/craft.py [CASE...]   (needs bin/ddp, i.e. the ddptools)
"""
import hashlib, os, shutil, subprocess, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def base_fileset(dest, exp):
    base_exp = os.path.join(root, "exp", exp)
    subprocess.run([os.path.join(root, "bin", "exp"), "--inputs", base_exp], check=True)
    options = open(os.path.join(base_exp, "run.args")).read().split()[1:]
    tool = os.path.join(root, "ocaml", "_build", "default", "bin", "cue2ddp.exe")
    subprocess.run(["dune", "build"], cwd=os.path.join(root, "ocaml"), check=True)
    subprocess.run([tool, *options, "input.cue", dest], cwd=base_exp, check=True)
    for f in ("CHECKSUM.MD5", "CHECKSUM.TXT"):
        os.remove(os.path.join(dest, f))


def put(data, offset, value):
    return data[:offset] + value + data[offset + len(value):]


def edit(path, fn):
    data = open(path, "rb").read()
    open(path, "wb").write(fn(data))


def split_image(d, dss):
    image = open(os.path.join(d, "IMAGE.DAT"), "rb").read()
    os.remove(os.path.join(d, "IMAGE.DAT"))
    open(os.path.join(d, "IMAGE01.DAT"), "wb").write(image[: 900 * 2352])
    open(os.path.join(d, "IMAGE02.DAT"), "wb").write(image[900 * 2352 :])
    ms = open(os.path.join(d, "DDPMS"), "rb").read()
    d0 = ms[128:256]
    first = put(put(d0, 14, b"     900"), 74, b"IMAGE01.DAT      ")
    second = put(put(put(d0, 14, b"     750"), 46, b"    "), 74, b"IMAGE02.DAT      ")
    if dss:
        first, second = put(first, 22, b"00000000"), put(second, 22, b"00000900")
    open(os.path.join(d, "DDPMS"), "wb").write(ms[:128] + first + second)


cases = {
    "ddpid-text": lambda d: edit(os.path.join(d, "DDPID"), lambda b: put(b, 93, b"09Some text")),
    "ddpid-text-sonoris": lambda d: edit(os.path.join(d, "DDPID"), lambda b: put(b, 93, b" 09Some text")),
    "two-streams": lambda d: split_image(d, dss=False),
    "two-streams-dss": lambda d: split_image(d, dss=True),
    "storage-mode-0": lambda d: edit(os.path.join(d, "DDPMS"), lambda b: put(b, 128 + 40, b"0")),
    "scrambled-0": lambda d: edit(os.path.join(d, "DDPMS"), lambda b: put(b, 128 + 41, b"0")),
    "export-full": lambda d: None,
}


def set_control(value):
    def craft(d):
        # Packets 1 and 2 are track 1's INDEX 00 and 01.
        edit(os.path.join(d, "SD"), lambda b: put(put(b, 64 + 16, value), 128 + 16, value))
    return craft


for value in ("01", "11", "21", "31", "81", "91", "A1", "B1", "0S"):
    cases["control-" + value] = set_control(value.encode())
base = {"export-full": "025-embed-cue-full"}

only = sys.argv[1:]
for name, craft in cases.items():
    if only and name not in only:
        continue
    case = os.path.join(root, "oracle", name)
    shutil.rmtree(os.path.join(case, "in"), ignore_errors=True)
    os.makedirs(case, exist_ok=True)
    base_fileset(os.path.join(case, "in"), base.get(name, "002-two-tracks"))
    craft(os.path.join(case, "in"))
    ddp = os.path.join(root, "bin", "ddp")
    with open(os.path.join(case, "ddpinfo-e.txt"), "w") as out:
        subprocess.run([ddp, "ddpinfo", "-e", "in"], cwd=case, stdout=out, stderr=subprocess.STDOUT)
    with open(os.path.join(case, "ddpinfo-w.txt"), "w") as out:
        subprocess.run([ddp, "ddpinfo", "-w", "export.wav", "in"], cwd=case, stdout=out, stderr=subprocess.STDOUT)
    wav = os.path.join(case, "export.wav")
    if os.path.exists(wav):
        data = open(wav, "rb").read()
        position, pcm = 12, b""
        while position + 8 <= len(data):
            tag, size = data[position : position + 4], int.from_bytes(data[position + 4 : position + 8], "little")
            if tag == b"data":
                pcm = data[position + 8 : position + 8 + size]
            position += 8 + size + (size & 1)
        with open(os.path.join(case, "export.md5"), "w") as out:
            out.write(hashlib.md5(pcm).hexdigest() + "  exported PCM\n")
        os.remove(wav)
    print(name, "done", file=sys.stderr)
