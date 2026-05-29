#!/bin/bash

echo "======================================"
echo "  🖥️  VirtualDesk — Iniciando..."
echo "======================================"

# Mata processos anteriores se existirem
pkill Xvfb 2>/dev/null
pkill x11vnc 2>/dev/null
pkill websockify 2>/dev/null
sleep 1

# Inicia o display virtual (1280x720)
echo "▶ Iniciando display virtual..."
Xvfb :1 -screen 0 1280x720x24 -ac &
sleep 2

export DISPLAY=:1

# Inicia o XFCE (desktop leve)
echo "▶ Iniciando interface gráfica (XFCE)..."
dbus-launch --exit-with-session startxfce4 &
sleep 4

# Inicia o servidor VNC sem senha
echo "▶ Iniciando servidor VNC..."
x11vnc -display :1 -forever -nopw -shared -rfbport 5900 -quiet &
sleep 1

# Inicia o noVNC (acesso pelo browser)
echo "▶ Iniciando noVNC na porta 6080..."
websockify --web /usr/share/novnc 6080 localhost:5900 &

echo ""
echo "======================================"
echo "  ✅ Desktop pronto!"
echo "  🌐 Acesse pela porta 6080"
echo "  💡 Para sair: digite 'exit' no terminal"
echo "  💡 Para forçar saída: 'exit-forcado'"
echo "======================================"

# Mantém o script rodando
wait
