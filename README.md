# Kubernetes Infrastructure on AWS with Terraform and Karpenter while utilizing Graviton and Spot instances.

This repository contains Terraform code to deploy an EKS cluster on AWS, leveraging Karpenter for autoscaling and utilizing Graviton instances for better price/performance.

## Prerequisites

1. Terraform: >= 1.9.3
2. AWS CLI: 2.11.25 or higher.
3. kubectl: 1.31
4. Helm: v3.15.3.

## Usage
Create s3 bucket for state file (project-terraform-state)

Set your ACCOUNT_ID in locals.tf

Configure your AWS CLI credentials
This will prompt you to enter:

AWS Access Key ID
AWS Secret Access Key
Default region
Default output format

```bash
# Configure CLI with aws configure command  
aws configure
```

To provision the provided configurations you need to execute:

```bash
$ cd EKS-karpenter-terraform/terraform/provider/aws
$ terraform init
$ terraform workspace new dev
$ terraform workspace select dev
$ terraform plan
$ terraform apply
```

## Example Karpenter Deployment

```bash
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  instanceProfile: arn:aws:iam::ACCOUNT_ID:instance-profile/KarpenterInstanceProfile
  subnetSelector:
    karpenter: enabled
  securityGroupSelector:
    karpenter: enabled
  # Block device configuration
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
        encrypted: true
  # Resource tags
  tags:
    Environment: "dev"
    ManagedBy: "karpenter"
---
# NodePool for scheduling and scaling configuration
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]
        - key: karpenter.k8s.aws/capacity-type
          operator: In
          values: ["on-demand", "spot"]
      nodeClassRef:
        name: default
  # Resource limits
  limits:
    cpu: "1000"
    memory: "1000Gi"
  # Disruption configuration
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
    expireAfter: 168h  # 7 days
```

```bash
# First, make sure you have updated your local kubeconfig
aws eks --region us-east-1 update-kubeconfig --name dev-eks-us-east-1
```

## Running Pods on Specific Instance Types
To run a pod or deployment on a specific instance type (x86 or Graviton), you can use node selectors.

### Example Deployment on x86 Instance
Create a file named nginx-x86.yaml with the following content:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: x86-pod
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
    - name: nginx
      image: nginx
      ports:
        - containerPort: 80
```
Apply the deployment:
```bash
kubectl apply -f nginx-x86.yaml
```

### Example Deployment on Graviton Instance
Create a file named nginx-arm64.yaml with the following content:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: graviton-pod
spec:
  nodeSelector:
    kubernetes.io/arch: arm64
  containers:
    - name: nginx
      image: nginx
      ports:
        - containerPort: 80
```
Apply the deployment:
```bash
kubectl apply -f nginx-arm64.yaml
```
