# KEY PAIR
resource "aws_key_pair" "terramino" {
  key_name   = "terramino-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYC15qFZeCF6btb4VDD6Dio63uvo1LFuBYlKf+Zq15Z ken@RAD6657"
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name = "demo-terramino-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  public_subnets  = ["10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.4.0/24", "10.0.5.0/24"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  create_igw            = true
  enable_nat_gateway    = true
  single_nat_gateway    = true
  map_public_ip_on_launch = true

  tags = {
    Terraform   = "true"
    Environment = "demo"
  }
}

# SECURITY GROUPS
resource "aws_security_group" "demo_terramino_instance_ec2_sg_001" {
  name        = "demo_terramino_instance_ec2_sg_001"
  description = "Allow HTTP from VPC"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "terramino-ec2-sg"
  }
}

resource "aws_security_group_rule" "terramino_ec2_allow_http_from_vpc" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = [module.vpc.vpc_cidr_block]
  security_group_id        = aws_security_group.demo_terramino_instance_ec2_sg_001.id
}

resource "aws_security_group_rule" "terramino_ec2_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.demo_terramino_instance_ec2_sg_001.id
}

# ALB security group (public). Allow HTTP from internet.
resource "aws_security_group" "demo_terramino_alb_sg_003" {
  name        = "demo_terramino_alb_sg_003"
  description = "Allow HTTP from internet"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "terramino-alb-sg"
  }
}

resource "aws_security_group_rule" "terramino_alb_allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.demo_terramino_alb_sg_003.id
}

resource "aws_security_group_rule" "terramino_alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.demo_terramino_alb_sg_003.id
}

# EC2 
resource "aws_instance" "demo_terramino_ec2_001" {
  ami                         = "ami-0e86e20dae9224db8"   # Ubuntu 22.04 LTS (as you supplied)
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.demo_terramino_instance_ec2_sg_001.id]
  key_name                    = aws_key_pair.terramino.key_name
  user_data                   = file("${path.module}/user-data.sh")
  associate_public_ip_address = false

  tags = {
    Name = "demo-terramino-ec2"
  }
}

# LAUNCH CONFIGURATION (for ASG)
resource "aws_launch_configuration" "terramino" {
  name_prefix     = "terramino-lc-"
  image_id        = "ami-0e86e20dae9224db8"    # using the AMI you provided
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.terramino.key_name
  security_groups = [aws_security_group.demo_terramino_instance_ec2_sg_001.id]
  user_data       = file("${path.module}/user-data.sh")

  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }
}

# ALB
resource "aws_lb" "demo_terramino_alb" {
  name               = "learn-asg-terramino-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.demo_terramino_alb_sg_003.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "learn-asg-alb"
  }
}

resource "aws_lb_target_group" "demo_terramino_lb_tg" {
  name     = "learn-asg-terramino"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
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

# AUTOSCALING GROUP (private subnets)
resource "aws_autoscaling_group" "demo_terramino_asg_001" {
  name                 = "terramino"
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.terramino.name
  vpc_zone_identifier  = module.vpc.private_subnets
  health_check_type    = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "HashiCorp Learn ASG - Terramino"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Attach ASG to Target Group
resource "aws_autoscaling_attachment" "asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.demo_terramino_asg_001.name
  lb_target_group_arn    = aws_lb_target_group.demo_terramino_lb_tg.arn
}
