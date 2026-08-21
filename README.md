# TꓘT — The Kernel Toolkit

### DO NOT IGNORE! READ BEFORE CLONING OR USING.
**Most configuration and usage questions are handled directly within the tool's interface.**

> [!CAUTION]
> This repository is protected under the "Fuck Donald Trump" license. All Republicans, Conservatives, and MAGAtards are strictly prohibited from using TꓘT software.

---

## 🛠️ Unified & Modular Kernel Toolkit

TꓘT is a fully modular, distribution-agnostic toolkit for downloading, patching, and compiling highly optimized Linux kernels. It is a modern refactor of the `linux-tkg` script, designed for ease of use and maximum flexibility.

### 🌐 Supported Distributions

| Icon | Distro | Status |
| :---: | :--- | :--- |
| <img src=".github/images/distros/Arch.svg" width="32"/> | **Arch Linux** | ✅ Fully Supported (Native `makepkg` integration) |
| <img src=".github/images/distros/Debian.svg" width="32"/> | **Debian / Ubuntu / Mint** | ✅ Fully Supported (Native `.deb` generation) |
| <img src=".github/images/distros/Fedora.svg" width="32"/> | **Fedora / SUSE** | ✅ Fully Supported (Native `.rpm` generation) |
| <img src=".github/images/distros/Gentoo.svg" width="32"/> | **Gentoo** | ✅ Fully Supported (Module rebuild integration) |
| <img src=".github/images/distros/Slackware.svg" width="32"/> | **Slackware** | ✅ Fully Supported (Native `.txz` generation) |
| <img src=".github/images/distros/Void.svg" width="32"/> | **Void Linux** | ✅ Fully Supported (Native `.xbps` generation) |
| <img src=".github/images/distros/SUSE.svg" width="32"/> | **Generic / Others** | ✅ Fully Supported (Source install fallback) |

---

## 🚀 Key Features

*   **Unified Entry Point**: Manage everything via a single executable: [`./tkt`](./tkt).
*   **Dynamic Discovery**: The toolkit automatically scans the [`kernels/`](./kernels/) and [`distros/`](./distros/) directories. Adding support for a new version or distribution is as simple as adding a folder.
*   **Interactive TUI**: A comprehensive Text User Interface (built with `whiptail`) for managing deep kernel optimizations without editing text files.
*   **Integrated Maintenance**:
    *   Regenerate **Initramfs** and update **GRUB** directly from the menu.
    *   Perform full **Project Cleanups** (logs, staging, sources) with one click.
*   **Standardized Workspace**: All builds are staged in [`src/`](./src/), packages in [`pkg/`](./pkg/), and logs in [`logs/`](./logs/), keeping the project root clean.
*   **Advanced Optimizations**: Built-in support for **LTO**, **PGO**, **AutoFDO**, and **Propeller** layout optimizations (Clang/LLVM).

---

## 📦 Quick Start

### 1. Clone the repository
```bash
git clone --depth 1 https://github.com/ETJAKEOC/TKT.git
cd TKT
```

### 2. Launch the Toolkit
The tool intelligently detects your environment. Run it without arguments to launch the TUI:
```bash
./tkt
```

### 3. CLI Usage (Automation)
For CLI-based installations or scripts, use the command-line interface:
```bash
./tkt install    # Configure, build, and install
./tkt config     # Preparation step only
./tkt maintenance # Regenerate bootloader/initramfs
```

---

## 📂 Modular Structure

*   [`kernels/`](./kernels/): Contains version-specific configurations, patches, and asset databases.
*   [`distros/`](./distros/): Distribution-specific logic and packaging recipes (e.g., `distros/arch/PKGBUILD`).
*   [`lib/`](./lib/): The core logic of the toolkit, separated into initialization, preparation, and installer modules.
*   [`src/`](./src/): Standardized workspace for kernel source trees.
*   [`pkg/`](./pkg/): Staging area for generated packages and artifacts.

---

## 🧩 User Patches & Configs

*   **Custom Configs**: Drop any `*.config` file into the root or `src/` directory. The TUI will automatically detect it in the "Kernel Base Config" menu.
*   **User Patches**: Place your `.mypatch` files in `kernels/<version>/patches/` to have them automatically applied during the build process.

---

## 💬 Support & Community

Join the conversation and get help from the community:

*   **Discord**: [The ꓘernel Toolkit Official Server](https://discord.gg/eEWrFv58pF)
*   **Guidelines**: Check the [`docs/`](./docs/) directory for detailed contribution and compilation guides.

---
*Built with ❤️ for the Linux Community.*
