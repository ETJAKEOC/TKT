# ETJAKEOC's crash course on The ꓘernel Toolkit:

## INTRODUCTION:

Welcome to TKT (The Kernel Toolkit). Here we will learn about the basics of setting up and using the TKT kernel install script. Most options in this guide that we will cover will have their own descriptions inside the `customization.cfg` file, this just covers the basics and tries to explain them. For a more in depth explanation of an option, please refer to the original file, or do a search online about it.

Depending on the OS you`re running depends on how you will install this package.


## FIRST STEPS:

All users will begin with the beginning step of cloning the github repo from this repository.

```git clone --depth 1 https://github.com/ETJAKEOC/TKT```

We will `cd` into the new directory called `TKT`.

Inside this directory you will find a `customization.cfg` file, open this in your favorite text editor (Kate, Emacs, nano, vim, etc etc).

Inside this file we will find a bunch of awesome options we can tweak to generate our own custom kernel every time with the same options, even if the script or kernel versions update. In order to keep our changes persistent though, we will want to save our copy elsewhere, this location is specified inside the `customization.cfg` file, and is customizable in itself as well.

## CUSTOMIZING THE INSTALL SCRIPT:
### (This is long, but recommended to at least glance through, it will explain some of the options in a dumbed down way. For more in detail explanations of options, refer to the `customization.cfg` file itself.)

#### (This can be skipped if you do not want to save your configurations for recompiling new kernel versions) Following the conventional method in the script from the github repo, we will save our file to `~/.config/TKT.cfg`. Again, feel free to modify this, but for our purposes here, we will stick with the default location.

Now that we have our file saved in our location, we will open and modify it to be customized for our system.

Inside this script, one of the first options you will come across is the option for your distribution. If using Arch, you can leave blank, as the script state, it defaults to Arch when using `PKGBUILD`. Otherwise, insert your distribution here, following the provided names in the first comment.

The next option allows you to specify a kernel version to build against. Personally, I leave this blank, as it leaves the option to pick whatever version you want when you run the script.

Our next option we have may have already seen, the location of our custom `customization.cfg` file.

Underneath this is the cleanup option, this only applies to Arch Linux, it cleans up the code as it compiles it, helping to save disk space.

Our next option is where we want to pull our kernel from, change this to one of the provided options based on your preference.

The next four options are pretty self explanatory, and I normally leave these as the default (blank).

The Force all threads option will change the amount of threads it uses to compile your kernel, ignoring the setting in the `makepkg.conf` on Arch Linux.

You can also disable ccache if you wanted to, I tend to leave this option enabled. `ccache` is a compiler caching program, TLDR; it makes cache files on your disk for compiling tasks that it does often, allowing it to `skip` compiling on some steps, as it already has the output cached somewhere. This will slow down your first build, as it builds the cache, subsequent runs *may* notice improvements in compile time.

modprobed-db is an interesting and dangerous tool. It's not recommended for those who are not prepared to have a possible no-boot scenario. It is also recommended that you run the program for a while on a generic kernel first, updating the list regularly as you load and plugin new hardware, so it captures all the modules you will ever need to use into a list. This option compiles a very slim kernel, with only the modules that your system uses. We can configure it`s DB location in the option underneath.

The menuconfig/nconfig option is an option that anyone who has used `Unix Makefiles` will be familiar with. This allows us to enter the kernel configuration menu and make our tweaks that we may want to make. I won`t go too into depth here as this will vary from user to user and machine to machine, but if you wanted to, and were comfortable and intelligent enough, you could make a very slim kernel using this tool.

The diffconfig options allow you to generate config fragments from your changes in menuconfig/nconfig, this can safely be left blank.

## Kernel Options:

Now we enter into the kernel options, this is where some of the actual kernel tuning comes into play. The very first option is the kernel config option. I normally recommend using `running-kernel` here the very first time you compile a kernel from your stock kernel, as this will base it from that, allowing for better compatibility, ensuring that the proper modules and drivers and other flags are turned on or off. After we have run it the first time, I recommend copying the `kernelconfig.new` in the `TKT` directory to another file name in the same directory, and then changing this option to that name, so as to have your custom base to build from. config_updating can be left alone, unless you know what you`re doing.

The `debug_disable` flag is self explanatory, it disables some debugging flags in the kernel, slimming it down, and reducing overhead. You will also normally want to strip the vmlinux file in the next option, unless you are doing kernel debugging.

The next set of options are where we dig into the tuning. The CPU scheduler basically controls how the CPU assigns time for jobs to run. The kernel default is `EEVDF`, but we're going to go with `BORE`, as it is a upgraded version of `EEVDF` that will bring us more performance.

## Compiler options:

Now we have our compiler option. You can use `gcc` if you like, but I personally use `llvm` myself. The next option controls LTO (Link Time Optimization), which changes how the kernel links things during compiling, trying to optimize them during linking, to boost our performance again. I normally enable this. If you picked clang, I recommend you choose an LTO mode, depending on your use case. I prefer `full` here.

(More about LTO [here](https://llvm.org/docs/LinkTimeOptimization.html))

## Realtime Kernel???

The following 2 options are for generating a realtime kernel image. If you don't know what that means, set them to `0`. We are then asked about our CPU scheduler yield type, the safe answer here is `0`, but feel free to read it and adjust for your usecase. This also applies for the Round Robin interval, your best bet here is `default` unless you know what you are doing.

## More performance tweaks:

Our next two options **can** give us some extra performance, **but** the numadisable flag **may break CUDA/NvEnc on Nvidia and ROCm/OpenCL on AMD**. The ftracedisable flag disables some debugging functions, lowering overhead, increasing performance.

The next option can be hit or miss, it adds miscellaneous patches and tweaks pending upstream, and can break on non-arch distributions, it`s safer to set this to false on non-arch.

Our next option controls our CPU idle ticks process. Putting a `2` there is recommended, but if you want full performance boost, go with `1`.

ACS override is for PCI passthrough, e.g. GPU passthrough to VM. If this pertains to you, answer true, otherwise false.

Bcachefs is a new experimental filesystem that was recently introduced into the kernel, promoted as a "better BTRFS". You can say `false` here unless you need bcachefs support.

After that we come across the winesync option, this has a description attached to it explaining that it`s an experiental replacement for esync, and requires a patched version of wine. This is used for running Windows applications on Linux, but with a patch applied to it. Do not enable this unless you know what you are doing.

Our next option is waydroid support. Waydroid is a special container system that can run Android applications "natively" in linux. What this option does is prepare the kernel to support waydroid, by enabling the Android `binder` and `ashmem` kernel modules. If you use waydroid, or want Android app support, enable this option. The following option is Anbox, which is similar, but is deprecated and replaced by waydroid these days.

Zenify, the mack daddy of why we`re here. This pulls in the patches from the Zen and Liquorix kernel, and some other tweaks for better a gaming performance.

Our next two options are all about optimization of the code of the kernel. You can choose a kernel compiler optimization level in our first option `copileroptlevel`. I normally pick `2` here, for (-O3) optimizations, you can safely enter `1` for the standard kernel optimizations if you wish, and `3` to optimize the kernel for the smallest file size after compilation (-Os).
`processor_opt` is one of my favorite optimizations here, this allows you to pass flags to the compiler the compile the kernel specifically for your CPU generation. Got a Zen 2 CPU? We have a choice for you. Zen 3? Got you. Intel chips? We got you. If in doubt, you can use a generic option here.

Some of the next options only apply in certain scenarios, so some of these will not apply to you, please read them carefully to see if they apply to your use case. This covers the `calcule_rdb` through the `random_trust_cpu` options.

The `timer_freq` should generally be set to the highest number on a desktop, and the lowest on a server. If you're running a server off a desktop that you still use as a desktop, I have found `750` to be a nice middleground between throughput and performance.

Our next choice is the default CPU governor. This controls how the CPU steps through it's frequencies. Adjust this to your liking. If you choose `ondemand`, the option below can be used to enable a new `ondemand` algorithm that is designed to increase performance.

The following option is the network TCP algorithm to use. You can leave this as the default unless you have a reason and know what you are doing. The line after this is the `custom_commandline` option. This is what you see in your GRUB bootloader entry after the kernel image is specific in `linux /boot/vmlinuz` where it starts normally with `ro`. These are kernel command line flags that change how the kernel/init system operate from the boot level. You should research what these are before you start messing with them, as you can harm your system by doing the wrong things here.

The last option of the kernel options it the Intel Clear Linux patches toggle. This pulls in patches from Intel`s Clear Linux, bringing more performance for Intel platforms. AMD users can say no here, but there is no harm in saying yes.

## Are we done yet???

Oh no, we still have a few more options to go through, this is what makes the TKT kernel project such an amazing tool, the level of customization that you have out of the box is amazing.

Now we reach the "SPESHUL OPTIONS" which you may or may not be interested in, you can safely skip these if you want to, but I recommend giving the descriptions a read to see what they do.

Onto the "LEGACY OPTIONS". Our first 4 options can be safely ignored if you are compiling any kernel over 5.15, otherwise, read the descriptions and use them as you need to. The first 3 options are normally used for gaming optimizations. The last option `zfsfix` is a patch to make the ZFS filesystem work on kernels older than 5.15 and can be ignored on kernels newer than this.

Our next option is the `runqueue_sharing` option, the kernel default is `smt`, but if you have an AMD Zen series CPU, you should use `mc-llc` here. Most people with multi-core CPU`s will want to run `mc`.

`irq_threding` only applies if you are using the MuQSS CPU scheduler. It forces IRQ threading. I do not know what this is.

The final option here in "LEGACY OPTIONS" is an amazing system that you should enable on any kernel above 5.18. `mglru` improves the memory pressure handling system of the Linux kernel, allowing the system to better manage the RAM usage. This will be disabled though if you enabled bcachefs support.

The final four options of the file, here we go, let's wrap up with this `customization.cfg` file already. There is a section for user patches. This is self explanatory, if you have patches you want to apply to a kernel, make a directory for that kernel version (e.g. kernel 6.7 patches would go in `linux6.7-userpatches/`). The last two options are used for keeping whatever changes you make to the kernel config file after running menuconfig/nconfig to a fragment that you can apply again later, to keep changes to apply to new kernels.

## It`s finally install time:

Wow, that was a lot, but let's save our file, and now, we have a fully automated installation of the TKT kernel, no more questions asked every time we compile. Now comes the fun part, it`s time to take all this hard work and compile the kernel. The directions take a small divergence, but then recombine back down the same path (for the most part).

## ARCH USERS:

Now it is time to begin the compile and installation process. We will begin this by running `makepkg -si` in the `TKT` folder. This will launch the script, asking you for a kernel version if you did not specify it already in `customization.cfg`. This process should be straight forward, asking you any questions that you did not answer in the `customization.cfg` file, or that may have invalid answers for the kernel version.

This will begin to compile a kernel, if you enabled the menuconfig/nconfig option, you will be greated with it at some point, after exiting this, the kernel will continue compiling until it completes. At this point it will generate 2 `.zst` package files and install them through `pacman`, allowing you to manage the kernel through your package manager.

At this point, you may have to generate a new bootloader entry for the new kernel, if it did not already, this will vary from setup to setup. After this is completed, reboot and enjoy the new kernel.

## NON-ARCH USERS:

We sadly don't have the ability to run `makepkg` in non-arch distributions, so we are provided with a script file instead called `install.sh`. This script has 3 options, `config` and `install`, install has 3 sub-options `DEB`, `RPM`, and `Generic`. `uninstall-help` will list any installed kernels on your system, and provide you with hints on how to uninstall them from the system.

You should most of the time just run `bash ./install.sh install` you can specify your package format if you want, but it's not needed if you pick the distro in the script when it asks or have it set in `customization.cfg`. This will launch the process and ask you any questions that are not answered in the `customization.cfg` file, or that are incorrect for that kernel version. If you enabled menuconfig/nconfig, this will pop up at some point, and when you exit out of it, it will finish compiling the kernel.

Depending on the system, you will get `.deb`, `.rpm`, or a generic kernel package, which you can install through your package manager, to make maintaining as easy as installing and removing your stock kernel.

## CONCLUSION:

This is a crash course guide to get you comfortable working with the TKT kernel, and should for the most part, get you to a working kernel build. This is by no means a full on official step by step guide of how to compile a kernel, the TKT way or the standard Linux way. This is a project that I (ETJAKEOC) have taken my time to generate in order to help me bring more users to the same project that brings me great joy using my computer. I have noticed many performance boosts using the TKT kernel over the stock kernel on my machines, and love the install script and it`s options. This is why I forked it and wrote up this guide to go alongside it, in an attempt to encourage others to play with their kernels, and show that that it is not a scary place to work in.

## SUPPORT:

Support results may vary. Keep in mind at the end of the day, I am not a developer, let alone a kernel developer. I am just some guy who can read files, understand things, and experiment. The choices I have made for my defaults may not always work for you, when in doubt, go with the default recommended in the `customization.cfg` file. If all else has failed, you can find me on [The Linux Cast Discord server](https://discord.gg/KHckz5RTJs). Please feel free to join us, start a #tech-support thread, and tag me (ETJAKEOC) in the thread, I will be along to assist you when I can.
