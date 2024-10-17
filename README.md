# O Desafio
Você foi contratado como Data Engineer por uma empresa de tecnologia que oferece serviços online. Sua tarefa é analisar os logs de acesso ao servidor web da empresa, os quais são cruciais para monitorar a performance do sistema, identificar padrões de uso e detectar possíveis problemas de segurança.

Como parte do seu trabalho, você recebeu um arquivo de log em duas partes ([001](https://github.com/seriallink/assignments/blob/main/access_log.txt.7z.001) e [002](https://github.com/seriallink/assignments/blob/main/access_log.txt.7z.002)) contendo registros de requisições HTTP feitas ao servidor da empresa ao longo de alguns dias. Sua missão é processar e analisar esses logs para extrair informações relevantes, auxiliando a equipe de operações a compreender melhor o comportamento dos usuários e a performance da infraestrutura. Para isso, você utilizará o **Apache Spark**, um framework amplamente usado para processamento distribuído de grandes volumes de dados.

O arquivo de log segue o padrão **Web Server Access Log**, e cada linha representa uma requisição HTTP. Com base nos dados do arquivo, responda às seguintes perguntas:

1. **Identifique as 10 maiores origens de acesso (Client IP) por quantidade de acessos.**
2. **Liste os 6 endpoints mais acessados, desconsiderando aqueles que representam arquivos.**
3. **Qual a quantidade de Client IPs distintos?**
4. **Quantos dias de dados estão representados no arquivo?**
5. **Com base no tamanho (em bytes) do conteúdo das respostas, faça a seguinte análise:**
   - O volume total de dados retornado.
   - O maior volume de dados em uma única resposta.
   - O menor volume de dados em uma única resposta.
   - O volume médio de dados retornado.
   - *Dica:* Considere como os dados podem ser categorizados por tipo de resposta para realizar essas análises.
6. **Qual o dia da semana com o maior número de erros do tipo "HTTP Client Error"?**

# Desenvolvimento

## Ambiente
O desenvolvimento da solução foi realizada no [Databricks Community Edition](https://docs.databricks.com/en/getting-started/community-edition.html), utilizando a Azure como provedor de recursos na nuvem.

Para reprodução do processo, são necessários esses recursos:
1. Uma conta ativa e válida na Azure
2. O registro no Databricks para vínculo na nuvem
 
Com esses dois itens podemos seguir para o processo de criação de recursos e desenvolvimento

## Recursos da nuvem
Pela integração nativa entre DCE (Databricks Community Edition) e Azure, o único trabalho inicial é realizar o cadastro nesse [link](https://www.databricks.com/try-databricks#account) e selecionar a "Azure" como provedor de nuvem. Você realizará o login na plataforma e um script de deploy será executado para criação do workspace no Databricks.

Além disso, é necessária a criação dos seguintes recursos:
1. Um grupo de recursos para organizar os serviços criados dentro da Azure
2. Uma conta de armazena que hospedará nossos conteineres que serão montados pelo Databricks

### Estrutura da conta de armazenamento
Para aumentar a similaridade com a realidade, eu realizei a criação de um conjunto de conteineres que representam as camadas do medallion. Dentro da conta de armazenamento "santanderloganalysis", foram criados os conteineres:
1. bronze - caminho que recebeu o arquivo bruto de log
2. silver - caminho que recebeu a tabela Delta já formada a partir dos logs
3. gold - caminho que recebeu os resultados das análises realizadas, prontas para serem consumidas
4. data-ingestion - um caminho extra criado para um teste de escala

### Mounting no Databricks
Após a criação da conta de armazenamento e dos caminhos que utilizaremos, é necessário fazer os mounts dentro do Databricks. Eu optei por isolar os mounts, de modo que cada zone tivesse um caminho específico dentro do databricks.

Para realizar o mount, você pode utilizar esse script dentro de um notebook do Databricks:
~~~python
storageAccountName = "" # Inserir o nome da conta de armazenamento
storageAccountAccessKey = "" # Inserir a chave de acesso da conta de armazenamento, disponível em Conta de Armazenamento > Segurança + Rede > Chaves de Acesso

blobContainerName = ['bronze', 'silver', 'gold', 'data-ingestion'] 
mountPoint = ["/mnt/data/bronze", "/mnt/data/silver", "/mnt/data/gold", "/mnt/data/data-ingestion"]

for container, mount in zip(blobContainerName, mountPoint):
   if not any(mount.mount == mount for mount in dbutils.fs.mounts()): # Checa de o mount já não existe
      try:
         dbutils.fs.mount(
            source = "wasbs://{}@{}.blob.core.windows.net".format(container, storageAccountName),
            mount_point = mount,
            extra_configs = {'fs.azure.account.key.' + storageAccountName + '.blob.core.windows.net': storageAccountAccessKey}
         )
         print("mount succeeded!")
      except Exception as e:
         print("mount exception", e)

~~~

Após o mount dos conteineres, já podemos utilizar esses caminhos para leitura e escrita de dados utilizando o `dbutils.fs`. Você pode consultar o sucesso da operação utilizando o comando abaixo:
~~~python
print([mount for mount in dbutils.fs.mounts() if 'data/' in mount.mountPoint])
# [MountInfo(mountPoint='/mnt/data/data-ingestion', source='wasbs://data-ingestion@santanderloganalysis.blob.core.windows.net', encryptionType=''),
#  MountInfo(mountPoint='/mnt/data/gold', source='wasbs://gold@santanderloganalysis.blob.core.windows.net', encryptionType=''),
#  MountInfo(mountPoint='/mnt/data/bronze', source='wasbs://bronze@santanderloganalysis.blob.core.windows.net', encryptionType=''),
#  MountInfo(mountPoint='/mnt/data/silver', source='wasbs://silver@santanderloganalysis.blob.core.windows.net', encryptionType='')]
~~~


## Estrutura do repositório
O repositório possui duas pastas com scripts Python:
1. ***generate_sample_logs.ipynb*** - esse arquivo faz a geração de um número N de arquivos com 1 milhão de linhas simulando a mesma estrutura de logs recebida. Foi utilizado para fazer um teste de escala e garantir a possibilidade de uma complexidade linear (ou muito próxima disso).
2. ***log_analysis.ipynb*** - arquivo principal, onde estão sendo feitas as transformações e análises.


### generate_sample_logs.ipynb
Para reproduzir o teste de escalabilidade, basta alterar a variável `quantidade_de_arquivos` e executar o notebook. Ele, automaticamente, salvará os novos arquivos `.txt` no conteiner de ingestão de dados, paralelo ao bronze.

Após isso, no arquivo principal (log_analysis.ipynb), basta alterar o fluxo para "escala" e executar o código.

### log_analysis.ipynb
Esse arquivo possui as transformações realizada para conclusão das questões iniciais. Todas as transformações (incluindo movimentações entre camadas) foram realizadas em um único arquivo, mas eu acredito que, no mundo ideal, elas seriam separadas. Por exemplo:
1. notebook para ingestão source para bronze.
2. notebook para transformações bronze para silver.
3. notebooks individuais para cada agregação realizada a ser salva na camada gold.

Todos os dados, com exceção da camada bronze, estão salvos em Delta. Entendi ser o melhor formato para esse caso por:
1. ser muito eficiente quando o assunto é Spark
2. me trazer uma gama extensa de ferramentas de otimização
3. me permitir trabalhar com big data de modo mais eficiente que o `.parquet`, isoladamente
4. ter uma extensa lista de aplicações que conseguem interagir com ele nativamente

#### Fluxo do notebook
O notebook foi estruturado de forma muito simples, com o objetivo de facilitar a leitura e execução do código. Evitei o uso de funções customizadas, para aumentar a legibilidade e integração com versões Spark. O fluxo de execução é:
- imports de bibliotecas necessárias para a execução
- uma célula para definição do que chamei de "fluxo", onde você pode optar por "4" ou "530".
   - O fluxo "4" é o solicitado no teste, com o arquivo enviado por e-mail. Enquanto o fluxo 530 é um teste de escala com um arquivo muito maior.
- é realizada uma tentativa de leitura da tabela gravada anteriormente. Caso isso não seja possível, é realizada uma nova escrita.
   - por conta da infraestrutura da community edition, o teste de escala pode demorar um pouco. Mas em uma infra comum (com mais de 4 cores e um node único), o processo é bem mais tranquilo.
- as células subsequentes realizam as respostas de cada uma cadas perguntas propostas.