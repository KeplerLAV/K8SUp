# Projet M2Cloud – Déploiement Kubernetes d’une application microservices

## Description

Ce projet consiste à déployer une application composée de plusieurs microservices sur un cluster Kubernetes (AKS ou local). L’objectif est de mettre en place une architecture cloud complète avec conteneurs, scalabilité, monitoring, sécurité et gestion des logs.

L’application se compose des services suivants :

* **web** : Application web consommant les services `applicants.api` et `jobs.api`.
* **applicants.api** : API REST fournissant des données sur les candidats.
* **jobs.api** : API REST fournissant des informations sur les offres d’emploi.
* **identity.api** : API REST gérant l’authentification.
* **sql.data** : Base de données SQL Server pour les données des APIs.
* **rabbitmq** : Service de messagerie pour la communication entre services.

Les dépendances et les variables d’environnement sont définies dans le fichier `docker-compose` du projet.

---

## Objectifs techniques

1. **Conteneurisation**

   * Création d’images Docker pour chaque service.
   * Publication des images dans un registre privé (Docker Hub ou Azure Container Registry).

2. **Déploiement Kubernetes**

   * Déploiement de tous les services sous forme de pods, deployments et StatefulSet pour SQL.
   * Services internes et ingress pour l’accès externe sécurisé via HTTPS.
   * Affinité des pods pour optimiser les performances et communication entre services.
   * Limites et demandes de ressources CPU/Mémoire définies pour chaque service.

3. **Scalabilité**

   * Mise en place d’un **Horizontal Pod Autoscaler** (HPA) basé sur l’utilisation CPU.
   * Démonstration de l’augmentation des replicas sous charge.

4. **Santé et monitoring**

   * Sondes de liveness et readiness configurées pour chaque pod.
   * Installation de Metrics Server, kube-state-metrics et Prometheus pour surveiller le cluster et les pods.

5. **Sécurité**

   * Accès externe via HTTPS avec certificat TLS auto-signé.
   * ServiceAccount dédié avec RBAC restreint.
   * NetworkPolicy pour limiter les communications inter-services.

6. **Gestion des logs**

   * Mise en place d’une stack EFK (Elasticsearch / FluentBit / Kibana) pour centraliser et analyser les logs.
   * Dashboard et recherche filtrée pour détecter les erreurs d’un service.

7. **Automatisation du déploiement**

   * Création d’un **Helm chart** pour automatiser la création des déploiements, services, ingress, HPA, NetworkPolicy et RBAC.
   * CI/CD avec GitHub Actions pour build et push des images Docker.

---

## Ressources par service

| Service        | CPU Requests | CPU Limits | Mem Requests | Mem Limits | Affinité                 |
| -------------- | ------------ | ---------- | ------------ | ---------- | ------------------------ |
| web            | 4m           | 1          | 900Mi        | 2000Mi     | applicants.api, jobs.api |
| applicants.api | 0.5          | 1          | 500Mi        | 1500Mi     | sql.data                 |
| jobs.api       | 0.5          | 1          | 500Mi        | 1500Mi     | sql.data                 |
| identity.api   | 0.5          | 1          | 500Mi        | 1500Mi     | sql.data                 |
| sql.data       | 4m           | 1          | 500Mi        | 1500Mi     | —                        |

---

## Démonstration

Le projet permet de :

* Déployer une architecture microservices complète sur Kubernetes.
* Monitorer l’état des pods, nodes et du cluster via Prometheus.
* Observer le scaling automatique via HPA.
* Consulter et analyser les logs centralisés dans Kibana/OpenSearch Dashboards.
* Assurer la sécurité via TLS, RBAC et NetworkPolicy.

Ce qui compose le docker : 

*  **ports exposés**
*  **dossiers des Dockerfile**
*  **dépendances entre services**

---

##  Récapitulatif des services

### 1 user.data (Redis)

* **Image** : `redis`
* **Ports** :

  * `6379 → 6379`
* **Dockerfile** : ❌ (image officielle)
* **Dépendances** : ❌

---

### 2 rabbitmq

* **Image** : `rabbitmq:3-management`
* **Ports** :

  * `15672 → Interface Web`
  * `5672 → AMQP`
* **Dockerfile** : ❌
* **Dépendances** : ❌
* **Nom conteneur** : `rabbitmq`

---

### 3 webmvc

* **Image** : `web`
* **Ports** :

  * `8080 → 80`
* **Dockerfile** :

  *  **Contexte** : `./`
  *  **Dockerfile** : `Web/Dockerfile`
* **Dépendances** :

  * `applicants.api`
  * `identity.api`
  * `jobs.api`
* **Nom conteneur** : `web`

---

### 4 applicants.api

* **Image** : `applicants.api`
* **Ports** :

  * `8081 → 80`
* **Dockerfile** :

  *  **Contexte** : `./`
  *  **Dockerfile** : `Services/Applicants.Api/Dockerfile`
* **Variables d’environnement** :

  * `ConnectionString → sql.data`
  * `HostRabbitmq → rabbitmq`
* **Dépendances** :

  * `sql.data`
  * `rabbitmq`
* **Nom conteneur** : `applicants.api`

---

### 5 jobs.api

* **Image** : `jobs.api`
* **Ports** :

  * `8083 → 80`
* **Dockerfile** :

  *  **Contexte** : `./`
  *  **Dockerfile** : `Services/Jobs.Api/Dockerfile`
* **Variables d’environnement** :

  * `ConnectionString → sql.data`
  * `HostRabbitmq → rabbitmq`
* **Dépendances** :

  * `sql.data`
  * `rabbitmq`
* **Nom conteneur** : `jobs.api`

---

### 6 identity.api

* **Image** : `identity.api`
* **Ports** :

  * `8084 → 80`
* **Dockerfile** :

  *  **Contexte** : `./`
  *  **Dockerfile** : `Services/Identity.Api/Dockerfile`
* **Variables d’environnement** :

  * `RedisHost → user.data:6379`
  * `HostRabbitmq → rabbitmq`
* **Dépendances** :

  * `user.data`
  * `rabbitmq`
* **Nom conteneur** : `identity.api`

---

### 7 sql.data (SQL Server)

* **Image** : `mssql-linux`
* **Ports** :

  * `1433 → 1433`
* **Dockerfile** :

  *  **Contexte** : `./Database`
  *  **Dockerfile** : `Database/Dockerfile`
* **Dépendances** : ❌
* **Nom conteneur** : `mssql-linux`

---

## Vue rapide des ports

| Service         | Port hôte | Port conteneur | URL locale                                       | Notes                       |
| --------------- | --------- | -------------- | ------------------------------------------------ | --------------------------- |
| Redis           | 6379      | 6379           | localhost:6379                                   | Cache pour identity.api     |
| RabbitMQ (UI)   | 15672     | 15672          | [http://localhost:15672](http://localhost:15672) | Management Web              |
| RabbitMQ (AMQP) | 5672      | 5672           | localhost:5672                                   | Communication API           |
| Web MVC         | 8080      | 80             | [http://localhost:8080](http://localhost:8080)   | Frontend web                |
| Applicants API  | 8081      | 80             | [http://localhost:8081](http://localhost:8081)   | API candidats               |
| Jobs API        | 8083      | 80             | [http://localhost:8083](http://localhost:8083)   | API jobs                    |
| Identity API    | 8084      | 80             | [http://localhost:8084](http://localhost:8084)   | API authentification        |
| SQL Server      | 1433      | 1433           | localhost:1433                                   | Base de données             |
| Elasticsearch   | 9200      | 9200           | [http://localhost:9200](http://localhost:9200)   | Indexation logs             |
| Logstash        | 5044      | 5044           | localhost:5044                                   | Pipeline logs (beats input) |
| Kibana          | 5601      | 5601           | [http://localhost:5601](http://localhost:5601)   | Dashboard logs              |



---

##  Dépendances 

```
webmvc
 ├── applicants.api ──┐
 ├── identity.api     ├── rabbitmq
 └── jobs.api      ───┘
        │
        └── sql.data

identity.api ── user.data (Redis)
```
kubectl delete namespace projet-apps ns-monitoring ns-data 
kubectl delete namespace ns-data    
kubectl delete namespace ns-monitoring

Service URL Locale Login 
Frontend Web http://localhost:8080
Kibana (Logs) http://localhost:5601
Grafana (Metrics)http://localhost:3000 admin / admin
Rabbit MQ UI http://localhost:15672 guest / guest
Prometheus http://localhost:9090

