<#
.SYNOPSIS
    Mini serveur SMTP de test : recoit les mails sur localhost:25, les enregistre
    en .eml, puis cree une version lisible (.txt) et extrait la piece jointe.
    Sert uniquement a tester Send-Notification.ps1.
#>

# Les mails recus sont ranges dans reports\mails-recus (dossier ignore par git)
$racine = Split-Path $PSScriptRoot -Parent
$dossier = Join-Path $racine "reports\mails-recus"
if (-not (Test-Path $dossier)) {
    New-Item -ItemType Directory -Path $dossier -Force | Out-Null
}

function Enregistrer-MailLisible {
    param(
        [string]$Brut,
        [string]$Base
    )

    # Objet (encode en base64 UTF-8, parfois sur plusieurs lignes)
    $enteteSujet = [regex]::Match($Brut, '(?s)Subject:\s*(.+?)\r?\nContent-Type').Groups[1].Value
    $octetsSujet = New-Object System.Collections.Generic.List[byte]
    foreach ($m in [regex]::Matches($enteteSujet, '=\?utf-8\?B\?(.+?)\?=')) {
        $octetsSujet.AddRange([Convert]::FromBase64String($m.Groups[1].Value))
    }
    $sujet = [System.Text.Encoding]::UTF8.GetString($octetsSujet.ToArray())
    if (-not $sujet) { $sujet = $enteteSujet.Trim() }

    $de = [regex]::Match($Brut, '(?m)^From:\s*([^\r\n]+)').Groups[1].Value
    $a = [regex]::Match($Brut, '(?m)^To:\s*([^\r\n]+)').Groups[1].Value
    $date = [regex]::Match($Brut, '(?m)^Date:\s*([^\r\n]+)').Groups[1].Value

    # Corps du message
    $blocCorps = [regex]::Match($Brut, '(?s)text/plain; charset=utf-8\s+Content-Transfer-Encoding: base64\s+(.+?)\s*----boundary').Groups[1].Value
    $corps = ""
    if ($blocCorps) {
        $corps = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($blocCorps -replace '\s', '')))
    }

    # Piece jointe
    $nomPj = [regex]::Match($Brut, '(?m)name=([^\r\n;\s]+)').Groups[1].Value
    $blocPj = [regex]::Match($Brut, '(?s)Content-Disposition: attachment\s+(.+?)\s*----boundary').Groups[1].Value
    $infoPj = "aucune"
    if ($nomPj -and $blocPj) {
        $cheminPj = "${Base}_$nomPj"
        [System.IO.File]::WriteAllBytes($cheminPj, [Convert]::FromBase64String(($blocPj -replace '\s', '')))
        $infoPj = $nomPj
    }

    $texte = "Objet : $sujet`r`nDe : $de`r`nA : $a`r`nDate : $date`r`nPiece jointe : $infoPj`r`n`r`n$corps"
    [System.IO.File]::WriteAllText("$Base.txt", $texte, [System.Text.UTF8Encoding]::new($true))

    Write-Host ""
    Write-Host $texte
}

$ecouteur = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 25)
$ecouteur.Start()
Write-Host "Serveur de test a l'ecoute sur localhost:25 (Ctrl+C pour arreter)"

try {
    while ($true) {

        if (-not $ecouteur.Pending()) {
            Start-Sleep -Milliseconds 200
            continue
        }

        $client = $ecouteur.AcceptTcpClient()
        $flux = $client.GetStream()
        $lecteur = [System.IO.StreamReader]::new($flux, [System.Text.Encoding]::UTF8)
        $ecrivain = [System.IO.StreamWriter]::new($flux, [System.Text.UTF8Encoding]::new($false))
        $ecrivain.NewLine = "`r`n"
        $ecrivain.AutoFlush = $true

        $ecrivain.WriteLine("220 localhost Serveur de test")

        $enData = $false
        $message = [System.Text.StringBuilder]::new()

        while ($true) {
            $ligne = $lecteur.ReadLine()
            if ($null -eq $ligne) { break }

            if ($enData) {
                if ($ligne -eq ".") {
                    $enData = $false
                    $base = Join-Path $dossier ("mail_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
                    [System.IO.File]::WriteAllText("$base.eml", $message.ToString(), [System.Text.Encoding]::UTF8)
                    Write-Host "Mail recu, enregistre : $base.eml"
                    try {
                        Enregistrer-MailLisible -Brut $message.ToString() -Base $base
                    }
                    catch {
                        Write-Host "Version lisible impossible : $($_.Exception.Message)"
                    }
                    $ecrivain.WriteLine("250 OK message recu")
                }
                else {
                    [void]$message.AppendLine($ligne)
                }
                continue
            }

            $commande = $ligne.ToUpper()

            if ($commande.StartsWith("DATA")) {
                $ecrivain.WriteLine("354 Terminer avec une ligne contenant seulement un point")
                $enData = $true
            }
            elseif ($commande.StartsWith("QUIT")) {
                $ecrivain.WriteLine("221 Au revoir")
                break
            }
            else {
                $ecrivain.WriteLine("250 OK")
            }
        }

        $client.Close()
    }
}
finally {
    $ecouteur.Stop()
    Write-Host "Serveur arrete."
}