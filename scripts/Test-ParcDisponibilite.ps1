    <#
    .SYNOPSIS
        Lit le fichier computers.txt et affiche, pour chaque machine,
        son nom, son adresse IP et son etat de disponibilite.

    .DESCRIPTION
        Partie 1 - Preparation de l'environnement.
        Le fichier computers.txt contient une ligne par machine, au format :
        Nom;AdresseIP
    #>

    # Chemin du fichier d'inventaire, relatif a l'emplacement du script.
    # $PSScriptRoot contient le dossier ou se trouve CE script (scripts/),
    # on remonte donc d'un niveau (..) pour aller dans config/.
    $cheminInventaire = Join-Path $PSScriptRoot "..\config\computers.txt"

    # Verifie que le fichier existe avant d'aller plus loin.
    if (-not (Test-Path $cheminInventaire)) {
        Write-Error "Fichier introuvable : $cheminInventaire"
        return
    }

    # Lit chaque ligne du fichier. Get-Content retourne un tableau de chaines.
    $lignes = Get-Content -Path $cheminInventaire

    # On boucle sur chaque ligne pour la traiter individuellement.
    foreach ($machine in $lignes) {

        # Ignore les lignes vides (utile si le fichier a une ligne vide a la fin).
        if ([string]::IsNullOrWhiteSpace($machine)) {
            continue
        }

        # Separe la ligne au niveau du point-virgule.
        # -split renvoie un tableau : [0] = nom, [1] = IP.
        $champs = $machine -split ";"
        $nom = $champs[0].Trim()
        $adresseIP  = $champs[1].Trim()

        # Test-Connection envoie des paquets ICMP (comme un ping).
        # -Count 1 : un seul paquet, pour aller vite.
        # -Quiet   : renvoie directement $true/$false au lieu d'un objet detaille.
        # -ErrorAction SilentlyContinue : evite d'afficher une erreur rouge
        # si la machine ne repond pas (ce n'est pas un bug, juste un etat a afficher).
        $disponible = Test-Connection -ComputerName $adresseIP -Count 1 -Quiet -ErrorAction SilentlyContinue

        # On construit un texte lisible pour l'etat.
        $etat = if ($disponible) { "Disponible" } else { "Indisponible" }

        # Affichage formate pour chaque machine.
        Write-Host "$nom`t$adresseIP`t$etat"
    }