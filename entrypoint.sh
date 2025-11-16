#!/bin/bash

# Armazena o primeiro argumento ( $1 ) passado para este script na variável SPARK_WORKLOAD.
# No contexto do docker-compose, $1 será "master", "worker" ou "history".
SPARK_WORKLOAD=$1

# Imprime o valor da variável no log, útil para depuração.
echo "SPARK_WORKLOAD: $SPARK_WORKLOAD"

# Inicia o serviço (daemon) do SSH.
# O Hadoop (HDFS e YARN) usa SSH para que o nó mestre (Namenode, ResourceManager)
# possa se comunicar e gerenciar os nós de trabalho (Datanodes, Nodemanagers).
# A configuração 'ssh_config' que vimos antes (desabilitando StrictHostKeyChecking)
# é o que permite que essa comunicação aconteça sem prompts manuais.
/etc/init.d/ssh start

# Inicia um bloco 'if'. O código abaixo só executa se a variável SPARK_WORKLOAD for "master".
if [ "$SPARK_WORKLOAD" == "master" ];
then

  # Formata o Namenode do HDFS.
  # ATENÇÃO: Este comando APAGA todos os dados no HDFS.
  # Ele deve ser executado apenas uma vez, na primeira inicialização do cluster,
  # para criar as estruturas de metadados do sistema de arquivos.
  hdfs namenode -format

  # Inicializa os processos no master
  # Inicia o daemon do Namenode: o "cérebro" do HDFS que gerencia onde os arquivos estão.
  hdfs --daemon start namenode
  # Inicia o Secondary Namenode: um processo auxiliar que periodicamente faz "checkpoints"
  # dos metadados do Namenode para evitar perda de dados e acelerar a reinicialização.
  hdfs --daemon start secondarynamenode
  # Inicia o ResourceManager: o "cérebro" do YARN, responsável por gerenciar
  # e alocar os recursos do cluster (CPU, memória) para as aplicações (como o Spark).
  yarn --daemon start resourcemanager

  # Cria as pastas necessárias
  # Inicia um loop 'while'. O '!' inverte o resultado.
  # O loop continua ENQUANTO o comando 'hdfs dfs -mkdir' FALHAR.
  # Isso é um mecanismo de espera para garantir que os comandos HDFS
  # só rodem depois que o Namenode estiver totalmente pronto para aceitar conexões.
  while ! hdfs dfs -mkdir -p /data-lake-logs;
  do
    # Se falhar, imprime uma mensagem e o loop tenta novamente.
    echo "Falha ao criar a pasta /data-lake-logs no hdfs"
  done
  
  # Mensagem de sucesso após o loop 'while' terminar.
  echo "Criada a pasta /data-lake-logs no hdfs"
  # Cria o diretório '/opt/spark/data' DENTRO do sistema de arquivos HDFS.
  hdfs dfs -mkdir -p /opt/spark/data
  echo "Criada a pasta /opt/spark/data no hdfs"


  # Copia os dados para o HDFS
  # Copia arquivos do sistema de arquivos LOCAL do container (de /opt/spark/data/*)
  # para o sistema de arquivos DISTRIBUÍDO (HDFS) (para /opt/spark/data).
  # (Lembre-se: /opt/spark/data local foi montado a partir de './dados' no docker-compose).
  hdfs dfs -copyFromLocal /opt/spark/data/* /opt/spark/data
  # Lista o conteúdo do diretório no HDFS para confirmar que a cópia funcionou (visível nos logs).
  hdfs dfs -ls /opt/spark/data

# 'Senão, se' a variável for "worker", executa este bloco.
elif [ "$SPARK_WORKLOAD" == "worker" ];
then

  # Inicializa processos no worker
  # Inicia o Datanode: o "trabalhador" do HDFS que armazena os blocos de dados reais
  # e se reporta ao Namenode (master).
  hdfs --daemon start datanode
  # Inicia o Nodemanager: o "trabalhador" do YARN que executa as tarefas (containers)
  # das aplicações e se reporta ao ResourceManager (master).
  yarn --daemon start nodemanager

# 'Senão, se' a variável for "history", executa este bloco.
elif [ "$SPARK_WORKLOAD" == "history" ];
then

  # Inicia um loop de espera, similar ao do master.
  # 'hdfs dfs -test -d' verifica se o diretório HDFS '/data-lake-logs' existe.
  # O loop roda ENQUANTO ('!') o diretório NÃO existir.
  # Isso garante que o History Server (que depende dessa pasta) só inicie
  # DEPOIS que o container 'master' a criou com sucesso.
  while ! hdfs dfs -test -d /data-lake-logs;
  do
    echo "spark-logs não existe ainda...criando"
    # Espera 1 segundo antes de verificar novamente.
    sleep 1;
  done
  echo "Exit loop"

  # Inicializa o history server
  # Executa o script padrão do Spark para iniciar o History Server.
  # Este servidor lerá os logs da pasta HDFS /data-lake-logs
  # (configurada nos arquivos .xml/spark-defaults.conf) para exibir a UI.
  start-history-server.sh
fi
# Fecha a estrutura condicional if/elif.

# Este é um comando crucial para manter o container rodando.
# 'tail -f' "segue" (monitora) um arquivo. '/dev/null' é um arquivo especial
# do Linux que é um "buraco negro" (sempre vazio).
# O resultado é que o script fica "preso" nesta linha, rodando indefinidamente.
# Se este comando não existisse, o script terminaria, e o Docker
# encerraria o container (e todos os daemons: Namenode, Datanode, etc.).
tail -f /dev/null<