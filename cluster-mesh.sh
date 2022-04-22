ssh gary@192.168.0.23

CLUSTER1="cluster1-cntx"
CLUSTER2="cluster2-cntx"

kubectl get nodes -o wide --context $CLUSTER1
kubectl get nodes -o wide --context $CLUSTER2

cilium status --context $CLUSTER1
cilium status --context $CLUSTER2

ip route

cilium clustermesh enable --context $CLUSTER1 --service-type NodePort #LoadBalancer 
    cilium clustermesh disable --context $CLUSTER1
cilium clustermesh enable --context $CLUSTER2 --service-type NodePort #LoadBalancer 
     cilium clustermesh disable --context $CLUSTER2

cilium clustermesh status --context $CLUSTER1 --wait
cilium clustermesh status --context $CLUSTER2 --wait

cilium clustermesh connect --context $CLUSTER1 --destination-context $CLUSTER2
    cilium clustermesh disconnect --context $CLUSTER1 --destination-context $CLUSTER2

cilium clustermesh status --context $CLUSTER1 --wait
cilium clustermesh status --context $CLUSTER2 --wait

ip route

kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.11.2/examples/kubernetes/clustermesh/global-service-example/cluster1.yaml --context $CLUSTER1

kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.11.2/examples/kubernetes/clustermesh/global-service-example/cluster2.yaml --context $CLUSTER2

kubectl get services --context $CLUSTER2

kubectl exec -ti deployment/x-wing -- curl rebel-base

#Cleanup
kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/1.11.2/examples/kubernetes/clustermesh/global-service-example/cluster1.yaml --context $CLUSTER1
kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/1.11.2/examples/kubernetes/clustermesh/global-service-example/cluster2.yaml --context $CLUSTER2


ip route