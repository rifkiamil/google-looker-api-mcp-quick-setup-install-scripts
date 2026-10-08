#!/bin/sh
#
# One-time MCP Toolbox + Looker setup for macOS (Apple Silicon or Intel).
# Run: sh setup-mcp-toolbox-looker-macos.sh
# Afterwards, use the printed Toolbox commands directly.
#
# This script installs a verified Toolbox binary in ~/mcp-looker and creates
# ~/.config/mcp-toolbox-looker/looker_env. It does not leave a server running.
# After setup, source the credentials file in each new Terminal session and
# run Toolbox directly. A Looker API key (client ID and secret) is required.
#
# For another release, update the version AND both SHA256 hashes together from
# https://github.com/googleapis/mcp-toolbox/releases

set -eu
umask 077

###############################################################################
# RELEASE SETTINGS — update the version and BOTH hashes from the official page
# https://github.com/googleapis/mcp-toolbox/releases
###############################################################################
TOOLBOX_VERSION="1.13.1"
SHA256_DARWIN_ARM64="fb14fd0692c777d14e45fbebeebd7907564a0e3a1942c55a8829cfd9423f012b"
SHA256_DARWIN_AMD64="b26129f5773312d071fc28b060ca203843798caa5f82d2a123914907572dfde6"
RELEASES_URL="https://github.com/googleapis/mcp-toolbox/releases"
DOWNLOAD_ROOT="https://storage.googleapis.com/mcp-toolbox-for-databases"
INSTALL_DIR="${HOME}/mcp-looker"
CREDS_DIR="${HOME}/.config/mcp-toolbox-looker"
CREDS_FILE="${CREDS_DIR}/looker_env"

if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ -z "${NO_COLOR:-}" ]; then
  GREEN=$(printf '\033[32m'); YELLOW=$(printf '\033[33m')
  RED=$(printf '\033[31m'); CYAN=$(printf '\033[36m')
  BOLD=$(printf '\033[1m'); RESET=$(printf '\033[0m')
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; BOLD=''; RESET=''
fi
ok()   { printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[WARNING]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
step() { printf '\n%s%s%s\n' "$BOLD" "$*" "$RESET"; }
cmd()  { printf '  %s%s%s\n' "$CYAN" "$*" "$RESET"; }
cleanup() {
  if [ "${ECHO_OFF:-0}" -eq 1 ]; then stty echo 2>/dev/null || :; fi
  if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then rm -rf "$TEMP_DIR"; fi
  if [ -n "${TEMP_CREDS:-}" ] && [ -f "$TEMP_CREDS" ]; then rm -f "$TEMP_CREDS"; fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

for needed in curl shasum uname mktemp stty sed mkdir chmod mv; do
  command -v "$needed" >/dev/null 2>&1 || die "Missing command: $needed. Install macOS command line tools and rerun."
done
[ "$(uname -s)" = Darwin ] || die "This installer supports macOS only."
case "$(uname -m)" in
  arm64)  PLATFORM=arm64; EXPECTED_SHA256=$SHA256_DARWIN_ARM64 ;;
  x86_64) PLATFORM=amd64; EXPECTED_SHA256=$SHA256_DARWIN_AMD64 ;;
  *) die "Unsupported Mac architecture. Check $RELEASES_URL for a matching download." ;;
esac

# Make a single-quoted shell value, including embedded quotes and shell symbols.
quote_sh() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

step "1. Looker credentials"
if [ -e "$CREDS_FILE" ]; then
  warn "A credentials file already exists at $CREDS_FILE."
  printf 'Replace it? [y/N]: '
  IFS= read -r ANSWER || die "Could not read your answer."
  case "$ANSWER" in
    y|Y|yes|YES) : ;;
    *) ok "Keeping your existing credentials file."; KEEP_CREDS=1 ;;
  esac
fi

if [ "${KEEP_CREDS:-0}" -ne 1 ]; then
  printf 'Looker base URL (for example https://company.cloud.looker.com or https://company.cloud.looker.com:19999): '
  IFS= read -r LOOKER_BASE_URL || die "Could not read the Looker URL."
  case "$LOOKER_BASE_URL" in
    https://*) : ;;
    *) die "Use a full https:// Looker URL. Check the API hostname and optional port in your Looker settings." ;;
  esac
  HOST_PORT=${LOOKER_BASE_URL#https://}
  case "$HOST_PORT" in
    ''|*/*|*\?*|*\#*|*\@*|*' '*|*'\t'*|*'\n'*)
      die "Enter the base URL only: https://hostname with an optional :port, without a path or query." ;;
  esac
  case "$HOST_PORT" in
    *[!A-Za-z0-9.:-]*|:*|*:) die "The Looker URL contains an invalid hostname or port." ;;
  esac
  printf 'Looker API client ID: '
  IFS= read -r LOOKER_CLIENT_ID || die "Could not read the client ID."
  [ -n "$LOOKER_CLIENT_ID" ] || die "The client ID cannot be empty."
  printf 'Looker API client secret (input hidden): '
  if [ -t 0 ]; then
    stty -echo || die "Could not hide secret input. Run in an interactive Terminal."
    ECHO_OFF=1
  else
    die "Run in an interactive Terminal so the secret can be entered privately."
  fi
  IFS= read -r LOOKER_CLIENT_SECRET || die "Could not read the client secret."
  stty echo || die "Could not restore Terminal echo. Run: stty echo"
  ECHO_OFF=0
  printf '\n'
  [ -n "$LOOKER_CLIENT_SECRET" ] || die "The client secret cannot be empty."
  mkdir -p "$CREDS_DIR" || die "Could not create $CREDS_DIR. Check folder permissions."
  TEMP_CREDS=$(mktemp "$CREDS_DIR/.looker_env.XXXXXX") || die "Could not prepare the credentials file."
  {
    printf '# Source this file in your shell before running MCP Toolbox.\n'
    printf 'export LOOKER_BASE_URL='; quote_sh "$LOOKER_BASE_URL"; printf '\n'
    printf 'export LOOKER_CLIENT_ID='; quote_sh "$LOOKER_CLIENT_ID"; printf '\n'
    printf 'export LOOKER_CLIENT_SECRET='; quote_sh "$LOOKER_CLIENT_SECRET"; printf '\n'
  } > "$TEMP_CREDS" || die "Could not write credentials."
  chmod 600 "$TEMP_CREDS" || die "Could not restrict credentials file permissions."
  mv -f "$TEMP_CREDS" "$CREDS_FILE" || die "Could not save credentials."
  ok "Credentials saved with user-only permissions at $CREDS_FILE."
  warn "This file contains your API secret. Do not share or commit it."
fi

step "2. Download and verify MCP Toolbox"
DOWNLOAD_URL="$DOWNLOAD_ROOT/v$TOOLBOX_VERSION/darwin/$PLATFORM/toolbox"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mcp-toolbox.XXXXXX") || die "Could not create a temporary folder."
printf 'Version %s for darwin/%s\n' "$TOOLBOX_VERSION" "$PLATFORM"
printf 'Download: %s\n' "$DOWNLOAD_URL"
if ! curl --fail --location --silent --show-error --output "$TEMP_DIR/toolbox" "$DOWNLOAD_URL"; then
  warn "Download failed; no new Toolbox binary was installed."
  printf 'Check your internet connection and the official release page: %s\n' "$RELEASES_URL" >&2
  die "If this version is unavailable, update TOOLBOX_VERSION and the two SHA256 values from the same official release, then rerun."
fi
ACTUAL_SHA256=$(shasum -a 256 "$TEMP_DIR/toolbox" | sed 's/ .*//') || die "Could not calculate SHA-256; nothing was installed."
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  warn "SHA-256 mismatch. The downloaded binary will NOT be installed or run."
  printf '  Version/platform: v%s darwin/%s\n' "$TOOLBOX_VERSION" "$PLATFORM" >&2
  printf '  Expected: %s\n  Downloaded: %s\n' "$EXPECTED_SHA256" "$ACTUAL_SHA256" >&2
  printf '  Next: compare the version, Mac architecture, and published SHA-256 at:\n  %s\n' "$RELEASES_URL" >&2
  printf '  If the official release changed, update TOOLBOX_VERSION and BOTH SHA256 values\n  in this .sh file from that same release, then rerun.\n' >&2
  die "Do not copy the downloaded hash into the script just to silence this warning."
fi
ok "SHA-256 matches the published hash for v$TOOLBOX_VERSION darwin/$PLATFORM."
chmod 755 "$TEMP_DIR/toolbox" || die "Could not make the verified binary executable."
"$TEMP_DIR/toolbox" --version || die "The verified binary did not start. Existing installation was not replaced."
mkdir -p "$INSTALL_DIR" || die "Could not create $INSTALL_DIR. Check folder permissions."
mv -f "$TEMP_DIR/toolbox" "$INSTALL_DIR/toolbox" || die "Could not install Toolbox into $INSTALL_DIR."
ok "Toolbox installed at $INSTALL_DIR/toolbox."

step "3. What to run next"
printf 'Paste one of these in a new Terminal. You do not need this setup script again.\n\n'
printf '%sOne-shot Looker test (runs get_models, then exits):%s\n' "$BOLD" "$RESET"
cmd 'source ~/.config/mcp-toolbox-looker/looker_env && cd ~/mcp-looker && ./toolbox --prebuilt looker invoke get_models'
printf '\n%sStart the HTTP MCP server (leave this Terminal open):%s\n' "$BOLD" "$RESET"
cmd 'source ~/.config/mcp-toolbox-looker/looker_env && cd ~/mcp-looker && ./toolbox --prebuilt looker'
printf '\n%sIn a second Terminal, check the server:%s\n' "$BOLD" "$RESET"
cmd 'curl -i http://127.0.0.1:5000/healthz'
printf 'Expected response body: %s{"status":"ok"}%s\n' "$GREEN" "$RESET"
printf 'The health check confirms the server is running; get_models also checks Looker access.\n'
ok "Setup complete."
