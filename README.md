# Patch Management en PowerShell

Projet du cours Sécurité des systèmes (EFREI Paris, enseignant : Salim Benayoune).

Auteurs : Arshdeep Singh et Fahed Tadrist.

Le projet contrôle à distance l'état des mises à jour Windows d'un parc de postes depuis un poste d'administration. Les scripts vérifient quels postes répondent, collectent un inventaire et la liste des correctifs, comparent avec les correctifs obligatoires, produisent un rapport de sécurité (CSV et HTML) et préviennent l'administrateur par mail uniquement en cas d'anomalie.

## Environnement de test

Deux machines virtuelles Windows 11 (groupe de travail, pas de domaine, sans accès à Internet) :

| Machine | Adresse IP | Rôle |
|---|---|---|
| ADMIN01 | 192.168.10.10 | Poste d'administration, lance les scripts |
| PC01 | 192.168.10.11 | Poste administré |

PC02 (192.168.10.12) et PC03 (192.168.10.13) sont écrits dans `config/computers.txt` mais n'existent pas. Ils servent à tester le cas d'un poste inaccessible. La communication passe par WinRM (PowerShell Remoting, port 5985).

## Contenu du dépôt

```
scripts/
  Test-ParcDisponibilite.ps1   Partie 1 : disponibilité des postes
  Get-InventaireParc.ps1       Partie 2 : inventaire du parc
  Get-InventairePatches.ps1    Partie 3 : correctifs installés
  Test-Conformite.ps1          Partie 4 : contrôle de conformité
  PatchManager.ps1             Partie 6 : rapport de sécurité (CSV, HTML, journal)
  Send-Notification.ps1        Partie 7 : notification par mail
  Start-SmtpTest.ps1           Partie 7 : serveur SMTP de test
config/
  computers.txt                Un poste par ligne, format Nom;AdresseIP
  required-patches.txt         Un correctif obligatoire (KB) par ligne
docs/
  journal-de-bord.md           Journal de bord du projet
  questions-partie1.md         Réponses aux questions (Partie 1)
  questions-partie4.md         Réponses aux questions (Partie 4)
  questions-partie7.md         Réponses aux questions (Partie 7)
  questions-partie8.md         Sécurisation de la solution (Partie 8)
  environnement.md             Description de l'environnement de test
reports/                       Rapports et journal générés (non versionnés)
```

Le sujet ne comporte pas de partie 5.

## Prérequis

- Windows PowerShell sur le poste d'administration.
- PowerShell Remoting activé sur les postes administrés (`Enable-PSRemoting`).
- Le poste d'administration doit connaître les postes administrés : sans domaine, leur adresse est ajoutée à TrustedHosts.
- Un compte autorisé à se connecter à distance. Les scripts demandent le mot de passe au lancement, aucun mot de passe n'est écrit dans le code.

## Utilisation

Depuis PowerShell sur ADMIN01, dans le dossier des scripts :

```powershell
.\Test-ParcDisponibilite.ps1    # quels postes répondent
.\Get-InventaireParc.ps1        # inventaire système, exporté en InventaireParc.csv
.\Get-InventairePatches.ps1     # correctifs installés, exportés en PatchesInventory.csv
.\Test-Conformite.ps1           # CONFORME, NON CONFORME ou INACCESSIBLE par poste
.\PatchManager.ps1              # rapport complet : CSV, HTML et journal
.\Send-Notification.ps1         # mail à l'administrateur s'il y a une anomalie
```

Pour tester la notification sans vrai serveur de messagerie, lancer d'abord `.\Start-SmtpTest.ps1` dans une autre fenêtre. Il écoute sur localhost:25 et enregistre les mails reçus dans un dossier `mails-recus`.

Pour obtenir un cas NON CONFORME, on peut ajouter une KB qui n'existe pas sur le poste (par exemple KB5054999) dans `config/required-patches.txt`.

## Résultats produits

Les rapports sont écrits dans `reports/` avec la date dans leur nom :

- `RapportSecurite_AAAAMMJJ_HHMMSS.csv` : un objet de 12 champs par poste ;
- `RapportSecurite_AAAAMMJJ_HHMMSS.html` : rapport lisible avec synthèse et détail par poste ;
- `PatchManager.log` : journal horodaté de chaque étape.

La synthèse comprend le nombre de postes, accessibles, inaccessibles, conformes, non conformes, le total de KB manquantes et le taux de conformité. Les postes inaccessibles ne comptent pas dans ce taux.

## Sécurité

- Aucun mot de passe dans les scripts. Un éventuel mot de passe de messagerie est lu depuis `config/smtp-cred.xml`, créé avec `Export-Clixml` (chiffrement DPAPI). Ce fichier est dans le `.gitignore`.
- Le dossier `reports/` n'est pas versionné, car il contient la liste des postes vulnérables.
- La règle de pare-feu WinRM de PC01 est restreinte à l'adresse d'ADMIN01.
- Un compte dédié à moindre privilège (svc-patch) a été testé. Il ne peut pas lire la liste des correctifs (Get-HotFix renvoie 0), la solution serait JEA, étudiée dans `docs/questions-partie8.md`.

## Limites

- Un seul poste réel dans le parc de test.
- Le compte admin est encore utilisé pour la démonstration.
- WinRM reste en HTTP et en NTLM, faute de domaine.
- Send-MailMessage est marqué comme obsolète par Microsoft.
- Le script de notification renvoie le même mail à chaque exécution tant que l'anomalie dure.

## Livrables

Le rapport écrit et la vidéo de démonstration sont déposés sur Moodle.
