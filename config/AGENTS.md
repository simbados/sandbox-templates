# Agent Sandbox Environment Guidance

## Package Management

- Do not use pip, npm, or any other package manager without explicit user consent — this applies even in auto mode.
- In Python projects, never use pip; always use uv for package and dependency management. If uv isn't installed, ask the user before installing it with mise (`mise use uv@<version>` in the project).
- Never run `npm install`, `pip install`, or equivalent without explicit consent. If a task requires adding a new dependency, ask the user before installing it.
- Before adding or importing any new dependency, you MUST run the `scan-dependencies` skill on it and report the result. The scan comes first, before anything is installed, downloaded, locked (e.g. `mise lock`, `uv lock`) or written to a manifest or lockfile, and before asking for consent to install it. A clean scan only means no known issues; it is not a guarantee of safety. Do not proceed with a dependency the scan flags without explicit user approval.

## Network Access

- You are running inside a Docker Sandbox (`sbx`) whose firewall only allows a custom list of domains chosen by the user. Everything else is blocked by default, so expect outbound requests to unfamiliar hosts to fail.
- If a fetch, clone, download, or install fails because a domain is blocked (typically HTTP 403 with a "Blocked by network policy" or "Approval required for <domain>" body, or a connection error), stop and report it to the user immediately, before doing anything else. Name the exact domain(s), explain why you need them, and ask the user to whitelist them on their host, e.g. `sbx policy allow network <domain>[,<domain>…]`.
- Do not try alternative approaches while a domain is blocked: no mirrors, alternative hosts, proxies, or other sources for the same information (e.g. probing an API directly because its docs site is blocked). Wait for the user to whitelist the domain or tell you how to proceed.
- Placeholder or example URLs, hostnames, and image/registry references (in code, config, docs, or answers) must use the reserved `.invalid` TLD (RFC 2606), e.g. `https://registry.example.invalid/my-image`, never a real registry or domain such as `docker.io` or `github.com`. A placeholder that points at a real host can be pulled or fetched by accident.
- Search for local solutions before reaching out over the network. Check what's already installed or present on disk (tools, files, `--help`/`man` output) before pulling a Docker image, cloning a repo, or fetching a URL for information that may already be available locally.

## Coding Guidelines

- For complex functions, add examples as comments above the function.
