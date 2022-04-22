#!/bin/bash

##################### Install the Kubernetes pre-req on all nodes #######################
#See the "kube-pre-req.sh" script file


####### This section must be run only on the Master node#########################################################################################

sudo kubeadm init --skip-phases=addon/kube-proxy

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#************************************************************Join other nodes***************************************************************************
#ssh into each node and run the "kubeadm join"
       
sudo kubeadm join #Provode the token that was create as part of the "kube init" step as teh argument

#**************************************************************

#*********************************************************Set up Cilium with Direct routing********************************************************************
#Install cilium
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}

#Setup Helm repository
helm repo add cilium https://helm.cilium.io/   
    helm uninstall cilium -n kube-system

helm install cilium cilium/cilium --version 1.11.3 --namespace kube-system \
    --set tunnel="disabled" \
    --set ipv4.enabled=true \
    --set ipam.operator.clusterPoolIPv4PodCIDR="10.0.0.0/8" \
    --set nativeRoutingCIDR="10.0.0.0/8" \
    --set autoDirectNodeRoutes=true \
    --set kubeProxyReplacement=strict \
    --set k8sServiceHost=192.168.0.23 \
    --set k8sServicePort=6443 \
    --set bpf.masquerade="true" \
    --set cluster.name=cluster1 \
    --set cluster.id=1 

#Make sure all system PODs and nodes are healthy and running
kubectl get pods -n kube-system -o wide
kubectl get nodes -o wide

#Get a Cilium agent's name
MASTER_CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o wide |  grep master | awk '{ print $1}' )

#Verify that VXLAN is not being used
kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium bpf tunnel list

#Verify that the Cilium agent is running in the desired mode
kubectl exec -it -n kube-system $MASTER_CILIUM_POD -- cilium status | grep KubeProxyReplacement
#Verify that iptables are not used
sudo iptables-save | grep KUBE-SVC

#Validate that Cilium installation
cilium status --wait

#**************************************************Deploy a test app*******************************************************

#Schedule a Kubernetes deployment using a container from Google samples
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0
#Scale up the replica set to 2
kubectl scale --replicas=2 deployment/hello-world

kubectl get pods -o wide
#apk --no-cache add curl

kubectl expose deployment hello-world --port=8080 --target-port=8080 

kubectl get services

kubectl exec -it -n kube-system $MASTER_CILIUM_POD -- cilium service list

CLUSTERIP=$(kubectl get service hello-world  -o jsonpath='{ .spec.clusterIP }')
echo $CLUSTERIP

PORT=$( kubectl get service hello-world  -o jsonpath='{.spec.ports[0].port}')
echo $PORT

curl http://$CLUSTERIP:$PORT


kubectl delete deployment hello-world ; kubectl delete service hello-world

#***************************************************Examine the routs******************************************************************
#Show Kubernetes node
kubectl get nodes -o wide

#Show the POD CIDRs on each node
 kubectl get cn kube-master -o jsonpath='{ .spec.ipam}'
 kubectl get cn kube-node1 -o jsonpath='{ .spec.ipam}'

#Examine the routes
ip route


















































#**************************************************ad-hoc commands and notes****************************

#Get POD logs
kubectl logs hello-minikube-64b64df8c9-ln67f

#Untaint maste
kubectl taint node kube-master node-role.kubernetes.io/master-

#Add curl to POD
apk --no-cache add curl

#From inside cluster we can do
curl http://hello-world:8080
    #rather than ClusterIP
        curl http://10.99.252.65:8080


kubeadm token create --print-join-command #This will get teh token for adding a new node.
sudo kubeadm reset   #this will un-configure the kubernetes cluster.
#Deleting a worker node:
    kubectl cordon c1-kube-node1-cilium
    kubectl drain --ignore-daemonsets --force c1-kube-node1-cilium --delete-emptydir-data 
    kubectl delete node c1-kube-node1-cilium

    kubectl cordon c2-kube-node1-cilium
    kubectl drain --ignore-daemonsets --force c2-kube-node1-cilium --delete-emptydir-data 
    kubectl delete node c2-kube-node1-cilium

    sudo rm -r /etc/cni/net.d ;      sudo rm $HOME/.kube/config


--type=NodePort
--type=ClusterIP

#How to install docker enterprise on Win 2019: https://computingforgeeks.com/how-to-run-docker-containers-on-windows-server-2019/

#Get OS and version
cat /etc/os-release
	#Notes:
	cat /proc/version is showing kernel version. As containers run on the same kernel as the host. It is the same kernel as the host.
	cat /etc/*-release is showing the distribution release. It is the OS version, minus the kernel.
	A container is not virtualisation, in is an isolation system that runs directly on the Linux kernel. 
        It uses the kernel name-spaces, and cgroups. Name-spaces allow separate networks, process ids, mount points, users, hostname, 
        Inter-process-communication. cgroups allows limiting resources.

#How to install ip utility on Ubuntu:
    # apt update
    # apt install iproute2 -y

    #Kube context switching
    kubectl config use-context kubernetes-admin@kubernetes

#Copy cluster certs to Windows machines
scp -r $HOME/.kube gary@192.168.0.10:/Users/grost

#**************************************Postgres**********************************************************************
docker run --name postgres -e POSTGRES_PASSWORD=ostad1 -d postgres
docker exec -it postgres psql -U postgres
    postgres=# create database test
    docker exec -it postgres createdb -h localhost -p 5432 -U postgres products

#************************************Check iptable rules***********************************************************
#Checking NAT rules
iptables -n -t nat -L KUBE-SERVICES

#*************************************TShark*****************************************************************************
#For capturing IPinIP
sudo tshark -i eth0  -V -Y "http"

link show type tunnel
#VXLAN traffic
tshark -V --color -i eth0  -d udp.port=8472,vxlan -f "port 8472"

#****************************************scp from remote server*****************************************************
scp gary@10.0.0.155:/home/gary/tests/*.* /Users/grost/OneDrive/YouTube-Channel/Video-15-Kube-Security/Scripts
#*******************************************************************************************************************

#--set nativeRoutingCIDR="172.0.0.0/16"
#Get cluster info
kubectl cluster-info

#Check health of ETCD
kubectl get ComponentStatuses

#View nodes
kubectl get nodes -o wide

#Untaint maste
kubectl taint node c1-kube-master-cilium node-role.kubernetes.io/master-
    kubectl taint node c2-kube-master-cilium node-role.kubernetes.io/master-
        kubectl taint node kube-master node-role.kubernetes.io/master-

cilium config view | grep cluster- 

# ssh gary@192.168.0.23
# ssh gary@192.168.0.40
