# fsarchiver-helpers User Guide

![mc fsarchiver archinfo](images/mc_with_fshelp_menu.jpg)

> [!IMPORTANT]
> fsarchiver-helpers requires a _local_ .mc.menu file in the directory where the fsarchiver archive to be operated on resides

## How to Display info about an fsarchiver archive
In Midnight Commander (mc)

+ navigate to a directory containing fsarchiver file-system archive file
+ Select an achive e.g. backup-msata-chrisrobin-trixie-20250621.fsa
+ keypress F2 (or mouse click on the Menu button at the bottom of the mc interface)
+ double click on:

```
fsarchiver archinfo
```


+ The info is presented in the mc Internal File Viewer (e.g. below)
  - keypress F1 for more info on the Internal File Viewer
  - keypress \<ESC\> to dismiss each popup in turn

![mc fsarchiver archinfo](images/mc_fsarchiver_archinfo_view.jpg)

> [!TIP]
> for users who are not entirely familiar with mc, numbers next to menu items correspond to numbered function keys, you can use a corresponding keypress for most functions in mc (mc provides visual queues for most items i.e. which key to press). Even fsarchiver-helpers menu items could be assigned a keypress.

## Detection of filesystems

+ navigate to a directory containing a _local_ .mc.menu file
+ keypress F2
+ double click on + double click on:

```
fsarchiver probe
```

## How to copyout, mount and peruse an fsarchiver archive filesystem
