variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = list(map(string))
  default = [
    {
      "ap-southeast-1a" : "10.0.1.0/24",
      "ap-southeast-1b" : "10.0.2.0/24",
      "ap-southeast-1c" : "10.0.3.0/24"
    },
    {
      "ap-southeast-1a" : "10.0.11.0/24",
      "ap-southeast-1b" : "10.0.12.0/24",
      "ap-southeast-1c" : "10.0.13.0/24"
    }
  ]
}

variable "default_name" {
  description = "Default name for resources"
  type        = string
  default     = ""
}
