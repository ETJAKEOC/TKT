#!/bin/bash

# Slackware distribution

distro_install_dependencies() {
  sudo slackpkg update
  msg2 "Installing dependencies for $_distro"
  if [[ "$_compiler_name" == *llvm* ]]; then
    sudo slackpkg -batch=on -default_answer=y install ${_slack_common} ${_clang_deps} || true
  else
    sudo slackpkg -batch=on -default_answer=y install ${_slack_common} || true
  fi
}

distro_build_pkg() {
  _build_kernel_generic

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
  while read -r -d '' file; do
    case "$(file -bi "$file")" in
      application/x-sharedlib\;*)      # Libraries (.so)
        strip -v "${STRIP_SHARED}" "$file" ;;
      application/x-archive\;*)        # Libraries (.a)
        strip -v "${STRIP_STATIC}" "$file" ;;
      application/x-executable\;*)     # Binaries
        strip -v "${STRIP_BINARIES}" "$file" ;;
      application/x-pie-executable\;*) # Relocatable binaries
        strip -v "${STRIP_SHARED}" "$file" ;;
    esac
  done < <(find . -type f -perm -u+x ! -name vmlinux -print0)

  msg2 "Copying kernel files..."
  cp -a arch/x86/boot/bzImage "$PKGROOT/boot/vmlinuz-$_kernelname"
  cp -a System.map "$PKGROOT/boot/System.map-$_kernelname"
  cp -a .config "$PKGROOT/boot/config-$_kernelname"
  rsync -aHAX --delete-during "$_where"/linux-src-git/ "$headers_dest"

  msg2 "Installing modules..."
  if [ "$_STRIP" = "true" ]; then
    make INSTALL_MOD_PATH="$PKGROOT" INSTALL_MOD_STRIP=1 modules_install
  else
    make INSTALL_MOD_PATH="$PKGROOT" modules_install
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
}

distro_install_pkg() {
  # install.sh doesn't have an automatic install step for Slackware, it just prints the command
  msg2 "To install the created Slackware package, run:"
  msg2 "sudo installpkg $_where/$_kernelname/Slackware-kernel-$_kernelname-TKT-x86_64-1.txz"
}
