<#
.SYNOPSIS
    Notification de l'administrateur en cas d'anomalie dans le dernier rapport de securite.

.DESCRIPTION
    Partie 7 : Notification.

    Le script lit le dernier rapport CSV genere par PatchManager.ps1 et cherche
    les postes NON CONFORME ou INACCESSIBLE. S'il n'y en a aucun, il se termine
    sans rien envoyer. Sinon, il envoie un mail a l'administrateur avec le
    rapport en piece jointe et note le resultat dans le journal.

    Aucun mot de passe n'est ecrit dans le script : si un fichier d'identifiants
    existe (cree avec Get-Credential | Export-Clixml), il est utilise, sinon
    l'envoi se fait sans authentification (serveur de test local).
#>

# Chemins relatifs a l'emplacement du script (scripts\ -> racine du projet)
$racine = Split-Path $PSScriptRoot -Parent
$dossierRapports = Join-Path $racine "reports"
$cheminLog = Join-Path $dossierRapports "PatchManager.log"
$cheminIdentifiants = Join-Path $racine "config\smtp-cred.xml"

if (-not (Test-Path $dossierRapports)) {
    New-Item -ItemType Directory -Path $dossierRapports | Out-Null
}

# Parametres du serveur de messagerie
$serveurSmtp = "localhost"
$portSmtp = 25
$expediteur = "patchmanager@entreprise.local"
$destinataire = "admin@entreprise.local"

function Write-Log {
    param(
        [string]$Message
    )

    $horodatage = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $ligne = "$horodatage ; $Message"
    Add-Content -Path $cheminLog -Value $ligne -Encoding UTF8
}

# Recherche du dernier rapport CSV
$dernierRapport = Get-ChildItem -Path $dossierRapports -Filter "RapportSecurite_*.csv" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $dernierRapport) {
    Write-Log "ERREUR ; Aucun rapport trouve, notification non envoyee"
    Write-Error "Aucun rapport RapportSecurite_*.csv dans $dossierRapports"
    return
}

$rapport = Import-Csv -Path $dernierRapport.FullName

# Detection des anomalies
$anomalies = @($rapport | Where-Object { $_.EtatConformite -ne "CONFORME" })

if ($anomalies.Count -eq 0) {
    Write-Log "Aucune anomalie detectee, pas de notification"
    Write-Host "Aucune anomalie : pas de notification."
    return
}

# Chiffres du message
$dateControle = ($rapport[0].DateEtHeureControle -split " ")[0]
$nbControles = @($rapport).Count
$nbNonConformes = @($rapport | Where-Object { $_.EtatConformite -eq "NON CONFORME" }).Count
$nbInaccessibles = @($rapport | Where-Object { $_.EtatConformite -eq "INACCESSIBLE" }).Count

# Objet et corps du message (e accent aigu = 0xE9, o accent circonflexe = 0xF4)
$eAigu = [char]0xE9
$oCirc = [char]0xF4
$aGrave = [char]0xE0

$objetMail = "[PATCH MANAGEMENT] Anomalies d${eAigu}tect${eAigu}es"

$corps = @"
Date du contr${oCirc}le : $dateControle

Postes contr${oCirc}l${eAigu}s     : $nbControles
Postes non conformes : $nbNonConformes
Postes inaccessibles : $nbInaccessibles


"@

foreach ($poste in $anomalies) {
    $corps += "$($poste.Poste) : $($poste.EtatConformite)`r`n"

    if ($poste.EtatConformite -eq "NON CONFORME") {
        $kbListe = $poste.ListeKbManquants -split ", "
        foreach ($kb in $kbListe) {
            $corps += "       $kb manquante`r`n"
        }
    }

    $corps += "`r`n"
}

# Parametres de l'envoi
$parametresMail = @{
    SmtpServer  = $serveurSmtp
    Port        = $portSmtp
    From        = $expediteur
    To          = $destinataire
    Subject     = $objetMail
    Body        = $corps
    Attachments = $dernierRapport.FullName
    Encoding    = [System.Text.Encoding]::UTF8
    ErrorAction = "Stop"
}

# Identifiants : lus depuis un fichier chiffre, jamais ecrits dans le script
if (Test-Path $cheminIdentifiants) {
    $parametresMail["Credential"] = Import-Clixml -Path $cheminIdentifiants
    $parametresMail["UseSsl"] = $true
}

# Envoi et trace dans le journal
try {
    Send-MailMessage @parametresMail
Write-Log "Notification envoy${eAigu}e ${aGrave} $destinataire"
 Write-Host "Notification envoyee a $destinataire"
}
catch {
    Write-Log "ERREUR ; Notification non envoy${eAigu}e"
    Write-Log "ERREUR ; $($_.Exception.Message)"
    Write-Host "Notification non envoyee : $($_.Exception.Message)"
}