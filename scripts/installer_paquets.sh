#!/bin/bash

set -e

echo "Début de l'installation des paquets"
echo ""

if [ -z "$SUDO_USER" ]; then
    echo "ERREUR : Ce script doit être exécuté avec sudo."
    exit 1
fi

echo "Utilisateur courant : $SUDO_USER"
echo ""

echo "Mise à jour de la liste des paquets..."
apt update -y

echo "Installation de KVM/QEMU, Virt-Manager et outils associés..."
apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager \
    bridge-utils \
    ovmf \
    virtinst

echo "Installation des outils pour le passthrough GPU..."
apt install -y libguestfs-tools

echo "Installation de Samba pour le dossier partagé..."
apt install -y samba

echo "Activation et démarrage du service libvirtd..."
systemctl enable libvirtd
systemctl start libvirtd

echo "Installation des paquets terminée"
