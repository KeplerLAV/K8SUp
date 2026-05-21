# --- CONFIGURATION DES CHEMINS ---
$NS_APP  = "projet-apps"
$NS_DATA = "ns-data"
$NS_MON  = "ns-monitoring"
$NS_ING  = "ingress-nginx"

# Assure-toi que ces chemins sont corrects sur ton PC
$SQL_PATH        = "k8s/sql/sql-deployment.yaml"
$REDIS_PATH      = "k8s/redis/redis-deployment.yaml"
$RABBIT_PATH     = "k8s/rabbitmq/rabbitmq-deployment.yaml"
$IDENTITY_PATH   = "k8s/identity/identity-deployment.yaml"
$JOBS_PATH       = "k8s/jobs/jobs-deployment.yaml"
$APPLICANTS_PATH = "k8s/applicant/applicants-deployment.yaml"
$WEB_PATH        = "k8s/web/web-deployment.yaml"
$METRICS_PATH    = "k8s/metrics_server/component.yaml"
$EFK_PATH        = "k8s/efk/efk-stack.yaml"
$PROM_PATH       = "k8s/prometheus/prometheus.yaml"
$GRAF_PATH       = "k8s/grafana/grafana.yaml"
$USER_DATA_PATH = "k8s/sql/user-data-deployment.yaml" # <--- AJOUTER CECI
$SECRET_PATH     = "k8s/web/secret.yaml"
$INGRESS_PATH    = "k8s/ingress-nginx/ingress-nginx.yaml"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   DÉPLOIEMENT COMPLET : OBSERVABILITÉ + MICROSERVICES   " -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan

# 0. NETTOYAGE (CRUCIAL POUR EVITER LES CONFLITS DE PORTS)
Write-Host "[0/4] Nettoyage des anciennes ressources..." -ForegroundColor Red
kubectl delete namespace projet-apps ns-monitoring ns-data 
kubectl delete deploy --all -n $NS_APP --timeout=10s 2>$null
kubectl delete svc --all -n $NS_APP --timeout=10s 2>$null
# On ne supprime pas ns-data pour ne pas perdre les données SQL à chaque test, 
# sauf si tu le veux vraiment (dans ce cas, décommente la ligne dessous)
# kubectl delete all --all -n $NS_DATA

# 1. NAMESPACES
foreach ($ns in @($NS_APP, $NS_DATA, $NS_MON)) {
    if (!(kubectl get ns $ns --ignore-not-found)) { kubectl create ns $ns }
}

# 2. INFRASTRUCTURE & MONITORING
Write-Host "`n[1/4] Déploiement Infrastructure (SQL, NoSQL, EFK, Prometheus)..." -ForegroundColor Yellow
# On déploie d'abord Metrics Server s'il n'est pas là
try { kubectl apply -f $METRICS_PATH } catch {} 

kubectl apply -f $SQL_PATH -n $NS_DATA
kubectl apply -f $USER_DATA_PATH -n $NS_DATA # <--- AJOUTER CECI
kubectl apply -f $REDIS_PATH -n $NS_DATA
kubectl apply -f $RABBIT_PATH -n $NS_DATA
kubectl apply -f $EFK_PATH -n $NS_MON
kubectl apply -f $PROM_PATH -n $NS_MON
kubectl apply -f $GRAF_PATH -n $NS_MON
kubectl apply -f $INGRESS_PATH -n $NS_ING

Write-Host "Attente de l'infrastructure critique (SQL & RabbitMQ)..." -ForegroundColor Gray
# On attend que les pods soient 'Running'
kubectl wait --for=condition=ready pod -l app=sql-data -n $NS_DATA --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n $NS_DATA --timeout=300s
kubectl wait --for=condition=ready pod -l app=user-data -n $NS_DATA --timeout=300s # <--- AJOUTER CECI
# --- PAUSE CRITIQUE ---
# SQL Server est "Running" mais il met ~30s à initialiser les tables.
# On ajoute une pause ici pour garantir que les APIs ne crashent pas au lancement.
Write-Host "⏳ Pause de 45s pour l'initialisation interne de SQL Server..." -ForegroundColor Magenta
Start-Sleep -Seconds 45

# 3. MICROSERVICES
Write-Host "`n[2/4] Déploiement des APIs et Frontend..." -ForegroundColor Yellow
kubectl apply -f $IDENTITY_PATH -n $NS_APP
kubectl apply -f $JOBS_PATH -n $NS_APP
kubectl apply -f $APPLICANTS_PATH -n $NS_APP
kubectl apply -f $WEB_PATH -n $NS_APP
kubectl apply -f $SECRET_PATH -n $NS_APP

Write-Host "Attente du démarrage des Microservices (Sondes Readiness)..." -ForegroundColor Gray
# Grâce aux readinessProbes dans tes YAML, cette commande attendra que les APIs soient VRAIMENT prêtes
kubectl wait --for=condition=ready pod --all -n $NS_APP --timeout=180s

# 4. OUVERTURE DES ACCÈS (PORT-FORWARD)
Write-Host "`n[3/4] Ouverture des tunnels..." -ForegroundColor Green

# Tunnel pour les APIs (Port 80)
$apps = @{ "webmvc"=8080; "identity-api"=8084; "jobs-api"=8083; "applicants-api"=8081 }
foreach ($name in $apps.Keys) {
    $p = $apps[$name]
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF $name'; kubectl port-forward service/$name ${p}:80 -n $NS_APP"
}

# --- LIGNES POUR LES SERVICES DE DONNÉES & MONITORING ---
# RabbitMQ Management (Interface Web)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF RabbitMQ Admin'; kubectl port-forward service/rabbitmq 15672:15672 -n $NS_DATA"

# Monitoring (Kibana, Prometheus, Grafana)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF Kibana'; kubectl port-forward service/kibana 45001:5601 -n $NS_MON"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF Prometheus'; kubectl port-forward service/prometheus-service 9090:9090 -n $NS_MON"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF Grafana'; kubectl port-forward service/grafana-service 3000:3000 -n $NS_MON"
# Ajoute ceci dans la section "OUVERTURE DES ACCÈS" de ton script
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='MONITOR Redis'; kubectl exec -it redis-0 -n ns-data -- redis-cli monitor"
# 5. DIAGNOSTIC FINAL
Write-Host "`n[4/4] État final du cluster :" -ForegroundColor Yellow
kubectl get pods -n $NS_APP
Write-Host "`nConsommation des ressources :" -ForegroundColor Yellow
try { kubectl top pods -n $NS_APP } catch { Write-Host "Metrics server non prêt, pas grave." -ForegroundColor DarkGray }

Write-Host "`n✅ DÉPLOIEMENT TERMINÉ ! Teste tes URLs maintenant." -ForegroundColor Green