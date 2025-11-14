variable "aws_region" {
  description = "AWS region where all resources should be created."
  type        = string
}
# variable "vpc_id" {
#   description = "The ID of the VPC where resources (EC2, ALB, ASG) should be created."
#   type        = string
# }

# variable "public_subnets" {
#   description = "List of public subnet IDs used for the Application Load Balancer (ALB)."
#   type        = list(string)
# }

# variable "private_subnets" {
#   description = "List of private subnet IDs used for EC2 instances and AutoScaling Group."
#   type        = list(string)
# }

variable "key_name" {
  description = "The EC2 Key Pair name used to access EC2 instances (only needed if SSH access is required)."
  type        = string
}
