#!/bin/bash
set -e

REGION="ap-northeast-1"
CLUSTER_NAME="devops-eks"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Daily Rebuild Script ==="
read -rp "確定執行完整重建? (y/N) " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { echo "取消"; exit 0; }

# Step 1: Terraform (EKS)
echo ""
echo "=== Step 1: terraform apply ==="
cd "${PROJECT_DIR}/terraform/eks"
terraform init
terraform apply -auto-approve
cd "$PROJECT_DIR"

# Step 2: 等待 nodes ready
echo ""
echo "=== Step 2: 等待 nodes ready ==="
kubectl wait --for=condition=Ready nodes --all --timeout=15m

# Step 3: ALB Controller
echo ""
echo "=== Step 3: ALB Controller ==="
kubectl apply -f "${PROJECT_DIR}/k8s/setup/ServiceAccount.yaml"
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  -f "${PROJECT_DIR}/helm/aws-load-balancer-controller/values.yaml"

# Step 4: 觸發 CI/CD
echo ""
echo "=== Step 4: git push 觸發 CI/CD ==="
cd "$PROJECT_DIR"
git commit --allow-empty -m "chore: trigger deploy $(date +%-m/%-d)"
git push

# Step 5: 等待 ALB active
echo ""
echo "=== Step 5: 等待 ALB ready... ==="
while true; do
  STATE=$(aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --query 'LoadBalancers[0].State.Code' \
    --output text 2>/dev/null)
  DNS=$(aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --query 'LoadBalancers[0].DNSName' \
    --output text 2>/dev/null)

  printf "ALB State: %-15s DNS: %s\n" "${STATE:-waiting...}" "${DNS:-N/A}"

  if [[ "$STATE" == "active" ]]; then
    break
  fi
  sleep 15
done

# Step 6: 等待應用程式就緒 (HTTP 200)
echo ""
echo "=== Step 6: 等待應用程式就緒 (HTTP 200)... ==="
while true; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DNS")
  printf "HTTP Status: %s\n" "$HTTP_CODE"
  if [[ "$HTTP_CODE" == "200" ]]; then
    break
  fi
  sleep 10
done

echo ""
echo "=== Done! ==="
echo "URL: http://$DNS"
echo ""
cmd.exe /c "start http://$DNS" 2>/dev/null || echo "請手動開啟: http://$DNS"
