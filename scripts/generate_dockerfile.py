#!/usr/bin/env python3
"""Assemble a template's Dockerfile from tools/*.dockerfile fragments.

Each template directory (e.g. claude/) has a template.yaml manifest naming a
base image, an optional template-specific prelude fragment, and an ordered
list of shared tool fragments from tools/. This script concatenates them
into <template-dir>/Dockerfile.

The generated Dockerfile is a build artifact, not a source file: to change
a tool's install logic, edit its fragment in tools/, then re-run this
script. Version/hash pins live in the tools/*.dockerfile fragments, which is
also where scripts/update_hashes.py and renovate.json now look for them.

No YAML library dependency: template.yaml only ever needs a flat
`key: value` mapping plus one `key:` / `  - item` list, so a small
hand-rolled parser is used instead of pulling in PyYAML.

Kit mode: a template directory that also holds a v3 kit descriptor named
after itself (shell-base/shell-base.yaml) is built by `sbx run ./shell-base`,
whose build context is that directory alone. Such a template gets
<template-dir>/<template-dir>.dockerfile instead (the kit frontend finds the
companion Dockerfile by the descriptor's base name), and its COPY lines are
rewritten to fit that context: sources inside the template directory become
relative to it, and sources elsewhere in the repo (config/, keys/) are copied
into <template-dir>/shared/ and referenced from there. Those copies are
generated too - edit the originals and re-run this script. Symlinks are no
alternative: neither BuildKit nor sbx follows ones that point outside the
context.
"""
import re
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOOLS_DIR = REPO_ROOT / "tools"

GENERATED_HEADER = """\
# GENERATED FILE - do not edit directly.
#
# Edit the fragments in tools/ (and this template's template.yaml / prelude
# fragment), then regenerate with:
#   python3 scripts/generate_dockerfile.py {template}
"""

# Single-line `COPY [--flag=...]... <src>... <dest>`, as every fragment in
# tools/ writes it.
COPY_RE = re.compile(r"^COPY(?P<flags>(?:\s+--\S+)*)\s+(?P<args>\S.*)$")

# Kit-mode copies of COPY sources from outside the template directory.
SHARED_DIR_NAME = "shared"


def kit_descriptor(template_dir: Path) -> Path:
    return template_dir / f"{template_dir.name}.yaml"


def is_kit(template_dir: Path) -> bool:
    return kit_descriptor(template_dir).is_file()


def output_path(template_dir: Path) -> Path:
    if is_kit(template_dir):
        return template_dir / f"{template_dir.name}.dockerfile"
    return template_dir / "Dockerfile"


def kitify_copy(line: str, template_dir: Path, shared: dict[str, Path]) -> str:
    """Rewrite a repo-root-relative COPY line for a kit's build context.

    Sources outside the template directory are recorded in `shared` (file
    name -> original) for sync_shared() to copy into <template-dir>/shared/.
    """
    match = COPY_RE.match(line)
    if not match:
        return line
    *sources, dest = match["args"].split()
    if not sources:
        return line

    template_root = template_dir.resolve()
    rewritten = []
    for source in sources:
        path = (REPO_ROOT / source).resolve()
        if not path.is_file():
            raise ValueError(f"COPY source {source!r} is not a file in the repo: {line!r}")
        if path.is_relative_to(template_root):
            rewritten.append(str(path.relative_to(template_root)))
            continue
        if shared.setdefault(path.name, path) != path:
            raise ValueError(
                f"{shared[path.name]} and {path} would both be copied to "
                f"{SHARED_DIR_NAME}/{path.name}"
            )
        rewritten.append(f"{SHARED_DIR_NAME}/{path.name}")
    return f"COPY{match['flags']} {' '.join(rewritten)} {dest}"


def sync_shared(template_dir: Path, shared: dict[str, Path]) -> None:
    """Make <template-dir>/shared/ hold exactly the files in `shared`."""
    shared_dir = template_dir / SHARED_DIR_NAME
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
    prelude = None
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
        elif key == "prelude":
            prelude = value
        elif key == "tools":
            if value:
                raise ValueError(f"{path}: 'tools:' must be a list on following '  - ' lines")
            in_tools_list = True
        else:
            raise ValueError(f"{path}: unknown key {key!r}")

    if not base_image:
        raise ValueError(f"{path}: missing required 'base_image'")

    return {"base_image": base_image, "prelude": prelude, "tools": tools}


def generate(template_dir: Path, shared: dict[str, Path] | None = None) -> str:
    """Return the Dockerfile text; in kit mode, also fill `shared` (see kitify_copy)."""
    manifest_path = template_dir / "template.yaml"
    manifest = parse_template_yaml(manifest_path)
    kit = is_kit(template_dir)
    if shared is None:
        shared = {}

    def fragment(text: str) -> str:
        text = text.rstrip("\n")
        if not kit:
            return text
        return "\n".join(kitify_copy(line, template_dir, shared) for line in text.split("\n"))

    parts = [
        GENERATED_HEADER.format(template=template_dir.name),
        f"FROM {manifest['base_image']}",
        "",
    ]

    if manifest["prelude"]:
        prelude_path = template_dir / manifest["prelude"]
        parts.append(fragment(prelude_path.read_text()))
        parts.append("")

    for tool in manifest["tools"]:
        fragment_path = TOOLS_DIR / f"{tool}.dockerfile"
        if not fragment_path.is_file():
            raise ValueError(f"{manifest_path}: tool {tool!r} has no fragment at {fragment_path}")
        parts.append(fragment(fragment_path.read_text()))
        parts.append("")

    return "\n".join(parts).rstrip("\n") + "\n"


def discover_templates() -> list[Path]:
    """Every directory with a template.yaml, repo-wide."""
    return sorted(
        p.parent for p in REPO_ROOT.rglob("template.yaml") if ".git" not in p.parts
    )


def write_dockerfile(template_dir: Path) -> None:
    dockerfile_path = output_path(template_dir)
    shared: dict[str, Path] = {}
    dockerfile_path.write_text(generate(template_dir, shared))
    if is_kit(template_dir):
        sync_shared(template_dir, shared)
    print(f"Wrote {dockerfile_path}")


def main() -> int:
    if len(sys.argv) == 1:
        # No args: regenerate every template in the repo.
        template_dirs = discover_templates()
        if not template_dirs:
            print("::warning::No template.yaml found anywhere in the repo")
            return 0
    else:
        template_dirs = [REPO_ROOT / arg for arg in sys.argv[1:]]

    for template_dir in template_dirs:
        if not (template_dir / "template.yaml").is_file():
            print(f"::error::{template_dir} has no template.yaml", file=sys.stderr)
            return 1

    for template_dir in template_dirs:
        write_dockerfile(template_dir)

    return 0


if __name__ == "__main__":
    sys.exit(main())
