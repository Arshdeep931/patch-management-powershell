# Journal de bord

Une ligne (ou quelques-unes) par seance de travail : ce qui a ete fait, les problemes rencontres et comment ils ont ete resolus. Sert de base aux parties "tests effectues" et "resultats obtenus" du rapport.

## 28/09/2026

- Demarrage du projet. Creation du depot GitHub prive (patch-management-powershell) et de la structure de dossiers (scripts, config, docs, reports, logs).
- Choix initial de l'environnement de virtualisation : UTM sur Mac (Apple Silicon M2 Pro).
- Redaction de computers.txt (plan d'adressage ADMIN01/PC01/PC02) et du script scripts/Test-ParcDisponibilite.ps1 (Partie 1, point 3 : lecture de computers.txt et affichage nom/IP/disponibilite).
- Bascule d'UTM vers VMware Fusion pour la creation des VM.
- Erreur rencontree : premiere ISO telechargee en x64, incompatible avec l'architecture ARM de l'hote ("architecture X86 incompatible"). Corrige en telechargeant l'ISO officielle Windows 11 ARM64 depuis le site Microsoft.
- Reponse a 6 des 7 questions de theorie de la Partie 1 (role de WinRM, commande d'activation, ports, pare-feu, Test-Connection vs Test-WSMan, interet de verifier l'accessibilite avant une commande distante). La derniere (risques de securite de PowerShell Remoting sans restriction) est laissee pour apres avoir manipule WinRM en pratique.
- Partie 1 terminee : Enter-PSSession teste avec succes (session interactive sur PC01). Le fix Sysprep a bien resolu le probleme d'acces distant.

## 29/09/2026

- Partie 2 : script Get-InventaireParc.ps1. Pour chaque poste de computers.txt, test du ping puis collecte a distance avec Invoke-Command (modele, BIOS, Windows, architecture, dernier demarrage, RAM, espace disque, nombre de mises a jour, etat de Windows Update). Les postes qui ne repondent pas sont notes "Inaccessible" et les erreurs WinRM sont gerees avec try/catch. Export en CSV.

## 30/09/2026

- Partie 3 : script Get-InventairePatches.ps1. Recuperation des correctifs installes (Get-HotFix) sur chaque poste, avec un resume par machine : nombre de correctifs et dernier correctif installe (Group-Object).
- Partie 4 : script Test-Conformite.ps1 et fichier config/required-patches.txt. Un poste est CONFORME seulement si toutes les KB requises sont installees, NON CONFORME s'il en manque, INACCESSIBLE s'il ne repond pas. Calcul du taux de conformite sans compter les postes inaccessibles. Reponses aux questions dans docs/questions-partie4.md.
- Probleme rencontre : comparaison des listes de KB avec -notcontains (le tableau doit etre a gauche), corrige apres plusieurs essais.

## 07/10/2026

- Partie 6 (rapport de securite) : creation de scripts/PatchManager.ps1. Le script lit computers.txt et required-patches.txt, teste le ping puis se connecte en WinRM une seule fois par poste (un seul Invoke-Command) pour recuperer Windows, le dernier demarrage, l'etat de Windows Update et les KB installees. Le calcul de conformite se fait ensuite en local.
- Pour chaque poste, un objet de 12 champs (les 11 demandes par le sujet + une colonne Erreur) : etat CONFORME / NON CONFORME / INACCESSIBLE. Les postes inaccessibles ne comptent pas dans le taux de conformite.
- Ajout de la synthese globale (7 indicateurs), de la section "postes necessitant une intervention", d'un rapport CSV et d'un rapport HTML dans reports/, et du journal PatchManager.log (fonction Write-Log).
- Problemes rencontres : un second Invoke-Command dans le scriptblock ne marchait pas (les variables locales n'existent pas sur la machine distante), corrige en recuperant les KB une fois et en comparant en local. Faute de frappe sur $htmlPostes qui laissait la section "Detail par poste" vide dans le HTML. Collage du script en double dans le fichier a cause d'un mauvais copier-coller, corrige en repartant d'un fichier propre.
- Tests : avec la fausse KB5054999 dans required-patches.txt, PC01 est NON CONFORME (taux 0 %). Sans elle, PC01 est CONFORME (taux 100 %). PC02 et PC03 restent INACCESSIBLE dans les deux cas (VM eteintes).
- Commit 9f4e779 : scripts/PatchManager.ps1.