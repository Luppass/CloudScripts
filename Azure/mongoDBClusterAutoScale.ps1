#!/usr/bin/env pwsh

[CmdletBinding()]
param()

# Salir ante errores y activar modo estricto
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Línea en blanco para separación visual
Write-Output ""

# Funciones de logging (usando Write-Output para Azure Automation)
function Get-Timestamp {
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
}

function Info {
    param ([string]$Message)
    $timestamp = Get-Timestamp
    Write-Output "[$timestamp] [INFO]  $Message"
}

function Success {
    param ([string]$Message)
    $timestamp = Get-Timestamp
    Write-Output "[$timestamp] [ OK ]  $Message"
}

function WarningLog {
    param ([string]$Message)
    $timestamp = Get-Timestamp
    Write-Output "[$timestamp] [WARN]  $Message"
}

function ErrorLog {
    param ([string]$Message)
    $timestamp = Get-Timestamp
    Write-Error "[$timestamp] [ERROR] $Message"
}

# Parámetros (ajustar según necesidad)
$TagKey   = 'env'
$TagValue = 'dev'
$NewTier  = 'M10'
$NewDisk  = 32

# Autenticación Managed Identity
Info "Iniciando sesión con Identidad Administrada..."
try {
    Connect-AzAccount -Identity | Out-Null
    az login --identity | Out-Null
    Success "Autenticado con Identidad Administrada"
} catch {
    ErrorLog "Error al autenticar: $($_.Exception.Message)"
    throw $_.Exception
}

# Instalar/Actualizar extensión cosmosdb-preview
Info "Instalando/extensión 'cosmosdb-preview'..."

az extension add --name cosmosdb-preview --allow-preview true | Out-Null
Success "Extensión cosmosdb-preview instalada"

# Inicio del proceso
Info "Iniciando actualización de clústeres vCore"
Info "Etiqueta buscada: $TagKey=$TagValue"

# Listado de clústeres
Info "Buscando clústeres con etiqueta $TagKey=$TagValue..."
$clusterLines = az resource list --tag "$TagKey=$TagValue" --query "[?type=='Microsoft.DocumentDB/mongoClusters'].{name:name,rg:resourceGroup}" -o tsv

$clusters = @()
foreach ($line in $clusterLines) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        $parts = $line -split "\t"
        $clusters += [PSCustomObject]@{ Name = $parts[0]; RG = $parts[1] }
    }
}

if ($clusters.Count -eq 0) {
    WarningLog "No se encontraron clústeres con etiqueta $TagKey=$TagValue."
    exit 1
}

Success "Encontrados $($clusters.Count) clúster(es):"
foreach ($cluster in $clusters) {
    Write-Output "  • $($cluster.Name) (RG: $($cluster.RG))"
}

# Actualización de cada clúster
foreach ($cluster in $clusters) {
    Info "Preparando actualización del clúster $($cluster.Name) (RG: $($cluster.RG)) al tier '$NewTier' con disco de $NewDisk GB"
    try {
        az cosmosdb mongocluster update `
            --resource-group $($cluster.RG) `
            --cluster-name $($cluster.Name) `
            --shard-node-tier $NewTier `
            --shard-node-disk-size-gb $NewDisk | Out-Null
        Success "'$($cluster.Name)' escalado a Tier=$NewTier, Disco=${NewDisk}GB"
    } catch {
        ErrorLog "Falló la actualización de '$($cluster.Name)'"
    }
}

Success "Proceso completado."
# Línea en blanco al final
Write-Output ""