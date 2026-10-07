# Ships a default helix config (theme) as the user-level config in ~/.config/helix/, so it applies
# in every project; a project's own .helix/ still overrides it. Kit mode flattens COPY sources into
# shared/ by file name, so this name must stay unique there.
# mkdir first so ~/.config/helix is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/helix
COPY --chown=agent:agent config/helix/config.toml /home/agent/.config/helix/config.toml
