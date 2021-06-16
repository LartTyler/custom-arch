#!/usr/bin/env zsh

source "$(dirname "$0")/functions.sh"

on_complete_action="none"
hostname=""
verbosity=0
minimal_interaction=0
prompt_root_password=0

positional_args=()

while [[ $# != 0 ]]; do
    key="$1"

    case "$key" in
        --after)
            on_complete_action="$2"
            shift

            case "$on_complete_action" in
                restart|shutdown|none)
                    ;;

                *)
                    usage
                    echo -e "\nUnrecognized option for --after: $on_complete_action"

                    exit 1

                    ;;

            esac

            ;;

        --help)
            usage

            exit 0

            ;;

        --set-root-password)
            prompt_root_password=1

            ;;

        -y|--minimal-interaction)
            minimal_interaction=1

            ;;


        -v|--verbose)
            verbosity=$((verbosity + 1))

            ;;

        -*|--*)
            echo "Unrecognized option: ${key}"

            usage

            exit 1

            ;;

        *)
            positional_args+=("$key")

            ;;
    esac

    shift
done

set -- "${positional_args[@]}"

if [[ $# != 2 ]]; then
    usage

    exit 1
fi

command_output_redir="/dev/null"
if [ $verbosity -gt 0 ]; then
    command_output_redir="&1"
fi

block_device="$1"
username="$2"

password_prompt__text="Password for ${username}" password_prompt
user_password="$password_input"

root_password=""

if [ $prompt_root_password -gt 0 ]; then
    password_prompt__text="Password for root" password_prompt
    root_password="$password_input"
else
    echo -e "Root's password will be safely randomized\n"

    root_password=$(openssl rand -base64 24)
fi

timedatectl set-ntp true

swap_size=$(free --mebi | awk '/Mem:/ { print $2 + int($2 + 0.99) }')

echo -n "Partioning ${block_device} ... "

echo "label: gpt
device: ${block_device}
unit: sectors

${block_device}1 : size=1MiB, type=21686148-6449-6E6F-744E-656564454649, name=bios
${block_device}2 : size=${swap_size}MiB, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, name=swap
${block_device}3 : type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709, name=root
" | sfdisk -q -W always --force ${block_device}

device_swap="${block_device}2"
device_root="${block_device}3"

echo "done"

if [ $verbosity -gt 0 ]; then
    fdisk ${block_device} -l -o Device,Size,Type,Name | grep -E "^(Device|/dev)"
fi

echo -n "Formatting partitions ... "

mkswap $device_swap
swapon $device_swap

mkfs.ext4 $device_root

echo "done"

echo -n "Configuring base install ... "

trap cleanup_mounts EXIT SIGINT SIGTERM

mount $device_root /mnt
pacstrap /mnt base linux linux-firmware neovim man-pages man-db texinfo sudo grub

genfstab -L /mnt > /mnt/etc/fstab

echo "done"

echo -n "Bootstrapping install configs ... "

cp "$(dirname "$0")/bootstrap.sh" /mnt/bootstrap.sh
arch-chroot /mnt /bootstrap.sh "$root_password" "$username" "$user_password"

echo "done"

echo -n "Cleaning up ... "

trap - EXIT SIGINT SIGTERM
rm -f /mnt/bootstrap.sh

echo "done"

if [ $minimal_interaction -eq 0 ] && [ "$on_complete_action" != "none" ]; then
    echo -n "Installation complete. Press any key to $on_complete_action ... "
    read
fi

case $on_complete_action in
    restart)
        shutdown -r now

        ;;

    shutdown)
        shutdown -h now

        ;;
esac