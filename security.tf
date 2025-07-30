
# EKS Node Security Group
resource "aws_security_group" "eks_nodes_sg" {
  name        = "eks-nodes-sg"
  description = "Security group for EKS nodes"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "eks-nodes-sg"
  }
}

# Egress Rule: Allow all outbound traffic
resource "aws_security_group_rule" "eks_nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "Allow all outbound traffic for nodes to pull images and communicate with AWS APIs."
}

# Ingress Rule: Allow all traffic within the security group (node-to-node)
resource "aws_security_group_rule" "eks_nodes_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "Allow all traffic between nodes in the same security group"
}

# Ingress Rule: Allow EKS control plane to nodes
resource "aws_security_group_rule" "eks_nodes_ingress_cluster_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "Allow EKS control plane to communicate with nodes on port 443"
}

# Ingress Rule: Allow EKS control plane to nodes for webhooks
resource "aws_security_group_rule" "eks_nodes_ingress_webhook_8443" {
  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "Allow EKS control plane to communicate with nodes on port 8443 (webhooks)"
}

# Ingress Rule: Allow EKS control plane to nodes for webhooks
resource "aws_security_group_rule" "eks_nodes_ingress_webhook_9443" {
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "Allow EKS control plane to communicate with nodes on port 9443 (webhooks)"
}

# Ingress Rule: Allow Kubelet API from cluster to nodes
resource "aws_security_group_rule" "eks_nodes_ingress_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "Allow EKS control plane to communicate with Kubelet API on port 10250"
}

# Ingress Rule: Allow Kubelet API from cluster to nodes
resource "aws_security_group_rule" "eks_nodes_ingress_cluster_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow EKS control plane to communicate with Kubelet API."
}


# Ingress Rule: Allow SSH from bastion to nodes
resource "aws_security_group_rule" "eks_nodes_ingress_bastion_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.jskwon_bastion_sg.id
  description              = "Allow SSH access from bastion host."
}

# CoreDNS를 위한 DNS 포트
resource "aws_security_group_rule" "eks_nodes_ingress_dns_tcp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow DNS (TCP) from control plane"
}

resource "aws_security_group_rule" "eks_nodes_ingress_dns_udp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow DNS (UDP) from control plane"
}

# Ingress Rule: Allow all traffic from nodes to cluster
resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  description              = "Allow all traffic from the node group to the EKS control plane."
}

# Bastion Host Security Group
resource "aws_security_group" "jskwon_bastion_sg" {
  name        = "jskwon-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_cidr]
    description = "Allow SSH access from specified IP."
  }
  # Allow HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.bastion_cidr]
    description = "Allow HTTPS access from specified IP."
  }
  # Allow VSCode web access
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.bastion_cidr]
    description = "Allow VSCode web access from specified IP."
  }
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic from the bastion host."
  }

  tags = {
    Name = "jskwon-bastion-sg"
  }
}