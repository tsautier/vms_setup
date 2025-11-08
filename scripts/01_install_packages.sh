#!/bin/bash

# ------------------------------------------------------------------------------
# 01_install_packages.sh
# Description : Script d'installation des paquets nécessaires pour la
#               virtualisation avec KVM/QEMU, Virt-Manager, les outils de
#               passthrough GPU et Samba pour le partage de dossiers.
# ------------------------------------------------------------------------------

# Active l'arrêt du script à la première erreur
set -e

# ------------------------------------------------------------------------------
# Initialisation
# Description : Affiche un message indiquant le début de l'installation des paquets.
# ------------------------------------------------------------------------------
echo "Début de l'installation des paquets"
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
# Mise à jour des paquets
# Description : Met à jour la liste des paquets disponibles pour garantir
#               l'installation des versions les plus récentes.
# ------------------------------------------------------------------------------
echo "Mise à jour de la liste des paquets..."
apt update -y

# ------------------------------------------------------------------------------
# Installation de KVM/QEMU, Virt-Manager et outils associés
# Description : Installe les paquets nécessaires pour la virtualisation, y compris
#               KVM/QEMU, Virt-Manager, et les outils de gestion de machines
#               virtuelles.
# ------------------------------------------------------------------------------
echo "Installation de KVM/QEMU, Virt-Manager et outils associés..."
apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager \
    bridge-utils \
    ovmf \
    virtinst

# ------------------------------------------------------------------------------
# Installation des outils pour le passthrough GPU
# Description : Installe les outils nécessaires pour configurer le passthrough GPU
#               dans un environnement de virtualisation.
# ------------------------------------------------------------------------------
echo "Installation des outils pour le passthrough GPU..."
apt install -y libguestfs-tools

# ------------------------------------------------------------------------------
# Installation de Samba
# Description : Installe Samba pour permettre le partage de dossiers entre l'hôte
#               et les machines virtuelles.
# ------------------------------------------------------------------------------
echo "Installation de Samba pour le dossier partagé..."
apt install -y samba

# ------------------------------------------------------------------------------
# Activation et démarrage du service libvirtd
# Description : Active le service libvirtd pour qu'il démarre automatiquement au
#               démarrage du système et le lance immédiatement.
# ------------------------------------------------------------------------------
echo "Activation et démarrage du service libvirtd..."
systemctl enable libvirtd
systemctl start libvirtd

# ------------------------------------------------------------------------------
# Finalisation
# Description : Affiche un message confirmant que l'installation des paquets s'est
#               terminée avec succès.
# ------------------------------------------------------------------------------
echo "Installation des paquets terminée"
