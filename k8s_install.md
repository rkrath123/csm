

# Install Kubernetes Cluster on Ubuntu 20.04 with kubeadm


Kubernetes is a tool for orchestrating and managing containerized applications at scale on on-premise server or across hybrid cloud environments. Kubeadm is a tool provided with Kubernetes to help users install a production ready Kubernetes cluster with best practices enforcement. This tutorial will demonstrate how one can install a Kubernetes Cluster on Ubuntu 20.04 with kubeadm.



-   **Master**: A Kubernetes Master is where control API calls for the pods, replications controllers, services, nodes and other components of a Kubernetes cluster are executed.
-   **Node**: A Node is a system that provides the run-time environments for the containers. A set of container pods can span multiple nodes.

The minimum requirements for the viable setup are:

-   Memory: **2 GiB** or more of RAM per machine
-   CPUs: At least **2 CPUs** on the control plane machine.
-   Internet connectivity for pulling containers required (Private registry can also be used)
-   Full network connectivity between machines in the cluster – This is private or public

## Install Kubernetes Cluster on Ubuntu 20.04

My Lab setup contain three servers. One control plane machine and two nodes to be used for running containerized workloads. You can add more nodes to suit your desired use case and load, for example using **three** control plane nodes for HA.if(typeof ez\_ad\_units != "undefined"){ez\_ad\_units.push(\[\[580,400\],"computingforgeeks\_com-medrectangle-4","ezslot\_6",167,"0","0"\])};\_\_ez\_fad\_position("div-gpt-ad-computingforgeeks\_com-medrectangle-4-0");

<table><tbody><tr><td><span class="has-inline-color has-luminous-vivid-orange-color">Server Type</span></td><td><span class="has-inline-color has-luminous-vivid-orange-color">Server Hostname</span></td><td><span class="has-inline-color has-luminous-vivid-orange-color">Specs</span></td></tr><tr><td>Master</td><td>k8s-master01.computingforgeeks.com</td><td>4GB Ram, 2vcpus</td></tr><tr><td>Worker</td><td>k8s-worker01.computingforgeeks.com</td><td>4GB Ram, 2vcpus</td></tr><tr><td>Worker</td><td>k8s-worker02.computingforgeeks.com</td><td>4GB Ram, 2vcpus</td></tr></tbody></table>

### Step 1: Install Kubernetes Servers

Provision the servers to be used in the deployment of Kubernetes on Ubuntu 20.04. The setup process will vary depending on the virtualization or cloud environment you’re using.

Once the servers are ready, update them.

```
sudo apt update && sudo apt -y full-upgrade
[ -f /var/run/reboot-required ] && sudo reboot -f
```

### Step 2: Install kubelet, kubeadm and kubectl

Once the servers are rebooted, add Kubernetes repository for Ubuntu 20.04 to all the servers.

```
sudo apt -y install curl apt-transport-https
curl  -fsSL  https://packages.cloud.google.com/apt/doc/apt-key.gpg|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Then install required packages.

```
sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

Confirm installation by checking the version of kubectl.


```
$ kubectl version --client && kubeadm version
Client Version: version.Info{Major:"1", Minor:"27", GitVersion:"v1.27.2", GitCommit:"7f6f68fdabc4df88cfea2dcf9a19b2b830f1e647", GitTreeState:"clean", BuildDate:"2023-05-17T14:20:07Z", GoVersion:"go1.20.4", Compiler:"gc", Platform:"linux/amd64"}
Kustomize Version: v5.0.1
kubeadm version: &version.Info{Major:"1", Minor:"27", GitVersion:"v1.27.2", GitCommit:"7f6f68fdabc4df88cfea2dcf9a19b2b830f1e647", GitTreeState:"clean", BuildDate:"2023-05-17T14:18:49Z", GoVersion:"go1.20.4", Compiler:"gc", Platform:"linux/amd64"}
```

### Step 3: Disable Swap

Turn off swap.

```
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

Now disable Linux swap space permanently in `/etc/fstab`. Search for a swap line and add `#` (hashtag) sign in front of the line.if(typeof ez\_ad\_units != "undefined"){ez\_ad\_units.push(\[\[250,250\],"computingforgeeks\_com-banner-1","ezslot\_30",169,"0","0"\])};\_\_ez\_fad\_position("div-gpt-ad-computingforgeeks\_com-banner-1-0");

```
$ sudo vim /etc/fstab
#/swap.imgnoneswapsw00
```

Confirm setting is correct

```
sudo swapoff -a
sudo mount -a
free -h
```

Enable kernel modules and configure sysctl.


```
# Enable kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Add some settings to sysctl
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload sysctl
sudo sysctl --system
```

### Step 4: Install Container runtime

To run containers in Pods, Kubernetes uses a container runtime. Supported container runtimes are:

-   Docker
-   CRI-O
-   Containerd

**NOTE**: You have to choose one runtime at a time.


#### Option 1: Install and Use Docker CE runtime:

```
# Add repo and Install packages
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io docker-ce docker-ce-cli

# Create required directories
sudo mkdir -p /etc/systemd/system/docker.service.d

# Create daemon json config file
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Start and enable Services
sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker


# For Docker Engine you need a shim interface. You can install Mirantis cri-dockerd as covered in the below.


$ systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2022-04-15 10:34:54 UTC; 14s ago
     Docs: https://docs.docker.com
 Main PID: 26072 (dockerd)
    Tasks: 9
   Memory: 29.1M
   CGroup: /system.slice/docker.service
           └─26072 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
Install cri-dockerd using ready binary (recommended)
Install wget and curl command line tools.



sudo apt update
sudo apt install git wget curl


VER=$(curl -s https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest|grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo $VER

wget https://github.com/Mirantis/cri-dockerd/releases/download/v${VER}/cri-dockerd-${VER}.amd64.tgz
tar xvf cri-dockerd-${VER}.amd64.tgz


sudo mv cri-dockerd/cri-dockerd /usr/local/bin/


# Validate successful installation by running the commands below:

$ cri-dockerd --version
cri-dockerd 0.3.4 (e88b1605)
Configure systemd units for cri-dockerd:

wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket
sudo mv cri-docker.socket cri-docker.service /etc/systemd/system/
sudo sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
Start and enable the services

sudo systemctl daemon-reload
sudo systemctl enable cri-docker.service
sudo systemctl enable --now cri-docker.socket
Confirm the service is now running:

$ systemctl status cri-docker.socket
● cri-docker.socket - CRI Docker Socket for the API
   Loaded: loaded (/etc/systemd/system/cri-docker.socket; enabled; vendor preset: disabled)
   Active: active (listening) since Fri 2023-03-10 10:02:13 UTC; 4s ago
   Listen: /run/cri-dockerd.sock (Stream)
    Tasks: 0 (limit: 23036)
   Memory: 4.0K
   CGroup: /system.slice/cri-docker.socket

Mar 10 10:02:13 rocky8.mylab.io systemd[1]: Starting CRI Docker Socket for the API.
Mar 10 10:02:13 rocky8.mylab.io systemd[1]: Listening on
```


#### Option 2: Install and Use CRI-O:

```
# Ensure you load modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload sysctl
sudo sysctl --system

# Add Cri-o repo
sudo su -
OS="xUbuntu_20.04"
VERSION=1.27
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | apt-key add -

# Install CRI-O
sudo apt update
sudo apt install cri-o cri-o-runc

# Update CRI-O CIDR subnet
sudo sed -i 's/10.85.0.0/172.24.0.0/g' /etc/cni/net.d/100-crio-bridge.conf
sudo sed -i 's/10.85.0.0/172.24.0.0/g' /etc/cni/net.d/100-crio-bridge.conflist

# Start and enable Service
sudo systemctl daemon-reload
sudo systemctl restart crio
sudo systemctl enable crio
sudo systemctl status crio
```

#### Option 3: Install and Use Containerd:

```
# Configure persistent loading of modules
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

# Load at runtime
sudo modprobe overlay
sudo modprobe br_netfilter

# Ensure sysctl params are set
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload configs
sudo sysctl --system

# Install required packages
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Add Docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install containerd
sudo apt update
sudo apt install -y containerd.io

# Configure containerd and start service
sudo mkdir -p /etc/containerd
sudo containerd config default|sudo tee /etc/containerd/config.toml

# restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
systemctl status  containerd
```

To use the systemd cgroup driver, set **plugins.cri.systemd\_cgroup = true** in `/etc/containerd/config.toml`. When using kubeadm, manually configure the [cgroup driver for kubelet](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#configure-cgroup-driver-used-by-kubelet-on-control-plane-node)


### Step 5: Initialize master node

Login to the server to be used as master and make sure that the _br\_netfilter_ module is loaded:

```
$ lsmod | grep br_netfilter
br_netfilter           22256  0 
bridge                151336  2 br_netfilter,ebtable_broute
```

Enable kubelet service.

```
sudo systemctl enable kubelet
```

We now want to initialize the machine that will run the control plane components which includes _etcd_ (the cluster database) and the API Server.


Pull container images:

```
$ sudo kubeadm config images pull
[config/images] Pulled registry.k8s.io/kube-apiserver:v1.27.2
[config/images] Pulled registry.k8s.io/kube-controller-manager:v1.27.2
[config/images] Pulled registry.k8s.io/kube-scheduler:v1.27.2
[config/images] Pulled registry.k8s.io/kube-proxy:v1.27.2
[config/images] Pulled registry.k8s.io/pause:3.9
[config/images] Pulled registry.k8s.io/etcd:3.5.7-0
[config/images] Pulled registry.k8s.io/coredns/coredns:v1.10.1
```

If you have multiple CRI sockets, please use `--cri-socket` to select one:

```
# CRI-O
sudo kubeadm config images pull --cri-socket unix:///var/run/crio/crio.sock

# Containerd
sudo kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock

# Docker
sudo kubeadm config images pull --cri-socket unix:///run/cri-dockerd.sock 
```

These are the basic `kubeadm init` options that are used to bootstrap cluster.

```
--control-plane-endpoint :  set the shared endpoint for all control-plane nodes. Can be DNS/IP
--pod-network-cidr : Used to set a Pod network add-on CIDR
--cri-socket : Use if have more than one container runtime to set runtime socket path
--apiserver-advertise-address : Set advertise address for this particular control-plane node's API server
```

#### Bootstrap without shared endpoint

To bootstrap a cluster without using DNS endpoint, run:

```
### With Docker CE ###
sudo sysctl -p
sudo kubeadm init \
  --pod-network-cidr=172.24.0.0/16 \
  --cri-socket unix:///run/cri-dockerd.sock 

### With CRI-O###
sudo sysctl -p
sudo kubeadm init \
  --pod-network-cidr=172.24.0.0/16 \
  --cri-socket unix:///var/run/crio/crio.sock

### With Containerd ###
sudo sysctl -p
sudo kubeadm init \
  --pod-network-cidr=172.24.0.0/16 \
  --cri-socket unix:///run/containerd/containerd.sock
```

#### Bootstrap with shared endpoint (DNS name for control plane API)

Set cluster endpoint DNS name or add record to /etc/hosts file.

```
$ sudo vim /etc/hosts
172.29.20.5 k8s-cluster.computingforgeeks.com
```

**Create cluster:**

```
sudo sysctl -p
sudo kubeadm init \
  --pod-network-cidr=172.24.0.0/16 \
  --upload-certs \
  --control-plane-endpoint=k8s-cluster.computingforgeeks.com
```

**Note**: If _**172.24.0.0/16**_ is already in use within your network you must select a different pod network CIDR, replacing 172.24.0.0/16 in the above command.


Container runtime sockets:

| Runtime | Path to Unix domain socket |
| --- | --- |
| Docker | `unix:///run/cri-dockerd.sock` |
| containerd | `unix:///run/containerd/containerd.sock` |
| CRI-O | `unix:///var/run/crio/crio.sock` |

You can optionally pass Socket file for runtime and advertise address depending on your setup.

```
# CRI-O
sudo kubeadm init \
  --pod-network-cidr=172.24.0.0/16 \
  --cri-socket unix:///var/run/crio/crio.sock \
  --upload-certs \
  --control-plane-endpoint=k8s-cluster.computingforgeeks.com

# Containerd
sudo kubeadm init \
  --pod-network-cidr=172.24.0.0/16 \
  --cri-socket unix:///run/containerd/containerd.sock \
  --upload-certs \
  --control-plane-endpoint=k8s-cluster.computingforgeeks.com

# Docker
# Must do https://computingforgeeks.com/install-mirantis-cri-dockerd-as-docker-engine-shim-for-kubernetes/
sudo kubeadm init \
  --pod-network-cidr=172.24.0.0/16 \
  --cri-socket unix:///run/cri-dockerd.sock  \
  --upload-certs \
  --control-plane-endpoint=k8s-cluster.computingforgeeks.com
```

Here is the output of my initialization command.


```
....
[init] Using Kubernetes version: v1.27.2
[preflight] Running pre-flight checks
[WARNING Firewalld]: firewalld is active, please ensure ports [6443 10250] are open or your cluster may not function correctly
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Using existing ca certificate authority
[certs] Using existing apiserver certificate and key on disk
[certs] Using existing apiserver-kubelet-client certificate and key on disk
[certs] Using existing front-proxy-ca certificate authority
[certs] Using existing front-proxy-client certificate and key on disk
[certs] Using existing etcd/ca certificate authority
[certs] Using existing etcd/server certificate and key on disk
[certs] Using existing etcd/peer certificate and key on disk
[certs] Using existing etcd/healthcheck-client certificate and key on disk
[certs] Using existing apiserver-etcd-client certificate and key on disk
[certs] Using the existing "sa" key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Using existing kubeconfig file: "/etc/kubernetes/admin.conf"
[kubeconfig] Using existing kubeconfig file: "/etc/kubernetes/kubelet.conf"
[kubeconfig] Using existing kubeconfig file: "/etc/kubernetes/controller-manager.conf"
[kubeconfig] Using existing kubeconfig file: "/etc/kubernetes/scheduler.conf"
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
W0611 22:34:23.276374    4726 manifests.go:225] the default kube-apiserver authorization-mode is "Node,RBAC"; using "Node,RBAC"
[control-plane] Creating static Pod manifest for "kube-scheduler"
W0611 22:34:23.278380    4726 manifests.go:225] the default kube-apiserver authorization-mode is "Node,RBAC"; using "Node,RBAC"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 8.008181 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.21" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node k8s-master01.computingforgeeks.com as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node k8s-master01.computingforgeeks.com as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: zoy8cq.6v349sx9ass8dzyj
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join k8s-cluster.computingforgeeks.com:6443 --token sr4l2l.2kvot0pfalh5o4ik \
    --discovery-token-ca-cert-hash sha256:c692fb047e15883b575bd6710779dc2c5af8073f7cab460abd181fd3ddb29a18 \
    --control-plane 

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join k8s-cluster.computingforgeeks.com:6443 --token sr4l2l.2kvot0pfalh5o4ik \
    --discovery-token-ca-cert-hash sha256:c692fb047e15883b575bd6710779dc2c5af8073f7cab460abd181fd3ddb29a18
```

Configure kubectl using commands in the output:


```
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Check cluster status:

```
$ kubectl cluster-info
Kubernetes master is running at https://k8s-cluster.computingforgeeks.com:6443
KubeDNS is running at https://k8s-cluster.computingforgeeks.com:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Additional Master nodes can be added using the command in installation output:

```
kubeadm join k8s-cluster.computingforgeeks.com:6443 --token sr4l2l.2kvot0pfalh5o4ik \
    --discovery-token-ca-cert-hash sha256:c692fb047e15883b575bd6710779dc2c5af8073f7cab460abd181fd3ddb29a18 \
    --control-plane
```

### Step 6: Install network plugin on Master
```
 kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml   
```



If you wish to customize the Calico install, customize the downloaded custom-resources.yaml. For example we are updating CIDR.

```
sed -ie 's/192.168.0.0/172.24.0.0/g' custom-resources.yaml
```

Use the manifest locally then install Calico:


```
$ kubectl create -f custom-resources.yaml
installation.operator.tigera.io/default created
apiserver.operator.tigera.io/default created
```

Confirm that all of the pods are running:

```
$ kubectl get pods --all-namespaces -w
NAMESPACE         NAME                               READY   STATUS    RESTARTS   AGE
kube-system       coredns-5d78c9869d-5fmlg           1/1     Running   0          9m43s
kube-system       coredns-5d78c9869d-gtlwr           1/1     Running   0          9m43s
kube-system       etcd-focal                         1/1     Running   0          10m
kube-system       kube-apiserver-focal               1/1     Running   0          9m58s
kube-system       kube-controller-manager-focal      1/1     Running   0          9m59s
kube-system       kube-proxy-pgvnf                   1/1     Running   0          9m43s
kube-system       kube-scheduler-focal               1/1     Running   0          9m57s
tigera-operator   tigera-operator-549d4f9bdb-gfdcf   1/1     Running   0          91s
```

For Single node cluster allow Pods to run on master nodes:

```
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all  node-role.kubernetes.io/control-plane-
```

Confirm master node is ready:


```
# CRI-O
$ kubectl get nodes -o wide
NAME     STATUS   ROLES                  AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
ubuntu   Ready    control-plane,master   38s   v1.27.2   143.198.114.46   <none>        Ubuntu 20.04.3 LTS   5.4.0-88-generic   cri-o://1.27.0

# Containerd
$ kubectl get nodes -o wide
NAME     STATUS   ROLES                  AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
ubuntu   Ready    control-plane,master   15m   v1.27.2   143.198.114.46   <none>        Ubuntu 20.04.3 LTS   5.4.0-88-generic   containerd://1.6.21

# Docker
$ kubectl get nodes -o wide
NAME           STATUS   ROLES    AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE           KERNEL-VERSION     CONTAINER-RUNTIME
k8s-master01   Ready    master   64m   v1.27.2   135.181.28.113   <none>        Ubuntu 20.04 LTS   5.4.0-37-generic   docker://24.0.1
```

### Step 7: Add worker nodes

With the control plane ready you can add worker nodes to the cluster for running scheduled workloads.


If endpoint address is not in DNS, add record to _/etc/hosts_.

```
$ sudo vim /etc/hosts
172.29.20.5 k8s-cluster.computingforgeeks.com
```

The join command that was given is used to add a worker node to the cluster.

```
kubeadm join k8s-cluster.computingforgeeks.com:6443 \
  --token sr4l2l.2kvot0pfalh5o4ik \
  --discovery-token-ca-cert-hash sha256:c692fb047e15883b575bd6710779dc2c5af8073f7cab460abd181fd3ddb29a18
```

Output:

```
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.21" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.
```

Run below command on the control-plane to see if the node joined the cluster.


```
$ kubectl get nodes
NAME                                 STATUS   ROLES    AGE   VERSION
k8s-master01.computingforgeeks.com   Ready    master   10m   v1.27.2
k8s-worker01.computingforgeeks.com   Ready    <none>   50s   v1.27.2
k8s-worker02.computingforgeeks.com   Ready    <none>   12s   v1.27.2

$ kubectl get nodes -o wide
```


```
kubectl apply -f https://k8s.io/examples/pods/commands.yaml
```

Check to see if pod started

```
$ kubectl get pods
NAME           READY   STATUS      RESTARTS   AGE
command-demo   0/1     Completed   0          16s
```
