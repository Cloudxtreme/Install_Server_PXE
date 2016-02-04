#!/bin/sh
############################################################################
############################################################################
#
#
#
#                     Install_Server_PXE.sh
#                          version 1.0
#                    sidney jacques sidjack972@gmail.com
#
#
############################################################################
# Définition: Script d'installation d'un serveur DHCP et PXE 
#
###########################################################################
# VERSION: 1.0 
#
##########################################################################
##########################################################################

#=========================== DEBUT DU SCRIPT =============================

#====================== Verification que l'utilisateur soit bien root ====
i=$(id -u)
if [ $? -ne 0 ]; then exit 1; fi
if [ "$i" -ne 0 ]
then
echo "L'installation doit se faire sous root" >&2
exit 2
fi
#=========================== DOSSIERS ======================================
# Vérifie la présence du dossier logInstall
if [ -d "/var/log/LogInstall" ] ; then 
    # vérifie la prensence du fichier InstallSRVDHCP.log 
    if [ ! -f "/var/log/LogInstall/InstallSRVDHCP.log" ]; then
        touch /var/log/logInstall/InstallSRVDHCP.log
    fi
else
 mkdir /var/log/logInstall
 touch /var/log/logInstall/InstallSRVDHCP.log
fi
# Dossier tftpboot ISO pxelinux.cfg
mkdir /tftpboot
mkdir /tftpboot/ISO
mkdir /tftpboot/pxelinux.cfg
# Fichiers default

# Redirection Globale erreur et resultat vers logInstallSRVDHCP
exec  1> /var/log/logInstall/InstallPXE.log 
exec  2> /var/log/logInstall/InstallPXE.log 
#=========================== Variables ===================================
# Cartes reseau eth0 eth1 
ipEth0=192.168.1.23
netmskEth0=255.255.255.0
gtwayEth0=192.168.1.1
ipEth1=192.168.2.23
netmskEth1=255.255.255.0

# DHCP
adressReseauIp=192.168.2.0 
plageIpDebut=192.168.2.100
plageIpFin=192.168.2.200
masqSsreseau=255.255.255.0
adresseSrvDns1="192.168.1.23"
adresseSrvDns2="192.168.2.23"
domaine="sidteste.fr"
tempBailDefault=86400   # Bail par defaut (en seconde)
tempBailMax=691200      # Bail Max (en seconde)

jour=" ====== $(date +%a%d/%m/%y%t==============%t%T%t===========)"
#=========================== Mise à jour du système ======================
echo "---------------------------------------------------------"
echo ":         DEBUT Mise à jour du système                  :" 
echo "---------------------------------------------------------"
echo $jour
apt-get update && apt-get dist-upgrade -y && echo "Mise a jour OK!" || ping -c 4 8.8.4.4 || echo -e '\33[31m Problème de connexion a internet \33[0m' 
#=========================== Configuration des Cartes reseaux ============
# Sauvegarde configuration des cartes reseaux
cp /etc/network/interfaces /etc/network/interfaces.original 
# Configuration cartes reseaux
cat > /etc/network/interfaces << EOF
##########################################
#                                        #
#            Cartes Reseaux              #
#                                        #
##########################################
# loopback
auto lo 
iface lo inet loopback

# Premiere carte reseau eth0
auto eth0
  iface eth0 inet static
  address $ipEth0
  netmask $netmskEth0
  gateway $gtwayEth0

# Deuxieme carte reseau eth1
auto eth1
  iface eth1 inet static
  address $ipEth1
  netmask $netmskEth1
    

EOF
echo "Configuration des cartes reseau    OK !"
echo "---------------------------------------------------------"
echo ":         DEBUT l'installation des services             :" 
echo "---------------------------------------------------------"
#=========================== Installation des Services =======================
apt-get install -y isc-dhcp-server tftpd-hpa proftpd pxelinux syslinux
#=========================== Configuration du Service DHCP ===================
# Sauvegarde du fichier de configuration original
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.original
# Configuration du service DHCP
cat > /etc/dhcp/dhcpd.conf << EOF
#################################################
#                                               #
#   Configuration simple ISC DHCP pour Debian   #
#                                               #
#################################################

# DHCP autoritaire
authoritative;       

ddns-update-style none;

# Addresse serveur DNS et domaine
option domain-name-servers $adresseSrvDns1, $adresseSrvDns2; 
option domain-name "$domaine";
# Bail
default-lease-time $tempBailDefault;       # Bail en (s)  1 jour 
max-lease-time $tempBailMax;          # Bail max en (s)  8 jours

log-facility local7;

# Distrubition adresse IP 
subnet $adressReseauIp netmask $masqSsreseau {
    # Plage adresse IP
    range $plageIpDebut $plageIpFin;
    
}
next-server $ipEth1;
filename "pxelinux.0";

EOF
# Configuration des Interfaces reseaux d'ecoute
cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.original
sed -i 's/INTERFACES=""/INTERFACES="eth1"/g' /etc/default/isc-dhcp-server
#================== Copie des fichiers nécessaire pour PXE ===================
cp -R /usr/lib/syslinux/* /usr/lib/PXELINUX/* /tftpboot
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /tftpboot
#====================== Configuration du service TFPT ===================
cp /etc/default/tftpd-hpa /etc/default/tftpd-hpa.original
cat > /etc/default/tftpd-hpa << EOF 
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/tftpboot"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure"
EOF
#====================== Configuration du service FTP ====================

#=============================== MENU PXE ===============================
cat > /tftpboot/pxelinux.cfg/default << EOF
MENU TITLE SERVEUR PXE
PATH /modules/bios/
default menu.c32
prompt 0
noescape 1
timeout 300
LABEL 1
MENU LABEL Demarrer sur le premier disque dur
COM32 chain.c32
APPEND hd0
LABEL 2
MENU LABEL CLONEZILLA 64 BITS
LINUX memdisk
INITRD /ISO/clonezilla-live-amd64.iso
APPEND iso
LABEL 3
MENU LABEL Redemarrer 
COM32 reboot.c32
EOF

# Redemarrage des services
echo "+----------------------------------------------------------------+"  
echo ":     Appliquer les modification sur les cartes reseaux         :"
echo "+----------------------------------------------------------------+"
/etc/init.d/networking restart && echo " Les cartes reseaux OK " 
echo "----------------------------------------------------------------"  
echo ":                Démmarrage du service DHCP                    :"
echo "----------------------------------------------------------------"
/etc/init.d/isc-dhcp-server restart && echo " Le service DHCP OK"
echo "----------------------------------------------------------------"  
echo ":                Démmarrage du service TFTP                    :"
echo "----------------------------------------------------------------"
/etc/init.d/tftpd-hpa restart && echo " Le service TFTP OK"
wget http://sourceforge.net/projects/clonezilla/files/clonezilla_live_stable/2.4.2-61/clonezilla-live-2.4.2-61-amd64.iso && mv clonezilla-live-2.4.2-61-amd64.iso /tftpboot/ISO/clonezilla-live-amd64.iso
exit