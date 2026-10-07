<#
.SYNOPSIS
    Audit de securite du parc : verifie que chaque poste a bien les correctifs requis et genere un rapport pour l'administrateur.

.DESCRIPTION
    Partie 6 : Rapport de securite.

    Le script lit la liste des postes (config\computers.txt) et la liste des KB
    obligatoires (config\required-patches.txt). Pour chaque poste, il teste le
    ping puis se connecte en WinRM pour recuperer la version de Windows, la date
    du dernier demarrage, l'etat du service Windows Update et les KB installees.
    Il compare ensuite les KB installees aux KB requises : le poste est CONFORME
    si toutes les KB sont presentes, NON CONFORME s'il en manque, et INACCESSIBLE
    s'il ne repond pas (ping ou WinRM).

    A la fin, il affiche la synthese du parc (nombre de postes, taux de
    conformite sans compter les postes inaccessibles) et la liste des postes qui
    necessitent une intervention. Il genere un rapport CSV et un rapport HTML
    dans le dossier reports, et note chaque etape dans PatchManager.log.


#>

$dateFichier = Get-Date -Format "yyyyMMdd_HHmmss"
$racine = Split-Path $PSScriptRoot -Parent

$cheminInventaire = Join-Path $racine "config\computers.txt"
$cheminPatchesNeeded = Join-Path $racine "config\required-patches.txt"

$dossierReports = Join-Path $racine "reports"
if (-not (Test-Path $dossierReports)) {
    New-Item -ItemType Directory -Path $dossierReports | Out-Null
}

$cheminLog = Join-Path $dossierReports "PatchManager.log"
$cheminRapportCsv = Join-Path $dossierReports "RapportSecurite_$dateFichier.csv"
$cheminRapportHtml = Join-Path $dossierReports "RapportSecurite_$dateFichier.html"

function Write-Log {
    param(
        [string]$Message
    )

    $horodatage = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $ligne = "$horodatage ; $Message"
    Add-Content -Path $cheminLog -Value $ligne -Encoding UTF8
}

Write-Log "Debut de l'audit"


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

    Write-Log "$nom ; Inaccessible (ping)"
        $infos = [pscustomobject]@{
               Poste               = $nom
          IP                  = $adresseIP
          Accessibilite       = "Inaccessible"
           Windows             = $null
            DernierDemarrage    = $null
            EtatWU              = $null
            NbKbRequises        = $inventairepatchesneeded.Count
           NbKbManquants       = $null
           ListeKbManquants    = $null
            EtatConformite      = "INACCESSIBLE"
            DateEtHeureControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        Erreur           = "Ne repond pas au ping"
        }
        $inventairePatches += $infos
    }
    else { Write-Log "$nom ; Accessible"

        try {
        $infosDistantes = Invoke-Command -ComputerName $adresseIP -Credential $cred -ErrorAction Stop -ScriptBlock {
        $serviceWU = (Get-Service -Name wuauserv).Status
        $os = Get-CimInstance Win32_OperatingSystem
        $hotfixes = (Get-HotFix).HotFixID     
        $infos = [pscustomobject]@{
            Windows = $os.Caption
            DernierDemarrage = $os.LastBootUpTime
            EtatWU = $serviceWU
            KbInstalles = $hotfixes }
$infos
}

            $kbInstalles = $infosDistantes.KbInstalles

            $kbManquants = @( $inventairepatchesneeded | Where-Object { $kbInstalles -notcontains $_ } )

            if ($kbManquants.Count -eq 0) {$etatConformite = "CONFORME"}


            

       else  {$etatConformite = "NON CONFORME"}
    Write-Log "$nom ; $etatConformite ; $($kbManquants -join ', ')"
    $infosKB = [pscustomobject]@{
            Poste               = $nom
          IP                  = $adresseIP
          Accessibilite       = "Accessible"
           Windows             = $infosDistantes.Windows
            DernierDemarrage    = $infosDistantes.DernierDemarrage
            EtatWU              = $infosDistantes.EtatWU
            NbKbRequises        = $inventairepatchesneeded.Count
           NbKbManquants       = $kbManquants.Count
           ListeKbManquants    = $kbManquants -join ", "
            EtatConformite      = $etatConformite
            DateEtHeureControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
            Erreur              = $null
                    
            }
    $inventairePatches += $infosKB

        }
        catch {
        Write-Log "$nom ; WinRM inaccessible ; $($_.Exception.Message)"
            $infos = [pscustomobject]@{
                Poste               = $nom
          IP                  = $adresseIP
          Accessibilite       = "Inaccessible"
           Windows             = $null
            DernierDemarrage    = $null
            EtatWU              = $null
            NbKbRequises        = $inventairepatchesneeded.Count
           NbKbManquants       = $null
           ListeKbManquants    = $null
            EtatConformite      = "INACCESSIBLE"
            DateEtHeureControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
            Erreur           = $_.Exception.Message

            }
            $inventairePatches += $infos
        }
    }
}

$inventaireTrie = $inventairePatches | Sort-Object Poste
$inventaireTrie | Format-List 
$nbConforme =@($inventaireTrie | Where-Object {$_.EtatConformite -eq "CONFORME"}).Count
$nbNonConforme =@($inventaireTrie | Where-Object {$_.EtatConformite -eq "NON CONFORME"}).Count
$nbEvalues = $nbConforme + $nbNonConforme
              

$taux = 0
         if (($nbEvalues) -eq 0){Write-Host "Aucune machine evaluee"}
         else {$taux = [math]::Round(($nbConforme/$nbEvalues)*100 , 2)
            Write-Host "Le taux global de conformite du parc (sans inclure les postes inaccessibles) est de : $taux%"  }
              
$synthese = [pscustomobject]@{
               TotalPostes              = @($inventaireTrie).Count
          PostesAccessibles       = @($inventaireTrie | Where-Object {$_.Accessibilite -eq "Accessible"}).Count
          PostesInaccessibles      = @($inventaireTrie | Where-Object {$_.Accessibilite -eq "Inaccessible"}).Count
           PostesConformes          = $nbConforme
            PostesNonConformes       = $nbNonConforme
            TotalKbManquants         = ($inventaireTrie | Measure-Object -Property NbKbManquants -Sum).sum
            TauxConformite           = $taux
        }
        
$synthese | Format-List

$interventions = @($inventaireTrie | Where-Object {$_.EtatConformite -ne "CONFORME"} | Select-Object Poste, IP, EtatConformite, ListeKbManquants, Erreur)

if ($interventions.Count -eq 0){Write-Host "Aucune intervention necessaire"}
else {
    Write-Host "Postes necessitant une intervention : "
    $interventions | Format-Table -AutoSize
    }


$htmlPostes = $inventaireTrie | ConvertTo-Html -Fragment | Out-String

$htmlSynthese = $synthese | ConvertTo-Html -As List -Fragment | Out-String

if ($interventions.Count -eq 0) {
    $htmlInterventions = "<p>Aucune intervention necessaire.</p>"
}
else {
    $htmlInterventions = $interventions | ConvertTo-Html -Fragment | Out-String
}

$dateRapport = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$pageHtml = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Rapport de securite - Patch Management</title>
<style>
body { font-family: Arial, sans-serif; margin: 30px; }
h1 { color: #1f3a5f; }
h2 { color: #1f3a5f; margin-top: 30px; }
table { border-collapse: collapse; margin-top: 10px; }
th, td { border: 1px solid #999; padding: 6px 10px; text-align: left; }
th { background-color: #1f3a5f; color: white; }
</style>
</head>
<body>
<h1>Rapport de securite : Patch Management</h1>
<p>Controle realise le $dateRapport</p>

<h2>Synthese</h2>
$htmlSynthese

<h2>Postes necessitant une intervention</h2>
$htmlInterventions

<h2>Detail par poste</h2>
$htmlPostes
</body>
</html>
"@

$pageHtml | Out-File -FilePath $cheminRapportHtml -Encoding UTF8
Write-Log "Rapport HTML genere : $cheminRapportHtml"


$inventaireTrie | Export-Csv -Path $cheminRapportCsv -NoTypeInformation -Encoding UTF8
Write-Log "Rapport genere : $cheminRapportCsv"
Write-Log "Fin de l'audit"
Write-Host "Rapport exporte vers $cheminRapportCsv"