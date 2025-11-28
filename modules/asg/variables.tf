variable "name" {
  description = "Name of the security group"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID to associate the security group with"
  type        = string
}

variable "tags" {
  description = "Tags to assign to the security group"
  type        = map(string)
  default     = {}
}

variable "ingress_rules" {
  description = "List of ingress rules to attach to the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
  }))
  default = []
}

variable "egress_rules" {
  description = "List of egress rules to attach to the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
  }))
  default = []
}

variable "cidr_blocks" {
  description = "List of CIDR blocks to allow traffic from"
  type        = list(string)
  default     = []
}