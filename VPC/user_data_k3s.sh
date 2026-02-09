#!/bin/bash
set -euxo pipefail

# 로그 남기기 (문제 생기면 여기 보면 됨)
exec > >(tee /var/log/user-data-k3s.log | logger -t user-data -s 2>/dev/console) 2>&1



# k3s 설치 (단일 노드: server + agent)
# kubeconfig 권한 완화(테스트용)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -

# 서비스 확인
systemctl enable --now k3s
sleep 5
k3s kubectl get nodes -o wide || true
