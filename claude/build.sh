#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="simbados/claude"
NAME="claude"
TAR="claude/${NAME}.tar"

docker build -t "$IMAGE" -f claude/Dockerfile .
docker image save "$IMAGE" -o "$TAR"
sbx template load "$TAR"
#sbx run --name "$NAME" --template "$IMAGE" "$NAME"

rm -f "$TAR"
