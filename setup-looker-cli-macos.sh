#!/usr/bin/env bash
#
# Looker CLI setup for macOS
#
# What this does:
#   1. Downloads the Looker CLI
#   2. Checks that the download has not been altered
#   3. Installs it in a folder in your home directory
#   4. Creates and selects a Looker profile
#   5. Signs in once, then lists models using that profile
#
# Before running: update the settings in the next section.

set -euo pipefail

###############################################################################
# SETTINGS — edit these values if needed
###############################################################################

# Looker CLI release to install. Change this when you want a newer version.
LOOKER_CLI_VERSION="0.4.8"

# Your Mac type:
#   Apple Silicon (M1, M2, M3, M4, etc.): darwin_arm64
#   Intel Mac:                           darwin_amd64
LOOKER_CLI_PLATFORM="darwin_arm64"

# Official download location. Normally this does not need changing.
# Change it only if Looker publishes downloads somewhere different.
LOOKER_CLI_DOWNLOAD_BASE="https://github.com/looker-open-source/looker-cli/releases/download/v${LOOKER_CLI_VERSION}"

# Your Looker address — do not include https:// or a path.
# Example: company.cloud.looker.com or company.looker.app
MY_LOOKER_URL="YOUR-LOOKER.looker.com"

# The name for this saved Looker connection. It will be the default profile.
# Change it if you use more than one Looker instance on this Mac.
LOOKER_PROFILE_NAME="prod"

# Where Looker CLI will be installed. Change only if you prefer another folder.
INSTALL_DIR="${HOME}/looker-cli"

###############################################################################
# SETUP — no changes needed below this line
###############################################################################

if [[ "$MY_LOOKER_URL" == "YOUR-LOOKER.looker.com" || -z "$MY_LOOKER_URL" ]]; then
  printf 'Please set MY_LOOKER_URL near the top of this file, then run it again.\n' >&2
  exit 1
fi

ARCHIVE_NAME="looker-cli_${LOOKER_CLI_VERSION}_${LOOKER_CLI_PLATFORM}.tar.gz"
CHECKSUMS_NAME="looker-cli_${LOOKER_CLI_VERSION}_checksums.txt"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/looker-cli.XXXXXX")"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

printf 'Downloading Looker CLI %s for %s…\n' "$LOOKER_CLI_VERSION" "$LOOKER_CLI_PLATFORM"
curl --fail --location --silent --show-error \
  --output "$TEMP_DIR/$ARCHIVE_NAME" \
  "$LOOKER_CLI_DOWNLOAD_BASE/$ARCHIVE_NAME"
curl --fail --location --silent --show-error \
  --output "$TEMP_DIR/$CHECKSUMS_NAME" \
  "$LOOKER_CLI_DOWNLOAD_BASE/$CHECKSUMS_NAME"

# Check only the archive we downloaded, rather than every platform in the list.
if ! grep -E "[[:space:]]${ARCHIVE_NAME}$" "$TEMP_DIR/$CHECKSUMS_NAME" \
  > "$TEMP_DIR/selected-checksum.txt"; then
  printf 'Could not find a checksum for %s. Stopping for safety.\n' "$ARCHIVE_NAME" >&2
  exit 1
fi

printf 'Checking the download…\n'
(cd "$TEMP_DIR" && shasum -a 256 -c selected-checksum.txt)

printf 'Installing in %s…\n' "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TEMP_DIR/$ARCHIVE_NAME" -C "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/looker-cli"

printf 'Checking the installation…\n'
"$INSTALL_DIR/looker-cli" version

printf '\nSaving the %s profile for %s…\n' "$LOOKER_PROFILE_NAME" "$MY_LOOKER_URL"
cd "$INSTALL_DIR"
./looker-cli profile add "$LOOKER_PROFILE_NAME" \
  --host "$MY_LOOKER_URL" \
  --port 443
./looker-cli profile use "$LOOKER_PROFILE_NAME"

printf '\nYour browser will now open for a one-time Looker sign-in.\n'
printf 'After it finishes, the sign-in is saved in the %s profile.\n' "$LOOKER_PROFILE_NAME"
./looker-cli session login --oauth --profile "$LOOKER_PROFILE_NAME"

printf '\nListing Looker models using the saved default profile…\n'
./looker-cli model ls

printf '\nDone. Looker CLI is installed at %s/looker-cli\n' "$INSTALL_DIR"
printf 'The default profile is "%s". From that folder, try:\n' "$LOOKER_PROFILE_NAME"
printf '  ./looker-cli model ls      # List LookML models\n'
printf '  ./looker-cli user me       # Show your signed-in user\n'
printf '  ./looker-cli project ls    # List LookML projects\n'
printf '  ./looker-cli connection ls # List database connections\n'
printf '  ./looker-cli space top     # List top-level folders\n'
