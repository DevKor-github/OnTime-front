#!/usr/bin/env bash

SRCROOT="${SRCROOT:-$(pwd)}"

OUTPUT_FILE="${SRCROOT}/Flutter/Dart-Defines.xcconfig"
REQUIRED_RELEASE_DEFINES=("GOOGLE_RESERVED_CLIENT_ID_IOS" "REST_API_URL")

set -euo pipefail

mkdir -p "$(dirname "$OUTPUT_FILE")"
: > "$OUTPUT_FILE"

decode_base64() {
    local value="$1"

    if printf '%s' "$value" | base64 --decode >/dev/null 2>&1; then
        printf '%s' "$value" | base64 --decode
    else
        printf '%s' "$value" | base64 -D
    fi
}

is_release_configuration() {
    [[ "${CONFIGURATION:-}" == "Release" ]]
}

IFS=',' read -r -a define_items <<<"${DART_DEFINES:-}"

for index in "${!define_items[@]}"
do
    if [[ -z "${define_items[$index]}" ]]; then
        continue
    fi

    item=$(decode_base64 "${define_items[$index]}")

    lowercase_item=$(echo "$item" | tr '[:upper:]' '[:lower:]')
    if [[ $lowercase_item != flutter* ]]; then
        echo "$item" >> "$OUTPUT_FILE"
    fi
done

if is_release_configuration; then
    for required_define in "${REQUIRED_RELEASE_DEFINES[@]}"
    do
        if ! grep -Eq "^${required_define}=.+" "$OUTPUT_FILE"; then
            echo "error: Missing required iOS release dart define: ${required_define}" >&2
            echo "error: Pass it with --dart-define=${required_define}=<value> for release/archive builds." >&2
            exit 1
        fi
    done

    rest_api_url=$(grep -E "^REST_API_URL=" "$OUTPUT_FILE" | tail -n 1 | cut -d= -f2-)
    if [[ "$rest_api_url" != https://* ]]; then
        echo "error: iOS release REST_API_URL must use HTTPS." >&2
        echo "error: Received REST_API_URL=${rest_api_url}" >&2
        exit 1
    fi
fi
