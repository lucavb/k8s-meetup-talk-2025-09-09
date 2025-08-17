#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KARPENTER_VERSION="1.6.0"

# Read configuration from tfvars file if it exists
if [ -f "opentofu/opentofu.tfvars" ]; then
    AWS_REGION=$(grep '^aws_region' opentofu/opentofu.tfvars | cut -d'"' -f2)
    CLUSTER_NAME=$(grep '^cluster_name' opentofu/opentofu.tfvars | cut -d'"' -f2)
else
    # Fallback defaults
    AWS_REGION="us-west-2"
    CLUSTER_NAME="karpenter-demo"
fi

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if required tools are installed
    local tools=("tofu" "kubectl" "helm" "aws")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

deploy_infrastructure() {
    log_info "Deploying AWS infrastructure with OpenTofu..."
    
    cd opentofu
    
    # Verify tfvars file exists
    if [ ! -f "opentofu.tfvars" ]; then
        log_error "opentofu.tfvars file not found! Please copy from opentofu.tfvars.example and configure."
        exit 1
    fi
    
    # Show configuration being used
    log_info "Using configuration:"
    echo "  Region: $AWS_REGION"
    echo "  Cluster: $CLUSTER_NAME"
    
    # Initialize OpenTofu
    log_info "Initializing OpenTofu..."
    tofu init
    
    # Validate configuration
    log_info "Validating OpenTofu configuration..."
    tofu validate
    
    # Plan the deployment
    log_info "Planning OpenTofu deployment..."
    tofu plan -var-file="opentofu.tfvars" -out=tfplan
    
    # Apply the configuration
    log_info "Applying OpenTofu configuration..."
    tofu apply -auto-approve tfplan
    
    # Get outputs
    log_info "Getting OpenTofu outputs..."
    CLUSTER_ENDPOINT=$(tofu output -raw cluster_endpoint)
    KARPENTER_ROLE_ARN=$(tofu output -raw karpenter_irsa_arn)
    INSTANCE_PROFILE=$(tofu output -raw karpenter_instance_profile_name)
    
    # Verify state was properly written
    log_info "Verifying OpenTofu state..."
    RESOURCE_COUNT=$(tofu show -json 2>/dev/null | jq -r '.values.root_module.resources // [] | length' 2>/dev/null || echo "0")
    log_info "OpenTofu is now tracking $RESOURCE_COUNT resources"
    
    if [ "$RESOURCE_COUNT" -eq 0 ]; then
        log_error "No resources in OpenTofu state! Something went wrong."
        exit 1
    fi
    
    log_success "Infrastructure deployment completed"
    cd ..
}

configure_kubectl() {
    log_info "Configuring kubectl..."
    
    # Update kubeconfig
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        log_success "kubectl configured successfully"
    else
        log_error "Failed to configure kubectl"
        exit 1
    fi
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
}

deploy_karpenter() {
    log_info "Deploying Karpenter..."
    
    # Add Karpenter Helm repository
    helm repo add karpenter https://karpenter.sh/v$KARPENTER_VERSION
    helm repo update
    
    # Create Karpenter namespace
    kubectl create namespace karpenter --dry-run=client -o yaml | kubectl apply -f -
    
    # Prepare Helm values
    cat > /tmp/karpenter-values.yaml << EOF
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: $KARPENTER_ROLE_ARN

settings:
  clusterName: $CLUSTER_NAME
  clusterEndpoint: $CLUSTER_ENDPOINT
  defaultInstanceProfile: $INSTANCE_PROFILE
  aws:
    region: $AWS_REGION

controller:
  nodeSelector:
    node-role.kubernetes.io/system: "true"
  tolerations:
    - key: node-role.kubernetes.io/system
      operator: Equal
      value: "true"
      effect: NoSchedule

replicas: 2
EOF
    
    # Deploy Karpenter
    helm upgrade --install karpenter karpenter/karpenter \
        --namespace karpenter \
        --version $KARPENTER_VERSION \
        --values /tmp/karpenter-values.yaml \
        --wait
    
    log_success "Karpenter deployed successfully"
    
    # Wait for Karpenter to be ready
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=karpenter -n karpenter --timeout=300s
}

configure_karpenter_resources() {
    log_info "Configuring Karpenter NodePools and EC2NodeClasses..."
    
    # Add discovery tags to subnets and security groups
    log_info "Adding discovery tags to AWS resources..."
    
    # Tag subnets
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$(tofu -chdir=opentofu output -raw vpc_id)" \
        --query 'Subnets[*].SubnetId' --output text)
    
    for subnet_id in $SUBNET_IDS; do
        aws ec2 create-tags \
            --resources $subnet_id \
            --tags Key=karpenter.sh/discovery,Value=$CLUSTER_NAME
    done
    
    # Tag security groups
    SG_IDS=$(tofu -chdir=opentofu output -raw cluster_security_group_id)
    NODE_SG_ID=$(tofu -chdir=opentofu output -raw node_security_group_id)
    
    aws ec2 create-tags \
        --resources $SG_IDS $NODE_SG_ID \
        --tags Key=karpenter.sh/discovery,Value=$CLUSTER_NAME
    
    # Deploy NodePools and EC2NodeClasses using Helm chart
    NODE_ROLE_NAME=$(tofu -chdir=opentofu output -raw karpenter_node_iam_role_name)
    
    helm install karpenter-config k8s/karpenter-config --namespace karpenter \
        --set aws.iam.nodeRole="$NODE_ROLE_NAME" \
        --set aws.eks.clusterName="$CLUSTER_NAME" \
        --set cluster.name="$CLUSTER_NAME" \
        --set cluster.discoveryTag="$CLUSTER_NAME" \
        --set cluster.instanceProfile="$INSTANCE_PROFILE"
    
    log_success "Karpenter resources configured"
}



deploy_demo_applications() {
    log_info "Deploying demo applications..."
    
    # Deploy scaling demo
    kubectl apply -f k8s/karpenter-demo/scaling-demo.yaml
    
    log_success "Demo applications deployed"
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check cluster status
    echo ""
    log_info "Cluster Info:"
    kubectl cluster-info
    
    echo ""
    log_info "Nodes:"
    kubectl get nodes -o wide
    
    echo ""
    log_info "Karpenter Status:"
    kubectl get pods -n karpenter
    
    echo ""
    log_info "NodePools:"
    kubectl get nodepools -o wide
    
    echo ""
    log_info "EC2NodeClasses:"
    kubectl get ec2nodeclasses -o wide
    
    log_success "Deployment verification completed"
}

print_demo_instructions() {
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo ""
    echo "📋 Demo Instructions:"
    echo "===================="
    echo ""
    echo "1. 🔍 Monitor Karpenter logs:"
    echo "   kubectl logs -f deployment/karpenter -n karpenter"
    echo ""
    echo "2. 🚀 Start CPU workload (triggers node provisioning):"
    echo "   kubectl scale deployment/cpu-workload-simulator --replicas=3"
    echo ""
    echo "3. 📊 Watch nodes being created:"
    echo "   watch 'kubectl get nodes -o wide'"
    echo ""
    echo "4. 🌐 Access the demo web service:"
    echo "   kubectl port-forward svc/web-service-demo 8080:80"
    echo "   # Then visit http://localhost:8080"
    echo ""
    echo "5. 🎯 Scale up for more dramatic effect:"
    echo "   kubectl scale deployment/cpu-workload-simulator --replicas=8"
    echo ""
    echo "6. 📈 Test horizontal pod autoscaling:"
    echo "   kubectl get hpa"
    echo ""
    echo "7. ⬇️  Scale down to see nodes terminate:"
    echo "   kubectl scale deployment/cpu-workload-simulator --replicas=0"
    echo ""
    echo "8. 📊 Watch pods and nodes:"
    echo "   kubectl get pods,nodes -o wide"
    echo ""
    echo "📝 For cleanup: ./scripts/cleanup.sh"
    echo ""
}

main() {
    echo "🚀 Karpenter Auto-Scaling Demo Deployment Script"
    echo "================================================="
    
    check_prerequisites
    deploy_infrastructure
    configure_kubectl
    deploy_karpenter
    configure_karpenter_resources
    deploy_demo_applications
    verify_deployment
    print_demo_instructions
    
    log_success "All done! Ready for your Kubernetes meetup demo! 🎯"
}

# Run main function
main "$@"
