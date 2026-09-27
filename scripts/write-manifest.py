#!/usr/bin/env python3
import argparse
import hashlib
from pathlib import Path


parser = argparse.ArgumentParser()
parser.add_argument("--distdir", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("files", nargs="+")
args = parser.parse_args()

rows = []
for name in sorted(args.files):
    path = args.distdir / name
    if not path.is_file():
        raise SystemExit(f"missing distfile: {path}")
    data = path.read_bytes()
    rows.append(
        f"DIST {name} {len(data)} BLAKE2B {hashlib.blake2b(data).hexdigest()} "
        f"SHA512 {hashlib.sha512(data).hexdigest()}"
    )
args.output.write_text("\n".join(rows) + "\n")
