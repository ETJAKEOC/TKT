#!/bin/bash

# Generic installation method

distro_install_dependencies() {
  msg2 "Generic install selected. Ensure all dependencies are manually installed."
}

distro_build_pkg() {
  _gen_kern_name
  ./scripts/config --set-str LOCALVERSION "-${_kernel_flavor}"
  msg2 "Building kernel"
  _make bzImage modules
  msg2 "Build successful"

  if [ "$_STRIP" = "true" ]; then
    if [[ "$_compiler_name" =~ llvm ]]; then
      echo "Stripping vmlinux..."
      llvm-strip --strip-all-gnu "${STRIP_STATIC}" "$_where/linux-src-git/vmlinux"
    elif [[ "$_compiler_name" =~ gcc ]]; then
      echo "Stripping vmlinux..."
      strip --strip-all "${STRIP_STATIC}" "$_where/linux-src-git/vmlinux"
    fi
  fi
}

distro_install_pkg() {
  _headers_folder_name="linux-$_kernel_flavor"

  echo -e "\n\n"
  msg2 "The installation process will run the following commands:"
  echo "    # copy the patched and compiled sources to /usr/src/$_headers_folder_name"
  echo "    sudo make modules_install"
  echo "    sudo make install"
  echo "    sudo dracut --force --hostonly ${_dracut_options} --kver $_kernel_flavor"
  echo "    sudo grub-mkconfig -o /boot/grub/grub.cfg"

  msg2 "Note: Uninstalling requires manual intervention, use './install.sh uninstall-help' for more information."
  read -r -p "Continue ? Y/[n]: " _continue

  if ! [[ "$_continue" =~ ^(Y|y|Yes|yes)$ ]];then
    exit 0
  fi

  msg2 "Copying files over to /usr/src/$_headers_folder_name"
  if [ -d "/usr/src/$_headers_folder_name" ]; then
    msg2 "Removing old folder in /usr/src/$_headers_folder_name"
    sudo rm -rf "/usr/src/$_headers_folder_name"
  fi
  sudo cp -R . "/usr/src/$_headers_folder_name"
  sudo rm -rf "/usr/src/$_headers_folder_name"/.git*
  cd "/usr/src/$_headers_folder_name" || exit 1

  msg2 "Installing modules"
  if [ "$_STRIP" = "true" ]; then
    sudo make modules_install INSTALL_MOD_STRIP="1"
  else
    sudo make modules_install
  fi

  msg2 "Installing kernel"
  sudo make install
  _regen_boot
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
