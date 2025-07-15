# Based on the file created for Arch Linux by:
# Tobias Powalowski <tpowa@archlinux.org>
# Thomas Baechler <thomas@archlinux.org>

# Original Contributor: Tk-Glitch <ti3nou at gmail dot com>
# Original Contributor: Hyper-KVM <hyperkvmx86 at gmail dot com>

# All credits due to the previous pioneers of this script whom came before me. Thank you for your effort.
# Hijacked by: ETJAKEOC <etjakeoc@gmail.com>

pkgdesc='A customized Linux kernel install script, forked from the TKG script, aimed at a more performant tune, at the risk of stability.'
arch=('x86_64') # no i686 in here
url="https://www.kernel.org/"
license=('GPL2')
makedepends=(base-devel bc bison clang coreutils cpio docbook-xsl flex gcc git \
graphviz imagemagick inetutils  initramfs kmod libelf lld llvm pahole \
patchutils perl python-sphinx python-sphinx_rtd_theme schedtool sudo \
tar wget xmlto xz)
if [[ "$_compiler_name" =~ llvm ]]; then
  makedepends+=(llvm clang lld)
elif [[ "$_compiler_name" =~ gcc ]]; then
  makedepends+=(gcc)
fi
optdepends=('schedtool')
options=('!strip')

 # track basedir as different Arch based distros are moving srcdir around
_where="$PWD"

# Create logs dir if it does not already exist.
[ -d "$_where/logs" ] || mkdir -p "$_where/logs"

# Clear TKT_CONFIG and save all settings in it fresh again
if [ ! -e "$_where"/TKT_CONFIG ]; then

  cp "$_where"/customization.cfg "$_where"/TKT_CONFIG

  # extract and define value of _EXT_CONFIG_PATH from customization file
  if [[ -z "$_EXT_CONFIG_PATH" ]]; then
    eval `grep _EXT_CONFIG_PATH "$_where"/customization.cfg`
  fi

  if [ -f "$_EXT_CONFIG_PATH" ]; then
    msg2 "External configuration file $_EXT_CONFIG_PATH will be used and will override customization.cfg values."
    cat "$_EXT_CONFIG_PATH" >> "$_where"/TKT_CONFIG
  fi

  declare -p -x >> "$_where"/TKT_CONFIG

  echo -e "_ispkgbuild=\"true\"\n_distro=\"Arch\"\n_where=\"$PWD\"" >> "$_where"/TKT_CONFIG

  source "$_where"/TKT_CONFIG
  source "$_where"/kconfigs/prepare

  _tkg_initscript
fi

source "$_where"/TKT_CONFIG

if [ -n "$_custom_pkgbase" ]; then
  pkgbase="${_custom_pkgbase}"
else
  pkgbase=linux"${_basever}"-tkt-"${_cpusched}"${_compiler_name}
fi
pkgname=("${pkgbase}" "${pkgbase}-headers")
pkgver="${_basekernel}"."${_sub}"
pkgrel=1

for f in "$_where"/kconfigs/"$_basekernel"/* "$_where"/kpatches/"$_basekernel"/*; do
  source+=( "$f" )
  sha256sums+=( "SKIP" )
done

export KBUILD_BUILD_HOST=archlinux
export KBUILD_BUILD_USER=$pkgbase
export KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

prepare() {
  source "$_where"/TKT_CONFIG
  source "$_where"/kconfigs/prepare
  rm -rf $pkgdir # Nuke the entire pkg folder so it'll get regenerated clean on next build
  ln -s "${_kernel_work_folder_abs}" "${srcdir}/linux-src-git"
  _tkg_srcprep
}

build() {
  source "$_where"/TKT_CONFIG

  cd "$_kernel_work_folder_abs"

  # Use custom compiler paths if defined
  if [[ "$_compiler_name" =~ llvm ]] && [ -n "${CUSTOM_LLVM_PATH}" ]; then
    PATH="${CUSTOM_LLVM_PATH}/bin:${CUSTOM_LLVM_PATH}/lib:${CUSTOM_LLVM_PATH}/include:${PATH}"
  elif [ -n "${CUSTOM_GCC_PATH}" ]; then
    PATH="${CUSTOM_GCC_PATH}/bin:${CUSTOM_GCC_PATH}/lib:${CUSTOM_GCC_PATH}/include:${PATH}"
  fi

  if [ "$_force_all_threads" = "true" ]; then
    _force_all_threads="-j$((`nproc`))"
  else
    _force_all_threads="${MAKEFLAGS}"
  fi

  # ccache
  if [ "$_noccache" != "true" ] && pacman -Qq ccache &> /dev/null; then
    export PATH="/usr/lib/ccache/bin/:$PATH"
    export CCACHE_SLOPPINESS="file_macro,locale,time_macros"
    export CCACHE_NOHASHDIR="true"
    msg2 'ccache was found and will be used'
  fi

  # document the tkt variables, excluding "_", "_EXT_CONFIG_PATH", "_where", and "_path".
  declare -p | cut -d ' ' -f 3 | grep -P '^_(?!=|EXT_CONFIG_PATH|where|path)' > "${srcdir}/customization-full.cfg"

  # remove -O2 flag and place user optimization flag
  CFLAGS=${CFLAGS/-O2/}
  CFLAGS+=" ${_compileropt}"

  # build!
  if pacman -Qq schedtool &> /dev/null; then
    msg2 "Using schedtool"
    _schedtool="command schedtool -B -n 1"
    _ionice="command ionice -n 1"
  fi
  _runtime=$(
    if [ -n "$_schedtool" ]; then
      _pid="$(exec bash -c 'echo "$PPID"')"
      $_schedtool "$_pid" ||:
      $_ionice -p "$_pid" ||:
    fi

    export KCPPFLAGS
    export KCFLAGS

  # Setup "llvm_opts" if compiling using clang
  if [[ "$_compiler_name" =~ llvm ]]; then
    time (CC=clang CPP=clang-cpp CXX=clang++ LD=ld.lld RANLIB=llvm-ranlib STRIP=llvm-strip AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump LLVM=1 LLVM_IAS=1 \
    make ${_force_all_threads} ${llvm_opt} bzImage modules 2>&1 ) 3>&1 1>&2 2>&3
  elif [[ "$_compiler_name" =~ gcc ]]; then
    time (CC=gcc CXX=g++ LD=ld.bfd HOSTCC=gcc HOSTLD=ld.bfd AR=ar NM=nm OBJCOPY=objcopy OBJDUMP=objdump READELF=readelf RANLIB=ranlib STRIP=strip \
    make ${_force_all_threads} bzImage modules 2>&1 ) 3>&1 1>&2 2>&3
  fi
    return 0
  )
}

hackbase() {
  source "$_where"/TKT_CONFIG

  pkgdesc="The $pkgdesc kernel and modules"
  depends=('coreutils' 'kmod' 'initramfs')
  optdepends=('linux-docs: Kernel hackers manual - HTML documentation that comes with the Linux kernel.'
              'crda: to set the correct wireless channels of your country.'
              'linux-firmware: Firmware files for Linux'
              'modprobed-db: Keeps track of EVERY kernel module that has ever been probed. Useful for make localmodconfig.'
              'nvidia-tkg: NVIDIA drivers for all installed kernels - non-dkms version. From TK-Glitch.'
              'nvidia-dkms-tkg: NVIDIA drivers for all installed kernels - dkms version. From TK-Glitch.'
              'update-grub: Simple wrapper around grub-mkconfig.')
  if [ -e "${srcdir}/ntsync.rules" ]; then
    provides=("linux=${pkgver}" "${pkgbase}" VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE NTSYNC-MODULE ntsync-header)
  else
    provides=("linux=${pkgver}" "${pkgbase}" VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE)
  fi
  replaces=(virtualbox-guest-modules-arch wireguard-arch)

  cd "$_kernel_work_folder_abs"

  # get kernel version
  local _kernver="$(<version)"
  local modulesdir="$pkgdir/usr/lib/modules/$_kernver"

  msg2 "Installing boot image..."
  # systemd expects to find the kernel here to allow hibernation
  # https://github.com/systemd/systemd/commit/edda44605f06a41fb86b7ab8128dcf99161d2344
  install -Dm644 "$(make ${llvm_opt} -s image_name)" "$modulesdir/vmlinuz"

  # Used by mkinitcpio to name the kernel
  echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

  msg2 "Installing modules..."

  local _STRIP_MODS=""
  [[ "$_STRIP" == "true" ]] && _STRIP_MODS="INSTALL_MOD_STRIP=1"

  ZSTD_CLEVEL=19 make INSTALL_MOD_PATH="$pkgdir/usr" $_STRIP_MODS \
    DEPMOD=/doesnt/exist modules_install  # Suppress depmod

  # remove build and source links
  rm -f "$modulesdir"/{source,build}

  # install cleanup pacman hook and script
  sed -e "s|cleanup|${pkgbase}-cleanup|g" "${srcdir}"/90-cleanup.hook |
    install -Dm644 /dev/stdin "${pkgdir}/usr/share/libalpm/hooks/90-${pkgbase}.hook"
  install -Dm755 "${srcdir}"/cleanup "${pkgdir}/usr/share/libalpm/scripts/${pkgbase}-cleanup"

  # install customization file, for reference
  install -Dm644 "${srcdir}"/customization-full.cfg "${pkgdir}/usr/share/doc/${pkgbase}/customization.cfg"

  # ntsync
  if [ -e "${srcdir}/ntsync.conf" ]; then
    # workaround for missing header on <6.14 with ntsync
    if [ $_basever -lt 614 ]; then
      if [ -e "${_kernel_work_folder_abs}/include/uapi/linux/ntsync.h" ] && [ ! -e "/usr/include/linux/ntsync.h" ]; then
        msg2 "Workaround missing ntsync header"
        install -Dm644 "${_kernel_work_folder_abs}"/include/uapi/linux/ntsync.h "${pkgdir}/usr/include/linux/ntsync.h"
      fi
    fi
    # load ntsync module at boot
    msg2 "Set the ntsync module to be loaded at boot through /etc/modules-load.d"
    install -Dm644 "${srcdir}"/ntsync.conf "${pkgdir}/etc/modules-load.d/ntsync-${pkgbase}.conf"
  fi

  # install udev rule for ntsync if needed (<6.14)
  if [ -e "${srcdir}/ntsync.rules" ]; then
    msg2 "Installing udev rule for ntsync"
    install -Dm644 "${srcdir}"/ntsync.rules "${pkgdir}/etc/udev/rules.d/ntsync.rules"
  fi
}

hackheaders() {
  source "$_where"/TKT_CONFIG

  pkgdesc="Headers and scripts for building modules for the $pkgdesc kernel"
  provides=("linux-headers=${pkgver}" "${pkgbase}-headers=${pkgver}")
  case $_basever in
    54|57|58|59|510)
    ;;
    *)
      depends=('pahole')
    ;;
  esac

  cd "$_kernel_work_folder_abs"

  local builddir="${pkgdir}/usr/lib/modules/$(<version)/build"

  msg2 "Installing build files..."
  install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map \
    localversion.* version vmlinux
  install -Dt "$builddir/kernel" -m644 kernel/Makefile
  install -Dt "$builddir/arch/x86" -m644 arch/x86/Makefile
  cp -t "$builddir" -a scripts

  # add objtool for external module building and enabled VALIDATION_STACK option
  install -Dt "$builddir/tools/objtool" tools/objtool/objtool

  # add xfs and shmem for aufs building
  mkdir -p "$builddir"/{fs/xfs,mm}

  # add resolve_btfids on 5.16+
  if [[ $_basever = 6* ]] || [ $_basever -ge 516 ]; then
    install -Dt "$builddir"/tools/bpf/resolve_btfids tools/bpf/resolve_btfids/resolve_btfids || ( warning "$builddir/tools/bpf/resolve_btfids was not found. This is undesirable and might break dkms modules !!! Please review your config changes and consider using the provided defconfig and tweaks without further modification." && read -rp "Press enter to continue anyway" )
  fi

  msg2 "Installing headers..."
  cp -t "$builddir" -a include
  cp -t "$builddir/arch/x86" -a arch/x86/include
  install -Dt "$builddir/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s

  install -Dt "$builddir/drivers/md" -m644 drivers/md/*.h
  install -Dt "$builddir/net/mac80211" -m644 net/mac80211/*.h

  # http://bugs.archlinux.org/task/13146
  install -Dt "$builddir/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h

  # http://bugs.archlinux.org/task/20402
  install -Dt "$builddir/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
  install -Dt "$builddir/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
  install -Dt "$builddir/drivers/media/tuners" -m644 drivers/media/tuners/*.h

  msg2 "Installing KConfig files..."
  find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" \;

  msg2 "Removing unneeded architectures..."
  local arch
  for arch in "$builddir"/arch/*/; do
    [[ $arch = */x86/ ]] && continue
    echo "Removing $(basename "$arch")"
    rm -r "$arch"
  done

  msg2 "Removing documentation..."
  rm -r "$builddir/Documentation"

  msg2 "Removing broken symlinks..."
  find -L "$builddir" -type l -printf 'Removing %P\n' -delete

  msg2 "Removing loose objects..."
  find "$builddir" -type f -name '*.o' -printf 'Removing %P\n' -delete

  msg2 "Stripping build tools..."
  local file
  while read -rd '' file; do
    if [[ "$_compiler_name" =~ llvm ]]; then
      case "$(file -Sib "$file")" in
        application/x-sharedlib\;*)      # Libraries (.so)
          strip --strip-all-gnu $STRIP_SHARED "$file" ;;
        application/x-archive\;*)        # Libraries (.a)
          strip --strip-all-gnu $STRIP_STATIC "$file" ;;
        application/x-executable\;*)     # Binaries
          strip --strip-all-gnu $STRIP_BINARIES "$file" ;;
        application/x-pie-executable\;*) # Relocatable binaries
          strip --strip-all-gnu $STRIP_SHARED "$file" ;;
      esac
    elif [[ "$_compiler_name" =~ gcc ]]; then
      case "$(file -Sib "$file")" in
        application/x-sharedlib\;*)      # Libraries (.so)
          strip --strip-all $STRIP_SHARED "$file" ;;
        application/x-archive\;*)        # Libraries (.a)
          strip --strip-all $STRIP_STATIC "$file" ;;
        application/x-executable\;*)     # Binaries
          strip --strip-all $STRIP_BINARIES "$file" ;;
        application/x-pie-executable\;*) # Relocatable binaries
          strip --strip-all $STRIP_SHARED "$file" ;;
      esac
    fi
  done < <(find "$builddir" -type f -perm -u+x ! -name vmlinux -print0)

  msg2 "Adding symlink..."
  mkdir -p "$pkgdir/usr/src"
  ln -sr "$builddir" "$pkgdir/usr/src/$pkgbase"

  if [ "$_STRIP" = "true" ]; then
    if [[ "$_compiler_name" =~ llvm ]]; then
      echo "Stripping vmlinux..."
      strip --strip-all-gnu $STRIP_STATIC "$builddir/vmlinux"
    elif [[ "$_compiler_name" =~ gcc ]]; then
      echo "Stripping vmlinux..."
      strip --strip-all $STRIP_STATIC "$builddir/vmlinux"
    fi
  fi

  if [ "$_NUKR" = "true" ]; then
    rm -rf "$srcdir" # Nuke the entire src folder so it'll get regenerated clean on next build
  fi
}

source /dev/stdin <<EOF
package_${pkgbase}() {
hackbase
}

package_${pkgbase}-headers() {
hackheaders
}
EOF
