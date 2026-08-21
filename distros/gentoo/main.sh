#!/bin/bash

# Gentoo distribution

distro_install_dependencies() {
  msg2 "Installing dependencies for $_distro"
  # Gentoo dependencies are assumed to be handled by the user or base deps
}

distro_build_pkg() {
  _build_kernel_generic
}

distro_install_pkg() {
  _install_kernel_source_generic "linux-$_kernel_flavor" "true"

  msg2 "Selecting the kernel source code as default source folder"
  sudo ln -sfn "/usr/src/linux-$_kernel_flavor" "/usr/src/linux"

  msg2 "Rebuild kernel modules with \"emerge @module-rebuild\" ?"
  if [ "$_compiler" = "llvm" ];then
    warning "Building modules with LLVM/Clang is mostly unsupported OOTB by \"emerge @module-rebuild\" except for Nvidia 465.31+"
    warning "     Manually setting \"CC=clang\" for some modules may work if you haven't used LTO"
  fi

  read -r -p "Y/[n]: " _continue
  if [[ "$_continue" =~ ^(Y|y|Yes|yes)$ ]];then
    sudo emerge @module-rebuild --keep-going
  fi
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

distro_srcprep_pre() {
  # https://dev.gentoo.org/~mpagano/genpatches/trunk/
  tkgpatch="$srcdir/0013-gentoo-kconfig.patch"
  _msg="Import Gentoo-kconfig patches" && _tkg_patcher
  tkgpatch="$srcdir/0013-gentoo-print-loaded-firmware.patch"
  _msg="Print firmware names on load" && _tkg_patcher
}

distro_srcprep_post() {
  # Default config for Gentoo as defined in kconfig
  _enable "GENTOO_LINUX" "GENTOO_LINUX_UDEV" "GENTOO_LINUX_PORTAGE" "GENTOO_LINUX_INIT_SCRIPT" "GENTOO_PRINT_FIRMWARE_INFO" "GENTOO_LINUX_INIT_SYSTEMD"
  _disable "GENTOO_KERNEL_SELF_PROTECTION"
}
