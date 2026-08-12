# Build and Push the Retail UI Docker Image

> Status: ✅ Completed  
> Image version: `2.0.0`  
> Registry: [Docker Hub – retail-store-sample-ui](https://hub.docker.com/r/sajanvethakumar/retail-store-sample-ui)

This exercise documents how I customized, built, tested, published, verified,
and cleaned up the Retail UI Docker image.

## Workflow

`Source download → UI customization → Docker build → Local test → Docker Hub push → Pull-and-run verification → Cleanup`

## 1. Download and Customize the Application

```bash
mkdir -p ~/demo-docker-build
cd ~/demo-docker-build

wget https://github.com/aws-containers/retail-store-sample-app/archive/refs/tags/v1.2.4.zip
unzip v1.2.4.zip

cd retail-store-sample-app-1.2.4/src/ui/src/main/resources/templates

sed -i.bak \
  's|Secret Shop</span>|Secret Shop - V2 Version</span>|' \
  home.html

grep -n "Secret Shop" home.html
```

The change adds a visible `V2 Version` label to the Retail UI homepage.

## 2. Configure and Build the Image

```bash
export DOCKERHUB_USERNAME="sajanvethakumar"
export IMAGE_NAME="retail-store-sample-ui"
export IMAGE_VERSION="2.0.0"

cd ~/demo-docker-build/retail-store-sample-app-1.2.4/src/ui
ls -l Dockerfile

docker build --pull \
  -t "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_VERSION}" \
  .
```

The build must be executed from the directory containing the `Dockerfile`.

## 3. Run and Test Locally

```bash
docker run -d \
  --name retail-ui \
  -p 8889:8080 \
  "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_VERSION}"

docker ps
docker logs --tail 100 retail-ui
curl --fail http://localhost:8889
```

Browser access:

```text
http://EC2-PUBLIC-IP:8889
```

The EC2 security group must allow inbound TCP port `8889` from the tester's IP
address.

## 4. Publish to Docker Hub

The Docker Hub repository was created under the `sajanvethakumar` namespace.
A personal access token with **Read & Write** permission was used for the push.

```bash
read -s -p "Paste Docker Hub token: " DOCKERHUB_TOKEN
echo

printf '%s' "$DOCKERHUB_TOKEN" | docker login \
  --username "$DOCKERHUB_USERNAME" \
  --password-stdin

docker push \
  "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_VERSION}"
```

Never commit passwords, tokens, AWS credentials, or Docker configuration files.

## 5. Verify the Published Image

The local copy was removed before pulling and testing the published image. This
confirmed that the Docker Hub artifact works independently of the original build.

```bash
docker rm -f retail-ui
docker image rm \
  "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_VERSION}"

docker pull \
  "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_VERSION}"

docker run -d \
  --name retail-ui-verification \
  -p 8889:8080 \
  "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_VERSION}"

curl --fail http://localhost:8889
```

## Validation Results

- ✅ Retail UI source downloaded and customized
- ✅ Versioned Docker image built successfully
- ✅ Container and V2 homepage tested on EC2
- ✅ Image pushed to Docker Hub
- ✅ Published image pulled and tested independently
- ✅ Test container and local image removed from EC2

## My Enhancements

- Added a customized V2 homepage
- Used consistent image naming and semantic versioning
- Used token-based Docker Hub authentication
- Added local HTTP validation before publication
- Added independent pull-and-run verification
- Documented common build, networking, and authorization issues

## Troubleshooting

```bash
# Dockerfile not found
find ~ -type f -name Dockerfile 2>/dev/null

# Container or application issue
docker ps -a
docker logs --tail 100 retail-ui
sudo ss -lntp | grep 8889
curl -v http://localhost:8889
```

If Docker Hub returns `access token has insufficient scopes`, create or use a
token with **Read & Write** permission and log in again.

## Cleanup

```bash
docker rm -f retail-ui-verification
docker image rm \
  "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_VERSION}"
docker logout
```

The published image remains available from Docker Hub:

```bash
docker pull sajanvethakumar/retail-store-sample-ui:2.0.0
```

## Credits and Attribution

This hands-on exercise is based on the Udemy course
[Ultimate DevOps Real-World Project Implementation on AWS](https://www.udemy.com/course/aws-eks-kubernetes-karpenter-devops-production/)
by StackSimplify.

The original application and reference materials were provided by StackSimplify.
This repository documents my own customization, build, deployment, validation,
troubleshooting, publication, and cleanup work.

