# Establish a wifi connection and check ethernet connection
ip a
iwctl
station wlan device connect ""
enter passphrase
directly: iwctl --passphrase "" station wlan device connect SSID

loadkeys de-latin1
setfont ter-132n
ping archlinux.org
# Create partitions
# Establish a wifi connection and check ethernet connection
ip a
iwctl
station wlan device connect ""
enter passphrase
directly: iwctl --passphrase "" station wlan device connect SSID

loadkeys de-latin1
setfont ter-132n
ping archlinux.org
# Create partitions
fdisk -l 
fdisk /dev/device
g for new partition table
n for new partition 
Last Sector for partition size
t for partition type
1 for EFI Partition 
44 for LVM Partition
# Create filesystems 
mkfs.fat --label EFI -F32 /dev/nvme0n1p1
mkfs.btrfs --label Boot /dev/nvme0n1p2 Boot partition
## Encrypt drive and create filesystem and mount
cryptsetup --type luks2 luksFormat /dev/nvme0n1p3
cryptsetup open --type luks2 /dev/nvme0n1p3 archie
mkfs.btrfs --label archie /dev/mapper/archie
mount -o noatime,compress=lzo:3,ssd,space_cache=v2 /dev/mapper/archie /mnt
# With LVM
((((((((((((((
pvcreate --dataalignment 1m /dev/mapper/archie
vgcreate volgroup0 /dev/mapper/archie
lvcreate -L 40GB volgroup0 archie_root
lvcreate -L 300GB volgroup0 archie_home
modprobe dm_mod
vgscan
vgchange -ay
mount /dev/volgroup/archie_root /mnt
mkdir -p /mnt/home
mkfs.btrfs /dev/volgroup0/archie_home
mount /dev/volgroup0/archie_home /mnt/home
))))))))))))))
# BTRFS: Create and mount subvolumes
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
umount /mnt
mkdir -p /mnt/{boot,.snapshots,var_log}
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@ /dev/mapper/archie /mnt 
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home /dev/mapper/archie /mnt/home
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@snapshots /dev/mapper/archie /mnt/.snapshots
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_log /dev/mapper/archie /mnt/var_log 
mount /dev/nvme0n1p2 /mnt/boot
lsblk

# Install the base system 
pacstrap /mnt base git bash-completion linux linux-lts linux-headers linux-lts-headers linux-firmware nvim amd-ucode

# Generate filesystem table
genfstab -U -p /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
cp /mnt/etc/fstab fstab.bak

# Entering installation directory
arch-chroot /mnt
# Setting timezone, clock and language
timedatectl list-timezones | grep City
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
nvim /etc/locale.gen 
locale-gen
echo LANG=en_US.UTF8 >> /etc/locale.conf 
echo LANGUAGE=en_US >> /etc/locale.conf
echo KEYMAP=de-latin1 >> /etc/vconsole.conf
# Setting hostname and hosts
echo tim-archie >> /etc/hostname
echo 127.0.0.1 localhost >> /etc/hosts
echo ::1 localhost >> /etc/hosts
echo 127.0.0.1 tim-archie.localdomain tim-archie >> /etc/hosts
# Setting root password
passwd
# Installing boot packages
git clone https://github.com/rescay/Archie-Tim
cd Archie-Tim/Paclists
pacman -Syy
pacman -Syu 
pacman -S --needed - < pacman-boot.txt
# Regenerating boot image file
nvim /etc/mkinitcpio.conf MODULES=(btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck"
sudo mkinitcpio -p linux linux-lts
# Nvidia pacman hook
mkdir /etc/pacman.d/hooks
nvim /etc/pacman.d/hooks/nvidia.hook  
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux
Target=linux-lts

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
# create UEFI folder and mount UEFI partition 
mkdir /boot/EFI
mount /dev/nvme0n1p1 /boot/EFI
# Install grub in MBR and configurate grub and generate grub configuration file
grub-install --target=x86_64-efi -bootloader-id=grub_uefi --recheck
cp /usr/share/locale/en\@quot/LC_MESSAGE/grub.mo /boot/grub/locale/en.mo
nvim /etc/default/grub uncomment GRUB_ENABLE_CRYPTODISK=y 
GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=/dev/nvme01np3:archie:allow-discards root=/dev/mapper/archie rootflags=subvol=@ loglevel=3 quiet nvidia_drm.modeset=1"
grub-mkconfig -o /boot/grub/grub.cfg
# Enable various services
systemctl enable NetworkManager
systemctl enable Bluetooth
systemctl enable Cups
systemctl enable sshd
systemctl enable systemd-timesyncd
# Create user and add sudo privileges
useradd -aG wheel tim
passwd tim
EDITOR=nvim visudo  wheel group all
exit 
umount -a
Reboot
sudo pacman -S --needed - < pacman-pkgs.txt ; wayland.txt ; kde.txt ; X11.txt 
systemctl enable sddm
git clone https://aur.archlinux.org/paru.git
cd paru 
makepkg -si
paru -S --needed - < aur.txt

