# EKS 클러스터
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name    = local.project
  cluster_version = var.eks_cluster_version

  # 클러스터 엔드포인트(API 서버)에 퍼블릭 접근 허용
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  # 클러스터 보안그룹을 생성할 VPC
  vpc_id = module.vpc.vpc_id

  # 노드그룹/노드가 생성되는 서브넷
  subnet_ids = module.vpc.private_subnets

  # 컨트롤 플레인으로 연결될 ENI를 생성할 서브넷
  control_plane_subnet_ids = module.vpc.private_subnets

  # 클러스터를 생성한 IAM 객체에서 쿠버네티스 어드민 권한 할당
  enable_cluster_creator_admin_permissions = true

  create_kms_key              = false
  create_cloudwatch_log_group = false
  create_node_security_group  = false

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      vpc_security_group_ids = [aws_security_group.eks_nodes_sg.id]
    }
  }

  # 로깅 비활성화
  cluster_enabled_log_types = []
  # 암호화 비활성화
  cluster_encryption_config = {}

  depends_on = [
    module.vpc.natgw_ids
  ]
}

locals {
  eks_addons = [
    "coredns",
    "kube-proxy",
    "vpc-cni",
    "eks-pod-identity-agent"
  ]
}

data "aws_eks_addon_version" "this" {
  for_each = toset(local.eks_addons)

  addon_name         = each.key
  kubernetes_version = module.eks.cluster_version
}

resource "aws_eks_addon" "this" {
  for_each = toset(local.eks_addons)

  cluster_name                = module.eks.cluster_name
  addon_name                  = each.key
  addon_version               = data.aws_eks_addon_version.this[each.key].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "2m"
  }
}

/* 필수 라이브러리 */
# AWS Load Balancer Controller에 부여할 IAM 역할 및 Pod Identity Association
module "aws_load_balancer_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.11.0"

  name = "aws-load-balancer-controller"

  attach_aws_lb_controller_policy = true

  associations = {
    (module.eks.cluster_name) = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = {
    app = "aws-load-balancer-controller"
  }
}

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version
  namespace  = "kube-system"

  values = [
    <<-EOT
    clusterName: ${module.eks.cluster_name}
    vpcId: ${module.vpc.vpc_id}
    replicaCount: 1
    serviceAccount:
      create: true
    EOT
  ]

  depends_on = [
    module.aws_load_balancer_controller_pod_identity
  ]
}

resource "time_sleep" "wait_for_lb_controller" {
  create_duration = "60s"
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}

# ExternalDNS에 부여할 IAM 역할 및 Pod Identity Association
module "external_dns_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.11.0"

  name = "external-dns"

  attach_external_dns_policy = true
  external_dns_hosted_zone_arns = [
    data.aws_route53_zone.this.arn
  ]

  associations = {
    (module.eks.cluster_name) = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "external-dns"
    }
  }

  tags = {
    app = "external-dns"
  }
}

# ExternalDNS
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = var.external_dns_chart_version
  namespace  = "kube-system"

  values = [
    <<-EOT
    serviceAccount:
      create: true
      annotations:
        eks.amazonaws.com/role-arn: ${module.external_dns_pod_identity.iam_role_arn}
    txtOwnerId: ${module.eks.cluster_name}
    policy: sync
    resources:
      requests:
        memory: 100Mi
    EOT
  ]

  depends_on = [
    time_sleep.wait_for_lb_controller
  ]

  timeout = 600 # 헬름 언인스톨 타임아웃 증가
}

# Ingress NGINX를 설치할 네임스페이스
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

# Ingress NGINX
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_chart_version
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name

  values = [
    templatefile("${path.module}/helm-values/ingress-nginx.yaml", {
      lb_acm_certificate_arn = aws_acm_certificate_validation.this.certificate_arn
    })
  ]

  depends_on = [
    time_sleep.wait_for_lb_controller,
    aws_acm_certificate_validation.this
  ]

  timeout = 600 # 헬름 언인스톨 타임아웃 증가
}



