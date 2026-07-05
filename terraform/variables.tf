variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  default = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "AZ to use for both subnets"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "Name of an EXISTING AWS EC2 Key Pair (you create this in AWS Console first)"
  type        = string
}

variable "my_ip" {
  description = "Your home/office public IP in CIDR form, e.g. 103.21.45.10/32. Get it from https://checkip.amazonaws.com"
  type        = string
}
