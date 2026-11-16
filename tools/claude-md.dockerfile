# Ships the global agent guidance (package-manager and network-access rules) so it applies
# regardless of which project directory a session starts in. The rules live in AGENTS.md so
# other agents can read them too; CLAUDE.md only imports it (`@AGENTS.md`, resolved relative to
# CLAUDE.md), which is why both files must land in the same directory.
RUN mkdir -p ~/.claude
COPY --chown=agent:agent config/CLAUDE.md config/AGENTS.md /home/agent/.claude/

# Claude Code's classic renderer instead of its fullscreen one, which became the default when the
# `tui` setting is unset. Fullscreen captures the mouse, so drags no longer reach tmux copy mode
# on the host, and its own copy (OSC 52) does not arrive through sbx and tmux: copy-paste breaks.
# Same as `"tui": "default"` in settings.json, which claude-mixin seeds; the variable beats the
# setting, so `/tui fullscreen` only lasts with CLAUDE_CODE_NO_FLICKER=1 set for that session.
ENV CLAUDE_CODE_NO_FLICKER=0
