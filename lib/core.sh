#!/bin/bash

# TKT Core Library - Clean Version

# Path Constants
_where="${_where:-$(pwd)}"
# If we are in a sub-directory (like distros/arch), find the toolkit root
if [ -f "$_where/tkt" ]; then
    _TKT_ROOT="$_where"
elif [ -f "$_where/../../tkt" ]; then
    _TKT_ROOT="$(realpath "$_where/../..")"
else
    _TKT_ROOT="$_where"
fi

_KERNELS_DIR="$_TKT_ROOT/kernels"
_DISTROS_DIR="$_TKT_ROOT/distros"
_LIB_DIR="$_TKT_ROOT/lib"
_SRC_DIR="$_TKT_ROOT/src"
_PKG_DIR="$_TKT_ROOT/pkg"
_LOGS_DIR="$_TKT_ROOT/logs"
_TKT_CONFIG_PATH="$_SRC_DIR/TKT_CONFIG"

# Ensure core directories exist
mkdir -p "$_SRC_DIR" "$_PKG_DIR" "$_LOGS_DIR"

# Ensure core directories exist
mkdir -p "$_SRC_DIR" "$_PKG_DIR" "$_LOGS_DIR"

# Static Data
_current_kernels=("7.3" "7.2" "7.1" "6.18")
_eol_kernels=()

typeset -Ag _all_scheds=(
  ["pds"]="Project C's Priority and Deadline based Skiplist multiple queue scheduler (PDS)"
  ["bmq"]="Project C's BitMap Queue Scheduler (BMQ)"
  ["eevdf"]="Earliest Eligible Virtual Deadline First scheduler (EEVDF). Linux kernel's default for ≥ 6.6"
  ["cfs"]="Completely Fair Scheduler (CFS). Linux kernel's default for ≤ 6.5"
  ["muqss"]="Multiple Queue Skiplist Scheduler (MuQSS)"
  ["upds"]="TkG's Undead PDS"
  ["bore"]="Burst-Oriented Response Enhancer Scheduler (BORE)"
  ["bore-eevdf"]="Burst-Oriented Response Enhancer Scheduler (BORE, EEVDF variant)"
)

typeset -Ag _cpu_marchs=(
  ["x86-64"]="Baseline for any X86 CPU (default)"
  ["x86-64-v2"]="Baseline for X86 CPUs newer than ~2008"
  ["x86-64-v3"]="Baseline for X86 CPUS newer than ~2013"
  ["x86-64-v4"]="Baseline for Intel Skylake or newer, AMD zen4 or newer"
  ["native"]="Automatically tune for the current CPU"
  ["znver5"]="AMD Ryzen 9000 | Mobile Ryzen AI (MAX) 300 | EPYC 9005"
  ["znver4"]="AMD Ryzen 8000/7000 | Mobile Ryzen 200 | Threadripper 7000WX | EPYC 9004/8004/4004"
  ["znver3"]="AMD Ryzen 6000/5000 | Mobile Ryzen 7030/5000 | Threadripper 5000WX | EPYC 7003"
  ["znver2"]="AMD Ryzen 4000/3000 | Mobile Ryzen 5[3,5,7]00U | Threadripper 3000WX | EPYC 7002"
  ["znver1"]="AMD Ryzen 1000/2000 | Athlon 200/300/3000 | Threadripper 1000 | EPYC 7001"
  ["arrowlake-s"]="Intel Desktop Core Ultra 200"
  ["arrowlake"]="Intel Laptop Core Ultra 200"
  ["lunarlake"]="Intel Laptop Core Ultra 200V"
  ["meteorlake"]="Intel Laptop Core Ultra 100"
  ["raptorlake"]="Intel Core 14th & 13th gen"
  ["alderlake"]="Intel Core 12th gen"
  ["rocketlake"]="Intel Core 11th gen"
  ["tigerlake"]="Intel Laptop Core 11th gen"
  ["icelake-client"]="Intel Desktop Core 10th gen"
  ["skylake"]="Intel Desktop Core 6th to 9th gen"
)

typeset -Ag _kernel_git_remotes=(
  ["kernel.org"]="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
  ["googlesource.com"]="https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable"
  ["gregkh"]="https://github.com/gregkh/linux.git"
  ["torvalds"]="https://github.com/torvalds/linux.git"
)

_git_remote_names=("${!_kernel_git_remotes[@]}")
_git_mirror="${_kernel_git_remotes[kernel.org]}"

# RT Map caching
declare -A _rt_subver_map
declare -A _rt_rev_map

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

# Sudo wrapper for systems without sudo (e.g. some Gentoo installs)
sudo() {
  if command -v sudo >/dev/null 2>&1; then
    command sudo "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  else
    # Fallback to su -c
    local cmd_str
    cmd_str=$(printf "%q " "$@")
    su -c "$cmd_str"
  fi
}

_gen_kern_name() {
  if declare -f distro_gen_kern_name >/dev/null; then
    distro_gen_kern_name
  else
    # Fallback/Generic naming
    _kernelname="${_basekernel}.${_sub}-${_kernel_flavor}"
  fi
}

_load_distro_script() {
  local script_dir=""
  case "$_distro" in
    Debian|Ubuntu|Mint) script_dir="debian" ;;
    Fedora|Suse) script_dir="fedora" ;;
    Gentoo) script_dir="gentoo" ;;
    Slackware) script_dir="slackware" ;;
    Void) script_dir="void" ;;
    Arch) script_dir="arch" ;;
    Generic) script_dir="generic" ;;
  esac

  if [ -n "$script_dir" ] && [ -f "$_DISTROS_DIR/$script_dir/main.sh" ]; then
    # shellcheck source=/dev/null
    source "$_DISTROS_DIR/$script_dir/main.sh"
  else
    # Dynamic fallback: scan for main.sh in distros/ subdirs
    local found=false
    for d in "$_DISTROS_DIR"/*/main.sh; do
        if [[ -f "$d" ]]; then
            local dname
            dname=$(basename "$(dirname "$d")")
            if [[ "${dname,,}" == "${_distro,,}" ]]; then
                # shellcheck source=/dev/null
                source "$d"
                found=true
                break
            fi
        fi
    done

    if [ "$found" = "false" ]; then
      error "Distro script main.sh not found for distro $_distro in $_DISTROS_DIR!"
      exit 1
    fi
  fi
}

_get_debian_version() (
  # shellcheck source=/dev/null
  source /etc/os-release
  echo "$VERSION_ID"
)

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

# Unified stripping function
_strip_vmlinux_file() {
  local target_file="$1"
  if [ "$_STRIP" = "true" ] && [ -f "$target_file" ]; then
    if [[ "$_compiler_name" =~ llvm ]]; then
      echo "Stripping $target_file with llvm-strip..."
      llvm-strip --strip-all-gnu "${STRIP_STATIC}" "$target_file"
    elif [[ "$_compiler_name" =~ gcc ]]; then
      echo "Stripping $target_file with strip..."
      strip --strip-all "${STRIP_STATIC}" "$target_file"
    fi
  fi
}

# Common kernel build workflow (naming, localversion, make, winesync, strip)
_build_kernel_generic() {
  _gen_kern_name
  cd "$_kernel_work_folder_abs" || { error "Kernel source dir not found at $_kernel_work_folder_abs"; exit 1; }
  ./scripts/config --set-str LOCALVERSION "-${_kernel_flavor}"
  msg2 "Building kernel..."
  _build_kernel_core
  msg2 "Build successful"
  _winesync_copy
  _strip_vmlinux_file "$_where/linux-src-git/vmlinux"
}

# Core build execution logic (reusable by PKGBUILD and install.sh)
_make() {
  _build_kernel_core "$@"
}

_build_kernel_core() {
  local verbose_opt=""
  if [[ "$1" == "verbose" ]]; then
    verbose_opt="V=2"
    shift
  fi

  local _make_jobs_arg
  if [ "$_force_all_threads" = "true" ]; then
    _make_jobs_arg="-j$(nproc)"
  else
    _make_jobs_arg="-j$(($(nproc) / 2))"
    [ "$_make_jobs_arg" = "-j0" ] && _make_jobs_arg="-j1"
  fi

  # -------------------------
  # Optimization flags
  # -------------------------
  export LLVM_FLAGS=""
  export LDFLAGS="${LDFLAGS:-}"

  if [[ "$_compiler" == "llvm" ]]; then
    # PGO
    if [[ "$_pgo_generate" == "true" ]]; then
      export LLVM_PROFDIR="${srcdir:-.}/pgo-profiles"
      mkdir -p "$LLVM_PROFDIR"
      LLVM_FLAGS+=" -fprofile-generate=${LLVM_PROFDIR}"
    elif [[ "$_pgo_use" == "true" ]]; then
      LLVM_FLAGS+=" -fprofile-use=${_pgo_profile_path} -fprofile-correction"
    fi

    # AutoFDO
    if [[ "$_auto_afdo" == "true" ]]; then
      LLVM_FLAGS+=" -fauto-profile=${_auto_fdo_profile}"
    fi

    # Propeller
    if [[ "$_propeller_generate" == "true" ]]; then
      LLVM_FLAGS+=" -Wl,--emit-relocs -Wl,-z,notext"
    elif [[ "$_propeller_use" == "true" ]]; then
      LDFLAGS+=" -Wl,--propeller=${_propeller_profile}"
    fi

    export KCFLAGS="${KCFLAGS:-} $LLVM_FLAGS"
    export KCPPFLAGS="${KCPPFLAGS:-} $LLVM_FLAGS"
  fi

  # -------------------------
  # Final build
  # -------------------------
  local diet_args=()
  local diet_target=""

  if [[ "$_modprobeddb" == "true" || "$_kernel_on_diet" == "true" ]]; then
    diet_args=(LMC_KEEP=false "LMC_FILE=${_modprobeddb_db_path}")
    diet_target="localmodconfig"
  fi

  if [[ "$ETJAKEOC" == "1" ]]; then
    # Override for 3900XT
    # shellcheck disable=SC2086
    time (taskset -c 0-21 env ${compiler_opt} make -j22 -l22 ${verbose_opt} "$@")
  else
    if [[ -n "$diet_target" ]]; then
        msg2 "Building modprobed/diet kernel..."
        # shellcheck disable=SC2086
        time (env ${compiler_opt} make ${_make_jobs_arg} ${verbose_opt} "${diet_args[@]}" ${diet_target} "$@")
    else
        msg2 "Building kernel..."
        # shellcheck disable=SC2086
        time (env ${compiler_opt} make ${_make_jobs_arg} ${verbose_opt} "$@")
    fi
  fi
}

# Common source installation workflow
_install_kernel_source_generic() {
  local _headers_folder_name="$1"
  local _remove_modules_from_src="${2:-true}"

  echo -e "\n\n"
  msg2 "The installation process will run the following commands:"
  echo "    # copy the patched and compiled sources to /usr/src/$_headers_folder_name"
  echo "    sudo make modules_install"
  echo "    sudo make install"
  echo "    sudo dracut --force --hostonly ${_dracut_options} --kver $_kernel_flavor"
  echo "    sudo grub-mkconfig -o /boot/grub/grub.cfg"

  msg2 "Note: Uninstalling requires manual intervention, use './install.sh uninstall-help' for more information."
  read -r -p "Continue ? Y/[n]: " _continue

  if ! [[ "$_continue" =~ ^(Y|y|Yes|yes)$ ]]; then
    exit 0
  fi

  msg2 "Copying files over to /usr/src/$_headers_folder_name"
  if [ -d "/usr/src/$_headers_folder_name" ]; then
    msg2 "Removing old folder in /usr/src/$_headers_folder_name"
    sudo rm -rf "/usr/src/$_headers_folder_name"
  fi
  sudo cp -R . "/usr/src/$_headers_folder_name"
  sudo rm -rf "/usr/src/$_headers_folder_name/.git"*
  cd "/usr/src/$_headers_folder_name" || exit 1

  msg2 "Installing modules"
  if [ "$_STRIP" = "true" ]; then
    sudo make modules_install INSTALL_MOD_STRIP="1"
  else
    sudo make modules_install
  fi

  if [ "$_remove_modules_from_src" = "true" ]; then
    msg2 "Removing modules from source folder in /usr/src/${_headers_folder_name}"
    sudo find . -type f -name '*.ko' -delete
    sudo find . -type f -name '*.ko.cmd' -delete
  fi

  msg2 "Installing kernel"
  sudo make install
  _regen_boot
}

#  initramfs + GRUB2
_regen_boot() {
  msg2 "Creating initramfs"

  # Probe if dracut is available
  local use_dracut=false
  local use_mkinitcpio=false
  local use_update_initramfs=false

  command -v dracut >/dev/null 2>&1 && use_dracut=true
  command -v mkinitcpio >/dev/null 2>&1 && use_mkinitcpio=true
  command -v update-initramfs >/dev/null 2>&1 && use_update_initramfs=true

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
  local grub_cfg_cmd=""
  local use_grub=true

  if command -v grub-mkconfig >/dev/null 2>&1; then
    grub_cfg_cmd="sudo grub-mkconfig -o /boot/grub/grub.cfg"
  elif command -v grub2-mkconfig >/dev/null 2>&1; then
    grub_cfg_cmd="sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
  else
    echo "Error: Unable to find grub-mkconfig or grub2-mkconfig command."
    use_grub=false
  fi

  msg2 "Updating GRUB"
  if [ "$use_grub" = "false" ]; then
    echo "GRUB2 not installed, skipping GRUB2 steps..."
  else
    # shellcheck disable=SC2086
    sudo ${grub_cfg_cmd}
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

# Copy winesync header if present
_winesync_copy() {
  if [ -e "${_where}/winesync.rules" ]; then
    sudo mkdir -p /usr/include/linux/
    sudo cp "$_kernel_work_folder_abs/include/uapi/linux/winesync.h" /usr/include/linux/winesync.h
  fi
}

# Core configuration sourcing logic
_source_tkt_config() {
  # Backup existing exported variables to prevent overwriting by source
  local old_distro="${_distro:-}"
  local old_compiler="${_compiler:-}"
  local old_cpusched="${_cpusched:-}"
  local old_timer_freq="${_timer_freq:-}"

  # Set default config path if not set
  _EXT_CONFIG_PATH="${_EXT_CONFIG_PATH:-$HOME/.config/TKT.cfg}"

  # Expand tilde in _EXT_CONFIG_PATH
  _EXT_CONFIG_PATH="${_EXT_CONFIG_PATH/#\~/$HOME}"

  if [ -z "$_ispkgbuild" ]; then
    if [[ -z "$SCRIPT" ]]; then
      declare -p -x > "$_LOGS_DIR/current_env"
    fi

    if [ "$_IS_GHCI" = "true" ]; then
      # shellcheck source=/dev/null
      [ -f "/GHCI.cfg" ] && source "/GHCI.cfg"
    else
      # We no longer rely on a local customization.cfg if TUI/User config is present
      # But we keep it as a legacy fallback for now if it exists
      # shellcheck source=/dev/null
      [ -f "$_where/customization.cfg" ] && source "$_where/customization.cfg"
    fi

    if [ -f "$_TKT_CONFIG_PATH" ]; then
        # shellcheck source=/dev/null
        source "$_TKT_CONFIG_PATH"
    fi

    if [ -f "$_EXT_CONFIG_PATH" ]; then
      # shellcheck source=/dev/null
      source "$_EXT_CONFIG_PATH"
    fi
  else
    # PKGBUILD specific sourcing
    local pkgbuild_dir
    pkgbuild_dir=$(dirname "$_where/distros/arch/PKGBUILD")
    if [ -f "$pkgbuild_dir/TKT_CONFIG" ]; then
      # shellcheck source=/dev/null
      source "$pkgbuild_dir/TKT_CONFIG"
    fi
  fi

  # Restore exported overrides
  [ -n "$old_distro" ] && _distro="$old_distro"
  [ -n "$old_compiler" ] && _compiler="$old_compiler"
  [ -n "$old_cpusched" ] && _cpusched="$old_cpusched"
  [ -n "$old_timer_freq" ] && _timer_freq="$old_timer_freq"

  return 0
}

# TUI Helper: Generic whiptail menu wrapper
_tui_whiptail_menu() {
    local title="$1"
    local text="$2"
    local height="${3:-18}"
    local width="${4:-60}"
    local list_height="${5:-10}"
    shift 5

    # Use _TUI_DEFAULT_ITEM if set, then clear it to avoid accidental reuse
    local def_item_args=()
    if [ -n "$_TUI_DEFAULT_ITEM" ]; then
        def_item_args=(--default-item "$_TUI_DEFAULT_ITEM")
        unset _TUI_DEFAULT_ITEM
    fi

    whiptail --title "$title" "${def_item_args[@]}" --menu "$text" "$height" "$width" "$list_height" "$@" 3>&1 1>&2 2>&3
}

# TUI Helper: Generic whiptail checklist wrapper
_tui_whiptail_checklist() {
    local title="$1"
    local text="$2"
    local height="${3:-18}"
    local width="${4:-60}"
    local list_height="${5:-10}"
    shift 5
    whiptail --title "$title" --checklist "$text" "$height" "$width" "$list_height" "$@" 3>&1 1>&2 2>&3
}

# TUI Helper: Toggle variable value
_tui_toggle_var() {
    local var_name="$1"
    if [[ "${!var_name}" == "true" ]]; then
        eval "$var_name=false"
    else
        eval "$var_name=true"
    fi
}

_fetch_rt_maps() {
    local rt_base_url="https://cdn.kernel.org/pub/linux/kernel/projects/rt/"
    for kver in "${_current_kernels[@]}"; do
        local kver_regex="${kver//./\\.}"
        local rt_patches
        mapfile -t rt_patches < <(curl -s "$rt_base_url" | grep -oP "patch-${kver_regex}\\.\\d+-rt\\d+\\.patch\\.xz" | sort -V)
        if [ ${#rt_patches[@]} -eq 0 ]; then
            _rt_subver_map[$kver]="0"; _rt_rev_map[$kver]="0"
            continue
        fi
        local latest_patch="${rt_patches[-1]}"
        local subver
        subver=$(echo "$latest_patch" | grep -oP "${kver_regex}\\.\\d+")
        local rt_rev
        rt_rev=$(echo "$latest_patch" | grep -oP "rt\\d+" | cut -c3-)
        _rt_subver_map[$kver]=$(echo "$subver" | cut -d. -f3)
        _rt_rev_map[$kver]="$rt_rev"
    done
}

# Tag fetching logic (shared by TUI and prepare)
_fetch_kernel_tags() {
  local mirror="$1"
  [ -z "$mirror" ] && return 1

  git -c 'versionsort.suffix=-' \
    ls-remote --exit-code --refs --sort='version:refname' --tags "$mirror" '*.*' 2>/dev/null | \
    cut --delimiter='/' --fields=3 || return 1
}

_get_latest_tag_map() {
    local tags="$1"
    local kvers_name="$2"
    local -n kvers=$kvers_name

    for k in "${kvers[@]}"; do
        echo "$tags" | grep -F "v$k" | grep -v "v${k}[0-9]" | tail -1 | cut -c1-
    done
}

_prompt_from_array() {
  # Prompts from array, selects default index on empty user input
  # Set the _default_index variable to enable default index selection

  if [ $# = "0" ]; then
    warning "Prompting on an empty array, please report this issue."
    exit 1
  fi

  unset _selected_index

  local _N=$(($# - 1))
  local _index=0
  for _value in "$@"; do
    if [ "$_index" = "$_default_index" ]; then
      plain "  > ${_index}) ${_value}"
    else
      plain "    ${_index}) ${_value}"
    fi
    _index=$((_index + 1))
  done
  while true; do
    read -rp "[0-${_N}]: "
    if [[ -z "$REPLY" && -n "$_default_index" ]]; then
      _selected_index="$_default_index"
      break
    elif [[ "$REPLY" =~ ^[0-9]+$ && 0 -le "$REPLY" && "$REPLY" -le _N ]]; then
      _selected_index="$REPLY"
      break
    else
      echo "Wrong selection: select any number in 0-$_N"
    fi
  done

  local _natural_index=$((_selected_index + 1))
  _selected_value="${!_natural_index}"
  plain "Selected: ${_selected_value}"
}

_prompt_from_dict() {
  # Prompts from dict that it receives by name, selects default key on empty user input
  # Set the _default_key variable to enable default index selection

  if [ $# != "1" ]; then
    warning "Prompting on an empty dict, please report this issue."
    exit 1
  fi

  unset _selected_key

  declare -n _dict="$1"

  for _key in "${!_dict[@]}"; do
    if [ "$_key" = "$_default_key" ]; then
      plain "  > ${_key}: ${_dict[$_key]}"
    else
      plain "    ${_key}: ${_dict[$_key]}"
    fi
  done
  while true; do
    read -rp "Section: "
    if [[ -z "$REPLY" && -n "$_default_key" ]]; then
      _selected_key="$_default_key"
      break
    elif [[ -v _dict["$REPLY"] ]]; then
      _selected_key="$REPLY"
      break
    else
      echo "Selection not part of the possibilities, please re-try"
    fi
  done

  plain "Selected: ${_selected_key}"
}
