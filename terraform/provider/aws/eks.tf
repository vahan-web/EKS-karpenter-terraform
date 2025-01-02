module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.6"

  cluster_name                    = local.name
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_version                = "1.31"
  cluster_service_ipv4_cidr      = local.cluster_service_ipv4_cidr  

  # Authentication configuration directly in the main module
  authentication_mode = "API"
  
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    # Access for cluster admin role
    admin_role = {
      kubernetes_groups = ["system:masters"]
      principal_arn    = "arn:aws:iam::${local.aws_account}:role/devops"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    # Access for devops user
    devops_user = {
      kubernetes_groups = ["system:masters"]
      principal_arn    = "arn:aws:iam::${local.aws_account}:user/devops"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    # Access for root user
    root_user = {
      kubernetes_groups = ["system:masters"]
      principal_arn    = "arn:aws:iam::${local.aws_account}:user/root"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  # Encryption key
  create_kms_key = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }
  kms_key_deletion_window_in_days = 7
  enable_kms_key_rotation         = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type                              = "AL2_x86_64"
    instance_types                        = ["t3.micro", "m6a.large", "m6i.large", "m7i.large"]
    attach_cluster_primary_security_group = true
    vpc_security_group_ids                = []
  }

  cluster_enabled_log_types = local.workspace["cluster_enabled_log_types"]
  
  tags = local.tags
}

# AMD64 Node Group
module "eks_managed_node_group_amd64" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "20.31.6"

  name                              = "eks-mng-amd64"
  cluster_name                      = module.eks.cluster_name
  cluster_version                   = module.eks.cluster_version
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_service_ipv4_cidr        = local.cluster_service_ipv4_cidr

  vpc_security_group_ids = [
    module.eks.node_security_group_id
  ]
  
  subnet_ids = module.vpc.private_subnets

  min_size     = local.workspace["eks_node_min_size"]
  max_size     = local.workspace["eks_node_max_size"]
  desired_size = local.workspace["eks_node_desired_size"]

  instance_types = local.workspace["node_size"]
  capacity_type  = local.workspace["capacity_type"]

  labels = {
    Environment = local.workspace["environment"]
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 40
        volume_type          = "gp3"
        iops                 = 100
        throughput          = 150
        delete_on_termination = true
      }
    }
  }

  tags = merge(local.tags, { Separate = "eks-managed-node-group-amd64" })
}

# ARM64 Node Group
module "eks_managed_node_group_arm64" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "20.31.6"

  name                              = "eks-mng-arm64"
  cluster_name                      = module.eks.cluster_name
  cluster_version                   = module.eks.cluster_version
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_service_ipv4_cidr        = local.cluster_service_ipv4_cidr

  vpc_security_group_ids = [
    module.eks.node_security_group_id
  ]

  subnet_ids = module.vpc.private_subnets

  min_size     = local.workspace["eks_node_min_size"]
  max_size     = local.workspace["eks_node_max_size"]
  desired_size = local.workspace["eks_node_desired_size"]

  instance_types = ["m6g.large", "m6g.xlarge"]
  ami_type       = "AL2_ARM_64"
  capacity_type  = local.workspace["capacity_type"]

  labels = {
    Environment = local.workspace["environment"]
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 40
        volume_type          = "gp3"
        iops                 = 100
        throughput          = 150
        delete_on_termination = true
      }
    }
  }

  tags = merge(local.tags, { Separate = "eks-managed-node-group-arm64" })
}