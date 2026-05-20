FROM docker.elastic.co/elasticsearch/elasticsearch:8.11.1

# Définition des variables d'environnement de ton StatefulSet
ENV discovery.type=single-node
ENV xpack.security.enabled=false
ENV ES_JAVA_OPTS="-Xms768m -Xmx768m"

EXPOSE 9200