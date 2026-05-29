FROM gitpod/workspace-base

USER root

RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    x11vnc \
    xvfb \
    novnc \
    websockify \
    firefox \
    dbus-x11 \
    fonts-liberation \
    net-tools \
    --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER gitpod
