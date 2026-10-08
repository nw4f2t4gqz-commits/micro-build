#!/bin/bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
    echo "Usage: bash scripts/prepare-image.sh [output-directory]" >&2
    exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
output="${1:-prepared/SL-Micro-6.2}"

if [[ -e "$output" || -L "$output" ]]; then
    echo "Output already exists; refusing to overwrite: $output" >&2
    exit 1
fi

for tool in shasum patch xmllint; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found: $tool" >&2
        exit 1
    fi
done

printf '%s  %s\n' \
    d8e6a1de1d623d4304fbf446cced0ea5748865ecbe44d9483f65954d428ee86c upstream/SL-Micro-6.2/SL-Micro.kiwi \
    7694a175c73459358518517d2c4fd1651efa192325a10f1f4de8c0c5c6b9615d upstream/SL-Micro-6.2/config.sh \
    | shasum -a 256 -c -

mkdir -p "$(dirname "$output")"
cp -R upstream/SL-Micro-6.2 "$output"
patch --batch --fuzz=0 -p1 -d "$output" < patches/selfinstall-vmware-tools.patch
xmllint --noout "$output/SL-Micro.kiwi"
bash -n "$output/config.sh"

printf 'Prepared image description: %s\n' "$output"
echo "Not build-ready yet: replace obsrepositories:/ with verified local repositories."
echo "RPM signatures, dependencies, KIWI schema and Linux/ESXi runtime remain unverified."
