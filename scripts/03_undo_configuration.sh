#!/bin/bash

# ------------------------------------------------------------------------------
# 03_undo_configuration.sh
# Description : Script pour annuler la configuration système mise en place pour la
#               virtualisation, incluant les paramètres GRUB pour IOMMU, les modules
#               VFIO, la configuration du passthrough GPU et le partage Samba.
# ------------------------------------------------------------------------------

# Active l'arrêt du script à la première erreur
set -e

# ------------------------------------------------------------------------------
# Initialisation
# Description : Affiche un message indiquant le début de l'annulation de la
#               configuration.
# ------------------------------------------------------------------------------
echo "Début de l'annulation de la configuration"
echo ""

# ------------------------------------------------------------------------------
# Vérification de l'exécution avec sudo
# Description : Vérifie que le script est exécuté avec les privilèges sudo et que
#               l'utilisateur courant est défini.
# ------------------------------------------------------------------------------
if [ -z "$SUDO_USER" ]; then
    echo "ERREUR : Ce script doit être exécuté avec sudo."
    exit 1
fi
echo "Utilisateur courant : $SUDO_USER"
echo ""

# ------------------------------------------------------------------------------
# Annulation de la configuration GRUB
# Description : Supprime les paramètres IOMMU de la configuration GRUB et met à
#               jour GRUB si nécessaire.
# ------------------------------------------------------------------------------
echo "Annulation de la configuration de GRUB..."
GRUB_FILE="/etc/default/grub"
if grep -q "amd_iommu=on" "$GRUB_FILE"; then
    sed -i 's/ amd_iommu=on iommu=pt//g' "$GRUB_FILE"
    update-grub
    echo "Paramètres IOMMU supprimés de GRUB."
else
    echo "Aucun paramètre IOMMU trouvé dans GRUB."
fi

# ------------------------------------------------------------------------------
# Suppression des modules VFIO
# Description : Supprime les modules VFIO du fichier de configuration des modules
#               du noyau et supprime le fichier s'il est vide.
# ------------------------------------------------------------------------------
echo "Suppression des modules VFIO..."
VFIO_CONF="/etc/modules-load.d/vfio.conf"
if [ -f "$VFIO_CONF" ]; then
    VFIO_MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")
    for MODULE in "${VFIO_MODULES[@]}"; do
        if grep -Fx "$MODULE" "$VFIO_CONF" > /dev/null; then
            sed -i "/^$MODULE$/d" "$VFIO_CONF"
            echo "Module $MODULE supprimé de $VFIO_CONF."
        fi
    done
    if [ ! -s "$VFIO_CONF" ]; then
        rm -f "$VFIO_CONF"
        echo "Fichier $VFIO_CONF supprimé car vide."
    fi
else
    echo "Aucun fichier $VFIO_CONF trouvé."
fi

# ------------------------------------------------------------------------------
# Suppression de la configuration VFIO pour le GPU
# Description : Supprime le fichier de configuration du pilote vfio-pci et met à
#               jour l'initramfs pour annuler le passthrough GPU.
# ------------------------------------------------------------------------------
echo "Suppression de la configuration VFIO pour le GPU..."
VFIO_MODPROBE="/etc/modprobe.d/vfio.conf"
if [ -f "$VFIO_MODPROBE" ]; then
    rm -f "$VFIO_MODPROBE"
    echo "Fichier $VFIO_MODPROBE supprimé."
    update-initramfs -u
    echo "Configuration VFIO annulée. Redémarrage requis."
else
    echo "Aucun fichier $VFIO_MODPROBE trouvé."
fi

# ------------------------------------------------------------------------------
# Suppression de la configuration Samba
# Description : Supprime la section de configuration du partage Samba dans smb.conf
#               et redémarre le service Samba.
# ------------------------------------------------------------------------------
echo "Suppression de la configuration du partage Samba..."
SMB_CONF="/etc/samba/smb.conf"
if grep -q "\[Shared\]" "$SMB_CONF"; then
    sed -i "/\[Shared\]/,/directory mask = 0777/d" "$SMB_CONF"
    systemctl restart smbd
    echo "Configuration du partage Samba supprimée."
else
    echo "Aucun partage Samba à supprimer."
fi

# ------------------------------------------------------------------------------
# Finalisation
# Description : Affiche un message confirmant que l'annulation de la configuration
#               s'est terminée avec succès, en notant qu'un redémarrage est requis.
# ------------------------------------------------------------------------------
echo "Annulation de la configuration terminée. Redémarrage requis."
