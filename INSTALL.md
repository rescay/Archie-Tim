## Set keymap and font size for installation
```sh
loadkeys de-latin1-nodeadkeys ; 
setfont ter-132n  
```
</br>

## Establish a wifi connection and check connection

```sh
ip a
```
```sh
iwctl station wlan device scan 
```
```sh
iwctl station wlan device get-networks 
```
```sh
iwctl --passphrase "" station wlan device connect SSID 
```
```sh
ping archlinux.org 
```

## Create partitions


```sh
fdisk -l 
```
```sh
fdisk /dev/device 
```
g for new GPT partition table </br>
n for new partition </br>
t for partition type </br>
1 for EFI Partition </br>
44 for LVM Partition </br>

# Create filesystems
```sh
mkfs.fat EFI -F32 /dev/nvme0n1p1
```
</br>
```sh
mkfs.btrfs --label Boot /dev/nvme0n1p2  
```
</br>
# Encrypt drive and create filesystem and mount
```sh
cryptsetup --type luks2 luksFormat /dev/nvme0n1p3 
```
</br>
```sh
cryptsetup open --type luks2 /dev/nvme0n1p3 archie 
```
</br>
```sh
mkfs.btrfs --label archie /dev/mapper/archie 
```
</br>
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2 /dev/mapper/archie /mnt 

```
</br>

# Setup with LVM (skip if want to use timeshift or snapper)
```sh
pvcreate --dataalignment 1m /dev/mapper/archie
```
</br>
```sh
vgcreate volgroup0 /dev/mapper/archie 
```
</br>
```sh
lvcreate -L 40GB volgroup0 archie_root 
```
</br>
```sh
lvcreate -L 300GB volgroup0 archie_home 
</br>
```
```sh
modprobe dm_mod 
```
</br>
```sh
vgscan 
```
</br>
```sh
vgchange -ay 
```
</br>
```sh
mount /dev/volgroup/archie_root /mnt
```
</br>
```sh
mkdir -p /mnt/home
```
</br>
```sh
mkfs.btrfs /dev/volgroup0/archie_home
```
</br>
```sh
mount /dev/volgroup0/archie_home /mnt/home
```
</br>

# BTRFS: Create and mount subvolumes
```sh
btrfs su cr /mnt/@ 
```
</br>
```sh
btrfs su cr /mnt/@home 
```
</br>
```sh
btrfs su cr /mnt/@home_snapshots
```
</br>
```sh
btrfs su cr /mnt/@snapshots 
```
</br>
```sh
btrfs su cr /mnt/@var_log
```
</br>
```sh
btrfs su cr /mnt/@var_cache 
```
</br>
```sh
btrfs su cr /mnt/@pkg 
```
</br>
```sh
umount /mnt
```
</br>
```sh
mkdir -p /mnt/{boot/EFI,home/.snapshots,.snapshots,var/{log,cache/pacman/pkg}} 
```
</br>
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@ /dev/mapper/archie /mnt
```
</br>
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home /dev/mapper/archie /mnt/home
```
</br>
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home_snapshots /dev/mapper/archie /mnt/home/.snapshots 
```
</br>
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@snapshots /dev/mapper/archie /mnt/.snapshots 
```
</br>
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_log /dev/mapper/archie /mnt/var/log 
```
</br>
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_cache /dev/mapper/archie /mnt/var/cache
```
</br>
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@pkg /dev/mapper/archie /mnt/var/cache/pacman/pkg
```
</br>
```sh
mount /dev/nvme0n1p2 /mnt/boot && 
mount /dev/nvme0n1p1 /mnt/boot/EFI 
```
</br>

# Install the base system
```sh
pacstrap -K /mnt base base-devel reflector rsync git bash-completion linux linux-lts linux-headers linux-lts-headers linux-firmware neovim amd-ucode
```
</br>

# Generate filesystem table
```sh
genfstab -U -p /mnt >> /mnt/etc/fstab &&
cat /mnt/etc/fstab &&
cp /mnt/etc/fstab /mnt/etc/fstab.bak 
```
</br>
# Entering installation directory
```sh
arch-chroot /mnt </br>
```
</br>
# Setting timezone, clock and language
```sh
timedatectl list-timezones | grep City 
```
</br> 
```sh
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime 
```
</br>
```sh
hwclock --systohc
```
</br>
```sh
nvim /etc/locale.gen 
```
</br>
```sh
locale-gen &&
echo LANG=en_US.UTF8 >> /etc/locale.conf &&
echo LANGUAGE=en_US >> /etc/locale.conf &&
echo KEYMAP=de-latin1 >> /etc/vconsole.conf 
```
</br>
# Setting hostname and hosts
```sh
echo tim-archie >> /etc/hostname &&
echo 127.0.0.1 localhost >> /etc/hosts &&
echo ::1 localhost >> /etc/hosts &&
echo 127.0.0.1 tim-archie.localdomain tim-archie >> /etc/hosts 
```
</br>
# Setting root password
```sh
passwd
```
</br>

# Create user and add sudo privileges                                                                    
```sh                                                                                                    
useradd -m -g users -G wheel tim &&                                                                   
passwd tim &&                                                                                       
EDITOR=nvim visudo # Add sudo privileges to wheel group 
```
</br>

# Installing boot packages and setting up reflector
```sh
reflector -c Germany --latest 5 --sort rate --save /etc/pacman.d/mirrorlist &&
cd /home/tim/Downloads &&
git clone https://github.com/rescay/Archie-Tim &&
cd Archie-Tim/Paclists &&
pacman -Syu &&
pacman -S --needed - < pacman-boot 
```
</br>
# Editing boot image file

```sh
nvim /etc/mkinitcpio.conf
```
</br>

## For AMD

MODULES=(btrfs amdgpu) </br>
HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck" </br>

## For NVIDIA

MODULES=(btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm) </br>
HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck" </br>

## Regenerating boot image file
```sh
sudo mkinitcpio -p linux linux-lts 
```
</br>

<<<<<<< HEAD
# Install grub in MBR and configurate grub and generate grub configuration file
=======
# Install grub in MBR and configurate grub 
>>>>>>> 72c6135 (Put commands together)
```sh
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot/EFI --recheck &&
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo &&
nvim /etc/default/grub # uncomment GRUB_ENABLE_CRYPTODISK=y 
```
</br>

## For AMD

GRUB_CMDLINE_DEFAULT="cryptdevice=/dev/nvme0n1p3:archie:allow-discards root=/dev/mapper/archie rootflags=subvol=@ loglevel= 3 quiet" </br>

## For NVIDIA

GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=/dev/nvme01np3:archie:allow-discards root=/dev/mapper/archie rootflags=subvol=@ loglevel=3 quiet nvidia_drm.modeset=1" </br>

<<<<<<< HEAD
=======
## Generate grub config file
>>>>>>> 72c6135 (Put commands together)
```sh
grub-mkconfig -o /boot/grub/grub.cfg 
```
</br>


# Enable various services
```sh
systemctl enable NetworkManager &&
sysemctl enable reflector.timer &&
systemctl enable sshd 
```
</br>
<<<<<<< HEAD
=======
#### Unmount and reboot
>>>>>>> 72c6135 (Put commands together)
```sh
umount -a &&
reboot
```
</br>
# Install packages
```sh
cd /home/tim/Downloads/Archie-Tim/Paclists
sudo pacman -S --needed - < pacman-pkgs ; wayland &&
cd ../.. &&
git clone https://aur.archlinux.org/yay.git &&
cd yay &&
makepkg -si &&
yay -S --needed - < aur
```
</br>

# Configuring snapper snapshots
```sh
sudo -s 
```
</br>

## For root subvolume
```sh
unmount /.snapshots &&
rm -r /.snapshots &&
snapper -c root create-config / && 
btrfs su del /.snapshots &&
mkdir /.snapshots &&
mount -a &&
btrfs su get-default / &&
btrfs subvol list / && 
btrfs subvol set-def number / &&
btrfs subvol get-default / 
```
</br>

### Setting privileges and create first snapshot
```sh
nvim /etc/snapper/configs/root # Editing config
```
</br>
```sh
chmod 750 /.snapshots &&
chown -r :wheel /.snapshots &&
snapper -c root create -d "***System Installed***" 
```
</br>

## For home subvolume
```sh
unmount /home/.snapshots &&
rm -r /home/.snapshots &&
snapper -c home create-config /@home && 
btrfs su del /home/.snapshots &&
mkdir /home/.snapshots &&
mount -a &&
btrfs subvol list /@home 
```
</br>

### Setting privileges and create first snapshot
```sh
nvim /etc/snapper/configs/home # Editing config
```
</br>
```sh
chmod 750 /home/.snapshots &&
chown -r :wheel /home/.snapshots &&
snapper -c home create -d "***System Installed***" 
```
</br>

### Disable updatedb to update from snapshots and enable snapper timers
```sh
nvim /etc/updatedb.conf  #PRUNENAMES = ".snapshots"  Editing plocates updatedb config
```
</br>
```sh
systemctl enable --now snapper-timeline.timer &&
systemctl enable --now snapper-cleanup.timer
```
</br>
