# Partie 8 : Sécurisation de la solution

Environnement de test : ADMIN01 (192.168.10.10), le poste d'administration, et PC01 (192.168.10.11), le poste administré. Les deux machines sont en groupe de travail, sans domaine.

## 1. Risques de PowerShell Remoting et de WinRM

PowerShell Remoting permet de lancer des commandes sur une autre machine. C'est exactement ce qui le rend dangereux : si quelqu'un en prend le contrôle, il peut s'en servir pour attaquer tout le parc. Voici les risques principaux que nous avons retenus.

Le premier est le vol ou la devinette du mot de passe. Une session WinRM s'ouvre avec un compte administrateur, donc si son mot de passe est faible, un attaquant peut se connecter à distance et faire ce qu'il veut avec les droits admin. Dans notre labo, le mot de passe de PC01 est très simple, ce qui n'est acceptable que pour un test.

Le deuxième est le trafic qui n'est pas chiffré par défaut. WinRM écoute en HTTP sur le port 5985. Dans un domaine, Kerberos protège l'authentification, mais en groupe de travail, comme chez nous, on est en NTLM et la protection est plus faible. Pour tout chiffrer, il faudrait passer en HTTPS (port 5986) avec un certificat.

Le troisième est la liste TrustedHosts. Sans domaine, il faut déclarer les machines de confiance. Si on met `*`, on accepte n'importe quelle machine, et une fausse machine pourrait se faire passer pour PC01 et récupérer nos identifiants. Il vaut mieux lister les adresses exactes.

Le quatrième est le déplacement latéral. Si un poste ou un compte admin est compromis, WinRM permet de rebondir vers les autres machines avec un outil normal de Windows, sans rien installer, ce qui est difficile à repérer.

Le cinquième est le manque de traces. Par défaut, les commandes lancées à distance laissent peu d'informations. Sans journalisation (Script Block Logging, transcription), on ne sait pas qui a exécuté quoi.

Le dernier est la surface d'attaque : le service écoute en permanence sur le réseau, et si le pare-feu l'ouvre à tout le monde, n'importe quelle machine peut essayer de s'y connecter.

## 2. Qui peut ouvrir une session distante

Pour le vérifier, nous avons interrogé PC01 avec Get-LocalGroupMember, Get-LocalUser et Get-PSSessionConfiguration.

Le groupe Administrateurs de PC01 contient trois comptes : admin, Administrateur et PC001. Get-LocalUser montre que le compte Administrateur, le compte intégré de Windows, est désactivé, ce qui est une bonne chose. Il reste donc deux comptes administrateurs actifs, admin et PC001. Le groupe « Utilisateurs de gestion à distance » était vide au départ.

La configuration de session Microsoft.PowerShell autorise les Administrateurs, les Utilisateurs de gestion à distance et le groupe INTERACTIF. Les sessions microsoft.powershell.workflow et microsoft.powershell32 ont des droits similaires.

Notre conclusion est que l'accès distant n'est pas limité au strict nécessaire. Notre script utilise le compte admin, qui est administrateur complet, alors qu'il ne fait que lire des informations. Si ce compte est volé, l'attaquant a la main totale sur le poste. De plus, PC001 est un second compte administrateur actif qui ne sert à rien dans le projet mais qui peut quand même ouvrir une session distante.

Pour améliorer ça, on peut utiliser un compte dédié au patch management (point 3), retirer les droits d'administrateur aux comptes qui n'en ont pas besoin, et restreindre la session distante avec JEA (point 7).

## 3. Limiter les privilèges du compte de patch management

Pour appliquer le moindre privilège, nous avons créé sur PC01 un compte local dédié, svc-patch. Il n'est pas administrateur, il est seulement dans le groupe « Utilisateurs de gestion à distance », qui permet d'ouvrir une session distante. Nous l'avons testé depuis ADMIN01 avec Invoke-Command, en le comparant au compte admin.

Premier test, avec les droits par défaut : l'ouverture de session fonctionne (whoami renvoie pc01\svc-patch) et la lecture du service Windows Update aussi (Get-Service wuauserv). En revanche, Get-HotFix et Get-CimInstance Win32_OperatingSystem donnent « Accès refusé », parce que l'espace de noms WMI root\cimv2 est réservé aux administrateurs.

Nous avons donc ajouté à svc-patch, sur root\cimv2 (dans wmimgmt.msc, onglet Sécurité), uniquement les droits « Activer le compte » et « Appel à distance autorisé », appliqués à l'espace de noms et à ses sous-espaces. Après ça, Get-CimInstance Win32_OperatingSystem fonctionne avec svc-patch. Mais Get-HotFix renvoie 0 correctif, sans aucune erreur, alors que le compte admin en renvoie 5 sur le même poste.

Ce qu'on en retient, c'est que la liste des correctifs installés n'est lisible que par un administrateur. Surtout, un compte trop limité ne fait pas forcément d'erreur : il peut donner une mauvaise réponse (0 KB), et dans notre rapport un poste serait classé NON CONFORME à tort. Nous n'avons donc pas basculé PatchManager.ps1 sur svc-patch, et nous avons gardé le compte admin pour la démonstration.

La vraie solution pour respecter le moindre privilège est JEA (point 7) : un point de connexion limité qui n'expose que les commandes nécessaires, en lecture seule, et qui s'exécute côté serveur avec un compte virtuel. Le compte qui se connecte reste alors sans droits d'administration.

## 4. Accès aux fichiers produits

Nous avons vérifié avec icacls les droits sur PatchManager.log, sur les rapports CSV (RapportSecurite_*.csv) et sur le dossier qui les contient, sur ADMIN01. Seuls trois comptes y ont accès, tous en contrôle total : SYSTEM, le groupe Administrateurs et le compte admin. Les droits sont hérités du dossier. Le groupe Utilisateurs n'apparaît pas, donc un utilisateur standard de la machine ne peut pas lire ces fichiers.

La limite est que le compte admin peut modifier ou supprimer le journal et les rapports. Dans une vraie exploitation, il faudrait ranger les fichiers dans un dossier dédié (reports\), couper l'héritage avec icacls /inheritance:r, donner la lecture seule aux auditeurs et l'écriture au compte du script seulement (voir point 8).

## 5. Règles du pare-feu Windows pour WinRM

Nous avons listé les règles de pare-feu WinRM sur PC01 avec Get-NetFirewallRule, Get-NetFirewallAddressFilter et Get-NetFirewallPortFilter. La règle WINRM-HTTP-In-TCP (profil Public, port 5985, depuis le sous-réseau local) est désactivée. La règle WINRM-HTTP-In-TCP-NoScope (profils Domaine et Privé, port 5985, depuis n'importe quelle adresse) est activée.

Le réseau de PC01 est en profil Privé, donc c'est la règle NoScope qui s'applique. Elle acceptait les connexions WinRM depuis n'importe quelle adresse IP, alors que seul ADMIN01 en a besoin. C'était trop permissif : n'importe quelle machine du réseau pouvait essayer de se connecter à PC01.

Nous avons donc restreint cette règle à l'adresse 192.168.10.10 (ADMIN01) avec Set-NetFirewallRule -RemoteAddress. Après ce changement, Test-WSMan et Invoke-Command depuis ADMIN01 fonctionnent toujours, PatchManager.ps1 produit le même rapport, et les autres adresses du réseau n'ont plus accès au port 5985 de PC01.

## 6. Mode d'authentification et Kerberos

Nous avons relu la configuration WinRM des deux machines (WSMan:\localhost\Service\Auth sur PC01 et WSMan:\localhost\Client\Auth sur ADMIN01).

Sur PC01, côté serveur, Basic est désactivé, Kerberos et Negotiate sont activés, Certificate et CredSSP sont désactivés, et AllowUnencrypted est à false. Sur ADMIN01, côté client, Negotiate, Kerberos, Digest, Certificate et Basic sont activés, CredSSP est désactivé et AllowUnencrypted est à false. TrustedHosts contient seulement 192.168.10.11.

Nos deux machines ne sont pas dans un domaine. C'est pour ça que Windows refusait la connexion tant que l'adresse de PC01 n'était pas dans TrustedHosts. Sans domaine, il n'y a pas de contrôleur de domaine pour délivrer les tickets, donc Kerberos ne peut pas servir, et Negotiate se replie sur NTLM.

Côté points positifs, Basic (mot de passe presque en clair) est désactivé sur le serveur et le trafic non chiffré est interdit. Avec Negotiate, le contenu des messages WinRM est chiffré même en HTTP. Côté points faibles, NTLM est moins solide que Kerberos (attaques par relais, mot de passe attaquable hors ligne), et le client n'authentifie pas le serveur, d'où TrustedHosts. Il serait aussi préférable de désactiver Basic côté client.

Kerberos est préférable dès que les machines sont dans un domaine Active Directory. Il authentifie les deux côtés (le client vérifie qu'il parle au vrai serveur, ce que NTLM ne fait pas), n'envoie jamais le mot de passe sur le réseau parce qu'il utilise des tickets temporaires, résiste mieux aux attaques par relais et par rejeu, permet l'authentification unique et évite de gérer TrustedHosts. En production, nous utiliserions donc un domaine avec Kerberos, ou à défaut WinRM en HTTPS avec un certificat.

## 7. Just Enough Administration (JEA)

JEA est une fonction de PowerShell qui permet de donner à un utilisateur le droit de lancer seulement certaines commandes à distance, sans le faire administrateur. C'est le moindre privilège appliqué aux commandes : on ne donne pas une session d'administration complète, mais un point d'entrée limité.

Pour le mettre en place, on crée un fichier de capacités de rôle (.psrc, avec New-PSRoleCapabilityFile) qui liste les cmdlets, fonctions et paramètres autorisés. On crée ensuite un fichier de configuration de session (.pssc, avec New-PSSessionConfigurationFile) qui associe un groupe d'utilisateurs à ce rôle et qui met le mode du langage en restreint. On l'enregistre sur le poste avec Register-PSSessionConfiguration. La session s'exécute ensuite avec un compte virtuel élevé, créé pour l'occasion : le compte qui se connecte n'a pas de droits d'administrateur, mais la session peut quand même lire ce qui est protégé. Toutes les commandes peuvent aussi être journalisées.

Dans notre projet, JEA résoudrait le problème du point 3. Le compte svc-patch ne pourrait pas lire la liste des KB tout seul, mais un point de connexion « PatchReader » pourrait autoriser uniquement Get-Service (limité à wuauserv), Get-HotFix et Get-CimInstance sur Win32_OperatingSystem. Le script s'y connecterait avec Invoke-Command -ConfigurationName PatchReader. Si le compte était volé, l'attaquant ne pourrait lancer aucune autre commande, donc pas d'installation et pas de suppression de fichiers. Nous n'avons pas mis JEA en place dans notre labo, par manque de temps : nous avons étudié le principe et nous l'avons appliqué à notre cas.

## 8. Stratégie de conservation des rapports et des journaux

Les rapports et le journal contiennent des informations sensibles. La liste des postes et des correctifs manquants est, pour un attaquant, une carte des machines vulnérables. Voici la stratégie que nous proposons.

Pour éviter la modification non autorisée, il faut ranger les fichiers dans un dossier dédié (reports\) et couper l'héritage des droits avec icacls /inheritance:r. Le compte du script ne devrait avoir que le droit d'ajouter des lignes, les administrateurs la lecture, et personne d'autre aucun droit. Le journal ne devrait être ouvert qu'en ajout, avec Add-Content. On peut aussi calculer l'empreinte de chaque rapport avec Get-FileHash et la stocker à part, pour détecter une modification, et activer l'audit des accès aux fichiers de Windows pour savoir qui a ouvert ou modifié quoi.

Pour éviter la suppression, il faut sauvegarder les rapports et les journaux sur un emplacement distant en écriture seule, ou sur un serveur de journaux (SIEM), pour qu'un attaquant qui prend ADMIN01 ne puisse pas effacer ses traces. Il faut aussi retirer le droit de suppression aux comptes courants. Pour la durée de conservation, nous proposons 12 mois pour les journaux, et 90 jours pour les rapports détaillés, avec ensuite une archive des synthèses seulement. La rotation est automatique : un nouveau fichier par jour, ce qui est déjà le cas pour les rapports grâce à la date dans le nom.

Pour éviter l'exposition d'informations sensibles, il faut limiter la lecture aux administrateurs et aux auditeurs, chiffrer le disque (BitLocker) et les archives, et ne pas envoyer les rapports par un canal non chiffré. Dans notre script de notification, le rapport part en pièce jointe, donc le serveur SMTP devrait utiliser TLS. Enfin, il ne faut jamais mettre de mots de passe dans les journaux : notre script ne journalise que des messages d'erreur, jamais d'identifiants.
