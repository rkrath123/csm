Lightweight Kubernetes distribution (Install kind on linux)
-----------------------------------------------------------
```
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

kind.yaml
---------
```
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
```
```
kind create cluster --config kind.yaml
``` 
 
Install kubectl 
--------------
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```


# Prometheus Operator

We will be using Prometheus Operator in this installation to deploy Prometheus monitoring stack on Kubernetes. The Prometheus Operator is written to ease the deployment and overall management of Prometheus and its related monitoring components. 
By using the Operator we simplify and automate Prometheus configuration on any any Kubernetes cluster using Kubernetes custom resources.
```
The Operator uses the following custom resource definitions (CRDs) to deploy and configure Prometheus monitoring stack:
Prometheus – This defines a desired Prometheus deployment on Kubernetes
Alertmanager – This defines a desired Alertmanager deployment on Kubernetes cluster
ThanosRuler – This defines Thanos desired Ruler deployment.
ServiceMonitor – Specifies how groups of Kubernetes services should be monitored
PodMonitor – Declaratively specifies how group of pods should be monitored
Probe – Specifies how groups of ingresses or static targets should be monitored
PrometheusRule – Provides specification of Prometheus alerting desired set. The Operator generates a rule file, which can be used by Prometheus instances.
AlertmanagerConfig – Declaratively specifies subsections of the Alertmanager configuration, allowing routing of alerts to custom receivers, and setting inhibit rules.
```

![image](https://github.com/rkrath123/csm/assets/53966749/0fa20fd3-c18a-4de8-9fc8-9dff6e41b846)



Deploy Prometheus / Grafana Monitoring Stack on Kubernetes
----------------------------------------------------------

```
git clone https://github.com/prometheus-operator/kube-prometheus.git

```

```
cd kube-prometheus
```

Create monitoring namespace, CustomResourceDefinitions & operator pod
---------------------------------------------------------------------
```
kubectl create -f manifests/setup
```
```
customresourcedefinition.apiextensions.k8s.io/alertmanagerconfigs.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/alertmanagers.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/podmonitors.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/probes.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/prometheuses.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/prometheusrules.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/servicemonitors.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/thanosrulers.monitoring.coreos.com created
namespace/monitoring created

```

```
kubectl get ns monitoring
```
```
$ kubectl get ns monitoring
NAME         STATUS   AGE
monitoring   Active   2m41s
```

Deploy Prometheus Monitoring Stack on Kubernetes
------------------------------------------------

```
kubectl create -f manifests/
```
```
poddisruptionbudget.policy/alertmanager-main created
prometheusrule.monitoring.coreos.com/alertmanager-main-rules created
secret/alertmanager-main created
service/alertmanager-main created
serviceaccount/alertmanager-main created
servicemonitor.monitoring.coreos.com/alertmanager created
clusterrole.rbac.authorization.k8s.io/blackbox-exporter created
clusterrolebinding.rbac.authorization.k8s.io/blackbox-exporter created
configmap/blackbox-exporter-configuration created
deployment.apps/blackbox-exporter created
service/blackbox-exporter created
serviceaccount/blackbox-exporter created
servicemonitor.monitoring.coreos.com/blackbox-exporter created
secret/grafana-datasources created
configmap/grafana-dashboard-alertmanager-overview created
configmap/grafana-dashboard-apiserver created
configmap/grafana-dashboard-cluster-total created
configmap/grafana-dashboard-controller-manager created
configmap/grafana-dashboard-k8s-resources-cluster created
configmap/grafana-dashboard-k8s-resources-namespace created
configmap/grafana-dashboard-k8s-resources-node created
configmap/grafana-dashboard-k8s-resources-pod created
configmap/grafana-dashboard-k8s-resources-workload created
configmap/grafana-dashboard-k8s-resources-workloads-namespace created
configmap/grafana-dashboard-kubelet created
configmap/grafana-dashboard-namespace-by-pod created
configmap/grafana-dashboard-namespace-by-workload created
configmap/grafana-dashboard-node-cluster-rsrc-use created
configmap/grafana-dashboard-node-rsrc-use created
configmap/grafana-dashboard-nodes created
configmap/grafana-dashboard-persistentvolumesusage created
configmap/grafana-dashboard-pod-total created
configmap/grafana-dashboard-prometheus-remote-write created
configmap/grafana-dashboard-prometheus created
configmap/grafana-dashboard-proxy created
configmap/grafana-dashboard-scheduler created
configmap/grafana-dashboard-workload-total created
configmap/grafana-dashboards created
deployment.apps/grafana created
service/grafana created
serviceaccount/grafana created
servicemonitor.monitoring.coreos.com/grafana created
prometheusrule.monitoring.coreos.com/kube-prometheus-rules created
clusterrole.rbac.authorization.k8s.io/kube-state-metrics created
clusterrolebinding.rbac.authorization.k8s.io/kube-state-metrics created
deployment.apps/kube-state-metrics created
prometheusrule.monitoring.coreos.com/kube-state-metrics-rules created
service/kube-state-metrics created
serviceaccount/kube-state-metrics created
servicemonitor.monitoring.coreos.com/kube-state-metrics created
prometheusrule.monitoring.coreos.com/kubernetes-monitoring-rules created
servicemonitor.monitoring.coreos.com/kube-apiserver created
servicemonitor.monitoring.coreos.com/coredns created
servicemonitor.monitoring.coreos.com/kube-controller-manager created
servicemonitor.monitoring.coreos.com/kube-scheduler created
servicemonitor.monitoring.coreos.com/kubelet created
clusterrole.rbac.authorization.k8s.io/node-exporter created
clusterrolebinding.rbac.authorization.k8s.io/node-exporter created
daemonset.apps/node-exporter created
prometheusrule.monitoring.coreos.com/node-exporter-rules created
service/node-exporter created
serviceaccount/node-exporter created
servicemonitor.monitoring.coreos.com/node-exporter created
clusterrole.rbac.authorization.k8s.io/prometheus-adapter created
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrolebinding.rbac.authorization.k8s.io/prometheus-adapter created
clusterrolebinding.rbac.authorization.k8s.io/resource-metrics:system:auth-delegator created
clusterrole.rbac.authorization.k8s.io/resource-metrics-server-resources created
configmap/adapter-config created
deployment.apps/prometheus-adapter created
poddisruptionbudget.policy/prometheus-adapter created
rolebinding.rbac.authorization.k8s.io/resource-metrics-auth-reader created
service/prometheus-adapter created
serviceaccount/prometheus-adapter created
servicemonitor.monitoring.coreos.com/prometheus-adapter created
clusterrole.rbac.authorization.k8s.io/prometheus-k8s created
clusterrolebinding.rbac.authorization.k8s.io/prometheus-k8s created
prometheusrule.monitoring.coreos.com/prometheus-operator-rules created
servicemonitor.monitoring.coreos.com/prometheus-operator created
poddisruptionbudget.policy/prometheus-k8s created
prometheus.monitoring.coreos.com/k8s created
prometheusrule.monitoring.coreos.com/prometheus-k8s-prometheus-rules created
rolebinding.rbac.authorization.k8s.io/prometheus-k8s-config created
rolebinding.rbac.authorization.k8s.io/prometheus-k8s created
rolebinding.rbac.authorization.k8s.io/prometheus-k8s created
rolebinding.rbac.authorization.k8s.io/prometheus-k8s created
role.rbac.authorization.k8s.io/prometheus-k8s-config created
role.rbac.authorization.k8s.io/prometheus-k8s created
role.rbac.authorization.k8s.io/prometheus-k8s created
role.rbac.authorization.k8s.io/prometheus-k8s created
service/prometheus-k8s created
serviceaccount/prometheus-k8s created
servicemonitor.monitoring.coreos.com/prometheus-k8s created
```
```
kubectl get pods -n monitoring -w
```
```
$ kubectl get pods -n monitoring -w
NAME                                   READY   STATUS    RESTARTS        AGE
alertmanager-main-0                    2/2     Running   0               3m8s
alertmanager-main-1                    2/2     Running   1 (2m55s ago)   3m8s
alertmanager-main-2                    2/2     Running   1 (2m40s ago)   3m8s
blackbox-exporter-69684688c9-nk66w     3/3     Running   0               6m47s
grafana-7bf8dc45db-q2ndq               1/1     Running   0               6m47s
kube-state-metrics-d75597b45-d9bhk     3/3     Running   0               6m47s
node-exporter-2jzcv                    2/2     Running   0               6m47s
node-exporter-5k8pk                    2/2     Running   0               6m47s
node-exporter-9852n                    2/2     Running   0               6m47s
node-exporter-f5dmp                    2/2     Running   0               6m47s
prometheus-adapter-5f68766c85-hjcz9    1/1     Running   0               6m46s
prometheus-adapter-5f68766c85-shjbz    1/1     Running   0               6m46s
prometheus-k8s-0                       2/2     Running   0               3m7s
prometheus-k8s-1                       2/2     Running   0               3m7s
prometheus-operator-748bb6fccf-b5ppx   2/2     Running   0
```
To list all the services created you’ll run the command:
---------------------------------------------------------
```
kubectl get svc -n monitoring
```
```
$ kubectl get svc -n monitoring
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
alertmanager-main       ClusterIP   10.100.171.41    <none>        9093/TCP,8080/TCP            7m2s
alertmanager-operated   ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP   3m23s
blackbox-exporter       ClusterIP   10.108.187.73    <none>        9115/TCP,19115/TCP           7m2s
grafana                 ClusterIP   10.97.236.243    <none>        3000/TCP                     7m2s
kube-state-metrics      ClusterIP   None             <none>        8443/TCP,9443/TCP            7m2s
node-exporter           ClusterIP   None             <none>        9100/TCP                     7m2s
prometheus-adapter      ClusterIP   10.109.119.234   <none>        443/TCP                      7m1s
prometheus-k8s          ClusterIP   10.101.253.211   <none>        9090/TCP,8080/TCP            7m1s
prometheus-operated     ClusterIP   None             <none>        9090/TCP                     3m22s
prometheus-operator     ClusterIP   None             <none>        8443/TCP                     7m1s
```

Access Prometheus, Grafana, and Alertmanager dashboards
--------------------------------------------------------

```
kubectl --namespace monitoring port-forward svc/grafana 80:3000 --address='0.0.0.0' &
```

Default Logins are:
```
Username: admin
Password: admin
```
![image](https://github.com/rkrath123/csm/assets/53966749/8bb2b547-d42f-4372-9124-351349652fd4)

For Prometheus port forwarding run the commands below:
```
kubectl --namespace monitoring port-forward svc/prometheus-k8s 8000:9090 --address='0.0.0.0' &
```
![image](https://github.com/rkrath123/csm/assets/53966749/86ff54fd-f55b-48a2-9d68-70a75fd085d8)


Alert Manager Dashboard

```
kubectl --namespace monitoring port-forward svc/alertmanager-main 8001:9093 --address='0.0.0.0' &

```

# Destroying / Tearing down Prometheus monitoring stack
```
kubectl delete --ignore-not-found=true -f manifests/ -f manifests/setup
```
