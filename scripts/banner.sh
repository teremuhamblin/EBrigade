#!/usr/bin/env bash
set -euo pipefail

###############################################
#  EBRIGADE OS V2 — ANIMATION TACTIQUE ULTIME #
###############################################

umask 027

# ================================
#  Couleurs tactiques
# ================================
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

# ================================
#  Modes d’animation
# ================================
MODE="${1:-normal}"   # normal | furtif | beep

# ================================
#  Frames ASCII
# ================================
frames=(
"   ______     _           _       
  |  ____|   | |         | |      
  | |__  __ _| |__  _ __ | | ___  
  |  __|/ _\` | '_ \| '_ \| |/ _ \ 
  | |  | (_| | |_) | |_) | |  __/ 
  |_|   \__,_|_.__/| .__/|_|\___| 
                    | |           
                    |_|   EBrigade"

"   ______     _           _       
  |  ____|   | |         | |      
  | |__  __ _| |__  _ __ | | ___  
  |  __|/ _\` | '_ \| '_ \| |/ _ \ 
  | |  | (_| | |_) | |_) | |  __/ 
  |_|   \__,_|_.__/| .__/|_|\___| 
                    | |           
                    |_|   LeBrigade"
)

# ================================
#  Effet fade-in
# ================================
fade_in() {
  local text="$1"
  for i in {1..5}; do
    clear
    printf "\e[38;2;$((i*40));255;$((i*40))m%s${RESET}\n" "$text"
    sleep 0.05
  done
}

# ================================
#  Effet fade-out
# ================================
fade_out() {
  local text="$1"
  for i in {5..1}; do
    clear
    printf "\e[38;2;$((i*40));255;$((i*40))m%s${RESET}\n" "$text"
    sleep 0.05
  done
}

# ================================
#  Effet scan radar
# ================================
scan_radar() {
  local width=40
  for ((i=0; i<width; i++)); do
    clear
    printf "${CYAN}SCAN RADAR : [%*s>${RESET}\n" "$i" ""
    sleep 0.02
  done
}

# ================================
#  Mode beep (ultra tactique)
# ================================
beep() {
  [[ "$MODE" == "beep" ]] && printf "\a"
}

# ================================
#  Mode furtif (silencieux)
# ================================
sleep_tactique() {
  [[ "$MODE" == "furtif" ]] && return
  sleep "$1"
}

# ================================
#  Animation principale
# ================================
animation() {
  for _ in {1..4}; do
    for frame in "${frames[@]}"; do
      fade_in "$frame"
      beep
      sleep_tactique 0.15
      fade_out "$frame"
    done
  done
}

# ================================
#  Exécution
# ================================
clear
scan_radar
animation

printf "${GREEN}[EBRIGADE][OK] Animation tactique terminée.${RESET}\n"
