# Configurateur Ubuntu 24.04 LTS – KVM/QEMU avec passthrough GPU

Configuration testée sur le matériel suivant :

```
CM    : Aorus X570 Pro
CPU   : AMD Ryzen 9 3900X
RAM   : Corsair 256 Go
GPU 1 : NVIDIA RTX 2080 Super
GPU 2 : NVIDIA GT 730

OS Host    : Ubuntu (Kubuntu) 24.04 LTS
OS GUEST 1 : Windows 10
OS GUEST 2 : Ubuntu (Kubuntu) 24.04 LTS
OS GUEST 3 : Ubuntu (Server) 24.04 LTS
```

Passthrough GPU fonctionnel sur :
- Windows 10
- Ubuntu (Kubuntu) 24.04 LTS


## Configuration du BIOS minimale

```
IOMMU : Enabled
SVM   : Enabled
```

## Vérification

Exécutez le script depuis le dossier.

```
sudo ./00_check_environment.sh
```

Cette commande retourne l'état de IOMMU et SVM ainsi que la liste des groupes IOMMU.
Vous pourrez choisir le GPU à utiliser en Passthrough à la fin du script :

```
Vérification du support AMD SVM...
SVM est pris en charge.
Vérification du support IOMMU...
IOMMU est activé.
Liste des groupes IOMMU...
Groupe IOMMU 0 00:00.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Root Complex [1022:1480]
[....]
Vérification des cartes graphiques...
Trouvé 2 GPUs. Suffisant pour le passthrough.
09:00.0 VGA compatible controller: NVIDIA Corporation TU104 [GeForce RTX 2080 SUPER] (rev a1)
0a:00.0 VGA compatible controller: NVIDIA Corporation GK208B [GeForce GT 730] (rev a1)
Veuillez identifier l'ID PCIe GPU Passthrough dans la liste suivante :
09:00.0 VGA compatible controller: NVIDIA Corporation TU104 [GeForce RTX 2080 SUPER] (rev a1)
0a:00.0 VGA compatible controller: NVIDIA Corporation GK208B [GeForce GT 730] (rev a1)
Entrez l'ID PCIe du GPU Passthrough (ex. : 01:00.0) :
```

Dans cette configuration :

```
0a:00.0
```

Attention nous trions ici que les VGA. Une carte graphique comporte au moins un périphérique VGA et un Audio dans le meme groupe IOMMU. Ca aura son importance par la suite.


## Installation des paquets

Exécutez le script depuis le dossier.

```
sudo ./01_install_packages.sh
```


## Configuration de l'host

Exécutez le script depuis le dossier.

```
sudo ./02_configure_system.sh
```

- Si vous avez des options spécifiques de démarrage dans GRUB le script ne les écrasera pas.
- Paramétrage d'un dossier partagé Samba à la fin du script, commenter les lignes si ce n'est pas nécessaire.
- Redémarrer.


## Création de la VM

 Lancer virt-manager et suivre les instructions de création.
 Une fois la VM créée vous devrez ```Ajouter un matériel``` et ajouter deux ```Périphériques Hote PCI```:
 - Un pour le VGA défini plus haut
 - Un pour l'Audio correspondant au meme périphérique

 Dans le cas de cette configuration :

```
 0A:00.0 # VGA
 0A:00.1 # Audio
```


## Système Windows

- Pour obtenir de bonnes performances vous devez installer les drivers virtio.
- Téléchargez ```Stable virtio-win ISO```
- Montez l'ISO dans un périphérique CD-ROM de la VM pour l'installer dans Windows.
```
https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
```
- Une fois installé, redémarrez la VM puis installez les drivers de la carte graphique.
- Redémarrez.
- Votre VM est prête à l'emploi avec un accès direct à votre deuxième GPU.
