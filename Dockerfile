# Use the official Rocky Linux 8 image as base
FROM rockylinux/rockylinux:8

ARG PRIVATE_KEY

USER root

# Store private key
RUN echo "$PRIVATE_KEY" > /root/.ssh/id_rsa && chmod 400 /root/.ssh/id_rsa

# Install necessary packages
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
    && dnf config-manager --set-enabled epel \
    && dnf -y update \
    && dnf install -y livecd-tools dracut-network lsof git \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Kickstart files are expected to be mounted via docker volumes
# Only use this if you don't trust docker volumes
# COPY kickstarts .