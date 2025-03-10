#!/bin/bash

echo "#####################################################"
echo "ETJAKEOC TKT kernel initramfs and GRUB2 update script"
echo "#####################################################"
echo "#####################################################"
echo "This script should be adaptable to any distribution."
echo "It will attempt to generate a new 'initrd' image for your system"
echo "and update your GRUB2 bootloader menu for you."
echo "Please press enter to continue."
read -r dummy_variable

# Find the TKT kernel package
tkt_k=$(find /lib/modules -name 'kernel*tkt*')

if [ -z "$tkt_k" ]; then
    echo "Error: TKT kernel package not found."
    exit 1
fi

# Extract the kernel version from the package filename
tkt_version=$(basename "$tkt_k" | sed 's/kernel-\([0-9.]*\).*/\1/')

if [ -z "$tkt_version" ]; then
    echo "Error: Unable to extract TKT kernel version."
    exit 1
fi

# Probe for the name of the GRUB configuration command
if command -v grub-mkconfig >/dev/null 2>&1; then
    grub_config_command="grub-mkconfig"
elif command -v grub2-mkconfig >/dev/null 2>&1; then
    grub_config_command="grub2-mkconfig"
else
    echo "Error: Unable to find grub-mkconfig or grub2-mkconfig command."
    exit 1
fi

# Probe if dracut is available
if command -v dracut >/dev/null 2>&1; then
    use_dracut=true
else
    use_dracut=false
fi

# Probe if mkinitcpio is available
if command -v mkinitcpio >/dev/null 2>&1; then
    use_mkinitcpio=true
else
    use_mkinitcpio=false
fi

# Probe if update-initramfs is available
if command -v update-initramfs >/dev/null 2>&1; then
    use_update_initramfs=true
else
    use_update_initramfs=false
fi

# Generate initramfs using dracut if available, mkinitcpio if available, otherwise use update-initramfs
if [ "$use_dracut" = true ]; then
    echo "Running 'dracut' to generate the 'initramfs' file..."
    sudo dracut --kver "$tkt_version"
elif [ "$use_mkinitcpio" = true ]; then
    echo "Running 'mkinitcpio' to generate the 'initramfs' file..."
    sudo mkinitcpio -k "$tkt_version" -g "/boot/initramfs-${tkt_version}.img"
elif [ "$use_update_initramfs" = true ]; then
    echo "Running 'update-initramfs' to generate the 'initramfs' file..."
    sudo update-initramfs -c -k "$tkt_version"
else
    echo "Error: Unable to find dracut, mkinitcpio, or update-initramfs command."
    exit 1
fi

# Update GRUB configuration
echo "Updating the GRUB boot loader menu to add the new kernel..."
sudo "$grub_config_command" -o /boot/grub/grub.cfg

echo "Everything completed successfully. Please reboot, and enjoy your new kernel! :D"
