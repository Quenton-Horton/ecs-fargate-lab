variable "project" {
  type    = string
  default = "ecs-fargate-lab"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "container_image" {
  type    = string
  default = "nginxdemos/hello:plain-text"
}

variable "container_port" {
  type    = number
  default = 80
}
