provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      hashicorp-learn = "aws-asg"
    }
  }
}
