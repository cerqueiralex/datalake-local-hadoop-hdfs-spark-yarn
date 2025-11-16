# O Dockerfile é dividido em "estágios" (stages). Isso ajuda a manter a imagem final menor.
# Este é o primeiro estágio, nomeado como 'spark-base'.
# Imagem do SO usada como base
# Imagem linux (Debian Bullseye) com o interpretador Python 3.11 já instalado.
# Usaremos este Python para rodar os scripts PySpark.
# https://hub.docker.com/_/python
FROM python:3.11-bullseye as spark-base

# Atualiza os pacotes do sistema operacional (Debian) e instala dependências.
# 'apt-get update' atualiza a lista de pacotes disponíveis.
# 'apt-get install -y' instala os pacotes listados.
# '--no-install-recommends' evita instalar pacotes opcionais, economizando espaço.
# 'sudo': permite rodar comandos como superusuário (root).
# 'curl': ferramenta para baixar arquivos (como o Spark e Hadoop).
# 'vim', 'nano': editores de texto para depuração dentro do container.
# 'unzip', 'rsync': utilitários de arquivos.
# 'openjdk-11-jdk': O Java Development Kit (JDK) versão 11. É um requisito OBRIGATÓRIO para rodar Spark e Hadoop.
# 'build-essential': Pacotes necessários para compilar código (caso alguma biblioteca Python precise).
# 'software-properties-common': Utilitário para gerenciar repositórios de software.
# 'ssh': O cliente e servidor SSH, necessário para o Hadoop gerenciar seus nós (workers).
# 'apt-get clean && rm -rf ...': Limpa os arquivos de cache para reduzir o tamanho da imagem.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      sudo \
      curl \
      vim \
      nano \
      unzip \
      rsync \
      openjdk-11-jdk \
      build-essential \
      software-properties-common \
      ssh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Define variáveis de ambiente. 'ENV' torna essas variáveis disponíveis no container.
# ${VAR:-"/default"} significa: use o valor de $VAR se ela existir, senão, use "/default".
# SPARK_HOME: O diretório onde o Spark será instalado.
ENV SPARK_HOME=${SPARK_HOME:-"/opt/spark"}
# HADOOP_HOME: O diretório onde o Hadoop será instalado.
ENV HADOOP_HOME=${HADOOP_HOME:-"/opt/hadoop"}

# Cria as pastas definidas nas variáveis de ambiente acima.
# 'mkdir -p' cria a pasta e qualquer pasta "pai" necessária (como /opt) sem dar erro.
RUN mkdir -p ${HADOOP_HOME} && mkdir -p ${SPARK_HOME}
# Define o diretório de trabalho padrão para os próximos comandos RUN, CMD, ENTRYPOINT.
# A partir daqui, os comandos são executados como se estivéssemis dentro de /opt/spark.
WORKDIR ${SPARK_HOME}

# Baixa (curl) o arquivo binário pré-compilado do Spark 3.5.1 compatível com Hadoop 3.
# '-o' especifica o nome do arquivo salvo (spark-3.5.1-bin-hadoop3.tgz).
RUN curl https://archive.apache.org/dist/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz -o spark-3.5.1-bin-hadoop3.tgz \
 # '&&' encadeia comandos. O próximo só roda se o anterior for bem-sucedido.
 # 'tar xvzf' extrai o arquivo .tgz que baixamos.
 # '--directory /opt/spark' extrai o conteúdo para o SPARK_HOME.
 # '--strip-components 1' remove o primeiro nível de diretório do arquivo .tgz (ex: /spark-3.5.1-bin-hadoop3/...)
 # para que os arquivos (bin, sbin, conf, etc.) fiquem direto em /opt/spark.
 && tar xvzf spark-3.5.1-bin-hadoop3.tgz --directory /opt/spark --strip-components 1 \
 # Remove o arquivo .tgz baixado para economizar espaço na imagem final.
 && rm -rf spark-3.5.1-bin-hadoop3.tgz

# Processo idêntico ao do Spark, mas agora para o Hadoop 3.4.0.
# Baixa (curl) o Hadoop.
RUN curl https://dlcdn.apache.org/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz -o hadoop-3.4.0.tar.gz \
 # Extrai (tar xfz) o conteúdo para o HADOOP_HOME (/opt/hadoop).
 && tar xfz hadoop-3.4.0.tar.gz --directory /opt/hadoop --strip-components 1 \
 # Remove o arquivo .tgz baixado.
 && rm -rf hadoop-3.4.0.tar.gz

# --- Fim do primeiro estágio ---

# Inicia o SEGUNDO ESTÁGIO, nomeado 'pyspark'.
# 'FROM spark-base' significa que este estágio herda TUDO que foi feito no estágio 'spark-base'.
# Vamos adicionar as configurações específicas do Python e do ambiente.
FROM spark-base as pyspark

# Atualiza o 'pip', o gerenciador de pacotes do Python.
RUN pip3 install --upgrade pip
# Copia o arquivo de requisitos do Python (da sua máquina local) para dentro da imagem.
# O '.' significa que ele será copiado para o diretório de trabalho atual (WORKDIR), que é /opt/spark.
COPY requirements/requirements.txt .
# Instala todas as bibliotecas Python listadas no requirements.txt (ex: pyspark, pandas, etc).
RUN pip3 install -r requirements.txt

# Define a variável de ambiente JAVA_HOME, essencial para o Spark e Hadoop encontrarem a instalação do Java.
# O caminho aponta para a instalação do openjdk-11-jdk que fizemos no primeiro estágio.
ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
# A linha abaixo está comentada, mas serviria para arquiteturas ARM64 (ex: Macs M1/M2).
#ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-arm64"

# Adiciona os diretórios de binários (executáveis) do Spark, Hadoop e Java ao PATH do sistema.
# Isso permite que você execute comandos como 'spark-submit', 'hdfs', 'yarn', 'java' de qualquer lugar no terminal.
# A sintaxe '...:${PATH}' garante que estamos *adicionando* ao PATH existente, e não o substituindo.
ENV PATH="$SPARK_HOME/sbin:/opt/spark/bin:${PATH}"
ENV PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:${PATH}"
ENV PATH="${PATH}:${JAVA_HOME}/bin"

# Define variáveis de ambiente específicas de configuração do Spark.
# SPARK_MASTER: A URL do nó mestre (Master) do Spark.
ENV SPARK_MASTER="spark://datauniversemaster:7077"
# SPARK_MASTER_HOST: O hostname do mestre.
ENV SPARK_MASTER_HOST datauniversemaster
# SPARK_MASTER_PORT: A porta do mestre.
ENV SPARK_MASTER_PORT 7077
# PYSPARK_PYTHON: Informa ao Spark qual executável do Python usar.
ENV PYSPARK_PYTHON python3
# HADOOP_CONF_DIR: Informa ao Spark (e outros) onde encontrar os arquivos de configuração do Hadoop.
ENV HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"

# Informa ao sistema onde encontrar as bibliotecas nativas do Hadoop (otimizadas).
ENV LD_LIBRARY_PATH="$HADOOP_HOME/lib/native:${LD_LIBRARY_PATH}"

# Define qual usuário do sistema operacional irá rodar os serviços (daemons) do Hadoop (HDFS e YARN).
# Aqui, está configurado para usar o usuário 'root'.
ENV HDFS_NAMENODE_USER="root"
ENV HDFS_DATANODE_USER="root"
ENV HDFS_SECONDARYNAMENODE_USER="root"
ENV YARN_RESOURCEMANAGER_USER="root"
ENV YARN_NODEMANAGER_USER="root"

# Adiciona a definição do JAVA_HOME diretamente no arquivo de configuração de ambiente do Hadoop.
# Isso garante que o Hadoop usará a versão correta do Java.
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"

# Copia os arquivos de configuração customizados (da sua máquina local) para dentro da imagem.
# Copia o 'spark-defaults.conf' para a pasta de configuração do Spark.
COPY yarn/spark-defaults.conf "$SPARK_HOME/conf/"
# Copia todos os arquivos .xml (core-site.xml, hdfs-site.xml, yarn-site.xml, etc.) para a pasta de configuração do Hadoop.
COPY yarn/*.xml "$HADOOP_HOME/etc/hadoop/"

# 'chmod u+x' torna os arquivos executáveis ('x') para o usuário ('u') proprietário.
# Isso é necessário para rodar os scripts de inicialização e binários do Spark.
RUN chmod u+x /opt/spark/sbin/* && \
    chmod u+x /opt/spark/bin/*

# Adiciona os diretórios Python do Spark ao PYTHONPATH.
# Isso permite que o Python (ex: no seu script) encontre e importe a biblioteca 'pyspark'.
ENV PYTHONPATH=$SPARK_HOME/python/:$PYTHONPATH

# Padrao do HADOOP
# Configura o SSH para permitir login sem senha (password-less login) na própria máquina (localhost).
# O Hadoop usa SSH para se comunicar entre seus nós (Namenode, Datanodes, etc.).
# 'ssh-keygen -t rsa -P '' -f ...': Gera uma chave SSH tipo RSA, sem senha ('-P '''), e salva em ~/.ssh/id_rsa.
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
  # 'cat ... >> ...': Adiciona a chave pública (id_rsa.pub) ao arquivo de chaves autorizadas (authorized_keys).
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
  # Ajusta as permissões do arquivo, uma exigência de segurança do SSH.
  chmod 600 ~/.ssh/authorized_keys

# Copia um arquivo de configuração SSH personalizado (da sua máquina) para dentro da imagem.
# Pode conter configurações como 'StrictHostKeyChecking no' para evitar prompts de confirmação.
COPY ssh/ssh_config ~/.ssh/config

# Copia o script de 'entrypoint' (da sua máquina) para o diretório de trabalho (/opt/spark).
# Este script será o comando principal executado quando o container iniciar.
COPY entrypoint.sh .

# Torna o script 'entrypoint.sh' executável.
RUN chmod +x entrypoint.sh

# 'EXPOSE' é uma instrução informativa para o Docker, dizendo que o container "escuta" na porta 22 (SSH).
EXPOSE 22

# Define o comando que será executado quando um container for iniciado a partir desta imagem.
# Ele executará o script que acabamos de copiar e tornar executável.
ENTRYPOINT ["./entrypoint.sh"]