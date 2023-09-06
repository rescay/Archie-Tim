# Set keymap and font size for installation
<details>
	loadkeys de-latin1-nodeadkeys                                                                            
	setfont ter-132n
</details>
# Establish a wifi connection and check connection

ip a
iwctl station wlan device scan
iwctl station wlan device get-networks
iwctl --passphrase "" station wlan device connect SSID
ping archlinux.org

# Create partitions

fdisk -l 
fdisk /dev/device
g for new GPT partition table
n for new partition 
t for partition type
1 for EFI Partition 
44 for LVM Partition

# Create filesystems

mkfs.fat EFI -F32 /dev/nvme0n1p1
mkfs.btrfs --label Boot /dev/nvme0n1p2 

# Encrypt drive and create filesystem and mount

cryptsetup --type luks2 luksFormat /dev/nvme0n1p3
cryptsetup open --type luks2 /dev/nvme0n1p3 archie
mkfs.btrfs --label archie /dev/mapper/archie
mount -o noatime,compress=lzo:3,ssd,space_cache=v2 /dev/mapper/archie /mnt

# Setup with LVM (skip if want to use timeshift or snapper)

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

# BTRFS: Create and mount subvolumes

btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@home_snapshots
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache
btrfs su cr /mnt/@pkg

umount /mnt

mkdir -p /mnt/{boot/EFI,home/.snapshots,.snapshots,var/{log,cache/pacman/pkg}}

mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@ /dev/mapper/archie /mnt 
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home /dev/mapper/archie /mnt/home
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home_snapshots /dev/mapper/archie /mnt/home/.snapshots
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@snapshots /dev/mapper/archie /mnt/.snapshots
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_log /dev/mapper/archie /mnt/var/log 
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_cache /dev/mapper/archie /mnt/var/cache
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@pkg /dev/mapper/archie /mnt/var/cache/pacman/pkg

mount /dev/nvme0n1p2 /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot/EFI

# Install the base system

pacstrap -K /mnt base base-devel reflector rsync git bash-completion linux linux-lts linux-headers linux-lts-headers linux-firmware neovim amd-ucode

# Generate filesystem table

genfstab -U -p /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
cp /mnt/etc/fstab /mnt/etc/fstab.bak

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
pacman -Syu 
pacman -S --needed - < pacman-boot.txt

# Editing boot image file

nvim /etc/mkinitcpio.conf

## For AMD

MODULES=(btrfs amdgpu)
HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck"

## For NVIDIA

MODULES=(btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck"

## Regenerating boot image file

sudo mkinitcpio -p linux linux-lts

# Install grub in MBR and configurate grub and generate grub configuration file

grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot/EFI --recheck
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
nvim /etc/default/grub uncomment GRUB_ENABLE_CRYPTODISK=y

## For AMD

GRUB_CMDLINE_DEFAULT="cryptdevice=/dev/nvme0n1p3:archie:allow-discards root=/dev/mapper/archie rootflags=subvol=@ loglevel= 3 quiet"

## For NVIDIA
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
EDITOR=nvim visudo   uncomment wheel group all

umount -a
Reboot

# Install packages

sudo pacman -S --needed - < pacman-pkgs ; wayland
systemctl enable sddm
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd yay 
yay -S --needed - < aur

# Configuring snapper snapshots

sudo -s

## For root subvolume

unmount /.snapshots
rm -r /.snapshots
snapper -c root create-config /
btrfs su del /.snapshots
mkdir /.snapshots
mount -a
btrfs su get-default /
btrfs subvol list /
btrfs subvol set-def number /
btrfs subvol get-default /

### Setting privileges and create first snapshot

nvim /etc/snapper/configs/root
chmod 750 /.snapshots
chown -r :wheel /.snapshots
snapper -c root create -d "***System Installed***"

## For home subvolume

unmount /home/.snapshots
rm -r /home/.snapshots
snapper -c home create-config /@home
btrfs su del /home/.snapshots 
mkdir /home/.snapshots
mount -a
btrfs subvol list /@home

### Setting privileges and create first snapshot

nvim /etc/snapper/configs/home
chmod 750 /home/.snapshots
chown -r :wheel /home/.snapshots
snapper -c home create -d "***System Installed***"



### Disable updatedb to update from home snapshots and enable snap service

nvim /etc/updatedb.conf PRUNENAMES = ".snapshots"
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer
