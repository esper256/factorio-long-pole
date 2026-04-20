#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

detect_factorio_bin() {
  local candidates=(
    "${FACTORIO_BIN:-}"
    "$HOME/.steam/steam/steamapps/common/Factorio/bin/x64/factorio"
    "$HOME/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio"
    "$HOME/factorio/bin/x64/factorio"
    "/usr/bin/factorio"
    "/usr/local/bin/factorio"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

factorio_bin="$(detect_factorio_bin || true)"
if [[ -z "$factorio_bin" ]]; then
  echo "Could not find a Factorio client binary."
  echo "Set FACTORIO_BIN=/path/to/factorio and rerun."
  exit 1
fi

if [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: tests/gui_smoke_test.sh

Environment:
  FACTORIO_BIN=/path/to/factorio   Override Factorio client binary
  XVFB_RUN=0                       Disable auto-use of xvfb-run when DISPLAY is unset

This test creates an isolated temporary Factorio user-data directory, installs the
current mod checkout there, enables a test-only flag that opens and closes the
plan editor once, creates a fresh save, then loads it for 1 tick.
It fails on Factorio process errors or if the log contains a mod runtime error.
EOF
  exit 0
fi

mod_name="$(sed -n 's/^[[:space:]]*"name":[[:space:]]*"\([^"]*\)".*/\1/p' "$repo_root/info.json" | head -n1)"
mod_version="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$repo_root/info.json" | head -n1)"

if [[ -z "$mod_name" || -z "$mod_version" ]]; then
  echo "Unable to parse mod name/version from info.json"
  exit 1
fi

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/long-pole-gui-smoke.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT

user_data_dir="$temp_root/user-data"
mods_dir="$user_data_dir/mods"
saves_dir="$user_data_dir/saves"
mod_dir="$mods_dir/${mod_name}_${mod_version}"
log_file="$user_data_dir/factorio-current.log"
save_file="$saves_dir/gui-smoke-test.zip"
config_file="$temp_root/config.ini"

mkdir -p "$mods_dir" "$saves_dir" "$mod_dir"

cat > "$config_file" <<EOF
[path]
read-data=__PATH__executable__/../../data
write-data=$user_data_dir
EOF

rsync -a \
  --exclude='.git' \
  --exclude='.codex' \
  --exclude='.vscode' \
  --exclude='*.zip' \
  --exclude='factorio-current.log' \
  "$repo_root/" "$mod_dir/"

mkdir -p "$mod_dir/test_support"
cat > "$mod_dir/test_support/runtime_flags.lua" <<EOF
return {
  gui_smoke_open_and_close_editor = true
}
EOF

run_factorio() {
  local -a cmd=("$factorio_bin" --config "$config_file" --mod-directory "$mods_dir" --disable-audio --no-log-rotation "$@")

  if [[ -z "${DISPLAY:-}" && "${XVFB_RUN:-1}" != "0" ]] && command -v xvfb-run >/dev/null 2>&1; then
    xvfb-run -a "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
}

find_in_log() {
  local pattern="$1"

  if command -v rg >/dev/null 2>&1; then
    rg -n -C 3 "$pattern" "$log_file"
    return $?
  fi

  grep -n -E -C 3 "$pattern" "$log_file"
}

echo "Using Factorio binary: $factorio_bin"
echo "Creating temporary save: $save_file"
run_factorio --create "$save_file"

echo "Loading save for GUI smoke test"
run_factorio --load-game "$save_file" --until-tick 1

if [[ ! -f "$log_file" ]]; then
  echo "Expected log file was not produced: $log_file"
  exit 1
fi

if find_in_log "caused a non-recoverable error|Error while running event|stack traceback:" >/dev/null; then
  echo "GUI smoke test failed; Factorio reported a runtime error:"
  find_in_log "caused a non-recoverable error|Error while running event|stack traceback:"
  exit 1
fi

echo "GUI smoke test passed"
