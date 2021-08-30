## POD 생성
**POD 생성은 1) Command 2) YAML File 2가지 방법으로 가능**

> **TIP** `alias kc='kubectl'`을 입력하면 편하게 명령어를 입력할 수 있습니다.

**1) Command 이용**
```
spkr@erdia22:~/02.k8s_code$ kc create deployment nginx01 --image=nginx
deployment.apps/nginx01 created
```

**생성된 POD 확인**
```
spkr@erdia22:~/02.k8s_code$ kc get pod
NAME                       READY   STATUS    RESTARTS   AGE
nginx01-6bdf767788-shs7g   1/1     Running   0          21s
```

**IP 등 상세 정보 확인은 -o wide 추가**
```
spkr@erdia22:~/02.k8s_code$ kc get pod -o wide
NAME                       READY   STATUS    RESTARTS   AGE    IP             NODE    NOMINATED NODE   READINESS GATES
nginx01-6bdf767788-shs7g   1/1     Running   0          108s   10.10.100.13   dia03   <none>           <none>
```

축하합니다 ^^ 첫번째 POD 생성을 완료 하였습니다. 

**2) YAML 파일 이용**

- [Deploy YAML 파일 예제](05.Deployment/centOS-deploy.yml)

```
vi centOS-deploy.yml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: centos
  labels:
    app: centos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: centos  # POD label과 일치
  template:    
    metadata:
      labels:
        app: centos # Selector label과 일치
    spec:
      containers:
      - name: centos
        image: centos:7.5.1804
        command:
        - "/bin/sh"
        - "-c"
        - "while true; do date >> /data/pod-out.txt; cd /data; sync; sync; sleep 10; done"

spkr@erdia22:~/02.k8s_code/04.Deploy$ kc apply -f centos-deploy.yml
deployment.apps/centos created
spkr@erdia22:~/02.k8s_code/04.Deploy$ kc get pod
NAME                                  READY   STATUS    RESTARTS   AGE
centos-859c64885-s9l8d                1/1     Running   0          7s
date-mirror-deploy-7b987cd5d7-d7sm8   1/1     Running   0          5m18s
nginx01-6bdf767788-shs7g              1/1     Running   0          9m11s
```

## POD 접속 (like SSH)

exec 명령어 사용 
```
spkr@erdia22:~/02.k8s_code/04.Deploy$ kc get pod -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP             NODE    NOMINATED NODE   READINESS GATES
nginx01-6bdf767788-shs7g   1/1     Running   0          52m   10.10.100.13   dia03   <none>           <none>

spkr@erdia22:~/02.k8s_code/04.Deploy$ kc exec -it nginx01-6bdf767788-shs7g -- bash
root@nginx01-6bdf767788-shs7g:/# hostname
nginx01-6bdf767788-shs7g
```
