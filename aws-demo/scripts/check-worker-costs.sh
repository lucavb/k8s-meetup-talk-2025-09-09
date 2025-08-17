#!/bin/bash

# Script to check actual AWS worker node costs
# Usage: ./check-worker-costs.sh [cluster-name]

set -e

# Get current kubectl context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)

if [[ -z "$CURRENT_CONTEXT" ]]; then
    echo "❌ No kubectl context configured. Please configure kubectl first:"
    echo "   kubectl config use-context <your-context>"
    exit 1
fi

# Extract cluster name and region from kubectl context
# Handle EKS ARN format: arn:aws:eks:region:account:cluster/cluster-name
if [[ "$CURRENT_CONTEXT" =~ arn:aws:eks:([^:]+):[^:]+:cluster/(.+)$ ]]; then
    AWS_REGION="${BASH_REMATCH[1]}"
    CLUSTER_NAME="${BASH_REMATCH[2]}"
elif [[ "$CURRENT_CONTEXT" =~ cluster/([^/]+)$ ]]; then
    # Fallback for simpler cluster contexts
    CLUSTER_NAME="${BASH_REMATCH[1]}"
    # Get region from AWS profile as fallback
    AWS_REGION=$(aws configure get region 2>/dev/null)
else
    echo "❌ Could not parse cluster information from kubectl context: $CURRENT_CONTEXT"
    exit 1
fi

# Override with parameter if provided
if [[ -n "$1" ]]; then
    CLUSTER_NAME="$1"
fi

# Ensure we have both cluster name and region
if [[ -z "$CLUSTER_NAME" ]] || [[ -z "$AWS_REGION" ]]; then
    echo "❌ Could not determine cluster name or region"
    echo "Cluster: $CLUSTER_NAME"
    echo "Region: $AWS_REGION" 
    echo "Context: $CURRENT_CONTEXT"
    exit 1
fi

echo "🔍 Checking actual worker node costs for cluster: $CLUSTER_NAME"
echo "📍 Region: $AWS_REGION"

# Show current AWS profile if set
if [[ -n "$AWS_PROFILE" ]]; then
    echo "🔧 AWS Profile: $AWS_PROFILE"
else
    echo "🔧 AWS Profile: default (or from config/credentials)"
fi

echo

# Get current worker nodes
echo "📊 Current worker nodes:"
kubectl get nodes -l karpenter.sh/nodepool --no-headers 2>/dev/null | wc -l | xargs printf "   Active worker nodes: %s\n" || echo "   No worker nodes found or kubectl not configured"

echo

# Get EC2 instances for this cluster
echo "💰 Checking EC2 instance costs..."
instances=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:karpenter.sh/cluster,Values=$CLUSTER_NAME" \
          "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,LaunchTime]' \
  --output table 2>/dev/null || echo "No instances found or AWS CLI not configured")

if [[ "$instances" == "No instances found or AWS CLI not configured" ]] || [[ -z "$instances" ]]; then
  echo "✅ Current worker node cost: \$0.00/hour (no running instances)"
  echo
  exit 0
fi

echo "$instances"
echo

# Show running instances without pricing (to avoid hardcoded regions)
echo "📋 Running instances:"

while IFS=$'\t' read -r instance_id instance_type state launch_time; do
  if [[ "$instance_id" =~ ^i-[a-f0-9]+ ]]; then
    printf "   %-15s %-15s %s (launched: %s)\n" "$instance_id" "$instance_type" "$state" "$launch_time"
  fi
done <<< "$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:karpenter.sh/cluster,Values=$CLUSTER_NAME" \
          "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,LaunchTime]' \
  --output text 2>/dev/null)"

echo
echo "📊 To monitor costs in real-time:"
echo "   aws ce get-cost-and-usage --time-period Start=$(date -d '1 day ago' '+%Y-%m-%d'),End=$(date '+%Y-%m-%d') --granularity DAILY --metrics BlendedCost --group-by Type=DIMENSION,Key=SERVICE"
