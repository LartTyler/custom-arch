#!/usr/bin/env sh

usage() {
    echo "$0 [OPTIONS] <BLOCK_DEVICE> <USERNAME>"
    echo
    echo "Arguments:"
    echo "    BLOCK_DEVICE     - The block device to partition for the Archlinux installation"
    echo "                       NOTE: This will ERASE ALL DATA stored on the specified device"'!'
    echo "    USERNAME         - The username of the primary user account to add to the system"
    echo "                       You will be prompted for a password during installation. The"
    echo "                       user will automatically be added to the 'wheel' group."
    echo
    echo "Options:"
    echo "--after <action>"
    echo "    What action to take after the initial installation is complete. Allowed values are"
    echo "    'restart', 'shutdown', or 'none' (default: 'none')."
    echo "--hostname <name>"
    echo "    Sets the hostname during install. If not provided, you will have to do this yourself."
    echo "--set-root-password"
    echo "    Prompt for a root password, instead of generating a random one."
    echo "-y, --minimal-interaction"
    echo "    Aside from the initial setup prompts, do not ask before doing anything."
}

block_device=""
cleanup_mounts() {
    if [ -n "$block_device" ]; then
        if [ -f /mnt/bootstrap.sh ]; then
            rm -f /mnt/bootstrap.sh
        fi

        umount /mnt
        swapoff ${block_device}2
    fi
}

password_input=""
password_prompt() {
    echo -n "${password_prompt__text:-Enter password}: "
    read -s password_input
    echo

    echo -n "${password_prompt__confirm_text:-Confirm password}: "
    read -s password_input_confirmation
    echo

    if [ "$password_input" != "$password_input_confirmation" ]; then
        echo "Passwords did not match"

        exit 1
    fi

    echo
}