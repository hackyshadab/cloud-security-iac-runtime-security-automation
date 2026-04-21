# Architecture Documentation

## System Purpose

This architecture provisions a hardened AWS security baseline using Terraform and then layers continuous detection and response on top of it. The infrastructure is designed to protect S3 storage, preserve audit evidence, detect threats, and notify operators automatically.

---

## 1) CI/CD Layer

### What it does

The GitHub Actions workflow acts as the first security checkpoint. On every push to `main`, it performs:

- repository checkout
- Terraform setup
- AWS credential configuration
- `terraform init`
- `terraform validate`
- `tfsec` scan
- `Checkov` scan
- `terraform plan`
- OPA evaluation against the generated plan JSON

### Why it matters

This layer prevents insecure Terraform from reaching AWS. It is the place where policy violations should be caught before deployment.

### Repo-specific implementation

The workflow file is `.github/workflows/devsecops.yml`. It currently ends after OPA evaluation. The repository does **not** yet include a Terraform apply job in the workflow.

---

## 2) IaC Layer

### Root Terraform layout

- `terraform/backend.tf` defines the remote backend
- `terraform/providers.tf` configures the AWS provider
- `terraform/environments/dev/main.tf` wires the modules together
- `terraform/modules/s3` creates the secure storage layer
- `terraform/modules/security-services` creates the security and monitoring layer

### Design approach

The IaC is split into modules to keep responsibilities clear:

- `s3` module = encrypted, versioned, public-blocked buckets
- `security-services` module = detection, logging, alerting, and compliance services

This modular split makes the stack easier to audit, reuse, and extend.

---

## 3) Security Scanning Layer

### Tools used

- **tfsec** for Terraform security checks
- **Checkov** for policy and misconfiguration detection
- **OPA** for custom logic that is specific to this repository

### Custom OPA policies

- `encryption.rego` blocks S3 buckets without server-side encryption
- `iam.rego` blocks IAM policies containing `*:*`
- `tagging.rego` blocks S3 buckets missing the `Owner` tag

### Why this layer is useful

Terraform scanners catch many common issues, but not every organization-specific rule. OPA fills that gap and allows the team to define its own deploy-time rules.

---

## 4) AWS Infrastructure Layer

### Secure storage

The S3 module provisions:

- a main bucket
- a log bucket
- versioning
- KMS encryption
- public access blocks
- access logging
- lifecycle expiration

### Security services

The security-services module provisions:

- KMS key for logs and alerts
- GuardDuty detector
- Security Hub account
- AWS Config recorder and delivery channel
- CloudTrail
- VPC Flow Logs
- EventBridge rules
- Lambda incident handler
- SNS topic and email subscription
- SQS dead-letter queue
- CloudWatch log groups
- IAM roles and policies

---

## 5) Monitoring Layer

### GuardDuty

GuardDuty is enabled with a fifteen-minute finding publishing frequency. It provides threat detection for suspicious AWS activity.

### Security Hub

Security Hub is enabled as a central findings plane. The standards subscription is present in the repo but commented out in `securityhub_config.tf`.

### AWS Config

AWS Config continuously records resource configuration and delivers snapshots into a dedicated S3 bucket. This supports compliance checks and drift review.

### CloudTrail

CloudTrail is configured as a multi-region trail with log file validation enabled. That makes the audit trail more defensible and tamper-aware.

### VPC Flow Logs

The default VPC flow logs are enabled and routed into CloudWatch Logs for network telemetry.

---

## 6) Incident Response Layer

### Event routing

Three EventBridge rules route events to the same Lambda function:

- GuardDuty findings
- Security Hub findings
- AWS Config compliance changes

### Lambda behavior

The incident handler reads the `source` field and formats a different alert body for each event family. It then publishes the message to SNS.

### Notification path

SNS delivers email alerts to the configured security notification address. Lambda also has a DLQ configured with SQS to preserve failed events.

---

## Architecture Diagram

```mermaid
flowchart LR
    Dev[Developer] --> GH[GitHub Actions]
    GH --> TF[Terraform Validate]
    GH --> SF[tfsec + Checkov]
    GH --> OPA[OPA Plan Policy Check]
    OPA -->|pass| APPLY[Terraform Apply]
    OPA -->|fail| FAIL[Block deployment]

    APPLY --> S3[S3 Module]
    APPLY --> SEC[Security Services Module]

    S3 --> MAIN[Encrypted main bucket]
    S3 --> LOGS[Encrypted log bucket]

    SEC --> GD[GuardDuty]
    SEC --> SH[Security Hub]
    SEC --> CFG[AWS Config]
    SEC --> CT[CloudTrail]
    SEC --> VPC[VPC Flow Logs]
    SEC --> EB[EventBridge]
    SEC --> L[Lambda incident handler]
    SEC --> SNS[SNS Email Alerts]
    SEC --> DLQ[SQS Dead-Letter Queue]

    GD --> EB
    SH --> EB
    CFG --> EB
    EB --> L
    L --> SNS
    L --> DLQ
```

![ end-to-end promotion flow](./images/main.png)

---

## CI/CD Layer Detail

```mermaid
flowchart TD
    A[Push to main] --> B[GitHub Actions]
    B --> C[terraform init]
    C --> D[terraform validate]
    D --> E[tfsec]
    E --> F[Checkov]
    F --> G[terraform plan]
    G --> H[OPA eval on plan JSON]
    H --> I{Deny rules triggered?}
    I -->|Yes| J[Stop pipeline]
    I -->|No| K[Ready for apply stage]
```

---

## IaC Layer Detail

```mermaid
flowchart TD
    R[terraform/environments/dev/main.tf] --> S3M[modules/s3]
    R --> SEM[modules/security-services]
    S3M --> B1[Secure S3 bucket]
    S3M --> B2[Log bucket]
    SEM --> G1[GuardDuty]
    SEM --> G2[Security Hub]
    SEM --> G3[AWS Config]
    SEM --> G4[CloudTrail]
    SEM --> G5[EventBridge]
    SEM --> G6[Lambda]
```

---

## Security Scanning Layer Detail

```mermaid
flowchart TD
    TF[Terraform source] --> TS[tfsec]
    TF --> CK[Checkov]
    TF --> PLAN[terraform plan JSON]
    PLAN --> OPA[OPA / Rego]
    OPA --> A1[encryption.rego]
    OPA --> A2[iam.rego]
    OPA --> A3[tagging.rego]
```

---

## Monitoring Layer Detail

```mermaid
flowchart TD
    GD[GuardDuty Finding] --> EB[EventBridge]
    SH[Security Hub Finding] --> EB
    CFG[AWS Config Change] --> EB
    EB --> L[Lambda]
    L --> SNS[SNS Email]
    L --> DLQ[SQS DLQ]
```

---

## Incident Response Behavior

The Lambda function in `lambda/incident_handler.py` handles three event families:

- **GuardDuty**: prints type, severity, description, account, and region
- **Security Hub**: prints title, severity, resource ID, and description
- **AWS Config**: prints resource type, resource ID, and change type

The handler then publishes a unified alert into SNS, which simplifies response operations and keeps the notification path consistent across services.

---

## Why the Architecture Is Strong

- Each domain has a dedicated module.
- Security is enforced before deploy and after deploy.
- Controls are layered rather than duplicated.
- Alerts are routed through a single incident path.
- The design is understandable for both engineers and auditors.
