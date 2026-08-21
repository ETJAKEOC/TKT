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

distro_srcprep_pre() {
  if [ -n "$_custom_pkgbase" ]; then
    echo "-${_custom_pkgbase}" >localversion.10-pkgrel
    printf "Version tail set to \"-%s\"\n" "${_custom_pkgbase}" >"$_where"/logs/prepare.log.txt
  else
    echo "-${_cpusched}${_compiler_name}" >localversion.10-pkgrel
    printf "Version tail set to \"-%s%s\"\n" "${_cpusched}" "${_compiler_name}" >"$_where"/logs/prepare.log.txt
  fi
  echo "" >localversion.20-pkgname
}

distro_srcprep_post() {
  # don't run depmod on 'make install'. We'll do this ourselves in packaging
  sed -i '2iexit 0' scripts/depmod.sh
}

_mkinitcpio() {
  if [[ "${_ukify}" == "true" ]]; then
    msg2 "Preparing mkinitcpio preset for ${pkgbase} (UKI configuration)..."
    # ... (content from PKGBUILD)
  else
    msg2 "Preparing standard mkinitcpio preset for ${pkgbase}..."
    # ...
  fi
}
