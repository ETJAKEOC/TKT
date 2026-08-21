#!/bin/bash

# Generic installation method

distro_install_dependencies() {
  msg2 "Generic install selected. Ensure all dependencies are manually installed."
}

distro_build_pkg() {
  _build_kernel_generic
}

distro_install_pkg() {
  _install_kernel_source_generic "linux-$_kernel_flavor" "false"
}

distro_uninstall_help() {
  msg2 "Folders in /lib/modules :"
  ls /lib/modules
  msg2 "Files in /boot :"
  ls /boot
  msg2 "To uninstall a kernel version installed through install.sh with 'Generic' as a distro:"
  msg2 "  - Remove manually the corresponding folder in '/lib/modules'"
  msg2 "  - Remove manually the corresponding 'System.map', 'vmlinuz', 'config' and 'initramfs' in the folder :/boot"
  msg2 "  - Update the boot menu. e.g. 'sudo grub-mkconfig -o /boot/grub/grub.cfg'"
}
