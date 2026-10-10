#!/usr/bin/env bash
# Builds zls against a copy of the installed Zig lib with patches/*.patch applied,
# then installs it to ~/.local/bin/zls (ahead of /usr/bin/zls on PATH).
#
# The patches change Zig's std (not zls), and zls compiles std.zig.Ast into its
# binary, so the fix only takes effect in a zls built against the patched copy.
#
# Usage: ./build-patched.sh [install-dir]   (default: ~/.local/bin)
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
install_dir=${1:-$HOME/.local/bin}

zig_version=$(zig version)
lib_dir=$(zig env | sed -n 's/^ *\.lib_dir = "\(.*\)",$/\1/p')
[ -d "$lib_dir" ] || { echo "could not find the Zig lib dir (got '$lib_dir')" >&2; exit 1; }

zls_version=$(sed -n 's/^ *\.version = "\(.*\)",$/\1/p' "$repo/build.zig.zon")
if [ "$zls_version" != "$zig_version" ]; then
    echo "warning: zls is $zls_version but zig is $zig_version; check out the matching zls tag first" >&2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "copying $lib_dir"
cp -a "$lib_dir" "$work/lib"
for p in "$repo"/patches/*.patch; do
    echo "applying $(basename "$p")"
    # --dry-run first so a patch that no longer fits leaves nothing half-applied.
    if ! patch -p1 -d "$work/lib" --forward --batch --dry-run --quiet < "$p"; then
        echo "error: $(basename "$p") doesn't apply to zig $zig_version; check whether upstream fixed it, or update the patch" >&2
        exit 1
    fi
    patch -p1 -d "$work/lib" --forward --batch --quiet < "$p"
done

echo "building zls (ReleaseSafe)"
(cd "$repo" && zig build -Doptimize=ReleaseSafe --zig-lib-dir "$work/lib" -p "$work/out")

mkdir -p "$install_dir"
install -m755 "$work/out/bin/zls" "$install_dir/zls"
echo "installed $install_dir/zls ($("$install_dir/zls" --version))"
echo "restart zls in your editor (:LspRestart) to use it"
