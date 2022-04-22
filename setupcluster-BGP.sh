#!/bin/bash

##################### Install the Kubernetes pre-req on all nodes #######################
#See the "kube-pre-req.sh" script file


####### This section must be run only on the Master node#########################################################################################

sudo kubeadm init --pod-network-cidr="10.0.0.0/8" --skip-phases=addon/kube-proxy

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#************************************************************Join other nodes***************************************************************************
#ssh into each node and run the "kubeadm join"
       
sudo kubeadm join #Use token from the "kubeadm init" step

#**************************************************************

#***************************************************************Deploying kube-router **************************************************************************

#Download the "kube-router" config file and modify
curl -LO https://raw.githubusercontent.com/cloudnativelabs/kube-router/v1.2/daemonset/generic-kuberouter-only-advertise-routes.yaml

#Set recommended options: https://docs.cilium.io/en/stable/gettingstarted/kube-router/ 

# - --run-router=true
# - --run-firewall=false
# - --run-service-proxy=false
# - --bgp-graceful-restart=true
# - --enable-cni=false
# - --enable-pod-egress=false
# - --enable-ibgp=true
# - --enable-overlay=true
# - --advertise-cluster-ip=true
# - --advertise-external-ip=true
# - --advertise-loadbalancer-ip=true

nano generic-kuberouter-only-advertise-routes.yaml

kubectl apply -f generic-kuberouter-only-advertise-routes.yaml
       #To remove kube-router 
       kubectl delete -f generic-kuberouter-only-advertise-routes.yaml

#Verify installtion
kubectl -n kube-system get pods -l k8s-app=kube-router -o wide

#*********************************************************Set up Cilium with Direct routing********************************************************************
#Install cilium
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}

#Setup Helm repository
helm repo add cilium https://helm.cilium.io/   
    helm uninstall cilium -n kube-system

helm install cilium cilium/cilium --version 1.11.2 --namespace kube-system \
    --set kubeProxyReplacement=strict \
    --set cluster.name=cluster1 \
    --set cluster.id=1 \
    --set ipam.mode="kubernetes" \
    --set tunnel="disabled" \
    --set ipv4.enabled=true \
    --set k8sServiceHost=192.168.0.46 \
    --set nativeRoutingCIDR="10.0.0.0/8" \
    --set k8sServicePort=6443

#Make sure all system PODs and nodes are healthy and running
kubectl get pods -n kube-system -o wide
kubectl get nodes -o wide

#If "coredens-*" POD(s) are stuck in pending state, reboot nodes!

#Get a Cilium agent's name
MASTER_CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o wide |  grep master | awk '{ print $1}' )

#Verify that VXLAN is not being used
kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium bpf tunnel list

#Validate that Cilium installation
cilium status --wait

#**************************************************Examine BGP mesh*******************************************************
#Install "gobgp" CLI
sudo apt install gobgpd

gobgp neighbor -u c1-kube-node1-cilium
gobgp  global rib -u c1-kube-node1-cilium

ip route

#**************************************************Deploy a test app*******************************************************

#Optional: Untaint maste
kubectl taint node c1-kube-master-cilium node-role.kubernetes.io/master-

#Schedule a Kubernetes deployment using a container from Google samples
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0
#Scale up the replica set to 2
kubectl scale --replicas=2 deployment/hello-world

kubectl get pods -o wide
#apk --no-cache add curl

kubectl expose deployment hello-world --port=8080 --target-port=8080 

kubectl get services

CLUSTERIP=$(kubectl get service hello-world  -o jsonpath='{ .spec.clusterIP }')
echo $CLUSTERIP

PORT=$( kubectl get service hello-world  -o jsonpath='{.spec.ports[0].port}')
echo $PORT

curl http://$CLUSTERIP:$PORT
