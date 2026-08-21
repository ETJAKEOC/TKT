#!/bin/bash

# Fedora and openSUSE distributions

distro_install_dependencies() {
  msg2 "Installing dependencies for $_distro"
  if [ "$_distro" = "Fedora" ]; then
    sudo dnf update -y
    if [[ "$_compiler_name" == *llvm* ]]; then
      sudo dnf install -y --skip-unavailable "${_fedora_common}" "${_clang_deps}"
    else
      sudo dnf install -y --skip-unavailable "${_fedora_common}"
    fi
  elif [ "$_distro" = "Suse" ]; then
    sudo zypper refresh
    if [[ "$_compiler_name" == *llvm* ]]; then
      sudo zypper install -y "${_suse_common}" "${_clang_deps}"
    else
      sudo zypper install -y "${_suse_common}"
    fi
  fi
}

distro_gen_kern_name() {
  _kernelname_rpm="${_basekernel}.${_sub}-${_kernel_flavor//-/_}"
}

distro_build_pkg() {
  if [ "$_distro" = "Fedora" ]; then
    _kernel_flavor_rpm="${_kernel_flavor//-/_}"
  else
    _kernel_flavor_rpm="${_kernel_flavor}"
  fi

  _fedora_work_dir="$_kernel_work_folder_abs/rpmbuild"

  msg2 "Building kernel RPM packages"
  _make RPMOPTS="--define '_topdir ${_fedora_work_dir}'" EXTRAVERSION=-"${_kernel_flavor_rpm}" binrpm-pkg
  msg2 "Build done"
  _move_artifacts "rpm"
  _winesync_copy
}

distro_install_pkg() {
  if _confirm_install; then
    if [ "$_distro" = "Fedora" ]; then
      sudo dnf install "$_where/${_kernelname_rpm}"/*.rpm
    elif [ "$_distro" = "Suse" ]; then
      sudo zypper removelock kernel-default-devel kernel-default kernel-devel kernel-syms
      sudo zypper remove kernel-devel
      sudo zypper install --oldpackage --allow-unsigned-rpm "$_where/${_kernelname}"/*.rpm
      sudo zypper addlock kernel-default-devel kernel-default kernel-devel kernel-syms
    fi
    _regen_boot
  fi
}

distro_uninstall_help() {
  if [ "$_distro" = "Fedora" ]; then
    msg2 "List of installed custom TKT kernels: "
    dnf list --installed | grep -i "tkt"
    msg2 "To uninstall a version, you should remove the kernel, kernel-headers and kernel-devel associated to it (if installed), with: "
    msg2 "      sudo dnf remove --noautoremove kernel-VERSION kernel-devel-VERSION kernel-headers-VERSION"
    msg2 "       where VERSION is displayed in the second column"
    msg2 "Note: kernel-headers packages are no longer created and installed, you can safely remove any remnants."
  elif [ "$_distro" = "Suse" ]; then
    msg2 "List of installed custom TKT kernels: "
    zypper packages --installed-only | grep "kernel.*"
    msg2 "To uninstall a version, you should remove the kernel, kernel-headers and kernel-devel associated to it (if installed), with: "
    msg2 "      sudo zypper remove --no-clean-deps kernel-VERSION kernel-devel-VERSION kernel-headers-VERSION"
    msg2 "       where VERSION is displayed in the second to last column"
    msg2 "Note: kernel-headers packages are no longer created and installed, you can safely remove any remnants."
  fi
}

distro_srcprep_pre() {
  if [ "$_distro" = "Fedora" ]; then
    tkgpatch="$srcdir/0013-fedora-rpm.patch"
    _msg="RPM: fixing spec generator" && _tkg_patcher
    if [[ "$_STRIP" == "true" ]]; then
      tkgpatch="$srcdir/0013-fedora-strip-modules.patch"
      _msg="RPM: strip modules" && _tkg_patcher
    fi
  elif [ "$_distro" = "Suse" ]; then
    tkgpatch="$srcdir/0013-suse-rpm.patch"
    _msg="RPM: fixing spec generator" && _tkg_patcher
    if [[ "$_STRIP" == "true" ]]; then
      tkgpatch="$srcdir/0013-suse-strip-modules.patch"
      _msg="RPM: strip modules" && _tkg_patcher
    fi
    tkgpatch="$srcdir/0013-suse-additions.patch"
    _msg="Import Suse-specific patches" && _tkg_patcher
  fi
}

distro_srcprep_post() {
  # Modify the kernel config file to fit Fedora SELinux configuration
  if [ "$_distro" = "Fedora" ]; then
    msg2 "SELinux activation for Fedora"
    _enable "AUDIT"
    _enable "SECURITY_SELINUX"
    _enable "DEFAULT_SECURITY_SELINUX"
    _disable "DEFAULT_SECURITY_DAC"
    scripts/config --set-str "LSM" "lockdown,yama,integrity,selinux,bpf,landlock"
  fi
}
