#!/bin/sh
mydir=`dirname "$0"`

export HOME=$mydir
export PATH=libs:$PATH
export LD_LIBRARY_PATH=libs

cd $mydir
bgdi ./SorR.dat
sync
