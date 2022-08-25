*** Settings ***
Library     OperatingSystem
Library     Process
Library     DateTime
Library     String
Force Tags      sms      sma     component

Documentation
...     This is the resiliency test for the postgres datastore in Cray's Shasta System Monitoring Application.
...     See https://connect.us.cray.com/confluence/display/~msilvia/Shasta+SMA+Resiliency+Test+Plan

*** Test Case ***
Postgres Persister Configuration
#   This is a minimal test intended to indicate major failures of component deployment.
#  	Postgres-persister Pod Exists in SMA Namespace
    ${getpostgrespod}=     Run    kubectl -n sma get pods | grep postgres-persister | grep -v test
    Log To Console  	postgres pod reported as ${getpostgrespod}
    Should Contain      ${getpostgrespod}     postgres-persister
    Should Contain      ${getpostgrespod}     Running
#   Postgres service is running
    ${pgsvc}=     Run    kubectl -n sma get svc | grep postgres
    Log To Console      postgres service reported as ${pgsvc}
    Should Contain      ${pgsvc}     postgres
    ${getinitpod}=     Run    kubectl -n sma get pods | grep sma-db-init | grep -v test
    Log To Console  	${getinitpod}
    Should Contain      ${getinitpod}     sma-db-init
    Should Contain      ${getinitpod}     Completed
#   Kubernetes persistent volume claim for postgres is bound
    ${postgrespvc}=     Run    kubectl -n sma get pvc | grep postgres
    Log To Console  	${postgrespvc}
    Should Contain      ${postgrespvc}     pgdata-craysma-postgres-cluster-0
    Should Contain      ${postgrespvc}     pgdata-craysma-postgres-cluster-1
    Should Contain      ${postgrespvc}     Bound
#   Kafka is a prerequisite for the persister. Confirm kafka is up.
    ${getkafkapod}=     Run    kubectl -n sma get pods | grep kafka | grep -v test
    Should Contain      ${getkafkapod}     kafka
    Should Contain      ${getkafkapod}     Running
    ${getkafkapod}=     Run    kubectl -n sma get svc | grep kafka | grep -v test
    Should Contain      ${getkafkapod}     kafka
#   Kubernetes persistent volume claim for kafka is bound
    ${postgrespvc}=     Run    kubectl -n sma get pvc | grep kafka
    Log To Console  	${postgrespvc}
    Should Contain      ${postgrespvc}     Bound

*** Test Case ***
Postgres Persister Failure - Pod Deleted
#   Cause the failure of the Postgres Persister pod directly, and confirm that it recovers gracefully.
    ${persisterpod}=     Run     kubectl -n sma get pods | grep postgres-persister | head -n 1 | cut -d ' ' -f 1
    Log To Console      Checking data exists in PostgreSQL...

    Log To Console      Disrupting Postgres Persister Pod...
    ${deletepod}=        Run     kubectl -n sma delete pod ${persisterpod}
    Log To Console      ${deletepod}
#   get current time
    ${deletetime}=    Run     date -I'seconds'
    Log To Console      Pod disrupted at: ${deletetime}
    ${time1}=   Run     echo ${deletetime} | cut -d "T" -f 2 | cut -d "-" -f 1
        #   confirm container is restarted
    Log To Console      Waiting for container to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${persisterpod}=     Run     kubectl -n sma get pods | grep postgres-persister | head -n 1 | cut -d ' ' -f 1
        ${podstatus}=   Run    kubectl -n sma get -o=custom-columns=PHASE:.status.phase pod/${persisterpod} --no-headers=true
        Log To Console      ${persisterpod} is ${podstatus}
        Exit For Loop If    '${podstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    #   check for data more current than current time
    Log To Console      Looking for new data in postgres...
    FOR     ${index}        IN RANGE        12
        Sleep       5
        ${dbtime}=    Run     kubectl -n sma exec -it craysma-postgres-cluster-0 -- psql sma -U postgres -c "SELECT ts FROM sma.seastream_data ORDER BY ts DESC LIMIT 1"
        ${latest}=   Get Lines Containing String     ${dbtime}   +00
        ${time2}=   Run     echo ${latest} | cut -d " " -f 2 | cut -d "+" -f 1
        Log To Console      First timestamp was ${time1}
        Log To Console      Latest timestamp is ${time2}
        Exit For Loop If    '${time2}' > '${time1}'
        Run Keyword If      '${index}' == '11'       Fail    no new data after 1 minute
    END