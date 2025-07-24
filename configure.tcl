# Test for mc, fsarchiver and fallocate
foreach prog {mc fsarchiver fallocate} progdesc {{(Midnight Commander)} FSArchiver {}} {
	set progpath [auto_execok $prog]
	if {[string length $progpath] < 1} {
   		puts "ERROR: $prog $progdesc not installed or accessible"
   		exit 1
	}
}

# Check for fsarchiver.tcl in custom path
set fsadir [file dirname [auto_execok fsarchiver]]
set fsahexec [auto_execok fsarchiver.tcl]
if {[string length $fsahexec] > 16} {
   if {[string compare [file dirname $fsahexec] $fsadir]} {
       puts "ERROR: $fsahexec found - please rename or remove"
       exit 1
   }
}

# Get fsarchiver.tcl configuration
source .fsarchiver.rc.tcl
# The follwing variables should be available:
#    tclsh - Absolute path to tclsh9.0+
#    configdir - Configuration directory
#    backfsdir - Backing store directory
#    backfssize - Backing store size
#    backfstag - Backing store file/container prefix
#    mountfsdir - Copyout mount point head
#    nthr - Number of compression threads

# create configdir if it doesn't exist, and set its attributes
file mkdir $configdir
file attributes $configdir -permissions 00644
file copy -force .mc.menu.template .fsarchiver.rc.tcl autumndc.rc $configdir

# configure fsarchiver.tcl according to the rc.tcl file and set the attributes
regsub -- {/usr/local/bin/tclsh9.0} [readFile fsarchiver.tcl] $tclsh fsahexec
regsub -- {source .fsarchiver.rc.tcl} $fsahexec "source $configdir/.fsarchiver.rc.tcl" fsahexec
writeFile [file join $fsadir fsarchiver.tcl] $fsahexec
file attributes [file join $fsadir fsarchiver.tcl] -permissions 00755

# create backingstore files
file mkdir $backfsdir
file attributes $backfsdir -permissions 00666
foreach fsys {ext4 btrfs vfat} {
    set bsf "${backfsdir}/${backfstag}_${fsys}.img"
    if {[file exists $bsf]} {
       continue
    }
    set istat [catch {exec -- fallocate -l $backfssize $bsf} out]
    if {$istat} {
    	puts "fallocate -l $backfssize $bsf"
    	puts "   status message: $out"
    } else {
        puts "$bsf created, size: [file size $bsf] bytes"
        file attributes $bsf -permissions 00666
    }
}

# create mountpoints
foreach fsys {ext4 btrfs vfat} {
    if {![file exists ${mountfsdir}/fsabackup_$fsys]} {
        file mkdir ${mountfsdir}/fsabackup_$fsys
        file attributes ${mountfsdir}/fsabackup_$fsys -owner root -permissions 0777
    }
}
