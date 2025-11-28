resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.dns_hostnames
  tags = merge(
    var.tags,
    {
      Name = var.vpc_name
    }
  )
}

resource "aws_subnet" "subnets" {
  for_each          = { for subnet in var.subnets : subnet.name => subnet }
  vpc_id            = aws_vpc.vpc.id
  availability_zone = each.value.azs
  cidr_block        = each.value.cidr
  tags = merge(
    var.tags,
    {
      Name = each.value.name
    }
  )

  depends_on = [aws_vpc.vpc]
}

resource "aws_subnet" "public_subnet" {
  for_each                = { for subnet in var.public_subnet : subnet.name => subnet }
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true
  availability_zone       = each.value.azs

  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}-PUBLIC"
    }
  )

  depends_on = [aws_vpc.vpc]
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.tags,
    {
      Name = var.gw
    }
  )

  depends_on = [aws_vpc.vpc]
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = merge(
    var.tags,
    {
      Name = "${var.product_name}-EIP"
    }
  )

  depends_on = [aws_vpc.vpc]
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public_subnet[keys(aws_subnet.public_subnet)[0]].id
  allocation_id = aws_eip.nat_eip.id
  tags = merge(
    var.tags,
    {
      Name = "NAT-Gateway"
    }
  )

  depends_on = [aws_vpc.vpc, aws_eip.nat_eip, aws_subnet.public_subnet]
}

resource "aws_route_table" "private_route" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = var.route_cidr_block
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(
    var.tags,
    {
      Name = var.route_table_name
    }
  )

  depends_on = [aws_vpc.vpc]

  lifecycle {
    ignore_changes = [
      route
    ]
  }
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = var.route_cidr_block
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(
    var.tags,
    {
      Name = "PUBLIC-ROUTE"
    }
  )

  depends_on = [aws_vpc.vpc]
}

resource "aws_route_table_association" "private_association" {
  for_each       = aws_subnet.subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route.id
  depends_on     = [aws_vpc.vpc, aws_subnet.subnets]
}

resource "aws_route_table_association" "public_association" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route.id
  depends_on     = [aws_vpc.vpc, aws_subnet.public_subnet]
}
