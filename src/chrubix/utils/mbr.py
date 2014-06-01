#

''' mbr.py
Created on May 9, 2014

'''


from chrubix.utils import write_oneliner_file, system_or_die


def install_initcpio_wiperamonshutdown_files( mountpoint ):
    # There's a reason for extracting to /usr instead of /. You see, on some distros do 'ln -sf /usr/lib /lib' ...
    our_hook = 'wiperam_on_shutdown'
    system_or_die( 'mkdir -p %s/usr/lib/initcpio/hooks' % ( mountpoint ) )
    system_or_die( 'mkdir -p %s/usr/lib/initcpio/install' % ( mountpoint ) )
    write_wros_main_file( '%s/usr/lib/initcpio/%s' % ( mountpoint, our_hook ) )
    write_wros_hook_file( '%s/usr/lib/initcpio/hooks/%s' % ( mountpoint, our_hook ) )
    write_wros_install_file( '%s/usr/lib/initcpio/install/%s' % ( mountpoint, our_hook ) )


def write_wros_install_file( outfile ):
    write_oneliner_file( outfile, r'''#!/bin/bash

build() {
    BINARIES='cp'
    SCRIPT='wiperam_on_shutdown'

    add_file "/lib/initcpio/wiperam_on_shutdown" "/shutdown"
    add_binary "/usr/bin/smem"
}

help() {
    cat <<HELPEOF
Secure shutdown using smem to wipe RAM.
HELPEOF
}
''' )
def write_wros_hook_file( outfile ):
    write_oneliner_file( outfile, r'''#!/usr/bin/ash

run_hook() {
    cp -ax / /run/initramfs
}
''' )

def write_wros_main_file( outfile ):
    write_oneliner_file( outfile, r'''#!/usr/bin/ash

findmnt -Rruno TARGET /oldroot | awk '
BEGIN { i = 0 }
! /^\/(proc|dev|sys)/ {
  i++
  mounts[i] = $0
}
END {
  for (j = i; j > 0; j--) {
    print mounts[j]
  }
}
' | while read -r mount; do
  umount -l "$mount"
done

# sysctl tweaks to prevent smem from crashing
# http://git.immerda.ch/?p=amnesia.git;a=blob_plain;f=config%2Fchroot_local-includes%2Fusr%2Fshare%2Finitramfs-tools%2Fscripts%2Finit-premount%2Fsdmem
echo 3   > /proc/sys/kernel/printk
echo 3   > /proc/sys/vm/drop_caches
echo 256 > /proc/sys/vm/min_free_kbytes
echo 1   > /proc/sys/vm/overcommit_memory
echo 1   > /proc/sys/vm/oom_kill_allocating_task
echo 0   > /proc/sys/vm/oom_dump_tasks

smem -v -ll

case $1 in
  reboot)
    type kexec >/dev/null && kexec -e
    reboot -f
    ;;
  poweroff|shutdown|halt)
    "$1" -f
    ;;
  *)
    poweroff -f
    ;;
esac
''' )
