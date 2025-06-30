#!/bin/bash
set -e

# 🌙 Moon OS Minimal Arch Installer
# Installs base Arch with Moon OS flavor, US intl keyboard, Dutch mirrors, and yay

### === CONFIG === ###
DISK="/dev/sda"
HOSTNAME="moon-os"
TIMEZONE="Europe/Amsterdam"
LOCALE="en_US.UTF-8"
MIRROR_COUNTRY="Netherlands"
### =============== ###

# Welcome
echo -e "\n🌙 Welcome to the Moon OS Installer\n"

# Ask for username
read -rp "🌙 Enter your desired username: " USERNAME

# Keyboard layout

# Mirrors
echo "🌐 Setting fast mirrors from $MIRROR_COUNTRY..."
reflector --country "$MIRROR_COUNTRY" --latest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Disk setup
echo "💥 WIPING and partitioning $DISK..."
sgdisk -Z "$DISK"
sgdisk -n1:0:0 -t1:8300 "$DISK"
mkfs.ext4 "${DISK}1"
mount "${DISK}1" /mnt

# Base system
echo "📦 Installing base system..."
pacstrap /mnt base linux linux-firmware sudo vim git networkmanager

# Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot time!
arch-chroot /mnt /bin/bash <<EOF

# Time and locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Hostname and hosts
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Root password
echo "🌙 Set root password:"
passwd

# User setup
echo "🌙 Creating user: $USERNAME"
useradd -m -G wheel -s /bin/bash $USERNAME
echo "Set password for $USERNAME:"
passwd $USERNAME

# Enable sudo for wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Bootloader
bootctl install
PARTUUID=\$(blkid -s PARTUUID -o value ${DISK}1)

cat > /boot/loader/loader.conf <<LOADER
default arch
timeout 3
editor no
LOADER

cat > /boot/loader/entries/arch.conf <<ENTRY
title   Moon OS (Arch Linux)
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=\$PARTUUID rw
ENTRY

# Enable networking
systemctl enable NetworkManager

EOF

# Yay install (after chroot)
echo "✨ Installing yay for user $USERNAME..."
arch-chroot /mnt /bin/bash <<EOF
su - $USERNAME -c "
cd ~
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
"
EOF

echo -e "\n✅ Moon OS base system installed with yay! Reboot to enter your system.\n"

