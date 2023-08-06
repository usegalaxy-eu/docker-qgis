#!/bin/sh -f

# script to run QGIS 64 bit on a Linux 64 bit system


#TODO: set ODVHOME to the full path-name of the odv install-directory
QGISHOME=/app/qgis

#-----------------------------------------------------------------------
# nothing to be changed below this line

# set LD_LIBRARY_PATH
if [ -z LD_LIBRARY_PATH ]
then
LD_LIBRARY_PATH=${QGISHOME}/bin_linux-amd64
else
LD_LIBRARY_PATH=${QGISHOME}/bin_linux-amd64:${LD_LIBRARY_PATH}
fi

# set PATH
PATH=${PATH}:${QGISHOME}/bin_linux-amd64

export LD_LIBRARY_PATH
export PATH

qgis --noversioncheck --nologo 
