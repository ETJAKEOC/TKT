# CONTRIBUTION GUIDELINE
### These are the basic contribution guidelines for the project.

I am not all *that* picky about how this project evolves, I have a simple policy/goal with this project;
> Don't complicate it too much, but make the most performant kernel we can, without breaking generic support.
> I'm looking for patches that can be applied on a generic scale, something that will benefit everyone, 
> not just specific hardware.
> Possibly adding in a structure for adding specific patches for custom hardware, things like Steamdeck
> patches, Android device support, Microsoft Surface devices, etc etc.

All in all, the goal is to keep the user in control of their kernel. We will provide them with a nice
baseline to start with, with kernel debugging (mostly) disable as it should be in a production level kernel,
small tweaks to what compression algorithms the kernel/initramfs use to aim for speed during boot,
switching the zswap/zram compression algorithims to take advantage of multi-core CPU's,
removing support for CAN bus and HAM radio hardware for desktop PC kernels, this list goes on and on.

The main contribution to this project is to simply run it. If you can run this kernel on more hardware
this will help us to debug any issues that may arise from our tunings, and we can address them.

If you are interested in contributing to this project, please, feel free to fork it, and do some work.

You can contact me on Discord @ETJAKEOC

Thank you for taking the time to read this, and I hope you enjoy the work.

- ETJAKEOC
