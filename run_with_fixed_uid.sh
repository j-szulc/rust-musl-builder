#!/bin/bash
set -eu
set -o pipefail

# Script to run commands as a user with a specific UID
# Usage: run_with_fixed_id <USERNAME> <TARGET_UID> <COMMAND> [ARGS...]

# Function to display usage information
usage() {
    echo "Usage: $0 <USERNAME> <TARGET_UID> <COMMAND> [ARGS...]"
    echo "This script must be run as root"
    echo ""
    echo "  USERNAME    - Name for the user to create"
    echo "  TARGET_UID  - Numeric UID to assign to the user"
    echo "  COMMAND     - Command to execute as the created user"
    echo "  ARGS        - Optional arguments for the command"
    echo ""
    echo "Example:"
    echo "  $0 builder 1000 cargo --help"
    echo ""
    exit 1
}

# Check if we have at least 3 arguments
if [ $# -lt 3 ]; then
    echo "Error: Insufficient arguments provided." >&2
    echo "" >&2
    usage
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root" >&2
    exit 1
fi

USERNAME="$1"
TARGET_UID="$2"

# Validate that TARGET_UID is a number
if ! [[ "$TARGET_UID" =~ ^[0-9]+$ ]]; then
    echo "Error: TARGET_UID must be a numeric value, got: $TARGET_UID" >&2
    exit 1
fi

# Validate that USERNAME is not empty and contains valid characters
if [[ -z "$USERNAME" ]] || ! [[ "$USERNAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    echo "Error: USERNAME must start with a letter and contain only letters, numbers, underscores, and hyphens" >&2
    exit 1
fi

# Remove the first two arguments (USERNAME and TARGET_UID)
shift 2

# Validate root user consistency
is_root_user=[[ "$USERNAME" == "root" ]]
is_root_uid=[[ "$TARGET_UID" == "0" ]]

if $is_root_user && ! $is_root_uid; then
    echo "Error: Username 'root' must have UID 0, but got UID $TARGET_UID" >&2
    exit 1
elif $is_root_uid && ! $is_root_user; then
    echo "Error: UID 0 must be assigned to username 'root', but got username '$USERNAME'" >&2
    exit 1
elif $is_root_user && $is_root_uid; then
    echo "Running the command as root user: $*" >&2
    exec "$@"
    # Should be unreachable:
    exit 0
fi

# If we get here, we are not running as root user

echo "Creating user '$USERNAME' with UID $TARGET_UID..."

# Create the user with the specified UID
if ! useradd -u "$TARGET_UID" -s /bin/bash "$USERNAME" 2>/dev/null; then
    echo "Warning: User creation failed, user may already exist or UID may be in use" >&2
fi

# Add user to sudo group to allow passwordless sudo
usermod -aG sudo "$USERNAME" 2>/dev/null || {
    echo "Warning: Failed to add user '$USERNAME' to sudo group" >&2
}

echo "Setting ownership permissions..."

# Change ownership of key directories to the new user
chown -R "$USERNAME:$USERNAME" /bin /lib /lib64 /opt /root /sbin /var /home 2>/dev/null || {
    echo "Warning: Some ownership changes may have failed" >&2
}

echo "Running command as user '$USERNAME': $*"

# Execute the command as the specified user
exec sudo --preserve-env -u "$USERNAME" "$@"