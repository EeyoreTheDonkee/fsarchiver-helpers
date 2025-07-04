# fsarchiver-helpers

fsarchiver: helper scripts and approach(es)

Leverage [FSArchiver](https://www.fsarchiver.org/), [Midnight Commander](https://midnight-commander.org/) (mc) and a linux OS, to enable some features not found in FSArchiver itself and perhaps mitigate some of the facility and data reflection issues.

_fsarchiver-helpers_ is for fsarchiver _filesystem_ backups

+ fsarchiver can back up directories (similar to tar, zip, etc.) and they are perhaps easier to deal with directly

## Benefits
+ [TUI](https://en.wikipedia.org/wiki/Text-based_user_interface) _enabled by mc_ e.g. menus, popups, keycodes, customization, etc.
+ FSArchiver:
  + file-system can be restored to a partition with different size and different file-system type
  + archives can be stored anywhere (i.e. vs snapshots that reside on the same media as the original)
+ fsarchiver-helpers:
  + archives can be inspected for content or meta-data via mc
  + fine grain restoral control (e.g. individual files, directories)
  + archive testing

## Overview 
Typical usage with mc is to: 

```bash
 sudo COLORTERM=truecolor mc --skin=seasons-autumn16M
```
+ navigate to a directory containing fsarchiver file-system archive file
+ keypress F2 and a menu of options will display:

![](images/mc_with_fshelp_menu.jpg)

+ Local menu shows items that include fsarchiver-helper operators and additional items as desired
  + Note that the copyout operators perform the bulk of the help, as they execute _fsarchiver restfs_ with desired parameters 
+ keypress \<ESC\> to dismiss the menu
+ select an archive of interest
+ keypress F2 and double-click an operator
+ Please see the [fsarchiver-helpers Users Guide](/../main/GUIDE.md) for more details

## Dependencies
+ Other than the main apps, the helper script requires [tclsh](https://sourceforge.net/projects/tcl/files/) (version 8.4+ but, 9.0+ is recommended)
+ elevated credentials

## Installation
+ Download [fsarchiver-helpers]() (e.g. via the green <> Code button)
+ create backingstore files via fallocate or dd c200_{btrfs,ext4,vfat} e.g. 200 GB files (can be any size)
  ```bash
  fallocate -l 200G /mnt/bees/c200_ext4.img
  fallocate -l 200G /mnt/bees/c200_btrfs.img
  fallocate -l 200G /mnt/bees/c200_vfat.img
  ```
  or something like (for older storage devices):
  ```bash
  dd if=/dev/zero of=/mnt/bees/c200_ext4.img bs=2M count=102400
  dd if=/dev/zero of=/mnt/bees/c200_btrfs.img bs=2M count=102400
  dd if=/dev/zero of=/mnt/bees/c200_vfat.img bs=2M count=102400
  ```
+ fsarchiver.tcl (must be in the path and executable, suggested location /usr/local/sbin)
  - edit fsarchiver.tcl
    - search for "Start of main script logic"
    - Change the values of the following parameters as desired:
      - **backfsdir** - location of backingstore files (e.g. /mnt/bees)
      - **backfstag** - prefix tag of backingstore files (e.g. c200)
      - **mountfsdir** - mount point head directory (e.g. /media/root)
      - **nthr** - number of fsarchiver compression threads (e.g. 8)
+ .mc.menu - copy template to archive directories e.g.

```bash
    cp .mc.menu.template /mnt/jagular/fsarchiver/Chrisrobin/trixie/.mc.menu
    sudo chown root /mnt/jagular/fsarchiver/Chrisrobin/trixie/.mc.menu
```
+ download tcl9.0+ and install (default install location is /usr/local/bin)

```bash 
    cd tcl/unix
    autoconfig
    ./configure
    make install
```

## Conventions/suggestions
   - The naming convention for the backingstore files (bsf) serves only as a queue to content
     - fsarchiver.tcl will inspect the file system type associated with an id in a backup file. Effectively, btrfs file system backups will be copied to the btrfs bsf, while filesytem types that contain the string "fat" will be copied to  the vfat bsf and everything else will be copied to the ext4 bsf e.g. c200_ext4.img. Since fsarchiver will actually format the bsf according to the filesystem type stored in the backup, the naming convention has no functional effect.
   - Note that the copyout progress bar waits for fsarchiver to terminate before it signals DONE
     - when done - selecting the “other” panel in mc will reset the mc command line
   - (TBW) using [Cherrytree](https://www.giuspen.net/cherrytree/) to codify backup & restoral steps on multiple systems
   - naming conventions for fsarchive archives
     - consistency and helpful names & directories that provide a queue to content is suggested
   - Combining mc with [konsole](https://konsole.kde.org) shortcuts or [qterminal](https://github.com/lxqt/qterminal) bookmarks
   - Combining [tmux](https://github.com/tmux/tmux/wiki) with mc
   

