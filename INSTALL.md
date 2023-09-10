## Set keymap and font size for installation
```sh
loadkeys de-latin1-nodeadkeys ; 
setfont ter-132n  
```

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
iwctl station wlan device connect SSID --passphrase "" 
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

## Create filesystems

```sh
mkfs.fat EFI -F32 /dev/nvme0n1p1
```
```sh
mkfs.btrfs --label Boot /dev/nvme0n1p2  
```

## Encrypt drive and create filesystem and mount

```sh
cryptsetup --type luks2 luksFormat /dev/nvme0n1p3 
```
```sh
cryptsetup open --type luks2 /dev/nvme0n1p3 archie 
```
```sh
mkfs.btrfs --label archie /dev/mapper/archie 
```
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2 /dev/mapper/archie /mnt 

```

## Setup with LVM (skip if want to use timeshift or snapper)
```sh
pvcreate --dataalignment 1m /dev/mapper/archie
```
```sh
vgcreate volgroup0 /dev/mapper/archie 
```
```sh
lvcreate -L 40GB volgroup0 archie_root 
```
```sh
lvcreate -L 300GB volgroup0 archie_home 
```
```sh
modprobe dm_mod 
```
```sh
vgscan 
```
```sh
vgchange -ay 
```
```sh
mount /dev/volgroup/archie_root /mnt
```
```sh
mkdir /mnt/home
```
```sh
mkfs.btrfs /dev/volgroup0/archie_home
```
```sh
mount /dev/volgroup0/archie_home /mnt/home
```


## BTRFS: Create and mount subvolumes

```sh
btrfs su cr /mnt/@ &&
btrfs su cr /mnt/@home &&
btrfs su cr /mnt/@home_snapshots &&
btrfs su cr /mnt/@snapshots &&
btrfs su cr /mnt/@var_log &&
btrfs su cr /mnt/@var_cache &&
btrfs su cr /mnt/@pkg && 
umount /mnt
```
```sh
mkdir -p /mnt/{boot/EFI,home/.snapshots,.snapshots,var/{log,cache/pacman/pkg}} 
```
```sh
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@ /dev/mapper/archie /mnt &&
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home /dev/mapper/archie /mnt/home &&
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@home_snapshots /dev/mapper/archie /mnt/home/.snapshots &&
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@snapshots /dev/mapper/archie /mnt/.snapshots &&
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_log /dev/mapper/archie /mnt/var/log && 
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@var_cache /dev/mapper/archie /mnt/var/cache &&
mount -o noatime,compress=lzo:3,ssd,space_cache=v2,subvol=@pkg /dev/mapper/archie /mnt/var/cache/pacman/pkg
```
```sh
mount /dev/nvme0n1p2 /mnt/boot && 
mount /dev/nvme0n1p1 /mnt/boot/EFI 
```

## Install the base system

```sh
pacstrap -K /mnt base base-devel reflector rsync git bash-completion linux linux-lts linux-headers linux-lts-headers linux-firmware neovim amd-ucode
```
</br>

## Generate filesystem table

```sh
genfstab -U -p /mnt >> /mnt/etc/fstab &&
cat /mnt/etc/fstab &&
cp /mnt/etc/fstab /mnt/etc/fstab.bak 
```
</br>

## Entering installation directory

```sh
arch-chroot /mnt </br>
```

## Setting timezone, clock and language

```sh
timedatectl list-timezones | grep City 
```
```sh
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime 
```
```sh
hwclock --systohc
```
```sh
sed -e '/#de_DE.UTF-8/c\de_DE.UTF-8 UTF-8' -e '/#en_US.UTF-8/c\en_US.UTF-8 UTF-8' -i /etc/locale.gen && locale-gen  
```
```sh
echo LANG=en_US.UTF8 >> /etc/locale.conf &&
echo LANGUAGE=en_US >> /etc/locale.conf &&
echo KEYMAP=de-latin1-nodeadkeys >> /etc/vconsole.conf 
```
## Setting hostname and hosts

```sh
echo tim-archie >> /etc/hostname &&
echo 127.0.0.1 localhost >> /etc/hosts &&
echo ::1 localhost >> /etc/hosts &&
echo 127.0.0.1 tim-archie.localdomain tim-archie >> /etc/hosts 
```
## Setting root password

```sh
passwd
```

## Create user and add sudo privileges

```sh                                                                                                    
useradd -m -g users -G wheel tim &&                                                                   
passwd tim &&
sed '/# %wheel/c\%wheel ALL=(ALL:ALL) ALL' -i /etc/sudoers
```

## Installing boot packages and setting up reflector

```sh
reflector -c Germany --latest 5 --sort rate --save /etc/pacman.d/mirrorlist &&
cd /home/tim/Downloads &&
git clone https://github.com/rescay/Archie-Tim &&
cd Archie-Tim/Paclists &&
pacman -Syu &&
pacman -S --needed - < pacman-boot 
```

## Editing boot image file and regenerating boot image file

```sh
### For AMD
sed -e '/MODULES=()/c\MODULES=(btrfs amdgpu)' -e '/HOOKS=(base udev autodetect modconf/c\HOOKS=(base udev autodetect modconfblock encrypt lvm2 filesystems keyboard fsck)' -i /etc/mkinitcpio.conf &&
mkinitcpio -P
### For NVIDIA
sed -e '/MODULES=()/c\MODULES=(btrfs nouveau)' -e '/HOOKS=(base udev autodetect modconf/c\HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)' -i /etc/mkinitcpio.conf &&
mkinitcpio -P 
```

## Install grub in MBR and configurate and generate grub config file 

```sh
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot/EFI --recheck &&
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo &&
sed -e '/#GRUB_ENABLE_CRYPTODISK/c\GRUB_ENABLE_CRYPTODISK=y' -e '/GRUB_DEFAULT/c\GRUB_DEFAULT="Advanced options for Arch Linux>Arch Linux, with Linux linux"' -e '/GRUB_TIMEOUT/c\GRUB_TIMEOUT=1' -e '/GRUB_CMDLINE_DEFAULT/c\GRUB_CMDLINE_DEFAULT="cryptdevice=/dev/nvme0n1p3:archie:allow-discards root=/dev/mapper/archie rootflags=subvol=@ loglevel=3 quiet"' -i /etc/default/grub && # For custom edid file add drm.edid_firmware=eDP-1:edid/edid.bin
grub-mkconfig -o /boot/grub/grub.cfg
```

## Enable various services

```sh
systemctl enable NetworkManager &&
sysemctl enable reflector.timer &&
systemctl enable sshd 
```

#### Unmount and reboot

```sh
umount -a &&
reboot
```

## Install packages

```sh
cd /home/tim/Downloads/Archie-Tim/Paclists
sudo pacman -S --needed - < pacman-pkgs ; wayland &&
cd ../.. &&
git clone https://aur.archlinux.org/yay.git &&
cd yay &&
makepkg -si &&
yay -S --needed - < aur
```

## Configuring snapper snapshots

```sh
sudo -s 
```

## For root subvolume

```sh
unmount /.snapshots &&
rm -r /.snapshots &&
snapper -c root create-config / && 
btrfs su del /.snapshots &&
mkdir /.snapshots &&
mount -a 

### Set root as default subvolume

btrfs su get-default / &&
btrfs subvol list / 

btrfs subvol set-def number / &&
btrfs subvol get-default / 
```

### Setting privileges and create first snapshot

```sh
nvim /etc/snapper/configs/root 
```

```sh
chmod 750 /.snapshots &&
chown -R :wheel /.snapshots &&
snapper -c root create -d "***System Installed***" 
```

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

### Setting privileges and create first snapshot

```sh
nvim /etc/snapper/configs/home 
```

```sh
chmod 750 /home/.snapshots &&
chown -R :wheel /home/.snapshots &&
snapper -c home create -d "***System Installed***" 
```

### Disable updatedb to update from snapshots 

```sh
sudo sed '/PRUNENAMES=/c\PRUNENAMES = ".git .hg .svn .snapshots"' -i /etc/updatedb.conf
```

### Enable snapper timers

```sh
systemctl enable --now snapper-timeline.timer &&
systemctl enable --now snapper-cleanup.timer
```
