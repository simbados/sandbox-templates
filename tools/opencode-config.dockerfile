# Creates OpenCode's config directory agent-owned for `sbx-up opencode`. sbx mounts the shared
# skills at ~/.config/opencode/skills (opencode-mixin's agent-skills@1); without this the mount
# creates ~/.config/opencode root-owned, and the mixin's startup step, which writes
# opencode.json there as agent, fails with exit code 2.
RUN mkdir -p ~/.config/opencode
