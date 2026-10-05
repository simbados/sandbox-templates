# sandbox-templates

Reusable Docker Sandboxes (`sbx`) bases for shell and Claude Code, plus `sbx-up`, which
recreates a project's sandbox from them with the project's own additions. Renovate keeps the
base image, tool versions and the Claude Code mixin up to date.

## Pieces

- `shell-base/`: v3 workload kit. Ubuntu `docker/sandbox-templates:shell-docker` with Docker,
  mise (node, hunk, helix), supply-chain presets for npm/pnpm/uv, the shared agent guidance
  (`config/AGENTS.md`) and a base network allow list. sbx builds it from this directory.
  Project-specific tools such as pnpm or uv go in the project's `.sbx-kits/`.
- `claude-mixin.ref`: Docker's `claude-mixin` kit, pinned by digest. It adds Claude Code, API
  key / subscription sign-in through the sbx proxy (real credentials stay on the host), session
  volumes and Claude's allow list on top of shell-base.
- `bin/sbx-up`: composes the two with a project's mixins and (re)creates the sandbox.
- `project-template/`: a starting `.sbx-kits/` for projects.

## Setup

On the host (macOS), where `sbx` runs; `sbx-up` doesn't work inside a sandbox.

1. Check that `sbx` works: `sbx version` and `sbx ls`.
2. Clone this repo. `sbx-up` finds `shell-base/` and `claude-mixin.ref` through its own
   location, so the clone can live anywhere:

   ```bash
   git clone git@github.com:simbados/sandbox-templates.git ~/projects/sandbox-templates
   ```

3. Put `sbx-up` on `PATH`, either as a symlink into a directory already on it:

   ```bash
   mkdir -p ~/.local/bin
   ln -s ~/projects/sandbox-templates/bin/sbx-up ~/.local/bin/sbx-up
   # only if ~/.local/bin isn't on PATH yet (zsh):
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
   ```

   or with the repo's `bin/` on `PATH`:
   `echo 'export PATH="$HOME/projects/sandbox-templates/bin:$PATH"' >> ~/.zshrc`.
4. Check: `sbx-up -h` prints the usage, and `sbx-up -n shell` in any directory prints the `sbx`
   commands it would run without running them.
5. For Claude Code, optionally store an API key once: `sbx secret set anthropic`. Without one,
   use `/login` inside Claude Code; the sbx proxy keeps the real tokens on the host either way.
6. In each project, copy the template mixin and commit it with the project:

   ```bash
   sbx-up kit            # copies project-template/.sbx-kits/ into the current directory
   ```

   Make sure `.sbx-kits` isn't matched by a global gitignore (`git check-ignore -v .sbx-kits`).

To update the bases later, `git -C ~/projects/sandbox-templates pull`; the next `sbx-up` in a
project rebuilds from them (sbx reuses its build cache when nothing changed).

## Usage

From a project directory, on the host:

```bash
sbx-up shell          # shell-base + the project's .sbx-kits/ mixins, opens bash
sbx-up claude         # ... + claude-mixin, starts Claude Code in auto mode
sbx-up -n claude      # print the sbx commands instead of running them
sbx-up shell ~/projects/x -- -lc 'make test'   # other directory, own launch arguments
sbx-up sealed claude  # throwaway sandbox, see below
sbx-up kit [PATH]     # copy project-template/.sbx-kits/ into a project
```

The sandbox is named `<project>-shell` or `<project>-claude`. Every run removes an existing
sandbox of that name and creates a new one, because a sandbox keeps the kits it was created
with: after `git pull` here or an edit in `.sbx-kits/`, the next `sbx-up` uses them. Anything
installed by hand in the old sandbox is gone, and so is everything else `sbx rm` removes with it
("all associated resources"); put lasting setup in `.sbx-kits/`.

`sbx-up sealed shell|claude` starts a throwaway sandbox named `sealed-shell` or `sealed-claude`.
It mounts an empty directory (`~/.cache/sbx-up/sealed-<flavor>`) instead of a project and adds no
project mixins. When the session ends, also after an error or Ctrl-C, `sbx-up` removes the sandbox
and that directory. Only one of each can run at a time, since a new one replaces the old.

Before each start, `sbx-up` also copies `config/skills/` into the folder sbx mounts read-only at
`~/.claude/skills` in every sandbox (`~/Library/Application Support/com.docker.sandboxes/sandboxes/agent-skills`
on the Mac, not the Mac's own `~/.claude/skills`). Only changed skills are copied; `bin/install-skills`
does the same by hand.

`sbx-up kit` copies the template into a project's `.sbx-kits/` and leaves mixins the project
already has alone.

Claude Code signs in with `/login` inside the sandbox (the proxy keeps the real tokens on the
host) or with an API key stored once on the host: `sbx secret set anthropic`.

## Project additions

Copy `project-template/.sbx-kits/` into a project with `sbx-up kit`. Each `.sbx-kits/<name>/<name>.yaml` is a v3 mixin:
allow-listed hosts, install commands and files, and optionally a `<name>.dockerfile` for tools
that are better built once. See `project-template/README.md`.

## Changing the bases

`shell-base/shell-base.dockerfile` and `shell-base/shared/` (copies of `config/` and `keys/`,
because a kit can only use files inside its own directory) are generated from
`shell-base/template.yaml` and `tools/*.dockerfile`. After editing any of those, or `config/`,
run `python3 scripts/generate_dockerfile.py`.

Background and open points: `docs/kits-v3-migration.md`.
