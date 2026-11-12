# Runs a model on this computer for the phones of the network (Windows).
# The phones chat with it from PrivateLM; nothing leaves the network.
#
# Put this file in the folder of a llama.cpp release, next to
# llama-server.exe, then run:
#
#     powershell -ExecutionPolicy Bypass -File .\start-serveur.ps1 -Model modele.gguf
#     powershell -ExecutionPolicy Bypass -File .\start-serveur.ps1 -Model modele.gguf -Port 8081
#
# With a single .gguf file in the folder, -Model can be left out. Anything
# after these options is passed to llama-server as is.
#
# Windows asks once whether to let it through the firewall: allow it on
# private networks. The server has no password: only run it on a network
# you trust.
#
# Messages are in French without accents: Windows PowerShell reads a script
# without a byte-order mark as ANSI, which garbles accented letters.
param(
    [string]$Model = "",
    [int]$Port = 8080,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$More
)

$server = Join-Path $PSScriptRoot 'llama-server.exe'
if (-not (Test-Path $server)) {
    Write-Host "llama-server.exe introuvable."
    Write-Host "Placez ce script dans le dossier de llama.cpp, a cote de llama-server.exe,"
    Write-Host "puis relancez-le."
    exit 1
}

if (-not $Model) {
    # No model named: take the only one in the folder, if there is exactly one.
    $models = @(Get-ChildItem -Path $PSScriptRoot -Filter *.gguf)
    if ($models.Count -eq 1) {
        $Model = $models[0].FullName
    } else {
        Write-Host "Indiquez le fichier du modele :  -Model modele.gguf"
        exit 1
    }
}
if (-not (Test-Path $Model)) {
    Write-Host "Fichier de modele introuvable : $Model"
    exit 1
}

# The addresses phones on the same network can use.
$addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -ExpandProperty IPAddress

Write-Host "PrivateLM : cet ordinateur fait tourner $(Split-Path $Model -Leaf)."
Write-Host ""
Write-Host "Dans l'application : Modeles > Cloud > Un ordinateur de votre reseau."
Write-Host "La recherche le trouve seule. Sinon, saisissez son adresse :"
foreach ($address in $addresses) { Write-Host "    ${address}:$Port" }
Write-Host ""
Write-Host "Laissez cette fenetre ouverte. Ctrl+C pour arreter."
Write-Host ""

& $server -m $Model --host 0.0.0.0 --port $Port @More
