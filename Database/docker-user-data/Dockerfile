FROM mcr.microsoft.com/mssql/server:2019-latest
# L'utilisateur mssql est déjà créé dans cette image.

# Variables d'environnement par défaut
ENV SA_PASSWORD=Pass@word
ENV ACCEPT_EULA=Y
ENV MSSQL_TCP_PORT=1433

# Création du répertoire de travail pour les scripts
WORKDIR /usr/config

# Copie des scripts d'initialisation
COPY setup.sql setup.sql
COPY import-data.sh import-data.sh
COPY entrypoint.sh entrypoint.sh

# Permissions d'exécution sur les scripts shell
USER root
RUN chmod +x import-data.sh entrypoint.sh

# On repasse sur l'utilisateur mssql pour la sécurité
USER mssql

ENTRYPOINT ["./entrypoint.sh"]