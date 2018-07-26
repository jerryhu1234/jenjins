#!/bin/bash

echo -----------------------------------------parameter define -----------------------------------------

project_name=oss-gateway        #工程名称，唯一，需配置
port=8888                    #容器端口，注意与配置选择的profile对应，需配置
profile=dev                   #生效的配置文件（spring.profiles.active），需配置
podNum=1                   #需要启动节点数量，需配置
logPath=/var/log/xxxxxx/oss-gateway                   #日志路径，需配置

tag=$BUILD_TAG        #镜像标签，自动生成，无需手动配置
#################以下参数由k8s运维人员配置##################
k8s_master_ip='192.168.42.8'
k8s_master_pwd='passwd'
servicePort=9999

target_dir=/root/service/$project_name     #k8s Master 存放yaml的目录
jump_dir=/opt/user/release/k8s                 #跳板机存放yaml文件的上级目录


sevice_temp="apiVersion: v1
kind: Namespace
metadata: 
  name: $profile
  labels:
    name: $profile
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: $profile
  name: $project_name-app
  labels:
    app: $project_name-app
spec:
  replicas: $podNum
  selector:
    matchLabels:
      app: $project_name-app
#  minReadySeconds: 60     #滚动升级时60s后认为该pod就绪
  strategy:
    rollingUpdate:  ##由于replicas为3,则整个升级,pod个数在2-4个之间
      maxSurge: 1      #滚动升级时会先启动1个pod
      maxUnavailable: 1 #滚动升级时允许的最大Unavailable的pod个数
  template:
    metadata:
      labels:
        app: $project_name-app
    spec:
      terminationGracePeriodSeconds: 60 ##k8s将会给应用发送SIGTERM信号，可以用来正确、优雅地关闭应用,默认为30秒
      containers:
      - name: container
        image: aigpu.xxxxxx.com:30143/library/$project_name:$tag
        imagePullPolicy: IfNotPresent
        resources:
          # keep request = limit to keep this container in guaranteed class
          limits:
            cpu: 1000m
            memory: 2000Mi
        env:
          - name: spring.profiles.active
            value: $profile
        ports:
          - containerPort: $port
        volumeMounts:
          - name: app-logs
            mountPath: $logPath
      volumes:
        - name: app-logs
          hostPath:  
            path: $logPath
---
apiVersion: v1
kind: Service
metadata:
  namespace: $profile
  name: ${project_name}-service
  labels:
    app: ${project_name}-app
spec:
  ports:
  - port: $servicePort
    targetPort: $port
    nodePort: 30001
    protocol: TCP
  type: NodePort
  selector:
    app: ${project_name}-app"

mkdir -p $jump_dir/$project_name
cd $jump_dir/$project_name/
echo "$sevice_temp" > ${project_name}-app-s-${profile}.yaml

echo "进入k8s-master创建目录"
expect -c "
	spawn ssh root@${k8s_master_ip}
	expect {
		\"*assword\" {set timeout 300; send \"${k8s_master_pwd}\r\";}
		\"yes/no\" {send \"yes\r\"; exp_continue;}
	}
	expect "~$"
	send \"mkdir -p $target_dir\r\"
	expect "*$"
	send \"exit \r\"
	expect eof
"
echo "拷贝yaml文件到k8s-master"
expect -c "
	spawn scp ${project_name}-app-s-${profile}.yaml root@${k8s_master_ip}:$target_dir
	expect  {
	        \"*assword\" {set timeout 300; send \"${k8s_master_pwd}\r\";} 
	        \"yes/no\" {send \"yes\r\";exp_continue}
	}
	expect eof
"

echo "创建ReplicationController和service"
expect -c "
	spawn ssh root@${k8s_master_ip}
	expect {
		\"*assword\" {set timeout 300; send \"${k8s_master_pwd}\r\";}
		\"yes/no\" {send \"yes\r\"; exp_continue;}
	}
	expect "~$"
	send \"kubectl apply -f $target_dir/${project_name}-app-s-${profile}.yaml\r\"
	expect "*$"
	send \"exit \r\"
	expect eof
"
