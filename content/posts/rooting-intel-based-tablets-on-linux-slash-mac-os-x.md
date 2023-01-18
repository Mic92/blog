+++
title = "Rooting Intel Based Tablets on Linux Slash Mac Os X"
date = "2015-12-25"
slug = "2015/12/25/rooting-intel-based-tablets-on-linux-slash-mac-os-x"
Categories = []
+++

In this article I will explain how to root Intel-CPU based android Devices on
Linux/Mac OS X. The instructions are based on this
[forum post](http://forum.xda-developers.com/android/development/intel-android-devices-root-temp-cwm-t2975096).
I used this code to root a Medion LIFETAB P8912. However this should also apply
to all devices mentioned in this forum post.

The first thing to do, is install
[fastboot and adb](http://lifehacker.com/the-easiest-way-to-install-androids-adb-and-fastboot-to-1586992378)
on your PC/Mac. Make sure that you have enabled the development option on your
android device and are able to connect to it via adb.

Then place the update, you want to install on the sdcard on your device. In case
you want to install the root patch, you can download the latest
[SuperSU](http://download.chainfire.eu/supersu). **Note** that you will be not
able to install custom roms, if your bootloader is locked. If the signature
mismatch it will refuse to boot.

The next thing to do is to download and extract
[IntelAndroid-FBRL-07-24-2015.7z](https://www.androidfilehost.com/?fid=24052804347782876)
mentioned in the post. It contains a recovery images for CWM or TWRP and some
custom trigger code to start a temporary CWM Recovery Session on the device.
After reboot this session will be gone. But you can apply updates during the
session such as SuperSU. You will **not** be able to follow the exact
instructions from this forum post, because it contains a windows specific batch
file and windows executables. However these are just fancy wrappers around adb
and fastboot, so you can still use the contained images/launch code.

To reboot your device into the bootloader, connect it to your computer and run,
while it is turned on:

```console
$ adb reboot-bootloader
```

Within the boot loader, we will first put the alternate rescue image on the
device along with some custom launcher code. I first tried TWRP on my device,
but my touchscreen didn't work with it, so I sticked to CWM:

```console
# assuming you have changed to the directory of extracted archive:
$ fastboot flash /tmp/recovery.zip FB_RecoveryLauncher/cwm.zip
$ fastboot flash /tmp/recovery.launcher FB_RecoveryLauncher/recovery.launcher
```

The next thing to do is to trigger the device via fastboot to start our
recovery. The forum post contained 4 alternatives approaches based on the
android device. The following (T4) was working for me:

```console
$ fastboot oem start_partitioning; fastboot flash /system/bin/logcat FB_RecoveryLauncher/fbrl.trigger; fastboot oem stop_partitioning
```

This temporary replace logcat with a launcher. It is important to execute all
commands in one shot. Otherwise fastboot will fail to flash logcat.

If the command will not work for you, you could one of these commands:

```console
# T1
$ fastboot flash /sbin/adbd FB_RecoveryLauncher/fbrl.trigger; fastboot oem startftm
# T2
$ fastboot flash /system/bin/cp FB_RecoveryLauncher/fbrl.trigger; fastboot oem backup_factory
# T3
$ fastboot flash /sbin/partlink FB_RecoveryLauncher/fbrl.trigger; fastboot oem stop_partitioning
```

If everything works it should start the recovery image.
