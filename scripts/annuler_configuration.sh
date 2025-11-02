#!/bin/bash

set -e

echo "Début de l'annulation de la configuration"
echo ""

# Vérifie que l'utilisateur courant (via sudo) est défini
if [ -z "$SUDO_USER" ]; then
    echo "ERREUR : Ce script doit être exécuté avec sudo."
    exit 1
fi

echo "Utilisateur courant : $SUDO_USER"
echo ""

echo "Annulation de la configuration de GRUB..."
GRUB_FILE="/etc/default/grub"
if grep -q "amd_iommu=on" "$GRUB_FILE"; then
    # Supprime les paramètres IOMMU de GRUB
    sed -i 's/ amd_iommu=on iommu=pt//g' "$GRUB_FILE"
    update-grub
    echo "Paramètres IOMMU supprimés de GRUB."
else
    echo "Aucun paramètre IOMMU trouvé dans GRUB."
fi

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
    # Supprime le fichier s'il est vide
    if [ ! -s "$VFIO_CONF" ]; then
        rm -f "$VFIO_CONF"
        echo "Fichier $VFIO_CONF supprimé car vide."
    fi
else
    echo "Aucun fichier $VFIO_CONF trouvé."
fi

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

echo "Suppression de la configuration du partage Samba..."
SMB_CONF="/etc/samba/smb.conf"
if grep -q "\[Shared\]" "$SMB_CONF"; then
    sed -i "/\[Shared\]/,/directory mask = 0777/d" "$SMB_CONF"
    systemctl restart smbd
    echo "Configuration du partage Samba supprimée."
else
    echo "Aucun partage Samba à supprimer."
fi

echo "Annulation de la configuration terminée. Redémarrage requis."
