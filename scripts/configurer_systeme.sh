#!/bin/bash

set -e

echo "Début de l'installation des paquets"
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

# Charge le fichier de configuration
source "$BASE_DIR/config.conf"

echo "Début de la configuration du système"

# --- Configuration des groupes d'utilisateurs ---
echo "Ajout de $SUDO_USER aux groupes kvm et libvirt..."
for GROUP in kvm libvirt; do
    if ! id -nG "$SUDO_USER" | grep -qw "$GROUP"; then
        usermod -aG "$GROUP" "$SUDO_USER"
        echo "Utilisateur ajouté au groupe $GROUP."
    else
        echo "Utilisateur déjà dans le groupe $GROUP."
    fi
done

echo "Configuration des paramètres du noyau pour IOMMU..."
GRUB_FILE="/etc/default/grub"
GRUB_LINE=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE")
if ! echo "$GRUB_LINE" | grep -q "amd_iommu=on"; then
    NEW_GRUB_LINE=$(echo "$GRUB_LINE" | sed 's/"$/ amd_iommu=on iommu=pt"/')
    sed -i "s|$GRUB_LINE|$NEW_GRUB_LINE|" "$GRUB_FILE"
    update-grub
    echo "Paramètres IOMMU ajoutés à GRUB. Redémarrage requis."
else
    echo "Paramètres IOMMU déjà présents dans GRUB."
fi

echo "Configuration des modules VFIO..."
VFIO_CONF="/etc/modules-load.d/vfio.conf"
VFIO_MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")
touch "$VFIO_CONF"
for MODULE in "${VFIO_MODULES[@]}"; do
    if ! grep -Fx "$MODULE" "$VFIO_CONF" > /dev/null; then
        echo "$MODULE" >> "$VFIO_CONF"
        echo "Module $MODULE ajouté à $VFIO_CONF."
    else
        echo "Module $MODULE déjà présent dans $VFIO_CONF."
    fi
done

echo "Configuration du passthrough pour le GPU..."
if [ -z "$GPU_PCI_ID" ]; then
    echo "ERREUR : GPU_PCI_ID non défini dans config.conf."
    exit 1
fi

# Trouve le groupe IOMMU du GPU
IOMMU_GROUP=$(find /sys/kernel/iommu_groups/*/devices -name "*${GPU_PCI_ID}*" | cut -d'/' -f5)
if [ -z "$IOMMU_GROUP" ]; then
    echo "ERREUR : Impossible de trouver le groupe IOMMU pour $GPU_PCI_ID."
    exit 1
fi
echo "Groupe IOMMU du GPU ($GPU_PCI_ID) : $IOMMU_GROUP"

# Récupère tous les PCI IDs du groupe IOMMU
VFIO_IDS=""
for DEVICE in /sys/kernel/iommu_groups/$IOMMU_GROUP/devices/*; do
    PCI_ID=$(basename "$DEVICE")
    VENDOR_DEVICE=$(lspci -n -s "$PCI_ID" | awk '{print $3}' | tr -d '[]')
    if [ -n "$VENDOR_DEVICE" ]; then
        VFIO_IDS="$VFIO_IDS${VFIO_IDS:+,}$VENDOR_DEVICE"
    fi
done
if [ -z "$VFIO_IDS" ]; then
    echo "ERREUR : Aucun dispositif trouvé dans le groupe IOMMU $IOMMU_GROUP."
    exit 1
fi
echo "Dispositifs à attacher à vfio-pci : $VFIO_IDS"

# Configure vfio-pci pour tous les dispositifs du groupe
VFIO_MODPROBE="/etc/modprobe.d/vfio.conf"
tee "$VFIO_MODPROBE" > /dev/null <<EOT
options vfio-pci ids=$VFIO_IDS disable_vga=1
EOT
update-initramfs -u
echo "Groupe IOMMU $IOMMU_GROUP configuré pour le passthrough VFIO. Redémarrage requis."

# --- Création du dossier partagé ---
echo "Création du dossier partagé à $SHARED_FOLDER..."
SHARED_FOLDER=$(echo "$SHARED_FOLDER" | sed "s|\$SUDO_USER|$SUDO_USER|")
mkdir -p "$SHARED_FOLDER"
chown "$SUDO_USER:$SUDO_USER" "$SHARED_FOLDER"
chmod 777 "$SHARED_FOLDER"
echo "Dossier partagé créé (propriétaire : $SUDO_USER)."

# --- Configuration des chemins par défaut pour KVM/QEMU ---
echo "Configuration des chemins par défaut pour KVM/QEMU..."
QEMU_CONF="/etc/libvirt/qemu.conf"
# Remplace $SUDO_USER dans les chemins
VM_STORAGE_DIR=$(echo "$VM_STORAGE_DIR" | sed "s|\$SUDO_USER|$SUDO_USER|")
ISO_DIR=$(echo "$ISO_DIR" | sed "s|\$SUDO_USER|$SUDO_USER|")

# Crée les répertoires s'ils n'existent pas
mkdir -p "$VM_STORAGE_DIR" "$ISO_DIR"
chown "$SUDO_USER:$SUDO_USER" "$VM_STORAGE_DIR" "$ISO_DIR"
chmod 755 "$VM_STORAGE_DIR" "$ISO_DIR"

# Vérifie et met à jour le chemin des disques virtuels
if ! grep -q "^disk_image_dir = \"$VM_STORAGE_DIR\"" "$QEMU_CONF"; then
    if grep -q "^disk_image_dir = " "$QEMU_CONF"; then
        sed -i "s|^disk_image_dir = .*|disk_image_dir = \"$VM_STORAGE_DIR\"|" "$QEMU_CONF"
    else
        echo "disk_image_dir = \"$VM_STORAGE_DIR\"" >> "$QEMU_CONF"
    fi
    echo "Chemin des disques virtuels configuré à $VM_STORAGE_DIR."
else
    echo "Chemin des disques virtuels déjà configuré à $VM_STORAGE_DIR."
fi

# Vérifie et met à jour le chemin des ISOs
if ! grep -q "^iso_image_dir = \"$ISO_DIR\"" "$QEMU_CONF"; then
    if grep -q "^iso_image_dir = " "$QEMU_CONF"; then
        sed -i "s|^iso_image_dir = .*|iso_image_dir = \"$ISO_DIR\"|" "$QEMU_CONF"
    else
        echo "iso_image_dir = \"$ISO_DIR\"" >> "$QEMU_CONF"
    fi
    echo "Chemin des ISOs configuré à $ISO_DIR."
else
    echo "Chemin des ISOs déjà configuré à $ISO_DIR."
fi

# Redémarre libvirt pour appliquer les modifications
systemctl restart libvirtd
echo "Service libvirt redémarré pour appliquer les nouveaux chemins."

# --- Configuration de Samba pour le dossier partagé ---
echo "Configuration de Samba pour le dossier partagé..."
SMB_CONF="/etc/samba/smb.conf"  # Corrigé : ajout du chemin correct pour smb.conf
if ! grep -q "\[Shared\]" "$SMB_CONF"; then
    tee -a "$SMB_CONF" > /dev/null <<EOT
[Shared]
path = $SHARED_FOLDER
writable = yes
browsable = yes
guest ok = yes
create mask = 0777
directory mask = 0777
EOT
    systemctl restart smbd
    echo "Samba configuré et redémarré."
else
    echo "Partage Samba déjà configuré."
fi

echo "Configuration du système terminée. Redémarrage requis."
