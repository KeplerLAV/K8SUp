# Récupérer l'utilisateur avec l'ID 1 (Josh Dillinger)
Invoke-RestMethod -Uri "http://localhost:8084/api/users/1" -Method Get

# Vérifier le nombre de candidatures pour l'utilisateur 1
Invoke-RestMethod -Uri "http://localhost:8084/api/users/applicationcount/1" -Method Get

# Lister tous les candidats
Invoke-RestMethod -Uri "http://localhost:8081/api/applicants" -Method Get

# Récupérer un candidat spécifique (ID 1)
Invoke-RestMethod -Uri "http://localhost:8081/api/applicants/1" -Method Get

# Lister toutes les offres d'emploi
Invoke-RestMethod -Uri "http://localhost:8083/api/jobs" -Method Get

# Récupérer une offre spécifique (ID 1)
Invoke-RestMethod -Uri "http://localhost:8083/api/jobs/1" -Method Get

Site Web Principal : http://localhost:8080

Gestion RabbitMQ : http://localhost:15672 (Login/Pass: guest)