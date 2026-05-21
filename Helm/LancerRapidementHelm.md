Question: Quelles sont les commandes exactes pour recréer les namespaces et relancer proprement toute l'infrastructure après un reset du cluster ?

Answer:

Voici la séquence de commandes ordonnée et nettoyée pour reconstruire ton cluster à neuf, du provisionnement des espaces jusqu'au déploiement de tes services applicatifs et de supervision.

Ouvre ton terminal PowerShell dans ton dossier `Helm/` et exécute les blocs suivants :

---

### Étape 1 : Création de tous les Namespaces requis

Puisque ton cluster a été réinitialisé, il faut réinjecter manuellement tous les périmètres d'isolation de ton architecture :

```powershell
kubectl create namespace projet-apps
kubectl create namespace ns-data
kubectl create namespace ns-monitoring
kubectl create namespace ingress-nginx

```

---

### Étape 2 : Lancement global via Helm

Maintenant que tous les namespaces cibles sont actifs et prêts à recevoir du contenu, lance la compilation et l'installation de ton Chart Helm (sans utiliser l'option dépréciée `--force`) :

```powershell
helm upgrade --install k8s . --namespace projet-apps

```

---

### Étape 3 : Suivi de l'état des Services (L'ordre d'éveil)

Les conteneurs vont mettre quelques minutes à télécharger leurs images et à s'initialiser. Utilise ces commandes pour vérifier leur statut :

#### 1. La base de données et la messagerie (À vérifier en premier)

Tes API dépendent de ce namespace. Attends que tous les statuts passent à `1/1 Running`.

```powershell
kubectl get pods -n ns-data -w

```

#### 2. Les API et le Serveur Web (À rafraîchir si nécessaire)

```powershell
kubectl get pods -n projet-apps

```

*Astuce : Si tes API affichent `CrashLoopBackOff` ou ont redémarré parce que `sql-data` a mis trop de temps à démarrer, force leur réveil une fois la base prête avec :*

```powershell
kubectl rollout restart deployment -n projet-apps

```

#### 3. La Supervision et la Stack de logs (EFK / Prometheus)

Vérifie que ta stack de logs s'initialise bien dans son espace dédié :

```powershell
kubectl get pods -n ns-monitoring

```

---

### Étape 4 : Tunnel de test pour ton navigateur

Une fois que tous les pods de `projet-apps` et `ns-data` sont au statut `Running`, ouvre l'accès à ton interface graphique :

```powershell
kubectl port-forward deployment/webmvc 8080:80 -n projet-apps

```

Tu n'as plus qu'à ouvrir ton navigateur et aller sur **`http://localhost:8080`**.

Explanation:
Après la remise à zéro complète d'un plan de contrôle Kubernetes (reset du cluster), l'historique des releases Helm et la base de données des objets d'infrastructure (les namespaces) sont totalement effacés. En recréant d'abord manuellement l'intégralité des namespaces requis par l'architecture (`projet-apps`, `ns-data`, `ns-monitoring`, `ingress-nginx`) avant d'appeler `helm upgrade --install`, on garantit au gestionnaire de paquets Helm que toutes les routes logiques définies dans les métadonnées de tes manifests YAML seront valides et acceptées par l'API Server dès le premier essai.