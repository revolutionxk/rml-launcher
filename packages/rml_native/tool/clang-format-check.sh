#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

mode="check"
arguments=(--dry-run --Werror)
if [[ "${1:-}" == "--fix" ]]; then
    mode="fix"
    arguments=(-i)
fi

objc_style="$(mktemp)"
trap 'rm -f "${objc_style}"' EXIT
sed 's/^Language: Cpp$/Language: ObjC/' .clang-format > "${objc_style}"

format() {
    local style="$1"
    shift
    find include src tests -type f \( "$@" \) -exec clang-format --style="file:${style}" "${arguments[@]}" {} +
}

format .clang-format -name '*.h' -o -name '*.hpp' -o -name '*.cpp'
format "${objc_style}" -name '*.mm'

if [[ "${mode}" == "fix" ]]; then
    echo "clang-format: applied."
else
    echo "clang-format: clean."
fi
