variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scan on push"
  type        = bool
  default     = true
}

variable "prevent_destroy" {
  description = "Prevent the ECR repository from being accidentally destroyed"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to assign to the ECR repository"
  type        = map(string)
  default     = {}
}
