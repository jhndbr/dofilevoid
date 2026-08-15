#!/usr/bin/env bash
# ==============================================================================
#  _   _       _     _   ___       _   __ _ _           
# | | | |     (_)   | | |   \ ___ | |_/ _(_) |___ ___   
# | |_| |__ _  _  __| | | |) / _ \|  _|  _| | / -_|_-<   
#  \___/ \___/ |_|\___| |___/\___/ \__|_| |_|_\___/__/   
#                                                        
#  Instalador y configurador de Dotfiles para Void Linux (glibc) con Sway
# ==============================================================================

set -e

# --- Colores y Estilos ---
BOLD="\033[1m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[✔ OK]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[!] AVISO:${RESET} $1"
}

log_error() {
    echo -e "${RED}[✘ ERROR]${RESET} $1"
}

log_step() {
    echo -e "\n${BOLD}${CYAN}==>${RESET} ${BOLD}$1${RESET}"
}

# --- Detección de Comando de Elevación (sudo / doas) ---
SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
    SUDO_CMD="sudo"
elif command -v doas >/dev/null 2>&1; then
    SUDO_CMD="doas"
fi

check_root_or_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        log_error "Por favor no ejecutes este script directamente como root."
        log_info "Ejecútalo con tu usuario normal. El script pedirá sudo/doas cuando sea necesario."
        exit 1
    fi

    if [ -z "$SUDO_CMD" ]; then
        log_error "No se encontró ni 'sudo' ni 'doas'. Instálalo y configura tu usuario en el grupo wheel."
        exit 1
    fi
}

# --- Banner de Bienvenida ---
banner() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
  __      __   _     _   _     _                  ____                      
  \ \    / /__(_) __| | | |   (_)_ _ _  ___ __  / ___|_      ____ _ _   _ 
   \ \/\/ / _ \ |/ _` | | |__ | | ' \ || \ \ /  \___ \ \ /\ / / _` | | | |
    \_/\_/\___/_|\__,_| |____||_|_||_\_,_/_\_\  |___) \ V  V / (_| | |_| |
                                                |____/ \_/\_/ \__,_|\__, |
                                                                    |___/ 
EOF
    echo -e "${RESET}"
    echo -e "${BOLD}Instalador y Optimizador de Entorno Sway para Void Linux (glibc)${RESET}"
    echo -e "${MAGENTA}--------------------------------------------------------------------${RESET}\n"
}

# --- Paso 1: Verificación de Sistema ---
verify_system() {
    log_step "Paso 1: Verificando sistema operativo y arquitectura"
    
    if [ ! -f /etc/os-release ]; then
        log_warning "No se pudo leer /etc/os-release."
    else
        . /etc/os-release
        if [[ "$ID" != "void" ]]; then
            log_warning "Este script está especialmente diseñado para Void Linux (detectado: $NAME)."
            read -p "¿Deseas continuar de todas formas? [s/N]: " resp
            if [[ ! "$resp" =~ ^[sSyY]$ ]]; then
                log_info "Instalación cancelada."
                exit 0
            fi
        else
            log_success "Sistema detectado: Void Linux"
        fi
    fi

    # Comprobar glibc vs musl
    if ldd --version 2>&1 | grep -qi "musl"; then
        log_warning "Detectado entorno Void MUSL. Este dotfile fue adaptado con soporte para glibc y musl, pero se recomienda glibc para Neovim Mason y compatibilidad binaria."
    else
        log_success "Entorno C library: glibc detectado correctamente."
    fi
}

# --- Paso 2: Paquetes y Repositorios ---
install_packages() {
    log_step "Paso 2: Instalación de paquetes de Void Linux (XBPS)"
    
    if ! command -v xbps-install >/dev/null 2>&1; then
        log_warning "xbps-install no encontrado. Saltando instalación automática de paquetes."
        return
    fi

    echo -e "¿Deseas actualizar los repositorios e instalar todos los paquetes necesarios?"
    echo -e "Esto incluye: Sway, Swaylock, Swayidle, Pipewire, Wireplumber, Alacritty, Fuzzel, Neovim, Fuentes Nerd, etc."
    read -p "Instalar paquetes ahora [S/n]: " pkg_resp
    pkg_resp=${pkg_resp:-S}

    if [[ "$pkg_resp" =~ ^[sSyY]$ ]]; then
        log_info "Actualizando base de datos de repositorios..."
        $SUDO_CMD xbps-install -Sy

        # Repositorios adicionales recomendados
        log_info "Instalando repositorios nonfree y multilib..."
        $SUDO_CMD xbps-install -y void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree 2>/dev/null || true
        $SUDO_CMD xbps-install -Sy

        # Lista de paquetes
        PACKAGES=(
            # Sway y Wayland core
            sway swaylock swayidle swaybg wl-clipboard cliphist
            grim slurp mako fuzzel wmenu xorg-server-xwayland
            
            # Audio y Multimedia
            pipewire wireplumber alsa-pipewire pavucontrol
            
            # Gestión de Sesión, D-Bus y Permisos
            dbus seatd polkit polkit-gnome
            
            # Terminal, Shell y Utilidades CLI
            alacritty neovim tmux nnn fastfetch brightnessctl
            jq bc ripgrep fd curl git tar unzip btop
            xdg-user-dirs xdg-utils imv
            
            # Fuentes
            nerd-fonts font-awesome fonts-roboto-ttf noto-fonts-ttf noto-fonts-emoji
            
            # Navegador y Red
            NetworkManager firefox
        )

        log_info "Instalando paquetes principales..."
        $SUDO_CMD xbps-install -y "${PACKAGES[@]}" || {
            log_warning "Algunos paquetes no se pudieron instalar en un solo lote. Intentando individualmente..."
            for pkg in "${PACKAGES[@]}"; do
                $SUDO_CMD xbps-install -y "$pkg" 2>/dev/null || log_warning "Paquete opcional omitido o no disponible: $pkg"
            done
        }

        log_success "Instalación de paquetes completada."
    else
        log_info "Instalación de paquetes omitida por el usuario."
    fi
}

# --- Paso 3: Configuración de Servicios Runit y Grupos ---
configure_services() {
    log_step "Paso 3: Configuración de Servicios (Runit) y Permisos de Usuario"

    USER_NAME="$USER"
    log_info "Agregando al usuario '$USER_NAME' a los grupos necesarios (video, audio, input, _seatd, wheel)..."
    for grp in video audio input _seatd wheel; do
        if grep -q "^$grp:" /etc/group; then
            $SUDO_CMD usermod -aG "$grp" "$USER_NAME" 2>/dev/null && log_success "Añadido al grupo: $grp" || true
        fi
    done

    log_info "Habilitando servicios en /var/service/..."
    SERVICES_TO_ENABLE=("dbus" "seatd" "polkitd")

    for srv in "${SERVICES_TO_ENABLE[@]}"; do
        if [ -d "/etc/sv/$srv" ]; then
            if [ ! -L "/var/service/$srv" ]; then
                $SUDO_CMD ln -s "/etc/sv/$srv" "/var/service/" && log_success "Servicio habilitado: $srv"
            else
                log_info "El servicio $srv ya estaba habilitado."
            fi
        fi
    done

    # NetworkManager vs dhcpcd
    if [ -d "/etc/sv/NetworkManager" ]; then
        echo -e "\n¿Deseas habilitar NetworkManager como gestor de red principal?"
        read -p "[S/n]: " nm_resp
        nm_resp=${nm_resp:-S}
        if [[ "$nm_resp" =~ ^[sSyY]$ ]]; then
            # Desactivar dhcpcd y wpa_supplicant para evitar conflictos
            $SUDO_CMD rm -f /var/service/dhcpcd /var/service/wpa_supplicant 2>/dev/null || true
            $SUDO_CMD ln -sf /etc/sv/NetworkManager /var/service/ 2>/dev/null && log_success "NetworkManager habilitado."
        fi
    fi
}

# --- Paso 4: Selección de Idioma / Distribución de Teclado ---
configure_keyboard() {
    log_step "Paso 4: Configuración de Distribución de Teclado para Sway"
    
    echo -e "Selecciona la distribución de teclado principal para Sway:"
    echo -e "  ${BOLD}1)${RESET} Español - España (es)"
    echo -e "  ${BOLD}2)${RESET} Latinoamericano (latam)"
    echo -e "  ${BOLD}3)${RESET} Inglés US (us)"
    echo -e "  ${BOLD}4)${RESET} Francés AZERTY (fr)"
    echo -e "  ${BOLD}5)${RESET} Mantener multi-layout (es, latam, us con toggle Alt+Shift)"
    read -p "Opción [1-5] (Por defecto: 1): " kb_choice
    kb_choice=${kb_choice:-1}

    LAYOUT="es"
    case "$kb_choice" in
        1) LAYOUT="es" ;;
        2) LAYOUT="latam" ;;
        3) LAYOUT="us" ;;
        4) LAYOUT="fr" ;;
        5) LAYOUT="es,latam,us" ;;
        *) LAYOUT="es" ;;
    esac

    log_info "Configurando layout de teclado: '$LAYOUT'..."
    
    INPUTS_CONF="$SCRIPT_DIR/sway/sway_config.d/inputs.conf"
    if [ -f "$INPUTS_CONF" ]; then
        sed -i "s/xkb_layout .*/xkb_layout \"$LAYOUT\"/" "$INPUTS_CONF"
        log_success "Layout '$LAYOUT' establecido en inputs.conf."
    fi
}

# --- Paso 5: Despliegue de Archivos de Configuración (Dotfiles) ---
deploy_dotfiles() {
    log_step "Paso 5: Desplegando archivos de configuración en tu $HOME"

    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
    BIN_DIR="$HOME/.local/bin"
    BACKUP_DIR="$CONFIG_DIR/dotfiles_backup_$(date +'%Y%m%d_%H%M%S')"

    mkdir -p "$CONFIG_DIR" "$BIN_DIR" "$HOME/Pictures/Screenshots"

    # Carpetas a respaldar e instalar
    DOT_DIRS=("sway" "alacritty" "fuzzel" "fastfetch" "nvim")

    for dir in "${DOT_DIRS[@]}"; do
        if [ -d "$CONFIG_DIR/$dir" ]; then
            mkdir -p "$BACKUP_DIR"
            log_info "Respaldando configuración existente de $dir en $BACKUP_DIR/$dir..."
            cp -r "$CONFIG_DIR/$dir" "$BACKUP_DIR/"
        fi
    done

    # Copiar carpetas de configuración
    for dir in "${DOT_DIRS[@]}"; do
        if [ -d "$SCRIPT_DIR/$dir" ]; then
            log_info "Instalando ~/.config/$dir..."
            rm -rf "$CONFIG_DIR/$dir"
            cp -r "$SCRIPT_DIR/$dir" "$CONFIG_DIR/"
        fi
    done

    # Instalar scripts en ~/.local/bin
    log_info "Instalando scripts en ~/.local/bin/..."
    SCRIPTS=("swaybar.sh" "switch" "power_menu.sh")
    for scr in "${SCRIPTS[@]}"; do
        if [ -f "$SCRIPT_DIR/$scr" ]; then
            cp "$SCRIPT_DIR/$scr" "$BIN_DIR/"
            chmod +x "$BIN_DIR/$scr"
            log_success "Instalado: $BIN_DIR/$scr"
        fi
    done

    # Copiar imágenes y fondos si existen
    if [ -f "$SCRIPT_DIR/dark_theme.png" ] && [ ! -f "$HOME/Pictures/blurred_wallpaper_void.jpg" ]; then
        cp "$SCRIPT_DIR/dark_theme.png" "$HOME/Pictures/blurred_wallpaper_void.jpg"
    fi

    # Configuración inicial de tema
    "$BIN_DIR/switch" auto 2>/dev/null || true

    log_success "Dotfiles instalados correctamente."
}

# --- Paso 6: Configuración de Variables de Entorno y Shell ---
configure_shell() {
    log_step "Paso 6: Configurando PATH y Variables de Entorno para Wayland/Sway"

    SHELL_RC_FILES=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")

    PATH_ENTRY='export PATH="$HOME/.local/bin:$PATH"'
    WAYLAND_ENV='export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_TYPE=wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM="wayland;xcb"
export _JAVA_AWT_WM_NONREPARENTING=1'

    for rc in "${SHELL_RC_FILES[@]}"; do
        if [ -f "$rc" ] || [ "$rc" = "$HOME/.bashrc" ]; then
            touch "$rc"
            if ! grep -q '\.local/bin' "$rc"; then
                echo -e "\n# User local bin\n$PATH_ENTRY" >> "$rc"
                log_success "Añadido ~/.local/bin a PATH en $(basename "$rc")"
            fi
            if ! grep -q 'MOZ_ENABLE_WAYLAND' "$rc"; then
                echo -e "\n# Wayland Environment Variables\n$WAYLAND_ENV" >> "$rc"
                log_success "Variables de entorno Wayland añadidas a $(basename "$rc")"
            fi
        fi
    done

    # Inicializar xdg-user-dirs
    if command -v xdg-user-dirs-update >/dev/null 2>&1; then
        xdg-user-dirs-update
    fi
}

# --- Paso 7: Verificación Final y Resumen ---
summary() {
    log_step "¡Instalación y Configuración Completadas con Éxito! 🎉"
    
    echo -e "${BOLD}${GREEN}Tu entorno Sway en Void Linux está listo para usar.${RESET}\n"
    echo -e "${BOLD}Acciones y Atajos Principales:${RESET}"
    echo -e "  • ${CYAN}Iniciar Sway:${RESET}              Escribe ${BOLD}sway${RESET} desde la tty"
    echo -e "  • ${CYAN}Terminal (Alacritty):${RESET}      ${BOLD}Super + Enter${RESET}"
    echo -e "  • ${CYAN}Lanzador de Apps (Fuzzel):${RESET} ${BOLD}Super + D${RESET}"
    echo -e "  • ${CYAN}Navegador (Firefox):${RESET}       ${BOLD}Super + B${RESET}"
    echo -e "  • ${CYAN}Explorador (NNN):${RESET}          ${BOLD}Super + F${RESET}"
    echo -e "  • ${CYAN}Cambiar Tema Claro/Oscuro:${RESET} ${BOLD}Super + Shift + T${RESET} (o comando: ${BOLD}switch toggle${RESET})"
    echo -e "  • ${CYAN}Menú de Apagado/Sesión:${RESET}   ${BOLD}Super + Shift + X${RESET} o ${BOLD}Super + Esc${RESET}"
    echo -e "  • ${CYAN}Captura de Pantalla:${RESET}       ${BOLD}Super + Shift + S${RESET} o ${BOLD}Print${RESET} o ${BOLD}Shift + Alt + P${RESET}"
    echo -e "  • ${CYAN}Cerrar Ventana:${RESET}            ${BOLD}Super + Q${RESET}"
    echo -e "  • ${CYAN}Espacios de Trabajo:${RESET}       ${BOLD}Super + 1..9, 0${RESET}\n"

    log_info "Nota: Si acabas de agregar tu usuario a los grupos de audio/video/_seatd, reinicia tu sesión o equipo para que surtan efecto completo."
    echo -e "${MAGENTA}--------------------------------------------------------------------${RESET}"
}

# --- Main ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_root_or_sudo
banner
verify_system
install_packages
configure_services
configure_keyboard
deploy_dotfiles
configure_shell
summary
