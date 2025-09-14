# ------------------------------------------------------------
# Script para mostrar comandos de actualización de throughput en Azure CosmosDB
# Autor: Luppass
# Fecha: 2025-05-29
# ------------------------------------------------------------

[CmdletBinding()]
param()

# Modo estricto y captura de errores
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Definición manual de cuentas y umbrales
$entries = @(
    [pscustomobject]@{ AccountName = 'mongoaccount1'; ResourceGroup = 'azureCLiTest'; TargetRU = 1500 },
    [pscustomobject]@{ AccountName = 'mongoaccount2'; ResourceGroup = 'azureCLiTest'; TargetRU = 500 },
    [pscustomobject]@{ AccountName = 'mongoaccount3'; ResourceGroup = 'azureCLiTest'; TargetRU = 1500 }
)

# Funciones de logging
function Get-Timestamp { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }
function Info       { param($m) Write-Output "[$(Get-Timestamp)] [INFO]  $m" }
function Success    { param($m) Write-Output "[$(Get-Timestamp)] [ OK ]  $m" }
function WarningLog { param($m) Write-Warning "[$(Get-Timestamp)] [WARN]  $m" }
function ErrorLog   { param($m) Write-Error   "[$(Get-Timestamp)] [ERROR] $m" }

# Autenticación con Managed Identity
try {
    Info 'Autenticando con Managed Identity...'
    Connect-AzAccount -Identity | Out-Null
    az login --identity | Out-Null
    Success 'Autenticación correcta'
} catch {
    ErrorLog "Fallo de autenticación: $($_.Exception.Message)"
    throw
}

# Función que muestra SOLO los comandos de escritura (update)
function Show-UpdateCommands {
    param(
        [ValidateSet('Database','Collection')] [string]$Scope,
        [string]$AccountName,
        [string]$ResourceGroup,
        [string]$DatabaseName,
        [string]$CollectionName,
        [int]   $TargetRU,
        [int]   $CurrentRU,
        [ValidateSet('Manual','Autoscale')] [string]$Mode
    )

    # Ajuste de valores mínimos y múltiplos para autoscale/manual
    if ($Mode -eq 'Autoscale') {
        if ($TargetRU -lt 1000) {
            WarningLog "El valor mínimo para modo 'Autoscale' es 1000 RU/s. Se usará 1000."
            $UsedRU = 1000
        } elseif ($TargetRU % 1000 -ne 0) {
            $adjusted = [math]::Floor($TargetRU / 1000) * 1000
            WarningLog "El valor '$TargetRU' no es múltiplo de 1000. Se ajusta a $adjusted RU/s."
            $UsedRU = $adjusted
        } else {
            $UsedRU = $TargetRU
        }
    } elseif ($TargetRU -lt 400) {
        WarningLog "El valor mínimo para modo 'Manual' es 400 RU/s. Se usará 400."
        $UsedRU = 400
    } else {
        $UsedRU = $TargetRU
    }

    # Solo se permite reducción de throughput
    if ($UsedRU -ge $CurrentRU) {
        Info "→ Valor ajustado no implica reducción (actual: $CurrentRU, propuesto: $UsedRU) → sin cambios."
        return
    }

    $base = if ($Scope -eq 'Database') {
        "az cosmosdb mongodb database throughput update --account-name $AccountName --resource-group $ResourceGroup --name $DatabaseName"
    } else {
        "az cosmosdb mongodb collection throughput update --account-name $AccountName --resource-group $ResourceGroup --database-name $DatabaseName --name $CollectionName"
    }
    $paramRU = if ($Mode -eq 'Manual') { '--throughput' } else { '--max-throughput' }
    $cmd     = "$base $paramRU $UsedRU"
    Info "→ [COMENTADO] Ejecutar: $cmd"
}

# Recorrido de cuentas → bases de datos → colecciones
foreach ($entry in $entries) {
    $account   = $entry.AccountName
    $resource  = $entry.ResourceGroup
    $threshold = [int]$entry.TargetRU

    Write-Output "`n==================== Cuenta: $account (RG: $resource) ===================="
    Info "Umbral deseado: $threshold RU/s (Mínimos: Manual=400, Autoscale=1000)"

    $databases = az cosmosdb mongodb database list --account-name $account --resource-group $resource --output tsv --query '[].name'
    if (-not $databases) {
        Info "No se encontraron bases de datos MongoDB."
        continue
    }
    foreach ($db in $databases) {
        Info "Base de datos: $db"
        $hasDedicated = $false
        try {
            $raw = az cosmosdb mongodb database throughput show --account-name $account --resource-group $resource --name $db --output json 2>$null
            if ($raw) {
                $dbTh = $raw | ConvertFrom-Json
                $hasDedicated = $true
            }
        } catch {}

        if ($hasDedicated) {
            Info "→ Throughput a nivel de BASE DE DATOS"
            if ($dbTh.resource.autoscaleSettings -and $dbTh.resource.autoscaleSettings.maxThroughput) {
                $mode = 'Autoscale'; $current = [int]$dbTh.resource.autoscaleSettings.maxThroughput
            } elseif ($dbTh.resource.throughput) {
                $mode = 'Manual'; $current = [int]$dbTh.resource.throughput
            } else {
                WarningLog "No se pudo determinar throughput en BBDD $db"
                continue
            }
            Info "Modo: $mode; Actual: $current RU/s"
            Show-UpdateCommands -Scope 'Database' -AccountName $account -ResourceGroup $resource -DatabaseName $db -TargetRU $threshold -CurrentRU $current -Mode $mode
            continue
        }

        Info "→ Throughput a nivel de COLECCIONES"
        $cols = az cosmosdb mongodb collection list --account-name $account --resource-group $resource --database-name $db --output tsv --query '[].name'
        if (-not $cols) {
            Info "No se encontraron colecciones en BBDD $db."
            continue
        }
        foreach ($coll in $cols) {
            Info "Colección: $coll"
            try {
                $rawC = az cosmosdb mongodb collection throughput show --account-name $account --resource-group $resource --database-name $db --name $coll --output json 2>$null
            } catch {}
            if ($rawC) {
                $colTh = $rawC | ConvertFrom-Json
            } else {
                Info "Sin throughput dedicado en colección $coll"
                continue
            }
            if ($colTh.resource.autoscaleSettings -and $colTh.resource.autoscaleSettings.maxThroughput) {
                $mode = 'Autoscale'; $current = [int]$colTh.resource.autoscaleSettings.maxThroughput
            } elseif ($colTh.resource.throughput) {
                $mode = 'Manual'; $current = [int]$colTh.resource.throughput
            } else {
                WarningLog "No se pudo determinar throughput en colección $coll"
                continue
            }
            Info "Modo: $mode; Actual: $current RU/s"
            Show-UpdateCommands -Scope 'Collection' -AccountName $account -ResourceGroup $resource -DatabaseName $db -CollectionName $coll -TargetRU $threshold -CurrentRU $current -Mode $mode
        }
    }
}
Success 'Proceso de visualización de comandos completado.'