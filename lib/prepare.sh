#!/bin/bash

# TKT Preparation Library - Refactored for simplicity and modularity

_undefine() {
  for _config_name in "$@"; do
    ./scripts/config -k --undefine "${_config_name}"
  done
}

_enable() {
  for _config_name in "$@"; do
    ./scripts/config -k --enable "${_config_name}"
  done
}

_disable() {
  for _config_name in "$@"; do
    ./scripts/config -k --disable "${_config_name}"
  done
}

_module() {
  for _config_name in "$@"; do
    ./scripts/config -k --module "${_config_name}"
  done
}

_set_kver_internal_vars() {
  # Sets _basever, _basekernel and _sub global variables by reading Makefile at the root of the kernel sources
  local makefile="$_kernel_work_folder_abs/Makefile"
  if [ ! -f "$makefile" ]; then
      error "Makefile not found at $_kernel_work_folder_abs"
      exit 1
  fi

  local VERSION
  VERSION=$(head -n 10 "$makefile" | grep ^VERSION | awk '{print $3}')
  local PATCHLEVEL
  PATCHLEVEL=$(head -n 10 "$makefile" | grep ^PATCHLEVEL | awk '{print $3}')
  local SUBLEVEL
  SUBLEVEL=$(head -n 10 "$makefile" | grep ^SUBLEVEL | awk '{print $3}')
  local EXTRAVERSION
  EXTRAVERSION=$(head -n 10 "$makefile" | grep ^EXTRAVERSION | awk '{print $3}')

  _basekernel="$VERSION.$PATCHLEVEL"
  _basever="$VERSION$PATCHLEVEL"

  if [ -n "$EXTRAVERSION" ]; then
    [[ ! "$EXTRAVERSION" == "-rc"* ]] && error "$EXTRAVERSION does not start with '-rc'" && exit 1
    _sub="${EXTRAVERSION:1}"
  else
    _sub="$SUBLEVEL"
  fi

  msg2 "kernel version to build is $VERSION.$PATCHLEVEL.$_sub"

  [[ ${#PATCHLEVEL} == "1" ]] && PATCHLEVEL="0$PATCHLEVEL"
  _kver="$VERSION$PATCHLEVEL"
  _default_cpu_sched="eevdf"

  {
    printf "_basekernel='%s'\n" "$_basekernel"
    printf "_basever='%s'\n" "$_basever"
    printf "_sub='%s'\n" "$_sub"
    printf "_kver='%s'\n" "$_kver"
    printf "_default_cpu_sched='%s'\n" "$_default_cpu_sched"
  } >> "$_TKT_CONFIG_PATH"
}

_set_kernel_version() {
  if [ -n "$_kernel_git_tag" ]; then
    echo "_kernel_git_tag='$_kernel_git_tag'" >> "$_TKT_CONFIG_PATH"
    return 0
  fi

  if [[ "$_version" == *-latest ]]; then
    local kernel_ver="${_version::-7}"
    if [[ -v _kver_latest_tags_map["$kernel_ver"] ]]; then
      msg2 "Checking out latest kernel version of $kernel_ver"
      _kernel_git_tag="${_kver_latest_tags_map[$kernel_ver]}"
    else
      error "non-existing kernel version associated with $_version"
      exit 1
    fi
  elif [[ -n "$_version" ]]; then
    if echo "$_TAGS_CACHE" | grep -E "^$_version$" &>/dev/null; then
      _kernel_git_tag="$_version"
    else
      error "tag \"$_version\" not found in cache"
      exit 1
    fi
  else
    msg2 "Which kernel version do you want to install?"
    _kernel_fullver_list=()
    for _key in "${_current_kernels[@]}"; do
      _kernel_fullver_list+=("${_kver_latest_tags_map[$_key]}")
    done
    _default_index="0"
    if [[ "${_kver_latest_tags_map[${_current_kernels[0]}]}" == *rc* ]]; then
      _default_index="1"
    fi
    _prompt_from_array "${_kernel_fullver_list[@]}"
    _kernel_git_tag="$_selected_value"
  fi
  echo "_kernel_git_tag='$_kernel_git_tag'" >> "$_TKT_CONFIG_PATH"
}

_set_cpu_scheduler() {
  [[ -z "$_kver" ]] && error "bug: _kver variable not defined but needed" && exit 1

  if [ -n "$_cpusched" ]; then
    msg2 "Using $_cpusched CPU scheduler"
    printf "_cpusched='%s'\n" "$_cpusched" >> "$_TKT_CONFIG_PATH"
    return 0
  fi

  _avail_cpu_scheds=("$_default_cpu_sched")
  _recommended_sched="$_default_cpu_sched"

  if [[ -f "$_KERNELS_DIR/${_basekernel}/patches/0009-prjc.patch" ]]; then
    _avail_cpu_scheds+=("pds" "bmq")
  fi
  if [[ -f "$_KERNELS_DIR/${_basekernel}/patches/0001-bore.patch" ]]; then
    _avail_cpu_scheds+=("bore")
  fi

  if [ "${_preempt_rt}" = "1" ]; then
    warning "! Since you have enabled _preempt_rt, incompatible cpu schedulers will not be available !"
    _avail_cpu_scheds=("$_default_cpu_sched")
  fi

  for _sched in "${!_all_scheds[@]}"; do
    local found=false
    for _avail in "${_avail_cpu_scheds[@]}"; do
        if [[ "$_avail" == "$_sched" ]]; then
            found=true
            break
        fi
    done
    [[ "$found" == "false" ]] && unset _all_scheds["$_sched"]
  done

  if ! [[ " ${_avail_cpu_scheds[*]} " =~ " ${_cpusched} " ]]; then
    warning "Your cpusched selection ( $_cpusched ) is not available for the selected kernel version."
    if [ "$_nofallback" = "true" ]; then
      exit 1
    else
      _cpusched=""
    fi
  fi

  if [ -z "$_cpusched" ]; then
    msg2 "Which CPU sched variant do you want to build/install?"
    _default_key="$_recommended_sched"
    _prompt_from_dict "_all_scheds"
    _cpusched="${_selected_key}"
  fi

  msg2 "Using $_cpusched CPU scheduler"
  printf "_cpusched='%s'\n" "$_cpusched" >> "$_TKT_CONFIG_PATH"
}

_set_compiler() {
  if [ -n "$_compiler" ]; then
    if [ "$_compiler" = "llvm" ]; then
        _compiler_name="llvm"
        compiler_opt="CC=clang CPP=clang-cpp CXX=clang++ LD=ld.lld RANLIB=llvm-ranlib STRIP=llvm-strip AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump LLVM=1 LLVM_IAS=${_llvm_ias:-1}"
    else
        _compiler_name="gcc"
        compiler_opt="CC=gcc CXX=g++ LD=ld.bfd HOSTCC=gcc HOSTLD=ld.bfd AR=ar NM=nm OBJCOPY=objcopy OBJDUMP=objdump READELF=readelf RANLIB=ranlib STRIP=strip"
    fi
    printf "_compiler_name='%s'\ncompiler_opt='%s'\n" "$_compiler_name" "$compiler_opt" >> "$_TKT_CONFIG_PATH"
    return 0
  fi

  if ! [[ "$_compiler" =~ ^(gcc|llvm)$ ]]; then
    plain "Which compiler do you want to use?"
    _compiler_array_text=("GCC" "Clang/LLVM (recommended)")
    _compiler_array=("gcc" "llvm")
    _default_index="0"
    _prompt_from_array "${_compiler_array_text[@]}"
    _compiler="${_compiler_array[$_selected_index]}"
  fi

  if [ "$_compiler" = "llvm" ]; then
    _compiler_name="llvm"
    compiler_opt="CC=clang CPP=clang-cpp CXX=clang++ LD=ld.lld RANLIB=llvm-ranlib STRIP=llvm-strip AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump LLVM=1 LLVM_IAS=${_llvm_ias:-0}"
  else
    _compiler_name="gcc"
    compiler_opt="CC=gcc CXX=g++ LD=ld.bfd HOSTCC=gcc HOSTLD=ld.bfd AR=ar NM=nm OBJCOPY=objcopy OBJDUMP=objdump READELF=readelf RANLIB=ranlib STRIP=strip"
  fi

  printf "_compiler_name='%s'\ncompiler_opt='%s'\n" "$_compiler_name" "$compiler_opt" >> "$_TKT_CONFIG_PATH"
}

_define_kernel_abs_paths() {
  _kernel_work_folder_abs="$_SRC_DIR/linux-src-git"
  echo _kernel_work_folder_abs="$_kernel_work_folder_abs" >> "$_TKT_CONFIG_PATH"
}

_setup_kernel_work_folder() {
  _define_kernel_abs_paths

  if [ -z "$_kernel_git_tag" ]; then
    error "Internal error: kernel version should be chosen before cloning"
    exit 1
  fi

  if [ ! -d "$_kernel_work_folder_abs" ]; then
    msg2 "Cloning kernel sources (shallow, tag: $_kernel_git_tag)..."
    git clone --depth 1 --branch "$_kernel_git_tag" "$_git_mirror" "$_kernel_work_folder_abs"
  else
    msg2 "Ensuring existing kernel sources match tag: $_kernel_git_tag..."
    cd "$_kernel_work_folder_abs"
    if [[ "$(git describe --tags --always 2>/dev/null)" != "$_kernel_git_tag" ]]; then
        msg2 "Version mismatch. Re-cloning..."
        cd "$_SRC_DIR"
        rm -rf "$_kernel_work_folder_abs"
        git clone --depth 1 --branch "$_kernel_git_tag" "$_git_mirror" "$_kernel_work_folder_abs"
    else
        git reset --hard "$_kernel_git_tag"
        git clean -ffdx
    fi
  fi

  _set_kver_internal_vars
}

_tkg_initscript() {
  if ! command -v git >/dev/null 2>&1; then
    error "git is not installed."
    exit 1
  fi

  [ -d "$_LOGS_DIR" ] && rm -rf "${_LOGS_DIR:?}"/*
  mkdir -p "$_LOGS_DIR"

  _source_tkt_config
  _setup_kernel_work_folder
  _set_cpu_scheduler

  srcdir="$_KERNELS_DIR/$_basekernel"

  _set_compiler

  if [ -z "$_kernel_localversion" ]; then
    _compiler_tag="-$_compiler_name"
    parts=("tkt")
    [[ "${_distro,,}" == "arch" ]] && parts+=("arch")
    [ "$_kernel_on_diet" = "true" ] && parts+=("diet")
    [ "$_modprobeddb" = "true" ] && parts+=("modprobed")
    parts+=("$_cpusched")
    [ "$_preempt_rt" = "1" ] && parts+=("rt")
    parts+=("$_compiler_name")

    _kernel_flavor=$(IFS=- ; echo "${parts[*]}")
    {
      echo "_compiler_name=$_compiler_name"
      echo "_cpusched=$_cpusched"
      echo "_kernel_flavor=$_kernel_flavor"
    } >> "$_TKT_CONFIG_PATH"
  else
    _kernel_flavor="tkt-${_kernel_localversion}"
  fi

  _kernelname="${_basekernel}.${_sub}-${_kernel_flavor}"
  echo "_kernelname=$_kernelname" >> "$_TKT_CONFIG_PATH"

  if [ -n "$_custom_pkgbase" ]; then
    pkgbase="${_custom_pkgbase}"
  else
    pkgbase="linux-${_kernelname}"
  fi
  echo "pkgbase=$pkgbase" >> "$_TKT_CONFIG_PATH"

  _load_distro_script
}

_tkg_patcher() {
  local target_patch="$tkgpatch"
  if [ ! -e "$target_patch" ]; then
    local patch_name
    patch_name=$(basename "$tkgpatch")
    if [ -e "${srcdir}/patches/${patch_name}" ]; then
        target_patch="${srcdir}/patches/${patch_name}"
    fi
  fi

  if [ -e "$target_patch" ] && [[ $(wc -l <"$target_patch") -ge 7 ]]; then
    msg2 "$_msg"
    printf "### Applying ${target_patch##*/}... ###" >> "$_LOGS_DIR/prepare.log.txt"
    patch -Np1 -i "$target_patch" >> "$_LOGS_DIR/prepare.log.txt" || error "Patching failed. See prepare.log.txt"
    printf "\n" >> "$_LOGS_DIR/prepare.log.txt"
  else
    msg2 "Skipping patch ${tkgpatch##*/} (unavailable)"
  fi
}

_tkg_srcprep() {
  cd "$_kernel_work_folder_abs"

  [ -v distro_srcprep_pre ] && distro_srcprep_pre

  if [ "${_configfile}" = "config_hardened.x86_64" ] && [ "${_cpusched}" = "cfs" ]; then
    tkgpatch="$srcdir/0012-linux-hardened.patch"
    _msg="Using linux hardened patchset" && _tkg_patcher
  fi

  # PREEMPT_RT patch
  if [ "${_preempt_rt}" = "1" ] && [[ $_kver -lt 612 ]]; then
      # RT patching logic...
      warning "PREEMPT_RT patching via prepare.sh is legacy. Use kernels/ assets."
  fi

  # Core TKT Patches
  if [ "$_clear_patches" = "true" ] && [[ $_kver != 618 ]]; then
    tkgpatch="$srcdir/0002-clear-patches.patch"
    _msg="Applying clear linux patches" && _tkg_patcher
  fi

  if [ "$_glitched_base" = "true" ]; then
    tkgpatch="$srcdir/0003-glitched-base.patch"
    _msg="Applying glitched base patch" && _tkg_patcher
  fi

  if [ "${_preempt_rt}" != "1" ]; then
    tkgpatch="$srcdir/0003-glitched-base-nonrt.patch"
    _msg="Applying glitched base non-rt additions patch" && _tkg_patcher
  fi

  if [ "$_misc_adds" = "true" ]; then
    tkgpatch="$srcdir/0012-misc-additions.patch"
    _msg="Applying misc additions patch" && _tkg_patcher
  fi

  _msg="Applying patches for WRITE_WATCH support in Wine"
  tkgpatch="$srcdir/0001-mm-Support-soft-dirty-flag-reset-for-VA-range.patch" && _tkg_patcher
  tkgpatch="$srcdir/0002-mm-Support-soft-dirty-flag-read-with-reset.patch" && _tkg_patcher

  if [ "${_cpusched}" = "bore" ]; then
    _msg="Applying BORE patch"
    tkgpatch="$srcdir/0001-bore.patch" && _tkg_patcher
  fi

  if [ "${_cpusched}" = "cfs" ] || [ "${_cpusched}" = "bore" ] || [[ "${_cpusched}" =~ "eevdf" ]]; then
    _msg="Applying Glitched CFS/EEVDF patch"
    tkgpatch="$srcdir/0003-glitched-cfs.patch" && _tkg_patcher
  fi

  # Config selection
  if [ -z "${_configfile}" ]; then
    msg2 "Using TKT's default config"
    cat "${srcdir}"/config.x86_64 >./.config 2>/dev/null || cat "${srcdir}"/patches/config.x86_64 >./.config
  elif [ "${_configfile}" = "running-kernel" ]; then
    zcat /proc/config.gz >.config 2>/dev/null || cp /boot/config-$(uname -r) .config
  else
    cat "${_where}/${_configfile}" >./.config 2>/dev/null || cat "${_SRC_DIR}/${_configfile}" >./.config
  fi

  # Native micro-arch hardening
  _is_march_supported() {
    [[ "$1" == "native" ]] && return 0
    [[ "$1" == "generic" ]] && return 1
    if [[ "$_compiler" == "gcc" ]]; then
      gcc --target-help | grep -F "$1" &>/dev/null
    else
      clang -mcpu=help 2>&1 | grep -F "$1" &>/dev/null
    fi
  }

  if [ -n "$_processor_opt" ] && _is_march_supported "$_processor_opt"; then
    msg2 "Setting cpu micro architecture to $_processor_opt"
    sed -i "s/KBUILD_CFLAGS   += \$(KCFLAGS)/KBUILD_CFLAGS   += -march=$_processor_opt -mtune=$_processor_opt\nKBUILD_CFLAGS   += \$(KCFLAGS)/" Makefile
  fi

  cp .config "$_SRC_DIR"/kernelconfig.new
  [ -v distro_srcprep_post ] && distro_srcprep_post
}

exit_cleanup() {
  if [ -f "$_where/shell-output.log" ]; then
    mv -f "$_where"/shell-output.log "$_LOGS_DIR"/shell-output.log.txt
    sed -i 's/\x1b\[[0-9;]*m//g' "$_LOGS_DIR"/shell-output.log.txt
    sed -i 's/\x1b(B//g' "$_LOGS_DIR"/shell-output.log.txt
  fi

  rm -rf "$_where"/*.patch
  rm -f "$_where"/minimal_modprobed.db
  rm -f "$_where"/TKT_CONFIG
  rm -f "$_where"/current_env

  [ -f "$_TKT_CONFIG_PATH" ] && cp -f "$_TKT_CONFIG_PATH" "$_LOGS_DIR"/TKT_CONFIG.log

  if [ "$_NUKR" = "true" ]; then
    rm -rf "${_SRC_DIR:?}"/*
  fi

  msg2 'Cleanup done'
}

if [ -z "$_ispkgbuild" ]; then
    trap exit_cleanup EXIT
fi
