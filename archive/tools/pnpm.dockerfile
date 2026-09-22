# Archived - superseded by tools/mise.dockerfile + tools/{claude,shell-base}-mise-tools.dockerfile
# (mise's pnpm registry entry, backed by aqua:pnpm/pnpm). Kept here for reference; not built or
# referenced by anything active. This also retires the one gap in the old setup: pnpm here had
# no version pin and no Renovate coverage at all - mise gives it a real pin like every other tool.
RUN eval "$(fnm env --shell bash)" && \
    npm install -g pnpm
