#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
EDITION="${1:-community}"
OUTPUT="${2:-$PROJECT_DIR/assets/AppIcon.png}"

case "${EDITION:l}" in
    community)
        SOURCE="$PROJECT_DIR/assets/Brand/NelyrCommunityMaster.png"
        ;;
    pro)
        SOURCE="$PROJECT_DIR/assets/Brand/NelyrProMaster.png"
        ;;
    *)
        echo "Usage: $0 [community|pro] [output.png]" >&2
        exit 2
        ;;
esac

if [[ ! -f "$SOURCE" ]]; then
    echo "Missing ${EDITION:l} brand master: $SOURCE" >&2
    if [[ "${EDITION:l}" == "pro" ]]; then
        echo "The Pro brand master is distributed separately from Nelyr Community." >&2
    fi
    exit 1
fi

sips -z 1024 1024 "$SOURCE" --out "$OUTPUT" >/dev/null
echo "$OUTPUT"
