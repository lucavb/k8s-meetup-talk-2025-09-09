# Karpenter CPU Auto-Scaling Demo

This demo showcases Karpenter's intelligent node provisioning and cost optimization for CPU-intensive workloads. Perfect for demonstrating the "From 40% Savings to Smart Scaling" concepts with real-world scenarios.

**🎯 Demo Highlights:**
- Start at **$0/hour** with zero worker nodes
- Scale up **automatically** when workloads arrive  
- Provision **right-sized** instances in ~60 seconds
- Scale down to **$0/hour** when workloads complete

## Overview

The demo includes:
- **CPU Workload Simulator**: Configurable CPU-intensive applications that generate realistic workload patterns
- **Automatic Scaling**: Karpenter provisions nodes on-demand based on workload requirements
- **Horizontal Pod Autoscaler**: Automatically scales pods based on CPU and memory usage
- **Cost Optimization**: Zero idle costs with automatic scale-down when workloads complete

## Components

### 1. CPU Workload Simulator
- **Purpose**: Generates variable CPU load to demonstrate Karpenter scaling
- **Features**: Configurable load patterns, resource monitoring, realistic workload simulation  
- **Scaling**: HPA scales pods based on CPU utilization (70% target) and memory usage (80% target)
- **Smart Load Generation**: Alternates between light, medium, and high CPU usage patterns to simulate real applications

### 2. Horizontal Pod Autoscaler
- **Min/Max Replicas**: Scales from 1 to 10 pods automatically
- **CPU Target**: 70% average CPU utilization
- **Memory Target**: 80% average memory utilization
- **Smart Scaling**: Quick scale-up (30s) and controlled scale-down (60s) for stability

## Architecture

### Node Tainting Strategy
- **System Nodes**: EKS managed node group with `node-role.kubernetes.io/system=true:NoSchedule` taint
- **Worker Nodes**: Karpenter-provisioned nodes with no taints
- **Result**: All application workloads run exclusively on Karpenter nodes

This ensures:
- System components (Karpenter, CoreDNS, etc.) run on dedicated system nodes
- All demo workloads trigger Karpenter scaling
- Clear cost separation between system and workload infrastructure

## Quick Start

### Step 1: Deploy Karpenter Configuration
```bash
# Deploy the Karpenter node configuration
helm install karpenter-config ../karpenter-config --namespace karpenter
```

### Step 2: Deploy Demo Applications
```bash
# Deploy the scaling demo
kubectl apply -f scaling-demo.yaml

# Monitor the deployment
kubectl get pods -w
```

### Step 3: Test Auto-Scaling
```bash
# Start CPU workload to trigger scaling
kubectl scale deployment/cpu-workload-simulator --replicas=3

# Watch nodes being provisioned
kubectl get nodes -w

# Monitor HPA behavior
kubectl get hpa -w
```

### Step 4: Scale Down and Observe Cleanup
```bash
# Scale down to trigger automatic node cleanup
kubectl scale deployment/cpu-workload-simulator --replicas=0

# Watch Karpenter terminate unused nodes
kubectl get nodes -w

# Check costs return to zero
../../scripts/check-worker-costs.sh
```

## Demo Scenarios

### Scenario 1: Zero-Cost Starting Point 
1. Verify cluster starts with no worker nodes: `kubectl get nodes -l karpenter.sh/nodepool`
2. Check current costs: `../../scripts/check-worker-costs.sh` (should be $0)
3. Show pending workloads need nodes to run

### Scenario 2: On-Demand Node Provisioning
1. Scale CPU workload simulator: `kubectl scale deployment/cpu-workload-simulator --replicas=3`
2. Watch pods go from Pending to Running as Karpenter provisions nodes
3. Show optimal instance selection and placement

### Scenario 3: Automatic HPA Scaling  
1. Scale workload higher: `kubectl scale deployment/cpu-workload-simulator --replicas=6`
2. Observe HPA responding to CPU pressure and scaling pods automatically
3. Watch Karpenter add additional nodes as needed

### Scenario 4: Zero-Cost Scale-Down
1. Scale workload to 0: `kubectl scale deployment/cpu-workload-simulator --replicas=0`
2. Watch Karpenter terminate unused nodes automatically
3. Confirm return to $0 costs: `../../scripts/check-worker-costs.sh`

## Monitoring

### Check Node Provisioning
```bash
# Watch Karpenter provision nodes
kubectl get nodes -w

# Check node details and capacity
kubectl describe nodes

# Monitor Karpenter logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

### Monitor Resource Usage
```bash
# Check pod resource consumption
kubectl top pods

# View HPA status
kubectl get hpa

# Check node resource utilization
kubectl top nodes
```

### View Application Logs
```bash
# CPU workload simulator logs (shows load patterns and CPU usage)
kubectl logs -f deployment/cpu-workload-simulator

# Watch individual pod logs to see workload distribution
kubectl logs -f -l app=cpu-workload-simulator
```

## Configuration Options

### CPU Workload Resources
Edit the deployment resource requests/limits:
```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "1Gi"
```

### HPA Configuration
Modify scaling behavior:
```yaml
minReplicas: 1
maxReplicas: 10
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70
```

## Troubleshooting

### Pods Stuck in Pending
- Check node capacity: `kubectl get nodes -o wide`
- Verify resource requests vs available capacity
- Check Karpenter logs for provisioning issues

### HPA Not Scaling
- Ensure metrics server is running: `kubectl get pods -n kube-system -l k8s-app=metrics-server`
- Check pod resource requests are defined
- Monitor HPA status: `kubectl describe hpa`

### Nodes Not Provisioning
- Verify Karpenter configuration: `kubectl get nodepools,ec2nodeclasses`
- Check AWS permissions and instance availability
- Review Karpenter controller logs

## Cleanup

```bash
# Scale down workloads (triggers automatic node cleanup)
kubectl scale deployment/cpu-workload-simulator --replicas=0

# Watch nodes terminate automatically
kubectl get nodes -w

# Remove demo applications
kubectl delete -f scaling-demo.yaml

# Verify costs returned to zero
../../scripts/check-worker-costs.sh

# Karpenter automatically cleans up unused nodes within 30 seconds
```

## Performance Tips

- **Resource Requests**: Always define CPU/memory requests for proper scheduling
- **Node Utilization**: Karpenter optimizes for bin-packing efficiency
- **Scaling Policies**: Configure HPA behavior for your workload characteristics
- **Instance Types**: Karpenter automatically selects optimal instance types

## Cost Optimization

- **Spot Instances**: Karpenter uses spot instances by default (60-70% cost savings)
- **Auto-termination**: Nodes automatically terminate when unused (configurable TTL)
- **Right-sizing**: Multiple instance types ensure optimal cost/performance ratio
- **Consolidation**: Karpenter consolidates workloads to minimize node count