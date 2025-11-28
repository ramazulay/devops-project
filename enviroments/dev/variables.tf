variable "bucket_name" {
  type    = string
  default = "vica-tf-backend"
}
variable "region" {
  type = string
}
variable "cidr_block" {
  type = string
}
variable "environment" {
  type = string
}
variable "company_name" {
  type = string
}
variable "product_name" {
  type = string
}
variable "azs" {
  type = list(string)
}
variable "subnets" {
  type = list(object({
    name = string
    cidr = string
    azs  = string
  }))
}
variable "public_subnet" {
  type = list(object({
    name = string
    cidr = string
    azs  = string
  }))
}
variable "route_cidr_block" {
  type = string
}
variable "cluster_version" {
  type = string
}
variable "addons" {
  type = list(object({
    name    = string
    version = string
    attach  = bool
  }))
}
variable "desired_capacity" {
  type = string
}
variable "min_capacity" {
  type = string
}
variable "max_capacity" {
  type = string
}
variable "use_spot_nodes" {
  description = "Use spot instances for EKS nodes"
  type        = bool
}

variable "instance_types" {
  type = list(string)
}
variable "repository_name" {
  type = string
}

variable "access_point_path" {
  description = "The path in the EFS file system to expose as the root directory to NFS clients"
  type        = string
  default     = "/"
}
variable "image_tag_mutability" {
  type = string
}
variable "scan_on_push" {
  type = bool
}
variable "security_group_ingress_rules" {
  description = "List of ingress rules to attach to the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
  }))
  default = [
    {
      description = "Allow SSH traffic"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
    },
    {
      description = "Allow HTTP traffic"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
    },
    {
      description = "Allow HTTPS traffic"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
    },
    {
      description = "Allow MySQL traffic"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
    },
    {
      description = "Allow NFS traffic"
      from_port   = 2049
      to_port     = 2049
      protocol    = "tcp"
    }
  ]
}

variable "security_group_egress_rules" {
  description = "List of egress rules to attach to the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
  }))
  default = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1" # All traffic
    }
  ]
}

# variable "iam_role_assume_role_policy_principal_services" {
#   description = "The principal to assume the role"
#   type        = list(string)
#   default     = ["eks.amazonaws.com", "ec2.amazonaws.com", "ecr.amazonaws.com"]
# }

variable "iam_role_policy_arns" {
  description = "List of ARNs of the policies to attach to the IAM role"
  type        = map(list(string))
  default = {
    eks_cluster = [
      "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
      "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    ],
    eks_node_group = [
      "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
      "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
      "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
      "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
      "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
    ]
  }
}

# SQS Variables
variable "sqs_queue_name" {
  description = "The name of the SQS queue"
  type        = string
  default     = null
}

variable "sqs_create_dlq" {
  description = "Whether to create a Dead Letter Queue for SQS"
  type        = bool
  default     = false
}

variable "sqs_visibility_timeout_seconds" {
  description = "The visibility timeout for the SQS queue"
  type        = number
  default     = 30
}

variable "sqs_message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message"
  type        = number
  default     = 345600
}

# S3 Variables
variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = null
}

variable "s3_enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "s3_force_destroy" {
  description = "A boolean that indicates all objects should be deleted from the bucket"
  type        = bool
  default     = false
}

