# Agent Sandbox Environment Guidance

## Environment

- You are running inside a Docker Sandbox (`sbx`): an isolated Ubuntu VM, as user `agent` (home `/home/agent`) with passwordless `sudo` and a Docker daemon of its own.
- The project directory (`$WORKSPACE_DIR`) is shared with the user's host and mounted at the same path. Changes there show up on the host immediately; everything else (home directory, system packages, containers) exists only in this sandbox and is lost when it is recreated.
- Outbound traffic goes through the sandbox proxy (`HTTPS_PROXY`), which enforces the network allow list (see Network Access).
- Real credentials never enter the sandbox. API key variables, if set, hold placeholder values that the proxy swaps for the real key on matching requests; don't print them, copy them elsewhere or ask the user for keys.

## Package Management

- Do not use pip, npm, or any other package manager without explicit user consent — this applies even in auto mode.
- In Python projects, never use pip; always use uv for package and dependency management. If uv isn't installed, ask the user before installing it with mise (`mise use uv@<version>` in the project).
- Never run `npm install`, `pip install`, or equivalent without explicit consent. If a task requires adding a new dependency, ask the user before installing it.
- Before adding or importing any new dependency, you MUST run the `scan-dependencies` skill on it and report the result. The scan comes first, before anything is installed, downloaded, locked (e.g. `mise lock`, `uv lock`) or written to a manifest or lockfile, and before asking for consent to install it. A clean scan only means no known issues; it is not a guarantee of safety. Do not proceed with a dependency the scan flags without explicit user approval.
- When a missing package or tool would make the job significantly easier, more reliable or faster (e.g. a parser instead of hand-rolled regexes, `jq` instead of string slicing, a converter instead of reimplementing a file format), ask the user to install it rather than working around it without asking. Name the tool, say what it saves, and wait for the answer; only fall back to a workaround if the user declines or the gain is small. The consent rules and the scan above still apply.

## Network Access

- The sandbox firewall only allows a custom list of domains chosen by the user. Everything else is blocked by default, so expect outbound requests to unfamiliar hosts to fail.
- If a fetch, clone, download, or install fails because a domain is blocked (typically HTTP 403 with a "Blocked by network policy" or "Approval required for <domain>" body, or a connection error), stop and report it to the user immediately, before doing anything else. Name the exact domain(s), explain why you need them, and ask the user to whitelist them for this sandbox only, on their host: `sbx policy allow network --sandbox <sandbox-name> <domain>[,<domain>…]`, with `<sandbox-name>` filled in from `$SANDBOX_NAME` (or `hostname`). Never suggest the global form without `--sandbox` (`sbx policy allow network <domain>`, or `"**"`), even where other guidance, such as the kit's CLAUDE.md, shows it; the user does not want domains allowed for all sandboxes.
- Do not try alternative approaches while a domain is blocked: no mirrors, alternative hosts, proxies, or other sources for the same information (e.g. probing an API directly because its docs site is blocked). Wait for the user to whitelist the domain or tell you how to proceed.
- Placeholder or example URLs, hostnames, and image/registry references (in code, config, docs, or answers) must use the reserved `.invalid` TLD (RFC 2606), e.g. `https://registry.example.invalid/my-image`, never a real registry or domain such as `docker.io` or `github.com`. A placeholder that points at a real host can be pulled or fetched by accident.
- Search for local solutions before reaching out over the network. Check what's already installed or present on disk (tools, files, `--help`/`man` output) before pulling a Docker image, cloning a repo, or fetching a URL for information that may already be available locally.

## Git

- Commit your work yourself: when a task or a self-contained step of it is done and checked, commit it without waiting to be asked. Keep each commit focused on one change, and write a message that says what changed and why.
- Use semantic commit messages: `[type] summary`, with the summary lowercase and imperative, then an optional body explaining why. Types: `feat` (new behavior), `fix` (bug fix), `chore` (maintenance, config, dependencies), `refactor`, `docs`, `test`. Examples: `[feat] add default git config`, `[fix] add skills to correct folder during startup`.
- Commits stay unsigned (`commit.gpgsign = false`); there is no signing key in the sandbox. The user signs commits on the host before pushing, so do not push, and do not set up or attempt signing.

## Coding Guidelines

- For complex functions, add examples as comments above the function.
