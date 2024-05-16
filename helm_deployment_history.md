## Script to find  helm  deployment status history for singsle samespace(i.e. sma)

```
#!/bin/bash

NAMESPACE="sma"

RELEASES=$(helm list -n $NAMESPACE -q)

if [ -z "$RELEASES" ]; then
  echo "No Helm releases found in namespace: $NAMESPACE"
  exit 0
fi

for release in $RELEASES; do
  HISTORY=$(helm history -n $NAMESPACE $release)


  FAILED=$(echo "$HISTORY" | grep -i "failed")

  if [ -n "$FAILED" ]; then
    echo "Failed revisions found for release: $release"
    HISTORY=$(helm history -n $NAMESPACE $release)
    echo "$HISTORY"

  fi

done

```
```
command o/p
```
```
ncn-m001:~ # bash 2.sh
Failed revisions found for release: sma-opensearch
REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION                                                
1               Tue Apr 30 07:22:38 2024        superseded      sma-opensearch-2.5.9                    Install complete                                           
2               Fri May 10 10:51:40 2024        uninstalling    sma-opensearch-2.5.10   1.2.13          Deletion in progress (or silently failed)                  
3               Tue May 14 14:41:22 2024        failed          sma-opensearch-2.5.10   1.2.13          Upgrade "sma-opensearch" failed: post-upgrade hooks failed: timed out waiting for the condition
4               Tue May 14 17:39:23 2024        deployed        sma-opensearch-2.5.9    1.2.12          Upgrade complete                                           
Failed revisions found for release: sma-pgdb-init
REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION                                                
1               Tue May 14 14:27:20 2024        superseded      sma-pgdb-init-1.7.2     1.7.2           Install complete                                           
2               Tue May 14 17:16:06 2024        failed          sma-pgdb-init-1.7.1     1.7.1           Upgrade "sma-pgdb-init" failed: post-upgrade hooks failed: timed out waiting for the condition
3               Wed May 15 09:22:13 2024        deployed        sma-pgdb-init-1.7.1     1.7.1           Rollback to 2                                              

```
