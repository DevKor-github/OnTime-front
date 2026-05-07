#!/usr/bin/env bash

set -euo pipefail

if [[ "${CONFIGURATION:-}" != "Release" ]]; then
    exit 0
fi

required_scheme="${GOOGLE_RESERVED_CLIENT_ID_IOS:-}"
info_plist="${TARGET_BUILD_DIR:-}/${INFOPLIST_PATH:-}"

if [[ -z "$required_scheme" || "$required_scheme" == *'$('* ]]; then
    echo "error: GOOGLE_RESERVED_CLIENT_ID_IOS is not resolved for the iOS release build." >&2
    echo "error: Pass --dart-define=GOOGLE_RESERVED_CLIENT_ID_IOS=<value> before archiving." >&2
    exit 1
fi

if [[ ! -f "$info_plist" ]]; then
    echo "error: Built Info.plist not found at ${info_plist}." >&2
    exit 1
fi

if ! /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$info_plist" \
    | grep -Fq "$required_scheme"; then
    echo "error: Built Info.plist does not contain the Google Sign-In URL scheme." >&2
    echo "error: Expected CFBundleURLTypes to include: ${required_scheme}" >&2
    exit 1
fi

arbitrary_loads=$(/usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" "$info_plist" 2>/dev/null || true)
if [[ "$arbitrary_loads" == "true" || "$arbitrary_loads" == "1" || "$arbitrary_loads" == "YES" ]]; then
    echo "error: iOS release Info.plist must not allow arbitrary ATS loads." >&2
    echo "error: Remove NSAppTransportSecurity:NSAllowsArbitraryLoads from the release plist." >&2
    exit 1
fi
