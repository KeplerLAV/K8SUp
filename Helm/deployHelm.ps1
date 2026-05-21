# ==========================================================================================
# SCRIPT DE DÉPLOIEMENT AUTOMATISÉ : COMPATIBILITÉ KUBECTL, OWNERSHIP HELM & MULTI-TUNNELS
# À lancer depuis le dossier : Projet-Conteneurisation-et-Orchestration---YNOV-M2-/Helm
# ==========================================================================================

Clear-Host
Write-Host "========== 1. CRÉATION ET LABELLISATION DES NAMESPACES ==========" -ForegroundColor Cyan
$namespaces = @("projet-apps", "ns-data", "ns-monitoring", "ingress-nginx")

foreach ($ns in $namespaces) {
    # Vérification compatible kubectl (on redirige les erreurs vers le vide)
    kubectl get namespace $ns >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Le namespace '$ns' existe déjà. Annotation pour Helm..." -ForegroundColor Yellow
    } else {
        kubectl create namespace $ns
        Write-Host "Namespace '$ns' créé." -ForegroundColor Green
    }

    # Injection des métadonnées d'appartenance pour éviter le blocage Helm invalid ownership
    kubectl label namespace $ns app.kubernetes.io/managed-by=Helm --overwrite >$null
    kubectl annotate namespace $ns meta.helm.sh/release-name=k8s --overwrite >$null
    kubectl annotate namespace $ns meta.helm.sh/release-namespace=projet-apps --overwrite >$null
}

Write-Host "`n========== 2. DÉPLOIEMENT DU CHART HELM GLOBAL ==========" -ForegroundColor Cyan
Write-Host "Injection de l'architecture applicative et des briques de supervision..." -ForegroundColor Yellow

# Lancement de l'installation standard
helm upgrade --install k8s . --namespace projet-apps

if ($LASTEXITCODE -ne 0) {
    Write-Error "Le déploiement Helm a rencontré une erreur. Arrêt du script."
    Exit
}

Write-Host "`n========== 3. ATTENTE DE LA COUCHE DE DONNÉES (ns-data) ==========" -ForegroundColor Cyan
Write-Host "Attente du statut 'Running' pour SQL Server, Redis et RabbitMQ..." -ForegroundColor Yellow

while ($true) {
    $pods = kubectl get pods -n ns-data -o json | ConvertFrom-Json
    $allReady = $true

    if ($pods.items.Count -eq 0) { $allReady = $false }

    foreach ($pod in $pods.items) {
        if ($pod.status.phase -ne "Running") {
            $allReady = $false
            Write-Host "En attente du composant data: $($pod.metadata.name) ($($pod.status.phase))..." -ForegroundColor Gray
        }
    }

    if ($allReady) {
        Write-Host "Couche de données opérationnelle !" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 5
}

Write-Host "`n========== 4. ATTENTE DE LA COUCHE SUPERVISION (ns-monitoring) ==========" -ForegroundColor Cyan
Write-Host "Attente du statut 'Running' pour la stack de supervision..." -ForegroundColor Yellow

while ($true) {
    $podsMonitor = kubectl get pods -n ns-monitoring -o json | ConvertFrom-Json
    $allMonitorReady = $true

    if ($podsMonitor.items.Count -eq 0) { $allMonitorReady = $false }

    foreach ($pod in $podsMonitor.items) {
        if ($pod.metadata.name -like "*init-job*") {
            if ($pod.status.phase -ne "Succeeded" -and $pod.status.phase -ne "Running") {
                $allMonitorReady = $false
            }
            continue
        }
        if ($pod.status.phase -ne "Running") {
            $allMonitorReady = $false
            Write-Host "En attente du composant monitoring: $($pod.metadata.name) ($($pod.status.phase))..." -ForegroundColor Gray
        }
    }

    if ($allMonitorReady) {
        Write-Host "Toute la stack de supervision (EFK + Prometheus + Grafana) est prête !" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 5
}

Write-Host "`n========== 5. STABILISATION ET REBOOT DES APIS ==========" -ForegroundColor Cyan
kubectl rollout restart deployment -n projet-apps
Write-Host "Attente de 15 secondes pour la stabilisation..." -ForegroundColor Gray
Start-Sleep -Seconds 15

Write-Host "`n========== 6. ACCÈS APPLICATION ET DASHBOARDS ==========" -ForegroundColor Cyan
Write-Host "Ouverture automatique des fenêtres de tunnels réseau (Port-Forward)..." -ForegroundColor Yellow

# 1. Ouverture du tunnel Web (Port 8080)
$WebArgs = "-NoExit -Command `"`$global:Position = `$Host.UI.RawUI; `$Position.WindowTitle='Tunnel : Application Web'; Write-Host 'Lancement du tunnel Web...'; kubectl port-forward deployment/webmvc 8080:80 -n projet-apps`""
Start-Process powershell.exe -ArgumentList $WebArgs

# 2. Ouverture du tunnel Kibana (Port 5601)
$KibanaArgs = "-NoExit -Command `"`$global:Position = `$Host.UI.RawUI; `$Position.WindowTitle='Tunnel : Kibana Logs'; Write-Host 'Lancement du tunnel Kibana...'; kubectl port-forward deployment/kibana 5601:5601 -n ns-monitoring`""
Start-Process powershell.exe -ArgumentList $KibanaArgs

# 3. Ouverture du tunnel Grafana (Port 3000)
$GrafanaArgs = "-NoExit -Command `"`$global:Position = `$Host.UI.RawUI; `$Position.WindowTitle='Tunnel : Grafana Metrics'; Write-Host 'Lancement du tunnel Grafana...'; kubectl port-forward deployment/grafana 3000:3000 -n ns-monitoring`""
Start-Process powershell.exe -ArgumentList $GrafanaArgs

# 4. CORRECTION & ALIGNEMENT : Ouverture du tunnel Prometheus (Port 9090) direct via le Déploiement
$PrometheusArgs = "-NoExit -Command `"`$global:Position = `$Host.UI.RawUI; `$Position.WindowTitle='Tunnel : Prometheus Server'; Write-Host 'Lancement du tunnel Prometheus...'; kubectl port-forward deployment/prometheus 9090:9090 -n ns-monitoring`""
Start-Process powershell.exe -ArgumentList $PrometheusArgs

Write-Host "`n==========================================================================" -ForegroundColor Green
Write-Host " DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ! " -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "Vous pouvez maintenant accéder aux URLs suivantes dans votre navigateur : " -ForegroundColor White
Write-Host " -> Application Web   : http://localhost:8080" -ForegroundColor Cyan
Write-Host " -> Logs (Kibana)     : http://localhost:5601" -ForegroundColor Cyan
Write-Host " -> Métriques (Grafana): http://localhost:3000  (admin / admin)" -ForegroundColor Cyan
Write-Host " -> Prometheus Alerts : http://localhost:9090/alerts" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "Note : Laissez les 4 fenêtres de consoles ouvertes pour maintenir les accès actifs." -ForegroundColor Yellow