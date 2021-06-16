#!/usr/bin/env sh

usage() {
    echo "$0 <ROOT_PASSWORD> <PRIMARY_USER_NAME> <PRIMARY_USER_PASSWORD>"
    echo
    echo "Arguments:"
    echo "    ROOT_PASSWORD         - Password to assign to the root user"
    echo "    PRIMARY_USER_NAME     - The username of the primary user"
    echo "    PRIMARY_USER_PASSWORD - The password of the primary user"
}

if [ $# -ne 3 ]; then
    usage

    exit 1
fi

echo -n "Enter a hostname: "
read hostname

if [ -z "$hostname" ]; then
    hostname="archlinux"
fi

username="$2"

useradd -m -G wheel "$username"
echo -e "root:$1\n$username:$3" | chpasswd

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/allow_wheel

ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo -e "127.0.0.1\tlocalhost" > /etc/hosts
echo -e "::1\t\tlocalhost" >> /etc/hosts

if [ -n "$hostname" ]; then
    echo "$hostname" > /etc/hostname

    echo -e "127.0.1.1\t${hostname}.local ${hostname}" >> /etc/hosts
fi

sed -i 's/^#\{0,1\}GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
sed -i 's/^#\{0,1\}GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub

grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable systemd-networkd

echo "[Match]
Name=$(ip -br link show | grep -m1 -oP 'en\S+')

[Network]
DHCP=yes" > /etc/systemd/network/20-wired.network

systemctl restart systemd-networkd

systemctl enable systemd-resolved

ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
mkdir /etc/systemd/resolved.conf.d

echo "[Resolve]
DNS=1.1.1.1#1dot1dot1dot1.cloudflare-dns.com 1.0.0.1#1dot0dot0dot1.cloudflare-dns.com
DNSOverTLS=yes
Domains=~" > /etc/systemd/resolved.conf.d/dns_servers.conf

systemctl restart systemd-resolved

gpu_brand=$(lspci -v | grep -A1 -e VGA -e 3D | grep -oP "(?<=controller: )\w+" | tr '[:upper:]' '[:lower:]')
gpu_driver=""

case $gpu_brand in
    vmware)
        gpu_driver="xf86-video-vmware"

        ;;

    nvidia) # Untested
        gpu_driver="xf86-video-nouveau"

        ;;

    amd) # Untested
        gpu_driver="xf86-video-amdgpu"

        ;;

    intel) # Untested
        gpu_driver="xf86-video-intel"

        ;;

    *)
        echo "WARN: Could not determine an appropriate GPU driver"

        ;;
esac

pacman -S --noconfirm xorg lightdm lightdm-gtk-greeter bspwm sxhkd nitrogen picom alacritty firefox arandr $gpu_driver

install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc /home/${username}/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc /home/${username}/.config/bspwm/sxhkdrc

pacman -S exa fish

exit