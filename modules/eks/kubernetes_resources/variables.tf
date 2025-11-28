variable "eks_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "eks_endpoint" {
  description = "Endpoint of the EKS cluster"
  type        = string
}

variable "eks_ca_certificate" {
  description = "Base64 encoded CA certificate of the EKS cluster"
  type        = string
}