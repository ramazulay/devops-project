variable "cluster_name" {
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
variable "product_name" {
  type = string
}
variable "subnet_ids" {
  description = "List of subnet IDs to create mount targets"
  type        = list(string)
}
variable "cidr_block" {
  description = "cidr block"
  type        = string
}
variable "vpc_id" {
  type = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the mount targets"
  type        = list(string)
}

variable "policy_arns" {
  description = "List of ARNs of the policies to attach to the IAM role"
  type        = map(list(string))
  default     = {}
}

# variable "iam_role_arn" {
#   description = "value of the IAM role ARN"
#   type        = string
# }
# variable "iam_role_name" {
#   description = "value of the IAM role name"
#   type        = string
# }

# variable "iam_role_id" {
#   description = "value of the IAM role ID"
#   type        = string
# }

variable "spot" {
  description = "Use spot instances for the node group"
  type        = bool
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
variable "instance_types" {
  type = list(string)
}

variable "tags" {
  description = "Tags to assign to the resources"
  type        = map(string)
  default     = {}
}