#!/bin/sh

echo -----------------------------------------parameter define -----------------------------------------

project_name=oss-gateway    #工程名字，需配置,维护在wiki上http://172.30.144.8:8090/pages/viewpage.action?pageId=1116412


tag=$BUILD_TAG      #镜像标签，自动生成，无需手动配置
sudo docker rmi aigpu.xxxxxxx.com:30143/library/$project_name
set -e
echo $(pwd)
echo "FROM java:8
VOLUME /tmp
ADD $project_name/target/*.jar app.jar
ENTRYPOINT [\"java\",\"-Djava.security.egd=file:/dev/./urandom\",\"-jar\",\"/app.jar\"]" > Dockerfile


echo -------------build image and push it to harbor ---------------------
sudo docker build -t aigpu.xxxxx.com:30143/library/$project_name:$tag -f Dockerfile --rm=true .

sudo docker login -u admin -p Cd12345 aigpu.xxxxx.com:30143

sudo docker push aigpu.xxxxxx.com:30143/library/$project_name:$tag

echo images_url=aigpu.xxxxxxx.com:30143/library/$project_name:$tag > $project_name.txt

echo This is imagesUrl
echo '********************************************************************************************************************'
echo
echo aigpu.xxxxxxx.com:30143/library/$project_name:$tag
echo 
echo '********************************************************************************************************************'
