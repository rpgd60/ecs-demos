resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

## Gateways 
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.name_prefix}"
  }
}

resource "aws_egress_only_internet_gateway" "egress_only_gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.name_prefix}"
  }
}

# Create var.az_count public subnets, each in a different AZ
resource "aws_subnet" "public" {
  count = var.az_count
  ## If VPC CIDR is /16  we use parameter 8 to obtain a /24
  cidr_block      = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 0 * var.az_count)
  ipv6_cidr_block = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index + 0 * var.az_count)

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.name_prefix}-public-${count.index}"
  }
}

# Create var.az_count frontend subnets, each in a different AZ
resource "aws_subnet" "private" {
  count           = var.az_count
  cidr_block      = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1 * var.az_count)
  ipv6_cidr_block = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index + 1 * var.az_count)

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.name_prefix}-private-${count.index}"
  }
}

# Create az.count database subnets 
resource "aws_subnet" "database" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2 * var.az_count)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.name_prefix}-database-${count.index}"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = element(aws_route_table.public.*.id, count.index)
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}
resource "aws_route_table_association" "database" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.database.*.id, count.index)
  route_table_id = element(aws_route_table.database.*.id, count.index)
}

# route table for the public subnets 
resource "aws_route_table" "public" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${local.name_prefix}-public-${count.index}"
  }
}

# route table for the private subnets - 
## For the time being we configure - egress routing for IPv6
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  ### Consider removing
  route {
    ipv6_cidr_block        = "::0/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.egress_only_gw.id
  }
  # route = [] ## Required to remove all routes

  tags = {
    Name = "${local.name_prefix}-private-${count.index}"
  }
}

## Route table for database subnets - only vpc routing
resource "aws_route_table" "database" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id
  route  = [] ## Required to remove all routes
  tags = {
    Name = "${local.name_prefix}-database-${count.index}"
  }
}

# resource "aws_security_group" "security_group" {
#   name   = "ecs-security-group"
#   vpc_id = aws_vpc.main.id

#   ingress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = -1
#     self        = "false"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "any"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name = "${local.name_prefix}-sg"
#   }
# }

## Security group for ALB
resource "aws_security_group" "lb_sg" {
  name   = "${local.name_prefix}-lb-sg"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.name_prefix}-lb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "http_v6" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https_v6" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

resource "aws_vpc_security_group_egress_rule" "egress_v6" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = -1
}

## Security group for EC2 instances where tasks are deployed

resource "aws_security_group" "ec2_sg" {
  name   = "${local.name_prefix}-ec2-sg"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.name_prefix}-ec2-sg"
  }
}


resource "aws_vpc_security_group_ingress_rule" "ec2_lb" {
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.lb_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "ecs_control" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0" # aws_vpc.main.cidr_block
  ip_protocol       = -1
}

resource "aws_vpc_security_group_egress_rule" "ec2_all_v6" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv6         = "::/0" # aws_vpc.main.ipv6_cidr_block
  ip_protocol       = -1
}

## Security group for ECS Service
## For the time being allow all ingress and egress
resource "aws_security_group" "ecs_sg" {
  name   = "${local.name_prefix}-ecs-sg"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.name_prefix}-ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs" {
  security_group_id = aws_security_group.ecs_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

resource "aws_vpc_security_group_ingress_rule" "ecs_v6" {
  security_group_id = aws_security_group.ecs_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = -1
}
resource "aws_vpc_security_group_egress_rule" "ecs" {
  security_group_id = aws_security_group.ecs_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

resource "aws_vpc_security_group_egress_rule" "ecs_v6" {
  security_group_id = aws_security_group.ecs_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = -1
}

## ================================= Security Group for VPC Endpoints

# Newer version with independent resources for each rule
resource "aws_security_group" "vpce_sg" {
  name   = "${local.name_prefix}-vpce1"
  vpc_id = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${local.name_prefix}-vpce"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_https" {
  security_group_id = aws_security_group.vpce_sg.id
  ip_protocol       = "tcp"
  from_port         = "443"
  to_port           = "443"
  cidr_ipv4         = aws_vpc.main.cidr_block
  description       = "HTTPS Inbound from VPC"
  tags = {
    Name = "HTTPS inbound from VPC instances"
  }
}
