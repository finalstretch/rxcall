#!/usr/bin/env python3
"""Copy shared/data into each platform's resource directory, or check it's current.

The canonical file is the one in shared/data. Each platform keeps a copy
because neither build system can reach outside its own source tree without
build-phase surgery, and that surgery is not worth risking on a shipped app.
Two copies is only safe if something notices when they diverge, which is what
--check is for.

    tools/sync_shared.py            copy shared/data -> platforms
    tools/sync_shared.py --check    exit 1 if any copy is stale
"""
import filecmp
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# canonical -> where each platform expects it.
# glossary.json is exported *from* the iOS source, so iOS has no copy to sync;
# see "Known divergences" in shared/PARITY.md.
SYNC = {
    "drug-index.json": [
        "ios/Rxcall/Rxcall/Resources/drug-index.json",
        "android/app/src/main/assets/drug-index.json",
    ],
    "glossary.json": [
        "android/app/src/main/assets/glossary.json",
    ],
}


def main() -> int:
    check = "--check" in sys.argv
    stale = []

    for name, targets in SYNC.items():
        source = REPO / "shared" / "data" / name
        if not source.exists():
            print(f"missing: shared/data/{name}")
            return 1
        for rel in targets:
            target = REPO / rel
            # A platform that doesn't exist yet isn't out of date.
            if not target.parent.exists():
                print(f"skip  {rel} (no {target.parent.relative_to(REPO)})")
                continue
            if target.exists() and filecmp.cmp(source, target, shallow=False):
                print(f"ok    {rel}")
                continue
            if check:
                stale.append(rel)
                print(f"STALE {rel}")
            else:
                shutil.copyfile(source, target)
                print(f"wrote {rel}")

    if stale:
        print(f"\n{len(stale)} file(s) differ from shared/data. "
              f"Run tools/sync_shared.py.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
