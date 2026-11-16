#!/usr/bin/env python3
"""Assemble a kit's Dockerfile from tools/*.dockerfile fragments.

A kit directory (shell-base/) has a template.yaml manifest naming a base image
and an ordered list of fragments from tools/. This script concatenates them
into <kit>/<kit>.dockerfile, the companion Dockerfile the sbx kit frontend
finds by the descriptor's base name (<kit>/<kit>.yaml).

The generated Dockerfile is a build artifact, not a source file: to change a
tool's install logic, edit its fragment in tools/, then re-run this script.

`sbx run ./shell-base` builds with that directory alone as the context, so
COPY lines are rewritten to fit it: sources inside the kit directory become
relative to it, and sources elsewhere in the repo (config/, keys/) are copied
into <kit>/shared/ and referenced from there. Those copies are generated too -
edit the originals and re-run this script. Symlinks are no alternative:
neither BuildKit nor sbx follows ones that point outside the context.

No YAML library dependency: template.yaml only needs `base_image: ...` plus
one `tools:` / `  - item` list, so a small hand-rolled parser does.

Usage: python3 scripts/generate_dockerfile.py [KIT_DIR...]  (default: shell-base)
"""
from __future__ import annotations
import re
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOOLS_DIR = REPO_ROOT / "tools"
DEFAULT_KITS = ["shell-base"]

GENERATED_HEADER = """\
# GENERATED FILE - do not edit directly.
#
# Edit the fragments in tools/ (and this kit's template.yaml), then regenerate with:
#   python3 scripts/generate_dockerfile.py {kit}
"""

# Single-line `COPY [--flag=...]... <src>... <dest>`, as every fragment in
# tools/ writes it.
COPY_RE = re.compile(r"^COPY(?P<flags>(?:\s+--\S+)*)\s+(?P<args>\S.*)$")

# Copies of COPY sources from outside the kit directory.
SHARED_DIR_NAME = "shared"


def rewrite_copy(line: str, kit_dir: Path, shared: dict[str, Path]) -> str:
    """Rewrite a repo-root-relative COPY line for the kit's build context.

    Sources outside the kit directory are recorded in `shared` (file name ->
    original) for sync_shared() to copy into <kit>/shared/.

    Example, for kit_dir shell-base/:
      COPY config/git/gitconfig /home/agent/.config/git/config
      => COPY shared/gitconfig /home/agent/.config/git/config
      COPY shell-base/mise.toml /home/agent/.config/mise/config.toml
      => COPY mise.toml /home/agent/.config/mise/config.toml
    """
    match = COPY_RE.match(line)
    if not match:
        return line
    *sources, dest = match["args"].split()
    if not sources:
        return line

    kit_root = kit_dir.resolve()
    rewritten = []
    for source in sources:
        path = (REPO_ROOT / source).resolve()
        if not path.is_file():
            raise ValueError(f"COPY source {source!r} is not a file in the repo: {line!r}")
        if path.is_relative_to(kit_root):
            rewritten.append(str(path.relative_to(kit_root)))
            continue
        if shared.setdefault(path.name, path) != path:
            raise ValueError(
                f"{shared[path.name]} and {path} would both be copied to "
                f"{SHARED_DIR_NAME}/{path.name}"
            )
        rewritten.append(f"{SHARED_DIR_NAME}/{path.name}")
    return f"COPY{match['flags']} {' '.join(rewritten)} {dest}"


def sync_shared(kit_dir: Path, shared: dict[str, Path]) -> None:
    """Make <kit>/shared/ hold exactly the files in `shared`."""
    shared_dir = kit_dir / SHARED_DIR_NAME
    if not shared:
        if shared_dir.exists():
            shutil.rmtree(shared_dir)
        return
    shared_dir.mkdir(exist_ok=True)
    for entry in shared_dir.iterdir():
        if entry.name not in shared:
            shutil.rmtree(entry) if entry.is_dir() else entry.unlink()
    for name, source in shared.items():
        shutil.copyfile(source, shared_dir / name)


def parse_template_yaml(path: Path) -> dict:
    base_image = None
    tools: list[str] = []
    in_tools_list = False

    for raw_line in path.read_text().splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue

        if line.startswith("  - "):
            if not in_tools_list:
                raise ValueError(f"{path}: list item outside of 'tools:' block: {raw_line!r}")
            tools.append(line.strip()[2:].strip())
            continue

        in_tools_list = False
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()

        if key == "base_image":
            base_image = value
        elif key == "tools":
            if value:
                raise ValueError(f"{path}: 'tools:' must be a list on following '  - ' lines")
            in_tools_list = True
        else:
            raise ValueError(f"{path}: unknown key {key!r}")

    if not base_image:
        raise ValueError(f"{path}: missing required 'base_image'")

    return {"base_image": base_image, "tools": tools}


def generate(kit_dir: Path, shared: dict[str, Path]) -> str:
    """Return the Dockerfile text and fill `shared` (see rewrite_copy)."""
    manifest_path = kit_dir / "template.yaml"
    manifest = parse_template_yaml(manifest_path)

    parts = [
        GENERATED_HEADER.format(kit=kit_dir.name),
        f"FROM {manifest['base_image']}",
        "",
    ]
    for tool in manifest["tools"]:
        fragment_path = TOOLS_DIR / f"{tool}.dockerfile"
        if not fragment_path.is_file():
            raise ValueError(f"{manifest_path}: tool {tool!r} has no fragment at {fragment_path}")
        text = fragment_path.read_text().rstrip("\n")
        parts.append("\n".join(rewrite_copy(line, kit_dir, shared) for line in text.split("\n")))
        parts.append("")

    return "\n".join(parts).rstrip("\n") + "\n"


def write_dockerfile(kit_dir: Path) -> None:
    dockerfile_path = kit_dir / f"{kit_dir.name}.dockerfile"
    shared: dict[str, Path] = {}
    dockerfile_path.write_text(generate(kit_dir, shared))
    sync_shared(kit_dir, shared)
    print(f"Wrote {dockerfile_path}")


def main() -> int:
    kit_dirs = [REPO_ROOT / arg for arg in (sys.argv[1:] or DEFAULT_KITS)]
    for kit_dir in kit_dirs:
        if not (kit_dir / "template.yaml").is_file():
            print(f"::error::{kit_dir} has no template.yaml", file=sys.stderr)
            return 1
    for kit_dir in kit_dirs:
        write_dockerfile(kit_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
