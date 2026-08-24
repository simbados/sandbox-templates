#!/usr/bin/env python3
"""Re-verify the pinned GitHub release sha256 hashes in every tools/*.dockerfile
fragment against the real release assets, and rewrite any that no longer match
(e.g. after Renovate bumps a *_VERSION pin but leaves the old hash in place).

Some tools (fzf, zoxide, temurin) also embed the version number a second time
inside their *_ASSET filename (e.g. FZF_ASSET=fzf-0.74.2-linux_amd64.tar.gz).
Renovate's customManager only bumps *_VERSION, so after a bump that embedded
number is stale and the release download 404s. Before verifying hashes, this
script re-derives that numeral from *_VERSION and rewrites it in place too -
see the TOOLS dict and fix_asset_versions() below.

Version/hash pins live in tools/*.dockerfile fragments, not in a template's
generated Dockerfile (see scripts/generate_dockerfile.py) - those are build
artifacts, so this script never touches them directly.
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
#
# "asset_version_re" / "version_re" are only set for tools whose *_ASSET
# filename embeds the version number a second time (see module docstring).
# version_re's single capture group pulls the numeral out of *_VERSION;
# version_transform (if set) adapts it to the asset filename's own spelling
# of that numeral; asset_version_re then locates and replaces that numeral
# inside *_ASSET, leaving the rest of the filename (arch, extension, any
# fixed prefix like temurin's major-version-specific "OpenJDK25U") untouched.
TOOLS = {
    "FNM": {"repo": "Schniz/fnm"},
    "FZF": {
        "repo": "junegunn/fzf",
        "version_re": r"v([0-9.]+)",
        "asset_version_re": r"[0-9]+\.[0-9]+\.[0-9]+",
    },
    "ZOXIDE": {
        "repo": "ajeetdsouza/zoxide",
        "version_re": r"v([0-9.]+)",
        "asset_version_re": r"[0-9]+\.[0-9]+\.[0-9]+",
    },
    "TEMURIN": {
        "repo": "adoptium/temurin25-binaries",
        # jdk-25.0.4+7 -> 25.0.4+7 -> (version_transform) -> 25.0.4_7, matching
        # the asset filename's ..._hotspot_25.0.4_7.tar.gz spelling.
        "version_re": r"jdk-([0-9.]+\+[0-9]+)",
        "version_transform": lambda v: v.replace("+", "_"),
        "asset_version_re": r"[0-9]+\.[0-9]+\.[0-9]+_[0-9]+",
    },
    "UV": {"repo": "astral-sh/uv"},
}


def fix_asset_versions(name: str, meta: dict, version: str, content: str) -> tuple[str, bool]:
    """Rewrite the version numeral embedded in every {name}_ASSET occurrence
    to match {name}_VERSION. No-op for tools without an asset_version_re."""
    if "asset_version_re" not in meta:
        return content, False

    version_match = re.search(meta["version_re"], version)
    if not version_match:
        print(f"::error::{name}: version {version!r} doesn't match expected pattern {meta['version_re']!r}")
        raise SystemExit(1)
    numeral = version_match.group(1)
    if "version_transform" in meta:
        numeral = meta["version_transform"](numeral)

    changed = False

    def repl(m: re.Match) -> str:
        nonlocal changed
        prefix, old_numeral, suffix = m.group(1), m.group(2), m.group(3)
        if old_numeral != numeral:
            print(f"::notice::{name}_ASSET: version numeral {old_numeral} -> {numeral}")
            changed = True
        return f"{prefix}{numeral}{suffix}"

    pattern = re.compile(rf"({name}_ASSET=\S*?)({meta['asset_version_re']})(\S*?;)")
    new_content = pattern.sub(repl, content)
    return new_content, changed


def find_dockerfiles() -> list[Path]:
    return sorted(
        p for p in (REPO_ROOT / "tools").glob("*.dockerfile") if ".git" not in p.parts
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

    for name, meta in TOOLS.items():
        repo = meta["repo"]
        version_match = re.search(rf"{name}_VERSION=(\S+?);", content)
        if not version_match:
            continue  # this tool isn't pinned in this particular Dockerfile
        version = version_match.group(1)

        content, asset_changed = fix_asset_versions(name, meta, version, content)
        changed = changed or asset_changed

        assets = re.findall(rf"{name}_ASSET=(\S+?);", content)
        old_hashes = re.findall(rf"{name}_SHA256=([0-9a-f]{{64}})", content)
        if not assets or len(assets) != len(old_hashes):
            print(f"::error::{path}: {name}: found {len(assets)} asset(s) but {len(old_hashes)} hash(es), giving up")
            raise SystemExit(1)

        actual_hashes = []
        for asset, old_hash in zip(assets, old_hashes):
            url = f"https://github.com/{repo}/releases/download/{version}/{asset}"
            print(f"Checking {path}: {name} {asset} @ {version} ...")
            try:
                actual_hash = sha256_of_url(url)
            except Exception as exc:  # noqa: BLE001 - report and fail the job
                print(f"::error::Failed to download {url}: {exc}")
                raise SystemExit(1)

            actual_hashes.append(actual_hash)
            if actual_hash != old_hash:
                print(f"::notice::{path}: {asset}: hash changed {old_hash} -> {actual_hash}")
                changed = True
            else:
                print(f"{path}: {asset}: OK ({actual_hash})")

        # Rewrite the Nth "{name}_SHA256=..." occurrence with the Nth freshly
        # computed hash, by position rather than by searching for the old hash
        # string. A plain content.replace(old_hash, actual_hash) is unsafe here:
        # if two occurrences ever hold an identical hash (e.g. from a prior bug,
        # or coincidentally), replacing by string value corrupts every matching
        # occurrence at once instead of just the one that actually changed.
        sha_pattern = re.compile(rf"{name}_SHA256=[0-9a-f]{{64}}")
        actual_iter = iter(actual_hashes)
        content = sha_pattern.sub(lambda m: f"{name}_SHA256={next(actual_iter)}", content)

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
