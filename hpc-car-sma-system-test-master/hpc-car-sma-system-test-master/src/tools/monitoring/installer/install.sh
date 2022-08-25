#!/bin/bash

installdir=${1-/tmp/sma-sos}
mkdir -p ${installdir}
# check for an error

# Find __ARCHIVE__ maker, read archive content and decompress it
ARCHIVE=$(awk '/^__ARCHIVE__/ {print NR + 1; exit 0; }' "${0}")
tail -n+${ARCHIVE} "${0}" | tar xpzv -C ${installdir}

sed -i "/SMA_TOOLS_HOME=/c SMA_TOOLS_HOME=${installdir}" ${installdir}/sma_tools

echo
echo "tools are installed in ${installdir}"
echo
echo "To create the sosreport run the following command:"
echo "# ${installdir}/sma_sosreport.sh"

exit 0

__ARCHIVE__
