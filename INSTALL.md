# Set keymap and font size for installation
```sh
loadkeys de-latin1-nodeadkeys ; </br> 
setfont ter-132n </br> 
```
# Establish a wifi connection and check connection
```sh
ip a </br>
```
```sh
iwctl station wlan device scan </br>
```
```sh
iwctl station wlan device get-networks </br>
```
```sh
iwctl --passphrase "" station wlan device connect SSID </br>
```
```sh
ping archlinux.org </br>
```
# Create partitions
```sh
fdisk -l </br>
```
```sh
fdisk /dev/device </br>
```
g for new GPT partition table </br>
n for new partition </br>
t for partition type </br>
1 for EFI Partition </br>
44 for LVM Partition </br>

# Create filesystems
```sh
mkfs.fat EFI -F32 /dev/nvme0n1p1 </br>
```
```sh
mkfs.btrfs --label Boot /dev/nvme0n1p2 </br> 
```
# Encrypt drive and create filesystem and mount
```sh
cryptsetup --type luks2 luksFormat /dev/nvme0n1p3 </br>
```
```sh
cryptsetup open --type luks2 /dev/nvme0n1p3 archie </br>
```
```sh
mkfs.btrfs --label archie /dev/mapper/archie </br>
```
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2 /dev/mapper/archie /mnt </br>
```sh

# Setup with LVM (skip if want to use timeshift or snapper)

pvcreate --dataalignment 1m /dev/mapper/archie </br>
vgcreate volgroup0 /dev/mapper/archie </br>
lvcreate -L 40GB volgroup0 archie_root </br>
lvcreate -L 300GB volgroup0 archie_home </br>
modprobe dm_mod </br>
vgscan </br>
vgchange -ay </br>
mount /dev/volgroup/archie_root /mnt </br>
mkdir -p /mnt/home </br>
mkfs.btrfs /dev/volgroup0/archie_home </br>
mount /dev/volgroup0/archie_home /mnt/home </br>

# BTRFS: Create and mount subvolumes

btrfs su cr /mnt/@ </br>
btrfs su cr /mnt/@home </br>
btrfs su cr /mnt/@home_snapshots </br>
btrfs su cr /mnt/@snapshots </br>
btrfs su cr /mnt/@var_log </br>
btrfs su cr /mnt/@var_cache </br>
btrfs su cr /mnt/@pkg </br>

umount /mnt </br>

mkdir -p /mnt/{boot/EFI,home/.snapshots,.snapshots,var/{log,cache/pacman/pkg}} </br>

mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@ /dev/mapper/archie /mnt </br>
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home /dev/mapper/archie /mnt/home </br>
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home_snapshots /dev/mapper/archie /mnt/home/.snapshots </br>
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@snapshots /dev/mapper/archie /mnt/.snapshots </br>
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_log /dev/mapper/archie /mnt/var/log </br>
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_cache /dev/mapper/archie /mnt/var/cache </br>
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@pkg /dev/mapper/archie /mnt/var/cache/pacman/pkg </br>

mount /dev/nvme0n1p2 /mnt/boot </br>
mount /dev/nvme0n1p1 /mnt/boot/EFI </br>

# Install the base system

pacstrap -K /mnt base base-devel reflector rsync git bash-completion linux linux-lts linux-headers linux-lts-headers linux-firmware neovim amd-ucode</br>

# Generate filesystem table

genfstab -U -p /mnt >> /mnt/etc/fstab </br>
cat /mnt/etc/fstab </br>
cp /mnt/etc/fstab /mnt/etc/fstab.bak </br>

# Entering installation directory

arch-chroot /mnt </br>

# Setting timezone, clock and language

timedatectl list-timezones | grep City </br> 
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime </br>
hwclock --systohc </br>
nvim /etc/locale.gen </br>
locale-gen </br>
echo LANG=en_US.UTF8 >> /etc/locale.conf </br>
echo LANGUAGE=en_US >> /etc/locale.conf </br>
echo KEYMAP=de-latin1 >> /etc/vconsole.conf </br>

# Setting hostname and hosts

echo tim-archie >> /etc/hostname </br>
echo 127.0.0.1 localhost >> /etc/hosts </br>
echo ::1 localhost >> /etc/hosts </br>vv
echo 127.0.0.1 tim-archie.localdomain tim-archie >> /etc/hosts </br>

# Setting root password

passwd </br>

# Installing boot packages and setting up reflector

reflector -c Germany --latest 5 --sort rate --save /etc/pacman.d/mirrorlist </br>
git clone https://github.com/rescay/Archie-Tim </br>
cd Archie-Tim/Paclists </br>
pacman -Syu </br>
pacman -S --needed - < pacman-boot </br>

# Editing boot image file

nvim /etc/mkinitcpio.conf </br>

## For AMD

MODULES=(btrfs amdgpu) </br>
HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck" </br>

## For NVIDIA

MODULES=(btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm) </br>
HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck" </br>

## Regenerating boot image file

sudo mkinitcpio -p linux linux-lts </br>

# Install grub in MBR and configurate grub and generate grub configuration file

grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot/EFI --recheck </br>
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo </br>
nvim /etc/default/grub uncomment GRUB_ENABLE_CRYPTODISK=y </br>

## For AMD

GRUB_CMDLINE_DEFAULT="cryptdevice=/dev/nvme0n1p3:archie:allow-discards root=/dev/mapper/archie rootflags=subvol=@ loglevel= 3 quiet" </br>

## For NVIDIA
GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=/dev/nvme01np3:archie:allow-discards root=/dev/mapper/archie rootflags=subvol=@ loglevel=3 quiet nvidia_drm.modeset=1" </br>

grub-mkconfig -o /boot/grub/grub.cfg </br>


# Enable various services

systemctl enable NetworkManager </br>
sysemctl enable reflector.timer </br>
systemctl enable sshd </br>

# Create user and add sudo privileges

useradd -m -g users -G wheel tim </br>
passwd tim </br>
EDITOR=nvim visudo   uncomment wheel group all </br>

umount -a </br>
Reboot </br>

# Install packages

sudo pacman -S --needed - < pacman-pkgs ; wayland </br>
systemctl enable sddm </br>
git clone https://aur.archlinux.org/yay.git </br>
cd yay </br>
makepkg -si </br>
cd yay </br>
yay -S --needed - < aur </br>

# Configuring snapper snapshots

sudo -s </br>

## For root subvolume

unmount /.snapshots </br>
rm -r /.snapshots </br>
snapper -c root create-config / </br>
btrfs su del /.snapshots </br>
mkdir /.snapshots </br>
mount -a </br>
btrfs su get-default / </br>
btrfs subvol list / </br>
btrfs subvol set-def number / </br>
btrfs subvol get-default / </br>

### Setting privileges and create first snapshot

nvim /etc/snapper/configs/root </br>
chmod 750 /.snapshots </br>
chown -r :wheel /.snapshots </br>
snapper -c root create -d "***System Installed***" </br>

## For home subvolume

unmount /home/.snapshots </br>
rm -r /home/.snapshots </br>
snapper -c home create-config /@home </br>
btrfs su del /home/.snapshots </br>
mkdir /home/.snapshots </br>
mount -a </br>
btrfs subvol list /@home </br>

### Setting privileges and create first snapshot

nvim /etc/snapper/configs/home </br>
chmod 750 /home/.snapshots </br>
chown -r :wheel /home/.snapshots </br>
snapper -c home create -d "***System Installed***" </br>



### Disable updatedb to update from home snapshots and enable snap service

nvim /etc/updatedb.conf PRUNENAMES = ".snapshots" </br>
systemctl enable --now snapper-timeline.timer </br>
systemctl enable --now snapper-cleanup.timer </br>
