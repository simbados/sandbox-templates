# Agent Sandbox Environment Guidance

## Package Management

- Do not use pip, npm, or any other package manager without explicit user consent — this applies even in auto mode.
- Never use pip; always use uv for Python package and dependency management.
- Never run `npm install`, `pip install`, or equivalent without explicit consent. If a task requires adding a new dependency, ask the user before installing it.

## Network Access

- You are running inside a Docker Sandbox (`sbx`) whose firewall only allows a custom list of domains chosen by the user. Everything else is blocked by default, so expect outbound requests to unfamiliar hosts to fail.
- If a fetch, clone, download, or install fails because a domain is blocked (typically HTTP 403 with a "Blocked by network policy" body, or a connection error), do not work around it with mirrors, alternative hosts, or proxies. Stop and ask the user to whitelist the exact domain(s) you need on their host, e.g. `sbx policy allow network <domain>[,<domain>…]`, and explain why you need them.
- Placeholder or example URLs, hostnames, and image/registry references (in code, config, docs, or answers) must use the reserved `.invalid` TLD (RFC 2606), e.g. `https://registry.example.invalid/my-image`, never a real registry or domain such as `docker.io` or `github.com`. A placeholder that points at a real host can be pulled or fetched by accident.
- Search for local solutions before reaching out over the network. Check what's already installed or present on disk (tools, files, `--help`/`man` output) before pulling a Docker image, cloning a repo, or fetching a URL for information that may already be available locally.

## Coding Guidelines

- For complex functions, add examples as comments above the function.
