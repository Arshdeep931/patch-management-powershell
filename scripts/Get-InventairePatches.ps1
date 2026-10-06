<#
.SYNOPSIS
    Inventaire des correctifs installes sur chaque machine du parc.

.DESCRIPTION
    Partie 3 - Inventaire des correctifs.
#>

$cheminInventaire = Join-Path $PSScriptRoot "..\config\computers.txt"

if (-not (Test-Path $cheminInventaire)) {
    Write-Error "Fichier introuvable : $cheminInventaire"
    return
}

$lignes = Get-Content -Path $cheminInventaire
$cred = Get-Credential -Message "Identifiants du compte admin pour PowerShell Remoting"
$inventairePatches = @()

foreach ($machine in $lignes) {

    if ([string]::IsNullOrWhiteSpace($machine)) {
        continue
    }

    $champs = $machine -split ";"
    $nom = $champs[0].Trim()
    $adresseIP = $champs[1].Trim()

    $disponible = Test-Connection -ComputerName $adresseIP -Count 1 -Quiet -ErrorAction SilentlyContinue

    if (-not $disponible) {
        $infos = [pscustomobject]@{
            Poste            = $nom
            IP               = $adresseIP
            KB               = $null
            Description      = $null
            DateInstallation = $null
            Etat             = "Inaccessible"
        }
        $inventairePatches += $infos
    }
    else {
        try {
            $correctifsDistants = Invoke-Command -ComputerName $adresseIP -Credential $cred -ErrorAction Stop -ScriptBlock {
                Get-HotFix | Select-Object HotFixID, Description, InstalledOn, InstalledBy
                
            }

            foreach ($correctif in $correctifsDistants) {
                $infos = [pscustomobject]@{
                    Poste            = $nom
                    IP               = $adresseIP
                    KB               = $correctif.HotFixID
                    Description      = $correctif.Description
                    DateInstallation = $correctif.InstalledOn
                    Etat             = "Accessible"
                }
                $inventairePatches += $infos

            }
        }
        catch {
            $infos = [pscustomobject]@{
                Poste            = $nom
                IP               = $adresseIP
                KB               = $null
                Description      = $null
                DateInstallation = $null
                Etat             = "Erreur : $($_.Exception.Message)"
            }
            $inventairePatches += $infos
        }
    }
}
$inventaireTrie = $inventairePatches | Sort-Object Poste, @{Expression = "DateInstallation"; Descending = $true}
$inventaireTrie | Format-Table -AutoSize

$inventaireTrie | Export-Csv -Path (Join-Path $PSScriptRoot "..\reports\PatchesInventory.csv") -NoTypeInformation -Encoding UTF8

Write-Host "Inventaire exporte vers PatchesInventory.csv"