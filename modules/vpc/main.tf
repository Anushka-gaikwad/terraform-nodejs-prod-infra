# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

# -----------------------------------------------------------------------------
# Public Subnets
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-public-${var.azs[count.index]}"
    Tier = "public"
  })
}

# -----------------------------------------------------------------------------
# Private Subnets (App Tier)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-private-${var.azs[count.index]}"
    Tier = "private"
  })
}

# -----------------------------------------------------------------------------
# Isolated Subnets (Database Tier)
# -----------------------------------------------------------------------------
resource "aws_subnet" "isolated" {
  count             = length(var.isolated_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.isolated_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-isolated-${var.azs[count.index]}"
    Tier = "isolated"
  })
}

# -----------------------------------------------------------------------------
# Elastic IPs for NAT Gateways
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-eip-${var.azs[count.index]}"
  })
}

# -----------------------------------------------------------------------------
# NAT Gateways (one per AZ)
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-${var.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables (one per AZ for HA NAT)
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-private-rt-${var.azs[count.index]}"
  })
}

resource "aws_route" "private_nat" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Isolated route table (no internet access)
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-isolated-rt"
  })
}

resource "aws_route_table_association" "isolated" {
  count          = length(var.isolated_subnet_cidrs)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}

# -----------------------------------------------------------------------------
# Network ACLs
# -----------------------------------------------------------------------------

# Public NACL
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Inbound: HTTP
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Inbound: HTTPS
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Inbound: Ephemeral ports (return traffic)
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: All traffic
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-public-nacl"
  })
}

# Private NACL
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Inbound: From VPC CIDR (ALB -> EC2, inter-service)
  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Inbound: Ephemeral ports (return traffic from internet via NAT)
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: All (NAT egress, VPC traffic)
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-private-nacl"
  })
}

# Isolated NACL (only private subnet traffic)
resource "aws_network_acl" "isolated" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.isolated[*].id

  # Inbound: From private subnets only
  dynamic "ingress" {
    for_each = var.private_subnet_cidrs
    content {
      rule_no    = 100 + ingress.key * 10
      protocol   = "-1"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0
      to_port    = 0
    }
  }

  # Outbound: To private subnets only
  dynamic "egress" {
    for_each = var.private_subnet_cidrs
    content {
      rule_no    = 100 + egress.key * 10
      protocol   = "-1"
      action     = "allow"
      cidr_block = egress.value
      from_port  = 0
      to_port    = 0
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-isolated-nacl"
  })
}

# -----------------------------------------------------------------------------
# VPC Flow Logs
# -----------------------------------------------------------------------------
resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = var.flow_log_group_arn
  iam_role_arn             = var.flow_log_role_arn
  max_aggregation_interval = 60

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-flow-log"
  })
}
