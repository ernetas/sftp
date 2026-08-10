# sftp

A minimal, chroot-jailed SFTP server image, based on
[atmoz/sftp](https://github.com/atmoz/sftp) (MIT licensed).

Image: `ghcr.io/ernetas/sftp:latest` (mirrored to `docker.io/ernestas/sftp:latest`)

## What this is

An Alpine-based OpenSSH server that only allows SFTP (no shell, no TCP/agent
forwarding), with each user chrooted into their own home directory. Users are
created at container start from a config file, environment variable, or
CLI arguments.

## Differences from upstream atmoz/sftp

- Base image pinned by digest (`alpine:3.22@sha256:...`) instead of a
  floating tag, so builds are reproducible and only move forward via
  reviewed, CI-gated PRs (see Autoupdate below).
- Dropped the `HostKeyAlgorithms +ssh-rsa` legacy compatibility line — this
  container does not accept SHA-1-based `ssh-rsa` host key signatures.
- Added `AllowAgentForwarding no` and `PermitTunnel no` for defense in depth
  (neither is needed for pure SFTP).
- CI publishes multi-arch (amd64/arm64) images to GHCR (and Docker Hub) with
  provenance attestation and a Trivy vulnerability gate on every build.

## Autoupdate

[Renovate](https://docs.renovatebot.com/) watches the pinned base image
digest and the SHA-pinned GitHub Actions in this repo. When an update is
available it opens a PR that retargets the pin — which triggers this repo's
own CI (build, boot the image, SFTP round-trip test, Trivy critical/high
scan) against the *proposed* change. Renovate only auto-merges the PR if
every one of those checks passes; a failing smoke test or a new critical CVE
blocks the merge instead. The image is also rebuilt weekly regardless
(`.github/workflows/docker-publish.yml`, Monday 04:17 UTC) to pick up Alpine
package patches that don't require a digest bump.

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

## Building locally

```bash
docker build -t sftp .
```
