# fsarchiver-helpers

(DRAFT)

fsarchiver: helper scripts and approach(es)

Leverage [FSArchiver](https://www.fsarchiver.org/), [Midnight Commander](https://midnight-commander.org/) (mc) and a linux OS, to enable some features not found in FSArchiver itself and perhaps mitigate some of the facility and data reflection issues.

1. Overview 

-Typical usage with mc is to navigate to a directory containing fsarchiver file-system archive file, select an archive of interest, keypress F2 and a menu of options will display:
	
	Menu items include:
		1. probe
		2. archinfo (to inspect metadata)
		3. copyout id=0
		4. copyout id=1
		5. copyout id=n (a prompt for any id)
		6. mount/unmount
		7. configuration (info)
		
	Additional user specified options as desired


-Note that the copyout functions perform the bulk of the help, as they execute fsarchiver with desired parameters to make the archive contents available for perusal, etc.
	
2. Dependencies

	Other than the main apps, the helper script requires [tclsh](https://sourceforge.net/projects/tcl/files/) (version 8.4+ but, 9.0+ is recommended), 

3. Configuration

	fsarchiver.tcl, mc local menu
4. Installation
   - backfsdir - fallocate or dd c200_{btrfs,ext4,vfat}
   - mountfsdir - fsabackup_{btrfs,ext4,vfat}
5. Conventions/suggestions
   - Note that copyout progress bar waits for fsarchiver to terminate before it signals DONE
      - when done - it might be useful to select the “other” panel in mc to reset the command line
   - Using [Cherrytree](https://www.giuspen.net/cherrytree/) to codify backup & restoral steps
   - naming conventions
   - fsarchiver for filesystems, rsync for directories
   - some functionality could be put into fuser menus via “sudo”, etc. but, I have found this to be of limited use.
   - I have found that mc combined with konsole or qterminal is very helpful.
