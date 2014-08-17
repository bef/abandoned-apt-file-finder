#!/usr/bin/env tclsh
## aaff - abandoned-apt-file-finder
## finds files not listed in debian's list of installed files
## - (c) 2014 - BeF <bef@pentaphase.de>
##

package require fileutil
package require fileutil::traverse
package require cmdline

set debuglevel 0
set excludelist {/.}

## mini optparse
for {set i 0} {$i < $::argc} {incr i} {
	set arg [lindex $::argv $i]
	switch -regexp -matchvar foo -- $arg {
		^-v {incr debuglevel}
		^-x=(.*) {
			foreach line [split [fileutil::cat [lindex $foo 1]] "\n"] {
				if {$line eq "" || [string index $line 0] eq "#"} {continue}
				lappend excludelist $line
			}
		}
		default {puts "unknown argument $arg\nUsage: $argv0 \[-x=excludelist\] \[-v\]"; exit 1}
	}
}

## functions
proc log {msg {level 1}} {
	if {$level <= $::debuglevel} {puts "\[$level\] $msg"}
}

proc isExcluded {path} {
	foreach pattern $::excludelist {
		if {[string match $pattern $path]} {return true}
	}
	return false
}

## load dpkg lists

log "loading dpkg info..."
set i 0
set dpkg_files {}
foreach listfn [glob -directory {/var/lib/dpkg/info} -types f -- {*.list}] {
	foreach fn [split [fileutil::cat $listfn] "\n"] {
		if {$fn eq ""} {continue}
		if {[isExcluded $fn]} {continue}
		lappend dpkg_files $fn
		incr i
	}
}

log "sorting dpkg info ($i entries)..."
set dpkg_files [lsort $dpkg_files]

## traverse / and report unlisted files

log "find /"
proc prefilter {path} {expr {![isExcluded $path]}}
proc errorcmd {path msg} {log "ERR: $path: $msg"}
fileutil::traverse tr / -prefilter prefilter -filter prefilter -errorcmd errorcmd
#fileutil::traverse tr / -prefilter prefilter -errorcmd errorcmd
set i 0
tr foreach fn {
	incr i
	if {[lsearch -exact -sorted $dpkg_files $fn] == -1} {puts $fn}
	if {$i % 5000 == 0} {puts -nonewline . ; flush stdout}
}
log "checked $i files"

