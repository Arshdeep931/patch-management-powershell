<#
.SYNOPSIS
    Inventaire du parc : lit computers.txt, teste la disponibilite de chaque
    machine, et collecte a distance 8 informations systeme + 3 informations
    de patch management sur les machines accessibles.

.DESCRIPTION
    Partie 2 - Inventaire du parc.
#>

$cheminInventaire = Join-Path $PSScriptRoot "..\config\computers.txt"

if (-not (Test-Path $cheminInventaire)) {
    Write-Error "Fichier introuvable : $cheminInventaire"
    return
}

$lignes = Get-Content -Path $cheminInventaire

$cred = Get-Credential -Message "Identifiants du compte admin pour PowerShell Remoting"

$inventaire = @()

foreach ($machine in $lignes) {

    if ([string]::IsNullOrWhiteSpace($machine)) {
        continue
    }

    $champs = $machine -split ";"
    $nom = $champs[0].Trim()
    $adresseIP = $champs[1].Trim()

    $disponible = Test-Connection -ComputerName $adresseIP -Count 1 -Quiet -ErrorAction SilentlyContinue

    if (-not $disponible) {
        $objetMachine = [PSCustomObject]@{
            Nom              = $nom
            IP               = $adresseIP
            Etat             = "Inaccessible"
            Modele           = $null
            VersionBios      = $null
            Windows          = $null
            Architecture     = $null
            DernierDemarrage = $null
            RAM_Go           = $null
            EspaceDisque_Go  = $null
            NombreMAJ        = $null
            DerniereMAJ      = $null
            EtatWU           = $null
            Erreur           = "Machine ne repond pas au ping"
        }
    }
    else {
        try {
            $infosDistantes = Invoke-Command -ComputerName $adresseIP -Credential $cred -ErrorAction Stop -ScriptBlock {
                $cs   = Get-CimInstance Win32_ComputerSystem
                $bios = Get-CimInstance Win32_BIOS
                $os   = Get-CimInstance Win32_OperatingSystem
                $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

                $hotfixes    = Get-HotFix
                $derniereMAJ = $hotfixes | Sort-Object InstalledOn -Descending | Select-Object -First 1
                $serviceWU   = Get-Service -Name wuauserv

                [PSCustomObject]@{
                    Nom              = $cs.Name
                    Modele           = $cs.Model
                    VersionBios      = $bios.SMBIOSBIOSVersion
                    Windows          = $os.Caption
                    Architecture     = $os.OSArchitecture
                    DernierDemarrage = $os.LastBootUpTime
                    RAM_Go           = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
                    EspaceDisque_Go  = [math]::Round($disk.FreeSpace / 1GB, 2)
                    NombreMAJ        = $hotfixes.Count
                    DerniereMAJ      = $derniereMAJ.InstalledOn
                    EtatWU           = $serviceWU.Status
                }
            }

            $objetMachine = [PSCustomObject]@{
                Nom              = $infosDistantes.Nom
                IP               = $adresseIP
                Etat             = "Accessible"
                Modele           = $infosDistantes.Modele
                VersionBios      = $infosDistantes.VersionBios
                Windows          = $infosDistantes.Windows
                Architecture     = $infosDistantes.Architecture
                DernierDemarrage = $infosDistantes.DernierDemarrage
                RAM_Go           = $infosDistantes.RAM_Go
                EspaceDisque_Go  = $infosDistantes.EspaceDisque_Go
                NombreMAJ        = $infosDistantes.NombreMAJ
                DerniereMAJ      = $infosDistantes.DerniereMAJ
                EtatWU           = $infosDistantes.EtatWU
                Erreur           = $null
            }
        }
        catch {
            $objetMachine = [PSCustomObject]@{
                Nom              = $nom
                IP               = $adresseIP
                Etat             = "Erreur"
                Modele           = $null
                VersionBios      = $null
                Windows          = $null
                Architecture     = $null
                DernierDemarrage = $null
                RAM_Go           = $null
                EspaceDisque_Go  = $null
                NombreMAJ        = $null
                DerniereMAJ      = $null
                EtatWU           = $null
                Erreur           = $_.Exception.Message
            }
        }
    }

    $inventaire += $objetMachine
}

$inventaire | Format-Table -AutoSize

$inventaire | Export-Csv -Path (Join-Path $PSScriptRoot "..\reports\InventaireParc.csv") -NoTypeInformation -Encoding UTF8

Write-Host "Inventaire exporte vers InventaireParc.csv"