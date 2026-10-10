# Ships a default git config (identity, unsigned commits, aliases) as the user-level config. It goes
# to git's XDG path ~/.config/git/config rather than ~/.gitconfig, so anything that writes
# ~/.gitconfig at runtime cannot replace it (values set there still win). Kit mode flattens COPY sources into
# shared/ by file name, so this name must stay unique there.
# mkdir first so ~/.config/git is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/git
COPY --chown=agent:agent config/git/gitconfig /home/agent/.config/git/config
