
Build and install SMA sos tools
===============================

Create a self extracting bash script, sma_sos_installer.sh, to automate the installation of the sma sos tools including the sosreport command.
The self extracting script simplifies installation by the packaging the sma tools directories/files in
a compressed tar archive which will automatically install the required sos tools in /tmp/sma-sos
This self extracting command is available for download to a customer site for
collecting SMF diagnostics information; the sosreport command.

Build
-----

The build.sh tool is a shell script which creates compress tar archive out of the SMF tools directories/files,
and adds a small shell script stub at the beginning of the archive to initiate self-extraction.

    # Clone tools from BitBucket
    $ git clone https://USERID@stash.us.cray.com/scm/car/sma-system-test.git sma-test

    # Build script to install tools
    sma-test/src/tools/montoring/installer/build.sh
    ls -l sma-test/src/tools/montoring/installer/sma_sos_installer.sh

Install
-------

Download the sma_install_tools.sh script to the BIS NCN node (ncn-w001) and run the following command:

    ./sma_sos_installer.sh

The sma sos tools will be installed in /tmp/sma-sos

SMA sosreport
-------------

If unexpected behavior is experienced with SMF it is important to collect the current state of the SMA infrastructure.  
The sma_sosreport.sh command is a tool that collects SMF configuration details, system information, SMA docker logs 
and diagnostics information from the BIS NCN node and stores this output in a compressed tar file in /tmp.
The output of sosreport is the common starting point for engineers to perform an initial
analysis of a problem in SMF.

    /tmp/sma-sos/sma_sosreport.sh
