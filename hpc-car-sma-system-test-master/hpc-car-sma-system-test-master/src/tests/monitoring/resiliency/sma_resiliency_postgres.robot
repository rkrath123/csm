*** Settings ***
Library     OperatingSystem
Library     Process
Force Tags      sms      sma     component

Documentation
...     This is the resiliency test for the postgres datastore in Cray's Shasta System Monitoring Application.
...     See https://connect.us.cray.com/confluence/display/~msilvia/Shasta+SMA+Resiliency+Test+Plan

*** Variables ***
${pgpod0}     sma-postgres-cluster-0
${pgpod1}     sma-postgres-cluster-1

*** Keywords ***
Delete Test View
#   Delete the "test" view from the sma schema and confirm it no longer exists
    ${masterpod}=      Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1
    ${deleteout}=   Run    kubectl -n sma exec -it ${masterpod} -- psql sma -U postgres -c "DROP VIEW sma.test;"
    Should Contain      ${deleteout}    DROP VIEW
    ${views}=   Run    kubectl -n sma exec -it ${masterpod} -- bash -c 'echo "\\dv sma.*" | psql sma -A -U postgres --tuples-only'
    Should Not Contain      ${views}    test

Check Server Role
#   Confirm that a server is host to a postgres pod with the expected role
    [Arguments]    ${node}      ${role}
    Log To Console      confirming ${node} is ${role}...
    FOR     ${index}        IN RANGE        9
        Sleep       10
        ${replicarole_a}=   Run    kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=ROLE:.metadata.labels.spilo-role,NODE:.spec.nodeName | grep ${node} | cut -d " " -f 1
        Log To Console      ${node} role is ${role}
        Exit For Loop If    '${replicarole}' == 'master'
    END

*** Test Case ***
Postgres Configuration
#   This is a minimal test intended to indicate major failures of component deployment.
    ${pgsvc}=     Run    kubectl -n sma get svc | grep postgres
    Log To Console      ${pgsvc}
    Should Contain      ${pgsvc}     sma-postgres-cluster-config
    Should Contain      ${pgsvc}     sma-postgres-cluster-repl
#   Kubernetes persistent volume claim for postgres is bound
    ${postgrespvc}=     Run    kubectl -n sma get pvc | grep postgres
    Log To Console  	${postgrespvc}
    Should Contain      ${postgrespvc}     pgdata-sma-postgres-cluster-0
    Should Contain      ${postgrespvc}     pgdata-sma-postgres-cluster-1
    Should Contain      ${postgrespvc}     pgdata-sma-postgres-cluster-2
    Should Contain      ${postgrespvc}     Bound

*** Test Case ***
Postgres Master Failure - Pod Deleted
#   Cause the failure of the Postgres Master pod directly, and confirm that it recovers gracefully.
#   When the master fails, a standby replica will be promoted to be the new master and service will continue from there.
#   Kubenetes will restart the pod automatically as a hot standby. It will then have access to the same
#   data repository on the Ceph file system as it did before the failure occurred, and serve read only requests.
    ${masternode}=      Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1
    Log To Console      Master node is ${masternode}
    ${replicapod_a}=     Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | head -n 1 | cut -d " " -f 1
    Log To Console      Replica pod A is ${replicapod_a}
    ${replicapod_b}=     Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | tail -n 1 | cut -d " " -f 1
    Log To Console      Replica pod B is ${replicapod_b}
    Should Not Be Equal     ${replicapod_a}    ${replicapod_b}
    ${masterpod}=   Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1
    Log To Console      Master pod is ${masterpod}
#   Create a new view called "test" in the sma postgreSQL schema and confirm it exists
    ${createout}=   Run    kubectl -n sma exec -it ${masterpod} -- bash -c 'echo "CREATE VIEW sma.test AS SELECT measurementtypeid, measurementunits FROM sma.measurementsource;" | psql sma -A -U postgres --tuples-only'
    Should Contain      ${createout}     CREATE VIEW
    ${views}=   Run   kubectl -n sma exec -it ${masterpod} -- bash -c 'echo "\\dv sma.*" | psql sma -A -U postgres --tuples-only'
    Should Contain      ${views}    test
    Log To Console      Disrupt Postgres Master Pod
    ${deletepod}=        Run     kubectl -n sma delete pod ${masterpod}
    Log To Console      ${deletepod} deleted on ${masternode}
#   confirm container is restarted
    Log To Console      Waiting for master role change...
    FOR     ${index}        IN RANGE        12
        Sleep       5
        ${masterrole}=   Run    kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=ROLE:.metadata.labels.spilo-role,POD:.metadata.name | grep ${masterpod} | cut -d " " -f 1
        Log To Console      ${masterpod} role is ${masterrole}
        Exit For Loop If    'master' not in '${masterrole}'
        Run Keyword If      '${index}' == '11'       Fail    no role change after 1 minute
    END
    Log To Console      confirming a standby node is promoted to master...
    FOR     ${index}        IN RANGE        9
        Sleep       10
        ${replicarole_a}=   Run    kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=ROLE:.metadata.labels.spilo-role,POD:.metadata.name | grep ${replicapod_a} | cut -d " " -f 1
        Log To Console      ${replicapod_a} role is ${replicarole_a}
        ${replicarole_b}=   Run    kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=ROLE:.metadata.labels.spilo-role,POD:.metadata.name | grep ${replicapod_b} | cut -d " " -f 1
        Log To Console      ${replicapod_b} role is ${replicarole_b}
        Exit For Loop If    '${replicarole_a}' == 'master'
        Exit For Loop If    '${replicarole_b}' == 'master'
        Run Keyword If      '${index}' == '8'       Fail    no role change after 90 seconds
    END
    Log To Console      confirming disrupted pod restarts as hot standby...
        FOR     ${index}        IN RANGE        9
        Sleep       10
        ${masterrole}=   Run    kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=ROLE:.metadata.labels.spilo-role,POD:metadata.name | grep ${masterpod} | cut -d " " -f 1
        Log To Console      ${masterpod} role is ${masterrole}
        Exit For Loop If    '${masterrole}' == 'replica'
        Run Keyword If      '${index}' == '8'       Fail    no role change after 90 seconds
    END
    Log To Console      confirming replica pods both serve read requests after one restarts...
    ${replicapod_a}=      Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | head -n 1 | cut -d " " -f 1
    ${views_a}=   Run   kubectl -n sma exec -it ${replicapod_a} -- bash -c 'echo "\\dv sma.*" | psql sma -A -U postgres --tuples-only'
    Should Contain      ${views_a}    test
    ${replicapod_b}=      Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | tail -n 1 | cut -d " " -f 1
    Should Not Be Equal     ${replicapod_a}    ${replicapod_b}
    ${views_b}=   Run   kubectl -n sma exec -it ${replicapod_b} -- bash -c 'echo "\\dv sma.*" | psql sma -A -U postgres --tuples-only'
    Should Contain      ${views_b}    test
    [Teardown]          Run Keyword     Delete Test View

*** Test Case ***
Postgres Standby Pod Failure
#   When a standby node fails, it will be restarted on an available SMS node, and will begin accepting connections and serving read-only requests.
    ${masternode}=      Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1
    Log To Console      Master node is ${masternode}
    ${replicanode_a}=     Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | head -n 1 | cut -d " " -f 1
    Log To Console      Replica node A is on ${replicanode_a}
    ${replicanode_b}=     Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | tail -n 1 | cut -d " " -f 1
    Log To Console      Replica node B is on ${replicanode_b}
    ${masterpod}=   Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1
    Log To Console      Master pod is ${masterpod}
#   Create a new view called "test" in the sma postgreSQL schema and confirm it exists
    ${createout}=   Run    kubectl -n sma exec -it ${masterpod} -- bash -c 'echo "CREATE VIEW sma.test AS SELECT measurementtypeid, measurementunits FROM sma.measurementsource;" | psql sma -A -U postgres --tuples-only'
    Should Contain      ${createout}     CREATE VIEW
    ${views}=   Run   kubectl -n sma exec -it ${masterpod} -- bash -c 'echo "\\dv sma.*" | psql sma -A -U postgres --tuples-only'
    Should Contain      ${views}    test
    Log To Console      Disrupt a Postgres Replica Pod
    ${replicapod_a}=      Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | head -n 1 | cut -d " " -f 1
    ${deletepod}=        Run     kubectl -n sma delete pod ${replicapod_a}
    Log To Console      ${deletepod}
#   confirm container is restarted
    Log To Console      Waiting for replica role change...
    FOR     ${index}        IN RANGE        12
        Sleep       5
        ${replicarole}=   Run    kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=ROLE:.metadata.labels.spilo-role,POD:.metadata.name | grep ${replicapod_a} | cut -d " " -f 1
        Log To Console      ${replicapod_a} role is ${replicarole}
        Exit For Loop If    'replica' not in '${replicarole}'
        Run Keyword If      '${index}' == '11'       Fail    no role change after 1 minute
    END
    Log To Console      confirm standby pod is re-added
    FOR     ${index}        IN RANGE        9
        Sleep       10
        ${podroles}=   Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role
        Log To Console      ${podroles}
        ${replicacount}=    Get Count   ${podroles}     replica
        Exit For Loop If    '${replicacount}' == '2'
        Run Keyword If      '${index}' == '8'       Fail    replica pod not available after 90 seconds
    END
    Log To Console      confirming replica pods both serve read requests after one restarts...
    ${replicapod_a}=      Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | head -n 1 | cut -d " " -f 1
    ${views_a}=   Run   kubectl -n sma exec -it ${replicapod_a} -- bash -c 'echo "\\dv sma.*" | psql sma -A -U postgres --tuples-only'
    Should Contain      ${views_a}    test
    ${replicapod_b}=      Run     kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep replica | tail -n 1 | cut -d " " -f 1
    Should Not Be Equal     ${replicapod_a}    ${replicapod_b}
    ${views_b}=   Run   kubectl -n sma exec -it ${replicapod_b} -- bash -c 'echo "\\dv sma.*" | psql sma -A -U postgres --tuples-only'
    Should Contain      ${views_b}    test
    [Teardown]          Run Keyword     Delete Test View
