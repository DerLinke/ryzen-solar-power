#!/bin/bash
# ==============================================================================
# 🚀 ryzen-solar-power Installer v1.0.0
# ------------------------------------------------------------------------------
# Automatisiert die Installation von RyzenAdj und die Konfiguration
# des Garagen-Modus (TDP-Limitierung) unter Debian-basierten Systemen.
# ==============================================================================

# --- INITIALISIERUNG ---
SCRIPTNAME="ryzen-solar-power-installer"
VERSION="1.0.0"
REPO_URL="https://github.com/DerLinke/ryzen-solar-power"

# Definition der Branding-Farben (Horizontaler Verlauf von Rot nach Blau)
C_RED="\e[38;2;255;0;0m"
C_PINK="\e[38;2;161;0;94m"
C_BLUE="\e[38;2;0;0;255m"
C_GREEN="\e[38;2;0;255;0m"
NC="\e[0m"
BOLD="\e[1m"

show_banner() {
    echo -e "          ${C_PINK}██${NC}     ${C_BLUE}█████${NC}"
    echo -e "     ${C_RED}██${NC}                    ${C_BLUE}██${NC}"
    echo -e "${C_RED}██${NC}                ${C_BLUE}█████${NC} ${BOLD}${SCRIPTNAME} v${VERSION}${NC}"
    echo -e "     ${C_RED}██${NC}                    ${C_BLUE}██${NC}"
    echo -e "          ${C_PINK}██${NC}     ${C_BLUE}█████${NC}\n"
}

show_footer() {
    echo -e "\n${C_BLUE}----------------------------------------------------${NC}"
    echo -e "  ${BOLD}${SCRIPTNAME} v${VERSION}${NC}"
    echo -e "  \e[2mWeb:\e[0m ${C_BLUE}\e[4mhttps://derlinke.github.io/\e[0m"
    echo -e "  \e[2mGit:\e[0m ${C_BLUE}\e[4m${REPO_URL}\e[0m"
    echo -e "  ${C_RED}██${C_PINK}██${C_BLUE}██${NC}"
    echo -e "${C_BLUE}====================================================${NC}\n"
}

# Banner anzeigen
show_banner

# --- EINFÜHRUNG & ANLEITUNG ---
echo -e "${BOLD}Über dieses Skript:${NC}"
echo "Dieses Installationsskript konfiguriert dein System so, dass Einschaltstromspitzen"
echo "deiner AMD Ryzen CPU gedämpft werden. Dies schützt empfindliche Stromquellen"
echo "wie Solar-Batterien und Powerbanks vor Überlastung (z.B. in der Garage)."
echo ""
echo -e "${BOLD}Ablauf der Installation:${NC}"
echo "  1. Systemkompatibilität prüfen (CPU, OS, Sudo-Rechte)"
echo "  2. Installation der benötigten Pakete & Tools (z.B. GameMode)"
echo "  3. RyzenAdj (TDP-Steuerung) kompilieren & global installieren"
echo "  4. Erstellung des cpufreq-set Wrappers & der Steuerungsskripte"
echo "  5. Einrichtung eines systemd Boot-Services zur frühen TDP-Drosselung"
echo "  6. Optionale Integration in die GameMode-Hooks für automatische Leistung"
echo ""

read -p "Möchtest du mit der Installation fortfahren? [J/n]: " START_INSTALL
if [[ "$START_INSTALL" =~ ^([nN][eE][iI][nN]|[nN])$ ]]; then
  echo "Installation abgebrochen."
  exit 0
fi
echo ""

# 0) Sudo-Rechte prüfen
echo -e "${C_BLUE}[+] Prüfe Sudo-Berechtigung...${NC}"
if ! sudo -v &>/dev/null; then
  echo -e "${C_RED}[!] Fehler: Dieses Skript benötigt Sudo-Rechte. Bitte führe es als Benutzer mit Sudo-Rechten aus.${NC}"
  exit 1
fi
echo -e "${C_GREEN}[✓] Sudo-Rechte vorhanden.${NC}"

# 1) Systemprüfung (CPU & OS)
echo -e "${C_BLUE}[+] Prüfe Prozessor-Kompatibilität...${NC}"
if ! lscpu | grep -i -E "Ryzen|AMD" >/dev/null 2>&1; then
  echo -e "${C_RED}[-] Warnung: Es wurde keine AMD Ryzen CPU erkannt.${NC}"
  read -p "Trotzdem fortfahren? [j/N]: " CPU_PROCEED
  if [[ ! "$CPU_PROCEED" =~ ^([jJ][aA]|[jJ])$ ]]; then
    echo "Installation abgebrochen."
    exit 1
  fi
else
  CPU_NAME=$(lscpu | grep "Modellname" || lscpu | grep "Model name" | cut -d':' -f2 | sed -e 's/^[ \t]*//')
  echo -e "${C_GREEN}[✓] AMD CPU erkannt: ${CPU_NAME}${NC}"
fi

echo -e "${C_BLUE}[+] Prüfe Betriebssystem-Kompatibilität...${NC}"
if [ ! -f /etc/debian_version ] && ! command -v apt >/dev/null 2>&1; then
  echo -e "${C_RED}[-] Fehler: Dieses Skript unterstützt nur Debian-basierte Systeme (Debian, Ubuntu, Mint etc.).${NC}"
  exit 1
fi
echo -e "${C_GREEN}[✓] Kompatibles Debian-basiertes System erkannt.${NC}"

# 2) GameMode prüfen und ggf. installieren
echo -e "${C_BLUE}[+] Prüfe GameMode Status...${NC}"
if ! command -v gamemoded >/dev/null 2>&1; then
  echo -e "${C_BLUE}[+] GameMode ist nicht installiert. Installiere 'gamemode' über apt...${NC}"
  sudo apt update && sudo apt install -y gamemode
else
  echo -e "${C_GREEN}[✓] GameMode ist bereits installiert.${NC}"
fi

# 3) Wählbare Watt-Begrenzung
echo -e "\n${BOLD}--- TDP-Begrenzung für den Garagen-Modus ---${NC}"
echo "Wähle das gewünschte Limit für den Stromspar-Modus:"
echo "  1) 15 Watt (Sehr stromsparend, ideal für schwache Batterien/Solar)"
echo "  2) 20 Watt (Ausbalanciert - Empfohlen für GMKtec K12)"
echo "  3) 25 Watt (Mehr Leistung, mäßiger Verbrauch)"
echo "  4) Benutzerdefiniert (Wert manuell eingeben)"
read -p "Auswahl [1-4] (Standard: 2): " TDP_CHOICE

case $TDP_CHOICE in
  1) TDP_LIMIT=15000 ;;
  3) TDP_LIMIT=25000 ;;
  4) 
     read -p "Gib das gewünschte TDP-Limit in Watt ein (z.B. 12 oder 18): " CUSTOM_WATT
     if [[ "$CUSTOM_WATT" =~ ^[0-9]+$ ]] && [ "$CUSTOM_WATT" -gt 0 ]; then
       TDP_LIMIT=$((CUSTOM_WATT * 1000))
     else
       echo "Ungültige Eingabe. Nutze Standardwert (20W)."
       TDP_LIMIT=20000
     fi
     ;;
  *) TDP_LIMIT=20000 ;;
esac
TDP_WATT=$((TDP_LIMIT / 1000))
echo -e "${C_GREEN}[✓] Garagen-Modus TDP-Limit auf ${TDP_WATT}W festgelegt.${NC}\n"

# 4) RyzenAdj bauen/prüfen und installieren
REBUILD_RYZENADJ=true
if command -v ryzenadj >/dev/null 2>&1 || [ -x /usr/local/bin/ryzenadj ]; then
  echo -e "${C_GREEN}[✓] ryzenadj wurde bereits auf dem System gefunden.${NC}"
  read -p "Möchtest du RyzenAdj neu kompilieren und installieren? [y/N]: " REBUILD_ANS
  if [[ ! "$REBUILD_ANS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    REBUILD_RYZENADJ=false
  fi
fi

if [ "$REBUILD_RYZENADJ" = true ]; then
  echo -e "${C_BLUE}[+] Installiere Entwicklungs-Abhängigkeiten...${NC}"
  sudo apt update && sudo apt install -y git build-essential cmake libpci-dev

  echo -e "${C_BLUE}[+] Bereite RyzenAdj vor...${NC}"
  RYZENADJ_SRC="/tmp/ryzenadj_build"
  rm -rf "$RYZENADJ_SRC"

  # Prüfen, ob bereits lokale Quellen vorhanden sind
  if [ -d "$HOME/RyzenAdj" ]; then
    echo -e "${C_BLUE}[+] Nutze lokales RyzenAdj Verzeichnis für den Build...${NC}"
    cp -r "$HOME/RyzenAdj" "$RYZENADJ_SRC"
  else
    echo -e "${C_BLUE}[+] Clone RyzenAdj von GitHub...${NC}"
    git clone https://github.com/FlyGoat/RyzenAdj.git "$RYZENADJ_SRC"
  fi

  echo -e "${C_BLUE}[+] Baue RyzenAdj...${NC}"
  cd "$RYZENADJ_SRC"
  mkdir -p build && cd build
  cmake -DCMAKE_BUILD_TYPE=Release ..
  make -j$(nproc)

  echo -e "${C_BLUE}[+] Installiere RyzenAdj global...${NC}"
  sudo cp ryzenadj /usr/local/bin/ryzenadj
  sudo chmod +x /usr/local/bin/ryzenadj
  rm -rf "$RYZENADJ_SRC"
else
  echo -e "${C_GREEN}[✓] Überspringe Kompilierung von RyzenAdj.${NC}"
fi

# 5) cpufreq-set Compatibility-Wrapper erstellen
echo -e "${C_BLUE}[+] Erstelle cpufreq-set Wrapper...${NC}"
sudo tee /usr/local/bin/cpufreq-set > /dev/null <<'EOF'
#!/bin/bash
while getopts "g:c:d:u:f:r" opt; do
  case $opt in
    g) governor=$OPTARG ;;
  esac
done
if [ -n "$governor" ]; then
  echo "$governor" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
  echo "CPU-Governor auf '${governor}' gesetzt."
else
  echo "Verwendung: cpufreq-set -g [governor]"
  exit 1
fi
EOF
sudo chmod +x /usr/local/bin/cpufreq-set

# 6) Steuerungsskripte erstellen
echo -e "${C_BLUE}[+] Erstelle Garagen-Modus-Skript (${TDP_WATT}W Limit)...${NC}"
sudo tee /usr/local/bin/garagen-modus.sh > /dev/null <<EOF
#!/bin/bash
# --- INITIALISIERUNG ---
SCRIPTNAME="garagen-modus.sh"
VERSION="1.0.0"

C_RED="\e[38;2;255;0;0m"
C_PINK="\e[38;2;161;0;94m"
C_BLUE="\e[38;2;0;0;255m"
NC="\e[0m"
BOLD="\e[1m"

echo "=== Garagen-Modus Aktivierung ==="
if ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1; then
    echo "Setze CPU-Governor auf powersave..."
    echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
fi
if [ -x /usr/local/bin/ryzenadj ]; then
    echo "Begrenze Ryzen TDP auf ${TDP_WATT}W (${TDP_LIMIT}mW)..."
    /usr/local/bin/ryzenadj --stapm-limit=${TDP_LIMIT} --fast-limit=${TDP_LIMIT} --slow-limit=${TDP_LIMIT} --apu-slow-limit=${TDP_LIMIT} >/dev/null
fi

echo -e "\n\${C_BLUE}----------------------------------------------------\${NC}"
echo -e "  \${BOLD}\${SCRIPTNAME} v\${VERSION}\${NC}"
echo -e "  \e[2mWeb:\e[0m \${C_BLUE}\e[4mhttps://derlinke.github.io/\e[0m"
echo -e "  \${C_RED}██\${C_PINK}██\${C_BLUE}██\${NC}"
echo -e "\${C_BLUE}====================================================\${NC}\n"
EOF
sudo chmod +x /usr/local/bin/garagen-modus.sh

echo -e "${C_BLUE}[+] Erstelle Spiele-Modus-Skript (Maximale Leistung)...${NC}"
sudo tee /usr/local/bin/spiele-modus.sh > /dev/null <<'EOF'
#!/bin/bash
# --- INITIALISIERUNG ---
SCRIPTNAME="spiele-modus.sh"
VERSION="1.0.0"

C_RED="\e[38;2;255;0;0m"
C_PINK="\e[38;2;161;0;94m"
C_BLUE="\e[38;2;0;0;255m"
NC="\e[0m"
BOLD="\e[1m"

echo "=== Spiele-Modus Aktivierung ==="
if [ -x /usr/local/bin/ryzenadj ]; then
    echo "Setze Ryzen TDP auf unbegrenzt (54W)..."
    /usr/local/bin/ryzenadj --stapm-limit=54000 --fast-limit=54000 --slow-limit=54000 --apu-slow-limit=54000 >/dev/null
fi

echo -e "\n${C_BLUE}----------------------------------------------------${NC}"
echo -e "  ${BOLD}${SCRIPTNAME} v${VERSION}${NC}"
echo -e "  \e[2mWeb:\e[0m ${C_BLUE}\e[4mhttps://derlinke.github.io/\e[0m"
echo -e "  ${C_RED}██${C_PINK}██${C_BLUE}██${NC}"
echo -e "${C_BLUE}====================================================${NC}\n"
EOF
sudo chmod +x /usr/local/bin/spiele-modus.sh

# 7) Systemd Boot-Service erstellen
echo -e "${C_BLUE}[+] Erstelle systemd Boot-Service...${NC}"
sudo tee /etc/systemd/system/garagen-modus-boot.service > /dev/null <<'EOF'
[Unit]
Description=Garagen-Modus Stromspar-Limitierung bei Boot
DefaultDependencies=no
After=systemd-modules-load.service local-fs.target
Before=sysinit.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/garagen-modus.sh

[Install]
WantedBy=sysinit.target
EOF

echo -e "${C_BLUE}[+] Aktiviere systemd Boot-Service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable garagen-modus-boot.service

# 8) GameMode Hook-Integration
echo -e "${C_BLUE}[+] Konfiguriere GameMode Hooks...${NC}"
python3 - "$TDP_WATT" <<'EOF'
import sys
import configparser
import os

tdp_watt = sys.argv[1] if len(sys.argv) > 1 else "20"
path = os.path.expanduser('~/.config/gamemode.ini')
config = configparser.ConfigParser()

if os.path.exists(path):
    print(f"[+] Lese bestehende {path}...")
    config.read(path)
else:
    print(f"[+] Erstelle neue {path}...")
    config['general'] = {'reaper': 'true'}
    config['gpu'] = {'apply_gpu_optimisations': 'true', 'gpu_device': '0', 'amd_performance_level': 'high'}
    config['cpu'] = {'governor': 'performance'}
    config['power_profiles_daemon'] = {'request_performance': 'true'}

if 'custom' not in config:
    config['custom'] = {}

config['custom']['start'] = "notify-send 'GameMode' '🎮 Performance-Modus aktiviert (TDP unbegrenzt, KI pausiert)' && systemctl --user stop open-webui && sudo /usr/local/bin/spiele-modus.sh"
config['custom']['end'] = f"notify-send 'GameMode' '🔋 Zurück zum Garagen-Modus (TDP {tdp_watt}W, KI aktiv)' && systemctl --user start open-webui && sudo /usr/local/bin/garagen-modus.sh"

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f:
    config.write(f)
print("[+] gamemode.ini erfolgreich aktualisiert.")
EOF

# 9) Garagen-Modus jetzt ausführen
echo -e "${C_BLUE}[+] Wende Garagen-Modus direkt an...${NC}"
sudo /usr/local/bin/garagen-modus.sh

# Footer anzeigen
show_footer
echo "Installation erfolgreich abgeschlossen! Der Schutz vor Boot-Spitzen ist aktiv."
