# Installs this image's tools as declared in claude/mise.toml (see that file for the list and
# tools/mise.dockerfile for how the mise binary itself gets here). claude/mise.lock pins exact
# reviewed checksums/provenance so `mise install` doesn't re-resolve against live upstream
# metadata on every build; .github/workflows/update-hashes.yml keeps it refreshed going forward.
COPY --chown=agent:agent claude/mise.toml claude/mise.lock /home/agent/

RUN mise trust ~/mise.toml && mise install
