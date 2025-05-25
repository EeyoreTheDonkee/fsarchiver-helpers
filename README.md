# fsarchiver-helpers

(DRAFT)

fsarchiver: helper scripts and assorted approaches

Leverage [FSArchiver](https://www.fsarchiver.org/), [Midnight Commander](https://midnight-commander.org/) and a linux OS, to enable some features not found in FSArchiver itself and perhaps mitigate some of the facility and data reflection issues.

1. dependencies
2. configuration of fsarchiver.tcl
3. installation
   - backfsdir - fallocate or dd c200_{btrfs,ext4,vfat}
   - mountfsdir - fsabackup_{btrfs,ext4,vfat}
4. how to use
5. conventions/suggestions
   - Note that copyout progress bar waits for fsarchiver to terminate before it signals DONE
      - when done - it might be useful to select the “other” panel in mc to reset the command line
   - Using cherrytree to codify backup & restoral steps
   - naming conventions
   - fsarchiver for filesystems, rsync for directories
   - some functionality could be put into fuser menus via “sudo”, etc. but, I have found this to be of limited use.
