#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: Python 3 is required to run the project checks." >&2
  exit 1
}
command -v zip >/dev/null 2>&1 || {
  echo "ERROR: zip is required to package the client mod." >&2
  exit 1
}

python3 -m unittest discover -s tests -v

if command -v lua5.3 >/dev/null 2>&1; then
  lua5.3 tests/lua/test_roster_manager.lua
  lua5.3 tests/lua/test_match_manager.lua
  lua5.3 tests/lua/test_server_adapter.lua
else
  echo "NOTE: lua5.3 not found; Lua logic tests are skipped locally."
fi

rm -rf dist
mkdir -p "dist/Resources/Server/Eliminator"
cp -R server-plugin/. "dist/Resources/Server/Eliminator/"
(
  cd client-mod
  zip -qr ../dist/Eliminator-client.zip .
)

printf '\nBuild completed:\n'
printf '  dist/Resources/Server/Eliminator\n'
printf '  dist/Eliminator-client.zip\n'
