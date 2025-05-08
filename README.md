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
docker-compose/nginx/index.html에 있는 메세지가 보이면 성공입니다.(새로고침 후 확인)

정리하기

```bash
sudo docker-compose down
```

### 3. Github Actions로 커스텀 이미지 빌드

docker cli를 사용하지 않고 github actions로 이미지를 빌드하고 푸시합니다. 단, docker registry가 준비되어있어야 합니다. 실습을 하기 전에, https://hub.docker.com/ 에 가입하셔서 public docker registry를 만들어주시기 바랍니다.

branch를 별도로 만들어서 작업을 진행합니다.

```bash
BRANCH="your_branch"
git checkout -b $BRANCH
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
git add .
git commit -m "update index.html"
git push
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
docker-compose/nginx/index.html에 있는 메세지가 보이면 성공입니다.(새로고침 후 확인)

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
git checkout -b $BRANCH && git push --set-upstream origin $BRANCH
```

applicationset.yaml의 spec.generators.git.revision을 배포할 branch로 변경합니다.

```bash
sed -i "s/revision: main/revision: $BRANCH/" applicationset.yaml
```

applicationset.yaml의 template.spec.destination.namespace를 배포할 namespace로 변경합니다.

```bash
NAMESPACE="your_namespace"
sed -i "s/namespace: default/namespace: $NAMESPACE/" applicationset.yaml
```

k8s에 ArgoCD가 설치되어있고 current context가 해당 클러스터를 가리키고 있는 경우, 아래 명령어로 ArgoCD에 애플리케이션을 배포할 수 있습니다.

```bash
kubectl apply -f applicationset.yaml
```

ArgoCD에 애플리케이션이 배포되었습니다. ArgoCD 웹페이지에서도 확인가능하며 kubectl 명령어로도 확인가능합니다.

```bash
kubectl get applicationset
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
kubectl delete -f applicationset.yaml
# kubectl delete namespace $NAMESPACE
```
