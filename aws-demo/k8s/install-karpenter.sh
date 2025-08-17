#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# You can find the possible versions here -> https://gallery.ecr.aws/karpenter/karpenter
KARPENTER_VERSION="1.6.1"
KARPENTER_NAMESPACE="karpenter"


CLUSTER_NAME="luca-karpenter-demo"
CONTROLLER_ROLE_ARN="arn:aws:iam::086771290543:role/KarpenterController-20250817200906281600000002"
QUEUE_NAME="Karpenter-luca-karpenter-demo"

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
    --create-namespace \
    --namespace "$KARPENTER_NAMESPACE" \
    --set "controller.resources.limits.cpu=1" \
    --set "controller.resources.limits.memory=1Gi" \
    --set "controller.resources.requests.cpu=1" \
    --set "controller.resources.requests.memory=1Gi" \
    --set "settings.clusterName=$CLUSTER_NAME" \
    --set "settings.interruptionQueue=$QUEUE_NAME" \
    --version "$KARPENTER_VERSION" \
    --wait
