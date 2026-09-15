#!/usr/bin/env sh
# shellcheck shell=sh
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# mount_bandicoot.sh
#
# This script creates a local mount point and mounts a CIFS/Samba share
# at //data.ucdenver.pvt/dept/SOM/DBMI/Bandicoot into ~/mnt/bandicoot.
# It auto-detects macOS vs. Linux, installs cifs-utils on Linux if needed,
# verifies VPN/network access, and works under any POSIX shell
# (sh, bash, zsh, dash, etc.).
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

set -eu
# -e: exit immediately on any error
# -u: treat unset variables as an error

# Remote share location (UNC path)
SHARE="//data.ucdenver.pvt/dept/SOM/DBMI/Bandicoot"
# Local directory where the share will be mounted
MOUNT_POINT="$HOME/mnt/bandicoot"

# ────────────────────────────────────────────────────────────────────────────
# 1) Ensure the mount directory exists
# ────────────────────────────────────────────────────────────────────────────
if [ ! -d "$MOUNT_POINT" ]; then
    echo "→ Creating mount point directory: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
    # mkdir -p will also create any missing parent directories
fi

# ────────────────────────────────────────────────────────────────────────────
# 2) Extract host from the UNC path and verify network/VPN access
# ────────────────────────────────────────────────────────────────────────────
# Strip leading '//' and everything after the first '/'
HOST="${SHARE#//}"
HOST="${HOST%%/*}"
echo "→ Checking network reachability to $HOST..."
# Try a single ping with 1s timeout; adjust flags if your ping differs
if ! ping -c 1 -W 1 "$HOST" >/dev/null 2>&1; then
    echo "✗ Unable to reach $HOST. Please ensure you're connected to VPN or network." >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────────────────────
# 3) Detect operating system and perform mount
# ────────────────────────────────────────────────────────────────────────────
OS="$(uname)"
case "$OS" in
    Darwin)
        # macOS branch
        echo "→ Detected macOS (Darwin). Using mount_smbfs."
        #
        # mount_smbfs is the built-in macOS SMB client.
        # It will prompt you for credentials if required,
        # or use your current login keychain.
        #
        # NOTE: mount_smbfs falls back to your local Mac shortname as the
        # SMB username if none is given in the UNC path. That shortname
        # frequently does NOT match your CU Anschutz/AD username, which
        # produces a generic "Authentication error" even with the correct
        # password. To avoid this, prompt for the CU Anschutz username the
        # same way the Linux branch does, and embed it in the share path.
        #
        printf "CU Anschutz username (for %s): " "$HOST" >/dev/tty
        read -r SMB_USERNAME </dev/tty  # read from the terminal, not the script pipe
        if [ -z "$SMB_USERNAME" ]; then
            echo "✗ Username cannot be empty." >&2
            exit 1
        fi

        SHARE_WITH_USER="//${SMB_USERNAME}@${SHARE#//}"
        mount_smbfs "$SHARE_WITH_USER" "$MOUNT_POINT"
        ;;

    Linux)
        # Linux branch
        echo "→ Detected Linux. Verifying cifs-utils (mount.cifs) is installed..."
        #
        # mount.cifs is provided by the cifs-utils package.
        # If it's missing, we detect your package manager and install it.
        #
        if ! command -v mount.cifs >/dev/null 2>&1; then
            echo "→ cifs-utils not found. Attempting installation..."
            if command -v apt-get >/dev/null 2>&1; then
                echo "   • Using apt-get to install cifs-utils"
                sudo apt-get update
                sudo apt-get install -y cifs-utils
            elif command -v yum >/dev/null 2>&1; then
                echo "   • Using yum to install cifs-utils"
                sudo yum install -y cifs-utils
            else
                echo "✗ Unsupported package manager. Please install cifs-utils manually." >&2
                exit 1
            fi
        fi

        # Prompt the user for their CIFS username
        printf "Isilon/CIFS username (CU Anschutz username): " >/dev/tty
        read -r CIFS_USERNAME </dev/tty  # read from the terminal, not the script pipe
        if [ -z "$CIFS_USERNAME" ]; then
            echo "✗ Username cannot be empty." >&2
            exit 1
        fi
        if [ -z "$USER" ]; then
            echo "USER not defined, please define" >&2
            exit 1
        fi
        # Mount the share with domainauto for automatic domain selection
        sudo mount -t cifs "$SHARE" "$MOUNT_POINT" \
            -o username="$CIFS_USERNAME",uid="$USER",gid="$USER",domainauto,file_mode=0777,dir_mode=0777
        ;;

    *)
        # Unsupported OS
        echo "✗ Unsupported operating system: $OS" >&2
        exit 1
        ;;
esac

# ────────────────────────────────────────────────────────────────────────────
# 4) Success message
# ────────────────────────────────────────────────────────────────────────────
echo "✔ Successfully mounted $SHARE at $MOUNT_POINT"
