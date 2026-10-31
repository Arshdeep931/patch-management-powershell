Partie 8 : Securisation de la solution

Environnement de test : ADMIN01 (192.168.10.10, poste d'administration) et PC01 (192.168.10.11, poste administre), tous deux en groupe de travail (pas de domaine).

1. Risques de PowerShell Remoting / WinRM

PowerShell Remoting permet de lancer des commandes sur une autre machine, donc si quelqu'un en prend le controle, il peut s'en servir pour attaquer tout le parc. Les principaux risques que j'ai identifies :

Vol ou devinette du mot de passe. Une session WinRM s'ouvre avec un compte administrateur. Si son mot de passe est faible (dans mon labo PC01 a un mot de passe tres simple, ce qui n'est acceptable que pour un test), un attaquant peut ouvrir une session distante et executer ce qu'il veut avec les droits admin.
Trafic non chiffre par defaut. WinRM ecoute en HTTP sur le port 5985. Dans un domaine, Kerberos protege l'authentification et chiffre les echanges, mais en groupe de travail (mon cas) on est en NTLM et la protection est plus faible. Le chiffrement complet demande de configurer HTTPS (port 5986) avec un certificat.
TrustedHosts trop large. En groupe de travail, il faut declarer les machines de confiance. Mettre * revient a accepter n'importe quelle machine : on pourrait se connecter a une fausse machine qui se ferait passer pour PC01 et recuperer nos identifiants. Il vaut mieux lister les adresses exactes (192.168.10.11, etc.).
Deplacement lateral. Si un attaquant compromet un poste ou un compte admin, WinRM lui permet de rebondir vers les autres machines du parc sans rien installer, avec un outil legitime de Windows, ce qui est difficile a detecter.
Manque de tracabilite. Par defaut les commandes lancees a distance laissent peu de traces. Sans journalisation (Script Block Logging, transcription), on ne sait pas qui a execute quoi.
Surface d'attaque. Le service WinRM ecoute en permanence sur le reseau. S'il est ouvert a tout le monde dans le pare-feu, n'importe quelle machine du reseau peut essayer de s'y connecter.

Les mesures de protection sont detaillees dans les points suivants.

2. Qui est autorise a ouvrir une session distante

Pour verifier, j'ai interroge PC01 avec Get-LocalGroupMember, Get-LocalUser et Get-PSSessionConfiguration.

Le groupe Administrateurs de PC01 contient trois comptes : admin, Administrateur et PC001. Les trois peuvent ouvrir une session PowerShell distante. Get-LocalUser montre que le compte Administrateur integre est desactive (bon point), alors que admin et PC001 sont actifs.
Le groupe "Utilisateurs de gestion a distance" etait vide au depart.
La configuration de session Microsoft.PowerShell autorise les Administrateurs, les Utilisateurs de gestion a distance et le groupe INTERACTIF (sessions locales). Les sessions microsoft.powershell.workflow et microsoft.powershell32 ont des droits similaires.

Conclusion : l'acces distant n'est pas limite au strict necessaire. Mon script utilise le compte admin, qui est administrateur complet, alors qu'il ne fait que lire des informations. Si ce compte est compromis, l'attaquant a la main totale sur le poste. PC001 est un second compte administrateur actif qui n'a aucun role dans le projet mais peut lui aussi ouvrir une session distante.

Ameliorations proposees :

utiliser un compte dedie au patch management (voir point 3) ;
retirer les droits d'administrateur aux comptes qui n'en ont pas besoin ;
restreindre la session distante avec JEA (point 7).
3. Limiter les privileges du compte de patch management

Pour appliquer le moindre privilege, j'ai cree sur PC01 un compte local dedie, svc-patch. Il n'est pas administrateur : il est uniquement dans le groupe "Utilisateurs de gestion a distance", qui autorise l'ouverture d'une session distante. Je l'ai teste depuis ADMIN01 avec Invoke-Command, en comparant avec le compte admin.

Premier test, avec les droits par defaut :

ouverture de session distante : OK (whoami renvoie pc01\svc-patch) ;
lecture du service Windows Update (Get-Service wuauserv) : OK ;
Get-HotFix et Get-CimInstance Win32_OperatingSystem : "Acces refuse", car l'espace de noms WMI root\cimv2 est reserve aux administrateurs.

J'ai donc ajoute a svc-patch, sur root\cimv2 (wmimgmt.msc, onglet Securite), uniquement les droits "Activer le compte" et "Appel a distance autorise" (Enable Account et Remote Enable), appliques a l'espace de noms et ses sous-espaces. Apres cela :

Get-CimInstance Win32_OperatingSystem fonctionne avec svc-patch ;
mais Get-HotFix renvoie 0 correctif pour svc-patch, sans aucune erreur, alors que le compte admin en renvoie 5 sur le meme poste.

Conclusion : la liste des correctifs installes n'est lisible que par un administrateur. Un compte trop limite ne provoque pas d'erreur visible : il donne une reponse fausse (0 KB), ce qui ferait classer a tort un poste en NON CONFORME dans mon rapport. Je n'ai donc pas bascule PatchManager.ps1 sur svc-patch et j'ai garde le compte admin pour la demonstration.

Pour respecter vraiment le moindre privilege, la bonne solution est JEA (point 7) : un point de connexion restreint qui n'expose que les commandes necessaires (Get-Service, Get-HotFix, Get-CimInstance, en lecture seule) et qui s'execute cote serveur avec un compte virtuel eleve. Ainsi le compte qui se connecte reste sans droits d'administration.

4. Acces aux fichiers produits

J'ai verifie avec icacls les droits sur PatchManager.log, les rapports CSV (RapportSecurite_*.csv) et le dossier qui les contient sur ADMIN01. Seuls trois comptes y ont acces, tous en controle total : SYSTEM, le groupe Administrateurs et le compte admin. Les droits sont herites du dossier. Le groupe Utilisateurs n'apparait pas : un utilisateur standard de la machine ne peut donc pas lire ces fichiers.

Limite : le compte admin peut modifier ou supprimer le journal et les rapports. Pour une vraie exploitation, il faudrait ranger les fichiers dans un dossier dedie (reports), couper l'heritage avec icacls /inheritance:r, et donner seulement la lecture aux auditeurs, l'ecriture au compte du script (voir point 8).

5. Regles du pare-feu Windows pour WinRM

J'ai liste les regles de pare-feu WinRM sur PC01 avec Get-NetFirewallRule, Get-NetFirewallAddressFilter et Get-NetFirewallPortFilter :

WINRM-HTTP-In-TCP (profil Public, port 5985, depuis LocalSubnet) : desactivee ;
WINRM-HTTP-In-TCP-NoScope (profils Domaine et Prive, port 5985, depuis Any) : activee.

Le reseau de PC01 est en profil Prive, donc c'est la regle NoScope qui s'applique. Elle acceptait les connexions WinRM depuis n'importe quelle adresse IP, alors que seul ADMIN01 a besoin de se connecter. C'etait trop permissif : n'importe quelle machine du reseau pouvait tenter de se connecter a PC01.

Mesure appliquee : j'ai restreint la regle WINRM-HTTP-In-TCP-NoScope a l'adresse 192.168.10.10 (ADMIN01) avec Set-NetFirewallRule -RemoteAddress. Apres la restriction, Test-WSMan et Invoke-Command depuis ADMIN01 fonctionnent toujours, et PatchManager.ps1 produit le meme rapport, alors que les autres adresses du reseau n'ont plus acces au port 5985 de PC01.

6. Mode d'authentification et Kerberos

J'ai relu la configuration WinRM des deux machines (WSMan:\localhost\Client\Auth et WSMan:\localhost\Service\Auth).

PC01 (serveur) : Basic desactive, Kerberos et Negotiate actives, Certificate et CredSSP desactives, AllowUnencrypted a false.
ADMIN01 (client) : Negotiate, Kerberos, Digest, Certificate et Basic actives, CredSSP desactive, AllowUnencrypted a false. TrustedHosts contient uniquement 192.168.10.11.

Mes deux machines ne sont pas dans un domaine (groupe de travail) : c'est pour cela que Windows m'a refuse la connexion tant que l'adresse n'etait pas dans TrustedHosts. Sans domaine il n'y a pas de controleur de domaine pour delivrer des tickets, donc Kerberos ne peut pas servir : Negotiate retombe sur NTLM. Les points positifs sont que Basic (mot de passe quasi en clair) est desactive cote serveur et que le trafic non chiffre est interdit : avec Negotiate le contenu des messages WinRM est chiffre meme en HTTP. Les points faibles sont que NTLM est moins solide que Kerberos (attaques par relais, mot de passe attaquable hors ligne) et que le client n'authentifie pas le serveur, d'ou TrustedHosts. Il serait aussi preferable de desactiver Basic cote client.

Quand Kerberos est preferable : des que les machines sont dans un domaine Active Directory. Kerberos authentifie les deux cotes (le client verifie qu'il parle au vrai serveur, ce que NTLM ne fait pas), n'envoie jamais le mot de passe sur le reseau (il utilise des tickets temporaires), resiste mieux aux attaques par relais et par rejeu, permet l'authentification unique et evite de gerer TrustedHosts. En production j'utiliserais donc un domaine avec Kerberos, ou a defaut WinRM en HTTPS (port 5986) avec un certificat.

7. Just Enough Administration (JEA)

JEA est une fonction de PowerShell qui permet de donner a un utilisateur le droit de lancer seulement certaines commandes a distance, sans le faire administrateur. L'idee est le moindre privilege applique aux commandes : on ne donne pas une session d'administration complete, on donne un point d'entree limite.

Fonctionnement :

on cree un fichier de capacites de role (.psrc, New-PSRoleCapabilityFile) qui liste les cmdlets, fonctions et parametres autorises ;
on cree un fichier de configuration de session (.pssc, New-PSSessionConfigurationFile) qui associe un groupe d'utilisateurs a ce role, et definit le mode du langage (restreint) ;
on l'enregistre sur le poste avec Register-PSSessionConfiguration ;
la session s'execute avec un compte virtuel eleve cree pour la session : le compte qui se connecte n'a pas de droits d'administrateur, mais la session peut quand meme lire ce qui est protege ;
toutes les commandes peuvent etre journalisees (transcription).

Dans mon projet, JEA resoudrait le probleme vu au point 3 : le compte svc-patch ne pourrait plus lire la liste des KB tout seul, mais un point de connexion "PatchReader" pourrait autoriser uniquement Get-Service (limite a wuauserv), Get-HotFix et Get-CimInstance sur Win32_OperatingSystem. Le script s'y connecterait avec Invoke-Command -ConfigurationName PatchReader. Si le compte etait vole, l'attaquant ne pourrait executer aucune autre commande (pas d'installation, pas de suppression de fichiers). Je n'ai pas mis JEA en oeuvre dans mon labo (par manque de temps) : j'ai etudie le principe et je l'applique a mon cas.

8. Strategie de conservation des rapports et des journaux

Les rapports et le journal contiennent des informations sensibles : la liste des postes et des correctifs manquants est, pour un attaquant, une carte des machines vulnerables. Strategie proposee :

Eviter la modification non autorisee

ranger les fichiers dans un dossier dedie (reports) et couper l'heritage des droits (icacls /inheritance:r) ;
droits : le compte du script en ecriture seule (ajout), les administrateurs en lecture, personne d'autre ; le journal est ouvert uniquement en ajout (Add-Content) ;
calculer une empreinte de chaque rapport avec Get-FileHash et la stocker a part, pour detecter une modification ;
activer l'audit des acces aux fichiers de Windows pour savoir qui a ouvert ou modifie.

Eviter la suppression

sauvegarder les rapports et journaux sur un emplacement distant en ecriture seule (ou un serveur de journaux / SIEM), pour qu'un attaquant qui prend ADMIN01 ne puisse pas effacer ses traces ;
retirer le droit de suppression aux comptes courants ;
duree de conservation : journaux 12 mois, rapports detailles 90 jours puis archive des syntheses, avec une rotation automatique (nouveau fichier par jour, deja fait pour les rapports grace a la date dans le nom).

Eviter l'exposition d'informations sensibles

limiter la lecture aux administrateurs et auditeurs ;
chiffrer le disque (BitLocker) et les archives ;
ne pas envoyer les rapports par un canal non chiffre : dans mon script de notification le rapport part en piece jointe, donc le serveur SMTP devrait utiliser TLS ;
ne pas mettre de mots de passe dans les journaux (mon script ne journalise que les messages d'erreur, jamais d'identifiants).