# Terraform EKS 프로젝트 - 단계별 Apply 가이드 (간소화 버전)

이 문서는 Terraform `apply` 명령을 `--target` 옵션과 함께 사용하여 EKS 클러스터 및 관련 인프라를 논리적인 단계별로 배포하는 방법을 안내합니다. 각 단계는 이전 단계의 리소스에 의존하므로, 순서대로 실행하는 것이 중요합니다.

**주의사항:**
*   각 단계는 `terraform apply --auto-approve --target=<리소스 주소>` 형식으로 실행됩니다.
*   `--target` 옵션은 특정 리소스만 적용하지만, 해당 리소스의 모든 의존성도 함께 적용합니다.
*   이 가이드는 현재 Terraform 구성(`eks-project` 폴더 내 `.tf` 파일들)을 기반으로 작성되었습니다.

---

### ✅ 0단계: Terraform 초기화

프로젝트를 시작하기 전에 Terraform 워킹 디렉토리를 초기화합니다.

```bash
terraform init
```

---

### ✅ 1단계: 핵심 네트워크 및 Bastion 호스트 구성

VPC, 서브넷, 라우팅 테이블, NAT Gateway 등 기본적인 네트워크 인프라와 Bastion 호스트 및 SSH 키를 생성합니다. 이들은 다른 모든 리소스의 기반이 됩니다.

```bash
terraform apply --auto-approve \
  --target=module.vpc
```

---

### ✅ 2단계: EKS 클러스터 및 관리형 노드 그룹 구성

EKS 컨트롤 플레인, 관리형 노드 그룹, 그리고 사용자 접근을 위한 IAM 역할 및 정책, 노드 그룹 보안 그룹 규칙을 생성합니다. `module.eks`가 클러스터와 노드 그룹의 대부분을 관리하며, 나머지 IAM 및 보안 그룹 규칙은 명시적으로 타겟팅합니다.

```bash
terraform apply --auto-approve \
  --target=module.eks \
  --target=aws_security_group_rule.eks_nodes_egress_all \
  --target=aws_security_group_rule.eks_nodes_ingress_self \
  --target=aws_security_group_rule.eks_nodes_ingress_bastion_ssh \
  --target=aws_security_group_rule.eks_nodes_ingress_cluster_https \
  --target=aws_security_group_rule.eks_nodes_ingress_cluster_kubelet \
  --target=aws_security_group_rule.cluster_ingress_from_nodes \
  --target=aws_security_group_rule.eks_nodes_ingress_webhook_9443 \
  --target=aws_security_group_rule.eks_nodes_ingress_webhook_8443 \
  --target=aws_security_group_rule.eks_nodes_ingress_dns_tcp \
  --target=aws_security_group_rule.eks_nodes_ingress_dns_udp
```

cat ~/.aws/credentials
aws eks update-kubeconfig --region ap-northeast-2 --name jskwon-eks-project

---

### ✅ 3단계: EKS 핵심 애드온 배포

EKS 클러스터 운영에 필수적인 애드온들을 배포합니다. `aws_eks_addon.this` 리소스는 `for_each`를 사용하므로, 단일 타겟으로 모든 애드온을 포함합니다.

```bash
terraform apply --auto-approve \
  --target=aws_eks_addon.this
```

---

### ✅ 4단계: 외부 서비스 통합 (ACM, ExternalDNS, Ingress-Nginx)

ACM 인증서, Route53 레코드, AWS Load Balancer Controller, ExternalDNS, Ingress-Nginx를 배포하여 외부 서비스 노출을 가능하게 합니다. 각 주요 컴포넌트의 최상위 리소스만 타겟팅하여 의존성을 활용합니다.

```bash
terraform apply --auto-approve \
  --target=aws_acm_certificate_validation.this \
  --target=helm_release.aws_load_balancer_controller \
  --target=time_sleep.wait_for_lb_controller \
  --target=helm_release.external_dns \
  --target=helm_release.ingress_nginx
```

---

### ✅ 5단계: GitLab 설치
```bash
terraform apply --refresh=false --auto-approve \
  --target kubernetes_namespace.gitlab \
  --target helm_release.gitlab
```
### ✅ 6단계: Bastion 인프라 상태 확인 (선택 사항)

terraform apply --auto-approve \

```bash
terraform apply --auto-approve \
  --target=aws_security_group.jskwon_bastion_sg \
  --target=aws_instance.jskwon_bastion_ec2 \
  --target=aws_key_pair.jskwon \
  --target=local_file.private_key \
  --target=random_password.vscode_password \
  --target=tls_private_key.jskwon_key

### ✅ 6단계: 전체 인프라 상태 확인 (선택 사항)

모든 단계가 완료된 후, 전체 인프라의 상태를 확인합니다.

```bash
terraform plan
```

---