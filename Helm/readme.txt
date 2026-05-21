# Projet Kubernetes – Déploiement avec Helm

Ce projet déploie une architecture micro-services sur Kubernetes à l’aide de **Helm**.

Il comprend :
- des **APIs applicatives** (namespace `projet-apps`)
- des **services data** (namespace `ns-data`)
- des **options** activables (Ingress, HPA, Monitoring, EFK)

---

## 1. Prérequis

### Outils nécessaires
- Docker Desktop **avec Kubernetes activé**
- kubectl
- Helm
- Git

### Vérification des outils
```bash
kubectl version --client
helm version
git --version


2. Vérifier le cluster Kubernetes
Vérifier le contexte actif
kubectl config current-context
kubectl config get-contexts

(Docker Desktop) Utiliser le cluster local
kubectl config use-context docker-desktop

Vérifier que le cluster répond
kubectl cluster-info
kubectl get nodes


3. Création des namespaces (une seule fois)
kubectl create namespace projet-apps --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ns-data --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ns-monitoring --dry-run=client -o yaml | kubectl apply -f -

Vérification :
kubectl get namespaces


4. Vérification du chart Helm (sans déployer)
Se placer dans le dossier du chart Helm (ex: test-helm/).

Vérifier la structure et les values
helm lint .

Générer les manifests Kubernetes sans cluster
helm template k8s . -n projet-apps > rendered.yaml

Vérifier qu’il n’y a pas de valeurs manquantes
Select-String -Path .\rendered.yaml -Pattern "<no value>"

Vérifier les ressources générées
Select-String -Path .\rendered.yaml -Pattern "^kind:\s*(Deployment|StatefulSet|Service)"


5. Déploiement avec Helm

Installation (ou mise à jour)
helm upgrade --install k8s . -n projet-apps --create-namespace

Vérifier la release Helm
helm list -n projet-apps

Voir les manifests appliqués
helm get manifest k8s -n projet-apps

Voir les values utilisées
helm get values k8s -n projet-apps


6. Vérifications Kubernetes après déploiement

Pods
kubectl get pods -n ns-data
kubectl get pods -n projet-apps

Services
kubectl get svc -n ns-data
kubectl get svc -n projet-apps

Deployments
kubectl get deploy -n projet-apps

StatefulSets
kubectl get sts -n ns-data


7. Accès à l’application Web (sans Ingress)
kubectl port-forward svc/webmvc 8080:80 -n projet-apps
Accès navigateur :

http://localhost:8080


8. Debug en cas de problème
Événements Kubernetes
kubectl get events -n projet-apps --sort-by=.lastTimestamp
kubectl get events -n ns-data --sort-by=.lastTimestamp

Décrire un pod
kubectl describe pod <pod-name> -n <namespace>

Logs d’un pod
kubectl logs <pod-name> -n <namespace>


9. Mise à jour du déploiement
Après modification des templates ou du values.yaml :

helm upgrade k8s . -n projet-apps


10. Suppression complète du déploiement
helm uninstall k8s -n projet-apps


11. Git – Push du projet

Vérifier les fichiers
git status

Ajouter les fichiers
git add .

Commit
git commit -m "Helm chart final – déploiement Kubernetes"

Push
git push origin main

Recommandé : ignorer les fichiers générés
Ajouter dans .gitignore :

rendered.yaml
