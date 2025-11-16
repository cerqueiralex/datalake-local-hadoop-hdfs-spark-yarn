# Data lake Local com Apache Hadoop, HDFS, Apache Spark e Apache YARN

Design e Implementação de Data Lake Local Para Armazenamento e Processamento Distribuído

Tecnologias:

* Apache Hadoop
  * Sistema de armazenamento HDFS
  * Sistema de processamento: Apache Spark
* Apache YARN (Gerenciador de recursos do cluster Hadoop)

<img src="" style="width:100%;height:auto"/>

## Configuracao Docker 

```Dockerfile```

Este é um Dockerfile de múltiplos estágios projetado para construir uma imagem de container que executa um cluster PySpark sobre Hadoop YARN. O primeiro estágio, spark-base, prepara o ambiente instalando uma versão específica do Python, o JDK 11 (essencial para Spark e Hadoop), e baixa os binários do Apache Spark e do Hadoop. 

O segundo estágio, pyspark, usa essa base, instala as dependências Python necessárias (via requirements.txt), e realiza a configuração detalhada do ambiente. Isso inclui definir variáveis de ambiente cruciais (como SPARK_HOME, HADOOP_HOME, JAVA_HOME e o PATH), copiar arquivos de configuração customizados para YARN e HDFS, e configurar o SSH para permitir a comunicação sem senha entre os nós do cluster. 

Finalmente, ele define um entrypoint.sh como o script de inicialização do container.


```docker-compose.yml```

Este é um arquivo docker-compose.yml, que é usado para definir e executar aplicações Docker de múltiplos contêineres.

Este arquivo orquestra a criação de um cluster de processamento de dados (um "Data Lake") composto por três serviços principais: um nó mestre (datauniverse-data-lake-master), um nó trabalhador (datauniverse-data-lake-worker) e um servidor de histórico (datauniverse-data-lake-history-server). 

O serviço mestre é o único que "constrói" a imagem Docker principal (datauniverse-data-lake-image) a partir de um Dockerfile local. Os outros dois serviços (worker e history-server) reutilizam essa mesma imagem, garantindo que todos os nós do cluster tenham o mesmo ambiente e dependências. 

A diferenciação de papéis (mestre, trabalhador ou histórico) é feita passando um argumento diferente (master, worker, history) para o mesmo script entrypoint.sh. O arquivo também gerencia volumes para persistir dados, compartilhar scripts (jobs) e armazenar logs de eventos, além de mapear todas as portas necessárias para acessar as interfaces web do HDFS, YARN e Spark.

### Comandos

1. Inicializar o cluster
```
docker-compose -f docker-compose.yml up -d --scale datauniverse-data-lake-worker=3
```

2. Visualizar os logs
```
docker-compose logs
```

3. Testar o cluster
```
docker exec datauniversemaster spark-submit --master yarn --deploy-mode cluster ./examples/src/main/python/pi.py
```

4. Derrubar o cluster
```
docker-compose down --volumes --remove-orphans
```

5. Spark Master
http://localhost:9091

6. History Server
http://localhost:18081

## Alimentando dados no Datalake

### 1. No Arranque

Ao criar o cluster pela primeira vez, atraves dos comandos abaixo, ele ira criar e mapear a pasta de dados e subir os dados junto coma  criacao do cluster

```
hdfs dfs -mkdir -p /opt/spark/data

hdfs dfs -copyFromLocal /opt/spark/data/* /opt/spark/data
```

### 2. Com o cluster ja criado

Comandos que devem ser executados no terminal ou prompt de comando:

Esses três comandos, executados em sequência, interagem com o sistema de arquivos HDFS dentro do contêiner dsamaster. O objetivo é: primeiro, listar o conteúdo de um diretório no HDFS para ver o que há lá; segundo, criar um novo subdiretório chamado teste nesse mesmo local; e terceiro, listar o conteúdo novamente para confirmar que o novo diretório foi criado com sucesso.

* Obter os dados do Cluster 

Se conecta ao contêiner 'dsamaster' e pergunta ao HDFS: "Liste todos os arquivos e pastas que estão no diretório /opt/spark/data."

```
docker exec datauniversemaster hdfs dfs -ls /opt/spark/data
```

Cria uma nova pasta chamada 'teste' dentro do diretório '/opt/spark/data' no HDFS.

```
docker exec datauniversemaster hdfs dfs -mkdir /opt/spark/data/teste
```

Lista novamente o conteúdo de '/opt/spark/data' no HDFS. A diferença agora é que a saída deste comando deve incluir o novo diretório 'teste' que foi criado pelo comando anterior.

```
docker exec datauniversemaster hdfs dfs -ls /opt/spark/data
```

#### 2.1 Inserir os dados

Inserir os arquivos do diretorio /data/ no sistema distribuido hdfs
```
hdfs dfs -put dataset.csv /opt/spark/data
```

Verificar se os arquyivos foram incluidos no HDFS (pode excluir os dados do dirretorio local, pois ja foram distribuidos pelo cluster)
```
hdfs dfs -ls dataset.csv /opt/spark/data
```

<img src="" style="width:100%;height:auto"/>


## Treinar o modelo e salvar a métrica AUC

Executar o job.py DENTRO DO CONTAINER

```
docker exec datauniversemaster spark-submit --master yarn --deploy-mode cluster ./apps/job.py
```

> Acompanhamento e Monitoramento via Interface (YARN)

PORTS CONFIGURADOS

* 7071:7077
* 9091:8080 
* 8081:8088 (YARN)
* 9871:9870 (HDFS)

<img src="" style="width:100%;height:auto"/>

> Acompanhamento e Monitoramento via Interface (HDFS)

<img src="" style="width:100%;height:auto"/>

> Acompanhamento e Monitoramento via Interface (History Server)

<img src="" style="width:100%;height:auto"/>