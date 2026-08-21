#!/bin/bash

# Void Linux distribution

distro_install_dependencies() {
  msg2 "Installing dependencies for $_distro"
  if [[ "$_compiler_name" == *llvm* ]]; then
    sudo xbps-install -Sy "${_void_common}" "${_clang_deps}"
  else
    sudo xbps-install -Sy "${_void_common}"
  fi
}

distro_build_pkg() {
  _gen_kern_name
  ./scripts/config --set-str LOCALVERSION "-${_kernel_flavor}"

  msg2 "Building kernel for ${_distro}..."
  _make bzImage modules || { echo "Kernel build failed"; exit 1; }
  msg2 "Build successful"
  _winesync_copy

  if [ "$_STRIP" = "true" ]; then
    if [[ "$_compiler_name" =~ llvm ]]; then
      echo "Stripping vmlinux..."
      llvm-strip --strip-all-gnu "${STRIP_STATIC}" "$_where/linux-src-git/vmlinux"
    elif [[ "$_compiler_name" =~ gcc ]]; then
      echo "Stripping vmlinux..."
      strip --strip-all "${STRIP_STATIC}" "$_where/linux-src-git/vmlinux"
    fi
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
    make INSTALL_MOD_PATH="$PKGROOT/usr" INSTALL_MOD_STRIP=1 modules_install
  else
    make INSTALL_MOD_PATH="$PKGROOT/usr" modules_install
  fi

  msg2 "Copying kernel and config files..."
  cp -a "arch/x86/boot/bzImage" "$PKGROOT/boot/vmlinuz-$_kernelname"
  cp -a "System.map" "$PKGROOT/boot/System.map-$_kernelname"
  cp -a ".config" "$PKGROOT/boot/config-$_kernelname"

  msg2 "Installing headers into package root..."
  rsync -a --delete-during . "$headers_dest" --exclude='.*' \
--exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
--exclude='vmlinux' --exclude='Module.symvers' --exclude='*.mod.c'

  cd "$PKGROOT/usr/lib/modules" || exit 1
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
  rm -rf "${PKGROOT:?}/boot" "${PKGROOT:?}/usr" "$PKGROOT/install-script.sh" "$PKGROOT/remove-script.sh"
}

distro_install_pkg() {
  local_repo_dir="$(realpath "$_where/${_kernelname}")"
  _pkgname="kernel-${_kernel_flavor}"
  _pkgver="${_basekernel}.${_sub}"
  _pkgrev="1"
  _pkgfullver="${_pkgname}-${_pkgver}_${_pkgrev}"

  if _confirm_install; then
    msg2 "Updating local repo index..."
    xbps-rindex -d -a "$local_repo_dir"/*.xbps || { echo "Failed to update repo index"; exit 1; }

    msg2 "Installing package..."
    sudo xbps-install -y --repository="$local_repo_dir" "${_pkgfullver}" || { echo "Package install failed"; exit 1; }

    sudo depmod "$_kernelname" || { echo "depmod failed"; exit 1; }
    sudo xbps-reconfigure -f "${_pkgfullver}" || { echo "xbps-reconfigure failed"; exit 1; }
  fi
}
