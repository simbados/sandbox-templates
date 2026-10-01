# sandbox-templates

Base Dockerfiles for docker sbx sandboxes, one subfolder per template
(currently `claude/` and `shell-base/`). Renovate keeps the base image and
pinned tool versions up to date.

`shell-base/` is a v3 sbx kit: the image and its network allow list live in
the directory, and sbx builds it when the sandbox is created. From the repo
root, on the host:

```bash
sbx create --name <name> ./shell-base            # no workspace
sbx run --name <name> ./shell-base ~/projects/x  # with a workspace
```

`claude/` still uses `claude/build.sh` (build, save, `sbx template load`)
until it is converted too - see `docs/kits-v3-migration.md`.

Generated files (`*/Dockerfile`, `shell-base/shell-base.dockerfile`, and
`shell-base/shared/`, which holds copies of `config/` and `keys/` because a
kit can only use files inside its own directory) come from `template.yaml` +
`tools/*.dockerfile`; regenerate with `python3 scripts/generate_dockerfile.py`
after editing any of them.
