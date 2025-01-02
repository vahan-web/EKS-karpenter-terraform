module "vpc" {
  source                               = "terraform-aws-modules/vpc/aws"
  name                                 = local.name
  cidr                                 = local.workspace["cidr"]
  azs                                  = ["${local.region}a", "${local.region}b"]
  private_subnets                      = local.workspace["vpc_private_subnets"]
  public_subnets                       = local.workspace["vpc_public_subnets"]
  enable_nat_gateway                   = true
  enable_dns_hostnames                 = true
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }
}