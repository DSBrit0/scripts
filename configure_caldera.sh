#!/bin/bash
# =============================================================================
#  CALDERA — systemd Service Setup Script
#  Instala e configura o MITRE Caldera como serviço de produção
#  Validado em Ubuntu 24.04
# =============================================================================

set -euo pipefail

# ── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Configurações (edite conforme necessário) ─────────────────────────────────
CALDERA_DIR="${CALDERA_DIR:-/opt/caldera}"
CALDERA_USER="${CALDERA_USER:-root}"
CALDERA_PORT="${CALDERA_PORT:-8888}"
SERVICE_NAME="caldera"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PYTHON_BIN="$(which python3)"
SERVER_ARGS="--insecure"   # troque por --ssl para HTTPS

# ── Funções utilitárias ───────────────────────────────────────────────────────
log()     { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

# ── Verificações de pré-requisito ─────────────────────────────────────────────
section "Verificações iniciais"

[[ $EUID -ne 0 ]] && error "Execute como root: sudo $0"
ok "Executando como root"

[[ -d "$CALDERA_DIR" ]] || error "Diretório do Caldera não encontrado: $CALDERA_DIR\n       Defina CALDERA_DIR=/seu/caminho antes de rodar o script."
ok "Diretório encontrado: $CALDERA_DIR"

[[ -f "$CALDERA_DIR/server.py" ]] || error "server.py não encontrado em $CALDERA_DIR"
ok "server.py encontrado"

[[ -x "$PYTHON_BIN" ]] || error "python3 não encontrado no PATH"
ok "Python: $PYTHON_BIN"

# ── Criação do arquivo de serviço ─────────────────────────────────────────────
section "Criando arquivo de serviço systemd"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=MITRE Caldera Adversary Emulation Platform
Documentation=https://github.com/mitre/caldera
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=${CALDERA_USER}
WorkingDirectory=${CALDERA_DIR}
ExecStart=${PYTHON_BIN} server.py ${SERVER_ARGS}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=caldera

# Limites de recursos
LimitNOFILE=65536

# Variáveis de ambiente opcionais
# Environment="HTTP_PROXY=http://proxy:3128"

[Install]
WantedBy=multi-user.target
EOF

ok "Arquivo criado: $SERVICE_FILE"

# ── Habilitando e iniciando o serviço ─────────────────────────────────────────
section "Configurando serviço"

systemctl daemon-reload
ok "daemon recarregado"

systemctl enable "$SERVICE_NAME"
ok "Serviço habilitado (inicia com o sistema)"

systemctl restart "$SERVICE_NAME"
sleep 2

# ── Status final ──────────────────────────────────────────────────────────────
section "Status do serviço"

if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "Caldera está RODANDO"
else
    warn "Caldera pode não ter iniciado — verifique os logs abaixo"
fi

systemctl status "$SERVICE_NAME" --no-pager -l

# ── Comandos úteis ────────────────────────────────────────────────────────────
section "Comandos úteis"
echo -e "  ${CYAN}Logs em tempo real:${RESET}  journalctl -u caldera -f"
echo -e "  ${CYAN}Parar serviço:${RESET}       systemctl stop caldera"
echo -e "  ${CYAN}Reiniciar:${RESET}           systemctl restart caldera"
echo -e "  ${CYAN}Desabilitar:${RESET}         systemctl disable caldera"
echo -e "  ${CYAN}Interface web:${RESET}       http://$(hostname -I | awk '{print $1}'):${CALDERA_PORT}"
echo ""
ok "Setup concluído!"
