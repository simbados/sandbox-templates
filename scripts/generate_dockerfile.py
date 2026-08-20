#!/usr/bin/env python3
"""Assemble a template's Dockerfile from tools/*.dockerfile fragments.

Each template directory (e.g. npm/) has a template.yaml manifest naming a
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
"""
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


def generate(template_dir: Path) -> str:
    manifest_path = template_dir / "template.yaml"
    manifest = parse_template_yaml(manifest_path)

    parts = [
        GENERATED_HEADER.format(template=template_dir.name),
        f"FROM {manifest['base_image']}",
        "USER agent",
        "",
    ]

    if manifest["prelude"]:
        prelude_path = template_dir / manifest["prelude"]
        parts.append(prelude_path.read_text().rstrip("\n"))
        parts.append("")

    for tool in manifest["tools"]:
        fragment_path = TOOLS_DIR / f"{tool}.dockerfile"
        if not fragment_path.is_file():
            raise ValueError(f"{manifest_path}: tool {tool!r} has no fragment at {fragment_path}")
        parts.append(fragment_path.read_text().rstrip("\n"))
        parts.append("")

    return "\n".join(parts).rstrip("\n") + "\n"


def discover_templates() -> list[Path]:
    """Every directory with a template.yaml, repo-wide."""
    return sorted(
        p.parent for p in REPO_ROOT.rglob("template.yaml") if ".git" not in p.parts
    )


def write_dockerfile(template_dir: Path) -> None:
    dockerfile_path = template_dir / "Dockerfile"
    dockerfile_path.write_text(generate(template_dir))
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
