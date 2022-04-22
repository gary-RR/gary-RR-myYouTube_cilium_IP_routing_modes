alias k='kubectl'

#Disable health check during capture to reduce noise:
cilium config set nable-endpoint-health-checking "false"
cilium config set enable-health-check-nodeport "false"
cilium config set enable-health-checking "false"

#Optionally untaint maste
kubectl taint node c1-kube-master-cilium node-role.kubernetes.io/master-

#Schedule a Kubernetes deployment using a container from Google samples
k create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0

#Scale up the replica set to 2
k scale --replicas=2 deployment/hello-world

k get pods -o wide
CLIENT_POD_NAME=$(k get pods -o wide  |  grep master | awk '{ print $1}' )
    echo $CLIENT_POD_NAME

SERVICE_POD_IP=$(k get pods -o wide |  grep node1  | awk '{ print $6}' )
    echo $SERVICE_POD_IP

#Install curl
k exec -it $CLIENT_POD_NAME -- apk --no-cache add curl

#Call the service directly on teh second node
k exec -it $CLIENT_POD_NAME -- curl http://$SERVICE_POD_IP:8080

#Run this from anothe terminal
sudo tshark -V --color -i eth0  -d udp.port=8472,vxlan -f "port 8472"