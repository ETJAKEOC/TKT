#!/bin/bash

# TKT Installer Library - Clean Version

_install_dependencies() {
  _base_deps="bash bc bison ccache cmake cpio curl flex git kmod lz4 make patchutils perl python3 python3-pip rsync sudo tar time wget zstd whiptail"
  _clang_deps="clang lld llvm"
  _deb_common="${_base_deps} binutils binutils-dev binutils-gold build-essential debhelper device-tree-compiler dpkg-dev dwarves fakeroot g++ g++-multilib gcc gcc-multilib gnupg libc6-dev libc6-dev-i386 libdw-dev libelf-dev libncurses-dev libnuma-dev libperl-dev libssl-dev libudev-dev ninja-build python3-setuptools qtbase5-dev schedtool xz-utils"
  _deb_common_clang="clang-format clang-tidy clang-tools"
  _rpm_common="${_base_deps} dwarves gcc-c++ gawk hostname ncurses-devel libdw-devel libelf-devel libnuma-devel libopenssl-devel libudev-devel openssl openssl-devel python3-devel rpm-build rpmdevtools xz zstd"
  _fedora_common="${_rpm_common} elfutils-devel fedora-packager fedpkg pesign numactl-devel openssl-devel-engine perl-devel perl-generators qt5-qtbase-devel"
  _suse_common="${_rpm_common} awk kernel-source kernel-syms libqt5-qtbase-common-devel perl perl-ExtUtils-MakeMaker systemd-devel python311-devel python311-pip"
  _slack_common="${_base_deps} binutils brotli cyrus-sasl diffutils dwarves elfutils fakeroot fakeroot-ng file gc gcc gcc-g++ gcc-gcobol gcc-gdc gcc-gfortran gcc-gm2 gcc-gnat gcc-go gcc-objc gcc-rust glibc git guile gzip kernel-headers libedit libelf libxml2 lzop m4 ncurses nghttp2 nghttp3 openssl perl schedtool spirv-llvm-translator xxHash xz"
  _void_common="${_base_deps} base-devel docbook-xsl elfutils-devel fakeroot gcc gnupg graphviz liblz4-devel lz4 lzop m4 ncurses openssl-devel pahole patch pkg-config schedtool xtools xmlto xz"

  distro_install_dependencies
}

# Maintenance: Logic from initramfs-and-grub-update.sh
maintenance_regen_boot() {
    msg2 "Maintenance: Regenerating Initramfs and updating GRUB..."

    # Find the TKT kernel package in /lib/modules
    local tkt_k
    tkt_k=$(find /lib/modules -maxdepth 1 -name '*TKT*' | head -n 1)

    if [ -z "$tkt_k" ]; then
        # Try to use current session variable if running right after build
        if [ -n "$_kernelname" ]; then
            tkt_version="$_kernelname"
        else
            error "TKT kernel version not found in /lib/modules or current session."
            return 1
        fi
    else
        tkt_version=$(basename "$tkt_k")
    fi

    msg2 "Selected kernel version: $tkt_version"

    # Probe for tools
    local grub_cmd=""
    command -v grub-mkconfig >/dev/null 2>&1 && grub_cmd="grub-mkconfig"
    command -v grub2-mkconfig >/dev/null 2>&1 && grub_cmd="grub2-mkconfig"

    local dracut_bin=""
    command -v dracut >/dev/null 2>&1 && dracut_bin="dracut"

    if [ -n "$dracut_bin" ]; then
        msg2 "Running dracut..."
        sudo "$dracut_bin" --force --hostonly --kver "$tkt_version"
    else
        warning "dracut not found, attempting fallback tools..."
        # Fallback to _regen_boot logic already in core.sh if needed
        _regen_boot
    fi

    if [ -n "$grub_cmd" ]; then
        msg2 "Updating GRUB menu..."
        sudo "$grub_cmd" -o /boot/grub/grub.cfg
    else
        warning "GRUB configuration command not found."
    fi

    msg2 "Maintenance tasks completed."
}

# Maintenance: Project Cleanup (Logic from CLEAN_BUILD.sh)
maintenance_project_cleanup() {
    msg2 "Maintenance: Cleaning project build artifacts..."

    # Standard cleanup
    rm -rf "$_TKT_ROOT"/*.patch
    rm -f "$_LOGS_DIR/current_env"
    rm -f "$_TKT_ROOT/kernelconfig.new"
    rm -f "$_TKT_ROOT/TKT_CONFIG"
    rm -rf "${_LOGS_DIR:?}"/*

    # Source and Package cleanup
    rm -rf "${_SRC_DIR:?}"/*
    rm -rf "${_PKG_DIR:?}"/*

    msg2 "Cleanup completed."
}

_config() {
  _source_tkt_config

  # modprobed-db sanity check
  if [[ "$_modprobeddb" = "true" && "$_kernel_on_diet" == "true" ]]; then
    msg2 "_modprobeddb and _kernel_on_diet cannot be used together."
    exit 1
  fi

  if [[ "$_modprobeddb" = "true" ]]; then
    msg2 "Using modprobed-db"
    if [[ -f "$_where/$_modprobeddb_db_path" ]]; then
      _modprobeddb_db_path="$_where/$_modprobeddb_db_path"
    elif [[ "$_modprobeddb" = "false" && "$_kernel_on_diet" == "true" ]]; then
      msg2 "Using TKT diet db"
      _modprobeddb_db_path="$_KERNELS_DIR/$_basekernel/minimal-modprobed.db"
    fi
    if [ ! -f "$_modprobeddb_db_path" ]; then
      msg2 "modprobed-db database not found"
      exit 1
    fi
  fi

  # shellcheck source=/dev/null
  source lib/prepare.sh
  _build_dir="$_SRC_DIR"
  export KCPPFLAGS
  export KCFLAGS

  # Use custom compiler paths if defined
  if [[ "$_compiler_name" =~ llvm ]] && [ -n "${CUSTOM_LLVM_PATH}" ]; then
    PATH="${CUSTOM_LLVM_PATH}/bin:${CUSTOM_LLVM_PATH}/lib:${CUSTOM_LLVM_PATH}/include:${PATH}"
  elif [ -n "${CUSTOM_GCC_PATH}" ]; then
    PATH="${CUSTOM_GCC_PATH}/bin:${CUSTOM_GCC_PATH}/lib:${CUSTOM_GCC_PATH}/include:${PATH}"
  fi

  if [ "$_force_all_threads" = "true" ]; then
    _thread_num=$(nproc)
  else
    _thread_num=$(($(nproc) / 2))
    [ "$_thread_num" = "0" ] && _thread_num=1
  fi

  # ccache
  if [ "$_noccache" != "true" ]; then
    export PATH="/usr/lib64/ccache/:/usr/lib/ccache/bin/:$PATH"
    export CCACHE_SLOPPINESS="file_macro,locale,time_macros"
    export CCACHE_NOHASHDIR="true"
    msg2 'Enabled ccache'
  fi
}

tkt_cli_main() {
  _config

  if [ "$1" != "install" ] && [ "$1" != "config" ] && [ "$1" != "verbose" ] && [ "$1" != "uninstall-help" ] && [ "$1" != "maintenance" ]; then
    msg2 "Argument not recognised, options are:
          - config : Interactive preparation step.
          - install : Build and install the kernel.
          - verbose : Build and install with verbose output.
          - maintenance : Regenerate initramfs and update GRUB.
          - uninstall-help : Distro-specific hints for removal."
    exit 0
  fi

  if [ "$1" = "maintenance" ]; then
      maintenance_regen_boot
      exit 0
  fi

  if [ "$1" = "install" ] || [ "$1" = "config" ] || [ "$1" = "verbose" ]; then
    _tkg_initscript
    if [[ -z "$_distro" || ! "$_distro" =~ ^(Ubuntu|Debian|Fedora|Mint|Suse|Gentoo|Slackware|Void|Generic|Arch)$ ]]; then
      _distro_prompt
    fi
    _load_distro_script
  fi

  if [ "$1" = "install" ] || [ "$1" = "verbose" ]; then
    _install_dependencies

    if [[ "${_compiler}" = "llvm" && "${_distro}" =~ ^(Generic|Gentoo)$ && "${_libunwind_replace}" = "true" ]]; then
        export LDFLAGS_MODULE="-unwindlib=libunwind"
        export HOSTLDFLAGS="-unwindlib=libunwind"
    fi

    if [[ "$_distro" != "Arch" ]]; then
      _tkg_srcprep
    fi

    cd "$_TKT_ROOT" || { echo "Root dir missing"; exit 1; }

    distro_build_pkg
    distro_install_pkg
  fi

  if [ "$1" = "uninstall-help" ]; then
    if [ -z "$_distro" ]; then
      _distro_prompt
    fi
    _load_distro_script
    cd "$_where" || exit 1
    distro_uninstall_help
  fi
}
