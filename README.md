# Spring Boot Microservices on EKS

Production-oriented reference architecture for running Spring Boot microservices
on Amazon EKS: three services, infra-as-code, Kubernetes manifests, a Helm
chart, CI/CD, and observability, wired together end to end.

```
springboot-eks-microservices/
├── services/            Spring Boot 3 / Java 21 microservices (user, product, order)
├── kubernetes/          Raw K8s manifests (kustomize-style): base, ingress, hpa, pdb, network-policies, monitoring
├── helm/microservices/  Helm chart that templates the same resources for multi-env deploys
├── terraform/           VPC, EKS, ECR, RDS, IAM modules + root wiring
├── monitoring/          Prometheus, Grafana, and Alertmanager rule configs
├── scripts/             load-test.sh, chaos-test.sh
├── Jenkinsfile          CI/CD pipeline (build → scan → push → deploy → smoke test)
└── docker-compose.yml   Local dev stack (all 3 services + Postgres + Prometheus + Grafana)
```

## Architecture

- **Services**: `user-service` (8081), `product-service` (8082), `order-service` (8083) —
  each a standalone Spring Boot app with its own Postgres database, REST CRUD API under
  `/api/v1/<resource>`, and Actuator endpoints (`/actuator/health`, `/actuator/prometheus`).
- **Networking**: ALB Ingress → ClusterIP Services → Pods. Default-deny NetworkPolicies with
  explicit allow rules for DNS, ALB ingress, and inter-service/DB traffic.
- **Scaling & resilience**: HPA (CPU + memory, 65%/75% targets, 2–10 replicas), PodDisruptionBudgets
  (`minAvailable: 1`), topology spread across AZs, readiness/liveness/startup probes.
- **Data**: one RDS Postgres instance per service (`userdb`, `productdb`, `orderdb`), credentials in
  Secrets Manager, connectivity restricted to the VPC CIDR.
- **Identity**: EKS pods assume IAM roles via IRSA (per-service roles in `terraform/iam`), no
  static AWS credentials in containers.
- **Observability**: Micrometer + Prometheus scraping (pod annotations or `ServiceMonitor` if you run
  the Prometheus Operator), Grafana dashboard, Alertmanager rules for downtime, error rate, latency,
  crash loops, memory pressure, HPA saturation, and DB pool exhaustion.

## Getting started locally

```bash
docker-compose up --build
# user-service:    http://localhost:8081/api/v1/users
# product-service: http://localhost:8082/api/v1/products
# order-service:   http://localhost:8083/api/v1/orders
# Prometheus:      http://localhost:9090
# Grafana:         http://localhost:3000 (admin/admin)
```

Run a single service against an in-memory H2 DB instead of Postgres:

```bash
cd services/user-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

## Provisioning AWS infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in account-specific values
terraform init
terraform plan
terraform apply
```

This provisions, in order: VPC (public/private subnets across 3 AZs, NAT gateways) →
IAM roles (cluster, node group, IRSA per service, CI/CD) → EKS cluster + managed node group +
OIDC provider + core addons → ECR repositories (one per service, scan-on-push, lifecycle policy) →
RDS instances (one per service, Multi-AZ in prod, encrypted, Enhanced Monitoring).

> The S3/DynamoDB remote state backend in `terraform/main.tf` is a placeholder —
> replace `REPLACE_ME-terraform-state` / `REPLACE_ME-terraform-locks` with real
> resources before running `terraform init`.

## Deploying to Kubernetes

Point kubectl at the new cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name springboot-eks-cluster
```

**Option A — raw manifests (kustomize):**

```bash
kubectl apply -k kubernetes/base
kubectl apply -f kubernetes/ingress/
kubectl apply -f kubernetes/hpa/
kubectl apply -f kubernetes/pdb/
kubectl apply -f kubernetes/network-policies/
kubectl apply -f kubernetes/monitoring/   # requires Prometheus Operator CRDs
```

**Option B — Helm (recommended for multi-environment deploys):**

```bash
helm upgrade --install microservices ./helm/microservices \
  --namespace microservices --create-namespace \
  -f helm/microservices/values.yaml \
  -f helm/microservices/values-prod.yaml \
  --set global.imageRegistry=<your-ecr-repo-uri>
```

Before deploying, replace the placeholders in the manifests/values files:
`<ECR_REPO_URI>`, `<ACCOUNT_ID>`, `<ACM_CERT_ARN>`, and the `DB_USER`/`DB_PASSWORD`
secrets (ideally sourced from Secrets Manager via the External Secrets Operator
rather than committed as plain `Secret` manifests).

## CI/CD

The `Jenkinsfile` implements: checkout → detect changed services → build & unit
test (JUnit + JaCoCo) → SonarQube static analysis + quality gate → OWASP
dependency check → build & push images to ECR → Trivy image scan → `helm
upgrade` to the target environment → rollout status check → smoke test via
`scripts/load-test.sh`. Configure `ECR_REGISTRY_URI` as a Jenkins global
environment variable and wire the `sonarqube-server` and Slack integrations
before use.

## Testing & chaos engineering

```bash
# Load test the ingress (k6 if installed, else Apache Bench)
./scripts/load-test.sh https://api.example.com 60s 20

# Chaos experiments: random pod kills + CPU stress, then report pod/HPA/PDB state
./scripts/chaos-test.sh microservices full
```

## Notes & next steps

- The `Secret` manifests use plaintext placeholders for simplicity; swap in
  [External Secrets Operator](https://external-secrets.io/) or
  [AWS Secrets and Configuration Provider](https://docs.aws.amazon.com/eks/latest/userguide/manage-secrets.html)
  for production use.
- `kubernetes/monitoring/*-servicemonitor.yaml` requires the Prometheus
  Operator CRDs; if you're running plain Prometheus (as in `docker-compose.yml`),
  use `monitoring/prometheus/prometheus.yml` directly instead.
- Terraform modules assume you already manage a KMS key and an RDS Enhanced
  Monitoring IAM role elsewhere; ARNs are passed in via variables.
