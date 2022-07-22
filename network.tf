terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.48.0"
    }
  }
  backend "http" {}
}

provider "aws" {
  ignore_tags {
    key_prefixes = ["kubernetes.io/"]
  }
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_availability_zone" "available" {
  for_each = toset(data.aws_availability_zones.available.names)
  name     = each.key
}

resource "aws_vpc" "example-vpc" {
  cidr_block           = var.vpc-cidr-block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    local.common_tags,
    {
      Name = "Example Systems Internal"
    }
  )
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.example-vpc.id
  tags = merge(
    local.common_tags,
    {
      Name = "Example IGW"
    }
  )
}

resource "aws_subnet" "public" {
  for_each = toset(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.example-vpc.id
  availability_zone       = each.key
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(
    aws_vpc.example-vpc.cidr_block,
    8,
    local.az_number[data.aws_availability_zone.available[each.key].name_suffix]
  )
  tags = merge(
    local.common_tags,
    {
      Name = format("example-public-sub-%s", data.aws_availability_zone.available[each.key].name)
    }
  )
}

resource "aws_subnet" "private" {
  for_each = toset(data.aws_availability_zones.available.names)

  vpc_id            = aws_vpc.example-vpc.id
  availability_zone = each.key
  cidr_block = cidrsubnet(
    aws_vpc.example-vpc.cidr_block,
    8,
    local.az_number[data.aws_availability_zone.available[each.key].name_suffix] + length(data.aws_availability_zones.available.names)
  )
  tags = merge(
    local.common_tags,
    {
      Name = format("example-private-sub-%s", data.aws_availability_zone.available[each.key].name)
    }
  )
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.example-vpc.id
  tags = merge(
    local.common_tags,
    {
      Name = "example-public-rt"
    }
  )
}

resource "aws_route" "igw" {
  route_table_id         = aws_route_table.public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  depends_on             = [aws_route_table.public-rt]
}

resource "aws_route_table_association" "public-rt-ass" {
  for_each = toset(data.aws_availability_zones.available.names)

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_security_group" "from-example" {
  name        = "from-exampleSystems"
  description = "Allow All from ExampleSystems"
  vpc_id      = aws_vpc.example-vpc.id

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["1.1.1.1/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    local.common_tags,
    {
      Name = "from-exampleSystems"
    }
  )
}

resource "aws_security_group" "web" {
  name        = "web_access"
  description = "WEB access"
  vpc_id      = aws_vpc.example-vpc.id

  ingress {
    description = "http"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "https"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    local.common_tags,
    {
      Name = "web_access"
    }
  )
}


output "vpc_id" {
  value = aws_vpc.example-vpc.id
}

output "public_networks" {
  value = aws_subnet.public
}

output "private_networks" {
  value = aws_subnet.private
}

output "sg-from-example" {
  value = aws_security_group.from-example
}

output "sg-web" {
  value = aws_security_group.web
}
