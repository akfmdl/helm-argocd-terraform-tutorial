# helm-argocd-tutorial

Docker, Docker Compose, Github Actions, Helm, ArgoCD, Terraform을 경험해볼 수 있는 튜토리얼입니다.

## Prerequisites

* docker, docker-compose
* k3s
* kubectl
* k9s
* helm
* argocd
* terraform

위 패키지들을 설치하는 스크립트는 [install.sh](./install.sh)에 있습니다. 단, 리눅스 기준으로 작성되어 있습니다.

## 설치 방법

```bash
./install.sh
```

## 튜토리얼

### 1. Docker Compose로 간단한 애플리케이션 배포

```bash
cd docker/nginx
sudo docker-compose up -d
```

http://localhost:8080 에 접속하면 nginx 페이지를 확인할 수 있습니다.

정리하기

```bash
sudo docker-compose down
```

### 2. Docker cli로 커스텀 이미지 빌드

```bash
cd docker/nginx
sudo docker build -t nginx:custom .
```

docker-compose.yaml 파일에 있는 이미지 이름을 변경

```yaml
image: nginx:custom
```

docker registry가 준비되어있지 않을 경우, push하지 않아도 됩니다.

배포

```bash
sudo docker-compose up -d
```

http://localhost:8080 에 접속하면 nginx 페이지를 확인할 수 있습니다.
docker/nginx/index.html에 있는 메세지가 보이면 성공입니다.(새로고침 후 확인)

정리하기

```bash
sudo docker-compose down
```

### 3. Github Actions로 커스텀 이미지 빌드

docker cli를 사용하지 않고 github actions로 이미지를 빌드하고 푸시합니다. 단, docker registry가 준비되어있어야 합니다. 실습을 하기 전에, https://hub.docker.com/ 에 가입하셔서 public docker registry를 만들어주시기 바랍니다.

branch를 별도로 만들어서 작업을 진행합니다.

```bash
BRANCH="your_branch"
git checkout -b $BRANCH && git push origin $BRANCH --force
```

github actions에서 사용할 시크릿 변수들을 github 저장소 -> Settings -> Secrets and variables -> Actions -> New repository secret 에 추가합니다.

```bash
REGISTRY_URL="docker.io"
REGISTRY_USERNAME="개인 dockerhub 계정 이름(예: goranidocker)"
REGISTRY_PASSWORD="개인 dockerhub 계정 비밀번호 or token"
```

github actions의 workerflow 파일에서 push할 target branch명을 변경합니다.

```yaml
on:
  push:
    branches:
      - $BRANCH
```

github actions의 workerflow 파일에서 이미지 이름을 변경합니다.
<개인 dockerhub 계정 이름>/<이미지 이름> 형식으로 변경합니다.

```yaml
env:
  IMAGE_NAME: <개인 dockerhub 계정 이름>/nginx
```

docker/nginx/index.html 파일의 내용을 변경하고 commit 후 push합니다.

```bash
<!DOCTYPE html>
<html>

<head>
    <title>Welcome</title>
</head>

<body>
    <h1>Welcome to Github Actions!</h1>
    <p>This is a custom nginx container built by github actions.</p>
</body>

</html>
```

```bash
git add docker/nginx/index.html
git commit -m "update index.html"
git push origin $BRANCH --force
```

이제 github actions가 자동으로 이미지를 빌드하고 푸시합니다.
완료되면 docker hub에 가서 이미지가 잘 빌드되었는지 확인해보시기 바랍니다.

docker-compose.yaml 파일에 있는 이미지 이름을 변경

```yaml
image: <개인 dockerhub 계정 이름>/nginx:latest
```

배포

```bash
cd docker/nginx
sudo docker-compose up -d
```

http://localhost:8080 에 접속하면 nginx 페이지를 확인할 수 있습니다.
docker/nginx/index.html에 있는 메세지가 보이면 성공입니다.(새로고침 후 확인)

정리하기

```bash
sudo docker-compose down
```

test 했던 브랜치를 삭제합니다.

```bash
git checkout main
git branch -d $BRANCH
```

### 4. Helm으로 애플리케이션 배포

helm을 사용하여 애플리케이션을 배포합니다.

```bash
NAMESPACE="your_namespace"
helm upgrade --install nginx-chart charts/example -n $NAMESPACE --create-namespace
```

NodePort 타입의 서비스가 생성되었습니다. 포트번호를 확인합니다.

```bash
NODE_PORT=$(kubectl get svc nginx-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
echo $NODE_PORT
echo "http://localhost:$NODE_PORT"
```
http://localhost:$NODE_PORT 에 접속하면 nginx 페이지를 확인할 수 있습니다.

정리하기

```bash
helm uninstall nginx-chart -n $NAMESPACE
kubectl delete namespace $NAMESPACE
```

### 5. ArgoCD로 애플리케이션 배포

branch를 별도로 만들어서 작업을 진행합니다.

```bash
BRANCH="your_branch"
git checkout -b $BRANCH && git push origin $BRANCH --force
```

applicationset.yaml의 spec.source.targetRevision을 배포할 branch로 변경합니다.

```bash
sed -i "s/targetRevision: main/targetRevision: $BRANCH/" applicationset.yaml
```

applicationset.yaml의 template.spec.destination.namespace를 배포할 namespace로 변경합니다.

```bash
NAMESPACE="your_namespace"
sed -i "s/namespace: default/namespace: $NAMESPACE/" applicationset.yaml
```

k8s에 ArgoCD가 설치되어있고 current context가 해당 클러스터를 가리키고 있는 경우, 아래 명령어로 ArgoCD에 애플리케이션을 배포할 수 있습니다.

```bash
ARGOCD_NAMESPACE="argocd가 설치된 namespace"
kubectl apply -f applicationset.yaml -n $ARGOCD_NAMESPACE
```

ArgoCD에 애플리케이션이 배포되었습니다. ArgoCD 웹페이지에서도 확인가능하며 kubectl 명령어로도 확인가능합니다.

```bash
kubectl get applicationset -n $ARGOCD_NAMESPACE
```

NodePort 타입의 서비스가 생성되었습니다. 포트번호를 확인합니다.

```bash
NODE_PORT=$(kubectl get svc nginx-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
echo $NODE_PORT
echo "http://localhost:$NODE_PORT"
```

http://localhost:$NODE_PORT 에 접속하면 nginx 페이지를 확인할 수 있습니다.

nginx content를 변경하고 commit 후 push합니다. charts/example/values.yaml 파일의 content를 변경합니다.

```yaml
content: This will be changed by ArgoCD
```

```bash
git add charts/example/values.yaml
git commit -m "update nginx content"
git push origin $BRANCH --force
```

ArgoCD는 변경사항을 자동으로 감지하고 배포합니다. 잠시 후에 새로운 pod이 배포되면서 변경사항이 적용됩니다. 바로 적용하고 싶으실 경우, ArgoCD 웹페이지에서 Refresh 버튼을 눌러주시면 됩니다.

http://localhost:$NODE_PORT 에 접속해서 위 내용이 보이면 성공입니다.

정리하기

```bash
kubectl delete -f applicationset.yaml -n $ARGOCD_NAMESPACE
kubectl delete namespace $NAMESPACE
```

test 했던 브랜치를 삭제합니다.

```bash
git checkout main
git branch -d $BRANCH
```

### 보너스 - Github Actions workflow에 Self-hoated runner 적용 + Harbor Private Repository 사용

https://github.com/akfmdl/mlops-lifecycle.git 레포지토리에 있는 mlops-platform helm chart를 사용하여 Self-hoated runner를 설치해줍니다. 이 helm chart에는 불필요한 sub chart들이 많으니 charts/mlops-platform/Chart.yaml 파일에서 harbar, gha-runner-scale-set-controller, gha-runner-scale-set를 제외한 나머지 sub chart들을 모두 주석처리합니다.

그리고 아래 명령어를 실행하세요.

```bash
helm dependency update charts/mlops-platform
```

helm chart를 설치할 namespace를 생성합니다. mlops-platform helm chart는 기본적으로 mlops-platform namespace를 사용합니다. 다른 namespace를 사용하고 싶으실 경우 values.yaml 모든 namespace관련 내용을 변경해주시기 바랍니다.

```bash
NAMESPACE="mlops-platform"
kubectl create namespace $NAMESPACE
```

Github actions에서 사용할 토큰을 생성합니다.
https://github.com/settings/tokens 에 접속하여 Personal access tokens (classic)을 생성합니다.

필요 권한:
- repo: 권한 전체

gha-runner-scale-set에서 사용될 github credential secret을 생성합니다.
- username: github 사용자 이름
- email: github 사용자 이메일
- token: github 토큰

```bash
kubectl create secret generic github-credential \
  --from-literal=github_username=<github_username> \
  --from-literal=github_email=<github_email> \
  --from-literal=github_token=<github_token> \
  -n $NAMESPACE
```

charts/mlops-platform/values.yaml 파일에 아래 내용을 수정해주시기 바랍니다.
* githubConfigUrl: 본인의 github 레포지토리 url
* runnerScaleSetName: github actions runner의 이름이 됩니다. 원하는 이름으로 수정하셔도 됩니다.

```yaml
gha-runner-scale-set:
  githubConfigUrl: <github 레포지토리 url>
  runnerScaleSetName: <runner의 이름>
  githubConfigSecret: github-credential
```

위 runner 이름을 workflow에 적용합니다.

```yaml
jobs:
  build:
    runs-on: <runner의 이름>
```

이제 아래 설치 명령어를 실행하세요.

```bash
helm upgrade --install gha-runner-scale-set charts/mlops-platform -n $NAMESPACE --create-namespace
```

runner-scale-set-listener가 잘 생성되었는지 확인합니다. 이 pod은 controller에서 생성된 runner를 감지하고 할당하는 역할을 합니다. github actions에서 이벤트가 발생할 경우, 이 pod이 이벤트를 감지하고 runner를 자동으로 할당합니다.

```bash
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=runner-scale-set-listener
```

harbor도 잘 생성되었는지 확인합니다. harbor는 NodePort 타입의 서비스로 생성되었습니다.

```bash
NODE_PORT=$(kubectl get svc harbor -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
echo $NODE_PORT
echo "http://localhost:$NODE_PORT"
```
http://localhost:$NODE_PORT 에 접속하면 harbor에 접속할 수 있습니다. 여기서 github actions에서 push할 public 모드로 project를 생성합니다.

```yaml
env:
  IMAGE_NAME: <project 이름>/<이미지 이름>
```

github actions에서 사용할 시크릿 변수들을 github 저장소 -> Settings -> Secrets and variables -> Actions -> New repository secret 에 추가했던 변수들을 아래와 같이 수정합니다.

```bash
REGISTRY_URL="harbor.mlops-platform.svc.cluster.local"
REGISTRY_USERNAME="admin"
REGISTRY_PASSWORD="admin"
```

이제 모든 준비가 끝났습니다. 이제 본인의 github 레포지토리에서 github actions를 테스트해보세요.

이후에 발생하는 일
- runner-scale-set-controller가 자동으로 runner를 생성합니다.
- runner-scale-set-listener가 자동으로 runner를 감지하고 할당합니다.
- harbor private repository에 이미지가 푸시됩니다.