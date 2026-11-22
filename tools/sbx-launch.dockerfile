# Kit templates only (their descriptor declares com.docker.sandbox/sbx@1). sbx launches the
# workload with the image's ENTRYPOINT plus any arguments after `--`. sbx/shell's own entrypoint
# is `bash -c 'exec "$@"' bash`, which expects a whole command, but sbx-up passes bash options
# (`-lc 'exec fish -l'`, `-lc 'claude ...'`). So use a plain bash entrypoint, like Docker's
# example shell kit (sandbox-kit-spec examples/shell): no arguments give a login shell, and
# sbx-up's arguments run inside one. Setting ENTRYPOINT clears the inherited CMD, hence both lines.
ENTRYPOINT ["bash"]
CMD ["-l"]
