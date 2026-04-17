#!/bin/bash
set -eu

USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"

# Create group if it doesn't exist
if ! getent group "$USER_GID" > /dev/null 2>&1; then
    addgroup -g "$USER_GID" claude
fi
GROUP_NAME=$(getent group "$USER_GID" | cut -d: -f1)

# Create user if it doesn't exist
if ! getent passwd "$USER_UID" > /dev/null 2>&1; then
    adduser -D -u "$USER_UID" -G "$GROUP_NAME" -h /home/claude claude
fi
USER_NAME=$(getent passwd "$USER_UID" | cut -d: -f1)

# Ensure ownership of config, workspace, and home dirs (fresh PVC mounts are root-owned)
HOME_DIR=$(getent passwd "$USER_UID" | cut -d: -f6)
chown -R "$USER_UID:$USER_GID" /claude
chown -R "$USER_UID:$USER_GID" /workspace
chown -R "$USER_UID:$USER_GID" "$HOME_DIR"

# --- SSH host key persistence ---
# Keys are stored on the config PVC so the fingerprint stays stable across pod restarts.
SSH_HOST_KEY_DIR="/claude/ssh-host-keys"
mkdir -p "${SSH_HOST_KEY_DIR}"

if [ ! -f "${SSH_HOST_KEY_DIR}/ssh_host_ed25519_key" ]; then
    echo "[entrypoint] Generating SSH host keys (first run)..."
    ssh-keygen -t ed25519 -f "${SSH_HOST_KEY_DIR}/ssh_host_ed25519_key" -N ""
fi
if [ ! -f "${SSH_HOST_KEY_DIR}/ssh_host_rsa_key" ]; then
    ssh-keygen -t rsa -b 4096 -f "${SSH_HOST_KEY_DIR}/ssh_host_rsa_key" -N ""
fi
chmod 600 "${SSH_HOST_KEY_DIR}"/ssh_host_*_key
chmod 644 "${SSH_HOST_KEY_DIR}"/ssh_host_*_key.pub

# Set up authorized_keys from the mounted Secret
mkdir -p "${HOME_DIR}/.ssh"
cp /etc/ssh/authorized_keys "${HOME_DIR}/.ssh/authorized_keys"
chmod 700 "${HOME_DIR}/.ssh"
chmod 600 "${HOME_DIR}/.ssh/authorized_keys"
chown -R "$USER_UID:$USER_GID" "${HOME_DIR}/.ssh"

# Write a minimal sshd_config pointing to persistent host keys
cat > /etc/ssh/sshd_config <<EOF
Port 22
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PrintMotd no
AcceptEnv LANG LC_*
HostKey ${SSH_HOST_KEY_DIR}/ssh_host_ed25519_key
HostKey ${SSH_HOST_KEY_DIR}/ssh_host_rsa_key
EOF

# Start sshd in the background (runs as root; handles privilege drop on connect)
/usr/sbin/sshd
echo "[entrypoint] sshd started"

# Set HOME for the non-root user. su-exec does not change HOME, so without this
# Claude Code inherits HOME=/root and cannot find persisted auth tokens.
export HOME="$HOME_DIR"

# Keep-alive loop: restart claude if it exits (e.g. session timeout)
if [ "$1" = "claude" ]; then
    shift
    while true; do
        echo "[entrypoint] Starting Claude Code..."
        su-exec "$USER_UID:$USER_GID" claude "$@" || true
        echo "[entrypoint] Claude Code exited. Restarting in 5s..."
        sleep 5
    done
else
    exec su-exec "$USER_UID:$USER_GID" "$@"
fi
