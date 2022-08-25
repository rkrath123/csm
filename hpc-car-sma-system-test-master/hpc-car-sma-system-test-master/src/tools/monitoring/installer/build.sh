#!/bin/bash
# set -x

binpath=`dirname "$0"`
tmpdir=$(mktemp -d /tmp/sma-sos-install.XXXXXX)
d=`date +%Y%m%d.%H%M`
archive="${tmpdir}/sma-sos-archive-${d}.tar.gz"
installer="${binpath}/sma_sos_installer.sh"

rm -f ${installer}

mkdir -vp ${tmpdir}/sma-sos
cp -Rv ${binpath}/../* ${tmpdir}/sma-sos
if [ $? -ne 0 ]; then
	echo "payload copy failed"
	exit 1
fi

tar --exclude='./installer' -cvzf $archive -C $tmpdir/sma-sos .
if [ $? -ne 0 ]; then
	echo "tar failed"
	exit 1
fi

cp ${binpath}/install.sh ${installer}
cat ${archive} >> ${installer}

chmod +x ${installer}
rm -rf ${tmpdir}
echo
echo "done - ${installer}"
