# fsarchiver-helpers

(DRAFT)

fsarchiver: helper scripts and approach(es)

Leverage [FSArchiver](https://www.fsarchiver.org/), [Midnight Commander](https://midnight-commander.org/) (mc) and a linux OS, to enable some features not found in FSArchiver itself and perhaps mitigate some of the facility and data reflection issues.

## Benefits
+ FSArchiver:
  + file-system can be restored to a partition with different size and different file-system!
  + archives can be stored anywhere (i.e. vs snapshots that reside on the same media as the original - not safe)
+ fsarchiver-helper:
  + archives can be inspected for content or meta-data
  + fine grain control restoral (e.g. individual files)

## Overview 
Typical usage with mc is to: 
+ sudo COLORTERM=truecolor mc --skin=seasons-autumn16M
+ navigate to a directory containing fsarchiver file-system archive file
+ keypress F2 and a menu of options will display:

![](https://github.com/EeyoreTheDonkee/fsarchiver-helpers/blob/main/images/mc_with_fshelp_menu.jpg)

+ Local menu shows items that include fsarchiver-helper operators and additional items as desired
+ Note that the copyout operators perform the bulk of the help, as they execute fsarchiver with desired parameters 
+ keypress \<ESC\> to dismiss the menu
+ select an archive of interest
+ keypress F2 and double-click an operator

**More detailed manual TBW**

## Dependencies
+ Other than the main apps, the helper script requires [tclsh](https://sourceforge.net/projects/tcl/files/) (version 8.4+ but, 9.0+ is recommended)
+ elevated credentials

## Installation
+ fsarchiver.tcl
+ .mc.menu
- backfsdir - fallocate or dd c200_{btrfs,ext4,vfat}
- mountfsdir - fsabackup_{btrfs,ext4,vfat}

## Conventions/suggestions
   - Note that copyout progress bar waits for fsarchiver to terminate before it signals DONE
      - when done - it might be useful to select the “other” panel in mc to reset the command line
   - Using [Cherrytree](https://www.giuspen.net/cherrytree/) to codify backup & restoral steps
   - naming conventions
   - fsarchiver for filesystems, rsync for directories
   - some functionality could be put into fuser menus via “sudo”, etc. but, I have found this to be of limited use.
   - I have found that combining mc with konsole shortcuts or qterminal bookmarks is very helpful (I may describe or show examples of this at some point)

