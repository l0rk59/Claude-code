# Lends this computer's memory to a PrivateLM cluster (Windows).
#
# Put this file in the folder of the llama.cpp release named in the app
# (Phone cluster > Add a computer), next to ggml-rpc-server.exe, then
# right-click it and choose "Run with PowerShell", or run:
#
#     powershell -ExecutionPolicy Bypass -File .\start-worker.ps1
#     powershell -ExecutionPolicy Bypass -File .\start-worker.ps1 -Port 50060
#
# Windows asks once whether to let it through the firewall: allow it on
# private networks. The connection has no password: only run it on a
# network you trust.
#
# Messages are in French without accents: Windows PowerShell reads a script
# without a byte-order mark as ANSI, which garbles accented letters.
param([int]$Port = 50052)

$server = Join-Path $PSScriptRoot 'ggml-rpc-server.exe'
if (-not (Test-Path $server)) {
    Write-Host "ggml-rpc-server.exe introuvable."
    Write-Host "Placez ce script dans le dossier de llama.cpp (la version indiquee par"
    Write-Host "l'application), a cote de ggml-rpc-server.exe, puis relancez-le."
    exit 1
}

# The addresses phones on the same network can use.
$addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -ExpandProperty IPAddress

Write-Host "PrivateLM : cet ordinateur rejoint le cluster."
Write-Host ""
if ($addresses) {
    Write-Host "Dans l'application : Cluster de telephones > Principal > Ajouter un ordinateur, puis saisissez :"
    foreach ($address in $addresses) { Write-Host "    ${address}:$Port" }
} else {
    Write-Host "Aucune adresse reseau trouvee : verifiez que l'ordinateur est connecte au Wi-Fi."
}
Write-Host ""
Write-Host "Laissez cette fenetre ouverte. Ctrl+C pour arreter."
Write-Host ""

# -c keeps the model's layers on disk, so they cross the Wi-Fi only once.
& $server -H 0.0.0.0 -p $Port -c
