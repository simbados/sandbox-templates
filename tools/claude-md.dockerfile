# Ships Claude Code's global user memory (~/.claude/CLAUDE.md) so its
# package-manager and network-access guidance applies regardless of which
# project directory a session starts in.
RUN mkdir -p ~/.claude
COPY --chown=agent:agent config/CLAUDE.md /home/agent/.claude/CLAUDE.md
