#!/bin/bash

################################################################################
# Litax Desktop Startup Script
# Inicia VNC, noVNC e XFCE no Gitpod com logs e verificações de erro
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretórios
REPO_ROOT="${GITPOD_REPO_ROOT:-.}"
LOG_DIR="${REPO_ROOT}/logs"
RUN_DIR="/tmp/litax"
VNC_SOCKET="${RUN_DIR}/vnc.socket"
NOVNC_PID_FILE="${RUN_DIR}/novnc.pid"
VNC_PID_FILE="${RUN_DIR}/vnc.pid"
XFCE_PID_FILE="${RUN_DIR}/xfce.pid"

# Portas
VNC_PORT=5900
NOVNC_PORT=6080
DISPLAY=:99

# Log function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[${timestamp}]${NC} ${level}: ${message}" | tee -a "${LOG_DIR}/litax.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $@" | tee -a "${LOG_DIR}/litax.log"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $@" | tee -a "${LOG_DIR}/litax.log"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $@" | tee -a "${LOG_DIR}/litax.log"
}

# Limpeza ao sair
cleanup() {
    local exit_code=$?
    log_warning "Encerrando serviços..."
    
    [ -f "$XFCE_PID_FILE" ] && kill $(cat "$XFCE_PID_FILE") 2>/dev/null || true
    [ -f "$VNC_PID_FILE" ] && kill $(cat "$VNC_PID_FILE") 2>/dev/null || true
    [ -f "$NOVNC_PID_FILE" ] && kill $(cat "$NOVNC_PID_FILE") 2>/dev/null || true
    
    sleep 1
    pkill -9 Xvfb 2>/dev/null || true
    pkill -9 vncserver 2>/dev/null || true
    pkill -9 websockify 2>/dev/null || true
    
    rm -rf "$RUN_DIR"
    
    log_warning "Litax Desktop encerrado (code: $exit_code)"
    exit $exit_code
}

trap cleanup EXIT INT TERM

# ============================================================================
# INICIALIZAÇÃO
# ============================================================================

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════╗
║      🖥️  LITAX DESKTOP STARTUP        ║
║         XFCE + VNC + noVNC             ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Criar diretórios
mkdir -p "$LOG_DIR" "$RUN_DIR"
log "INFO" "Diretórios criados: $LOG_DIR, $RUN_DIR"

# ============================================================================
# 1. VERIFICAR DEPENDÊNCIAS
# ============================================================================

log "INFO" "Verificando dependências..."

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Comando não encontrado: $1"
        return 1
    fi
    log_success "$1 encontrado"
}

check_command "Xvfb" || exit 1
check_command "vncserver" || exit 1
check_command "websockify" || exit 1
check_command "firefox" || exit 1
check_command "xfce4-session" || exit 1

# ============================================================================
# 2. INICIAR XVFB (X11 Virtual Frame Buffer)
# ============================================================================

log "INFO" "Iniciando Xvfb no display $DISPLAY..."

if Xvfb "$DISPLAY" -screen 0 1280x720x24 -ac \
    -listen tcp \
    >> "${LOG_DIR}/xvfb.log" 2>&1 &
then
    XVFB_PID=$!
    log_success "Xvfb iniciado (PID: $XVFB_PID)"
    sleep 2
else
    log_error "Falha ao iniciar Xvfb"
    exit 1
fi

# ============================================================================
# 3. INICIAR VNC SERVER
# ============================================================================

log "INFO" "Iniciando VNC Server na porta $VNC_PORT..."

export DISPLAY=$DISPLAY
export XAUTHORITY=/tmp/.Xauthority

# Limpar configurações antigas
rm -rf /home/gitpod/.vnc/config >> "${LOG_DIR}/vnc.log" 2>&1 || true

if vncserver "$DISPLAY" \
    -geometry 1280x720 \
    -depth 24 \
    -rfbport $VNC_PORT \
    -SecurityTypes None \
    -desktop "Litax Desktop" \
    >> "${LOG_DIR}/vnc.log" 2>&1 &
then
    VNC_PID=$!
    echo $VNC_PID > "$VNC_PID_FILE"
    log_success "VNC Server iniciado (PID: $VNC_PID) na porta $VNC_PORT"
    sleep 2
else
    log_error "Falha ao iniciar VNC Server"
    exit 1
fi

# ============================================================================
# 4. INICIAR XFCE
# ============================================================================

log "INFO" "Iniciando XFCE4..."

# Desabilitar composição visual
dbus-launch xfce4-session \
    >> "${LOG_DIR}/xfce.log" 2>&1 &

XFCE_PID=$!
echo $XFCE_PID > "$XFCE_PID_FILE"
log_success "XFCE4 iniciado (PID: $XFCE_PID)"

sleep 3

# ============================================================================
# 5. INICIAR FIREFOX (em background)
# ============================================================================

log "INFO" "Iniciando Firefox..."

DISPLAY=$DISPLAY firefox \
    --new-instance \
    >> "${LOG_DIR}/firefox.log" 2>&1 &

FIREFOX_PID=$!
log_success "Firefox iniciado (PID: $FIREFOX_PID)"

# ============================================================================
# 6. INICIAR noVNC
# ============================================================================

log "INFO" "Iniciando noVNC na porta $NOVNC_PORT..."

# Download noVNC se não existir
if [ ! -d "/opt/noVNC" ]; then
    log "INFO" "Instalando noVNC..."
    mkdir -p /opt/noVNC
    cd /opt/noVNC
    git clone https://github.com/novnc/noVNC.git . >> "${LOG_DIR}/novnc_install.log" 2>&1 || \
        { log_error "Falha ao clonar noVNC"; exit 1; }
    cd -
fi

# Iniciar websockify
if websockify \
    --web=/opt/noVNC \
    --cert=/tmp/self.pem \
    $NOVNC_PORT \
    localhost:$VNC_PORT \
    >> "${LOG_DIR}/websockify.log" 2>&1 &
then
    NOVNC_PID=$!
    echo $NOVNC_PID > "$NOVNC_PID_FILE"
    log_success "noVNC iniciado (PID: $NOVNC_PID) na porta $NOVNC_PORT"
else
    log_error "Falha ao iniciar noVNC/websockify"
    exit 1
fi

sleep 2

# ============================================================================
# 7. VERIFICAR SAÚDE DOS SERVIÇOS
# ============================================================================

log "INFO" "Verificando saúde dos serviços..."

check_service() {
    local name=$1
    local port=$2
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        log_success "$name está respondendo na porta $port"
        return 0
    else
        log_warning "$name pode não estar respondendo na porta $port"
        return 1
    fi
}

check_service "VNC" $VNC_PORT || true
check_service "noVNC" $NOVNC_PORT || true

# ============================================================================
# 8. INFORMAÇÕES E INSTRUÇÕES
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ LITAX DESKTOP INICIADO COM SUCESSO!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}🔗 ACESSO:${NC}"
echo -e "  • noVNC (Browser): http://localhost:$NOVNC_PORT/vnc.html"
if [ -n "$GITPOD_WORKSPACE_URL" ]; then
    WORKSPACE_DOMAIN=$(echo $GITPOD_WORKSPACE_URL | sed 's|https://||' | cut -d'-' -f2-)
    NOVNC_URL="https://$NOVNC_PORT-${WORKSPACE_DOMAIN#-}"
    echo -e "  • noVNC (Gitpod):  $NOVNC_URL/vnc.html"
fi
echo -e "  • VNC Direct:      localhost:$VNC_PORT"

echo -e "\n${YELLOW}⌨️  ATALHOS:${NC}"
echo -e "  • /exit        - Encerrar desktop gracefully"
echo -e "  • /exit-forcado - Forçar encerramento imediato"

echo -e "\n${YELLOW}📊 PROCESSOS:${NC}"
echo -e "  • Xvfb:      PID $XVFB_PID"
echo -e "  • VNC:       PID $VNC_PID"
echo -e "  • XFCE:      PID $XFCE_PID"
echo -e "  • Firefox:   PID $FIREFOX_PID"
echo -e "  • noVNC:     PID $NOVNC_PID"

echo -e "\n${YELLOW}📝 LOGS:${NC}"
echo -e "  • $LOG_DIR/litax.log"
echo -e "  • $LOG_DIR/xvfb.log"
echo -e "  • $LOG_DIR/vnc.log"
echo -e "  • $LOG_DIR/xfce.log"
echo -e "  • $LOG_DIR/firefox.log"
echo -e "  • $LOG_DIR/websockify.log"

echo -e "\n${BLUE}💡 DICAS PARA CELULAR:${NC}"
echo -e "  • Use navegador em modo landscape"
echo -e "  • Toque 2x para zoom"
echo -e "  • Deslize com 2 dedos para mover"
echo -e "  • Botão direito: toque longo (1s)"

echo -e "\n${BLUE}Aguardando conexões... (Ctrl+C para encerrar)${NC}\n"

# ============================================================================
# 9. KEEP ALIVE
# ============================================================================

while true; do
    # Verificar se processos ainda estão rodando
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        log_error "Xvfb morreu. Encerrando..."
        exit 1
    fi
    
    if ! kill -0 $VNC_PID 2>/dev/null; then
        log_error "VNC Server morreu. Encerrando..."
        exit 1
    fi
    
    sleep 10
done
