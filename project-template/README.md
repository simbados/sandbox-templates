# Project mixin template

Copy `.sbx-kits/` into a project, edit `.sbx-kits/project/project.yaml`, then run from the project
directory:

```bash
sbx-up shell     # shell-base + this project's mixins, opens bash
sbx-up claude    # ... + Docker's claude-mixin, starts Claude Code
```

`sbx-up` adds every `.sbx-kits/<name>/` that holds `<name>.yaml` as a mixin (`--kit`), so a project
can split its additions, e.g. `.sbx-kits/tools/` and `.sbx-kits/net/`. The descriptor must be named after
its directory.

## What goes where

| Need | Where |
| --- | --- |
| Hosts the project reaches | `network-policy@1` → `runtime.allow` |
| apt packages, `mise use`, small setup | `lifecycle@1` → `install` commands (run at every sandbox creation; the hosts they reach go in `install.allow`) |
| Config files | `lifecycle@1` → `files` |
| Standalone binaries, slow installs | a `<name>.dockerfile` next to `<name>.yaml` (built once, then cached) |

A mixin's Dockerfile only contributes the files it produces. Download in a build stage and copy
the result into an empty image, rather than building `FROM` the shell-base image (which would
pin the base in every project):

```dockerfile
# .sbx-kits/project/project.dockerfile
FROM debian:trixie-slim AS build
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
 && mkdir -p /out/usr/local/bin \
 && curl -fsSL "https://downloads.example.invalid/tool-linux-${TARGETARCH}" -o /out/usr/local/bin/tool \
 && chmod 0755 /out/usr/local/bin/tool
FROM scratch
COPY --from=build /out/ /
```

Downloads in a Dockerfile use the build machine's network, so they need no allow rule.
