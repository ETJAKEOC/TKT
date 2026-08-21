#!/bin/bash

# Arch Linux distribution

distro_install_dependencies() {
  # Dependencies are handled by PKGBUILD makedepends
  msg2 "Dependencies for Arch are managed by PKGBUILD."
}

distro_gen_kern_name() {
  if [ -n "$_custom_pkgbase" ]; then
    pkgbase="${_custom_pkgbase}"
  else
    pkgbase="linux-${_kernelname}"
  fi
}

distro_build_pkg() {
  msg2 "Building Arch Linux package via makepkg..."
  # makepkg must be run from the root, pointing to the PKGBUILD in distros/arch/
  cd "$_TKT_ROOT" || exit 1
  # Use -p to point to the relocated PKGBUILD
  # Use -sc to clean up after build
  makepkg -p distros/arch/PKGBUILD -sc
}

distro_install_pkg() {
  if _confirm_install; then
    msg2 "Installing created packages..."
    sudo pacman -U ./*.pkg.tar.*
  fi
}

distro_srcprep_pre() {
  if [ -n "$_custom_pkgbase" ]; then
    echo "-${_custom_pkgbase}" >localversion.10-pkgrel
    printf "Version tail set to \"-%s\"\n" "${_custom_pkgbase}" >"$_LOGS_DIR"/prepare.log.txt
  else
    echo "-${_cpusched}${_compiler_name}" >localversion.10-pkgrel
    printf "Version tail set to \"-%s%s\"\n" "${_cpusched}" "${_compiler_name}" >"$_LOGS_DIR"/prepare.log.txt
  fi
  echo "" >localversion.20-pkgname
}

distro_srcprep_post() {
  # don't run depmod on 'make install'. We'll do this ourselves in packaging
  sed -i '2iexit 0' scripts/depmod.sh
}

_mkinitcpio() {
  source "$_where"/TKT_CONFIG
  if [[ "${_ukify}" == "true" ]]; then
    msg2 "Preparing mkinitcpio preset for ${pkgbase}..."

    local preset_file="/etc/mkinitcpio.d/${pkgbase}.preset"
    sudo mkdir -p "/etc/mkinitcpio.d"
    # Backup existing preset
    if [[ -f "$preset_file" ]]; then
      sudo cp "$preset_file" "${preset_file}.bak"
      msg2 "Existing preset backed up to ${preset_file}.bak"
    fi
    cat <<EOF | sudo tee "$preset_file" >/dev/null
# mkinitcpio preset file for ${pkgbase} (UKI configuration)

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="${pkgver}-${_kernelname}"
PRESETS=('default')

default_image="/boot/vmlinuz-${pkgbase}"
default_initramfs="/boot/initramfs-${pkgbase}.img"
default_uki="/efi/${pkgbase}.efi"
default_options=""
EOF
    msg2 "Created UKI-aware mkinitcpio preset at ${preset_file}"
  else
    local preset_file="/etc/mkinitcpio.d/${pkgbase}.preset"
    sudo mkdir -p "/etc/mkinitcpio.d"
    cat <<EOF | sudo tee "$preset_file" >/dev/null
# mkinitcpio preset file for ${pkgbase}

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="${pkgver}-${_kernelname}"
PRESETS=('default')

default_image="/boot/vmlinuz-${pkgbase}"
default_initramfs="/boot/initramfs-${pkgbase}.img"
default_options=""
EOF
    msg2 "Created standard mkinitcpio preset at ${preset_file}"
  fi
}
