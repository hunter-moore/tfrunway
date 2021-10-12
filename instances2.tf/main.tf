# Create random suffix
resource "random_id" "random_id_suffix" {
  byte_length = 2
}

# Create IMG-MGR s3 Bucket
#
resource "aws_s3_bucket" "img-mgr-tf-bucket" {
  bucket = var.bucket_name
  acl    = "private"

  tags = {
    Name        = "${var.environment}-tf-bucket"
    Environment = "${var.environment}"
  }
}

# Create templates via template_file
#
data "template_file" "user_data_template" {
  template = file("${path.module}/scripts/userdata.tftpl")
  vars = {
    bucketpath = aws_s3_bucket.img-mgr-tf-bucket.id
  }
}

data "template_file" "s3_bucket_template" {
  template = file("${path.module}/scripts/s3AccessPolicy.tftpl")
  vars = {
    bucketpath = aws_s3_bucket.img-mgr-tf-bucket.id
  }
}


# Create necessary Roles for IMG-MGR and attach
#
resource "aws_iam_role" "img-mgr-tf-role" {
  name               = "img-mgr-tf-role-${random_id.random_id_suffix.hex}"
  assume_role_policy = file("${path.module}/scripts/ec2assumerole.json")
}

resource "aws_iam_policy" "s3AccessPolicy" {
  name        = "s3AccessPolicy-${random_id.random_id_suffix.hex}"
  description = "s3 policy"
  policy      = data.template_file.s3_bucket_template.rendered
}

resource "aws_iam_policy_attachment" "policy-attach" {
  name       = "img-mgr-policy-attachment-${random_id.random_id_suffix.hex}"
  roles      = ["${aws_iam_role.img-mgr-tf-role.name}"]
  policy_arn = aws_iam_policy.s3AccessPolicy.arn
}

resource "aws_iam_instance_profile" "img-mgr-profile" {
  name = "img-mgr-profile-${random_id.random_id_suffix.hex}"
  role = aws_iam_role.img-mgr-tf-role.name
}


# Create Security Groups
#
resource "aws_security_group" "lb_sg" {
  name        = "${var.environment}-lb_sg"
  description = "IMG_MGR ALB SG"
  vpc_id      = data.terraform_remote_state.remote_vars.outputs.vpc_id
  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = "true"
  }
  tags = {
    Environment = "${var.environment}"
    Name        = "${var.environment}-lb_sg"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.environment}-ec2_sg"
  description = "ec2 sg"
  vpc_id      = data.terraform_remote_state.remote_vars.outputs.vpc_id
  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = "true"
  }
  tags = {
    Environment = "${var.environment}"
    Name        = "${var.environment}-lb_sg"
  }
}


# Create launch_template
#
resource "aws_launch_template" "ImgMgrLT2" {
  name                                 = "IMG_MGR2"
  image_id                             = data.terraform_remote_state.remote_vars.outputs.default_ami
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t2.micro"
  key_name                             = "my-key"
  iam_instance_profile {
    name = aws_iam_instance_profile.img-mgr-profile.id
  }
  monitoring {
    enabled = true
  }
  vpc_security_group_ids = [aws_security_group.ec2_sg.id, data.terraform_remote_state.remote_vars.outputs.security_groups_ids[0]]
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "IMG Mgr Instance"
    }
  }
  user_data = base64encode(data.template_file.user_data_template.rendered)
}


# Create ASG
#
resource "aws_autoscaling_group" "img_mgr_asg" {
  vpc_zone_identifier = [data.terraform_remote_state.remote_vars.outputs.private_subnets_id[0][0], data.terraform_remote_state.remote_vars.outputs.private_subnets_id[0][1]]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 2

  launch_template {
    id      = aws_launch_template.ImgMgrLT2.id
    version = "$Latest"
  }
}


# Create ALB, listener, and TG
#
resource "aws_lb" "ImgMgrALB2" {
  name               = "img-mgr-alb2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [data.terraform_remote_state.remote_vars.outputs.public_subnets_id[0][0], data.terraform_remote_state.remote_vars.outputs.public_subnets_id[0][1]]

  tags = {
    Environment = "deb"
    Name        = "IMG MGR ALB2"
  }
}

resource "aws_lb_listener" "img-mgr-listener" {
  load_balancer_arn = aws_lb.ImgMgrALB2.arn
  port              = 80
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.img_mgr_tg2.arn
  }
}

resource "aws_lb_target_group" "img_mgr_tg2" {
  name     = "img-mgr-tg2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.remote_vars.outputs.vpc_id
}

resource "aws_autoscaling_attachment" "img_mgr_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.img_mgr_asg.id
  alb_target_group_arn   = aws_lb_target_group.img_mgr_tg2.id
}

# Create Scaling Policy for LB
#
resource "aws_autoscaling_policy" "img_mgr_high_policy" {
  name                   = "img_mgr_high_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.img_mgr_asg.name
}

resource "aws_autoscaling_policy" "img_mgr_low_policy" {
  name                   = "img_mgr_low_policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.img_mgr_asg.name
}

# Create CW alarms
#
resource "aws_cloudwatch_metric_alarm" "img_mgr_high_cw" {
  alarm_name          = "img_mgr_high_cw"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cw_high

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.img_mgr_asg.name
  }

  alarm_description = "High CPU ALARM"
  alarm_actions     = [aws_autoscaling_policy.img_mgr_high_policy.arn]
}

resource "aws_cloudwatch_metric_alarm" "img_mgr_low_cw" {
  alarm_name          = "img_mgr_low_cw"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cw_low

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.img_mgr_asg.name
  }

  alarm_description = "This metric monitors ec2 ASG low cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.img_mgr_low_policy.arn]
}

# Create Cloudfront
#
resource "random_string" "origin_token" {
  length  = 30
  special = false
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_lb.ImgMgrALB2.dns_name
    origin_id   = "alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2", "TLSv1.1"]
    }
    custom_header {
      name  = "X-Origin-Token"
      value = random_string.origin_token.result
    }
  }
  enabled = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb"
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Create Bastion for access
#
resource "aws_instance" "bastion" {
  ami           = data.terraform_remote_state.remote_vars.outputs.default_ami
  instance_type = "t2.micro"
  key_name      = "my-key"
  subnet_id     = data.terraform_remote_state.remote_vars.outputs.public_subnets_id[0][0]
  tags = {
    Name        = "Bastion-${var.environment}"
    Environment = "${var.environment}"
  }
}
