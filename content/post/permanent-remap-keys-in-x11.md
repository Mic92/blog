+++
title = "Permanent Remap Keys in X11"
date = "2013-10-16"
slug = "2013/10/16/permanent-remap-keys-in-x11"
Categories = []
+++

Because my shift key got broken, I remapped Caps Lock to Shift using xmodmap:

```
remove Lock = Caps_Lock
keysym Caps_Lock = Shift_L
add Shift = Shift_L
```

However these settings got sometimes lost. (ex: after the driver was reloaded after suspend).
Finally I found event_key_remap patch from [here](http://www.thenautilus.net/SW/xf86-input-evdev/en),
which allows to permanently redefine keys in the xorg.conf.

To apply the patch under archlinux simply install [xf86-input-evdev-remap](https://aur.archlinux.org/packages/xf86-input-evdev-remap/?setlang=de) from AUR:

    yaourt -S xf86-input-evdev-remap

To track down the key, you want to remap use `xev` on the terminal.
Just type the wanted keys a few times. The output will be something like
the following:

```
KeyRelease event,  serial 33,  synthetic NO,  window 0x1e00001,
    root 0x8e,  subw 0x0,  time 5672767,  (611, 262),  root:(613, 288),
    state 0x1,  keycode 50 (keysym 0xffe1,  Shift_L),  same_screen YES
    XLookupString gives 0 bytes:
    XFilterEvent returns: False
```

The interesting value here is the `keycode`.
Use this code to build your final xorg.conf.
In my case this was:

```
#/etc/X11/xorg.conf.d/10-kb-layout.conf
Section "InputClass"
    Identifier             "Keyboard Defaults"
    MatchIsKeyboard        "yes"
    Option                 "XkbLayout" "de"          # Replace this with your layout
    Option                 "event_key_remap" "58=50" # Caps Lock Key = Shift
EndSection
```
