#!/bin/bash

if [ "$USER" != "root" ] && [ "$USER" != "" ] ; then
    sudo $0
else
    https_proxy=
    http_proxy=
    chrubix.sh tinker secretsquirrel
fi
exit $?
