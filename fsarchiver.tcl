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

proc getarchtype {archinfo} {
    # returns fsarchiver archive type from archinfo output
    set archinfo [split $archinfo \n]
    foreach line $archinfo {
       if {[string first "Archive type" $line] > -1} {
          set ll [split $line :]
          return [string trimleft [lindex $ll end]]
       }
    }
    return ""
}

proc getcreatedate {archinfo} {
    # returns fsarchiver creation date from archinfo output
    set archinfo [split $archinfo \n]
    foreach line $archinfo {
       if {[string first "Archive creation date" $line] > -1} {
          set crdate [lindex [split $line] end]
          regsub -all -- {-} $crdate {} crdate
          return $crdate
       }
    }
    return ""
}

proc getfscount {archinfo} {
    # returns number of filesystems in the archive
    set archinfo [split $archinfo \n]
    foreach line $archinfo {
       if {[string first "Filesystems count" $line] > -1} {
          return [lindex $line end]
       }
    }
    return 0
}

proc getfstype {id archinfo} {
    # returns fsarchiver fstype for fs id from archinfo output
    set archinfo [split $archinfo \n]
    set idfnd 0
    foreach line $archinfo {
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

proc getrestoresize {id archinfo} {
    # returns fsarchiver original space used for fs id from archinfo output
    set archinfo [split $archinfo \n]
    set idfnd 0
    foreach line $archinfo {
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
          file attributes ${mountfsdir}/fsabackup_$fstype -permissions 0777
       }
       puts "mount $loopdev ${mountfsdir}/fsabackup_$fstype"
       catch {exec -- mount $loopdev ${mountfsdir}/fsabackup_$fstype} out
       puts $out
    }      
}

proc isrunning {fspid} {
    # TBD: use ::tcl::process for this.. (i.e. "ps" is always changing output behavior)
    catch {exec -- ps $fspid} pout
    if {[regexp -- defunct|abnormal $pout]} {return 0}
    return [expr {[llength [split $pout \n]] > 1}]
}

proc get_id_total_fsize {id2dev archinfo} {
    # Given list of $idfsa,dest=/dev/$dev and archinfo
    # return total number of bytes used in the original fs
    set sum 0
    foreach el $id2dev {
       set idndev [split $el ,]
       scan [lindex $idndev 0] "id=%d" fsaid
       lappend sum [getrestoresize $fsaid $archinfo]
    }
    return [expr [join $sum +]]
}

proc id2dev_ismounted {id2dev} {
    # Test if any of the destinations are mounted
    # Typically used when fsarchiver has been kicked off
    # (i.e. fsarchiver mounts the destination fs before
    #  doing a restfs)
    # Returns true if loop device is mounted
    foreach el $id2dev {
       set idndev [split $el ,]
       scan [lindex $idndev 1] "dest=%s" destfs
       catch {exec -- df --block-size 1 $destfs | tail -1} output
       if {[string compare [lindex $output end] "/dev"] != 0} {
          return 1
       }
    }
    return 0
}

proc get_total_used {id2dev} {
    # Given list of $idfsa,dest=/dev/$dev
    # return total number of bytes used in the dest filesystems
    set sum 0
    foreach el $id2dev {
       set idndev [split $el ,]
       scan [lindex $idndev 1] "dest=%s" destfs
       catch {exec -- df --block-size 1 $destfs | tail -1} output
       lappend sum [lindex $output 2]
    }
    return [expr [join $sum +]]
}

proc wait_for_fsarchiver_to_start {id2dev delay fspid} {
    # Make sure that fsarchiver is running
    set iwait 1
    while {[id2dev_ismounted $id2dev] == 0} {
        if {$iwait < 2} {
           puts "\n\nWaiting for fsarchiver to start writing"
           flush stdout
        } else {
           puts -nonewline "."
           flush stdout
        }
        after $delay 
        if {$iwait > 19} {
            # This seems to be the easiest way to preserve stderr as
            # (e.g.) a dialog will cover it up or garble it..       		
            puts "\n\nERROR: wasn't able to start fsarchiver - see stderr"
            puts "(e.g. Check that partitions are large enough for id(s))"
            flush stdout
            catch {exec -- kill -9 $fspid} output
            after 5000
            return 1
        }
        incr iwait       		
    }
    return 0
}

proc fsa_pbar {tag fsa delay fsize id2dev fspid} {
    # Display a dialog gauge for fsarchiver restfs. The current man page for exec describes
    # using expect instead of tclsh for TUIs (which I obviously disagree with).
    #
    # i.e. " It is desirable to have console applications hidden and detached"
    #
    # There are two very good reasons for not using expect: 1. It isn't maintained, 2. It is overkill
    # and introduces unnecessary failure possibilities.
    #
    
    global configdir tclsh env
    set pvalue 0
    set env(DIALOGRC) ${configdir}/autumndc.rc

    # Make sure that fsarchiver is running 
    set wdelay 2500
    if {[wait_for_fsarchiver_to_start $id2dev $wdelay $fspid]} {
    	return
    }    
    set fd3 [file tempfile fsa_gauge]
    puts $fd3 [subst {#!$tclsh}]
    puts -nonewline $fd3 [subst {proc id2dev_ismounted {[info args id2dev_ismounted]}}]
    puts $fd3 " {"
    puts $fd3 [info body id2dev_ismounted]
    puts $fd3 " }"
    
    puts -nonewline $fd3 [subst {proc get_total_used {[info args get_total_used]}}]
    puts $fd3 " {"
    puts $fd3 [info body get_total_used]
    puts $fd3 " }"
    
    puts $fd3 {global env}
    puts $fd3 [subst {set env(DIALOGRC) ${configdir}/autumndc.rc}]
    
    puts $fd3 {set dcom {|dialog --erase-on-exit }}
    puts $fd3 [subst {append dcom {--backtitle "FSArchiver $tag $fsa" }}]
    puts $fd3 [subst -nobackslashes {append dcom {--gauge "Execute:\n    fsarchiver $tag $id2dev" 16 80 0 }}]  
    
    puts $fd3 [subst {set fsize $fsize}]
    puts $fd3 {set pvalue 0}
    puts $fd3 {set fd3 [open $dcom w]}
    puts -nonewline $fd3 [subst -nocommands {while {[id2dev_ismounted $id2dev]}}]
    puts $fd3 " {"      
    puts $fd3 [subst {   after $delay}]
    puts $fd3 [subst -nocommands {   set lsize [get_total_used $id2dev]}]
    puts $fd3 {   set value [expr {100.*$lsize/$fsize}]}
    puts $fd3 {   set value [expr {max($value,$pvalue)}]}
    puts $fd3 {   set value [expr {min(${value},99.0)}]}
    puts $fd3 {   set dvalue [expr {round(${value})}]}
    puts $fd3 {   if {$dvalue < 0 || $dvalue > 99} {continue}}
    puts $fd3 {   puts $fd3 "${dvalue}\nXXX\n${dvalue}"}
    puts $fd3 {   puts $fd3 "Progress: ${lsize} of ${fsize} bytes ([format %.2f%% ${value}])"}
    puts $fd3 {   puts $fd3 "XXX"}
    puts $fd3 {  flush $fd3}
    puts $fd3 {  set pvalue $value}  
    puts $fd3 " }"
    puts $fd3 {close $fd3}
    puts $fd3 "catch {exec -- reset} istat out"
    puts $fd3 [subst {file delete $fsa_gauge}]    
    puts $fd3 [subst {catch {exec -- kill -15 $fspid} istat out}]
    puts $fd3 {exit}
    close $fd3
    
    file attributes $fsa_gauge -permissions u+rwx
    # Putting dialog gauge in the background seems to be the only way to get it to render proper consistently.
    # Also, the parent tclsh when called from mc must be a child process and not a grandchild+. i.e. dialog
    # must have access to the controlling shell (aka console as referred to currently 01/09/26 - I always 
    # considered "console" to refer to the start up shell of the hardware on bootup. i.e. there is one and 
    # only one console on any one machine - but, the usage of "console" has changed in software circles..)
    catch {exec $fsa_gauge &} ggpid istat
    while {[isrunning $fspid]} {
       after 250
    }
    # fsarchiver process status now returns defunct because it's been forced to stop before issuing its
    # statistical output (I'd like an fsarchiver switch for this - but, not likely to happen unless I submit
    # a PR). However, defunct is good enough as the parent process can now be killed and the OS will 
    # clean up.
    while {[isrunning [pid]]} {
    	catch {exec kill -9 [pid] &} istat out
    	after 250
    }
    return
}

proc get_disk_part_list {} {
    # Returns list of restorable disks and partitions
    # - A partition is only restorable if it is not mounted
    # - A disk is only restorable if one of the following is true:
    #    1. it has no partitions and it isn't mounted
    #    2. it has more than one restorable partition
    
    # lsblk filter set here will not list mounted partitions or disks, but, it will
    # list disks that have mounted partitions..
    set filter {lsblk --filter 'MOUNTPOINT !~ "/"' }
    append filter {--inverse --nodeps --noempty --list --exclude 7,9,11 --noheadings }
    append filter {-o NAME,SIZE,TYPE,FSTYPE,TRAN,PARTTYPENAME,LABEL}
    catch {exec -- bash -c $filter} lsblk
    set lsblk [split $lsblk \n]
    set l1 [lsort -unique [lsearch -regexp -all -inline $lsblk disk]]
    set l2 [lsort -unique [lsearch -regexp -all -inline $lsblk part]]
    set l1n {}
    foreach l1e $l1 {
       set device [lindex $l1e 0]
       catch {exec -- lsblk --list --noheadings -o NAME /dev/$device} devlist
       set np [expr [llength $devlist] - 1]
       # Condition 1
       if {$np == 0} {
          lappend l1n $l1e
          continue
       }
       # Condition 2
       set l2s [lsearch -regexp -all -inline $l2 $device]
       if {[llength $l2s] > 1} {
          lappend l1n $l1e
       }          
    }
    set lsblk [concat $l1n $l2]

}

proc get_disk_part_dialog {fsa} {
    # Presents radiolist dialog of disks and partitions to restore to
    global configdir env
    # Include only standard storage devices for now (e.g. disks, usb, nvme).
    set lsblk [get_disk_part_list]
    for {set ii 1} {$ii <= [llength $lsblk]} {incr ii} {
        lappend items [subst {$ii "[lindex $lsblk $ii-1]" off}]
    }
    # Present disks at the top (and partitions at the bottom) of the dialog
    #    Can only select one item, if it is a disk then all partitions of the disk can be
    #    restored (i.e. if there are partitions), otherwise the individual item selected
    #    can be restored (to).
    set dcom {dialog --output-fd 1 --erase-on-exit --backtitle "FSArchiver restfs $fsa" }
    set dcom [subst $dcom]
    append dcom {--keep-tite --radiolist "Select disk or partition:" 16 100 0 }
    catch {append dcom [join $items " "]}
    set env(DIALOGRC) ${configdir}/autumndc.rc
    file tempfile tmpfile
    set istat [catch {exec bash -c $dcom 2>$tmpfile} choice]
    if {[string is digit -strict $choice]} {
        set dev [lindex [lindex $lsblk [incr choice -1]] 0]
        set devt [lindex [lindex $lsblk ${choice}] 2]
        return [list $dev $devt]
    }
    return
}

proc get_archive_restore_buildlist_dialog {archinfo device device_type} {
    # A buildlist dialog displays two lists, side-by-side. The list on the left shows 
    # unselected items. The list on the right shows selected items. As items are 
    # selected or unselected, they move between the lists.
    # 
    # In this usage, the selected items will reflect the desired filesystem restoral
    # mapping
    global configdir env
    
    # Create unselected entries for each fsarchive id
    for {set ii 0} {$ii < [getfscount $archinfo]} {incr ii} {
        set fstype [getfstype $ii $archinfo]
        lappend items [subst {id=$ii "id=$ii $fstype" off}]
    }
    # Get device info to populate information text at the top of the dialog and
    # a simple list of the device and partitions it may contain
    catch {exec -- lsblk -o NAME,SIZE,TYPE,PARTTYPENAME,LABEL /dev/$device} devinfo
    catch {exec -- lsblk --list --noheadings -o NAME /dev/$device} devlist
    # Insert enough "skip" items as the number of partitions minus one.
    set nchoice 1
    if {[string match $device_type disk]} {
        if {[llength $devlist] > 1} {
            set devlist [lrange $devlist 1 end]
            set ndev [llength $devlist]
            if {$ndev > 1} {
                foreach part [lrange $devlist 1 end] {
                    lappend items {"skip" "-- skip partition --" off}
                }
                set nchoice "1 - $ndev (MAX)"
            }
        }
    }
    # Populate a dialog command with the information from the lists: devinfo and items
    set dcom {dialog --output-fd 1 --erase-on-exit --backtitle }
    append dcom [subst {"FSArchiver restore (${device})" }]
    append dcom {--title "Select items to map to partitions" }
    append dcom {--separate-output --reorder --buildlist }
    foreach line [split $devinfo \n] {
        append dcom [subst {"${line}\\n"}]
    }
    append dcom [subst {"\\nChoose $nchoice item}]
    if {[string length $nchoice] > 1} {
        append dcom {(s) in desired order}
    }
    append dcom {:" }
    append dcom { 0 80 20 }
    catch {append dcom [join $items " "]}
    set env(DIALOGRC) ${configdir}/autumndc.rc
    file tempfile tmpfile
    # Execute the dialog command and it will return buildlist
    set istat [catch {exec bash -c $dcom 2>$tmpfile} buildlist]
    if {$istat == 0} {
        set nmax [llength $devlist]
        set buildlist [lrange $buildlist 0 ${nmax}-1]
        set id2dev {}
        foreach idfsa $buildlist dev $devlist {
            if {[string match $idfsa skip] || [string match $idfsa {}]} {continue}
            lappend id2dev $idfsa,dest=/dev/$dev
        } 
        return $id2dev
    }
    return
}

proc final_restfs_checkpoint_and_go_ahead {fsa archinfo buildlist} {
    global configdir nthr env
    set msg    {"Execute:\n\n }
    append msg { \\Zb\\Z1fsarchiver restfs $fsa $buildlist\\Zn\n\n }
    append msg {    -Please check that the \\Zb\\Z1dest=\\Zn parts make sense\n }
    append msg {    -For example, there can only be as many dest= as there }
    append msg { are partitions on a device"}
    set msg [subst $msg]
    set dcom {dialog --no-label "Stop" --yes-label "Go" --default-button "no" }
    append dcom {--colors --title "Final checkpoint, go ahead?" }
    append dcom {--output-fd 1 --erase-on-exit --backtitle "FSArchiver restfs" }
    append dcom [subst {--keep-tite --yesno $msg 16 80 }]
    set env(DIALOGRC) ${configdir}/autumndc.rc
    set istat [catch {exec -- bash -c $dcom} output]
    if {$istat == 1} {
       # Stop
       return 0
    }
    # Go
    return 1
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
#    fsarchiver.tcl restfs archivename
#    fsarchiver.tcl mclocalmenu

source .fsarchiver.rc.tcl

set fsaid 1
if {[llength $argv] > 1} {
   set cmd [lindex $argv 0]
   set fsa [lindex $argv 1]
   if {[file isdirectory $fsa]} {
      set fsadir $fsa
      set fsa {}
   }
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

set archinfo {}
if {$cmd == "probe"} {
   catch {exec -- fsarchiver probe} probe
   puts $probe
   exit
}
if {[llength $fsa] > 0} {
    catch {exec -- fsarchiver -v archinfo $fsa} archinfo
    set archisfs [string match [getarchtype $archinfo] "filesystems"]
    if {$archisfs == 0 && $cmd != "view"} {
        # FSArchiver is able to back up directories also. These archive types do not require a
        # backing store file to manipulate and so, we just inform the user about this and don't
        # proceed with the copyout.
        puts "Error - $fsa type is: [getarchtype $archinfo]"
        exit 1
    }
}
switch $cmd {
    "view" {
       # Outputs archinfo of archive
       puts "fsa: $fsa"
       puts "$archinfo"
       exit
    }
    "copyout" {
        # Copy fsarchiver stored filesystem to backing store file
        # (backing store files are premade via fallocate (or dd) and mkfs). For example,
        # see: https://linuxconfig.org/how-to-create-a-file-based-filesystem-using-dd-command-on-linux
        # (In demo configuration, there are 3 backing store files: e.g. c200_{btrfs,ext4,vfat}.img)
        set fsys [getstoretype [getfstype $fsaid $archinfo]]        
        catch {exec -- losetup --find --show ${backfsdir}/${backfstag}_$fsys.img} loopdev
        catch {exec -- losetup -c $loopdev} output istat
        set label [getcreatedate $archinfo]
        set uuid [exec -- uuidgen --random]
        set id2dev "id=$fsaid,dest=$loopdev"
        set fsize [get_id_total_fsize $id2dev $archinfo]
        # Start up restfs and a progress bar
        set fscom [subst {exec -- fsarchiver -x -j$nthr restfs $fsa $id2dev,label=$label,uuid=$uuid 2>@1 &}]
        catch $fscom fspid istat
        if {[string is digit $fspid] && [isrunning $fspid]} {
            puts $fdebug "fspid: $fspid - starting up pbar"
            set delay 250                 
            fsa_pbar copyout $fsa $delay $fsize $id2dev $fspid
        } else {
        	puts "\n\nERROR: wasn't able to start fsarchiver"
        	puts "result: $fspid"
        	foreach key [dict keys $istat] {
            	puts "$key - [dict get $istat $key]"
        	}
        }
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
        for {set ii 0} {$ii < 2} {incr ii} {
            # Not sure why 2 times is necessary, even for multi mounts, but,
            # since it isn't expensive or problematic, I won't both with
            # looking into it for now.
            foreach fsys {ext4 btrfs vfat} {
                detach_backfile "${backfsdir}/${backfstag}_${fsys}.img"
            }
            catch {exec losetup --list} out
        }
        puts "\n$out"
        exit
    }
    "config" {
        puts "fsarchiver.tcl configuration:"
        puts "   configuration directory: ${configdir}"
        puts "   backing store directory: ${backfsdir}"
        puts "   mountpoint head: ${mountfsdir}"
        puts "   number of threads: ${nthr}"
        exit
    }
    "restfs" {
        # Regular FSArchiver filesystem restoral
        # Create dialog of disks and/or partitions to restore to
        # (currently raids aren't allowed but, I should look into this. I think
        #  if a raid can be backed up by fsarchiver then it can be treated like
        #  a simple partition)
        lassign [get_disk_part_dialog $fsa] dev devt
        if {[string length $devt] > 0} {        
            set buildlist [get_archive_restore_buildlist_dialog $archinfo $dev $devt]
            if {[llength $buildlist] < 1} {
            	exit
            }
            # buildlist is empty or it contains proper fsarchiver id=##,dest=sssss in each
            # list element.
            if {[final_restfs_checkpoint_and_go_ahead $fsa $archinfo $buildlist]} {
                set fsize [get_id_total_fsize $buildlist $archinfo]
                # Start up restfs and a progress bar
                set fscom [subst {exec -- fsarchiver -j$nthr restfs $fsa $buildlist 2>@1 &}]
                catch $fscom fspid istat
                if {[string is digit $fspid] && [isrunning $fspid]} {                   
                   fsa_pbar restfs $fsa 1000 $fsize $buildlist $fspid
                } else {
                   puts "\n\nERROR: wasn't able to start fsarchiver"
                   puts "result: $fspid"
                   foreach key [dict keys $istat] {
                      puts "$key - [dict get $istat $key]"
                   }
                }
                exit
            }
        } else {
            puts "No unmounted disks or partitions available"
        }
    }
    "mclocalmenu" {
        file copy $configdir/.mc.menu.template $fsadir/.mc.menu
        file attributes $fsadir/.mc.menu -owner root -permissions 0644
    }
    default {
       return
    }
}
