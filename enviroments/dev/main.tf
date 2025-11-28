provider "aws" {
  region = var.region
}

# create a data source to get the Current AWS Account ID
data "aws_caller_identity" "current" {}

locals {
  # Define the tags to be used across all resources
  tags = {
    Product     = var.product_name
    Environment = var.environment
  }
}

module "vpc" {
  source           = "../../modules/vpc"
  subnets          = var.subnets
  public_subnet    = var.public_subnet
  vpc_name         = "${var.environment}-${var.company_name}-VPC"
  cidr_block       = var.cidr_block
  gw               = "${var.environment}-${var.company_name}-IGW"
  route_cidr_block = var.route_cidr_block
  route_table_name = "${var.environment}-${var.company_name}-PRIVATE-ROUTE-TABLE"
  tags             = local.tags
}

module "asg" {
  source        = "../../modules/asg"
  name          = "${var.environment}-${var.company_name}-ASG"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = var.security_group_ingress_rules
  egress_rules  = var.security_group_egress_rules
  cidr_blocks   = [var.cidr_block]
  tags          = local.tags
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "${var.environment}-${var.company_name}-EKS-CLUSTER"
  cluster_version    = var.cluster_version
  subnet_ids         = module.vpc.subnets_id
  cidr_block         = var.cidr_block
  addons             = var.addons
  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.asg.security_group_id]
  policy_arns        = var.iam_role_policy_arns
  spot               = var.use_spot_nodes
  desired_capacity   = var.desired_capacity
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  instance_types     = var.instance_types
  product_name       = var.product_name
  tags               = local.tags
}

module "ecr" {
  source               = "../../modules/ecr"
  repository_name      = var.repository_name
  image_tag_mutability = var.image_tag_mutability
  scan_on_push         = var.scan_on_push
  tags                 = local.tags
}

module "sqs" {
  count                      = var.sqs_queue_name != null ? 1 : 0
  source                     = "../../modules/sqs"
  queue_name                 = "${var.environment}-${var.company_name}-${var.sqs_queue_name}"
  create_dlq                 = var.sqs_create_dlq
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds
  tags                       = local.tags
}

module "s3" {
  count              = var.s3_bucket_name != null ? 1 : 0
  source             = "../../modules/s3"
  bucket_name        = lower("${var.environment}-${var.company_name}-${var.s3_bucket_name}-${data.aws_caller_identity.current.account_id}")
  enable_versioning  = var.s3_enable_versioning
  force_destroy      = var.s3_force_destroy
  enable_public_access_block = false  # Disabled due to SCP restrictions
  tags               = local.tags
}
