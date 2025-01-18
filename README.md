# Instalando Zabbix em Container (Shell Script)

> Este script automatiza a instalação do Zabbix em um ambiente de container Docker já instalado com Linux Ubuntu 24.04 LTS.
> Ele inclui os seguintes passos:

- Criar diretórios: o script cria os diretórios necessários para armazenar os arquivos de configuração do Zabbix e os volumes de dados.
- Baixar o arquivo docker-compose: o script baixa um arquivo "docker-compose-zabbix.yaml" pré-configurado que define os componentes do Zabbix e suas configurações.
- Definir permissões: o script define as permissões apropriadas para o script e o arquivo docker-compose baixado.
- Executar o script: o script executa o arquivo docker-compose baixado para criar e iniciar os contêineres do Zabbix.

Observação importante: este script requer a execução com privilégios de root (sudo).
Seguindo as instruções do script, é possível configurar de forma rápida e fácil um ambiente de monitoramento do Zabbix com Grafana usando contêineres do Docker.


## Instalação

Criar arquivo dentro do diretório de preferência (utilizado diretório "/home" como exemplo):

```sh
sudo nano /home/zdocker.sh
```

Abaixo o conteúdo do script para copiar para zdocker.sh:

```bash
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
```

## Execução do Script

Após salvar o arquivo, executar o comando para dar permissão ao script:
```sh
chmod +x zdocker.sh
```

Executar o arquivo zdocker.sh para criar os diretorios e o arquivo docker-compose-zabbix.yaml:
```sh
sudo ./zdocker.sh
```

Acessar o diretório "/docker"
```sh
cd /docker
```

Validar a criação do arquivo docker-compose-zabbix.yaml e os diretórios
```sh
ls
```

Comando para dar inicio na criação dos container:
```sh
sudo docker compose -f docker-compose-zabbix.yaml up -d
```

## COMANDOS UTEIS

Comando para listar os containers e obter o "CONTAINER_ID":
```sh
sudo docker ps
```

Inspeciona o arquivo de configuração do container, exemplo: "zabbix-agent2":
```sh
docker inspect {CONTAINER_ID}
```

Comando para recarregar o cache de configuração do Zabbix Server dentro do container "zabbix-server": 
```sh
docker exec -it {CONTAINER ID} zabbix-server -R config_cache_reload
```

Excluir o docker criado (CUIDADO):
```sh
docker-compose -f docker-compose-zabbix.yaml kill
```

Verificar logs:
```sh
docker logs {CONTAINER ID}
```

Executar comandos dentro do container:
```sh
docker exec it {CONTAINER ID} /bin/bash
```

## Contribuição

1. Faça o _fork_ do projeto (<https://github.com/nildojs/zabbixDocker25/fork>)
2. Crie uma _branch_ para sua modificação (`git checkout -b feature/zabbixDocker25`)
3. Faça o _commit_ (`git commit -am 'Add some zabbixDocker25'`)
4. _Push_ (`git push origin feature/zabbixDocker25`)
5. Crie um novo _Pull Request_
