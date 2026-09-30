# Questions de theorie - Partie 1 (preparation de l'environnement)

Questions posees telles quelles dans le sujet. A completer au fur et a mesure de la manipulation de WinRM (pas de reponse recopiee sans avoir teste).

## Quel est le role de WinRM dans PowerShell Remoting ?

WinRM (Windows Remote Management) est l'implementation Microsoft du standard WS-Management, base sur SOAP et transporte en HTTP/HTTPS. Contrairement a l'ancien systeme base sur du RPC, qui utilise des ports dynamiques (une plage aleatoire a chaque connexion, difficile a controler cote pare-feu), WinRM se limite a deux ports fixes et connus. C'est ce service qui rend possible PowerShell Remoting : quand on utilise Invoke-Command ou Enter-PSSession, c'est WinRM qui transporte la requete jusqu'a la machine distante, l'execute, puis renvoie le resultat. Sans WinRM demarre et accessible sur la machine cible, aucune de ces commandes ne fonctionne.

## Quelle commande permet d'activer PowerShell Remoting ?

La commande est Enable-PSRemoting (executee en tant qu'administrateur). Elle fait plusieurs choses en une fois : elle demarre le service WinRM et le passe en demarrage automatique, elle cree un ecouteur WinRM qui ecoute sur le reseau, elle active la regle de pare-feu correspondante (le trafic entrant sur les ports 5985/5986), et elle enregistre les configurations de session PowerShell par defaut. On peut y ajouter -Force pour eviter les confirmations manuelles, utile dans un script mais a utiliser avec prudence.

## Quels ports reseau sont utilises par WinRM ?

WinRM utilise deux ports : 5985 en HTTP et 5986 en HTTPS. Le port 5986 est preferable car la connexion est chiffree, contrairement au 5985 qui transmet en clair.

## Pourquoi le pare-feu Windows peut-il empecher une connexion PowerShell distante ?

Par defaut, le pare-feu Windows bloque le trafic entrant qui n'est pas explicitement autorise, et les ports WinRM (5985/5986) ne font pas exception. Meme si WinRM est correctement configure et le service demarre sur la machine distante, si la regle de pare-feu autorisant ce trafic entrant n'existe pas (ou est desactivee), la machine ne repondra jamais aux requetes PowerShell Remoting envoyees depuis le poste d'administration. C'est justement pour ca que Enable-PSRemoting cree automatiquement cette regle de pare-feu en meme temps qu'il active le service : sans elle, WinRM tournerait mais resterait injoignable depuis l'exterieur de la machine.

## Quelle difference existe-t-il entre tester la connectivite avec Test-Connection et tester WinRM avec Test-WSMan ?

Test-Connection et Test-WSMan ne testent pas la meme chose. Test-Connection envoie un ping (ICMP), donc ca verifie juste que la machine est allumee et joignable sur le reseau, rien de plus. Ca ne dit pas du tout si PowerShell Remoting va fonctionner dessus.

Test-WSMan, lui, verifie specifiquement que le service WinRM tourne et repond sur la machine distante, donc que l'administration a distance est possible. Une machine peut tres bien repondre au ping mais avoir WinRM desactive (Test-WSMan echouera), et a l'inverse le pare-feu peut parfois bloquer le ping ICMP alors que WinRM fonctionne quand meme. Du coup les deux tests sont complementaires : Test-Connection verifie que la machine est joignable sur le reseau, Test-WSMan verifie que l'administration a distance est possible dessus.

## Pourquoi est-il preferable de verifier l'accessibilite d'une machine avant de tenter une commande distante ?

Deja parce que si la machine n'est pas disponible, ca ne sert a rien de lancer une commande dessus, ca va juste echouer. Ensuite, faire un ping avec Test-Connection est rapide, alors qu'essayer Invoke-Command sur une machine injoignable prend beaucoup plus de temps (le temps que WinRM finisse par expirer). Sur un parc avec plusieurs machines, si on ne teste pas avant, on perd du temps a attendre ces timeouts pour rien. Ca permet aussi de bien distinguer deux problemes differents : une machine eteinte/injoignable, et une machine allumee mais ou WinRM n'est pas bien configure.

## Quels problemes de securite peuvent apparaitre si PowerShell Remoting est active sans restriction ?

Activer PowerShell Remoting sans restriction pose plusieurs risques. D'abord, si TrustedHosts est mal configuré (par exemple avec * pour accepter n'importe quelle machine), n'importe quel poste du réseau peut potentiellement se connecter et exécuter des commandes à distance, ce qui élargit énormément la surface d'attaque. Si un attaquant récupère les identifiants d'un compte admin (par phishing, brute force, etc.), il peut prendre le contrôle de toutes les machines qui acceptent les connexions WinRM.

Ensuite, le protocole WinRM écoute par défaut sur les ports 5985 (HTTP) et 5986 (HTTPS). Sans HTTPS, les identifiants et les commandes transitent en clair sur le réseau, ce qui les rend interceptables (attaque man-in-the-middle par exemple).

Il y a aussi le risque de mouvement latéral : dans un environnement où toutes les machines ont Remoting activé sans restriction, un attaquant qui compromet une seule machine peut rebondir facilement vers les autres, surtout si les comptes locaux partagent le même mot de passe ou (comme je l'ai découvert en pratique) si des machines clonées partagent le même SID, ce qui peut créer des comportements d'authentification imprévus.

Enfin, un LocalAccountTokenFilterPolicy mal configuré ou une politique de firewall trop permissive (ports WinRM ouverts vers l'extérieur, ICMP ouvert sans restriction) augmente encore l'exposition. C'est pour ça qu'en environnement réel, il faut limiter TrustedHosts aux machines nécessaires, privilégier HTTPS pour WinRM, restreindre les comptes ayant le droit de se connecter à distance, et éviter d'activer Remoting sur des machines qui n'en ont pas besoin.