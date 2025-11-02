#!/bin/bash

set -e

echo "Début de la vérification de l'environnement"
echo ""

# Vérifie que l'utilisateur courant (via sudo) est défini
if [ -z "$SUDO_USER" ]; then
    echo "ERREUR : Ce script doit être exécuté avec sudo."
    exit 1
fi

echo "Utilisateur courant : $SUDO_USER"
echo ""

# Détermine le répertoire racine du projet
BASE_DIR=$(dirname "$(realpath "$0")")/..

# Vérifie si le fichier de configuration existe
CONFIG_FILE="$BASE_DIR/config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERREUR : Le fichier de configuration $CONFIG_FILE n'existe pas."
    exit 1
fi

# Vérifie si le CPU prend en charge SVM (Secure Virtual Machine)
echo "Vérification du support AMD SVM..."
if grep -q "svm" /proc/cpuinfo; then
    echo "SVM est pris en charge."
else
    echo "ERREUR : SVM n'est pas pris en charge. La virtualisation ne peut pas continuer."
    exit 1
fi

# Vérifie si IOMMU est activé dans le noyau
echo "Vérification du support IOMMU..."
if dmesg | grep -q "AMD-Vi: IOMMU"; then
    echo "IOMMU est activé."
else
    echo "ERREUR : IOMMU n'est pas activé. Veuillez l'activer dans le BIOS et les paramètres du noyau."
    exit 1
fi

# Liste les groupes IOMMU et les enregistre
echo "Liste des groupes IOMMU..."
# Définit un chemin par défaut pour IOMMU_GROUPS_FILE
IOMMU_GROUPS_FILE="/home/$SUDO_USER/iommu_groups.txt"
mkdir -p "$(dirname "$IOMMU_GROUPS_FILE")"
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/}
    n=${n%%/*}
    printf 'Groupe IOMMU %s ' "$n"
    lspci -nns "${d##*/}"
done | tee "$IOMMU_GROUPS_FILE"
# Change la propriété du fichier pour l'utilisateur courant
chown "$SUDO_USER:$SUDO_USER" "$IOMMU_GROUPS_FILE"
echo "Groupes IOMMU enregistrés dans $IOMMU_GROUPS_FILE (propriétaire : $SUDO_USER)."

# Vérifie la présence d'au moins deux cartes graphiques
echo "Vérification des cartes graphiques..."
GPU_COUNT=$(lspci | grep -E "VGA|3D" | wc -l)
if [ "$GPU_COUNT" -ge 2 ]; then
    echo "Trouvé $GPU_COUNT GPUs. Suffisant pour le passthrough."
    lspci | grep -E "VGA|3D"
else
    echo "ERREUR : Moins de 2 GPUs détectés. Au moins deux sont requis."
    exit 1
fi

# Demande à l'utilisateur d'identifier l'ID PCIe du GPU Passthrough
echo "Veuillez identifier l'ID PCIe GPU Passthrough dans la liste suivante :"
lspci | grep -E "VGA|3D" | grep -i nvidia
read -p "Entrez l'ID PCIe du GPU Passthrough (ex. : 01:00.0) : " GPU_PASS
if [ -z "$GPU_PASS" ]; then
    echo "ERREUR : Aucun ID PCIe fourni."
    exit 1
fi

# Met à jour config.conf avec l'ID PCIe du GPU Passthrough
echo "Mise à jour de la configuration avec l'ID PCIe du GPU Passthrough..."
if grep -q "GPU_PCI_ID=" "$CONFIG_FILE"; then
    sed -i "s/GPU_PCI_ID=\".*\"/GPU_PCI_ID=\"$GPU_PASS\"/" "$CONFIG_FILE"
    if [ $? -eq 0 ]; then
        echo "ID PCIe du GPU Passthrough défini à $GPU_PASS."
    else
        echo "ERREUR : Échec de la mise à jour de GPU_PCI_ID dans $CONFIG_FILE."
        exit 1
    fi
else
    echo "GPU_PCI_ID=\"$GPU_PASS\"" >> "$CONFIG_FILE"
    echo "ID PCIe du GPU Passthrough ajouté à $CONFIG_FILE."
fi

# Change la propriété de config.conf pour l'utilisateur courant
chown "$SUDO_USER:$SUDO_USER" "$CONFIG_FILE"
echo "Propriétaire de $CONFIG_FILE mis à jour pour $SUDO_USER."

echo "Vérification de l'environnement terminée avec succès"
