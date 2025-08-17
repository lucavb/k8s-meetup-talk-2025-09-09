#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Read from tfvars if available
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

confirm_cleanup() {
    echo ""
    log_warning "🚨 This will DELETE all resources including:"
    echo "   - EKS Cluster: $CLUSTER_NAME"
    echo "   - VPC and networking resources"
    echo "   - IAM roles and policies"
    echo "   - Any running workloads and nodes"
    echo ""
    
    read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirm
    
    if [[ $confirm != "yes" ]]; then
        log_info "Cleanup cancelled by user"
        exit 0
    fi
}

cleanup_workloads() {
    log_info "Cleaning up Kubernetes workloads..."
    
    if kubectl cluster-info &> /dev/null; then
        # Scale down deployments to avoid new node creation
        log_info "Scaling down deployments..."

        kubectl scale deployment/cpu-workload-simulator --replicas=0 2>/dev/null || true
        
        # Delete demo applications
        log_info "Deleting demo applications..."
        kubectl delete -f k8s/karpenter-demo/ --ignore-not-found=true
        

        
        # Delete Karpenter resources (NodePools and EC2NodeClasses) - handle missing CRDs gracefully
        log_info "Deleting Karpenter resources..."
        if kubectl get crd nodepools.karpenter.sh &>/dev/null; then
            kubectl delete -f k8s/karpenter/nodepool.yaml --ignore-not-found=true 2>/dev/null || log_warning "NodePools may already be deleted"
        else
            log_warning "NodePool CRDs not found, skipping NodePool deletion"
        fi
        
        if kubectl get crd ec2nodeclasses.karpenter.k8s.aws &>/dev/null; then
            kubectl delete -f k8s/karpenter/ec2nodeclass.yaml --ignore-not-found=true 2>/dev/null || log_warning "EC2NodeClasses may already be deleted"
        else
            log_warning "EC2NodeClass CRDs not found, skipping EC2NodeClass deletion"
        fi
        
        # Wait for nodes to be drained
        log_info "Waiting for Karpenter nodes to be cleaned up..."
        sleep 30
        
        # Force delete any remaining Karpenter-managed nodes
        KARPENTER_NODES=$(kubectl get nodes -l karpenter.sh/nodepool --no-headers 2>/dev/null | awk '{print $1}' || true)
        if [[ -n "$KARPENTER_NODES" ]]; then
            log_info "Force deleting remaining Karpenter nodes..."
            echo "$KARPENTER_NODES" | xargs -r kubectl delete node --force --grace-period=0
        fi
        
        log_success "Kubernetes workloads cleaned up"
    else
        log_warning "Cluster not accessible, skipping workload cleanup"
    fi
}

cleanup_karpenter() {
    log_info "Uninstalling Karpenter..."
    
    if kubectl cluster-info &> /dev/null; then
        # Remove Karpenter Helm release
        if helm list -n karpenter 2>/dev/null | grep -q karpenter; then
            helm uninstall karpenter -n karpenter
            log_success "Karpenter Helm release removed"
        fi
        
        # Delete Karpenter namespace
        kubectl delete namespace karpenter --ignore-not-found=true
        
        log_success "Karpenter cleanup completed"
    else
        log_warning "Cluster not accessible, skipping Karpenter cleanup"
    fi
}

cleanup_aws_resources() {
    log_info "Cleaning up additional AWS resources..."
    
    # Find and terminate any remaining EC2 instances created by Karpenter
    log_info "Checking for orphaned EC2 instances..."
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --filters "Name=tag:karpenter.sh/cluster,Values=$CLUSTER_NAME" \
                  "Name=instance-state-name,Values=running,pending" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text 2>/dev/null || true)
    
    if [[ -n "$INSTANCE_IDS" && "$INSTANCE_IDS" != "None" ]]; then
        log_warning "Found orphaned instances, terminating: $INSTANCE_IDS"
        aws ec2 terminate-instances --region $AWS_REGION --instance-ids $INSTANCE_IDS
        
        # Wait for instances to terminate
        log_info "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --region $AWS_REGION --instance-ids $INSTANCE_IDS || true
    fi
    
    # Clean up any remaining launch templates
    log_info "Cleaning up launch templates..."
    LAUNCH_TEMPLATES=$(aws ec2 describe-launch-templates \
        --region $AWS_REGION \
        --filters "Name=tag:karpenter.sh/cluster,Values=$CLUSTER_NAME" \
        --query 'LaunchTemplates[*].LaunchTemplateName' \
        --output text 2>/dev/null || true)
    
    if [[ -n "$LAUNCH_TEMPLATES" && "$LAUNCH_TEMPLATES" != "None" ]]; then
        for template in $LAUNCH_TEMPLATES; do
            log_info "Deleting launch template: $template"
            aws ec2 delete-launch-template --region $AWS_REGION --launch-template-name "$template" || true
        done
    fi
    
    log_success "AWS resource cleanup completed"
}

cleanup_opentofu() {
    log_info "Destroying OpenTofu infrastructure..."
    
    cd opentofu
    
    # Check if state file exists and has resources
    if [ -f "terraform.tfstate" ]; then
        RESOURCE_COUNT=$(tofu show -json 2>/dev/null | jq -r '.values.root_module.resources // [] | length' 2>/dev/null || echo "0")
        
        if [ "$RESOURCE_COUNT" -gt 0 ]; then
            log_info "Found $RESOURCE_COUNT resources in state, destroying..."
            
            # Destroy all OpenTofu-managed resources
            if [ -f "opentofu.tfvars" ]; then
                tofu destroy -auto-approve -var-file="opentofu.tfvars"
            else
                tofu destroy -auto-approve -var="cluster_name=$CLUSTER_NAME" -var="aws_region=$AWS_REGION"
            fi
        else
            log_warning "No resources found in OpenTofu state"
        fi
    else
        log_warning "No OpenTofu state file found"
    fi
    
    # Clean up state files and plan files
    log_info "Cleaning up OpenTofu state and plan files..."
    rm -f terraform.tfstate terraform.tfstate.backup tfplan
    
    log_success "OpenTofu cleanup completed"
    cd ..
}

cleanup_local_config() {
    log_info "Cleaning up local configuration..."
    
    # Remove kubectl context
    kubectl config delete-cluster $CLUSTER_NAME 2>/dev/null || true
    kubectl config delete-context $CLUSTER_NAME 2>/dev/null || true
    kubectl config unset users.arn:aws:eks:$AWS_REGION:*:cluster/$CLUSTER_NAME 2>/dev/null || true
    
    # Clean up temporary files
    rm -f /tmp/karpenter-values.yaml
    
    log_success "Local configuration cleaned up"
}

verify_cleanup() {
    log_info "Verifying cleanup..."
    
    # Check for any remaining resources
    log_info "Checking for remaining AWS resources..."
    
    # Check for EKS cluster
    if aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME &>/dev/null; then
        log_warning "EKS cluster still exists (may take a few minutes to fully delete)"
    else
        log_success "EKS cluster deleted"
    fi
    
    # Check for instances
    REMAINING_INSTANCES=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --filters "Name=tag:karpenter.sh/cluster,Values=$CLUSTER_NAME" \
                  "Name=instance-state-name,Values=running,pending" \
        --query 'length(Reservations[*].Instances[*])' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$REMAINING_INSTANCES" -gt 0 ]]; then
        log_warning "$REMAINING_INSTANCES instances still exist"
    else
        log_success "No remaining instances found"
    fi
    
    log_success "Cleanup verification completed"
}

main() {
    echo "🧹 Karpenter + AI Demo Cleanup Script"
    echo "====================================="
    
    confirm_cleanup
    
    log_info "Starting cleanup process..."
    
    cleanup_workloads
    cleanup_karpenter
    cleanup_aws_resources
    
    # Brief pause to let AWS resources settle
    log_info "Waiting for AWS resources to settle..."
    sleep 10
    
    cleanup_opentofu
    cleanup_local_config
    verify_cleanup
    
    echo ""
    log_success "🎉 Cleanup completed successfully!"
    echo ""
    log_info "💡 Tips for next deployment:"
    echo "   - Check AWS console for any remaining resources"
    echo "   - Verify your AWS costs have returned to baseline"
    echo "   - Run './scripts/deploy.sh' to redeploy when ready"
    echo ""
}

# Run main function
main "$@"
