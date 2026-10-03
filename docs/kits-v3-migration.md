# Migrating to sbx v3 kits

Status: in progress. Researched 2026-09-29 against the Docker Sandboxes docs (links at the
bottom). On 2026-10-01 a throwaway kit showed that local v3 kits work with the installed sbx and
that a kit's allow rule takes effect under the local policy. `shell-base/` is a v3 workload kit.

Claude Code: Docker's v3 `claude` workload kit can't be loaded yet (`agent "claude" is already
registered` while `claude` is a built-in agent), so Claude comes from Docker's `claude-mixin`
composed onto `shell-base` (`claude-mixin.ref`, `bin/sbx-up claude`), tested on the host on
2026-10-03. Our own copy of the claude kit was removed. Projects add their own v3 mixins in
`.sbx-kits/<name>/`; `bin/sbx-up` composes and recreates. Note that the target layout below predates
this.

## Goal

- Build, load and configure each template in one step, instead of `build.sh` doing
  `docker build` → `docker save` → `sbx template load`.
- Declare the network allowlist when the sandbox is created.
- Keep the global policy free of the baseline AI-API allowlist; every allowed domain comes from a
  kit.
- Let each project add its own domains without touching this repo.

## Why v3 kits

A v3 kit is a YAML descriptor (`# syntax=docker/sandbox-kit:3`, a BuildKit frontend) plus a
companion Dockerfile. `sbx run ./kit-dir` builds the directory when the sandbox is created, so no
separate build/save/load step and no registry are needed. v2 kits could only reference a prebuilt
image (`sandbox.build` was parsed but not executed).

## Target layout

### This repo: one workload kit per template

```
claude/
├── claude.yaml         # kind: workload
├── claude.dockerfile   # generated Dockerfile, renamed (must share the descriptor's base name)
├── mise.toml
└── mise.lock
shell-base/
├── shell-base.yaml
├── shell-base.dockerfile
└── ...
```

```yaml
# claude/claude.yaml
# syntax=docker/sandbox-kit:3
schemaVersion: "3"
kind: workload
displayName: Claude (simbados)
capabilities:
  - type: com.docker.sandbox/sbx@1
  - type: com.docker.sandbox/network-policy@1
    config:
      runtime:
        allow:
          - api.anthropic.com:443
          # keep this list short - see "Known limits"
```

`sbx@1` requires a non-root `agent` user (UID 1000) with home `/home/agent`; the current images
already switch to `USER agent`.

### Each project: a declaration-only mixin

A mixin with no companion Dockerfile only declares things (the spec calls this
"declaration-only"). Stored in the project, e.g. `<project>/.sbx/project.yaml`:

```yaml
# syntax=docker/sandbox-kit:3
schemaVersion: "3"
kind: mixin
capabilities:
  - type: com.docker.sandbox/network-policy@1
    config:
      runtime:
        allow:
          - api.stripe.com:443
```

### Running

```bash
# from a local checkout
sbx run ~/projects/sandbox-templates/claude --kit ./.sbx --name myproject .

# or pinned to a commit of this repo, from anywhere
sbx run "git+https://github.com/simbados/sandbox-templates.git#ref=<sha>&dir=claude" \
  --kit ./.sbx --name myproject .
```

A sandbox keeps the kits it was created with. To change them, create a new sandbox; `sbx kit add`
can't add mixins to an existing v3 sandbox.

### Optional: publishing

Only needed for signing or for kit sets:

```bash
docker buildx build ./claude -f ./claude/claude.yaml \
  --platform linux/amd64,linux/arm64 \
  -t docker.io/<NAMESPACE>/claude-kit:1.0.0 --push
sbx kit sign docker.io/<NAMESPACE>/claude-kit:1.0.0
```

Kits used as source directories or Git references can't be signed.

## Global policy: remove the baseline API allowlist

The allowlist came from choosing the **Balanced** preset at first setup. On the host:

```bash
sbx policy reset   # deletes the local policy store, restarts the daemon, prompts for a preset
                   # -> choose "Locked Down" (deny-all)
sbx policy ls      # confirm no baseline allow rules remain
```

`sbx policy init --help` may also accept `deny-all` directly; check it.

## Open problems

1. **Build context — solved.** The build context is the kit directory, but the generated
   Dockerfiles `COPY` from the repo root (`config/`, `keys/`). BuildKit doesn't follow symlinks
   that point outside the context (tested: `COPY` reports them as `not found`), and neither
   does sbx (tested on the host). Instead, `scripts/generate_dockerfile.py` has a kit mode, used
   for any template directory that holds `<template>.yaml`: it writes
   `<template>/<template>.dockerfile`, makes `COPY` sources inside the template directory
   relative to it, and copies sources from elsewhere in the repo into `<template>/shared/`
   (marked generated in `.gitattributes`), referencing them from there. Edit `config/` and
   `keys/`, never `shared/`, and regenerate.
2. **Local policy vs kit allow rules — solved.** `kits/kit-smoke/` allows only `example.com`;
   in the sandbox `example.com` was reachable and `example.org` was blocked, so kit allow rules
   apply on top of the local policy. Not yet re-checked after resetting the global policy to
   Locked Down.
3. **sbx version — solved.** The installed sbx creates sandboxes from local v3 kits.
4. **Renovate / CI — done for kit names.** `renovate.json` disables the dockerfile manager for
   `**/*.dockerfile` as well as `**/Dockerfile`; `update-hashes.yml` also runs on `config/**` and
   `keys/**`, which are copied into kit templates' `shared/`. That workflow only runs on Renovate PRs, so after
   editing `config/` or `keys/` by hand, rerun the generator yourself.
5. **Git kit sources are restricted.** By default sbx only accepts remote kits from Docker Hub;
   the `git+https://github.com/...` form needs the source allowed first ("Restrict kit sources"
   in the "Use kits" page). Local paths like `./shell-base` work as is.

## Known limits

- The resolved kit is stored in a 4 KiB container label. A single v3 kit with 100 allow entries
  fails on v0.45.1 ([sbx-releases#645](https://github.com/docker/sbx-releases/issues/645), open).
  Keep base allowlists small and put project domains in the project mixin.
- v3 kits can't be combined with v1/v2 kits in one sandbox. Built-in shortcuts like `claude` are
  still v2, so don't mix them in.
- Every component of a kit set (`kind: set`) must be a published registry reference; local paths
  and Git URLs are rejected. Not useful here without a registry.
- Method/path-scoped rules and `install`-phase access exist in the spec (see the `gh` example,
  `network-policy@2`) but aren't needed for a first pass.

## Steps

1. ~~Smoke test: local v3 kit and kit allow rules.~~ Done.
2. ~~Generator kit mode, Renovate and CI for the new file names.~~ Done.
3. ~~Convert `shell-base/`; drop `shell-base/build.sh`.~~ Done, and created on the host.
4. ~~Claude Code: `shell-base` + Docker's `claude-mixin`.~~ Works on the host (shell, then
   `claude`). Our own `claude/` kit was removed.
5. `bin/sbx-up` and `project-template/` written. To check on the host in the first run:
   - `sbx-up claude` starts Claude directly through `-- -lc 'claude --permission-mode auto'`
     (appended to shell-base's `bash -l`), and the short `docker/...` mixin reference is accepted;
   - a project mixin's `lifecycle@1` install commands run (as root by default) and reach the
     hosts in its `install.allow`;
   - three kits compose (shell-base + claude-mixin + project), and claude-mixin's `CLAUDE.md`
     body shows up. shell-base declares no `agent-context@1` profile; if the body is missing,
     add one to `shell-base.yaml` (`filename: CLAUDE.md` or `AGENTS.md`).
6. Reset the global policy to Locked Down (host) and check `sbx policy log` with real work.
7. When sbx drops the built-in `claude`: consider Docker's `claude` workload plus our tools as a
   mixin instead of `shell-base` + `claude-mixin`.

## Sources

- [Kits (v3) overview](https://docs.docker.com/ai/sandboxes/customize/)
- [Use kits](https://docs.docker.com/ai/sandboxes/customize/use-kits/)
- [Build an agent](https://docs.docker.com/ai/sandboxes/customize/author/build-an-agent/)
- [Base images](https://docs.docker.com/ai/sandboxes/customize/author/base-images/)
- [Tool mixins](https://docs.docker.com/ai/sandboxes/customize/author/tool-mixins/)
- [Kit sets](https://docs.docker.com/ai/sandboxes/customize/author/kit-sets/)
- [Patterns](https://docs.docker.com/ai/sandboxes/customize/author/patterns/)
- [Distribute](https://docs.docker.com/ai/sandboxes/customize/author/distribute/)
- [Local policy](https://docs.docker.com/ai/sandboxes/governance/access-controls/local/)
- [docker/sandbox-kit-spec](https://github.com/docker/sandbox-kit-spec)
