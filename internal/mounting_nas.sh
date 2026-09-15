#!/usr/bin/env sh
# shellcheck shell=sh
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# mounting_nas.sh
#
# Interactive entry point for mounting the lab's network storage.
# Prompts for which storage solution(s) to mount and delegates to
# mount_bandicoot.sh (Isilon, CIFS/SMB) and/or mount_koala.sh
# (PetaLibrary/Alpine, sshfs), which live alongside this script.
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

set -eu
# -e: exit immediately on any error
# -u: treat unset variables as an error

# shellcheck disable=SC1007
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BANDICOOT_SCRIPT="$SCRIPT_DIR/mount_bandicoot.sh"
KOALA_SCRIPT="$SCRIPT_DIR/mount_koala.sh"

for script in "$BANDICOOT_SCRIPT" "$KOALA_SCRIPT"; do
    if [ ! -f "$script" ]; then
        echo "✗ Expected script not found: $script" >&2
        exit 1
    fi
done

echo "Which NAS would you like to mount?"
echo "  1) bandicoot (Isilon)"
echo "  2) koala (PetaLibrary / Alpine)"
echo "  3) both"
printf "Enter choice [1-3]: " >/dev/tty
read -r CHOICE </dev/tty

case "$CHOICE" in
    1)
        sh "$BANDICOOT_SCRIPT"
        ;;
    2)
        sh "$KOALA_SCRIPT"
        ;;
    3)
        sh "$BANDICOOT_SCRIPT"
        sh "$KOALA_SCRIPT"
        ;;
    *)
        echo "✗ Invalid choice: $CHOICE" >&2
        exit 1
        ;;
esac
