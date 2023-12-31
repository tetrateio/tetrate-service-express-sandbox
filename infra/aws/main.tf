provider "aws" {
  region = var.region

  # Re-enable this once https://github.com/hashicorp/terraform-provider-aws/issues/19583
  # is fixed. Until then, the workaround is to manually merge
  # the tags in every resource.
  # default_tags {
  #   tags = local.default_tags
  # }
}

resource "random_string" "random_id" {
  length  = 4
  special = false
  lower   = true
  upper   = false
  numeric = false
}

module "aws_base" {
  source      = "../../modules/aws/base"
  name_prefix = "${var.name_prefix}-${var.cluster_id}-${random_string.random_id.result}"
  cidr        = cidrsubnet(var.cidr, 4, 4 + tonumber(var.cluster_id))
  tags        = local.default_tags
  output_path = var.output_path
}

module "aws_jumpbox" {
  source                      = "../../modules/aws/jumpbox"
  name_prefix                 = "${var.name_prefix}-${var.cluster_id}-${random_string.random_id.result}"
  region                      = var.region
  vpc_id                      = module.aws_base.vpc_id
  vpc_subnet                  = module.aws_base.vpc_subnets[0]
  cidr                        = module.aws_base.cidr
  tetrate_version             = local.tetrate.version
  jumpbox_username            = var.jumpbox_username
  tetrate_image_sync_username = local.tetrate.image_sync_username
  tetrate_image_sync_apikey   = local.tetrate.image_sync_apikey
  registry                    = module.aws_base.registry
  registry_name               = module.aws_base.registry_name
  tags                        = local.default_tags
  output_path                 = var.output_path
}

module "aws_k8s" {
  source               = "../../modules/aws/k8s"
  k8s_version          = var.k8s_version
  region               = var.region
  vpc_id               = module.aws_base.vpc_id
  vpc_subnets          = module.aws_base.vpc_subnets
  name_prefix          = "${var.name_prefix}-${var.cluster_id}-${random_string.random_id.result}"
  cluster_name         = coalesce(var.cluster_name, "eks-${var.region}-${var.name_prefix}")
  jumpbox_iam_role_arn = module.aws_jumpbox.jumpbox_iam_role_arn
  output_path          = var.output_path
  tags                 = local.default_tags
}