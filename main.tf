# key-pem
resource "aws_key_pair" "terramino" {
  key_name   = "terramino-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYC15qFZeCF6btb4VDD6Dio63uvo1LFuBYlKf+Zq15Z ken@RAD6657"
}

# vpc
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "demo-terramino-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  public_subnets  = ["10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.4.0/24", "10.0.5.0/24"]

  enable_nat_gateway    = true
  single_nat_gateway    = true
  create_igw            = true
  map_public_ip_on_launch = true

  enable_dns_support   = true
  enable_dns_hostnames = true
}


# sg
resource "aws_security_group" "demo_terramino_instance_ec2_sg_001" {
  name        = "demo_terramino_instance_ec2_sg_001"
  description = "Allow HTTP only inside VPC"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "ec2_allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = aws_security_group.demo_terramino_instance_ec2_sg_001.id
}

resource "aws_security_group_rule" "ec2_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.demo_terramino_instance_ec2_sg_001.id
}

# ALB sg
resource "aws_security_group" "demo_terramino_alb_sg_003" {
  name        = "demo_terramino_alb_sg_003"
  description = "Allow HTTP from internet"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "alb_allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.demo_terramino_alb_sg_003.id
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.demo_terramino_alb_sg_003.id
}

# ec2-private
# resource "aws_instance" "demo_terramino_ec2_001" {
#   ami                         = "ami-0ecb62995f68bb549"
#   instance_type               = "t2.micro"
#   subnet_id                   = module.vpc.private_subnets[0]
#   vpc_security_group_ids      = [aws_security_group.demo_terramino_instance_ec2_sg_001.id]
#   key_name                    = aws_key_pair.terramino.key_name
#   associate_public_ip_address = false
#   user_data                   = file("${path.module}/user-data.sh")

#   tags = {
#     Name = "demo-terramino-ec2"
#   }
# }

# asg lunch-conf
resource "aws_launch_template" "terramino" {
  name_prefix   = "terramino-lt-"

  image_id      = "ami-0ecb62995f68bb549"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.terramino.key_name

  user_data = filebase64("${path.module}/user-data.sh")

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [
      aws_security_group.demo_terramino_instance_ec2_sg_001.id
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}



# alb
resource "aws_lb" "demo_terramino_alb" {
  name               = "learn-asg-terramino-lb"
  load_balancer_type = "application"
  internal           = false
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.demo_terramino_alb_sg_003.id]
}

resource "aws_lb_target_group" "demo_terramino_lb_tg" {
  name     = "learn-asg-terramino"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "demo_terramino" {
  load_balancer_arn = aws_lb.demo_terramino_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_terramino_lb_tg.arn
  }
}

# ASG
resource "aws_autoscaling_group" "demo_terramino_asg_001" {
  name                 = "terramino"
  min_size             = 1
  max_size             = 2
  desired_capacity     = 1

  vpc_zone_identifier  = module.vpc.private_subnets

  launch_template {
    id      = aws_launch_template.terramino.id
    version = "$Latest"
  }

  health_check_type = "EC2"

  tag {
    key                 = "Name"
    value               = "Terramino"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.demo_terramino_asg_001.id
  lb_target_group_arn    = aws_lb_target_group.demo_terramino_lb_tg.arn
}
