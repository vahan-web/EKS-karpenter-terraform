locals {
  aws_account                          = "ACCOUNT_ID"
  name                                 = "${local.workspace["environment"]}-eks-${local.region}"
  region                               = "us-east-1"
  tags = {
    Environment  = local.workspace["environment"]
    Provisioner  = "terraform"
  }
}
locals {
  env = {
    default = {}
    dev = {
      environment                          = "dev"
      cidr                                 = "10.0.0.0/16"
      vpc_public_subnets                   = ["10.0.10.0/24", "10.0.11.0/24"]
      vpc_private_subnets                  = ["10.0.1.0/24", "10.0.2.0/24"]
      cluster_service_ipv4_cidr            = "172.20.0.0/16"
      vpc_single_nat_gateway               = true
      vpc_dhcp_options_domain_name_servers = "10.0.0.3"
      single_nat_gateway                   = true
      eks_node_min_size                    = 1
      eks_node_max_size                    = 8
      eks_node_desired_size                = 4
      capacity_type                        = "SPOT"
      performance_insights_enabled         = true
      cluster_enabled_log_types            = []
      refresh_token_validity               = 30
      create_waf                           = true
      node_size                            = ["t3.large"]
      string_schemas = [
        {
          attribute_data_type      = "String"
          developer_only_attribute = false
          mutable                  = true
          name                     = "email"
          required                 = false

          string_attribute_constraints = {
            min_length = 0
            max_length = 256
          }
        },
        {
          attribute_data_type      = "String"
          developer_only_attribute = false
          mutable                  = true
          name                     = "email"
          required                 = true

          string_attribute_constraints = {
            min_length = 0
            max_length = 256
          }
        }
      ]
        }
      }
  environment_vars = contains(keys(local.env), terraform.workspace) ? terraform.workspace : "default"
  workspace        = merge(local.env["default"], local.env[local.environment_vars])
}

