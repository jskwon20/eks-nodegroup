
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

# Ingress Rule: Allow all traffic between nodes
resource "aws_security_group_rule" "eks_nodes_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "Allow nodes to communicate with each other."
}


resource "aws_security_group_rule" "eks_nodes_ingress_cluster_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "Allow EKS control plane to communicate with node webhooks (e.g., ALB/NLB webhook)."
}

# 명시적 추가 제안
resource "aws_security_group_rule" "eks_nodes_ingress_webhook_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "Allow node-to-node webhook traffic over 443"
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

resource "aws_iam_role_policy_attachment" "eks_admin_access" {
  role       = aws_iam_role.eks_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
