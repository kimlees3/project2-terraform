#!/bin/bash
set -euxo pipefail

# 로그 남기기 (문제 생기면 여기 보면 됨)
exec > >(tee /var/log/user-data-k3s.log | logger -t user-data -s 2>/dev/console) 2>&1

AWS_REGION="${aws_region}"
CLUSTER_NAME="${k3s_cluster_name}"
ENABLE_CONTAINER_INSIGHTS="${enable_container_insights}"

echo "[1/7] base packages"
dnf -y update || true
dnf -y install curl ca-certificates || true

echo "[2/7] install k3s (single node: server + agent)"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -

systemctl enable --now k3s

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "[3/7] wait node Ready"
for i in $(seq 1 180); do
  if kubectl get nodes 2>/dev/null | awk 'NR==2{print $2}' | grep -q "Ready"; then
    break
  fi
  sleep 2
done

echo "[4/7] wait traefik Ready"
# k3s 기본 traefik 배포가 완전히 Ready 된 뒤에 Ingress 적용해야 안정적
for i in $(seq 1 240); do
  READY="$(kubectl -n kube-system get deploy traefik -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "")"
  if [ "$${READY}" = "1" ]; then
    break
  fi
  sleep 2
done

echo "[4.5/7] force traefik NodePort fixed (30130/31942)"
# destroy/apply 시 traefik NodePort가 랜덤으로 바뀌면 ALB TargetGroup 포트(30130)와 mismatch가 발생함
# 그래서 traefik 서비스를 NodePort로 고정한다.
kubectl -n kube-system patch svc traefik --type='merge' -p '{
  "spec": {
    "type": "NodePort",
    "externalTrafficPolicy": "Local",
    "ports": [
      {"name":"web","port":80,"protocol":"TCP","targetPort":"web","nodePort":30130},
      {"name":"websecure","port":443,"protocol":"TCP","targetPort":"websecure","nodePort":31942}
    ]
  }
}'
kubectl -n kube-system get svc traefik -o wide || true

echo "[5/7] apply k8s manifests (healthz + justic-web + ingress)"
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: healthz-nginx-conf
  namespace: default
data:
  default.conf: |
    server {
      listen 80;
      location ^~ /health {
        add_header Content-Type text/plain;
        return 200 "ok\n";
      }
      location / { return 404 "not found\n"; }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthz
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: healthz
  template:
    metadata:
      labels:
        app: healthz
    spec:
      containers:
      - name: nginx
        image: nginx:stable-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: conf
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
      volumes:
      - name: conf
        configMap:
          name: healthz-nginx-conf
---
apiVersion: v1
kind: Service
metadata:
  name: healthz-svc
  namespace: default
spec:
  selector:
    app: healthz
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: justic-web
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: justic-web
  template:
    metadata:
      labels:
        app: justic-web
    spec:
      containers:
      - name: web
        image: ghcr.io/justice7934/justic-web:1.5
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: justic-web-svc
  namespace: default
spec:
  selector:
    app: justic-web
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: healthz-ing
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /health
        pathType: Prefix
        backend:
          service:
            name: healthz-svc
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ing
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: justic-web-svc
            port:
              number: 80
YAML

if [ "$${ENABLE_CONTAINER_INSIGHTS}" = "true" ] || [ "$${ENABLE_CONTAINER_INSIGHTS}" = "1" ]; then
  echo "[6/7] install CloudWatch Container Insights (cwagent + fluent-bit)"
  kubectl create namespace amazon-cloudwatch 2>/dev/null || true

  curl -fsSL \
    https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml \
  | sed "s/{{cluster_name}}/$${CLUSTER_NAME}/g; s/{{region_name}}/$${AWS_REGION}/g" \
  | kubectl apply -f -

  kubectl -n amazon-cloudwatch get pods -o wide || true
else
  echo "[6/7] skip Container Insights (ENABLE_CONTAINER_INSIGHTS=false)"
fi

echo "[7/7] quick checks"
kubectl get nodes -o wide || true
kubectl get pods,svc,ingress -A || true

echo "DONE"
