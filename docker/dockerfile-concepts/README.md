# Dockerfile Concepts – Optimized Java Microservice Image

> Project status: ✅ Completed  
> Current phase: Optimized multi-stage Dockerfile implementation

This exercise documents how I build and validate a secure, production-style
Docker image for the Retail Store UI Spring Boot microservice. It extends the
course implementation with automated tests, BuildKit caching, explicit
non-root ownership, container health checks, runtime restrictions, and targeted
cleanup.

## Concepts Covered

- Multi-stage Docker builds
- Dockerfile instructions and image layers
- Build context and `.dockerignore`
- BuildKit cache mounts for Maven
- Non-root container execution
- Spring Boot health checks
- CPU, memory, filesystem, and privilege restrictions
- Image inspection and runtime validation
- Targeted cleanup

## Implementation Flow

`Source → Dependency cache → Unit tests → JAR package → Runtime image → Security checks → Health validation`

## Repository Files

```text
docker/dockerfile-concepts/
├── README.md
├── Dockerfile
└── .dockerignore
```

## 1. Prepare the Application

The commands below assume that version `1.2.4` of the AWS Retail Store sample
application is already available:

```bash
cd ~/demo-docker-build/retail-store-sample-app-1.2.4/src/ui

pwd
ls -l Dockerfile pom.xml mvnw
```

Run every build command from the `src/ui` directory because it contains the
Dockerfile and application build context.

## 2. Optimized Multi-Stage Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

# ----------------------------
# Build and test stage
# ----------------------------
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS build

RUN dnf --setopt=install_weak_deps=False install -q -y \
    gzip \
    java-21-amazon-corretto-headless \
    tar \
    && dnf clean all

WORKDIR /workspace

COPY .mvn .mvn
COPY mvnw pom.xml ./

RUN chmod +x mvnw

RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw dependency:go-offline -B

COPY src ./src

RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw test -B && \
    ./mvnw package -B -DskipTests && \
    mv target/ui-0.0.1-SNAPSHOT.jar /app.jar

# ----------------------------
# Runtime stage
# ----------------------------
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS runtime

RUN dnf --setopt=install_weak_deps=False install -q -y \
    java-21-amazon-corretto-headless \
    shadow-utils \
    && dnf clean all \
    && dnf -q -y swap libcurl-minimal libcurl-full \
    && dnf -q -y swap curl-minimal curl-full \
    && dnf clean all

ARG APP_UID=10001
ARG APP_GID=10001

RUN groupadd --gid "${APP_GID}" appgroup && \
    useradd \
      --uid "${APP_UID}" \
      --gid "${APP_GID}" \
      --home-dir /app \
      --create-home \
      --shell /sbin/nologin \
      appuser

ENV JAVA_TOOL_OPTIONS="" \
    SPRING_PROFILES_ACTIVE="prod"

WORKDIR /app

COPY ATTRIBUTION.md LICENSES.md ./
COPY --from=build --chown=appuser:appgroup /app.jar ./app.jar

USER appuser:appgroup

EXPOSE 8080

HEALTHCHECK --interval=30s \
  --timeout=5s \
  --start-period=40s \
  --retries=3 \
  CMD curl --fail --silent http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

## 3. `.dockerignore`

Create `.dockerignore` beside the Dockerfile:

```dockerignore
.git
.github
.idea
.vscode

target/
*.log

.env
.env.*
!.env.example
*.pem
*.key
*.p12

docker-compose*.yml
chart/
scripts/
terraform/
kubernetes/
```

This reduces the build context and prevents local build outputs, credentials,
IDE settings, and unrelated project files from entering the image build.

## 4. Build the Image

```bash
export IMAGE_NAME="retail-ui"
export IMAGE_VERSION="9.0.0"

docker build --pull \
  --tag "${IMAGE_NAME}:${IMAGE_VERSION}" \
  .
```

Confirm the image:

```bash
docker image ls "${IMAGE_NAME}:${IMAGE_VERSION}"
docker history "${IMAGE_NAME}:${IMAGE_VERSION}"
```

## 5. Validate Docker Layer Caching

Run the same build again:

```bash
time docker build \
  --tag "${IMAGE_NAME}:${IMAGE_VERSION}" \
  .
```

Unchanged instructions should show `CACHED`. Maven dependencies are retained in
the BuildKit cache mount, reducing repeated downloads when source code changes.

Use a no-cache build only when specifically validating a clean build:

```bash
docker build --pull --no-cache \
  --tag "${IMAGE_NAME}:${IMAGE_VERSION}-no-cache" \
  .
```

## 6. Run with Runtime Restrictions

```bash
docker run -d \
  --name retail-ui \
  --memory=1g \
  --cpus=1.0 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=128m \
  --security-opt no-new-privileges:true \
  -p 8080:8080 \
  "${IMAGE_NAME}:${IMAGE_VERSION}"
```

These options limit CPU and memory usage, prevent privilege escalation, make
the root filesystem read-only, and provide a temporary writable `/tmp` area.

## 7. Test Application Health

```bash
docker ps
docker logs --tail 100 retail-ui
curl --fail http://localhost:8080/actuator/health
```

Expected health response:

```json
{"status":"UP"}
```

Inspect Docker's health status:

```bash
docker inspect \
  --format='Health={{.State.Health.Status}}' \
  retail-ui
```

The status may initially be `starting`; after the start period it should become
`healthy`.

## 8. Validate the Runtime Image

Confirm that the container runs as the expected non-root user:

```bash
docker exec retail-ui id
```

Confirm that Maven and application source code are absent from the runtime
image:

```bash
docker exec retail-ui sh -c \
  'command -v mvn || true; test ! -d /workspace && echo "Source absent"'
```

Inspect the configured user and entry point:

```bash
docker inspect \
  --format='User={{.Config.User}} Entrypoint={{json .Config.Entrypoint}}' \
  retail-ui
```

Expected user:

```text
appuser:appgroup
```

## Validation Checklist

| Validation | Status |
|---|---|
| Multi-stage image builds successfully | ✅ Completed |
| Maven unit tests pass during build | ✅ Completed|
| Rebuild reuses cached layers | ✅ Completed|
| Application health endpoint returns `UP` |✅ Completed |
| Docker reports the container as healthy | ✅ Completed |
| Container runs as a non-root user | ✅ Completed|
| Maven and source code are absent at runtime | ✅ Completed |
| Read-only and resource-restricted run succeeds | ✅ Completed |

Update each item to `✅ Completed` only after successfully executing and
validating it.

## My Enhancements

Compared with the course implementation, this version adds:

- Unit-test execution during the image build
- BuildKit caching for Maven dependencies
- An explicit non-root UID and GID
- A Spring Boot health check
- An exec-form Java entry point for correct signal handling
- CPU, memory, filesystem, and privilege restrictions
- Runtime validation of user identity and image contents
- Targeted cleanup instead of broad system pruning

## Troubleshooting

### Dockerfile not found

```bash
pwd
find ~ -type f -name Dockerfile 2>/dev/null
```

Run `docker build` from the application directory containing the Dockerfile.

### Build stops on a small EC2 instance

Check available resources:

```bash
free -h
df -h
docker system df
```

Java compilation may require more memory than a small burstable instance can
provide. Temporarily resize the EC2 instance, complete the build, and resize or
stop it afterward to control costs.

### Container is unhealthy

```bash
docker logs --tail 200 retail-ui
docker inspect \
  --format='{{json .State.Health}}' \
  retail-ui
curl -v http://localhost:8080/actuator/health
```

### Read-only filesystem error

If the application requires another writable runtime directory, add a narrowly
scoped `--tmpfs` or volume for that directory instead of removing `--read-only`.

## Cleanup

```bash
docker rm -f retail-ui
docker image rm "${IMAGE_NAME}:${IMAGE_VERSION}"
docker image rm "${IMAGE_NAME}:${IMAGE_VERSION}-no-cache" 2>/dev/null || true
```

Inspect build cache before removing unused entries:

```bash
docker system df
docker builder prune
```

Avoid `docker system prune -a --volumes -f` because it can delete unrelated
images, containers, networks, caches, and volumes.

## Credits and Attribution

This personal learning and portfolio implementation is based on concepts taught
in the Udemy course
[Ultimate DevOps Real-World Project Implementation on AWS](https://www.udemy.com/course/aws-eks-kubernetes-karpenter-devops-production/)
by StackSimplify.

The original retail application and course reference materials were provided by
StackSimplify. This repository documents my own Dockerfile improvements,
validation steps, troubleshooting experience, and implementation decisions.

