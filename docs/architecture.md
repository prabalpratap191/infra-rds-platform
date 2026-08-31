# RDS Platform Architecture

## Overview

This document describes the architecture of the RDS PostgreSQL infrastructure for microservices running on AWS EKS.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-east-1)                      │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │                        VPC (10.0.0.0/16)                        │    │
│  │                                                                 │    │
│  │  ┌──────────────────┐              ┌──────────────────┐        │    │
│  │  │  Public Subnet   │              │  Public Subnet   │        │    │
│  │  │    (AZ-1)        │              │    (AZ-2)        │        │    │
│  │  │                  │              │                  │        │    │
│  │  │  ┌───────────┐   │              │   ┌───────────┐  │        │    │
│  │  │  │  Bastion  │   │              │   │    NAT    │  │        │    │
│  │  │  │  Host     │   │              │   │  Gateway  │  │        │    │
│  │  │  └─────┬─────┘   │              │   └───────────┘  │        │    │
│  │  └────────┼──────────┘              └──────────────────┘        │    │
│  │           │                                                      │    │
│  │           │ SSH                                                  │    │
│  │           ▼                                                      │    │
│  │  ┌──────────────────┐              ┌──────────────────┐        │    │
│  │  │ Private Subnet   │              │ Private Subnet   │        │    │
│  │  │    (AZ-1)        │              │    (AZ-2)        │        │    │
│  │  │  10.0.1.0/24     │              │  10.0.2.0/24     │        │    │
│  │  │                  │              │                  │        │    │
│  │  │  ┌────────────┐  │              │  ┌────────────┐  │        │    │
│  │  │  │    EKS     │  │              │  │    EKS     │  │        │    │
│  │  │  │   Worker   │◄─┼──────────────┼─►│   Worker   │  │        │    │
│  │  │  │   Nodes    │  │              │  │   Nodes    │  │        │    │
│  │  │  └──────┬─────┘  │              │  └──────┬─────┘  │        │    │
│  │  │         │        │              │         │        │        │    │
│  │  │         │ Port 5432 (PostgreSQL)          │        │        │    │
│  │  │         │        │              │         │        │        │    │
│  │  │         └────────┼──────────────┼─────────┘        │        │    │
│  │  │                  │              │                  │        │    │
│  │  └──────────────────┘              └──────────────────┘        │    │
│  │                     │              │                           │    │
│  │                     ▼──────────────▼                           │    │
│  │            ┌─────────────────────────────┐                     │    │
│  │            │   RDS Security Group        │                     │    │
│  │            │   Ingress: Port 5432        │                     │    │
│  │            │   From: EKS SG, Bastion SG  │                     │    │
│  │            └─────────────────────────────┘                     │    │
│  │                           │                                     │    │
│  │  ┌──────────────────┐    │    ┌──────────────────┐            │    │
│  │  │ DB Subnet Group  │◄───┴───►│ DB Subnet Group  │            │    │
│  │  │    (AZ-1)        │         │    (AZ-2)        │            │    │
│  │  │  10.0.10.0/24    │         │  10.0.11.0/24    │            │    │
│  │  │                  │         │                  │            │    │
│  │  │  ┌────────────┐  │         │  ┌────────────┐  │            │    │
│  │  │  │    RDS     │  │         │  │RDS Standby │  │            │    │
│  │  │  │ PostgreSQL │◄─┼─────────┼─►│ (Multi-AZ) │  │            │    │
│  │  │  │  Primary   │  │         │  │            │  │            │    │
│  │  │  └────────────┘  │         │  └────────────┘  │            │    │
│  │  │                  │         │                  │            │    │
│  │  └──────────────────┘         └──────────────────┘            │    │
│  │                                                                │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    AWS Services                              │    │
│  │                                                              │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │    │
│  │  │   Secrets    │  │  CloudWatch  │  │  Parameter   │      │    │
│  │  │   Manager    │  │   Logs &     │  │    Store     │      │    │
│  │  │              │  │   Alarms     │  │              │      │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │    │
│  │                                                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

           ▲                                            ▲
           │                                            │
           │                                            │
     ┌─────┴─────┐                              ┌──────┴──────┐
     │ Terraform │                              │   Jenkins   │
     │  (IaC)    │                              │  Pipeline   │
     └───────────┘                              └─────────────┘
```

## Components

### 1. Networking Layer

#### VPC Configuration
- **VPC CIDR**: 10.0.0.0/16 (or custom)
- **Availability Zones**: 2 (us-east-1a, us-east-1b)

#### Subnets
- **Public Subnets**: For bastion host and NAT gateway
  - Public Subnet 1 (AZ-1): 10.0.0.0/24
  - Public Subnet 2 (AZ-2): 10.0.1.0/24

- **Private Subnets**: For EKS worker nodes
  - Private Subnet 1 (AZ-1): 10.0.10.0/24
  - Private Subnet 2 (AZ-2): 10.0.11.0/24

- **Database Subnets**: For RDS instances
  - DB Subnet 1 (AZ-1): 10.0.20.0/24
  - DB Subnet 2 (AZ-2): 10.0.21.0/24

### 2. Compute Layer

#### EKS Cluster
- **Worker Nodes**: Running in private subnets
- **Node Groups**: Auto-scaling group
- **Microservices**: Deployed as pods
  - customer-service
  - order-service
  - catalog-service
  - order-history-service
  - notification-service

#### Bastion Host
- **Purpose**: Database administration and troubleshooting
- **Access**: SSH from authorized IPs only
- **Security**: Key-based authentication

### 3. Database Layer

#### RDS PostgreSQL
- **Engine**: PostgreSQL 15.4
- **Instance Class**: 
  - Dev: db.t3.medium
  - Prod: db.r5.xlarge
- **Storage**: 
  - Type: gp3
  - Allocated: 100 GB (dev), 500 GB (prod)
  - Max: 500 GB (autoscaling)
- **Multi-AZ**: Enabled for production
- **Encryption**: AES-256 at rest
- **Backups**: 
  - Automated: 7-day retention
  - Manual snapshots: On-demand

#### Database Architecture
```
RDS Instance (postgres database)
├── customer_db
│   └── customer_user (owner)
├── order_db
│   └── order_user (owner)
├── catalog_db
│   └── catalog_user (owner)
├── order_history_db
│   └── order_history_user (owner)
└── notification_db
    └── notification_user (owner)
```

### 4. Security Layer

#### Security Groups

**RDS Security Group**:
- Ingress:
  - Port 5432 from EKS worker nodes SG
  - Port 5432 from Bastion host SG
- Egress:
  - All traffic (required for RDS)

**EKS Worker Nodes Security Group**:
- Ingress:
  - Application ports
  - Node-to-node communication
- Egress:
  - Port 5432 to RDS SG
  - Port 443 to AWS APIs

**Bastion Security Group**:
- Ingress:
  - Port 22 from authorized IPs
- Egress:
  - Port 5432 to RDS SG

#### Secrets Management

**AWS Secrets Manager**:
- Master credentials: `rds/dev/master-credentials`
- Microservice credentials:
  - `rds/dev/customer-service`
  - `rds/dev/order-service`
  - `rds/dev/catalog-service`
  - `rds/dev/order-history-service`
  - `rds/dev/notification-service`

**Rotation**: Automatic rotation every 90 days (optional)

### 5. Monitoring Layer

#### CloudWatch Metrics
- CPU Utilization
- Database Connections
- Free Storage Space
- Freeable Memory
- Read/Write IOPS
- Read/Write Latency
- Network Throughput

#### CloudWatch Alarms
- High CPU (> 80%)
- Low Memory (< 1 GB)
- Low Storage (< 10 GB)
- High Connections (> 80% of max)
- High Read Latency (> 100ms)
- High Write Latency (> 100ms)
- High Disk Queue Depth (> 64)

#### CloudWatch Logs
- PostgreSQL logs
- Upgrade logs
- Error logs

#### Performance Insights
- Query performance analysis
- Wait event analysis
- Top SQL queries
- Database load monitoring

### 6. Kubernetes Integration

#### External Secrets Operator
```
SecretStore (AWS Secrets Manager)
    │
    ├─► ExternalSecret (customer-service)
    │   └─► Kubernetes Secret (customer-db-credentials)
    │
    ├─► ExternalSecret (order-service)
    │   └─► Kubernetes Secret (order-db-credentials)
    │
    └─► ... (other services)
```

#### ConfigMaps
- Non-sensitive configuration (DB host, port, name)
- Injected as environment variables

#### Service Account
- IRSA (IAM Roles for Service Accounts)
- Allows pods to access Secrets Manager

## Data Flow

### Application Request Flow

1. **Request arrives** at microservice pod
2. **Pod reads environment variables**:
   - DB_HOST, DB_PORT, DB_NAME (from ConfigMap)
   - DB_USERNAME, DB_PASSWORD (from Secret synced via External Secrets)
3. **Connection pool** (HikariCP) establishes connection to RDS
4. **Connection goes through**:
   - EKS worker node → RDS Security Group → RDS instance
5. **Query executes** in respective database
6. **Results return** to application
7. **Connection** returned to pool

### Secrets Sync Flow

1. **External Secrets Operator** watches for ExternalSecret resources
2. **Operator authenticates** to AWS using IRSA
3. **Retrieves secret** from Secrets Manager
4. **Creates/updates** Kubernetes Secret
5. **Pods mount** secret as environment variables
6. **Refresh** occurs every 1 hour (configurable)

## High Availability

### RDS Multi-AZ
- **Primary**: Active in AZ-1
- **Standby**: Passive in AZ-2
- **Synchronous replication**: Zero data loss
- **Automatic failover**: ~1-2 minutes

### EKS Pod Distribution
- **Pod anti-affinity**: Spread across AZs
- **Horizontal Pod Autoscaler**: Scale based on CPU/memory
- **Pod Disruption Budget**: Minimum 2 pods available

## Disaster Recovery

### Backup Strategy

**Automated Backups**:
- Daily automated snapshots
- 7-day retention (configurable)
- Point-in-time recovery (PITR)

**Manual Snapshots**:
- Created before major changes
- Retained indefinitely
- Can copy to other regions

### Recovery Time Objective (RTO)
- **Multi-AZ Failover**: 1-2 minutes
- **Snapshot Restore**: 15-30 minutes
- **Cross-Region Recovery**: 1-2 hours

### Recovery Point Objective (RPO)
- **Multi-AZ**: 0 seconds (synchronous)
- **Automated Backup**: 5 minutes (transaction logs)
- **Cross-Region**: 15 minutes (async replication)

## Security Architecture

### Network Security
- ✅ Private subnet deployment
- ✅ No public internet access
- ✅ Security group isolation
- ✅ Network ACLs
- ✅ VPC Flow Logs

### Data Security
- ✅ Encryption at rest (AES-256)
- ✅ Encryption in transit (SSL/TLS)
- ✅ KMS key management
- ✅ SSL enforcement

### Access Security
- ✅ IAM authentication (optional)
- ✅ Secrets Manager integration
- ✅ Least privilege principles
- ✅ Bastion host for admin access
- ✅ MFA for production access

## Scalability

### Vertical Scaling (RDS)
- Modify instance class
- Zero downtime for storage increase
- Brief downtime for compute changes

### Horizontal Scaling (Applications)
- HPA scales pods based on metrics
- Connection pooling per pod
- Read replicas (future enhancement)

### Storage Scaling
- Automatic storage scaling enabled
- Max storage: 500 GB (configurable)
- No downtime for scaling

## Cost Optimization

### Compute
- Use appropriate instance class per environment
- Reserved Instances for production (60% savings)
- Stop dev instances after hours

### Storage
- gp3 instead of gp2 (20% cost reduction)
- Optimize IOPS provisioning
- Lifecycle policies for snapshots

### Data Transfer
- Keep traffic within same AZ when possible
- Use VPC endpoints for AWS services

## Compliance

### Audit Logging
- CloudWatch Logs for all database activities
- CloudTrail for API calls
- VPC Flow Logs for network traffic

### Encryption
- FIPS 140-2 compliant encryption
- KMS key rotation
- SSL/TLS 1.2+ enforced

## Future Enhancements

1. **Read Replicas**: For read-heavy workloads
2. **Cross-Region Replication**: For disaster recovery
3. **Aurora Migration**: For better scalability
4. **Database Proxy**: For connection pooling
5. **Automated Patching**: For security updates
6. **Advanced Monitoring**: Custom metrics and dashboards
7. **Cost Allocation**: Detailed cost tracking per service

## References

- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [External Secrets Operator](https://external-secrets.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
