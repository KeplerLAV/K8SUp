$message = '{"time":"26/Jan/2026:20:43:00 +0000", "message":"Test depuis mon PC via PowerShell", "service":"debug"}'
$server = "127.0.0.1"
$port = 5044

try {
    $client = New-Object System.Net.Sockets.TcpClient($server, $port)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.WriteLine($message)
    $writer.Flush()
    $writer.Close()
    $client.Close()
    Write-Host "Message envoyé avec succès à Fluent-Bit !" -ForegroundColor Green
} catch {
    Write-Host "Erreur : Impossible de contacter Fluent-Bit. Vérifie que le port-forward est actif." -ForegroundColor Red
}