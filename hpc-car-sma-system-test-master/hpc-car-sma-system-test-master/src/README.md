SMA testing
===========
All SMA tests formerly deployed as containerized robot-framework tests have been refactored as standalone bash scripts,
and have been supplimented with additional tests and test cases in order to make them more robust.

SMA Component tests can be found in hpc-car-sma-system-test/src/tests/monitoring/component, and are intended as much as
is reasonably possible, to test that individual components of the System Monitoring Framework are functioning
as intended. Top level scripts check a suite of test cases for each component, while those in the component
subdirectories represent an individual test case per script.

The smoke test looks at end-to-end functionality:
/Users/msilvia/PycharmProjects/matthew-silvia/hpc-car-sma-system-test/src/tests/monitoring/smoke/sma_smoke.sh

Scripts in /Users/msilvia/PycharmProjects/matthew-silvia/hpc-car-sma-system-test/src/tests/monitoring/scale have no
pass/fail criteria, but provide information about a component's resource utilization.

Tests in the resiliency directory were written in robot, but were very rarely utilized, and so no effort was invested in
refactoring them as shell scripts. They may provide a useful, if outdated, reference for such testing in the future.

/Users/msilvia/PycharmProjects/matthew-silvia/hpc-car-sma-system-test/src/tools/monitoring/alarm scale contains tools
used in testing monasca at scale.

Other tests and tools were mostly created for use with earlier versions or related features.

