# --- CONFIGURATION MISE A JOUR ---
$DOCKER_USER = "warshall"
$VERSION = "v3.0.0"
$IMAGES = @(
    # @{ Name = "webmvc";         Path = "Web/Dockerfile" },
    # @{ Name = "applicants-api"; Path = "Services/Applicants.Api/Dockerfile" },
    # @{ Name = "jobs-api";       Path = "Services/Jobs.Api/Dockerfile" },
    # @{ Name = "identity-api";   Path = "Services/Identity.Api/Dockerfile" }
    # @{ Name = "user-data";   Path = "Database/docker-user-data/Dockerfile" }
    # CORRECTION ICI : Le dossier s'appelle "Database" sur ton image
    @{ Name = "sql-data";       Path = "Database/Dockerfile" } 
    # @{ Name = "kibana";       Path = "logging/kibana/Dockerfile" } 
    # @{ Name = "fluent-bit";       Path = "logging/fluent-bit/Dockerfile" } 
    # @{ Name = "elasticsearch";       Path = "logging/elasticsearch/Dockerfile" } 
)

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   BUILD & PUSH TOTAL (RACINE COMME CONTEXTE)        " -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan

docker login

foreach ($Image in $IMAGES) {
    $FullImageName = "$DOCKER_USER/$($Image.Name):$VERSION"
    Write-Host "`n[*] Construction de : $FullImageName" -ForegroundColor Cyan

    # CORRECTION : On utilise le chemin complet du Dockerfile (-f) 
    # mais on garde le contexte sur la racine (.)
    docker build -t $FullImageName -f $($Image.Path) .

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[+] Build réussi, envoi vers Docker Hub..." -ForegroundColor Green
        docker push $FullImageName
    } else {
        Write-Host "[ERREUR] Échec sur $($Image.Name). Vérifie la casse des fichiers !" -ForegroundColor Red
    }
}