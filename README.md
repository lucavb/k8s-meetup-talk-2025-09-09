# Kubernetes + Karpenter Auto-Scaling Demo

A comprehensive demonstration project for K8s meetup talks showing how to achieve **40% cost savings** using Karpenter for intelligent auto-scaling of workloads in EKS. From zero-cost idle infrastructure to smart scaling based on actual demand.

## 🎯 Demo Overview

This project demonstrates:
- **Cost Optimization**: Start at $0/hour, scale up only when needed, return to $0/hour when idle
- **EKS Cluster** with Karpenter 1.6.0 for intelligent node provisioning
- **Smart Auto-scaling** for CPU-intensive workloads using spot instances (60-90% cost savings)
- **Real-time Scaling** based on actual workload demands with HPA integration
- **Professional Presentation** using Slidev with live demo capabilities

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ CPU Workloads   │───▶│    Karpenter     │───▶│ Spot Instances  │
│ (HPA + Pods)    │    │  (Controller)    │    │ (Cost Optimized)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         └────────────────────────┼───────────────────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │      EKS Cluster           │
                    │   (Kubernetes 1.33)        │
                    │                            │
                    │ ┌────────────────────────┐ │
                    │ │    System Nodes        │ │
                    │ │   (t3.medium, tainted) │ │
                    │ └────────────────────────┘ │
                    └────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- **AWS CLI** configured with appropriate permissions (EKS, EC2, IAM, VPC)
- **OpenTofu >= 1.6.0** (preferred) or Terraform >= 1.5.0
- **kubectl** - Kubernetes command-line tool
- **Helm >= 3.0** - Package manager for Kubernetes
- **jq** - JSON processor (for scripts)

### 1. Configure Infrastructure
```bash
cd aws-demo
# Copy and customize configuration
cp opentofu/opentofu.tfvars.example opentofu/opentofu.tfvars
# Edit with your preferred region and cluster name
```

### 2. Deploy Infrastructure
```bash
./scripts/deploy.sh
# Takes ~15 minutes to deploy EKS + Karpenter + Demo apps
```

### 3. Run Live Demo
```bash
# Follow the guided demo script
./scripts/demo-presentation.sh
```

### 4. Monitor Costs
```bash
# Check current worker node costs (should be $0 when idle)
./scripts/check-worker-costs.sh
```

### 5. Cleanup
```bash
./scripts/cleanup.sh
# Removes ALL resources - confirm with "yes"
```

## 📁 Project Structure

```
├── README.md                    # This file
├── aws-bill.png                 # AWS cost comparison screenshot
├── slides/                     # Slidev presentation (Node.js/Vue)
│   ├── slides.md              # Main presentation content
│   ├── package.json           # Slidev dependencies
│   ├── components/            # Custom Vue components
│   ├── assets/                # Images and presentation assets
│   ├── setup/                 # Slidev configuration
│   ├── README.md              # Slidev usage guide
│   └── netlify.toml           # Deployment config
└── aws-demo/                   # AWS demonstration infrastructure
    ├── opentofu/               # Infrastructure as Code (OpenTofu)
    │   ├── main.tf             # EKS cluster, VPC, and Karpenter setup
    │   ├── variables.tf        # Configuration variables
    │   ├── outputs.tf          # Cluster and Karpenter outputs
    │   ├── opentofu.tfvars.example # Template configuration
    │   └── terraform.tfstate   # State file (auto-generated)
    ├── k8s/                    # Kubernetes manifests and configurations
    │   ├── install-karpenter.sh # Karpenter installation script
    │   ├── karpenter-config/   # Helm chart for NodePools and EC2NodeClasses
    │   │   ├── Chart.yaml      
    │   │   ├── values.yaml     
    │   │   ├── templates/      # Karpenter resource templates
    │   │   └── README.md       
    │   └── karpenter-demo/     # Demo workloads and HPA configurations
    │       ├── scaling-demo.yaml # CPU workload simulator
    │       └── README.md       # Demo usage guide
    ├── scripts/               # Automation and utility scripts
    │   ├── deploy.sh          # Complete deployment automation
    │   ├── cleanup.sh         # Safe resource cleanup
    │   └── check-worker-costs.sh # Real-time cost monitoring
    └── docs/                  # Documentation
        └── demo-script.md     # 15-minute presentation script
```

## 💰 Cost Optimization Features

- **Zero-cost idle**: Start at $0/hour when no workloads are running
- **Spot instances**: 60-90% savings vs on-demand pricing
- **System nodes**: Dedicated t3.medium nodes for Karpenter/system pods (tainted to prevent workload scheduling)
- **Auto-termination**: Unused worker nodes automatically terminated after 30 seconds
- **Right-sizing**: Karpenter selects optimal instance types based on actual resource requests
- **Real-time monitoring**: `check-worker-costs.sh` script shows current AWS spend

### Cost Comparison Example
```bash
# Traditional approach: Fixed ASG with 3 m5.large instances
# Cost: $0.096/hour × 3 × 24/7 = ~$208/month

# Karpenter approach: Scale from 0 → workload → 0
# Cost: ~$0/hour when idle + ~$0.03/hour when running (spot)
# Savings: ~90% for typical intermittent workloads
```

## 🎤 For Presenters

### 1. **Slides Setup** (Slidev v52.1.0)
```bash
cd slides
npm install                     # Install Slidev dependencies
npm run dev                     # Start development server
# Opens at http://localhost:3030 with live reload
```

### 2. **AWS Infrastructure Setup**
```bash
cd aws-demo
cp opentofu/opentofu.tfvars.example opentofu/opentofu.tfvars
# Edit tfvars with your AWS region and cluster name
./scripts/deploy.sh            # Takes ~15 minutes to deploy everything
```

### 3. **Live Demo** (15-20 minutes)
```bash
# Follow the detailed demo script
./scripts/demo-presentation.sh  # Guided walkthrough with timing
# OR follow manual steps in docs/demo-script.md
```

### 4. **Cleanup**
```bash
./scripts/cleanup.sh           # Removes ALL resources safely
# Confirms deletion and provides cost verification
```

### 📊 Slidev Features
- **Live editing**: Modify `slides.md` and see changes instantly
- **Presenter mode**: Press `p` for speaker notes and timing
- **Overview mode**: Press `o` to see all slides at once
- **Export options**: `npm run export` for PDF, `npm run build` for hosting
- **Navigation**: Space/arrows for slides, `f` for fullscreen, `ESC` to exit modes
- **Interactive elements**: Click animations, code highlighting, Mermaid diagrams

## 🧪 Demo Applications

### CPU Workload Simulator
The main demo application simulates realistic CPU-intensive workloads:

```yaml
# Key features:
- Variable load patterns (light → medium → high CPU usage)
- Resource monitoring and logging
- HPA integration (scales 1-10 pods based on 70% CPU/80% memory)
- Smart scaling policies (quick scale-up, controlled scale-down)
```

### Demo Scenarios
1. **Zero-cost starting point**: Verify $0/hour with no worker nodes
2. **On-demand provisioning**: Scale workload → watch nodes appear in ~60 seconds
3. **HPA integration**: Automatic pod scaling based on CPU/memory pressure
4. **Cost monitoring**: Real-time cost tracking with `check-worker-costs.sh`
5. **Auto-termination**: Scale to zero → watch nodes disappear → return to $0/hour

## 🔧 Technical Components

### Infrastructure (OpenTofu)
- **EKS Cluster**: Kubernetes 1.33 with Pod Identity and VPC CNI
- **VPC Setup**: Public/private subnets across 2 AZs with NAT Gateway
- **Karpenter Integration**: IRSA roles, instance profiles, and SQS queue for interruption handling
- **Node Groups**: Dedicated t3.medium system nodes (tainted for system workloads only)

### Karpenter Configuration
- **NodePools**: Define compute requirements and scaling policies
- **EC2NodeClasses**: AWS-specific configurations (AMI, security groups, subnets)
- **Instance Selection**: Flexible instance types with spot prioritization
- **Taints/Tolerations**: Workload isolation and proper scheduling

### Monitoring & Observability
```bash
# Monitor Karpenter decision-making
kubectl logs -f deployment/karpenter -n karpenter

# Check resource utilization
kubectl top nodes && kubectl top pods

# View HPA scaling decisions
kubectl get hpa -w

# Monitor AWS costs in real-time
./scripts/check-worker-costs.sh
```

## 📋 Demo Script

For your meetup presentation, follow the **detailed 15-20 minute demo script** in `aws-demo/docs/demo-script.md`.

Key talking points:
- **Cost efficiency**: Pay only for what you use, when you use it
- **Simplicity**: No manual node management or capacity planning  
- **Flexibility**: Supports diverse workload requirements automatically
- **Production ready**: Proven at scale with proper observability

## 🛠️ Troubleshooting

### Common Issues

**Pods stuck in Pending state:**
```bash
# Check Karpenter logs for provisioning issues
kubectl logs -f deployment/karpenter -n karpenter

# Verify NodePool and EC2NodeClass configuration  
kubectl get nodepools,ec2nodeclasses -o wide

# Check if resource requests exceed available instance capacity
kubectl describe pod <pending-pod>
```

**HPA not scaling:**
```bash
# Ensure metrics server is running
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Verify resource requests are defined in deployments
kubectl get hpa -o yaml

# Check HPA status
kubectl describe hpa <hpa-name>
```

**Deployment fails:**
```bash
# Check OpenTofu state
cd opentofu && tofu show

# Verify AWS permissions
aws sts get-caller-identity

# Check for resource conflicts
aws eks describe-cluster --name <cluster-name>
```

**Costs higher than expected:**
```bash
# Check for orphaned instances
./scripts/check-worker-costs.sh

# Verify automatic node termination
kubectl get nodes -w

# Review Karpenter NodePool configurations
kubectl get nodepools -o yaml
```

## 📚 Additional Resources

### Karpenter Documentation
- [Official Karpenter Docs](https://karpenter.sh/)
- [Best Practices Guide](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [Troubleshooting Guide](https://karpenter.sh/docs/troubleshooting/)

### AWS EKS Resources  
- [EKS User Guide](https://docs.aws.amazon.com/eks/)
- [EKS Optimized AMI](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html)
- [Cost Optimization](https://aws.amazon.com/blogs/containers/cost-optimization-for-kubernetes-on-aws/)

### Presentation Resources
- [Slidev Documentation](https://sli.dev)
- [Kubernetes Meetup Presentation Tips](https://kubernetes.io/docs/contribute/suggesting-improvements/)

## ❓ FAQ

**Q: How much will this demo cost?**  
A: When idle: $0/hour. During demo: ~$0.03-0.10/hour (spot pricing). Total demo cost: typically < $1.

**Q: How fast does node provisioning happen?**  
A: Typically 60-90 seconds for most instance types, depending on AWS availability.

**Q: What about data persistence?**  
A: Use EBS volumes, EFS, or S3 for persistent data. Demo focuses on stateless workloads.

**Q: Production considerations?**  
A: Monitor metrics, set resource limits, use proper tagging, configure interruption handling.

**Q: Spot instance interruptions?**  
A: Karpenter handles gracefully with SQS queue notifications. Mix spot/on-demand for critical workloads.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-demo`)  
3. Commit your changes (`git commit -am 'Add amazing demo feature'`)
4. Push to the branch (`git push origin feature/amazing-demo`)
5. Create a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**Ready to revolutionize your Kubernetes scaling? Deploy the demo and experience the future of cost-effective infrastructure! 🚀**
