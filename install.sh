#!/bin/bash
set -e
_where=`pwd`
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

if [[ -z "$SCRIPT" ]]; then
  declare -p -x > current_env
fi

source customization.cfg

if [ -e "$_EXT_CONFIG_PATH" ]; then
  msg2 "External configuration file $_EXT_CONFIG_PATH will be used and will override customization.cfg values."
  source "$_EXT_CONFIG_PATH"
fi

. current_env
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
  _thread_num=`nproc`
else
  _thread_num=`expr \`nproc\` / 2`
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

_distro_prompt() {
  echo "Which linux distribution are you running ?"
  echo "if it's not on the list, chose the closest one to it: Fedora/Suse for RPM, Ubuntu/Debian for DEB"
  _prompt_from_array "Debian" "Fedora" "Gentoo" "Mint" "Slackware" "Suse" "Ubuntu" "Void" "Generic"
  _distro="${_selected_value}"
}

_install_dependencies() {
  _base_deps="bash bc bison ccache cmake cpio curl flex git kmod lz4 make patchutils perl python3 python3-pip rsync sudo tar time wget zstd"
  _clang_deps="clang lld llvm"
  _deb_common_clang="clang-format clang-tidy clang-tools"
  _deb_common="${_base_deps} binutils binutils-dev binutils-gold build-essential debhelper device-tree-compiler dpkg-dev dwarves fakeroot g++ g++-multilib gcc gcc-multilib gnupg libc6-dev libc6-dev-i386 libdw-dev libelf-dev libncurses-dev libnuma-dev libperl-dev libssl-dev libstdc++-14-dev libudev-dev ninja-build python3-setuptools qtbase5-dev schedtool xz-utils"
  _rpm_common="${_base_deps} dwarves gcc-c++ gawk hostname ncurses-devel libdw-devel libelf-devel libnuma-devel libopenssl-devel libudev-devel openssl openssl-devel python3-devel rpm-build rpmdevtools xz zstd"
  _fedora_common="${_rpm_common} elfutils-devel fedora-packager fedpkg pesign numactl-devel openssl-devel-engine perl-devel perl-generators qt5-qtbase-devel"
  _suse_common="${_rpm_common} awk kernel-source kernel-syms libqt5-qtbase-common-devel perl perl-ExtUtils-MakeMaker systemd-devel python311-devel python311-pip"
  _slack_common="${_base_deps} binutils brotli cyrus-sasl diffutils dwarves elfutils fakeroot fakeroot-ng file gc gcc gcc-g++ gcc-gcobol gcc-gdc gcc-gfortran gcc-gm2 gcc-gnat gcc-go gcc-objc gcc-rust glibc git guile gzip kernel-headers libedit libelf libxml2 lzop m4 ncurses nghttp2 nghttp3 openssl perl schedtool spirv-llvm-translator xxHash xz"
  _void_common="${_base_deps} base-devel docbook-xsl elfutils-devel fakeroot gcc gnupg graphviz liblz4-devel lz4 lzop m4 ncurses openssl-devel pahole patch pkg-config schedtool xtools xmlto xz"

  if [ "$_distro" = "Debian" ]; then
    sudo apt update
    msg2 "Installing dependencies for $_distro"
    if [[ "$_compiler_name" == *llvm* ]]; then
      sudo apt install -y ${_deb_common} ${_deb_common_clang} ${_clang_deps}
    else
      sudo apt install -y ${_deb_common}
    fi

  elif [ "$_distro" = "Ubuntu" ] || [ "$_distro" = "Mint" ]; then
    sudo apt update
    msg2 "Installing dependencies for $_distro"
    if [[ "$_compiler_name" == *llvm* ]]; then
      sudo apt install -y ${_deb_common} ${_deb_common_clang} ${_clang_deps} liblz4-dev libxxhash-dev software-properties-common
    else
      sudo apt install -y ${_deb_common} liblz4-dev libxxhash-dev software-properties-common
    fi

  elif [ "$_distro" = "Fedora" ]; then
    sudo dnf update -y
    msg2 "Installing dependencies for $_distro"
    if [[ "$_compiler_name" == *llvm* ]]; then
      sudo dnf install -y --skip-unavailable ${_fedora_common} ${_clang_deps}
    else
      sudo dnf install -y --skip-unavailable ${_fedora_common}
    fi

  elif [ "$_distro" = "Suse" ]; then
    sudo zypper refresh
    msg2 "Installing dependencies for $_distro"
    if [[ "$_compiler_name" == *llvm* ]]; then
      sudo zypper install -y ${_suse_common} ${_clang_deps}
    else
      sudo zypper install -y ${_suse_common}
    fi

  elif [ "$_distro" = "Void" ]; then
    msg2 "Installing dependencies for $_distro"
    if [[ "$_compiler_name" == *llvm* ]]; then
      sudo xbps-install -Sy ${_void_common} ${_clang_deps}
    else
      sudo xbps-install -Sy ${_void_common}
    fi

  elif [ "$_distro" = "Slackware" ]; then
    sudo slackpkg update
    msg2 "Installing dependencies for $_distro"
    if [[ "$_compiler_name" == *llvm* ]]; then
      sudo slackpkg -batch=on -default_answer=y install ${_slack_common} ${_clang_deps} || true
    else
      sudo slackpkg -batch=on -default_answer=y install ${_slack_common} || true
    fi
  fi
}

_gen_kern_name() {
  # Uppercase characters are not allowed in source package name for debian based distros
  if [[ "$_distro" =~ ^(Debian|Mint|Ubuntu)$ && "$_cpusched" = "MuQSS" ]]; then
    _cpusched="muqss"
  fi

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
    time make ${llvm_opt} -j ${_thread_num} "$@"
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
      read -p "Do you want to install the new Kernel ? Y/[n]: " _install
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
        sudo dracut --force --hostonly ${_dracut_options} --kver "$_kernelname_rpm"
      else
        echo "Running 'dracut' to generate the 'initramfs' file for $_distro..."
        sudo dracut --force --hostonly ${_dracut_options} --kver "$_kernelname"
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
    sudo ${_grub_cfg_cmd}
  fi
  }

if [ "$1" != "install" ] && [ "$1" != "config" ] && [ "$1" != "uninstall-help" ]; then
  msg2 "Argument not recognised, options are:
        - config : interactive script that shallow clones the linux kernel git tree into the folder \$_kernel_work_folder, then applies extra patches and prepares the .config file
                   by copying the one from the currently running linux system and updates it.
        - install : does the config step, proceeds to compile, then prompts to install
                    - 'DEB' distros: it creates .deb packages that will be installed then stored in a folder.
                    - 'RPM' distros: it creates .rpm packages that will be installed then stored in a folder.
                    - 'Generic' distro: it uses 'make modules_install' and 'make install', uses 'dracut' to create an initramfs, then updates grub's boot entry.
        - uninstall-help : [RPM and DEB based distros only], lists the installed kernels in this system, then gives hints on how to uninstall them manually."
  exit 0
fi

if [ "$1" = "install" ] || [ "$1" = "config" ]; then
  _tkg_initscript
  if [[ -z "$_distro" || ! "$_distro" =~ ^(Ubuntu|Debian|Fedora|Mint|Suse|Gentoo|Slackware|Void|Generic)$ ]]; then
    msg2 "Variable \"_distro\" in \"customization.cfg\" is invalid or empty. Prompting..."
    _distro_prompt
    msg2 "Configuration done."
  fi
fi

if [ "$1" = "install" ]; then
  _install_dependencies

  if [[ "${_compiler}" = "llvm" && "${_distro}" =~ ^(Generic|Gentoo)$ && "${_libunwind_replace}" = "true" ]]; then
      export LDFLAGS_MODULE="-unwindlib=libunwind"
      export HOSTLDFLAGS="-unwindlib=libunwind"
  fi

  _tkg_srcprep
  cd "$_kernel_work_folder_abs" || { echo "Source dir missing"; exit 1; }

  # Begin distro logic
  if [[ "$_distro" =~ ^(Debian|Mint|Ubuntu)$ ]]; then
    msg2 "Building kernel DEB packages"
    _gen_kern_name
    _make bindeb-pkg LOCALVERSION=-${_kernel_flavor} KDEB_PKGVERSION=1
    msg2 "Build done"
    _move_artifacts "deb"
    _winesync_copy

    if _confirm_install; then
      sudo dpkg -i "$_where/${_kernelname}"/*.deb
    fi

  elif [[ "$_distro" =~ ^(Fedora|Suse)$ ]]; then
    _gen_kern_name

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

  elif [[ "$_distro" == "Slackware" ]]; then
    _gen_kern_name
    ./scripts/config --set-str LOCALVERSION "-${_kernel_flavor}"
    msg2 "Building kernel"
    _make || { echo "Kernel build failed"; exit 1; }
    msg2 "Build successful"
    _winesync_copy

    if [ "$_STRIP" = "true" ]; then
      echo "Stripping vmlinux..."
      strip -v $STRIP_STATIC "vmlinux" || echo "strip failed"
    fi

    PKGROOT="$_where/${_kernelname}"

    msg2 "Preparing packaging directories..."
    mkdir -p "$PKGROOT/boot"
    mkdir -p "$PKGROOT/lib/modules"
    mkdir -p "$PKGROOT/install"
    headers_dest="$PKGROOT/usr/src/linux-$_kernelname"
    mkdir -p "$headers_dest/arch/x86"

    msg2 "Removing unneeded architectures..."
    for arch in arch/*/; do
      [[ $arch = */x86/ ]] && continue
      echo "Removing $(basename "$arch")"
      rm -r "$arch"
    done

    msg2 "Removing broken symlinks..."
    find -L . -type l -printf 'Removing %P\n' -delete

    msg2 "Removing loose objects..."
    find . -type f -name '*.o' -printf 'Removing %P\n' -delete

    msg2 "Stripping build tools..."
    while read -rd '' file; do
      case "$(file -bi "$file")" in
        application/x-sharedlib\;*)      # Libraries (.so)
          strip -v $STRIP_SHARED "$file" ;;
        application/x-archive\;*)        # Libraries (.a)
          strip -v $STRIP_STATIC "$file" ;;
        application/x-executable\;*)     # Binaries
          strip -v $STRIP_BINARIES "$file" ;;
        application/x-pie-executable\;*) # Relocatable binaries
          strip -v $STRIP_SHARED "$file" ;;
      esac
    done < <(find . -type f -perm -u+x ! -name vmlinux -print0)

    msg2 "Copying kernel files..."
    cp -a arch/x86/boot/bzImage "$PKGROOT/boot/vmlinuz-$_kernelname"
    cp -a System.map "$PKGROOT/boot/System.map-$_kernelname"
    cp -a .config "$PKGROOT/boot/config-$_kernelname"
    rsync -aHAX --delete-during $_where/linux-src-git/ "$headers_dest"

    msg2 "Installing modules..."
    if [ "$_STRIP" = "true" ]; then
      _make INSTALL_MOD_PATH="$PKGROOT" INSTALL_MOD_STRIP=1 modules_install
    else
      _make INSTALL_MOD_PATH="$PKGROOT" modules_install
    fi

    # Fix up module metadata (some tools depend on this)
    msg2 "Running depmod on packaged modules..."
    sudo depmod -b "$PKGROOT" "$_kernelname"

    msg2 "Installing headers..."
    cp -a include "$headers_dest/"
    cp -a arch/x86/include "$headers_dest/arch/x86/"
    cp Makefile Kconfig .config "$headers_dest/"
    cp -a scripts "$headers_dest/"

    # Symlink for dkms/build expectations
    ln -sf "/usr/src/linux-$_kernelname" "$PKGROOT/lib/modules/$_kernelname/build"
    ln -sf "/usr/src/linux-$_kernelname" "$PKGROOT/lib/modules/$_kernelname/source"

    # Cleanup headers junk files
    find "$headers_dest" -type f \( \
      -name '*.o' -o \
      -name '*.a' -o \
      -name '*.ko' -o \
      -name '*.cmd' -o \
      -name '*.mod.c' -o \
      -name '*.tmp' -o \
      -name '.*.cmd' -o \
      -name '*.order' -o \
      -name '*.symvers' -o \
      -name '*.mod' -o \
      -name 'vmlinux*' \) -delete

    rm -rf "$headers_dest"/{.git,.tmp_versions,modules.order,Module.symvers,build,source}

    msg2 "Creating slack-desc..."
    cat <<EOF > "$PKGROOT/install/slack-desc"
kernel-${_kernel_flavor}: Slackware TKT Kernel
kernel-${_kernel_flavor}: This is a generic kernel built from kernel.org sources.
kernel-${_kernel_flavor}: Packaged by TKT kernel toolkit.
EOF

    # Detect root device
    _rootdev=$(findmnt -n -o SOURCE /)

    msg2 "Creating doinst.sh..."
    cat <<EOF > "$PKGROOT/install/doinst.sh"
#!/bin/sh

# Auto-generate initrd
KERNEL_VERSION="$_kernelname"
MKINITRD_CONF="/etc/mkinitrd.conf"
INITRD="/boot/initrd-\$KERNEL_VERSION.gz"

if [ -f "\$MKINITRD_CONF" ]; then
  echo "Generating initrd..."
  mkinitrd -F -k \$KERNEL_VERSION -c \$MKINITRD_CONF -o \$INITRD
else
  echo "Generating default initrd..."
  mkinitrd -c -k \$KERNEL_VERSION -m ext4 -o \$INITRD
fi

# Add lilo entry if using lilo
if [ -x /sbin/lilo ]; then
  if grep -q "vmlinuz-\$KERNEL_VERSION" /etc/lilo.conf; then
    echo "lilo.conf already contains vmlinuz-\$KERNEL_VERSION"
  else
    echo "Appending new entry to /etc/lilo.conf..."
    cat <<LILOBLOCK >> /etc/lilo.conf

image = /boot/vmlinuz-\$KERNEL_VERSION
  initrd = /boot/initrd-\$KERNEL_VERSION.gz
  root = ${_rootdev}
  label = ${_kernel_flavor}
  read-only

LILOBLOCK
  fi

  echo "Running lilo..."
  lilo
fi
EOF

    sudo chmod 755 "$PKGROOT/install/doinst.sh"

    msg2 "Packaging .txz archive..."
    cd "$PKGROOT" || exit 1
    find . -type d -exec sudo chmod 755 {} +
    find . -type f -exec sudo chmod 644 {} +
    sudo chmod 755 ./boot/vmlinuz-$_kernelname
    tar --numeric-owner -cf - boot lib usr install | xz -9e > "Slackware-kernel-$_kernelname-TKT-x86_64-1.txz"

    msg2 "Slackware package created."

  elif [[ "$_distro" == "Void" ]]; then
    _gen_kern_name
    ./scripts/config --set-str LOCALVERSION "-${_kernel_flavor}"

    msg2 "Building kernel for ${_distro}..."
    _make || { echo "Kernel build failed"; exit 1; }
    msg2 "Build successful"
    _winesync_copy

    if [ "$_STRIP" = "true" ]; then
      echo "Stripping vmlinux..."
      strip -v $STRIP_STATIC "vmlinux" || echo "strip failed"
    fi

    _pkgname="kernel-${_kernel_flavor}"
    _pkgver="${_basekernel}.${_sub}"
    _pkgrev="1"
    _pkgfullver="${_pkgname}-${_pkgver}_${_pkgrev}"

    PKGROOT="$_where/${_kernelname}"
    rm -rf "$PKGROOT"
    msg2 "Preparing packaging directory: $PKGROOT"

    mkdir -p "$PKGROOT/boot"
    mkdir -p "$PKGROOT/usr/lib/modules/${_kernelname}"
    headers_dest="$PKGROOT/usr/src/linux-$_kernelname"
    mkdir -p "$headers_dest"

    msg2 "Installing modules into package root..."
    if [ "$_STRIP" = "true" ]; then
      _make INSTALL_MOD_PATH="$PKGROOT/usr" INSTALL_MOD_STRIP=1 modules_install
    else
      _make INSTALL_MOD_PATH="$PKGROOT/usr" modules_install
    fi

    msg2 "Copying kernel and config files..."
    cp -a "arch/x86/boot/bzImage" "$PKGROOT/boot/vmlinuz-$_kernelname"
    cp -a "System.map" "$PKGROOT/boot/System.map-$_kernelname"
    cp -a ".config" "$PKGROOT/boot/config-$_kernelname"

    msg2 "Installing headers into package root..."
    rsync -a --delete-during . "$headers_dest" --exclude='.*' \
  --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
  --exclude='vmlinux' --exclude='Module.symvers' --exclude='*.mod.c'

    cd "$PKGROOT/usr/lib/modules"
    rm -f "$_kernelname/build" "$_kernelname/source"
    ln -sf "../../src/linux-$_kernelname" "$_kernelname/build"
    ln -sf "../../src/linux-$_kernelname" "$_kernelname/source"

    cat <<EOF > "$PKGROOT/install-script.sh"
#!/bin/sh
# Post-install script for $_pkgname

depmod $_kernelname

echo "Running xbps-reconfigure to update bootloader..."
xbps-reconfigure -f ${_pkgfullver}

exit 0
EOF
  chmod 755 "$PKGROOT/install-script.sh"

  cat <<EOF > "$PKGROOT/remove-script.sh"
#!/bin/sh
# Pre-remove script for $_pkgname

echo "Removing old kernel and boot files..."
rm -f /boot/vmlinuz-$_kernelname
rm -f /boot/System.map-$_kernelname
rm -f /boot/config-$_kernelname

echo "Running xbps-reconfigure to update bootloader..."
xbps-reconfigure -f ${_pkgfullver}

exit 0
EOF
    chmod 755 "$PKGROOT/remove-script.sh"

    msg2 "Creating XBPS package..."

    cd "$PKGROOT" || exit 1

    xbps-create -A x86_64 \
                -n "${_pkgfullver}" \
                -s "TKT Linux ${_kernelname}" \
                -m "The Kernel Toolkit" \
                -l "GPL-2.0-only" \
                .

    msg2 "Void Linux package created: $_where/${_kernel_flavor}/${_pkgfullver}.x86_64.xbps"

    rm -rf "$PKGROOT/boot" "$PKGROOT/usr" "$PKGROOT/install-script.sh" "$PKGROOT/remove-script.sh"

    local_repo_dir="$(realpath "$_where/${_kernelname}")"

    if _confirm_install; then
      msg2 "Updating local repo index..."
      xbps-rindex -d -a "$local_repo_dir"/*.xbps || { echo "Failed to update repo index"; exit 1; }

      msg2 "Installing package..."
      sudo xbps-install -y --repository="$local_repo_dir" "${_pkgfullver}" || { echo "Package install   failed"; exit 1; }

      sudo depmod "$_kernelname" || { echo "depmod failed"; exit 1; }
      sudo xbps-reconfigure -f ${_pkgfullver} || { echo "xbps-reconfigure failed"; exit 1; }
    fi

  elif [[ "$_distro" =~ ^(Gentoo|Generic)$ ]]; then
    _gen_kern_name
    ./scripts/config --set-str LOCALVERSION "-${_kernel_flavor}"
    msg2 "Building kernel"
    _make LOCALVERSION "-${_kernel_flavor}"
    msg2 "Build successful"

    if [ "$_STRIP" = "true" ]; then
      echo "Stripping vmlinux..."
      strip -v $STRIP_STATIC "vmlinux"
    fi

    _headers_folder_name="linux-$_kernel_flavor"

    echo -e "\n\n"

    msg2 "The installation process will run the following commands:"
    echo "    # copy the patched and compiled sources to /usr/src/$_headers_folder_name"
    echo "    sudo make modules_install"
    echo "    sudo make install"
    echo "    sudo dracut --force --hostonly ${_dracut_options} --kver $_kernel_flavor"
    echo "    sudo grub-mkconfig -o /boot/grub/grub.cfg"

    msg2 "Note: Uninstalling requires manual intervention, use './install.sh uninstall-help' for more information."
    read -p "Continue ? Y/[n]: " _continue

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
    cd "/usr/src/$_headers_folder_name"

    msg2 "Installing modules"
    if [ "$_STRIP" = "true" ]; then
      sudo make modules_install INSTALL_MOD_STRIP="1"
    else
      sudo make modules_install
    fi
    msg2 "Removing modules from source folder in /usr/src/${_kernel_src_gentoo}"
    sudo find . -type f -name '*.ko' -delete
    sudo find . -type f -name '*.ko.cmd' -delete

    msg2 "Installing kernel"
    sudo make install
    _regen_boot

    if [ "$_distro" = "Gentoo" ]; then

      msg2 "Selecting the kernel source code as default source folder"
      sudo ln -sfn "/usr/src/$_headers_folder_name" "/usr/src/linux"

      msg2 "Rebuild kernel modules with \"emerge @module-rebuild\" ?"
      if [ "$_compiler" = "llvm" ];then
        warning "Building modules with LLVM/Clang is mostly unsupported OOTB by \"emerge @module-rebuild\" except for Nvidia 465.31+"
        warning "     Manually setting \"CC=clang\" for some modules may work if you haven't used LTO"
      fi

      read -p "Y/[n]: " _continue
      if [[ "$_continue" =~ ^(Y|y|Yes|yes)$ ]];then
        sudo emerge @module-rebuild --keep-going
      fi
    fi

  fi
fi

if [ "$1" = "uninstall-help" ]; then

  if [ -z $_distro ]; then
    _distro_prompt
  fi

  cd "$_where"

  if [[ "$_distro" =~ ^(Debian|Mint|Ubuntu)$ ]]; then
    msg2 "List of installed custom TKT kernels: "
    dpkg -l "*" | grep "linux.*"
    dpkg -l "*linux-libc-dev*" | grep "linux.*"
    msg2 "To uninstall a version, you should remove the linux-image, linux-headers and linux-libc-dev associated to it (if installed), with: "
    msg2 "      sudo apt remove linux-image-VERSION linux-headers-VERSION linux-libc-dev-VERSION"
    msg2 "       where VERSION is displayed in the lists above, uninstall only versions that have \"tkg\" in its name"
    msg2 "Note: linux-libc-dev packages are no longer created and installed, you can safely remove any remnants."
  elif [ "$_distro" = "Fedora" ]; then
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
  elif [[ "$_distro" =~ ^(Generic|Gentoo)$ ]]; then
    msg2 "Folders in /lib/modules :"
    ls /lib/modules
    msg2 "Files in /boot :"
    ls /boot
    msg2 "To uninstall a kernel version installed through install.sh with 'Generic' as a distro:"
    msg2 "  - Remove manually the corresponding folder in '/lib/modules'"
    msg2 "  - Remove manually the corresponding 'System.map', 'vmlinuz', 'config' and 'initramfs' in the folder :/boot"
    msg2 "  - Update the boot menu. e.g. 'sudo grub-mkconfig -o /boot/grub/grub.cfg'"
  fi

fi
