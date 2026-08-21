#!/bin/bash

# Debian-based distributions (Debian, Ubuntu, Mint)

_get_debian_version() (
  # shellcheck source=/dev/null
  source /etc/os-release
  echo "$VERSION_ID"
)

distro_install_dependencies() {
  local _debian_version
  _debian_version="$(_get_debian_version)"
  msg2 "Installing dependencies for $_distro"

  if [[ "$_debian_version" -lt 13 ]]; then
    _deb_common="${_deb_common} libstdc++-12-dev"
  else
    _deb_common="${_deb_common} libstdc++-14-dev"
  fi

  if [[ "$_compiler_name" == *llvm* ]]; then
    sudo apt install -y "${_deb_common}" "${_deb_common_clang}" "${_clang_deps}"
  else
    sudo apt install -y "${_deb_common}"
  fi

  if [[ "$_distro" = "Ubuntu" ]] || [ "$_distro" = "Mint" ]; then
    sudo apt install -y liblz4-dev libxxhash-dev software-properties-common
  fi
}

distro_gen_kern_name() {
  # Uppercase characters are not allowed in source package name for debian based distros
  if [ "$_cpusched" = "MuQSS" ]; then
    _cpusched="muqss"
  fi
}

distro_build_pkg() {
  msg2 "Building kernel DEB packages"
  _make bindeb-pkg LOCALVERSION=-"${_kernel_flavor}" KDEB_PKGVERSION=1
  msg2 "Build done"
  _move_artifacts "deb"
  _winesync_copy
}

distro_install_pkg() {
  if _confirm_install; then
    sudo dpkg -i "$_where/${_kernelname}"/*.deb
  fi
}

distro_uninstall_help() {
  msg2 "List of installed custom TKT kernels: "
  dpkg -l "*" | grep "linux.*"
  dpkg -l "*linux-libc-dev*" | grep "linux.*"
  msg2 "To uninstall a version, you should remove the linux-image, linux-headers and linux-libc-dev associated to it (if installed), with: "
  msg2 "      sudo apt remove linux-image-VERSION linux-headers-VERSION linux-libc-dev-VERSION"
  msg2 "       where VERSION is displayed in the lists above, uninstall only versions that have \"tkg\" in its name"
  msg2 "Note: linux-libc-dev packages are no longer created and installed, you can safely remove any remnants."
}

distro_srcprep_post() {
  # Prevent Debian, Mint, and Ubuntu to sign stuff because it breaks stuff
  # Help Debian cert compile problem.
  scripts/config --set-str "SYSTEM_TRUSTED_KEYS" ""
  if [[ $_kver -lt 612 ]]; then # note: 6.12 removed MODULE_COMPRESS_NONE
    # Debian/Mint/Ubuntu don't properly support zstd module compression
    _disable "MODULE_COMPRESS_ZSTD"
    _enable "MODULE_COMPRESS_NONE"
  fi
}
