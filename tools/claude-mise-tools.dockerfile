# Installs this image's tools as declared in claude/mise.toml (see that file for the list and
# tools/mise.dockerfile for how the mise binary itself gets here). claude/mise.lock pins exact
# reviewed checksums/provenance so `mise install` doesn't re-resolve against live upstream
# metadata on every build; .github/workflows/update-hashes.yml keeps it refreshed going forward.
#
# Installed as mise's *global* config (~/.config/mise/config.toml), not as ~/mise.toml: a
# ~/mise.toml is a project config that only applies when the cwd is under /home/agent, so in a
# workspace elsewhere (e.g. /Users/...) no version was active and the shims fell through to the
# base image's own node/npm (and pnpm had nothing to fall back to at all). The global config
# applies from every directory, is implicitly trusted (no `mise trust`), and its settings
# (minimum_release_age) also become the floor for ad-hoc `mise use`/`mise install` runs in a live
# sandbox. The lockfile must sit next to it as mise.lock (mise ignores config.lock there);
# `--locked` fails the build if mise isn't actually installing from it. See
# https://mise.jdx.dev/configuration.html#configuration-hierarchy and
# https://mise.jdx.dev/dev-tools/mise-lock.html.
# mkdir first so ~/.config/mise is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/mise
COPY --chown=agent:agent claude/mise.toml /home/agent/.config/mise/config.toml
COPY --chown=agent:agent claude/mise.lock /home/agent/.config/mise/mise.lock

RUN mise install --locked
