# =========================================================================
# SCRIPT DE DÉPLOIEMENT AUTOMATIQUE HELM / KUBERNETES
# =========================================================================

$ErrorActionPreference = "Stop"
Clear-Host

Write-Host "========================================================="
Write-Host "   INITIALISATION DU DEPLOIEMENT HELM                     "
Write-Host "========================================================="

# -------------------------------------------------------------------------
# STEP 1 : Vérification de l'emplacement du terminal
# -------------------------------------------------------------------------
$CurrentDir = Split-Path -Leaf $PWD

if ($CurrentDir -ne "Helm") {
    if (Test-Path "Helm") {
        Write-Host "Deplacement automatique dans le dossier Helm/..." -ForegroundColor Yellow
        Set-Location "Helm"
    } else {
        Write-Error "Erreur : Le dossier 'Helm' est introuvable depuis votre position actuelle."
        Exit
    }
}

# -------------------------------------------------------------------------
# STEP 2 : Validation des outils et du cluster
# -------------------------------------------------------------------------
Write-Host "`n[1/6] Verification des prerequis systeme..." -ForegroundColor Cyan

try {
    $null = kubectl version --client 2>$null
    $null = helm version 2>$null
} catch {
    Write-Error "Erreur : Kubectl ou Helm n'est pas installe ou accessible dans le PATH."
    Exit
}

try {
    $Nodes = kubectl get nodes -o name 2>$null
    if (-not $Nodes) { throw "Aucun noeud trouve" }
    Write-Host "Cluster actif et pret." -ForegroundColor Green
} catch {
    Write-Error "Erreur : Impossible de joindre le cluster Kubernetes. Verifiez votre contexte actif (Docker Desktop, Minikube, etc.)."
    Exit
}

# -------------------------------------------------------------------------
# STEP 3 : Analyse de la conformite du Chart (Linting)
# -------------------------------------------------------------------------
Write-Host "`n[2/6] Analyse syntaxique du chart (helm lint)..." -ForegroundColor Cyan
$LintResult = helm lint . 2>&1

if ($LastExitCode -ne 0) {
    Write-Host "Erreur détectée lors du linting du Chart :" -ForegroundColor Red
    Write-Output $LintResult
    Exit
}
Write-Host "Chart Helm valide." -ForegroundColor Green

# -------------------------------------------------------------------------
# STEP 4 : Preparation des espaces de noms (Namespaces) et Déploiement
# -------------------------------------------------------------------------
Write-Host "`n[3/6] Preparation des espaces de noms (Namespaces)..." -ForegroundColor Cyan

$RequiredNamespaces = @("projet-apps", "ns-data", "ns-monitoring")
foreach ($ns in $RequiredNamespaces) {
    $NsExists = kubectl get namespace $ns --ignore-not-found=true 2>$null
    if (-not $NsExists) {
        Write-Host "Creation du namespace : $ns..." -ForegroundColor Yellow
        kubectl create namespace $ns >$null
    } else {
        Write-Host "Le namespace '$ns' est dejà present." -ForegroundColor Gray
    }
}

# Nettoyage préventif des anciens tunnels de port-forward Windows
Get-Process -Name "kubectl" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "`nLancement du deploiement de la release Helm 'k8s'..." -ForegroundColor Cyan
helm upgrade --install k8s . --namespace projet-apps --create-namespace

if ($LastExitCode -ne 0) {
    Write-Error "Echec de l'installation ou de la mise a jour de la release Helm."
    Exit
}
Write-Host "Release appliquee avec succes." -ForegroundColor Green

# -------------------------------------------------------------------------
# STEP 5 : Attente de l'infrastructure critique et des Microservices
# -------------------------------------------------------------------------
Write-Host "`n[4/6] Synchronisation et surveillance de la couche de donnees..." -ForegroundColor Cyan

Write-Host "Attente du demarrage de SQL Server, RabbitMQ et User Data (Duree max: 300s)..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=sql-data -n ns-data --timeout=300s 2>$null
kubectl wait --for=condition=ready pod -l app=rabbitmq -n ns-data --timeout=300s 2>$null
kubectl wait --for=condition=ready pod -l app=user-data -n ns-data --timeout=300s 2>$null

Write-Host "Pause de 45 secondes pour l'initialisation interne de SQL Server..." -ForegroundColor Magenta
Start-Sleep -Seconds 45

Write-Host "Validation de la stabilisation du composant webmvc (Duree max: 60s)..." -ForegroundColor Gray
kubectl rollout status deployment/webmvc -n projet-apps --timeout=60s

Write-Host "Attente finale des sondes de preparation des microservices (Readiness)..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod --all -n projet-apps --timeout=180s 2>$null

# -------------------------------------------------------------------------
# STEP 6 : Ouverture automatique des accès (Port-Forwarding)
# -------------------------------------------------------------------------
Write-Host "`n[5/6] Ouverture automatique des tunnels reseaux..." -ForegroundColor Green

# 1. Tunnels pour les APIs et l'interface Web (Espace applicatif)
$apps = @{ "webmvc"=8080; "identity-api"=8084; "jobs-api"=8083; "applicants-api"=8081 }
foreach ($name in $apps.Keys) {
    $p = $apps[$name]
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF $name'; kubectl port-forward service/$name ${p}:80 -n projet-apps"
}

# 2. Tunnel pour RabbitMQ Management
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF RabbitMQ Admin'; kubectl port-forward service/rabbitmq 15672:15672 -n ns-data"

# 3. Tunnels pour la stack de Monitoring et d'Observabilite
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF Kibana'; kubectl port-forward service/kibana 45001:5601 -n ns-monitoring"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF Prometheus'; kubectl port-forward service/prometheus-service 9090:9090 -n ns-monitoring"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='PF Grafana'; kubectl port-forward service/grafana-service 3000:3000 -n ns-monitoring"

# 4. Activation du moniteur Redis CLI en direct
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='MONITOR Redis'; kubectl exec -it redis-0 -n ns-data -- redis-cli monitor"

# -------------------------------------------------------------------------
# STEP 7 : Synthese visuelle finale du cluster
# -------------------------------------------------------------------------
Write-Host "`n[6/6] Synthese de l'etat des espaces reseaux..." -ForegroundColor Cyan
Write-Host "---------------------------------------------------------"

Write-Host "`n[Pods - Applications]" -ForegroundColor Yellow
kubectl get pods -n projet-apps

Write-Host "`n[Pods - Stockage & Donnees]" -ForegroundColor Yellow
kubectl get pods -n ns-data --allow-missing-template-keys=true 2>$null

Write-Host "`n[Pods - Monitoring]" -ForegroundColor Yellow
kubectl get pods -n ns-monitoring --ignore-not-found=true

Write-Host "`n[Points d'entree reseau - Ingress]" -ForegroundColor Yellow
kubectl get ingress -n projet-apps --ignore-not-found=true

Write-Host "`n========================================================="
Write-Host "   FIN DU DEPLOIEMENT - TUNNELS ET MONITORING OPTIMISES  "
Write-Host "========================================================="