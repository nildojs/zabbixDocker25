###--INICIO--###
#!/bin/bash

# Criar estrutura de pastas para os conteineres do Zabbix
mkdir /docker \
/docker/zabbix \
/docker/zabbix/mysql \
/docker/zabbix/backend \
/docker/zabbix/backend/usr \
/docker/zabbix/backend/var \
/docker/zabbix/backend/var/snmptraps \
/docker/zabbix/backend/var/export \
/docker/zabbix/frontend \
/docker/zabbix/frontend/nginx \
/docker/zabbix/frontend/modules \
/docker/grafana/ \
/docker/grafana/lib

# Dar permissao na pasta dos volumes
chmod -R 777 /docker

# Criação do arquivo docker-compose-zabbix.yaml
cat <<EOF > /docker/docker-compose-zabbix.yaml

networks:
  zbx:
    ipam:
      config:
        - subnet: 172.50.0.0/24

services:
  mysql-server:
    container_name: mysql-server
    image: ubuntu/mysql:latest
    environment:
      - MYSQL_USER=zabbix
      - MYSQL_DATABASE=zabbix
      - MYSQL_PASSWORD=password
      - MYSQL_ROOT_PASSWORD=password
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - type: bind
        source: /docker/zabbix/mysql
        target: /var/lib/mysql
    cap_add: # evita o erro mBind Operation not found
      - SYS_NICE
    command: ['mysqld', '--character-set-server=utf8mb4', '--collation-server=utf8mb4_bin', '--authentication_policy=mysql_native_password']
    restart: always
    networks:
      zbx:
        ipv4_address: 172.50.0.2

  zabbix-server-mysql:
    container_name: zabbix-server
    image: zabbix/zabbix-server-mysql:ubuntu-latest
    ports:
      - 10051:10051
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - type: bind
        source: /docker/zabbix/backend/usr
        target: /usr/lib/zabbix
      - type: bind
        source: /docker/zabbix/backend/var
        target: /var/lib/zabbix
      - type: bind
        source: /docker/zabbix/backend/var/snmptraps
        target: /var/lib/zabbix/snmptraps
      - type: bind
        source: /docker/zabbix/backend/var/export
        target: /var/lib/zabbix/export
      - type: bind
        source: /var/run/docker.sock
        target: /var/run/docker.sock
    environment:
      - ZBX_CACHESIZE=4096M
      - ZBX_HISTORYCACHESIZE=1024M
      - ZBX_HISTORYINDEXCACHESIZE=1024M
      - ZBX_TRENDCACHESIZE=1024M
      - ZBX_VALUECACHESIZE=1024M
      - DB_SERVER_HOST=mysql-server
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=password
      - MYSQL_ROOT_PASSWORD=password
    depends_on:
      - mysql-server
    restart: always
    networks:
      zbx:
        ipv4_address: 172.50.0.4

  zabbix-web-nginx-mysql:
    container_name: zabbix-web
    image: zabbix/zabbix-web-nginx-mysql:ubuntu-latest
    ports:
      - 8080:8080
      - 8443:443
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - type: bind
        source: /docker/zabbix/frontend/nginx
        target: /etc/ssl/nginx
      - type: bind
        source: /docker/zabbix/frontend
        target: /usr/share/zabbix/modules
    environment:
      - ZBX_SERVER_HOST=zabbix-server-mysql
      - DB_SERVER_HOST=mysql-server
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=password
      - MYSQL_ROOT_PASSWORD=password
      - PHP_TZ=America/Sao_Paulo
      - ZBX_MEMORYLIMIT=1024M
    depends_on:
      - mysql-server
      - zabbix-server-mysql
    restart: always
    networks:
      zbx:
        ipv4_address: 172.50.0.3

  grafana:
    container_name: grafana
    image: grafana/grafana:latest
    ports:
      - 3000:3000
    volumes:
      - type: bind
        source: /docker/grafana/lib
        target: /var/lib/grafana
      - type: bind
        source: /var/run/docker.sock
        target: /var/run/docker.sock
    environment:
      - GF_INSTALL_PLUGINS=alexanderzobnin-zabbix-app
    restart: always
    networks:
      zbx:
        ipv4_address: 172.50.0.5

  zabbix-agent2:
    container_name: zabbix-agent2
    image: zabbix/zabbix-agent2:ubuntu-latest
    user: root
    depends_on:
      - zabbix-server-mysql
    environment:
      - ZBX_HOSTNAME=zabbix7
      - ZBX_SERVER_HOST=127.0.0.1
      - ZBX_PASSIVE_ALLOW=true
      - ZBX_PASSIVESERVERS=zabbix-server
      - ZBX_ENABLEREMOTECOMMANDS=1
      - ZBX_ACTIVE_ALLOW=false
      - ZBX_DEBUGLEVEL=3
    privileged: true
    pid: "host"
    ports:
      - 10050:10050
      - 31999:31999
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always
    networks:
      zbx:
        ipv4_address: 172.50.0.6
    stop_grace_period: 5s
EOF
###--FIM--###
