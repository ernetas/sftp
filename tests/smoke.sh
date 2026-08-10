#!/bin/bash
# Basic smoke test: boot the image, create a key-authenticated user, verify
# SFTP put/get works, and confirm the chroot jail actually contains them.
# Run from repo root: tests/smoke.sh <image:tag>
set -Eeuo pipefail

image="${1:?usage: smoke.sh <image:tag>}"
container="sftp-smoke-$$"
port=2255
user="smoketest"
workdir="$(mktemp -d)"

cleanup() {
    docker rm -f "$container" >/dev/null 2>&1 || true
    rm -rf "$workdir"
}
trap cleanup EXIT

ssh-keygen -t ed25519 -N '' -f "$workdir/id_test" -q
mkdir -p "$workdir/keys"
cp "$workdir/id_test.pub" "$workdir/keys/"

echo "Starting container from $image ..."
docker run -d --name "$container" -p "$port:22" \
    -v "$workdir/keys:/home/$user/.ssh/keys:ro" \
    "$image" "$user::1001::upload" >/dev/null

echo "Waiting for sshd to accept connections ..."
ready=false
for _ in $(seq 1 30); do
    if docker logs "$container" 2>&1 | grep -q "Server listening on 0.0.0.0 port 22"; then
        ready=true
        break
    fi
    sleep 1
done
if ! $ready; then
    echo "FAIL: sshd never reported ready"
    docker logs "$container" 2>&1
    exit 1
fi

sftp_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
    -i "$workdir/id_test" -P "$port")

echo "hello from smoke test" > "$workdir/upload.txt"

sftp "${sftp_opts[@]}" "$user@127.0.0.1" <<EOF
cd upload
put $workdir/upload.txt upload.txt
get upload.txt $workdir/download.txt
bye
EOF

diff "$workdir/upload.txt" "$workdir/download.txt"
echo "OK: upload/download round-trip matched"

# Confirm the chroot jail actually holds: nothing outside %h is reachable.
outside="$(sftp "${sftp_opts[@]}" "$user@127.0.0.1" <<EOF
ls /etc
EOF
)"
if echo "$outside" | grep -qi "passwd\|shadow"; then
    echo "FAIL: chroot escape — host /etc is visible to the sftp user"
    exit 1
fi
echo "OK: chroot jail holds"

docker logs "$container" 2>&1 | grep -qi "FATAL" && { echo "FAIL: fatal error in container logs"; exit 1; }
echo "PASS"
