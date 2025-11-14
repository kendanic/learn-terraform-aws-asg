variable "vpc_id" {
    description = ""
    type = string
}
variable "public_subnets" { 
    description = ""
    type = list(string)
}
variable "private_subnets" { 
    description = ""
    type = list(string)
}
variable "key_name" {
    description = ""
    type = string
}
