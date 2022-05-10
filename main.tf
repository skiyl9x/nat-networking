#############################################################
# VPC
#############################################################

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "nat-vpc"
  }
}

#############################################################
# Public subnet
#############################################################

resource "aws_subnet" "subnet_pb" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = "eu-west-1a"

  tags = {
    Name = "nat-subnet-public-${count.index}"
  }
}

#############################################################
# Private subnet
#############################################################

resource "aws_subnet" "subnet_pv" {
  count = length(var.private_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = "eu-west-1a"

  tags = {
    Name = "nat-subnet-private-${count.index}"
  }
}

#############################################################
# Internet Gateway
#############################################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "internet-gateway"
  }
}

#############################################################
# Public route table
#############################################################

resource "aws_route_table" "rt_pb" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "route-table-public"
  }
}

resource "aws_route_table_association" "rt_pb_assoc" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.subnet_pb[*].id, count.index)
  route_table_id = aws_route_table.rt_pb.id
}

resource "aws_route" "route_internet" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.rt_pb.id
  gateway_id             = aws_internet_gateway.igw.id
}

#############################################################
# Private route table
#############################################################

resource "aws_route_table" "rt_pv" {
  count = length(var.private_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "route-table-private-${count.index}"
  }
}

resource "aws_route_table_association" "rt_pv_assoc" {
  count = length(var.private_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.subnet_pv[*].id, count.index)
  route_table_id = element(aws_route_table.rt_pv[*].id, count.index)
}

resource "aws_route" "route_to_nat" {
  count = length(var.private_subnets) > 0 ? length(var.public_subnets) : 0

  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = element(aws_route_table.rt_pv[*].id, count.index)
  network_interface_id   = element(aws_network_interface.nic_pb[*].id, count.index)
}

#############################################################
# Public network interface
#############################################################

resource "aws_network_interface" "nic_pb" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id         = element(aws_subnet.subnet_pb[*].id, count.index)
  source_dest_check = false
  security_groups   = [aws_security_group.public.id]
  description       = "network-interface-${count.index} for nat-instance-0"

  tags = {
    Name = "eni-public-${count.index}"
  }
}

#############################################################
# Public network interface attachment
#############################################################

resource "aws_network_interface_attachment" "nic_pb_attach" {
  count = length(var.public_subnets) - 1 > 0 ? length(var.public_subnets) - 1 : 0

  instance_id          = var.pub_instance_id
  network_interface_id = element(aws_network_interface.nic_pb[*].id, count.index + 1)
  device_index         = count.index + 1
}

#############################################################
# Private network interface
#############################################################

# resource "aws_network_interface" "nic_pv" {
#   count = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

#   subnet_id       = element(aws_subnet.subnet_pv[*].id, count.index)
#   security_groups = [aws_security_group.private.id]
#   description     = "network_interface[0] for serv.priv[${count.index}]"


#   tags = {
#     Name = "ENI-private[${count.index}]"
#   }
# }

#############################################################
# Elastic IP
#############################################################

resource "aws_eip" "nat" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  vpc               = true
  network_interface = element(aws_network_interface.nic_pb[*].id, count.index)
  tags = {
    "Name" = "nat-eip-${count.index}"
  }
}

# data "aws_eips" "nat" {
#   filter {
#     name   = "tag:Name"
#     values = ["NAT-EIP*"]
#   }
# }

resource "aws_eip_association" "eip_assoc" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  network_interface_id = element(aws_network_interface.nic_pb[*].id, count.index)
  allocation_id        = element(aws_eip.nat[*].id, count.index)
  depends_on = [
    var.pub_instance_id,
  ]
}

#############################################################
# Public Security Group
#############################################################

resource "aws_security_group" "public" {
  name        = "${var.namespace}-public"
  description = "Allow inbound traffic from anywhere"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.pub_ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-public"
  }
}

#############################################################
# Private Security Group
#############################################################

resource "aws_security_group" "private" {
  name        = "${var.namespace}-private"
  description = "Allow inbound traffic from public subnet"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.private_ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-private"
  }
}
