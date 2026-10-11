# Ships a default hunk config (theme, view settings) as the user-level config in ~/.config/hunk/,
# so it applies in every project; a repo's own .hunk/config.toml still overrides it. Kit mode
# flattens COPY sources into shared/ by file name, so the source is hunk.toml, not config.toml
# (helix already uses that name).
# mkdir first so ~/.config/hunk is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/hunk
COPY --chown=agent:agent config/hunk/hunk.toml /home/agent/.config/hunk/config.toml

# Extension that shows a toast and rings the terminal bell when the agent comments or replies in a
# live review (see the file's header).
RUN mkdir -p ~/.config/hunk/extensions
COPY --chown=agent:agent config/hunk/agent-notify.ts /home/agent/.config/hunk/extensions/agent-notify.ts
