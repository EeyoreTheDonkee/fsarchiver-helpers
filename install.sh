#! /usr/bin/env bash
#

# Test for tclsh9.0+, if ok, then continue with configuration via tclsh

tclv9=$(awk '($2 == "tclsh"){print $3}' .fsarchiver.rc.tcl)
if [ ! -x "$tclv9" ]; then
    echo "ERROR: tclsh9.0+ either doesn't exist or is not executable."
    exit 1
fi

$tclv9 << DONE
if { [info tclversion] < 9.0 } {
   echo "ERROR: tclsh version 9.0+ is required for fsarchiver-helpers."
   exit 1
}

source configure.tcl
DONE

