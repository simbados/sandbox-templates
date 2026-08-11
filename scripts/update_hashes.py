#!/usr/bin/env python3
"""Re-verify the pinned GitHub release sha256 hashes in every Dockerfile in this
repo against the real release assets, and rewrite any that no longer match (e.g.
after Renovate bumps a *_VERSION pin but leaves the old hash in place).
"""
import hashlib
import re
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(".")
RESULT_FILE = Path("hash_update_result.txt")

# Known GitHub-release-pinned tools, keyed by the Dockerfile variable prefix
# (e.g. FNM_VERSION / FNM_ASSET / FNM_SHA256) they're pinned under. Deliberately
# hardcoded here rather than read from the Dockerfile: the repo name is what
# this script trusts to build download URLs from, so it must come from
# reviewed script code, not from content a Dockerfile PR could change.
TOOLS = {
    "FNM": "Schniz/fnm",
    "FZF": "junegunn/fzf",
    "ZOXIDE": "ajeetdsouza/zoxide",
}


def find_dockerfiles() -> list[Path]:
    return sorted(
        p for p in REPO_ROOT.rglob("Dockerfile") if ".git" not in p.parts
    )


def sha256_of_url(url: str) -> str:
    digest = hashlib.sha256()
    with urllib.request.urlopen(url) as resp:
        for chunk in iter(lambda: resp.read(1 << 16), b""):
            digest.update(chunk)
    return digest.hexdigest()


def process_dockerfile(path: Path) -> bool:
    """Verify (and fix) the pinned hashes in a single Dockerfile. Returns True
    if the file was rewritten."""
    content = path.read_text()
    changed = False

    for name, repo in TOOLS.items():
        version_match = re.search(rf"{name}_VERSION=(\S+?);", content)
        if not version_match:
            continue  # this tool isn't pinned in this particular Dockerfile
        version = version_match.group(1)

        assets = re.findall(rf"{name}_ASSET=(\S+?);", content)
        hashes = re.findall(rf"{name}_SHA256=([0-9a-f]{{64}})", content)
        if not assets or len(assets) != len(hashes):
            print(f"::error::{path}: {name}: found {len(assets)} asset(s) but {len(hashes)} hash(es), giving up")
            raise SystemExit(1)

        for asset, old_hash in zip(assets, hashes):
            url = f"https://github.com/{repo}/releases/download/{version}/{asset}"
            print(f"Checking {path}: {name} {asset} @ {version} ...")
            try:
                actual_hash = sha256_of_url(url)
            except Exception as exc:  # noqa: BLE001 - report and fail the job
                print(f"::error::Failed to download {url}: {exc}")
                raise SystemExit(1)

            if actual_hash != old_hash:
                print(f"::notice::{path}: {asset}: hash changed {old_hash} -> {actual_hash}")
                content = content.replace(old_hash, actual_hash)
                changed = True
            else:
                print(f"{path}: {asset}: OK ({actual_hash})")

    if changed:
        path.write_text(content)
        print(f"{path} updated with new hashes.")

    return changed


def main() -> int:
    dockerfiles = find_dockerfiles()
    if not dockerfiles:
        print("::warning::No Dockerfiles found in this repo")

    changed_files: list[Path] = []
    for path in dockerfiles:
        try:
            if process_dockerfile(path):
                changed_files.append(path)
        except SystemExit as exc:
            return exc.code or 1

    if changed_files:
        print(f"{len(changed_files)} Dockerfile(s) updated.")
    else:
        print("All hashes already up to date across all Dockerfiles.")

    RESULT_FILE.write_text("\n".join(str(p) for p in changed_files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
