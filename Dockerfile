FROM alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce

LABEL org.opencontainers.image.title="sftp" \
      org.opencontainers.image.description="Minimal, chroot-jailed SFTP server (based on atmoz/sftp)" \
      org.opencontainers.image.source="https://github.com/ernetas/sftp" \
      org.opencontainers.image.licenses="MIT"

# Steps done in one RUN layer:
# - Install upgrades and required packages only (no recommends/docs)
# - openssh-server-pam is required for authenticated chpasswd/PAM auth in create-sftp-user
# - OpenSSH needs /var/run/sshd to run
# - Remove generic host keys; entrypoint generates unique keys per container on first run
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache bash shadow openssh-server-pam openssh-sftp-server && \
    ln -s /usr/sbin/sshd.pam /usr/sbin/sshd && \
    mkdir -p /var/run/sshd && \
    rm -f /etc/ssh/ssh_host_*key*

COPY files/sshd_config /etc/ssh/sshd_config
COPY files/create-sftp-user /usr/local/bin/
COPY files/entrypoint /

RUN chmod 755 /entrypoint /usr/local/bin/create-sftp-user

EXPOSE 22

ENTRYPOINT ["/entrypoint"]
