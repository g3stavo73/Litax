#!/bin/bash
pkill Xvfb 2>/dev/null || true
pkill x11vnc 2>/dev/null || true
pkill websockify 2>/dev/null || true
sleep 1
Xvfb :1 -screen 0 1280x720x24 -ac &
export DISPLAY=:1
sleep 2
dbus-launch --exit-with-session startxfce4 &
sleep 3
x11vnc -display :1 -forever -nopw -shared -rfbport 5900 -bg -quiet
sleep 1
websockify --web /usr/share/novnc 6080 localhost:5900
