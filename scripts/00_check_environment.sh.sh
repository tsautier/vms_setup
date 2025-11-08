#!/bin/bash

# ------------------------------------------------------------------------------
# 00_check_environment.sh
# Description : Script de vérification de l'environnement système pour assurer
#               que les prérequis pour la virtualisation avec GPU passthrough sont
#               remplis, et mise à jour du fichier de configuration avec l'ID PCIe
#               du GPU sélectionné.
# ------------------------------------------------------------------------------

# Active l'arrêt du script à la première erreur
set -e

# ------------------------------------------------------------------------------
# Initialisation
# Description : Affiche un message indiquant le début de la vérification de
#               l'environnement.
# ------------------------------------------------------------------------------
echo "Début de la vérification de l'environnement"
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
# Détermination du répertoire racine du projet
# Description : Calcule le chemin du répertoire racine du projet à partir de
#               l'emplacement du script.
# ------------------------------------------------------------------------------
BASE_DIR=$(dirname "$(realpath "$0")")/..

# ------------------------------------------------------------------------------
# Vérification de l'existence du fichier de configuration
# Description : Vérifie si le fichier de configuration config.conf existe dans le
#               répertoire racine du projet.
# ------------------------------------------------------------------------------
CONFIG_FILE="$BASE_DIR/config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERREUR : Le fichier de configuration $CONFIG_FILE n'existe pas."
    exit 1
fi

# ------------------------------------------------------------------------------
# Vérification du support AMD SVM
# Description : Vérifie si le CPU prend en charge la fonctionnalité Secure Virtual
#               Machine (SVM) nécessaire pour la virtualisation.
# ------------------------------------------------------------------------------
echo "Vérification du support AMD SVM..."
if grep -q "svm" /proc/cpuinfo; then
    echo "SVM est pris en charge."
else
    echo "ERREUR : SVM n'est pas pris en charge. La virtualisation ne peut pas continuer."
    exit 1
fi

# ------------------------------------------------------------------------------
# Vérification du support IOMMU
# Description : Vérifie si l'IOMMU est activé dans le noyau, une condition
#               essentielle pour le passthrough GPU.
# ------------------------------------------------------------------------------
echo "Vérification du support IOMMU..."
if dmesg | grep -q "AMD-Vi: IOMMU"; then
    echo "IOMMU est activé."
else
    echo "ERREUR : IOMMU n'est pas activé. Veuillez l'activer dans le BIOS et les paramètres du noyau."
    exit 1
fi

# ------------------------------------------------------------------------------
# Vérification des cartes graphiques
# Description : Vérifie la présence d'au moins deux cartes graphiques pour permettre
#               le passthrough GPU.
# ------------------------------------------------------------------------------
echo "Vérification des cartes graphiques..."
GPU_COUNT=$(lspci | grep -E "VGA|3D" | wc -l)
if [ "$GPU_COUNT" -ge 2 ]; then
    echo "Trouvé $GPU_COUNT GPUs. Suffisant pour le passthrough."
    lspci | grep -E "VGA|3D"
else
    echo "ERREUR : Moins de 2 GPUs détectés. Au moins deux sont requis."
    exit 1
fi

# ------------------------------------------------------------------------------
# Saisie de l'ID PCIe du GPU Passthrough
# Description : Demande à l'utilisateur de sélectionner l'ID PCIe du GPU à utiliser
#               pour le passthrough parmi la liste des GPUs NVIDIA détectés.
# ------------------------------------------------------------------------------
echo "Veuillez identifier l'ID PCIe GPU Passthrough dans la liste suivante :"
lspci | grep -E "VGA|3D" | grep -i nvidia
read -p "Entrez l'ID PCIe du GPU Passthrough (ex. : 01:00.0) : " GPU_PASS
if [ -z "$GPU_PASS" ]; then
    echo "ERREUR : Aucun ID PCIe fourni."
    exit 1
fi

# ------------------------------------------------------------------------------
# Mise à jour du fichier de configuration
# Description : Met à jour ou ajoute l'ID PCIe du GPU Passthrough dans le fichier
#               config.conf.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Mise à jour des permissions du fichier de configuration
# Description : Change le propriétaire du fichier config.conf pour l'utilisateur
#               courant (SUDO_USER).
# ------------------------------------------------------------------------------
chown "$SUDO_USER:$SUDO_USER" "$CONFIG_FILE"
echo "Propriétaire de $CONFIG_FILE mis à jour pour $SUDO_USER."

# ------------------------------------------------------------------------------
# Finalisation
# Description : Affiche un message confirmant que la vérification de l'environnement
#               s'est terminée avec succès.
# ------------------------------------------------------------------------------
echo "Vérification de l'environnement terminée avec succès"
