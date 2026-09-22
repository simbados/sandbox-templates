# Installs this image's tools as declared in shell-base/mise.toml (see that file for the list and
# tools/mise.dockerfile for how the mise binary itself gets here). shell-base/mise.lock pins exact
# reviewed checksums/provenance so `mise install` doesn't re-resolve against live upstream
# metadata on every build; .github/workflows/update-hashes.yml keeps it refreshed going forward.
COPY --chown=agent:agent shell-base/mise.toml shell-base/mise.lock /home/agent/

RUN mise trust ~/mise.toml && mise install
