variable "vpc-cidr-block" {
  type        = string
  description = "(required) CIDR Block for VPC"
  default     = "172.16.0.0/16"
}

locals {
  az_number = {
    a = 1
    b = 2
    c = 3
    d = 4
    e = 5
    f = 6
  }

  common_tags = {
    Project = "Example"
  }
}
