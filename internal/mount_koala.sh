#!/usr/bin/env sh
# shellcheck shell=sh
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# mount_koala.sh
#
# This script creates a local mount point and mounts a PetaLibrary
# directory on CU Boulder Research Computing's HPC Cluster Alpine
# (aka "koala") into ~/mnt/koala using sshfs over SSH.
# It auto-detects macOS vs. Linux, installs sshfs (and macFUSE on macOS)
# if needed, and works under any POSIX shell (sh, bash, zsh, dash, etc.).
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

set -eu
# -e: exit immediately on any error
# -u: treat unset variables as an error

# Local directory where the PetaLibrary directory will be mounted
MOUNT_POINT="$HOME/mnt/koala"

# Alpine SSH login host
ALPINE_HOST="login.rc.colorado.edu"

# Path to the SSH private key used to authenticate to Alpine
IDENTITY_FILE="$HOME/.ssh/alpine"

# ────────────────────────────────────────────────────────────────────────────
# 1) Ensure the mount directory exists
# ────────────────────────────────────────────────────────────────────────────
if [ ! -d "$MOUNT_POINT" ]; then
    echo "→ Creating mount point directory: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
    # mkdir -p will also create any missing parent directories
fi

# If a previous (possibly stale/broken) mount is already attached here,
# sshfs will fail with a generic "mount failed with error: -1" and we'd
# rather unmount it first than leave a confusing failure.
if mount | grep -q " on $MOUNT_POINT "; then
    echo "→ $MOUNT_POINT is already mounted. Unmounting first..."
    if ! umount "$MOUNT_POINT" 2>/dev/null; then
        if command -v diskutil >/dev/null 2>&1; then
            diskutil unmount force "$MOUNT_POINT"
        elif command -v fusermount >/dev/null 2>&1; then
            fusermount -u "$MOUNT_POINT"
        fi
    fi
fi

# ────────────────────────────────────────────────────────────────────────────
# 2) Prompt for Alpine username and PetaLibrary directory
# ────────────────────────────────────────────────────────────────────────────
# NOTE: for CU Anschutz users, this will almost always take the form of an
# XSEDE-style identity: <your-rc-username>@xsede.org, rather than a plain
# CU Anschutz username.
printf "Alpine username (e.g. <your-rc-username>@xsede.org): " >/dev/tty
read -r ALPINE_USERNAME </dev/tty  # read from the terminal, not the script pipe
if [ -z "$ALPINE_USERNAME" ]; then
    echo "✗ Username cannot be empty." >&2
    exit 1
fi

printf "PetaLibrary directory (relative to /pl/active/): " >/dev/tty
read -r PETALIBRARY_DIR </dev/tty  # read from the terminal, not the script pipe
if [ -z "$PETALIBRARY_DIR" ]; then
    echo "✗ PetaLibrary directory cannot be empty." >&2
    exit 1
fi

if [ ! -f "$IDENTITY_FILE" ]; then
    echo "✗ SSH identity file not found at $IDENTITY_FILE." >&2
    echo "  Set up an SSH key for Alpine access and place it there," >&2
    echo "  or edit IDENTITY_FILE in this script to point at your key." >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────────────────────
# 3) Detect operating system, ensure sshfs is installed, and mount
# ────────────────────────────────────────────────────────────────────────────
OS="$(uname)"
case "$OS" in
    Darwin)
        # macOS branch
        echo "→ Detected macOS (Darwin). Verifying FUSE-T and sshfs are installed..."
        #
        # sshfs on macOS requires a FUSE implementation. FUSE-T is used here
        # instead of macFUSE because it doesn't need a kernel extension
        # (no reboot, no Privacy & Security approval step).
        #
        if ! command -v sshfs >/dev/null 2>&1; then
            echo "→ sshfs not found. Attempting installation via Homebrew..."
            if ! command -v brew >/dev/null 2>&1; then
                echo "✗ Homebrew not found. Please install FUSE-T and sshfs manually:" >&2
                echo "  https://github.com/macos-fuse-t/fuse-t" >&2
                exit 1
            fi
            # updating from deprecated tap macos-fuse-t/fuse-t
            # to macos-fuse-t/homebrew-cask
            brew tap macos-fuse-t/homebrew-cask
            brew install fuse-t fuse-t-sshfs

            # FUSE-T ships libfuse-t.dylib instead of the classic libfuse
            # name sshfs looks for, so symlink it in.
            if [ ! -e /usr/local/lib/libfuse.2.dylib ]; then
                sudo mkdir -p /usr/local/lib
                sudo ln -s /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
            fi
        fi
        ;;

    Linux)
        # Linux branch
        echo "→ Detected Linux. Verifying sshfs is installed..."
        #
        # sshfs is provided by the sshfs package (fuse-sshfs on some
        # distributions). If it's missing, we detect your package manager
        # and install it.
        #
        if ! command -v sshfs >/dev/null 2>&1; then
            echo "→ sshfs not found. Attempting installation..."
            if command -v apt-get >/dev/null 2>&1; then
                echo "   • Using apt-get to install sshfs"
                sudo apt-get update
                sudo apt-get install -y sshfs
            elif command -v dnf >/dev/null 2>&1; then
                echo "   • Using dnf to install fuse-sshfs"
                sudo dnf install -y fuse-sshfs
            elif command -v apk >/dev/null 2>&1; then
                echo "   • Using apk to install sshfs"
                sudo apk add sshfs
            else
                echo "✗ Unsupported package manager. Please install sshfs manually." >&2
                exit 1
            fi
        fi
        ;;

    *)
        # Unsupported OS
        echo "✗ Unsupported operating system: $OS" >&2
        exit 1
        ;;
esac

echo "→ Mounting PetaLibrary directory /pl/active/$PETALIBRARY_DIR via sshfs..."
if ! sshfs -o IdentityFile="$IDENTITY_FILE" \
    "$ALPINE_USERNAME@$ALPINE_HOST:/pl/active/$PETALIBRARY_DIR" \
    "$MOUNT_POINT"; then
    echo "✗ sshfs failed to mount /pl/active/$PETALIBRARY_DIR at $MOUNT_POINT." >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────────────────────
# 4) Success message
# ────────────────────────────────────────────────────────────────────────────
echo "✔ Successfully mounted /pl/active/$PETALIBRARY_DIR at $MOUNT_POINT"
