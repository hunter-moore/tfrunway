# Create VPC
#
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = "${var.environment}"
  }
}


# Create Internet Gateway
#
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.environment}-igw"
    Environment = "${var.environment}"
  }
}


# Create NAT Elastic IP
#
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
  count      = var.private_subnets_count
}


# Create Public Subnets
#
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = var.public_subnets_count
  cidr_block              = "${cidrsubnet(var.vpc_cidr, 8, count.index)}"
  availability_zone       = element(data.aws_availability_zones.azs.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-${element(data.aws_availability_zones.azs.names, count.index)}-public-subnet"
    Environment = "${var.environment}"
  }
}


# Create Private Subnets
#
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = var.private_subnets_count
  cidr_block              = "${cidrsubnet(var.vpc_cidr, 8, count.index+10)}"
  availability_zone       = element(data.aws_availability_zones.azs.names, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.environment}-${element(data.aws_availability_zones.azs.names, count.index)}-private-subnet"
    Environment = "${var.environment}"
  }
}


# Create Routing Tables
#
resource "aws_route_table" "private" {
  count  = var.private_subnets_count
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.environment}-private-route-table[count.index]"
    Environment = "${var.environment}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = "${var.environment}"
  }
}


# Create Public Route to IG
#
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}


# Rout to Private nat gw
#
resource "aws_route" "private_nat_gateway" {
  count                  = var.private_subnets_count
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat.*.id, count.index)
  timeouts {
    create = "5m"
  }
}

# Associate public Routing Tables
#
resource "aws_route_table_association" "public" {
  count          = var.public_subnets_count
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}


# Associate Private route table
#
resource "aws_route_table_association" "private" {
  count          = var.private_subnets_count
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}


# Create Nat Gateway
#
resource "aws_nat_gateway" "nat" {
  count         = var.public_subnets_count
  allocation_id = element(aws_eip.nat_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)
  depends_on    = [aws_internet_gateway.ig]
  tags = {
    Name        = "nat"
    Environment = "${var.environment}"
  }
}

# Create Default Security Groups
#
resource "aws_security_group" "default" {
  name        = "${var.environment}-default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_vpc.vpc]
  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }
  tags = {
    Environment = "${var.environment}"
  }
}

# Grab newest AWS ami
#
data "aws_ami" "default_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2*"]
  }
  owners = ["137112412989"]
}
