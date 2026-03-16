# GoLive2 Terraform Architecture

This repository contains a modular Terraform baseline for the AWS target architecture described in the supplied design document. It is structured so `dev` and `prod` can be composed from the same reusable modules with different capacity, networking, and security settings.

## Implemented Architecture

- API edge: Amazon API Gateway HTTP API behind CloudFront, protected by AWS WAF, with a Lambda request authorizer that validates JWTs against a JWKS endpoint, extracts roles, enforces route-level role access, and forwards `x-trace-id` for log correlation.
- Compute: ECS on EC2 using an Auto Scaling Group-backed capacity provider, two services (`user-management` and `device-management`), internal ALB routing, CloudWatch logs, and service autoscaling on CPU, memory, and ALB request count.
- Database: Amazon RDS for SQL Server in Multi-AZ mode, CloudWatch exports, Secrets Manager for credentials, security-group restrictions to ECS and bastion, and production-safe deletion protection.
- Networking: VPC across two AZs with public, application-private, and database-private subnets; internet gateway; NAT gateways; private ECS and database tiers.
- Security: Bastion host for administrative access, optional site-to-site VPN resources for ETL/on-prem connectivity, TLS via ACM on CloudFront, and WAF managed rules.
- CI/CD: GitHub Actions workflows for Terraform validation/apply and microservice image build/push/deploy.

## Repository Layout

```text
terraform/
  environments/
    dev/
    prod/
  modules/
    api-edge/
    bastion-vpn/
    ecs-platform/
    rds/
    vpc/
.github/workflows/
```

## Usage

1. Copy `terraform/environments/dev/terraform.tfvars.example` or `terraform/environments/prod/terraform.tfvars.example` to `terraform.tfvars`.
2. Configure your real ACM certificate ARN, JWT issuer/audience/JWKS values, CIDR ranges, and container image URIs.
3. Initialize and deploy the chosen environment:

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

## Important Assumptions

- The design uses ECS on EC2 rather than Fargate because the requirements explicitly reference ASG-driven scaling and EC2 as the lower-cost long-running option.
- API Gateway is implemented as HTTP API with VPC Link to an internal ALB. CloudFront sits in front for TLS and WAF enforcement.
- RDS is modeled as SQL Server because the requirements mention port `1433`.
- The Lambda authorizer expects an RSA-signed JWT and a reachable JWKS endpoint.
- The GitHub Actions workflows assume AWS OIDC federation, `AWS_DEPLOY_ROLE_ARN`, `AWS_ACCOUNT_ID`, and `AWS_REGION` are configured in GitHub.

## Gaps You Still Need To Fill

- Real application source under `services/user-management` and `services/device-management`.
- A remote Terraform backend such as S3 plus DynamoDB locking.
- Exact VPN tunnel, on-prem CIDR, and identity-provider settings.
- ECS task secrets and service-specific environment variables beyond the base scaffold.

## Recommended Next Step

Wire in the real service container repos and decide whether you want the deployment source of truth for image tags to remain in Terraform or move to dedicated ECS deployment artifacts per service.
