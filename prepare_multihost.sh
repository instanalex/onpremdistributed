#!/bin/bash

AGENT_KEY=
MAIN_IP=
FILLER_IP=
APPDATA_PROCESSOR_IP=


mkdir workdir
cd workdir

if ([ ! "$AGENT_KEY" ] || [ ! "$MAIN_IP" ] || [ ! "$FILLER_IP" ] || [ ! "$APPDATA_PROCESSOR_IP" ]); then
  echo "please edit the current file and enter appropriate values"
  exit 1
 fi
#echo "enter the main machine IP"
#read MAIN_IP
#echo "enter your agent key"
#read AGENT_KEY
#echo "enter filler machine IP"
#read FILLER_IP
#echo "enter appdata-processor machine IP"
#read APPDATA_PROCESSOR_IP

#elastic section
echo "grab original config from elastic"
	docker cp instana-elastic:/opt/instana/instana-elasticsearch/elasticsearch.yml_tmpl .
echo "change settings"
	sed -i 's/network.publish_host: _local_/network.publish_host: 0.0.0.0/' elasticsearch.yml_tmpl
	sed -i 's/network.bind_host: _local_/network.bind_host: 0.0.0.0/' elasticsearch.yml_tmpl
echo "reinject settings to elastic"
	docker cp ./elasticsearch.yml_tmpl instana-elastic:/opt/instana/instana-elasticsearch/elasticsearch.yml_tmpl
echo "restart elastic"
	docker restart instana-elastic

#kafka section
echo "grab original config from kafka"
	docker cp instana-kafka:/opt/instana/instana-kafka/kafka.properties_tmpl .
echo "change settings"
	sed -i 's/listeners=PLAINTEXT:\/\/127.0.0.1:9092/listeners=INTERNAL:\/\/127.0.0.1:9092,EXTERNAL:\/\/'$MAIN_IP':29092/' kafka.properties_tmpl
	          listeners=PLAINTEXT://127.0.0.1:9092
	sed -i 's/advertised.listeners=PLAINTEXT:\/\/127.0.0.1:9092/advertised.listeners=INTERNAL:\/\/127.0.0.1:9092,EXTERNAL:\/\/'$MAIN_IP':29092/' kafka.properties_tmpl
	echo listener.security.protocol.map=INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT >>kafka.properties_tmpl
	echo inter.broker.listener.name=INTERNAL >>kafka.properties_tmpl
echo "reinject settings to kafka"
	docker cp ./kafka.properties_tmpl instana-kafka:/opt/instana/instana-kafka/kafka.properties_tmpl
echo "restart kafka"
	docker restart instana-kafka

#corking directory prep
echo "prepare working dir"
	mkdir -p .instana/etc/instana/appdata-processor/
	mkdir -p .instana/etc/instana/filler/
	mkdir -p cert

#config file section
echo "retreive appdata-processor & filler original configs"
	cp /root/.instana/etc/instana/appdata-processor/* .instana/etc/instana/appdata-processor/
	cp /root/.instana/etc/instana/filler/* .instana/etc/instana/filler
	cp /root/cert/* ./cert
echo "chage settings"
	sed -i 's/127.0.0.1/'$MAIN_IP'/' .instana/etc/instana/appdata-processor/config.yaml #for both config files
	sed -i 's/9092/29092/' .instana/etc/instana/appdata-processor/config.yaml
	sed -i 's/127.0.0.1/'$MAIN_IP'/' .instana/etc/instana/filler/config.yaml
	sed -i 's/9092/29092/' .instana/etc/instana/filler/config.yaml

echo "stopping local appdata-processor and filler"
	docker stop instana-appdata-processor
	docker stop instana-filler

echo "create filler and appdata processor install files"
#create auto install shell
cat >./install_appdata_processor.sh <<EOF
#install_appdata_processor.sh
#!/bin/bash
docker login containers.instana.io -u _ -p $AGENT_KEY
docker run \
--name=instana-appdata-processor \
--hostname=175-on-prem \
--env=COMPONENT_ID=appdata-processor \
--env=COMPONENT_LOGLEVEL=Info \
--env='HEAP_OPTS=-Xss265k -Xms13140M -Xmx13140M' \
--env=IMPORT_TLS_PATH=/etc/secrets \
--env=GROUP_ID=998 \
--env=USER_ID=999 \
--env=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
--env=JAVA_HOME=/opt/instana/runtimes/jdk11 \
--env=COM_INSTANA_COMMIT_ID=7ca7493792 \
--env=COM_INSTANA_BRANCH=release-175 \
--env=COM_INSTANA_IMAGE_TAG=2.175.122-0 \
--volume=/root/cert/tls.key:/etc/secrets/tls.key:ro,z \
--volume=/root/cert/tls.crt:/etc/secrets/tls.crt:ro,z \
--volume=/root/.instana/etc/instana/appdata-processor/config.yaml:/etc/instana/appdata-processor/config.yaml:ro,z \
--volume=/root/.instana/etc/instana/appdata-processor/logback.xml:/etc/instana/appdata-processor/logback.xml:ro,z \
--volume=/mnt/logs/instana/appdata-processor:/var/log/instana/appdata-processor:z \
--network=host \
--restart=on-failure:3 \
--label com.instana.branch="release-175" \
--label group="service" \
--label com.instana.commit.id="7ca7493792" \
--label application="instana" \
--label version="175" \
--label com.instana.image.tag="2.175.122-0" \
--label component="instana-appdata-processor" \
--detach=true \
containers.instana.io/instana/release/product/appdata-processor:2.175.122-0 \
/usr/bin/instana-appdata-processor
EOF


cat >./install_filler.sh <<EOF
#install_filler.sh
#!/bin/bash
docker login containers.instana.io -u _ -p $AGENT_KEY
docker run \
--name=instana-filler \
--hostname=175-on-prem \
--env=COMPONENT_ID=filler \
--env=COMPONENT_LOGLEVEL=Info \
--env='HEAP_OPTS=-Xss265k -Xms13140M -Xmx13140M' \
--env=IMPORT_TLS_PATH=/etc/secrets \
--env=GROUP_ID=998 \
--env=USER_ID=999 \
--env=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
--env=JAVA_HOME=/opt/instana/runtimes/jdk11 \
--env=COM_INSTANA_COMMIT_ID=7ca7493792 \
--env=COM_INSTANA_BRANCH=release-175 \
--env=COM_INSTANA_IMAGE_TAG=2.175.122-0 \
--volume=/root/cert/tls.key:/etc/secrets/tls.key:ro,z \
--volume=/root/cert/tls.crt:/etc/secrets/tls.crt:ro,z \
--volume=/root/.instana/etc/instana/filler/config.yaml:/etc/instana/filler/config.yaml:ro,z \
--volume=/root/.instana/etc/instana/filler/logback.xml:/etc/instana/filler/logback.xml:ro,z \
--volume=/mnt/logs/instana/filler:/var/log/instana/filler:z \
--network=host \
--restart=on-failure:3 \
--label com.instana.branch="release-175" \
--label group="service" \
--label component="instana-filler" \
--label com.instana.commit.id="7ca7493792" \
--label application="instana" \
--label version="175" \
--label com.instana.image.tag="2.175.122-0" \
--detach=true \
containers.instana.io/instana/release/product/filler:2.175.122-0 \
/usr/bin/instana-filler
EOF

chmod +x install_filler.sh install_appdata_processor.sh
echo "package filler and appdata-processor configs"
	tar -czf appdata-processor.tar.gz .instana/etc/instana/appdata-processor/ cert/ install_appdata_processor.sh
	tar -czf filler.tar.gz .instana/etc/instana/filler/ cert/ install_filler.sh

echo "connect to filler machine and install component" 
	scp filler.tar.gz $FILLER_IP:/root
	ssh $FILLER_IP 'tar -xzf /root/filler.tar.gz && /root/install_filler.sh'

echo "connect to appdata processor machine and install component"
	scp appdata-processor.tar.gz $APPDATA_PROCESSOR_IP:/root
	ssh $APPDATA_PROCESSOR_IP 'tar -xzf /root/appdata-processor.tar.gz && /root/install_appdata_processor.sh'

#echo "tranfer filler.tar.gz on filler machine and extract file before running provided install shell"
#echo "transfer appdata-processor.tar.gz to appdata machine and extract file before running provided install shell"
