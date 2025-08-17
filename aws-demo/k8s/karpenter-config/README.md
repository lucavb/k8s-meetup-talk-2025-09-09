# Karpenter Auto-Scaling Configuration

This Helm chart configures Karpenter for general-purpose workloads on AWS EKS clusters. It's optimized for cost-effective auto-scaling of CPU-intensive applications.

## Prerequisites

- Karpenter controller installed in your cluster
- AWS IAM roles and permissions configured
- EKS cluster with appropriate tags for discovery
- Standard EC2 instance types available in your region

## What This Chart Provides

### Default Node Class
- **Optimized for general workloads**: Uses AL2023 AMI with standard configuration
- **Storage**: 50GB GP3 storage for general applications
- **Security**: Instance metadata service v2 required, encrypted storage

### Default Node Pool
- **Instance types**: Supports t3, m5, and c5 series for flexible workloads
- **Spot & On-Demand**: Cost-effective spot instances with on-demand fallback
- **No taints**: Allows general workloads to be scheduled
- **Disruption policy**: Quick cleanup (30s) for cost optimization

## Installation

1. Deploy the chart:
```bash
helm install karpenter-config ./karpenter-config --namespace karpenter
```

2. Verify deployment:
```bash
kubectl get nodepools,ec2nodeclasses -n karpenter
```

## Supported Instance Types

The chart is configured with instance types for general workloads:

| Instance Family | Use Case | Examples |
|----------------|----------|----------|
| t3 | Burstable CPU | t3.medium, t3.large, t3.xlarge |
| m5 | General purpose | m5.large, m5.xlarge, m5.2xlarge |
| c5 | CPU optimized | c5.large, c5.xlarge, c5.2xlarge |

## Deploying Workloads

Your applications can be deployed normally - no special tolerations needed:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-application
spec:
  template:
    spec:
      containers:
        - name: app
          image: your-app-image
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "2000m"
              memory: "1Gi"
```

## Configuration

Key configuration options in `values.yaml`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cluster.name` | EKS cluster name | `karpenter-demo` |
| `nodeClass.name` | Name for the default node class | `default-nodeclass` |
| `nodePool.name` | Name for the default node pool | `default-nodepool` |
| `nodePool.limits.cpu` | Maximum CPU limit | `1000` |
| `nodePool.limits.memory` | Maximum memory limit | `1000Gi` |

## Monitoring

Monitor your worker nodes:

```bash
# Check node provisioning
kubectl get nodes -l karpenter.sh/nodepool

# Monitor node utilization
kubectl top nodes

# View Karpenter logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Check node pool status
kubectl describe nodepool default-nodepool -n karpenter
```

## Cost Optimization

The configuration prioritizes spot instances for cost savings:
- Spot instances are tried first
- On-demand instances as fallback
- Nodes expire after 30s of emptiness
- Efficient consolidation when possible

## Troubleshooting

### Common Issues

1. **Pods stuck in pending**: Check resource requests and available capacity
2. **No nodes provisioned**: Verify instance types available in your region
3. **Nodes not terminating**: Check for workloads preventing node cleanup

### Debugging Commands

```bash
# Check Karpenter events
kubectl get events -n karpenter --sort-by='.lastTimestamp'

# Describe the node pool
kubectl describe nodepool default-nodepool -n karpenter

# Check node capacity
kubectl describe nodes -l karpenter.sh/nodepool
```