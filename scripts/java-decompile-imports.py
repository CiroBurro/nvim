#!/usr/bin/env python3
"""Batch decompile .class files in place using jadx.

Called by java_decompile.vim when the LSP reports unresolved imports.
Each .class file gets a .java sibling written next to it.
"""

import subprocess
import sys
import tempfile
from pathlib import Path


def decompile(classfile: Path) -> bool:
    dest = classfile.with_suffix(".java")
    if dest.exists():
        return True
    if not classfile.exists():
        return False

    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run(
            ["jadx", "--no-res", "-d", tmpdir, str(classfile)],
            capture_output=True,
        )
        java_files = list(Path(tmpdir).rglob("*.java"))
        if not java_files:
            return False
        dest.write_text(java_files[0].read_text())

    return True


def main():
    ok = 0
    total = len(sys.argv) - 1
    for arg in sys.argv[1:]:
        if decompile(Path(arg)):
            ok += 1
            print(f"  OK  {arg}", file=sys.stderr)
        else:
            print(f"  FAIL {arg}", file=sys.stderr)
    print(f"{ok}/{total}")


if __name__ == "__main__":
    main()
