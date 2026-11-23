# Ships a default git config (identity, unsigned commits, aliases) as the user-level config. It goes
# to git's XDG path ~/.config/git/config rather than ~/.gitconfig, so anything that writes
# ~/.gitconfig at runtime cannot replace it (values set there still win). Kit mode flattens COPY sources into
# shared/ by file name, so this name must stay unique there.
# mkdir first so ~/.config/git is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/git
COPY --chown=agent:agent config/git/gitconfig /home/agent/.config/git/config

# Debian's git pages through `pager` (as do man and others), a link to less that the package's setup
# script normally registers. The base image installs packages without running those scripts, so
# the link is missing and `git diff` fails with "cannot run pager". Same fix as the vim links in
# apt-packages.dockerfile, but here, so adding it didn't rebuild the toolchain layers.
RUN sudo ln -sf /usr/bin/less /usr/local/bin/pager
