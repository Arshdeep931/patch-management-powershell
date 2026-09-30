# Journal de bord

Une ligne (ou quelques-unes) par seance de travail : ce qui a ete fait, les problemes rencontres et comment ils ont ete resolus. Sert de base aux parties "tests effectues" et "resultats obtenus" du rapport.

## 28/09/2026

- Demarrage du projet. Creation du depot GitHub prive (patch-management-powershell) et de la structure de dossiers (scripts, config, docs, reports, logs).
- Choix initial de l'environnement de virtualisation : UTM sur Mac (Apple Silicon M2 Pro).
- Redaction de computers.txt (plan d'adressage ADMIN01/PC01/PC02) et du script scripts/Test-ParcDisponibilite.ps1 (Partie 1, point 3 : lecture de computers.txt et affichage nom/IP/disponibilite).
- Bascule d'UTM vers VMware Fusion pour la creation des VM.
- Erreur rencontree : premiere ISO telechargee en x64, incompatible avec l'architecture ARM de l'hote ("architecture X86 incompatible"). Corrige en telechargeant l'ISO officielle Windows 11 ARM64 depuis le site Microsoft.
- Reponse a 6 des 7 questions de theorie de la Partie 1 (role de WinRM, commande d'activation, ports, pare-feu, Test-Connection vs Test-WSMan, interet de verifier l'accessibilite avant une commande distante). La derniere (risques de securite de PowerShell Remoting sans restriction) est laissee pour apres avoir manipule WinRM en pratique.s

30/09/2026 - Partie 1 terminée : Enter-PSSession testé avec succès (session interactive sur PC01), confirmation que le fix Sysprep a bien résolu le problème d'accès distant. Passage à la Partie 2.