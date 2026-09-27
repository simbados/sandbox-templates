# Ships the global agent guidance (package-manager and network-access rules) so it applies
# regardless of which project directory a session starts in. The rules live in AGENTS.md so
# other agents can read them too; CLAUDE.md only imports it (`@AGENTS.md`, resolved relative to
# CLAUDE.md), which is why both files must land in the same directory.
RUN mkdir -p ~/.claude
COPY --chown=agent:agent config/CLAUDE.md config/AGENTS.md /home/agent/.claude/
