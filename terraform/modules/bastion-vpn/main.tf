data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "Administrative SSH access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-bastion-sg"
  })
}

resource "aws_iam_role" "bastion" {
  name               = "${var.name}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "bastion" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ])

  role       = aws_iam_role.bastion.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  tags = merge(var.tags, {
    Name = "${var.name}-bastion"
  })
}

resource "aws_vpn_gateway" "this" {
  count  = var.create_vpn ? 1 : 0
  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-vgw"
  })
}

resource "aws_customer_gateway" "this" {
  count      = var.create_vpn ? 1 : 0
  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = merge(var.tags, {
    Name = "${var.name}-cgw"
  })
}

resource "aws_vpn_connection" "this" {
  count               = var.create_vpn ? 1 : 0
  vpn_gateway_id      = aws_vpn_gateway.this[0].id
  customer_gateway_id = aws_customer_gateway.this[0].id
  type                = "ipsec.1"
  static_routes_only  = var.static_routes_only

  tags = merge(var.tags, {
    Name = "${var.name}-vpn"
  })
}

resource "aws_vpn_connection_route" "static" {
  for_each = var.create_vpn ? toset(var.vpn_static_routes) : []

  vpn_connection_id      = aws_vpn_connection.this[0].id
  destination_cidr_block = each.value
}
