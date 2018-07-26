#!/bin/bash

#######下面不同jenkins项目需要进行不同的配置########
profile=prod #当前环境,开发dev,测试test,线上prod，需要配置
project_name=app-auth-access  #工程名称，唯一，需要维护在wiki上http://172.30.144.8:8090/pages/viewpage.action?pageId=1116412，需要配置修改

target_ips='192.168.42.47 192.168.42.25' #目标集群的ip，'127.0.0.1 127.0.0.2' 需要配置
target_passwds='xxxxxx xxxxxx' #目标集群的机器的密码，特殊符号需要转义 '123 456'数量需要和ips保持一致 需要配置
#######配置完成##########################

target_dir=/root/service/$project_name  #目标集群机器的路径
jump_dir=/opt/user/release #跳板机存放jar包和脚本的目录
app_name=${jar_url##*/} #获取jar包名称
jvm_param='-Xms1536m -Xmx1536m -Xmn700m -XX:PermSize=100m -XX:MaxPermSize=100m -XX:MetaspaceSize=100m  -Xloggc:/home/logs/appauth/gc.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps'

echo "准备下载jar包，名字："${jar_url##*/}
rm ${jar_url##*/}  #删除目录下的jar包，避免jar包为release时jenkins不覆盖老包的问题
wget $jar_url   #根据jar包地址下载

echo "进入跳板机创建目录"
expect -c "
	spawn ssh release@1.1.1.1
	expect {
		\"*assword\" {set timeout 300; send \"passwd\!\r\";}
		\"yes/no\" {send \"yes\r\"; exp_continue;}
	}
	expect "~$"
	send \"mkdir -p $jump_dir/$project_name\r\"
	expect "~$"
	send \"exit \r\"
	expect eof
"

echo "拷贝jar包到跳板机"
expect -c "
	spawn scp $app_name release@1.1.1.1:$jump_dir/$project_name
	expect  {
	        \"*assword\" {set timeout 300; send \"passwd\!\r\";} 
	        \"yes/no\" {send \"yes\r\";exp_continue}
	}
	expect eof
"

echo "进入跳板机执行脚本"
expect -c "
	spawn ssh release@1.1.1.1
	expect {
		\"*assword\" {set timeout 300; send \"passwd\!\r\";}
		\"yes/no\" {send \"yes\r\"; exp_continue;}
	}
	expect "~$"
	send \"bash $jump_dir/spring-boot-start.sh -i '$target_ips' -p '$target_passwds' -s '$jump_dir/$project_name/$app_name' --a '$app_name' -d '$target_dir' -e '$profile' -n '$project_name' -j '$jvm_param'\r\"
	expect "~$"
	send \"exit \r\"
	expect eof
"
