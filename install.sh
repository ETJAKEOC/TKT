#!/bin/bash
set -e
_where="$(pwd)"
srcdir="$_where"

if ! command -v sudo >/dev/null; then
  if command -v doas >/dev/null; then
    sudo() { doas "$@"; }
  elif command -v su >/dev/null; then
    sudo() { su -c "$*"; }
  fi
fi

msg2() {
  echo -e " \033[1;34m->\033[1;0m \033[1;1m$1\033[1;0m" >&2
}

error() {
  echo -e " \033[1;31m==> ERROR: $1\033[1;0m" >&2
}

warning() {
  echo -e " \033[1;33m==> WARNING: $1\033[1;0m" >&2
}

plain() {
  echo -e "$1" >&2
}

################### Config sourcing

_load_distro_script() {
  local script_name=""
  case "$_distro" in
    Debian|Ubuntu|Mint) script_name="debian.sh" ;;
    Fedora|Suse) script_name="fedora.sh" ;;
    Gentoo) script_name="gentoo.sh" ;;
    Slackware) script_name="slackware.sh" ;;
    Void) script_name="void.sh" ;;
    Arch) script_name="arch.sh" ;;
    Generic) script_name="generic.sh" ;;
  esac

  if [ -n "$script_name" ] && [ -f "$_where/distros/$script_name" ]; then
    # shellcheck source=/dev/null
    source "$_where/distros/$script_name"
  else
    error "Distro script $script_name not found for distro $_distro!"
    exit 1
  fi
}

_config() {
  if [[ -z "$SCRIPT" ]]; then
    declare -p -x > current_env
  fi

  if [ "$_IS_GHCI" = "true" ]; then
    msg2 "Overriding config options for GHCI build"
    # shellcheck source=/dev/null
    source "/GHCI.cfg"
  else
    # shellcheck source=/dev/null
    source "$_where"/customization.cfg
  fi

  if [ -e "$_EXT_CONFIG_PATH" ]; then
    msg2 "External configuration file $_EXT_CONFIG_PATH will be used and will override customization.cfg values."
    # shellcheck source=/dev/null
    source "$_EXT_CONFIG_PATH"
  fi

    # modprobed-db

    if [[ "$_modprobeddb" = "true" && "$_kernel_on_diet" == "true" ]]; then
      msg2 "_modprobeddb and _kernel_on_diet cannot be used together: it doesn't make sense, _kernel_on_diet uses our own modprobed list ;)"
      exit 1
    fi

    if [[ "$_modprobeddb" = "true" ]]; then
      msg2 "Using modprobed-db"
      if [[ -f "$_where/$_modprobeddb_db_path" ]]; then
        _modprobeddb_db_path="$_where/$_modprobeddb_db_path"
      elif [[ "$_modprobeddb" = "false" && "$_kernel_on_diet" == "true" ]]; then
        msg2 "Using TKT diet db"
        _modprobeddb_db_path="$_where/kconfigs/$_basekernel/minimal-modprobed.db"
      fi
      if [ ! -f "$_modprobeddb_db_path" ]; then
        msg2 "modprobed-db database not found"
        exit 1
      fi
    fi

  . current_env
  # shellcheck source=/dev/null
  source kconfigs/prepare
  _build_dir="$_kernel_work_folder_abs/.."
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
    if [ "$_thread_num" = "0" ]; then
      _thread_num=1
    fi
  fi

  # ccache
  if [ "$_noccache" != "true" ]; then
    export PATH="/usr/lib64/ccache/:/usr/lib/ccache/bin/:$PATH"
    export CCACHE_SLOPPINESS="file_macro,locale,time_macros"
    export CCACHE_NOHASHDIR="true"
    msg2 'Enabled ccache'
  fi
}

_distro_prompt() {
  echo "Which linux distribution are you running ?"
  echo "if it's not on the list, chose the closest one to it: Fedora/Suse for RPM, Ubuntu/Debian for DEB"
  _prompt_from_array "Debian" "Fedora" "Gentoo" "Mint" "Slackware" "Suse" "Ubuntu" "Void" "Generic"
  _distro="${_selected_value}"
}

_get_debian_version() (
  # shellcheck source=/dev/null
  source /etc/os-release
  echo "$VERSION_ID"
) # () instead of {} to avoid polluting the global namespace

_install_dependencies() {
  _base_deps="bash bc bison ccache cmake cpio curl flex git kmod lz4 make patchutils perl python3 python3-pip rsync sudo tar time wget zstd"
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

_gen_kern_name() {
  distro_gen_kern_name

  if [ -z "$_kernel_localversion" ]; then
    # Build optional parts
    _diet_tag=""
    _modprobed_tag=""
    _rt_tag=""
    _compiler_name=""

    [ "$_kernel_on_diet" = "true" ] && _diet_tag="diet"
    [ "$_modprobeddb" = "true" ] && _modprobed_tag="modprobed"
    [ "$_preempt_rt" = "1" ] && _rt_tag="rt"

    if [ "$_compiler" = "llvm" ]; then
      _compiler_name="llvm"
    else
      _compiler_name="gcc"
    fi

    # Start parts array
    parts=( "tkt" )

    # Detect distro and append to kernel name
    shopt -s nocasematch
    if [[ "$_distro" =~ ^(Ubuntu|Debian|Fedora|Mint|Suse|Gentoo|Slackware|Void|Generic)$ ]]; then
      parts+=( "$(echo "$_distro" | tr '[:upper:]' '[:lower:]')" )
    fi
    shopt -u nocasematch

    # Append tags to kernel name as needed
    [ -n "$_diet_tag" ] && parts+=( "$_diet_tag" )
    [ -n "$_modprobed_tag" ] && parts+=( "$_modprobed_tag" )
    parts+=( "$_cpusched" )
    [ -n "$_rt_tag" ] && parts+=( "$_rt_tag" )
    parts+=( "$_compiler_name" )

    _kernel_flavor=$(IFS=- ; echo "${parts[*]}")

  else
    _kernel_flavor="tkt-${_kernel_localversion}"
  fi

  # Setup kernel_subver variable
  if [[ "$_sub" = rc* ]]; then
    # if an RC version, subver will always be 0
    _kernel_subver=0
  else
    _kernel_subver="${_sub}"
  fi

  # Generate kernel name once, re-used everywhere
  _kernelname="${_basekernel}.${_sub}-${_kernel_flavor}"
  _kernelname_rpm="${_basekernel}.${_sub}-${_kernel_flavor//-/_}"
}

# Condense repeated make flags
_make() {
  local verbose_opt=""

  if [[ "$1" == "verbose" ]]; then
    verbose_opt="V=2"
    shift
  fi

  if [[ "$_modprobeddb" == "true" || "$_kernel_on_diet" == "true" ]]; then
    msg2 "Building modprobed/diet kernel..."
    {
      time (env "${compiler_opt}" make "${verbose_opt}" LSMOD="$_modprobeddb_db_path" localmodconfig -j"${_thread_num:-1}" "$@")
    } 3>&1 1>&2 2>&3
  else
    msg2 "Building kernel..."
    {
      time (env "${compiler_opt}" make "${verbose_opt}" -j"${_thread_num:-1}" "$@")
    } 3>&1 1>&2 2>&3
  fi
}

# Copy winesync header if present
_winesync_copy() {
  if [ -e "${_where}/winesync.rules" ]; then
    sudo mkdir -p /usr/include/linux/
    sudo cp "$_kernel_work_folder_abs"/include/uapi/linux/winesync.h /usr/include/linux/winesync.h
  fi
}

# Make versioned output dir and move artifacts in
_move_artifacts() {
  local ext="$1"

  if [[ "$_distro" =~ ^(Fedora|Suse)$ ]]; then
    _search_dir="$_fedora_work_dir/RPMS/x86_64"
    mkdir -p "$_where/${_kernelname_rpm}"
  else
    _search_dir="$_where"
    mkdir -p "$_where/${_kernelname}"
  fi

  # Find files matching extension
  mapfile -t files < <(find "$_search_dir" -type f -iname "*.$ext")

  if [ ${#files[@]} -eq 0 ]; then
    msg2 "No .$ext artifacts found under $_search_dir"
    return 1
  fi

  if [[ "$_distro" =~ ^(Fedora|Suse)$ ]]; then
    # For Fedora use the underscore kernelname dir
    mv "${files[@]}" "$_where/${_kernelname_rpm}/"
    # For other distros, use dash kernelname dir
  else
    mv "${files[@]}" "$_where/${_kernelname}/"
  fi
}

# Prompt install confirm
_confirm_install() {
  if [[ "$_install_after_building" = "prompt" ]]; then
    read -rp "Do you want to install the new Kernel ? Y/[n]: " _install
  fi

  if [[ "$_install_after_building" =~ ^(Y|y|Yes|yes)$ || "$_install" =~ ^(Y|y|Yes|yes)$ ]]; then
    return 0
  else
    return 1
  fi
}

#  initramfs + GRUB2
_regen_boot() {
  msg2 "Creating initramfs"

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

  # Generate initramfs using available initramfs tool
  if [ "$use_dracut" = true ]; then
    if [[ "$_distro" =~ ^(Fedora|Suse)$ ]]; then
      echo "Running 'dracut' to generate the 'initramfs' file for $_distro..."
      sudo dracut --force --hostonly "${_dracut_options}" --kver "$_kernelname_rpm"
    else
      echo "Running 'dracut' to generate the 'initramfs' file for $_distro..."
      sudo dracut --force --hostonly "${_dracut_options}" --kver "$_kernelname"
    fi

  elif [ "$use_mkinitcpio" = true ]; then
    echo "Running 'mkinitcpio' to generate the 'initramfs' file..."
    sudo mkinitcpio -k "$_kernelname" -g "/boot/initramfs-${_kernelname}.img"
  elif [ "$use_update_initramfs" = true ]; then
    echo "Running 'update-initramfs' to generate the 'initramfs' file..."
    sudo update-initramfs -c -k "$_kernelname"
  else
    echo "Error: Unable to find dracut, mkinitcpio, or update-initramfs command."
    exit 1
  fi

  # Probe for the name of the GRUB configuration command
  if command -v grub-mkconfig >/dev/null 2>&1; then
    grub_cfg_cmd="sudo grub-mkconfig -o /boot/grub/grub.cfg"
  elif command -v grub2-mkconfig >/dev/null 2>&1; then
    grub_cfg_cmd="sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
  else
    echo "Error: Unable to find grub-mkconfig or grub2-mkconfig command."
    use_grub=false
  fi

  msg2 "Updating GRUB"
  if [ "$_use_grub" = "false" ]; then
    echo "GRUB2 not installed, skipping GRUB2 steps..."
  else
    sudo "${grub_cfg_cmd}"
  fi
}

main() {
  _config

  if [ "$1" != "install" ] && [ "$1" != "config" ] && [ "$1" != "verbose" ] && [ "$1" != "uninstall-help" ]; then
    msg2 "Argument not recognised, options are:
          - config : interactive script that shallow clones the linux kernel git tree into the folder \$_kernel_work_folder, then applies extra patches and prepares the .config file
                     by copying the one from the currently running linux system and updates it.
          - install : does the config step, proceeds to compile, then prompts to install
                      - 'DEB' distros: it creates .deb packages that will be installed then stored in a folder.
                      - 'RPM' distros: it creates .rpm packages that will be installed then stored in a folder.
                      - 'Generic' distro: it uses 'make modules_install' and 'make install', uses 'dracut' to create an initramfs, then updates grub's boot entry.
          - verbose : does the install step, but with extra verbose output for diagnostics.
          - uninstall-help : [RPM and DEB based distros only], lists the installed kernels in this system, then gives hints on how to uninstall them manually."
    exit 0
  fi

  if [ "$1" = "install" ] || [ "$1" = "config" ] || [ "$1" = "verbose" ]; then
    _tkg_initscript
    if [[ -z "$_distro" || ! "$_distro" =~ ^(Ubuntu|Debian|Fedora|Mint|Suse|Gentoo|Slackware|Void|Generic)$ ]]; then
      msg2 "Variable \"_distro\" in \"customization.cfg\" is invalid or empty. Prompting..."
      _distro_prompt
      msg2 "Configuration done."
    fi
    _load_distro_script
  fi

  if [ "$1" = "install" ] || [ "$1" = "verbose" ]; then
    _install_dependencies

    if [[ "${_compiler}" = "llvm" && "${_distro}" =~ ^(Generic|Gentoo)$ && "${_libunwind_replace}" = "true" ]]; then
        export LDFLAGS_MODULE="-unwindlib=libunwind"
        export HOSTLDFLAGS="-unwindlib=libunwind"
    fi

    _tkg_srcprep
    cd "$_kernel_work_folder_abs" || { echo "Source dir missing"; exit 1; }

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

path="$(realpath "$0")"
if [ "${path##*/}" = "install.sh" ]; then
  main "$@"
fi
