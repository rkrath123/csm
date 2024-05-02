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


Install kind on linux
-----------------------
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
- role: control-plane
- role: control-plane
- role: worker
- role: worker
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
kubectl get ns monitoring
```


Deploy Prometheus Monitoring Stack on Kubernetes
------------------------------------------------

```
kubectl create -f manifests/
```

```
kubectl get pods -n monitoring -w
```

To list all the services created you’ll run the command:
---------------------------------------------------------
```
kubectl get svc -n monitoring
```

Access Prometheus, Grafana, and Alertmanager dashboards
--------------------------------------------------------

```
kubectl --namespace monitoring port-forward svc/grafana 80:3000
```

Default Logins are:
```
Username: admin
Password: admin
```

For Prometheus port forwarding run the commands below:
```
kubectl --namespace monitoring port-forward svc/prometheus-k8s 8000:9090
```


Alert Manager Dashboard

```
kubectl --namespace monitoring port-forward svc/alertmanager-main 9093

```

