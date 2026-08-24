#!/bin/bash

# TKT - The Kernel Toolkit TUI Library - Clean Version

# Persisted TUI selection states
_LAST_MAIN_CHOICE="1"
_LAST_BASIC_CONFIG_CHOICE="1"
_LAST_OPTIMIZATION_CHOICE="1"
_LAST_ADVANCED_CHOICE="1"

tkt_tui_main() {
    # Ensure _where is available (fallback if not set by entry point)
    _where="${_where:-$(pwd)}"

    msg2 "Starting TꓘT TUI..."

    # Initial config load
    _source_tkt_config

    # Set defaults if still empty
    _distro="${_distro:-Generic}"
    _compiler="${_compiler:-gcc}"
    _cpusched="${_cpusched:-eevdf}"
    _timer_freq="${_timer_freq:-1000}"
    _processor_opt="${_processor_opt:-x86-64}"
    _git_mirror="${_git_mirror:-${_kernel_git_remotes[kernel.org]}}"

    # Load distro script early to ensure paths are set
    _load_distro_script

    while true; do
        tui_main_menu
    done
}

tui_main_menu() {
    local choice
    _TUI_DEFAULT_ITEM="$_LAST_MAIN_CHOICE"
    choice=$(_tui_whiptail_menu "TꓘT - The Kernel Toolkit" "Choose an option" 20 65 12 \
        "1" "Select Distribution ($_distro)" \
        "2" "Kernel Version and Scheduler" \
        "3" "Optimization Options (Compiler, LTO, etc.)" \
        "4" "Patch and Feature Toggles" \
        "5" "Interactive & Maintenance Prompts" \
        "6" "Advanced Build Options (NUKR, diet, etc.)" \
        "7" "Select Git Mirror" \
        "8" "Maintenance: Regen Initramfs & GRUB" \
        "9" "Maintenance: Project Cleanup" \
        "10" "Save Configuration to TKT.cfg" \
        "11" "Start Build and Install" \
        "12" "Exit")

    # If Cancel/Esc, exit gracefully
    [ -z "$choice" ] && exit 0

    _LAST_MAIN_CHOICE="$choice"

    case "$choice" in
        1) tui_select_distro ;;
        2) tui_kernel_basic_config ;;
        3) tui_optimization_menu ;;
        4) tui_patch_feature_toggles ;;
        5) tui_interactive_prompts ;;
        6) tui_advanced_build_options ;;
        7) tui_select_mirror ;;
        8) tui_trigger_maintenance ;;
        9) tui_trigger_cleanup ;;
        10) tui_save_config ;;
        11) tui_start_build ;;
        12) exit 0 ;;
        *) exit 0 ;;
    esac
}

tui_select_mirror() {
    local menu_items=()
    for m in "${!_kernel_git_remotes[@]}"; do
        menu_items+=("$m" "${_kernel_git_remotes[$m]}")
    done

    local new_mirror_key
    new_mirror_key=$(_tui_whiptail_menu "Select Git Mirror" "Choose your preferred kernel source" 18 70 4 "${menu_items[@]}")
    if [ -n "$new_mirror_key" ]; then
        _git_mirror="${_kernel_git_remotes[$new_mirror_key]}"
    fi
}

tui_trigger_maintenance() {
    whiptail --yesno "Regenerate Initramfs and update GRUB now?" 8 45 || return 0
    maintenance_regen_boot
    whiptail --msgbox "Maintenance tasks completed." 8 45
}

tui_trigger_cleanup() {
    whiptail --yesno "Nuke build sources, packages, and logs?" 8 45 || return 0
    maintenance_project_cleanup
    whiptail --msgbox "Project cleanup completed." 8 45
}

tui_select_distro() {
    local menu_items=()
    # shellcheck disable=SC2154
    for d_path in "$_DISTROS_DIR"/*/; do
        local dname
        dname=$(basename "$d_path")
        # Capitalize first letter for display
        local display_name="${dname^}"
        menu_items+=("$display_name" "")
    done

    local new_distro
    new_distro=$(_tui_whiptail_menu "Select Distribution" "Dynamically discovered in distros/" 18 60 10 "${menu_items[@]}")
    if [ -n "$new_distro" ]; then
        _distro="$new_distro"
        _load_distro_script
    fi
}

tui_kernel_basic_config() {
    local choice
    _TUI_DEFAULT_ITEM="$_LAST_BASIC_CONFIG_CHOICE"
    choice=$(_tui_whiptail_menu "Kernel Configuration" "Select option to configure" 18 65 6 \
        "1" "Kernel Version ($_kernel_git_tag)" \
        "2" "CPU Scheduler ($_cpusched)" \
        "3" "Timer Frequency ($_timer_freq)" \
        "4" "Kernel Base Config ($_configfile)" \
        "5" "Back to Main Menu")

    [ -n "$choice" ] && _LAST_BASIC_CONFIG_CHOICE="$choice"

    case "$choice" in
        1) tui_select_version ;;
        2) tui_select_scheduler ;;
        3) tui_select_timer_freq ;;
        4) tui_select_config ;;
        *) return 0 ;;
    esac
}

tui_select_config() {
    local menu_items=(
        "default" "Standard TKT config"
        "running-kernel" "Pull from current /proc/config.gz"
        "OpenRC" "TKT OpenRC specialized config"
        "config_hardened.x86_64" "Security-hardened config"
    )

    # Dynamic discovery of user-provided .config files
    # shellcheck disable=SC2154
    while IFS= read -r line; do
        local bname
        bname=$(basename "$line")
        menu_items+=("$bname" "User found config in root")
    done < <(find "$_where" -maxdepth 1 -name "*.config")

    # shellcheck disable=SC2154
    while IFS= read -r line; do
        local bname
        bname=$(basename "$line")
        menu_items+=("$bname" "User found config in src/")
    done < <(find "$_SRC_DIR" -maxdepth 1 -name "*.config" 2>/dev/null)

    local new_config
    new_config=$(_tui_whiptail_menu "Kernel Config Selection" "Choose a base configuration" 20 70 12 "${menu_items[@]}")

    if [ -n "$new_config" ]; then
        if [ "$new_config" = "default" ]; then
            _configfile=""
        else
            _configfile="$new_config"
        fi
    fi
    tui_kernel_basic_config
}

tui_select_version() {
    # Fetch tags if not already cached
    if [ -z "$_TAGS_CACHE" ]; then
        msg2 "Fetching available kernel versions..."
        _TAGS_CACHE=$(_fetch_kernel_tags "${_git_mirror:-https://github.com/gregkh/linux.git}")
        if [ -z "$_TAGS_CACHE" ]; then
            whiptail --msgbox "Failed to fetch kernel tags. Please check your internet connection." 8 50
            return 1
        fi
    fi

    local menu_items=()
    # shellcheck disable=SC2154
    for k_dir in "$_KERNELS_DIR"/*/; do
        [ -e "$k_dir" ] || continue
        local k
        k=$(basename "$k_dir")
        # Skip ProjectC-LICENSE and README.md
        [[ "$k" == "ProjectC-LICENSE" || "$k" == "README.md" || "$k" == "patches" ]] && continue

        local tag
        # shellcheck disable=SC2154
        tag=$(echo "$_TAGS_CACHE" | grep -F "v$k" | grep -v "v${k}[0-9]" | tail -1 | cut -c1-)
        # shellcheck disable=SC2154
        menu_items+=("$tag" "Kernel series $k")
    done

    local new_tag
    new_tag=$(_tui_whiptail_menu "Select Kernel Version" "Current: $_kernel_git_tag" 18 60 6 "${menu_items[@]}")
    [ -n "$new_tag" ] && _kernel_git_tag="$new_tag"
    tui_kernel_basic_config
}

tui_select_scheduler() {
    local menu_items=()
    # shellcheck disable=SC2154
    for k in "${!_all_scheds[@]}"; do
        menu_items+=("$k" "${_all_scheds[$k]}")
    done

    local new_sched
    new_sched=$(_tui_whiptail_menu "Select CPU Scheduler" "Current: $_cpusched" 18 65 8 "${menu_items[@]}")
    [ -n "$new_sched" ] && _cpusched="$new_sched"
    tui_kernel_basic_config
}

tui_select_timer_freq() {
    local freqs=("100" "250" "300" "500" "750" "1000")
    local menu_items=()
    for f in "${freqs[@]}"; do
        menu_items+=("$f" "$f Hz")
    done

    local new_freq
    new_freq=$(_tui_whiptail_menu "Select Timer Frequency" "Current: $_timer_freq" 18 60 6 "${menu_items[@]}")
    [ -n "$new_freq" ] && _timer_freq="$new_freq"
    tui_kernel_basic_config
}

tui_optimization_menu() {
    local choice
    _TUI_DEFAULT_ITEM="$_LAST_OPTIMIZATION_CHOICE"
    choice=$(_tui_whiptail_menu "Optimization Options" "Advanced Tuning" 18 65 7 \
        "1" "Compiler ($_compiler)" \
        "2" "CPU Micro-architecture ($_processor_opt)" \
        "3" "LTO Mode ($_lto_mode)" \
        "4" "PGO Config ($_pgo_config)" \
        "5" "AutoFDO ($_auto_afdo)" \
        "6" "Propeller ($_propeller_generate / $_propeller_use)" \
        "7" "Back to Main Menu")

    [ -n "$choice" ] && _LAST_OPTIMIZATION_CHOICE="$choice"

    case "$choice" in
        1) tui_select_compiler ;;
        2) tui_select_march ;;
        3) tui_select_lto ;;
        4) tui_select_pgo ;;
        5) tui_toggle_afdo ;;
        6) tui_select_propeller ;;
        *) return 0 ;;
    esac
}

tui_select_compiler() {
    local new_comp
    new_comp=$(_tui_whiptail_menu "Select Compiler" "Current: $_compiler" 18 60 2 \
        "gcc" "GNU Compiler Collection" \
        "llvm" "Clang/LLVM")
    [ -n "$new_comp" ] && _compiler="$new_comp"
    tui_optimization_menu
}

tui_select_march() {
    local menu_items=()
    # shellcheck disable=SC2154
    for k in "${!_cpu_marchs[@]}"; do
        menu_items+=("$k" "${_cpu_marchs[$k]}")
    done

    local new_march
    new_march=$(_tui_whiptail_menu "Select CPU Micro-architecture" "Current: $_processor_opt" 20 75 12 "${menu_items[@]}")
    [ -n "$new_march" ] && _processor_opt="$new_march"
    tui_optimization_menu
}

tui_select_lto() {
    local new_lto
    new_lto=$(_tui_whiptail_menu "LTO Mode" "Select Clang LTO" 18 60 3 \
        "no" "Disable LTO" \
        "thin" "Thin LTO (recommended)" \
        "full" "Full LTO (slow)")
    [ -n "$new_lto" ] && _lto_mode="$new_lto"
    tui_optimization_menu
}

tui_select_pgo() {
    local new_pgo
    new_pgo=$(_tui_whiptail_menu "PGO Configuration" "Profile-Guided Optimization" 18 60 3 \
        "false" "Disable PGO" \
        "generate" "Generate profile" \
        "use" "Use existing profile")
    [ -n "$new_pgo" ] && _pgo_config="$new_pgo"
    tui_optimization_menu
}

tui_toggle_afdo() {
    if [[ "$_auto_afdo" == "true" ]]; then _auto_afdo="false"; else _auto_afdo="true"; fi
    tui_optimization_menu
}

tui_select_propeller() {
    local choice
    choice=$(_tui_whiptail_menu "Propeller" "LLVM Propeller Layout Optimization" 18 60 3 \
        "none" "Disable Propeller" \
        "generate" "Generate/Instrument" \
        "use" "Use optimized layout")

    case "$choice" in
        none) _propeller_generate="false"; _propeller_use="false" ;;
        generate) _propeller_generate="true"; _propeller_use="false" ;;
        use) _propeller_generate="false"; _propeller_use="true" ;;
    esac
    tui_optimization_menu
}

tui_patch_feature_toggles() {
    local choice
    choice=$(_tui_whiptail_checklist "Patch and Feature Toggles" "SPACE to toggle" 18 65 11 \
        "clear_patches" "Clear Linux patches" "$([[ $_clear_patches == true ]] && echo ON || echo OFF)" \
        "glitched_base" "Glitched base patches" "$([[ $_glitched_base == true ]] && echo ON || echo OFF)" \
        "zenify" "Zenify (blk, mm, scheduler tweaks)" "$([[ $_zenify == true ]] && echo ON || echo OFF)" \
        "acs_override" "ACS Override patch" "$([[ $_acs_override == true ]] && echo ON || echo OFF)" \
        "bcachefs" "Bcachefs support" "$([[ $_bcachefs == true ]] && echo ON || echo OFF)" \
        "mglru" "Multi-generational LRU" "$([[ $_mglru == true ]] && echo ON || echo OFF)" \
        "ntsync" "NTsync support" "$([[ $_ntsync == true ]] && echo ON || echo OFF)" \
        "openrgb" "OpenRGB support" "$([[ $_openrgb == true ]] && echo ON || echo OFF)" \
        "misc_adds" "Enable misc additions" "$([[ $_misc_adds == true ]] && echo ON || echo OFF)" \
        "numadisable" "Disable NUMA" "$([[ $_numadisable == true ]] && echo ON || echo OFF)" \
        "ftracedisable" "Disable FTRACE" "$([[ $_ftracedisable == true ]] && echo ON || echo OFF)")

    if [ -n "$choice" ]; then
        _clear_patches=false; _glitched_base=false; _zenify=false; _acs_override=false
        _bcachefs=false; _mglru=false; _ntsync=false; _openrgb=false; _misc_adds=false
        _numadisable=false; _ftracedisable=false

        for p in $choice; do
            p=$(echo "$p" | tr -d '"')
            case "$p" in
                clear_patches) _clear_patches=true ;;
                glitched_base) _glitched_base=true ;;
                zenify) _zenify=true ;;
                acs_override) _acs_override=true ;;
                bcachefs) _bcachefs=true ;;
                mglru) _mglru=true ;;
                ntsync) _ntsync=true ;;
                openrgb) _openrgb=true ;;
                misc_adds) _misc_adds=true ;;
                numadisable) _numadisable=true ;;
                ftracedisable) _ftracedisable=true ;;
            esac
        done
    fi
}

tui_interactive_prompts() {
    local choice
    choice=$(_tui_whiptail_checklist "Interactive Prompts" "Toggle interactive steps" 18 60 5 \
        "menuconfig" "Run make menuconfig before build" "$([[ $_menunconfig == 1 ]] && echo ON || echo OFF)" \
        "nconfig" "Run make nconfig before build" "$([[ $_menunconfig == 2 ]] && echo ON || echo OFF)" \
        "xconfig" "Run make xconfig before build" "$([[ $_menunconfig == 3 ]] && echo ON || echo OFF)" \
        "diffconfig" "Generate config fragment after" "$([[ $_diffconfig == true ]] && echo ON || echo OFF)")

    if [ -n "$choice" ]; then
        _menunconfig="false"; _diffconfig="false"
        for p in $choice; do
            p=$(echo "$p" | tr -d '"')
            case "$p" in
                menuconfig) _menunconfig="1" ;;
                nconfig) _menunconfig="2" ;;
                xconfig) _menunconfig="3" ;;
                diffconfig) _diffconfig="true" ;;
            esac
        done
    fi
}

tui_advanced_build_options() {
    local choice
    _TUI_DEFAULT_ITEM="$_LAST_ADVANCED_CHOICE"
    choice=$(_tui_whiptail_menu "Advanced Build Options" "Configure build behavior" 18 65 6 \
        "1" "Strip Debug Symbols ($_STRIP)" \
        "2" "Nuke Build Folder (_NUKR: $_NUKR)" \
        "3" "Kernel on Diet ($_kernel_on_diet)" \
        "4" "Use modprobed-db ($_modprobeddb)" \
        "5" "Force All Threads ($_force_all_threads)" \
        "6" "Back to Main Menu")

    [ -n "$choice" ] && _LAST_ADVANCED_CHOICE="$choice"

    case "$choice" in
        1) _tui_toggle_var "_STRIP"; tui_advanced_build_options ;;
        2) _tui_toggle_var "_NUKR"; tui_advanced_build_options ;;
        3) _tui_toggle_var "_kernel_on_diet"; tui_advanced_build_options ;;
        4) _tui_toggle_var "_modprobeddb"; tui_advanced_build_options ;;
        5) _tui_toggle_var "_force_all_threads"; tui_advanced_build_options ;;
        *) return 0 ;;
    esac
}

tui_save_config() {
    local config_file="$HOME/.config/TKT.cfg"
    mkdir -p "$(dirname "$config_file")"

    {
        echo "# TKT User Configuration"
        echo "_distro=\"$_distro\""
        echo "_kernel_git_tag=\"$_kernel_git_tag\""
        echo "_compiler=\"$_compiler\""
        echo "_processor_opt=\"$_processor_opt\""
        echo "_cpusched=\"$_cpusched\""
        echo "_timer_freq=\"$_timer_freq\""
        echo "_lto_mode=\"$_lto_mode\""
        echo "_pgo_config=\"$_pgo_config\""
        echo "_auto_afdo=\"$_auto_afdo\""
        echo "_propeller_generate=\"$_propeller_generate\""
        echo "_propeller_use=\"$_propeller_use\""
        echo "_menunconfig=\"$_menunconfig\""
        echo "_diffconfig=\"$_diffconfig\""
        echo "_configfile=\"$_configfile\""
        echo "_clear_patches=\"$_clear_patches\""
        echo "_glitched_base=\"$_glitched_base\""
        echo "_zenify=\"$_zenify\""
        echo "_acs_override=\"$_acs_override\""
        echo "_bcachefs=\"$_bcachefs\""
        echo "_mglru=\"$_mglru\""
        echo "_ntsync=\"$_ntsync\""
        echo "_openrgb=\"$_openrgb\""
        echo "_misc_adds=\"$_misc_adds\""
        echo "_numadisable=\"$_numadisable\""
        echo "_ftracedisable=\"$_ftracedisable\""
        echo "_STRIP=\"$_STRIP\""
        echo "_NUKR=\"$_NUKR\""
        echo "_kernel_on_diet=\"$_kernel_on_diet\""
        echo "_modprobeddb=\"$_modprobeddb\""
        echo "_force_all_threads=\"$_force_all_threads\""
        echo "_git_mirror=\"$_git_mirror\""
    } > "$config_file"

    whiptail --msgbox "Configuration saved to $config_file" 8 45
}

tui_start_build() {
    whiptail --yesno "Start build for $_distro kernel?" 8 45 || return 0

    # Export ALL variables
    export _distro _kernel_git_tag _compiler _processor_opt _cpusched _timer_freq _configfile
    export _lto_mode _pgo_config _auto_afdo _propeller_generate _propeller_use
    export _menunconfig _diffconfig _git_mirror
    export _clear_patches _glitched_base _zenify _acs_override _bcachefs _mglru _ntsync _openrgb
    export _misc_adds _numadisable _ftracedisable
    export _STRIP _NUKR _kernel_on_diet _modprobeddb _force_all_threads

    # Run the build logic from tkt entry point
    tkt_cli_main install
}
