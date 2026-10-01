# Kit templates only (their descriptor declares com.docker.sandbox/sbx@1). sbx then launches
# the workload itself, under its own PID 1, so the base image's `tini --` entrypoint ends up as
# a child process and warns on every start that it can't reap zombies ("Tini is not running as
# PID 1 and isn't registered as a child subreaper"). Reaping is sbx's job here, so drop tini and
# use the same launch command as Docker's example shell kit (sandbox-kit-spec examples/shell):
# a login shell. Setting ENTRYPOINT clears the inherited CMD, hence both lines.
ENTRYPOINT ["bash"]
CMD ["-l"]
