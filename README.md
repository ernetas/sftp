# sftp

A minimal, chroot-jailed SFTP server image, based on
[atmoz/sftp](https://github.com/atmoz/sftp) (MIT licensed).

Image: `ghcr.io/ernetas/sftp:latest`

## What this is

An Alpine-based OpenSSH server that only allows SFTP (no shell, no TCP/agent
forwarding), with each user chrooted into their own home directory. Users are
created at container start from a config file, environment variable, or
CLI arguments.

## Differences from upstream atmoz/sftp

- Base image pinned by digest (`alpine:3.22@sha256:...`) instead of a
  floating tag, so builds are reproducible and only move forward via
  Dependabot-reviewed PRs.
- Dropped the `HostKeyAlgorithms +ssh-rsa` legacy compatibility line — this
  container does not accept SHA-1-based `ssh-rsa` host key signatures.
- Added `AllowAgentForwarding no` and `PermitTunnel no` for defense in depth
  (neither is needed for pure SFTP).
- CI publishes multi-arch (amd64/arm64) images to GHCR with SBOM,
  provenance attestation, and a Trivy vulnerability gate on every build.

## Usage

```bash
docker run -p 2222:22 -d ghcr.io/ernetas/sftp:latest \
    someuser:somepassword:1001
```

```bash
docker run -p 2222:22 -d \
    -v /host/upload:/home/someuser/upload \
    ghcr.io/ernetas/sftp:latest \
    someuser:somepassword:1001
```

Or mount a users config file at `/etc/sftp/users.conf`
(one `user:pass[:e]:uid:gid:dir1,dir2` per line) or set `SFTP_USERS`.
See [atmoz/sftp's README](https://github.com/atmoz/sftp#usage) for the full
option reference — the entrypoint and user-creation script here are
unmodified from upstream.

### SSH key auth

Mount public keys into `/home/<user>/.ssh/keys/` before first start; they're
merged into `authorized_keys` by `create-sftp-user`.

## Security notes

- Containers must run with the default (root) user — sshd needs root to
  chroot and drop privileges per-connection. Don't run this with
  `--user`/non-root or it will fail to start.
- Host keys are generated uniquely per container on first run and persisted
  only if `/etc/ssh` is mounted as a volume — mount it if you want stable
  host keys across recreations.
- Images are rebuilt weekly even without a source change, to pick up Alpine
  security patches, and scanned with Trivy before every push.

## Building locally

```bash
docker build -t sftp .
```
