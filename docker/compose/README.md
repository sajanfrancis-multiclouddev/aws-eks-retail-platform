# Docker Compose – Retail Store Microservices

> Baseline demo status: ✅ Completed  
> Current phase: Portfolio enhancements and resilience testing  
> Application version: `1.6.2`

This module documents my hands-on deployment of the AWS Retail Store sample
application as a multi-container microservices stack using Docker Compose on an
Amazon EC2 workstation.

The baseline application was successfully pulled, started and validated. The
next phase improves security, persistence, networking, observability and
automated testing without presenting planned work as completed work.

## Architecture

![Docker Compose Retail Store Architecture](docs/docker-compose-architecture.png)

Traffic enters through EC2 port `8888` and is forwarded to the UI container on
port `8080`. The UI communicates with the Cart, Catalog, Checkout and Orders
services through Docker's internal DNS. Supporting services provide relational
data, caching, messaging, search and local DynamoDB storage.

## Services Deployed

| Layer | Service | Image / Version | Validation |
|---|---|---|---|
| Frontend | UI | `retail-store-sample-ui:1.6.2` | ✅ Healthy |
| Application | Cart | `retail-store-sample-cart:1.6.2` | ✅ Healthy |
| Application | Catalog | `retail-store-sample-catalog:1.6.2` | ✅ Healthy |
| Application | Checkout | `retail-store-sample-checkout:1.6.2` | ✅ Healthy |
| Application | Orders | `retail-store-sample-orders:1.6.2` | ✅ Healthy |
| Data | DynamoDB Local | `amazon/dynamodb-local:1.20.0` | ✅ Healthy |
| Data | MariaDB | `mariadb:10.9` | ✅ Healthy |
| Data | Redis | `redis:6.0-alpine` | ✅ Healthy |
| Data | PostgreSQL | `postgres:16.1` | ✅ Healthy |
| Search | OpenSearch | `opensearchproject/opensearch:3.5.0` | ✅ Healthy |
| Messaging | RabbitMQ | `rabbitmq:3-management` | ✅ Running |

## Baseline Work Completed

- ✅ Downloaded and reviewed the Compose configuration
- ✅ Pulled all application and supporting-service images
- ✅ Started the complete stack in detached mode
- ✅ Verified container status using `docker compose ps` and `docker ps -a`
- ✅ Confirmed health checks for application, database and search containers
- ✅ Exposed only the UI on port `8888` for application access
- ✅ Diagnosed an OpenSearch image-pull failure caused by insufficient disk space
- ✅ Increased the EBS root volume from `8 GiB` to `40 GiB`
- ✅ Extended the Linux partition and XFS filesystem
- ✅ Confirmed approximately `34 GiB` of usable free space after expansion
- ✅ Recovered the deployment and started the stack successfully
- ✅ Practised stopping and starting individual Compose services
- ✅ Identified that Compose commands must run from the project directory or use `-f`

## Repository Structure

```text
docker/compose/
├── README.md
├── docker-compose.yaml
├── .env.example
├── .gitignore
├── docs/
│   └── docker-compose-architecture.png
└── tests/
    └── smoke-test.sh
```

## Prerequisites

- Docker Engine
- Docker Compose v2
- Linux `x86_64` EC2 workstation
- Sufficient memory for the complete microservices stack
- At least `30–40 GiB` of EBS storage when using OpenSearch locally
- EC2 security-group access to TCP port `8888` from the tester's IP only

Verify the environment:

```bash
docker version
docker compose version
uname -m
df -hT /
free -h
```

## Start the Baseline Stack

Run Compose commands from the directory containing `docker-compose.yaml`:

```bash
cd ~/demo-compose
ls -l docker-compose.yaml
```

Validate the configuration before deployment:

```bash
docker compose -f docker-compose.yaml config --quiet
```

Pull and start the stack:

```bash
docker compose -f docker-compose.yaml pull
docker compose -f docker-compose.yaml up -d
```

Check status:

```bash
docker compose -f docker-compose.yaml ps
docker compose -f docker-compose.yaml logs --tail 100
```

Application URL:

```text
http://EC2-PUBLIC-IP:8888
```

Do not commit a temporary EC2 public IP to the repository.

## Useful Operations

### Follow logs

```bash
docker compose logs -f
docker compose logs -f orders
```

### View resource usage

```bash
docker compose stats
docker system df
df -h /
```

### Stop and restart one service

```bash
docker compose stop orders
docker compose ps -a
docker compose start orders
```

### Run Compose from another directory

```bash
docker compose \
  -f ~/demo-compose/docker-compose.yaml \
  ps
```

Without the file path or the correct working directory, Compose returns:

```text
no configuration file provided: not found
```

## Troubleshooting Evidence

### OpenSearch image pull failed: no space left on device

The initial OpenSearch pull failed with:

```text
failed to register layer: no space left on device
```

Diagnosis:

```bash
df -h
df -i
docker system df
sudo lsblk
```

The EBS disk had been increased to `40 GiB`, but Linux initially continued to
use the original `8 GiB` root partition. The partition and XFS filesystem were
expanded with:

```bash
sudo growpart /dev/nvme0n1 1
sudo xfs_growfs -d /
df -hT /
```

Final validation showed the root filesystem at approximately `40 GiB` with
enough free capacity for all Compose images.

## Configuration Safety

Create `.env.example` with placeholders only:

```dotenv
DB_PASSWORD=replace-with-a-secure-password
UI_PORT=8888
UI_THEME=green
APP_VERSION=1.6.2
```

Create the real local file:

```bash
cp .env.example .env
chmod 600 .env
vi .env
```

Add to `.gitignore`:

```gitignore
.env
.env.*
!.env.example
secrets/
```

Never commit passwords, tokens, AWS credentials, Docker credentials or real
environment files. A gitignored `.env` is suitable for this local demo;
production credentials should be supplied by a managed secret store.

## Enhancement Roadmap

The following enhancements are intentionally marked as pending until they are
implemented and tested.

| Enhancement | Status |
|---|---|
| Replace placeholder health checks with genuine readiness checks | ⏳ Planned |
| Add RabbitMQ health check and Orders dependency | ⏳ Planned |
| Remove conflicting empty-password database configuration | ⏳ Planned |
| Add persistent named volumes for stateful services | ⏳ Planned |
| Test data persistence across container recreation | ⏳ Planned |
| Segment frontend, services and data networks | ⏳ Planned |
| Add CPU and memory limits to all services | ⏳ Planned |
| Add container-log rotation | ⏳ Planned |
| Parameterize image versions, UI port and theme | ⏳ Planned |
| Add automated smoke tests | ⏳ Planned |
| Perform service-failure and recovery testing | ⏳ Planned |
| Add Compose configuration validation to CI | ⏳ Planned |

## Planned Enhancements

### 1. Genuine dependency health checks

- Replace any `exit 0` placeholder health check with a real readiness test.
- Add `rabbitmq-diagnostics -q ping` to RabbitMQ.
- Make Orders wait for healthy PostgreSQL and RabbitMQ services.
- Use `depends_on.condition: service_healthy` only with meaningful checks.

### 2. Persistent state

Add named volumes for MariaDB, PostgreSQL, Redis, RabbitMQ, OpenSearch and any
required DynamoDB Local data. Validate that application data survives:

```bash
docker compose down
docker compose up -d
```

`docker compose down` preserves named volumes. Use `--volumes` only when data
deletion is intentional.

### 3. Network segmentation

Create separate networks:

```text
Frontend network: User-facing UI
Services network: UI and application APIs
Data network: Application services and their dependencies
```

Only services that must communicate should share a network.

### 4. Resource and log controls

- Measure real usage with `docker compose stats`.
- Apply tested CPU and memory limits per service.
- Configure `json-file` log rotation with `max-size` and `max-file`.
- Prefer `restart: unless-stopped` for a manually operated learning VM.

### 5. Automated validation

Create `tests/smoke-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

UI_URL="${UI_URL:-http://localhost:8888}"

curl --fail --silent "${UI_URL}/actuator/health"
curl --fail --silent "${UI_URL}/topology" >/dev/null
curl --fail --silent "${UI_URL}/" >/dev/null

echo "Docker Compose smoke tests passed"
```

Run:

```bash
chmod +x tests/smoke-test.sh
./tests/smoke-test.sh
```

### 6. Failure and recovery testing

```bash
docker compose stop catalog
docker compose ps
docker compose logs --tail 100 ui catalog

docker compose start catalog
docker compose ps
curl --fail http://localhost:8888/topology
```

Document observed errors, impact, recovery time and whether dependent services
reconnected automatically.

## My Enhancements

Move an item into this section only after it has been implemented and tested:

```markdown
- Replaced placeholder checks with genuine service-readiness validation
- Added persistent volumes and verified data survival after recreation
- Segmented frontend, application and data-layer networks
- Externalized configuration using a safe environment template
- Added tested resource limits and container log rotation
- Added automated smoke and service-recovery testing
```

## Safe Shutdown and Cleanup

Stop the project without deleting containers:

```bash
docker compose stop
```

Stop and remove the project's containers and network while preserving named
volumes:

```bash
docker compose down --remove-orphans
```

Remove project volumes only when their data is no longer required:

```bash
docker compose down --volumes --remove-orphans
```

Avoid broad cleanup commands such as:

```bash
docker system prune -a --volumes -f
```

They can delete resources belonging to unrelated Docker projects.

## Cost Control

- Stop the EC2 instance after each practice session.
- EC2 compute billing stops while the instance is stopped.
- The `40 GiB` EBS volume continues to incur storage charges while stopped.
- Push code to GitHub and necessary images to a registry before termination.
- Terminate the instance and delete the EBS volume after completing the project
  if the local environment is no longer needed.

## Learning Outcomes

- Orchestrated a multi-service retail platform with Docker Compose
- Used service discovery and health-based dependencies
- Operated and troubleshot a complete container stack on EC2
- Diagnosed Docker storage exhaustion and expanded an EBS-backed XFS filesystem
- Practised logs, statistics, individual-service lifecycle and project cleanup
- Defined a roadmap for persistence, network segmentation, security and testing

## Credits and Attribution

This personal learning and portfolio implementation is based on concepts taught
in the Udemy course
[Ultimate DevOps Real-World Project Implementation on AWS](https://www.udemy.com/course/aws-eks-kubernetes-karpenter-devops-production/)
by StackSimplify.

The original retail application and course reference materials were provided by
their respective authors. This repository documents my own deployment,
validation, troubleshooting, operational decisions and planned enhancements.

