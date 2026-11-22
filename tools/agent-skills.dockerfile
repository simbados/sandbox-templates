# Ships this repo's agent skills (shell-base/skills/<name>/SKILL.md) in the image. shell-base.yaml
# declares one com.docker.sandbox/agent-skill@1 entry per skill, and sbx exposes each at
# <destination>/<name> in every skills directory a kit in the sandbox declares
# (agent-skills@1; claude-mixin declares /home/agent/.claude/skills). The sources stay outside
# any discovery directory, since sbx assembles those itself.
COPY shell-base/skills /usr/share/shell-base/skills
