#!/usr/local/bin/tclsh9.0
# Helper script used to copyout and/or peruse an fsarchiver archive
# Used together with mc (midnight commander) and "local menus" i.e. .mc.menu
#
# (outputs tui progress bar for copyouts of large filesystems stored in an archive)

proc getstoretype {str} {
    # returns 3 storage types that are fairly general/flexible
    set fstype ext4
    if {[string first btrfs $str] > -1} {
       set fstype btrfs
    } elseif {[string first fat $str] > -1} {
       set fstype vfat
    }
    return $fstype
}

proc getarchtype {output} {
    # returns fsarchiver archive type from archinfo output
    set output [split $output \n]
    foreach line $output {
       if {[string first "Archive type" $line] > -1} {
          set ll [split $line :]
          return [string trimleft [lindex $ll end]]
       }
    }
    return ""
}

proc getfstype {id output} {
    # returns fsarchiver fstype for fs id from archinfo output
    set output [split $output \n]
    set idfnd 0
    foreach line $output {
       if {[string first "Filesystem id in archive" $line] > -1} {
          set ll [split $line]
          set cid [lindex $ll end]
          if {$cid == $id} {
             set idfnd 1
          }
          continue
       }
       if {[string first "Filesystem format" $line] > -1 && $idfnd} {
          set ll [split $line :]
          set fstype [string trim [lindex $ll end]]
          return $fstype
       }
    }
    return ""
}

proc getcreatedate {output} {
    # returns fsarchiver creation date from archinfo output
    set output [split $output \n]
    foreach line $output {
       if {[string first "Archive creation date" $line] > -1} {
          set crdate [lindex [split $line] end]
          regsub -all -- {-} $crdate {} crdate
          return $crdate
       }
    }
    return ""
}

proc getrestoresize {id output} {
    # returns fsarchiver original space used for fs id from archinfo output
    set output [split $output \n]
    set idfnd 0
    foreach line $output {
       if {[string first "Filesystem id in archive" $line] > -1} {
          set ll [split $line]
          set cid [lindex $ll end]
          if {$cid == $id} {
             set idfnd 1
          }
          continue
       }
       if {[string first "Space used" $line] > -1 && $idfnd} {
          set ll [split $line]
          set fsize [string trimleft [lindex $ll end-1] "("]
          return $fsize
       }
    }
    return ""
}

proc detach_backfile {fname} {
    # frees backing store mount point and loop device
    
    # Determine the loop device that fname has been attached to
    catch {exec -- losetup -j $fname} out
    if {[string length $out] > 0} {
       # Unmount it (if necessary) and free up the loop device
       set out [split $out :]
       set loopdev [lindex $out 0]
       set istat [catch {exec -- df --output=target $loopdev | tail -1} mntpoint]
       puts "loopdev: $loopdev mntpoint: $mntpoint istat: $istat"
       if {$istat == 0} {
          if {[string compare "/dev" $mntpoint]} {
             catch {exec -- umount $mntpoint}
          }
       }
       catch {exec -- losetup -d $loopdev}
    }       
}

proc mount_backfile {fname} {
    # mount backing store loop device to pre-made mount point
    global backfsdir mountfsdir backfstag
    set fstype [getstoretype $fname]
    # Determine the loop device that fname has been attached to
    catch {exec -- losetup -j $fname} out
    if {[string length $out] > 0} {
       set out [split $out :]
       set loopdev [lindex $out 0]
    } else {
       # attach to a new one
       catch {exec -- losetup --find --show ${backfsdir}/${backfstag}_${fstype}.img} loopdev
    }
    # Test if loopdev is already mounted
    set istat [catch {exec -- df --output=target $loopdev | tail -1} mntpoint]
    if {$istat != 0} {
       set mntpoint /dev
    }
    # If it isn't mounted then mount it on one of the pre-made mount points
    if {[string match "/dev" $mntpoint]} {
       # for progress bar..
       if {![file exists ${mountfsdir}/fsabackup_$fstype]} {
          file mkdir ${mountfsdir}/fsabackup_$fstype
          file attributes ${mountfsdir}/fsabackup_$fstype -permissions 0755
       }
       puts "mount $loopdev ${mountfsdir}/fsabackup_$fstype"
       catch {exec -- mount $loopdev ${mountfsdir}/fsabackup_$fstype} out
       puts $out
    }      
}

proc isrunning {fspid} {
    catch {exec -- pidstat -p $fspid} output
    return [expr {[llength [split $output \n]] > 3}]
}

proc copyout_pbar {delay fsize loopdev fspid {value 0}} {
    # writes a tui progress bar to mc command line
    global copyout_done
    set bar_size 40
    set done [expr round($bar_size * $value / 100)]
    set todo [expr $bar_size - $done]
    # set fbox instead of \#
    set fbox [format %c 0x2588]
    set done_sub_bar [string repeat ${fbox} ${done}]
    set todo_sub_bar [string repeat - ${todo}]
    set pvalue $value
    # output the bar
    puts -nonewline "\rProgress : \[${done_sub_bar}${todo_sub_bar}\] [format %5.2f%% ${value}]"
    flush stdout
    if {[isrunning $fspid]} {
       catch {exec -- df $loopdev | tail -1} output
       set value [expr {102400.*[lindex $output 2]/$fsize}]
       set value [expr {max($value,$pvalue)}]
       set value [expr {min(${value},99.99)}]
    } else {
       set value 100.0
    }
    if {$value >= 100.0} {
        puts -nonewline [format "\rProgress : \[%${bar_size}s\] DONE." {}]
        flush stdout
    	set copyout_done done
    	return
    }
    after $delay [list copyout_pbar $delay $fsize $loopdev $fspid $value]
}

# Start of main script logic
# Usage:
#    fsarchiver.tcl probe
#    fsarchiver.tcl archivename
#    fsarchiver.tcl copyout id archivename
#    fsarchiver.tcl mount
#    fsarchiver.tcl unmount
#    fsarchiver.tcl mountall
#    fsarchiver.tcl config

# Backing store directory
const backfsdir /mnt/bees
# Backing store tag
const backfstag c200
# Copyout mount point head
const mountfsdir /media/root
# Number of compression threads
const nthr 8

set fsaid 1
if {[llength $argv] > 1} {
   set cmd [lindex $argv 0]
   set fsa [lindex $argv 1]
   if {[llength $argv] > 2} {
      set fsaid [lindex $argv 1]
      set fsa [lindex $argv 2]
   }
   
} else {
   if {[file exists [lindex $argv 0]]} {
      set cmd "view"
      set fsa [lindex $argv 0]
   } else {
      set cmd [lindex $argv 0]
      set fsa {}
   }
}

if {$cmd == "probe"} {
   catch {exec -- fsarchiver probe} output
   puts $output
   exit
}
if {[llength $fsa] > 0} {
    catch {exec -- fsarchiver -v archinfo $fsa} output
    set archisfs [string match [getarchtype $output] "filesystems"]
}
switch $cmd {
    "view" {
       puts "fsa: $fsa"
       puts "$output"
       exit
    }
    "copyout" {
        if {$archisfs == 0} {
           # fsarchiver is able to back up directories also. These archive types do not require a
           # backing store file to manipulate and so, we just inform the user about this and don't
           # proceed with the copyout.
           puts "Error - $fsa type is: [getarchtype $output]"
           exit 1
        }
        # Copy fsarchiver stored filesystem to backing store file
        # (backing store files are premade via fallocate (or dd) and mkfs). For example,
        # see: https://linuxconfig.org/how-to-create-a-file-based-filesystem-using-dd-command-on-linux
        # (in the default case we have 3 backing store files: c200_{btrfs,ext4,vfat}.img, formatted as
        #  one might expect..)
        
        # perhaps inputs (e.g. fs-id) could be queried via mc instead of hardwiring it in mc menus
        # mc makes provision for this via ${query text} mechanism - but hardwiring a few options saves
        # several mouse and key clicks..
        set fsys [getstoretype [getfstype $fsaid $output]]        
        catch {exec -- losetup --find --show ${backfsdir}/${backfstag}_$fsys.img} loopdev
        set label [getcreatedate $output]
        set uuid [exec -- uuidgen --random]
        set fsize [getrestoresize $fsaid $output]
        # Start up restfs and a progress bar
        catch {exec -- fsarchiver -x -j$nthr restfs $fsa id=$fsaid,dest=$loopdev,label=$label,uuid=$uuid 2>@1 &} fspid
        copyout_pbar 62 $fsize $loopdev $fspid
        vwait copyout_done
        exit
    }
    "mount" {
        # mounts backingstore files that have been modified in the last hour
        foreach fsys {ext4 btrfs vfat} {
           	set msec [expr [clock seconds] - [file mtime ${backfsdir}/${backfstag}_${fsys}.img]]
           	if {$msec < 3600} {
              	mount_backfile "${backfsdir}/${backfstag}_${fsys}.img"
           	}
        }
    	exit
    }
    "mountall" {
        # mounts all backingstore files
        foreach fsys {ext4 btrfs vfat} {
            mount_backfile "${backfsdir}/${backfstag}_${fsys}.img"
        }
    	exit
    }
    "unmount" {
        # unmounts all backingstore files, frees up corresponding loop devices
        foreach fsys {ext4 btrfs vfat} {
            detach_backfile "${backfsdir}/${backfstag}_${fsys}.img"
        }
        catch {exec losetup --list} out
        puts "\n$out"
    	exit
    }
    "config" {
        puts "fsarchiver.tcl configuration:"
    	puts "   backing store directory: ${backfsdir}"
    	puts "   mountpoint head: ${mountfsdir}"
    	puts "   number of threads: ${nthr}"
        exit
    }
    default {
       exit 1
    }
}


