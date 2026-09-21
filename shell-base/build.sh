#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="simbados/shell-base"
NAME="shell-base"
TAR="shell-base/${NAME}.tar"

docker build -t "$IMAGE" -f shell-base/Dockerfile .
docker image save "$IMAGE" -o "$TAR"
sbx template load "$TAR"
#sbx run --name "$NAME" --template "$IMAGE" "$NAME"

rm -f "$TAR"
