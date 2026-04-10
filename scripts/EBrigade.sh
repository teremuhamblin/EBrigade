#!/usr/bin/env bash
# ============================================================
#  EBrigade TUI — Centre OPS
#  Unité  : LeBrigade / EBrigade OS V2
#  Objet  : Interface texte militaire-fictive d’administration
# ============================================================
set -euo pipefail

PROJECT_NAME="EBrigade OS V2"
VERSION="0.4.0"
MODULES_DIR="/usr/share/ebrigade/modules"
LOCAL_MODULES_DIR="$(dirname "$0")/../modules"

# Couleurs
C_RESET="\e[0m"
C_GREEN="\e[32m"
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_CYAN="\e[36m"

pause() {
  printf "\n%s[OPS]%s Appuyez sur Entrée pour continuer..." "$C_YELLOW" "$C_RESET"
  # shellcheck disable=SC2034
  read _ || true
}

cls() {
  command -v clear >/dev/null 2>&1 && clear || printf "\n"
}

print_header() {
  cls
  printf "%b" "$C_GREEN"
  printf "============================================================\n"
  printf "  %s — Centre OPS\n" "$PROJECT_NAME"
  printf "  Version : %s\n" "$VERSION"
  printf "============================================================\n"
  printf "%b" "$C_RESET"
}

print_banner() {
  # Si banner.sh existe, on l’utilise
  local banner_script
  banner_script="$(dirname "$0")/banner.sh"
  if [ -f "$banner_script" ]; then
    # shellcheck disable=SC1090
    bash "$banner_script"
  else
    printf "%b" "$C_GREEN"
    printf "   ______     _           _       \n"
    printf "  |  ____|   | |         | |      \n"
    printf "  | |__  __ _| |__  _ __ | | ___  \n"
    printf "  |  __|/ _\` | '_ \\| '_ \\| |/ _ \\ \n"
    printf "  | |  | (_| | |_) | |_) | |  __/ \n"
    printf "  |_|   \\__,_|_.__/| .__/|_|\\___| \n"
    printf "                    | |           \n"
    printf "                    |_|   EBrigade\n"
    printf "%b\n" "$C_RESET"
    sleep 1
  fi
}

detect_modules_dir() {
  if [ -d "$LOCAL_MODULES_DIR" ]; then
    MODULES_DIR="$LOCAL_MODULES_DIR"
  fi
}

list_modules() {
  detect_modules_dir
  if [ ! -d "$MODULES_DIR" ]; then
    printf "%b[ALERTE]%b Aucun dossier modules trouvé (%s)\n" "$C_RED" "$C_RESET" "$MODULES_DIR"
    return 1
  fi

  # Liste des modules *.sh
  find "$MODULES_DIR" -maxdepth 1 -type f -name "*.sh" -printf "%f\n" 2>/dev/null | sort
}

print_modules_menu() {
  detect_modules_dir
  printf "%b" "$C_CYAN"
  printf "---------------- Modules disponibles ----------------\n"
  printf "%b" "$C_RESET"

  local i=1
  local m
  MODULE_LIST=""
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    MODULE_LIST="${MODULE_LIST}${m}\n"
    printf "  [%d] %s\n" "$i" "$m"
    i=$((i+1))
  done <<EOF
$(list_modules || true)
EOF

  if [ "$i" -eq 1 ]; then
    printf "%b[INFO]%b Aucun module détecté.\n" "$C_YELLOW" "$C_RESET"
  fi
}

run_module_by_index() {
  detect_modules_dir
  local choice="$1"
  local index=1
  local selected=""
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    if [ "$index" -eq "$choice" ]; then
      selected="$m"
      break
    fi
    index=$((index+1))
  done <<EOF
$(list_modules || true)
EOF

  if [ -z "$selected" ]; then
    printf "%b[ERREUR]%b Module inexistant pour choix %s\n" "$C_RED" "$C_RESET" "$choice"
    return 1
  fi

  local module_path="$MODULES_DIR/$selected"
  if [ ! -f "$module_path" ]; then
    printf "%b[ERREUR]%b Fichier module introuvable : %s\n" "$C_RED" "$C_RESET" "$module_path"
    return 1
  fi

  printf "%b[OPS]%b Exécution du module : %s\n" "$C_GREEN" "$C_RESET" "$selected"
  # shellcheck disable=SC1090
  bash "$module_path"
}

show_system_briefing() {
  cls
  printf "%b[BRIEFING SYSTÈME]%b\n\n" "$C_GREEN" "$C_RESET"

  printf "%bHôte :%b " "$C_CYAN" "$C_RESET"
  hostname || echo "N/A"

  printf "%bUtilisateur :%b %s\n" "$C_CYAN" "$C_RESET" "${USER:-unknown}"

  printf "%bDate :%b " "$C_CYAN" "$C_RESET"
  date || echo "N/A"

  printf "\n%bRessources :%b\n" "$C_CYAN" "$C_RESET"
  command -v free >/dev/null 2>&1 && free -h || echo "free non disponible"
  printf "\n"
  command -v df >/dev/null 2>&1 && df -h / || echo "df non disponible"

  pause
}

show_help() {
  cat <<EOF
${PROJECT_NAME} — Centre OPS (TUI)
Usage : ebrigade [options]

Options :
  -h, --help      Affiche cette aide
  -v, --version   Affiche la version

Sans option, lance l’interface TUI.
EOF
}

show_version() {
  printf "%s %s\n" "$PROJECT_NAME" "$VERSION"
}

main_menu() {
  while :; do
    print_header
    print_banner

    printf "%b[MENU PRINCIPAL]%b\n" "$C_CYAN" "$C_RESET"
    printf "  [1] Briefing système (OPS)\n"
    printf "  [2] Lancer un module (RENSEIGNEMENT / OPS)\n"
    printf "  [3] Liste des modules\n"
    printf "  [4] À propos\n"
    printf "  [0] Quitter\n\n"

    printf "%b[ENTRÉE]%b Choix : " "$C_YELLOW" "$C_RESET"
    read -r choice || choice=""

    case "$choice" in
      1)
        show_system_briefing
        ;;
      2)
        cls
        print_modules_menu
        printf "\n%b[ENTRÉE]%b Numéro du module à lancer : " "$C_YELLOW" "$C_RESET"
        read -r mchoice || mchoice=""
        [ -z "$mchoice" ] && continue
        if printf '%s\n' "$mchoice" | grep -Eq '^[0-9]+$'; then
          run_module_by_index "$mchoice"
        else
          printf "%b[ERREUR]%b Entrée invalide.\n" "$C_RED" "$C_RESET"
        fi
        pause
        ;;
      3)
        cls
        print_modules_menu
        pause
        ;;
      4)
        cls
        printf "%b[À PROPOS]%b\n\n" "$C_CYAN" "$C_RESET"
        printf "  Projet   : %s\n" "$PROJECT_NAME"
        printf "  Version  : %s\n" "$VERSION"
        printf "  Unité    : LeBrigade (fictif)\n"
        printf "  Objet    : Interface TUI d’administration stylisée centre OPS.\n"
        printf "\n  Ce projet est fictif, à but pédagogique et esthétique.\n"
        pause
        ;;
      0)
        printf "%b[OPS]%b Fermeture du Centre OPS.\n" "$C_GREEN" "$C_RESET"
        exit 0
        ;;
      *)
        printf "%b[ERREUR]%b Choix invalide.\n" "$C_RED" "$C_RESET"
        sleep 1
        ;;
    esac
  done
}

# ===================== Point d’entrée =========================
if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
  show_help
  exit 0
fi

if [ "${1-}" = "-v" ] || [ "${1-}" = "--version" ]; then
  show_version
  exit 0
fi

main_menu
