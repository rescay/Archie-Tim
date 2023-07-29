# Establish a wifi connection and check ethernet connection
ip a
iwctl
station wlan device connect ""
enter passphrase
directly: iwctl --passphrase "" station wlan device connect SSID
ping archlinux.org

loadkeys de-latin1
setfont ter-132n


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
mkfs.fat EFI -F32 /dev/nvme0n1p1
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
btrfs su cr /mnt/@var_cache
umount /mnt
mkdir -p /mnt/{boot/EFI,.snapshots,var/{cache.log}}
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@ /dev/mapper/archie /mnt 
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home /dev/mapper/archie /mnt/home
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@snapshots /dev/mapper/archie /mnt/.snapshots
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_log /dev/mapper/archie /mnt/var/log 
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_cache /dev/mapper/archie /mnt/var/cache

mount /dev/nvme0n1p2 /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot/EFI
lsblk

# Install the base system 
pacstrap -K /mnt base base-devel reflector rsync git bash-completion linux linux-lts linux-headers linux-lts-headers linux-firmware neovim amd-ucode

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
# Installing boot packages and setting up reflector
reflector -c Germany --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
git clone https://github.com/rescay/Archie-Tim
cd Archie-Tim/Paclists
pacman -Syy
pacman -Syu 
pacman -S --needed - < pacman-boot.txt
# Regenerating boot image file
nvim /etc/mkinitcpio.conf MODULES=(btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck"
sudo mkinitcpio -p linux linux-lts
# Install grub in MBR and configurate grub and generate grub configuration file
grub-install --target=x86_64-efi -bootloader-id=grub_uefi --recheck
cp /usr/share/locale/en\@quot/LC_MESSAGE/grub.mo /boot/grub/locale/en.mo
nvim /etc/default/grub uncomment GRUB_ENABLE_CRYPTODISK=y 
GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=/dev/nvme01np3:archie:allow-discards root=/dev/mapper/archie rootflags=subvol=@ loglevel=3 quiet nvidia_drm.modeset=1"
grub-mkconfig -o /boot/grub/grub.cfg
# Enable various services
systemctl enable NetworkManager
sysemctl enable reflector.timer
systemctl enable sshd
systemctl enable systemd-timesyncd
# Create user and add sudo privileges
useradd -m -g users -G wheel tim
passwd tim
EDITOR=nvim visudo  wheel group all
exit 
umount -a
Reboot
sudo pacman -S --needed - < pacman-pkgs.txt ; wayland.txt  
systemctl enable sddm
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd
yay
rm -rf yay
yay -S --needed - < aur.txt
# Configuring snapper snapshots
sudo -s
umount /.snapshots
rm -r /.snapshots
snapper -c root create-config /
snapper -c home create-config /@home 
btrfs su del /.snapshots
mkdir /.snapshots
mount -a
btrfs su get-default /
btrfs subvol list /
btrfs subvol list /@home
btrfs subvol set-def number /
btrfs subvol get-default /
nvim /etc/snapper/configs/root
nvim /etc/snapper/configs/home
chmod 750 /.snapshots
chown -r :wheel /.snapshots
chmod 750 /home/.snapshots
chown -r :wheel /home/.snapshots
(snapper -c root create -d "***System Installed***"
systemctl status grub-btrfs.cfg
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer
nvim /etc/updatedb.conf PRUNENAMES = ".snapshots"
