# sandbox-templates

Guidance for agents working on this repo. `config/AGENTS.md` is not for this repo: it is the agent
guidance shipped inside the base image (`~/.claude/AGENTS.md` in every sandbox).

## Dockerfiles

- `shell-base/shell-base.dockerfile` and `shell-base/shared/` are generated. Edit the fragments in
  `tools/*.dockerfile`, the tool list in `shell-base/template.yaml` or the sources in `config/`,
  then run `python3 scripts/generate_dockerfile.py shell-base` and commit the regenerated files too.
- When adding or changing layers, always consider the build cache: a change to one layer rebuilds
  it and every layer after it. The tool order in `template.yaml` is the layer order. Put slow,
  rarely changing steps (apt, mise, `mise install`) first and small, often edited files (config,
  agent guidance) last. COPY only the files a step needs, right before that step.
- Kit mode flattens COPY sources into `shared/` by file name, so each copied file needs a unique
  name (e.g. `config/hunk/hunk.toml`, since helix already uses `config.toml`).

## Base kit

- `shell-base/shell-base.yaml` holds the sandbox's network allow list. Keep it short: the resolved
  kit is stored in a 4 KiB container label. Project-specific hosts belong in a project mixin.
