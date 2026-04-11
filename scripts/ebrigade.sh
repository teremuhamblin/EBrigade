#!/usr/bin/env bash
# ============================================================
#  EBrigade TUI — Centre OPS (Version 0.7.0)
#  Unité : EBrigade OS V2
# ============================================================
set -euo pipefail
umask 027

# ===================== Détection environnement =====================
IS_TTY=0
[ -t 1 ] && IS_TTY=1

IS_CI=0
[ -n "${CI:-}" ] && IS_CI=1

# ===================== Logs centralisés ============================
LOG_DIR="/var/log/ebrigade"
LOG_FILE="$LOG_DIR/ops.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || true

log() {
  printf "[%s] [%s] %s\n" \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "${1:-INFO}" \
    "${2:-}" >> "$LOG_FILE"
}

trap 'log ERROR "Erreur code $?"; printf "\n\e[31m[ERREUR]\e[0m Une erreur est survenue.\n"' ERR

# ===================== Résolution chemins ===========================
resolve_path() {
  local target="$1"
  while [ -L "$target" ]; do target="$(readlink "$target")"; done
  printf "%s" "$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
}

SCRIPT_PATH="$(resolve_path "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# ===================== Configuration avancée ========================
CONF_GLOBAL="/etc/ebrigade.conf"
CONF_LOCAL="$SCRIPT_DIR/ebrigade.conf"

declare -A CONF

load_conf_file() {
  local file="$1"
  [ ! -f "$file" ] && return

  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#|^$ ]] && continue
    key="$(echo "$key" | xargs)"
    val="$(echo "$val" | xargs)"
    CONF["$key"]="$val"
  done < "$file"
}

load_conf_file "$CONF_GLOBAL"
load_conf_file "$CONF_LOCAL"

PROJECT_NAME="${CONF[PROJECT_NAME]:-EBrigade OS V2}"
VERSION="${CONF[VERSION]:-0.7.0}"

# ===================== Permissions OPS ==============================
ROLE="${CONF[ROLE]:-operator}"

check_role() {
  case "$ROLE" in
    admin|operator|analyst) return 0 ;;
    *)
      printf "\e[31m[ERREUR]\e[0m Rôle inconnu : %s\n" "$ROLE"
      exit 1
      ;;
  esac
}

check_role

# ===================== Couleurs ==============================
if [ "$IS_TTY" -eq 1 ]; then
  C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_CYAN="\e[36m"; C_REDALERT="\e[41m"
else
  C_RESET=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_CYAN=""; C_REDALERT=""
fi

# ===================== Hooks (pre/post module) ======================
run_hook() {
  local hook="$SCRIPT_DIR/hooks/$1"
  [ -x "$hook" ] && bash "$hook" || true
}

# ===================== Utilitaires ================================
pause() {
  [ "${AUTO_MODE:-0}" -eq 1 ] && return
  [ "$IS_CI" -eq 1 ] && return
  printf "\n%s[OPS]%s Appuyez sur Entrée..." "$C_YELLOW" "$C_RESET"
  IFS= read -r _ || true
}

cls() {
  [ "$IS_TTY" -eq 1 ] && command -v tput >/dev/null && tput clear || printf "\n"
}

print_header() {
  cls
  printf "%b============================================================\n" "$C_GREEN"
  printf "  %s — Centre OPS\n" "$PROJECT_NAME"
  printf "  Version : %s\n" "$VERSION"
  printf "  Rôle    : %s\n" "$ROLE"
  printf "============================================================%b\n" "$C_RESET"
}

# ===================== Mode ALERTE ROUGE ============================
alert_red() {
  for _ in {1..3}; do
    printf "%b[ALERTE ROUGE — PROTOCOLE OPS]%b\n" "$C_REDALERT" "$C_RESET"
    sleep 0.1
  done
}

# ===================== Banner ================================
print_banner() {
  local banner_script="$SCRIPT_DIR/banner.sh"
  if [ -r "$banner_script" ]; then
    bash "$banner_script"
    return
  fi

  printf "%b" "$C_GREEN"
  cat <<'EOF'
   ______     _           _       
  |  ____|   | |         | |      
  | |__  __ _| |__  _ __ | | ___  
  |  __|/ _` | '_ \| '_ \| |/ _ \ 
  | |  | (_| | |_) | |_) | |  __/ 
  |_|   \__,_|_.__/| .__/|_|\___| 
                    | |           
                    |_|   EBrigade
EOF
  printf "%b\n" "$C_RESET"
}

# ===================== Modules ===============================
SYSTEM_MODULES_DIR="${CONF[SYSTEM_MODULES_DIR]:-/usr/share/ebrigade/modules}"
LOCAL_MODULES_DIR="${CONF[LOCAL_MODULES_DIR]:-$SCRIPT_DIR/../modules}"

MODULES_DIR="$SYSTEM_MODULES_DIR"

detect_modules_dir() {
  if [ -d "$LOCAL_MODULES_DIR" ]; then
    MODULES_DIR="$LOCAL_MODULES_DIR"
  elif [ -d "$SYSTEM_MODULES_DIR" ]; then
    MODULES_DIR="$SYSTEM_MODULES_DIR"
  else
    MODULES_DIR=""
  fi
}

list_modules_raw() {
  detect_modules_dir
  [ -z "$MODULES_DIR" ] && return 1
  find "$MODULES_DIR" -maxdepth 1 -type f -name "*.sh" -readable -printf "%f\n" | sort
}

run_module_by_index() {
  detect_modules_dir
  [ -z "$MODULES_DIR" ] && { printf "%b[ERREUR]%b Aucun dossier modules.\n" "$C_RED" "$C_RESET"; return 1; }

  local choice="$1" index=1 selected=""
  while IFS= read -r m; do
    [ "$index" -eq "$choice" ] && selected="$m" && break
    index=$((index+1))
  done <<EOF
$(list_modules_raw || true)
EOF

  [ -z "$selected" ] && { printf "%b[ERREUR]%b Module inexistant.\n" "$C_RED" "$C_RESET"; return 1; }

  local module_path="$MODULES_DIR/$selected"

  # Sandbox : interdit les modules contenant rm -rf /
  if grep -Eq 'rm -rf /' "$module_path"; then
    printf "%b[ALERTE]%b Module dangereux détecté.\n" "$C_RED" "$C_RESET"
    log WARN "Module bloqué : $selected"
    return 1
  fi

  run_hook "pre-$selected"
  log INFO "Exécution module: $selected"

  bash "$module_path"

  run_hook "post-$selected"
}

# ===================== Briefing ==============================
show_system_briefing() {
  cls
  printf "%b[BRIEFING SYSTÈME]%b\n\n" "$C_GREEN" "$C_RESET"

  printf "%bHôte :%b %s\n" "$C_CYAN" "$C_RESET" "$(hostname)"
  printf "%bUtilisateur :%b %s\n" "$C_CYAN" "$C_RESET" "${USER:-unknown}"
  printf "%bDate :%b %s\n" "$C_CYAN" "$C_RESET" "$(date)"

  printf "\n%bRessources :%b\n" "$C_CYAN" "$C_RESET"
  command -v free >/dev/null && free -h || echo "free non disponible"
  printf "\n"
  command -v df >/dev/null && df -h / || echo "df non disponible"

  pause
}

# ===================== Aide / Version ========================
show_help() {
  cat <<EOF
${PROJECT_NAME} — Centre OPS (TUI)
Usage : ebrigade [options]

Options :
  -h, --help        Affiche cette aide
  -v, --version     Affiche la version
  --auto            Mode non-interactif
  --module X        Lance directement un module
  --alert           Active le mode ALERTE ROUGE
EOF
}

show_version() {
  printf "%s %s\n" "$PROJECT_NAME" "$VERSION"
}

about_screen() {
  cls
  printf "%b[À PROPOS]%b\n\n" "$C_CYAN" "$C_RESET"
  printf "  Projet   : %s\n" "$PROJECT_NAME"
  printf "  Version  : %s\n" "$VERSION"
  printf "  Rôle     : %s\n" "$ROLE"
  printf "  Unité    : LeBrigade (fictif)\n"
  printf "\n  Projet fictif, pédagogique et esthétique.\n"
  pause
}

# ===================== Mode non-interactif ===================
AUTO_MODE=0
AUTO_MODULE=""
ALERT_MODE=0

parse_args() {
  case "${1-}" in
    --auto) AUTO_MODE=1 ;;
    --module) AUTO_MODULE="${2:-}"; AUTO_MODE=1 ;;
    --alert) ALERT_MODE=1 ;;
    -h|--help) show_help; exit 0 ;;
    -v|--version) show_version; exit 0 ;;
  esac
}

parse_args "${1-}" "${2-}"

[ "$ALERT_MODE" -eq 1 ] && alert_red

if [ "$AUTO_MODE" -eq 1 ] && [ -n "$AUTO_MODULE" ]; then
  run_module_by_index "$AUTO_MODULE"
  exit 0
fi

# ===================== Menu principal ========================
main_menu() {
  while :; do
    print_header
    print_banner

    printf "%b[MENU PRINCIPAL]%b\n" "$C_CYAN" "$C_RESET"
    printf "  [1] Briefing système\n"
    printf "  [2] Lancer un module\n"
    printf "  [3] Liste des modules\n"
    printf "  [4] À propos\n"
    printf "  [0] Quitter\n\n"

    printf "%b[ENTRÉE]%b Choix : " "$C_YELLOW" "$C_RESET"
    IFS= read -r choice || choice=""

    case "$choice" in
      1) show_system_briefing ;;
      2)
        print_modules_menu
        printf "\n%b[ENTRÉE]%b Numéro du module : " "$C_YELLOW" "$C_RESET"
        IFS= read -r mchoice || mchoice=""
        printf '%s' "$mchoice" | grep -Eq '^[0-9]+$' && run_module_by_index "$mchoice" || printf "%b[ERREUR]%b Entrée invalide.\n" "$C_RED" "$C_RESET"
        pause
        ;;
      3) print_modules_menu; pause ;;
      4) about_screen ;;
      0) printf "%b[OPS]%b Fermeture du Centre OPS.\n" "$C_GREEN" "$C_RESET"; exit 0 ;;
      *) printf "%b[ERREUR]%b Choix invalide.\n" "$C_RED" "$C_RESET"; sleep 1 ;;
    esac
  done
}

main_menu
