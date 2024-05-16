## Script to find  helm  deployment status history for singsle samespace(i.e. sma) with o/p

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


## Script to find  helm  deployment status history for ALL samespace in CSM with o/p

```
#!/bin/bash

NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

for ns in $NAMESPACES; do
  #echo "Fetching Helm chart history for namespace: $ns"

  RELEASES=$(helm list -n $ns -q)

  if [ -z "$RELEASES" ]; then
    echo "No Helm releases found in namespace: $ns"
    continue
  fi

  for release in $RELEASES; do
    HISTORY=$(helm history -n $ns $release)
    FAILED=$(echo "$HISTORY" | grep -i "failed")

    if [ -n "$FAILED" ]; then
      echo "Failed revisions found for release: $release"
      helm history -n $ns $release
    fi

    echo "-----------------------------------------------"
  done
done

```

```
ncn-m001:/mnt/developer/rkr # bash 4.sh
-----------------------------------------------
-----------------------------------------------
No Helm releases found in namespace: backups
-----------------------------------------------

-----------------------------------------------
-----------------------------------------------
No Helm releases found in namespace: cert-manager-init
No Helm releases found in namespace: default
-----------------------------------------------
-----------------------------------------------
-----------------------------------------------
No Helm releases found in namespace: ims
No Helm releases found in namespace: istio-operator
-----------------------------------------------
-----------------------------------------------
-----------------------------------------------
No Helm releases found in namespace: kube-node-lease
No Helm releases found in namespace: kube-public
-----------------------------------------------
-----------------------------------------------

-----------------------------------------------
No Helm releases found in namespace: multi-tenancy
-----------------------------------------------
-----------------------------------------------
-----------------------------------------------

-----------------------------------------------
Failed revisions found for release: sma-opensearch
REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION                                                
1               Wed May  1 15:53:12 2024        deployed        sma-opensearch-2.5.9    1.2.12          Install complete                                           
2               Wed May 15 06:22:13 2024        failed          sma-opensearch-2.5.10   1.2.13          Upgrade "sma-opensearch" failed: post-upgrade hooks failed: timed out waiting for the condition
-----------------------------------------------
-----------------------------------------------
-----------------------------------------------

-----------------------------------------------
-----------------------------------------------
No Helm releases found in namespace: tenants
No Helm releases found in namespace: uas
-----------------------------------------------
-----------------------------------------------
```
