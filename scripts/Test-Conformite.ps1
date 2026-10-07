cd "/Users/arsh/Desktop/CSIG/Sécurité Sys Exploitation/patch-management-powershell"
cat > scripts/Test-Conformite.ps1 << 'EOF'
<#
.SYNOPSIS
    Controle de conformite des postes du parc.

.DESCRIPTION
    Partie 4 - Controle de conformite.
    Compare les correctifs installes (Get-HotFix) avec la liste des correctifs
    obligatoires de required-patches.txt, attribue un etat (CONFORME, NON CONFORME,
    INACCESSIBLE), exporte ComplianceReport.csv et calcule le taux global de
    conformite (sans les postes inaccessibles).
#>

$cheminInventaire = Join-Path $PSScriptRoot "..\config\computers.txt"
$cheminPatchesNeeded = Join-Path $PSScriptRoot "..\config\required-patches.txt"

if (-not (Test-Path $cheminPatchesNeeded)) {
    Write-Error "Fichier introuvable : $cheminPatchesNeeded"
    return
}

$inventairepatchesneeded = @(
    Get-Content -Path $cheminPatchesNeeded |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() }
)

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
            Poste               = $nom
            NbKbRequises        = $inventairepatchesneeded.Count
            NbKbManquants       = $null
            ListeKbManquants    = $null
            Etat                = "INACCESSIBLE"
            DateEtHeureControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
            Erreur              = "Ne repond pas au ping"
        }
        $inventairePatches += $infos
    }
    else {
        try {
            $correctifsDistants = Invoke-Command -ComputerName $adresseIP -Credential $cred -ErrorAction Stop -ScriptBlock {
                Get-HotFix | Select-Object HotFixID, Description, InstalledOn, InstalledBy
            }

            $kbInstalles = $correctifsDistants | Select-Object -ExpandProperty HotFixID

            $kbManquants = @( $inventairepatchesneeded | Where-Object { $kbInstalles -notcontains $_ } )

            if ($kbManquants.Count -eq 0) {
                $infosKB = [pscustomobject]@{
                    Poste               = $nom
                    NbKbRequises        = $inventairepatchesneeded.Count
                    NbKbManquants       = $kbManquants.Count
                    ListeKbManquants    = $kbManquants -join ", "
                    Etat                = "CONFORME"
                    DateEtHeureControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
                    Erreur              = $null
                }
            }
            else {
                $infosKB = [pscustomobject]@{
                    Poste               = $nom
                    NbKbRequises        = $inventairepatchesneeded.Count
                    NbKbManquants       = $kbManquants.Count
                    ListeKbManquants    = $kbManquants -join ", "
                    Etat                = "NON CONFORME"
                    DateEtHeureControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
                    Erreur              = $null
                }
            }
            $inventairePatches += $infosKB
        }
        catch {
            $infos = [pscustomobject]@{
                Poste               = $nom
                NbKbRequises        = $inventairepatchesneeded.Count
                NbKbManquants       = $null
                ListeKbManquants    = $null
                Etat                = "INACCESSIBLE"
                DateEtHeureControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
                Erreur              = $_.Exception.Message
            }
            $inventairePatches += $infos
        }
    }
}

$inventaireTrie = $inventairePatches | Sort-Object Poste
$inventaireTrie | Format-Table -AutoSize

$nbConforme = @($inventaireTrie | Where-Object { $_.Etat -eq "CONFORME" }).Count
$nbNonConforme = @($inventaireTrie | Where-Object { $_.Etat -eq "NON CONFORME" }).Count
$nbEvalues = $nbConforme + $nbNonConforme

if ($nbEvalues -eq 0) {
    Write-Host "Aucune machine evaluee"
}
else {
    $taux = [math]::Round(($nbConforme / $nbEvalues) * 100, 2)
    Write-Host "Le taux global de conformite du parc (sans inclure les postes inaccessibles) est de : $taux%"
}

$inventaireTrie | Export-Csv -Path (Join-Path $PSScriptRoot "..\reports\ComplianceReport.csv") -NoTypeInformation -Encoding UTF8

Write-Host "Inventaire exporte vers ComplianceReport.csv"
EOF