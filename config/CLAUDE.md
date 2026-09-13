# Sandbox Environment Guidance

## Package Management

- Do not use pip, npm, or any other package manager without explicit user consent — this applies even in auto mode.
- Never use pip; always use uv for Python package and dependency management.
- Never run `npm install`, `pip install`, or equivalent without explicit consent. If a task requires adding a new dependency, ask the user before installing it.

## Network Access

- Search for local solutions before reaching out over the network. Check what's already installed or present on disk (tools, files, `--help`/`man` output) before pulling a Docker image, cloning a repo, or fetching a URL for information that may already be available locally.
