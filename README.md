Script to build ST Microelectronic's version of OpenOCD on MacOS
================================================================

Introduction
------------

This script helps building a statically-linked binary of OpenOCD for MacOS, based on the code customized by 
ST Microelectronics.


### OpenOCD

OpenOCD is an open-source tool for using On-Chip Debuggers. According to its documentation:
"The Open On-Chip Debugger (OpenOCD) aims to provide debugging, in-system program ming and boundary-scan testing for 
embedded target devices. It does so with the assistance of a debug adapter, which is a small hardware module which
helps provide the right kind of electrical signaling to the target being debugged."

For more information, refer to [the OpenOCD web site](https://openocd.org/)


### ST Microelectronics version of OpenOCD

OpenOCD provides support for a lot of different target devices and debug adapters. However, some of the devices and
adapters manufactured by ST Microelectronics (as part of theire STM32 line) are not supported out of the box.

ST Microelectronics provides enhancements to the OpenOCD source code in order to support such devices. Unfortunately,
ST's modifications are not merged in the main code base. Hence, a specific version needs to be built and used in order
to support these devices.

The modified source code is available [on ST's github](https://github.com/STMicroelectronics/OpenOCD)


### Why build OpenOCD

ST provides a pre-build OpenOCD as part of their development tools (STM32CubeIDE). However, last time I checked, this
build does not contain the configuration files (TCL scripts) needed to support non-ST hardware. Furthermore, it is not
clear wheher distributing this build is allowed, and it's not necesarily convenient to get the whole development package
if you only need OpenOCD.

Hence, building OpenOCD from scratch may be a better approach for you. Or not.


### Why a static build

In order to generate a build which can easily be distributed, depending on external libraries is problematic if you
don't want to fit into a specific packaging system such as homebrew or MacPorts.

A solution is to perform a static build, i.e. a build that does not have any significant external dependency on top of
the OS. Technically, it mans building all dependencies as static libraries, and ensuring the resulting binary is
statically linked against those libraries.

Building OpenOCD from source is not actually complicated, especially if you already have the required libraries on your
system. However, making sure you do not use any of the shared libraries on your system is actually trickier, hence this
script.



Script usage
------------

This GIT repository includes the OpenOCD dependencies as submodules in the `src/` sub-directory.

The script will perform an out-of-tree build of each dependency, ensuring each component is used explicitely for
building the subsequent items. Configuration of each component is specifically tailored for its use by OpenOCD.

The build process is an ordered sequence of individual steps; each step expectes the previous to have been
performed successfully. To perform a build, simply run `build.sh all`.

It is possible to specify more specific (sub-)steps, for troubleshooting purposes for example. One or more
specific steps can hence be specified on the command-line. Here is the tree of all possible steps:

    Step/Sub-steps                   Description
    ---------------------------------------------------------------------------------------------
    - all                            build everything and clean the interim build files
      +-- all-noclean                build everything, keep the intermin build files
      |   +-- clean-build            clean the (previous) iterim build files
      |   +-- libusb                 configure+build libusb
      |   |   +-- conf_libusb        configure stage of libusb
      |   |   +-- build_libusb       build stage of libusb
      |   +-- hidapi                 configure+build hidapi
      |   |   +-- conf_hidapi        configure stage of hidapi
      |   |   +-- build_hidapi       build stage of hidapi
      |   +-- libftdi                configure+build libftdi
      |   |   +-- conf_libftdi       configure stage of libftdi
      |   |   +-- build_libftdi      build stage of libftdi
      |   +-- libcapstone            configure+build libcapstone
      |   |   +-- conf_libcapstone   configure stage of libcapstone
      |   |   +-- build_libcapstone  build stage of libcapstone
      |   +-- OpenOCD                configure+build OpenOCD
      |   |   +-- conf_OpenOCD       configure stage of OpenOCD
      |   |   +-- build_OpenOCD      build stage of OpenOCD
      |   + assemble                 assemble binaries and other artefacts into output directory
      +-- clean-build                clean the interim build files
    
    - clean_all                      clean the interim build files as well as the output files
      +-- clean_build                clean the interim build files
      +-- clean_out                  clean the output directory
