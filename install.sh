#!/usr/bin/env bash
set -euo pipefail

##############################################
#  EBRIGADE OS V2 — INSTALLATEUR             #
##############################################

umask 027

# === Couleurs tactiques ===
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

log_info()    { echo -e "${GREEN}[EBRIGADE][INFO]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[EBRIGADE][WARN]${RESET} $1"; }
log_error()   { echo -e "${RED}[EBRIGADE][ERROR]${RESET} $1"; }
log_action()  { echo -e "${BLUE}[EBRIGADE][ACTION]${RESET} $1"; }

# === Variables ===
PROJECT_NAME="EBrigade OS V2"
PREFIX="/usr/local"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/ebrigade"
MAN_DIR="/usr/local/share/man/man1"

LOG_DIR="/var/log/ebrigade"
mkdir -p "$LOG_DIR"
chmod 0750 "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date +%F_%H%M%S).log"

# Rediriger tout vers le log + console
exec > >(tee -a "$LOG_FILE") 2>&1

GPG_KEY="ebrigade.gpg"
SIGNATURE_FILE="ebrigade.sig"

ROLLBACK_DIR="/tmp/ebrigade_rollback"
mkdir -p "$ROLLBACK_DIR"

###############################################
# 1. Vérification environnement & privilèges
###############################################
if [[ "$(uname -s)" != "Linux" ]]; then
    log_error "Environnement non supporté (Linux requis)."
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté avec sudo ou en root."
    exit 1
fi

###############################################
# 2. Vérification des dépendances
###############################################
DEPENDANCES=(gpg mandb install mkdir tee)

log_action "Vérification des dépendances système…"
for dep in "${DEPENDANCES[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        log_error "Dépendance manquante : $dep"
        exit 1
    fi
done
log_info "Toutes les dépendances sont présentes."

###############################################
# 3. Vérification des mises à jour système
###############################################
if command -v apt >/dev/null 2>&1; then
    log_action "Analyse des mises à jour système (APT)…"
    if apt list --upgradable 2>/dev/null | grep -q upgradable; then
        log_warn "Des mises à jour sont disponibles. Recommandé : apt update && apt upgrade"
    else
        log_info "Système APT à jour."
    fi
else
    log_warn "Gestionnaire APT non détecté, vérification des mises à jour ignorée."
fi

###############################################
# 4. Vérification de la signature GPG
###############################################
if [[ -f "$GPG_KEY" && -f "$SIGNATURE_FILE" ]]; then
    log_action "Vérification de l’intégrité via GPG…"
    if gpg --verify "$SIGNATURE_FILE" "$GPG_KEY" >/dev/null 2>&1; then
        log_info "Signature GPG valide. Intégrité confirmée."
    else
        log_error "Signature GPG invalide. Installation annulée."
        exit 1
    fi
else
    log_warn "Aucune signature GPG trouvée. Installation non sécurisée (mode dégradé)."
fi

###############################################
# 5. Rollback
###############################################
rollback() {
    log_warn "Rollback en cours…"
    if [[ -d "$ROLLBACK_DIR" ]]; then
        cp -a "$ROLLBACK_DIR"/. / || true
        log_info "Rollback terminé."
    else
        log_warn "Aucune sauvegarde rollback disponible."
    fi
}
trap rollback ERR

###############################################
# 6. Sauvegarde avant installation
###############################################
log_action "Sauvegarde des fichiers existants…"
for path in "$BIN_DIR/ebrigade" "$SHARE_DIR" "$MAN_DIR/ebrigade.1"; do
    if [[ -e "$path" ]]; then
        dest="$ROLLBACK_DIR${path}"
        mkdir -p "$(dirname "$dest")"
        cp -a "$path" "$dest"
    fi
done

###############################################
# 7. Création des dossiers
###############################################
log_action "Création des dossiers…"
mkdir -p "$BIN_DIR" "$SHARE_DIR/modules" "$SHARE_DIR/assets" "$MAN_DIR"
chmod 0755 "$BIN_DIR"
chmod 0750 "$SHARE_DIR" "$SHARE_DIR/modules" "$SHARE_DIR/assets"

###############################################
# 8. Installation du TUI principal
###############################################
log_action "Installation du TUI principal…"
if [[ -f "scripts/ebrigade.sh" ]]; then
    install -m 0755 scripts/ebrigade.sh "$BIN_DIR/ebrigade"
    log_info "TUI installé dans $BIN_DIR/ebrigade."
else
    log_warn "scripts/ebrigade.sh introuvable, TUI non installé."
fi

###############################################
# 9. Installation des modules + auto‑détection
###############################################
MODULE_INDEX="$SHARE_DIR/modules/modules.list"
> "$MODULE_INDEX"

log_action "Installation des modules et auto‑détection…"
if [[ -d "modules" ]]; then
    # Copie sécurisée
    find "modules" -type f -maxdepth 2 | while read -r mod; do
        rel="${mod#modules/}"
        target="$SHARE_DIR/modules/$rel"
        mkdir -p "$(dirname "$target")"
        install -m 0644 "$mod" "$target"

        # Si exécutable ou script .sh, on le marque comme module actif
        if [[ -x "$mod" || "$mod" == *.sh ]]; then
            chmod 0755 "$target"
            echo "$rel" >> "$MODULE_INDEX"
            log_info "Module détecté et enregistré : $rel"
        else
            log_info "Ressource module non exécutable : $rel"
        fi
    done
    log_info "Index des modules généré : $MODULE_INDEX"
else
    log_warn "Dossier modules/ introuvable, aucun module installé."
fi

###############################################
# 10. Installation des assets
###############################################
log_action "Installation des assets…"
if [[ -d "assets" ]]; then
    find "assets" -type f | while read -r asset; do
        rel="${asset#assets/}"
        target="$SHARE_DIR/assets/$rel"
        mkdir -p "$(dirname "$target")"
        install -m 0644 "$asset" "$target"
    done
    log_info "Assets installés dans $SHARE_DIR/assets."
else
    log_warn "Dossier assets/ introuvable, aucun asset installé."
fi

###############################################
# 11. Installation de la manpage
###############################################
log_action "Installation de la manpage…"
if [[ -f "docs/man/ebrigade.1" ]]; then
    install -m 0644 docs/man/ebrigade.1 "$MAN_DIR/ebrigade.1"
    mandb >/dev/null 2>&1 || true
    log_info "Manpage installée : man ebrigade"
else
    log_warn "docs/man/ebrigade.1 introuvable, manpage non installée."
fi

###############################################
# 12. Durcissement final & résumé
###############################################
chmod 0755 "$BIN_DIR/ebrigade" 2>/dev/null || true
chmod 0640 "$LOG_FILE" || true

log_info "Installation de ${PROJECT_NAME} terminée."
log_info "Commande disponible : ebrigade"
log_info "Logs centralisés : $LOG_FILE"
echo -e "${GREEN}Mission accomplie. EBrigade OS V2 opérationnel.${RESET}"
