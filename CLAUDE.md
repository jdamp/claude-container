# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repo contains Kubernetes manifests and a custom Docker image for running a persistent Claude Code CLI session inside a k3s homelab cluster. The session is accessible from the Claude Code mobile app via Anthropic's session sync infrastructure.

## Build & Deploy

**Build and push the image:**
```bash
docker build -t YOUR_REGISTRY/claude-code:latest ./claude-code
docker push YOUR_REGISTRY/claude-code:latest
```

**Deploy to the cluster (apply in order):**
```bash
kubectl apply -f claude-code/k8s/namespace.yaml
kubectl apply -f claude-code/k8s/
```

**First-time authentication (interactive OAuth):**
```bash
kubectl exec -it -n claude-code deploy/claude-code -c claude-code -- claude
```

**Reload Squid config after editing the allowlist:**
```bash
kubectl rollout restart deployment -n claude-code claude-code
```

## Architecture

The deployment lives in the `claude-code` namespace and consists of a single `Deployment` (1 replica, `Recreate` strategy) with two containers sharing a pod:

- **`claude-code` container** — Runs the Claude Code CLI. Proxies all egress traffic through the Squid sidecar via `HTTP_PROXY`/`HTTPS_PROXY` env vars. Mounts two PVCs:
  - `claude-config-pvc` (1Gi) at `/claude` — stores OAuth tokens (`CLAUDE_CONFIG_DIR`)
  - `claude-workspace-pvc` (10Gi) at `/workspace` — project files

- **`squid` sidecar** — Forward proxy listening on `localhost:3128`. Enforces a domain allowlist (`allowed-domains.txt` in the ConfigMap). All HTTPS uses `CONNECT` tunneling (no SSL bump). Logs to stdout.

The `entrypoint.sh` handles UID/GID remapping (via `USER_UID`/`USER_GID` env vars) and wraps the Claude Code process in a keep-alive loop that restarts it after a 5-second delay if it exits.

No ingress is needed for Claude Code session sync — the phone connects through Anthropic's infrastructure. SSH access is exposed separately via a NodePort Service (see below).

## SSH Access

SSH is available for direct terminal access from any WireGuard-connected client (e.g. phone via Termius/Blink).

**Connect:**
```bash
ssh -p 30022 claude@<node-ip>   # find node IP: kubectl get nodes -o wide
```

**Add or update public keys** — edit `claude-code/k8s/configmap-ssh.yaml` (which creates a Secret) then restart:
```bash
kubectl apply -f claude-code/k8s/configmap-ssh.yaml
kubectl rollout restart deployment -n claude-code claude-code
```

SSH host keys are stored on `claude-config-pvc` at `/claude/ssh-host-keys/` and persist across pod restarts. The fingerprint is stable; no `StrictHostKeyChecking` workaround is needed.

The `entrypoint.sh` starts `sshd` as root (required to bind port 22 and perform privilege drop on connect) before dropping to UID 1000 for the Claude Code process.

## Egress Allowlist

The Squid allowlist is managed via `claude-code/k8s/configmap-squid.yaml` under `allowed-domains.txt`. To add a domain, add it to that file and restart the deployment. Currently allowed categories:

- `*.anthropic.com`, `*.sentry.io`, `*.statsig.com` — Anthropic API and telemetry
- `*.github.com`, `*.githubusercontent.com` — Git
- `*.pypi.org`, `*.pythonhosted.org` — Python packages
- `*.typst.org` — Typst packages
- `*.alpinelinux.org` — Alpine system packages
- `*.npmjs.org`, `*.npmjs.com` — npm

## Key Configuration

| Setting | Value | Where |
|---|---|---|
| Claude config dir | `/claude` | `CLAUDE_CONFIG_DIR` env var |
| Squid proxy | `localhost:3128` | `HTTP_PROXY`/`HTTPS_PROXY` env vars |
| Deployment strategy | `Recreate` | Required for RWO PVCs |
| Service account token | disabled | `automountServiceAccountToken: false` |
| typst version | `0.13.1` | `ARG TYPST_VERSION` in Dockerfile |
| SSH NodePort | `30022` | `k8s/service-ssh.yaml` |
| SSH authorized keys | `k8s/configmap-ssh.yaml` (Secret) | mounted at `/etc/ssh/authorized_keys` |
| SSH host keys | `claude-config-pvc:/claude/ssh-host-keys/` | persisted across restarts |
