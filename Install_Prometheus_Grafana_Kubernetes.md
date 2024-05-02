##Prometheus Operator

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
