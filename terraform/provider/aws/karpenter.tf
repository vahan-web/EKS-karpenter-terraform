resource "aws_iam_role" "karpenter_role" {
  name = "KarpenterNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "karpenter_policy" {
  name        = "KarpenterControllerPolicy"
  description = "Policy for Karpenter controller"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeImages",
          "ec2:TerminateInstances",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstanceTypeOfferings",
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:TagInstanceProfile",
          "pricing:GetProducts",
          "iam:AddRoleToInstanceProfile"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "iam:PassRole"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "eks:DescribeCluster"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ssm:GetParameter"
        ],
        "Resource": "arn:aws:ssm:*:*:parameter/aws/service/eks/optimized-ami/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_attach_policy" {
  role       = aws_iam_role.karpenter_role.name
  policy_arn = aws_iam_policy.karpenter_policy.arn
}

resource "aws_iam_instance_profile" "karpenter_instance_profile" {
  name = "KarpenterInstanceProfile"
  role = aws_iam_role.karpenter_role.name
}

resource "aws_iam_role_policy_attachment" "karpenter_attach_policy_for_amd64" {
  role       = module.eks_managed_node_group_amd64.iam_role_name
  policy_arn = aws_iam_policy.karpenter_policy.arn
}

resource "aws_iam_role_policy_attachment" "karpenter_attach_policy_for_arm64" {
  role       = module.eks_managed_node_group_arm64.iam_role_name
  policy_arn = aws_iam_policy.karpenter_policy.arn
}

resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter/karpenter"
  chart      = ""
  version    = "0.36.0"
  namespace  = kubernetes_namespace.karpenter.metadata[0].name

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter_instance_profile.arn
  }

  depends_on = [kubernetes_namespace.karpenter]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
      annotations:
        kubernetes.io/description: "General purpose EC2NodeClass for running Amazon Linux 2 nodes"
    spec:
      amiFamily: AL2 # Amazon Linux 2
      role: "KarpenterNodeRole"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "dev-eks-us-east-1"
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "dev-eks-us-east-1"
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool_arm64" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: arm64
      annotations:
        kubernetes.io/description: "NodePool for arm64 workloads"
    spec:
      template:
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["arm64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "a"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["2"]
          nodeClassRef:
            apiVersion: karpenter.k8s.aws/v1beta1
            kind: EC2NodeClass
            name: default
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

resource "kubectl_manifest" "karpenter_node_pool_amd64" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: amd64
      annotations:
        kubernetes.io/description: "NodePool for amd64 workloads"
    spec:
      template:
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m", "r"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["2"]
          nodeClassRef:
            apiVersion: karpenter.k8s.aws/v1beta1
            kind: EC2NodeClass
            name: default
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}
