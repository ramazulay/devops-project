variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "product_name" {
  description = "Product name"
  type        = string
  default     = "VICA"
}
variable "cidr_block" {
  description = "cidr block"
  type        = string
}
variable "dns_hostnames" {
  description = "A boolean flag to enable/disable DNS hostnames in the VPC"
  type        = bool
  default     = true
}
variable "subnets" {
  description = "Subnet name"
  type = list(object({
    name = string
    cidr = string
    azs  = string
  }))
}
variable "public_subnet" {
  description = "Subnet name"
  type = list(object({
    name = string
    cidr = string
    azs  = string
  }))
}
variable "gw" {
  description = "internet gateway"
  type        = string
}

variable "route_cidr_block" {
  description = "route cidr block"
  type        = string
}
variable "route_table_name" {
  type = string
}
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}