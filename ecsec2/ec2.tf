resource "aws_launch_template" "ecs" {
  name_prefix   = local.name_prefix
  image_id      = data.aws_ami.amazon_linux_2023_ecs.id
  instance_type = var.instance_type

  # key_name               = "ec2ecsglog"
  # vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_ec2.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp2"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}"
    }
  }
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    ipv6_address_count          = 1
    security_groups             = [aws_security_group.ec2_sg.id]
  }
  user_data = base64encode(local.user_data_rendered)
}

resource "aws_iam_instance_profile" "ecs_ec2" {
  name = "EcsEc2"
  # role = local.ecs_task_execution_role
  role = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_autoscaling_group" "ecs_asg" {
  vpc_zone_identifier = aws_subnet.private.*.id
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
  health_check_type = "EC2"
}

//Alb
resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public.*.id
  ip_address_type    = "dualstack"

  tags = {
    Name = "ecs-alb"
  }
}

resource "aws_lb_listener" "ecs_alb_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

resource "aws_lb_target_group" "ecs_tg" {
  name     = "ecs-target-group"
  port     = 80
  protocol = "HTTP"
  ## Docs on why "ip" type: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/load-balancer-types.html#alb-considerations
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  # health_check {
  #   path = "/"
  # }
}



