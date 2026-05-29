FROM gitpod/workspace-full:latest

# Atualizar pacotes
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-panel \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    novnc \
    websockify \
    tigervnc-server \
    tigervnc-common \
    firefox \
    dbus \
    dbus-x11 \
    xauth \
    x11-xserver-utils \
    pulseaudio \
    pactl \
    mesa-utils \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Desabilitar composição visual (mais leve para Gitpod)
RUN mkdir -p /etc/xdg/xfce4 && \
    echo "[xfwm4]" > /etc/xfwm4/xfwm4rc && \
    echo "use_compositing=FALSE" >> /etc/xfwm4/xfwm4rc

# Criar diretórios necessários
RUN mkdir -p /home/gitpod/.vnc \
    && mkdir -p /home/gitpod/.config/xfce4 \
    && mkdir -p /opt/litax/scripts \
    && chown -R gitpod:gitpod /home/gitpod/.vnc \
    && chown -R gitpod:gitpod /home/gitpod/.config

# Configurar VNC com password padrão (pode ser alterado)
RUN echo "gitpod" | vncpasswd -f > /home/gitpod/.vnc/passwd && \
    chmod 600 /home/gitpod/.vnc/passwd && \
    chown gitpod:gitpod /home/gitpod/.vnc/passwd

# Configurar XFCE para não mostrar composição
RUN mkdir -p /home/gitpod/.config/xfce4/xfconf/xfce-perchannel-xml && \
    echo '<?xml version="1.0" encoding="UTF-8"?>' > /home/gitpod/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml && \
    echo '<channel name="xfwm4" version="1.0">' >> /home/gitpod/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml && \
    echo '  <property name="use_compositing" type="bool" value="false"/>' >> /home/gitpod/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml && \
    echo '</channel>' >> /home/gitpod/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml && \
    chown -R gitpod:gitpod /home/gitpod/.config
