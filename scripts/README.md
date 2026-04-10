🟩 README.md — Dossier scripts/

`markdown

🟩 Dossier scripts/

Modules d’administration – LeBrigade OS

Base Linux 22 (Xia) – Cinnamon Edition

---

🎯 Mission du dossier
Le dossier scripts/ contient l’ensemble des modules Bash permettant de configurer, personnaliser et administrer LeBrigade OS.  
Chaque script représente une unité opérationnelle indépendante, organisée selon une logique OPS / RENS / COMSEC (fictive).

---

🧩 Structure interne
`
scripts/
 ├── init/           # Préparation du système (mise à jour, paquets, base)
 ├── config/         # Personnalisation Cinnamon, thèmes, services
 ├── security/       # Renforcement COMSEC (fictif)
 └── deploy/         # Automatisation du déploiement et des profils
`

---

⚙️ Types de scripts
- 🔧 INIT — Mise en place du système  
- 🎨 CONFIG — Personnalisation visuelle et ergonomique  
- 🛡️ SECURITY — Modules COMSEC fictifs  
- 🚀 DEPLOY — Automatisation avancée  

Chaque script doit être :
- autonome  
- documenté en en-tête  
- compatible Bash strict (#!/bin/bash)  
- testé sur Linux 22 (Xia) Cinnamon  

---

🟩 Exemple de script minimal
`bash

!/bin/bash

[LBG-CONFIG] Configuration du thème Cinnamon

echo "[LBG] Application du thème personnalisé..."
gsettings set org.cinnamon.desktop.interface gtk-theme "LeBrigade-Dark"
`

---

📜 Convention de nommage
- [LBG-INIT] pour l’initialisation  
- [LBG-CONFIG] pour la personnalisation  
- [LBG-SEC] pour la sécurité  
- [LBG-DPL] pour le déploiement  

---

🪖 Devise du module
> “Automatiser, standardiser, sécuriser.”
`

---
