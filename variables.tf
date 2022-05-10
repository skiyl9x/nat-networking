variable "namespace" {
  type = string
}

variable "pub_ingress_ports" {
  description = "allowed ingress ports from world"
  type        = list(any)
}

variable "private_ingress_ports" {
  description = "allowed ingress ports from local"
  type        = list(any)
}

variable "pub_instance_id" {
  type = string
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = []
}
