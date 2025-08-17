# Karpenter Auto-Scaling Demo Script for Kubernetes Meetup

## 🎯 Demo Overview

**Duration**: ~15-20 minutes  
**Audience**: Kubernetes practitioners interested in auto-scaling  
**Goal**: Show how Karpenter intelligently provisions nodes based on workload demands

## 📋 Pre-Demo Checklist

- [ ] Infrastructure deployed via `./scripts/deploy.sh`
- [ ] Terminal windows prepared (3 recommended)
- [ ] Kubectl context set to demo cluster
- [ ] Helm and other tools verified working
- [ ] Choose demo type: CPU scaling OR batch processing

## 🎪 Demo Flow

### 1. Introduction (2 minutes)

**Talking Points:**
- Traditional node management vs. intelligent auto-scaling
- Variable workloads shouldn't require fixed infrastructure costs
- Karpenter solves this with demand-driven provisioning

### 2. Show Initial State (2 minutes)

```bash
# Terminal 1: Show cluster state
kubectl get nodes -o wide
kubectl get pods -A | grep karpenter
```

**Key Points:**
- Only system nodes running (t3.medium with taints)
- Karpenter controller is running
- No workload nodes = minimal infrastructure costs

### 3. Examine Karpenter Configuration (3 minutes)

```bash
# Show NodePools
kubectl get nodepools -o wide
kubectl describe nodepool default-nodepool

# Show EC2NodeClasses  
kubectl get ec2nodeclasses
kubectl describe ec2nodeclass default-nodeclass
```

**Highlight:**
- NodePool defines compute requirements
- EC2NodeClass defines AWS-specific config
- Instance type flexibility and taints for workload isolation
- Spot instance prioritization for cost savings

### 4. Start Monitoring (1 minute)

```bash
# Terminal 2: Karpenter logs
kubectl logs -f deployment/karpenter -n karpenter
```

**Set Expectation:** "Watch this terminal - you'll see Karpenter making decisions in real-time"

### 5. Trigger CPU Workload (3 minutes)

```bash
# Terminal 1: Scale up CPU workload
kubectl scale deployment/cpu-workload-simulator --replicas=3

# Watch node provisioning
watch -n 2 'kubectl get nodes -o wide'
```

**Narrate What's Happening:**
- Pods are pending (need worker nodes)
- Karpenter sees the pending pods
- Evaluates NodePool requirements
- Provisions appropriate instances
- Nodes join cluster and pods get scheduled

### 6. Verify Node Provisioning (2 minutes)

```bash
# Check worker nodes
kubectl get nodes -l karpenter.sh/nodepool
kubectl get pods -o wide | grep cpu-workload

# Verify node resources
kubectl top nodes
kubectl describe nodes | grep -A 10 "Allocated resources"
```

**Key Points:**
- Right instance types chosen automatically
- Pods scheduled efficiently across nodes
- Node labeling and resource allocation working correctly

### 7. Scale Up for Impact (2 minutes)

```bash
# Scale for more dramatic effect
kubectl scale deployment/cpu-workload-simulator --replicas=6

# Watch additional nodes provisioning
watch -n 2 'kubectl get nodes -l karpenter.sh/nodepool'
```

**Show:**
- Additional nodes being provisioned
- Mix of instance types based on availability
- Spot vs on-demand instance selection

### 8. Cost Optimization Demo (2 minutes)

```bash
# Show cost optimization features
kubectl get nodes -l karpenter.sh/nodepool -o yaml | grep "karpenter.sh/capacity-type"
kubectl describe nodepool default-nodepool | grep -A 10 requirements
```

**Highlight:**
- Spot instances prioritized (90% cost savings)
- Instance type flexibility
- Right-sizing based on actual requirements

### 9. Scale Down Magic (3 minutes)

```bash
# Scale down to zero
kubectl scale deployment/cpu-workload-simulator --replicas=0

# Watch nodes being terminated
watch -n 5 'kubectl get nodes -l karpenter.sh/nodepool'
```

**Key Demonstration:**
- Automatic node termination after 30s
- Graceful workload migration
- Return to minimal infrastructure
- Cost optimization in action

### 10. Final State (1 minute)

```bash
kubectl get nodes
kubectl get pods
```

**Wrap-up Points:**
- Back to just system nodes
- Workload infrastructure costs back to $0
- Infrastructure scales with demand, not time

## 💡 Key Messages to Reinforce

1. **Cost Efficiency**: Pay only for what you use, when you use it
2. **Simplicity**: No manual node management or capacity planning
3. **Flexibility**: Supports diverse workload requirements automatically
4. **Production Ready**: Proven at scale with proper observability

## 🎤 Q&A Preparation

**Common Questions:**

**Q: How fast does node provisioning happen?**
A: Typically 1-2 minutes for most instances, depends on AWS availability

**Q: What about data persistence?**
A: Use EBS volumes, EFS, or S3 for model artifacts and data

**Q: Production considerations?**
A: Monitor metrics, set resource limits, use proper cost allocation tags

**Q: Spot instance interruptions?**
A: Karpenter handles gracefully, can mix with on-demand for critical workloads

## 🧹 Post-Demo

- Run demo-presentation.sh for guided walkthrough
- Cleanup with `./scripts/cleanup.sh`
- Share GitHub repo link for attendees

## 🔄 Alternative: Batch Processing Demo

For a different demo focus, use the batch processing script:
```bash
cd k8s/karpenter-demo
./batch-demo-script.sh
```

This demonstrates:
- Multiple job types with different resource requirements
- Instance type selection (CPU-optimized, memory-optimized, general)
- Burst scaling for batch workloads
- Automatic cleanup when jobs complete

## 📊 Optional: Show AWS Console

If time permits, show:
- EC2 instances being created/terminated
- Cost Explorer showing compute usage spikes
- EKS cluster metrics

---

**Pro Tips:**
- Keep Terminal font size large for audience
- Have backup slides in case of AWS issues
- Practice the timing - it's easy to run over
- Prepare for "what if" questions about edge cases
