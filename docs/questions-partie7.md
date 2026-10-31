# Partie 7 : Notification : questions de réflexion

## Question 2 : Quels sont les inconvénients de cette solution ?

La solution marche, mais elle a plusieurs limites que j'ai pu constater en la testant.

**Elle dépend entièrement du serveur SMTP.** Si le serveur est éteint, injoignable ou
bloqué par un pare-feu, le mail ne part pas. Je l'ai vu pendant mes tests : sans mon
serveur de test lancé, le script a écrit "Notification non envoyée" dans le journal avec
l'erreur "Impossible de se connecter au serveur distant". Dans ce cas l'administrateur
n'est pas prévenu, alors que c'est justement le but du script. Le journal garde une
trace de l'échec, mais personne ne le lit en temps réel.

**La gestion du mot de passe reste fragile.** Le fichier `smtp-cred.xml` créé avec
`Export-Clixml` est chiffré avec DPAPI : il ne peut être relu que par le même
utilisateur sur la même machine. C'est mieux qu'un mot de passe en clair dans le
script, mais ça veut dire qu'il faut recréer le fichier si on change de compte ou de
machine, et que n'importe quel processus lancé avec ce compte peut le déchiffrer.

**Le mail n'est pas fiable à 100 %.** Un mail peut finir dans les spams, arriver avec
du retard, ou ne jamais être lu. Il n'y a pas d'accusé de réception : le script sait
que le serveur a accepté le message, pas que l'administrateur l'a vu. Et sans
chiffrement (TLS), le contenu circule en clair, alors qu'il donne la liste des postes
vulnérables et des KB manquantes. Pour un attaquant qui l'intercepte, c'est une liste
de cibles.

**Il y a un risque de trop de notifications.** Si le script tourne toutes les heures et
qu'un poste reste inaccessible pendant une semaine, l'administrateur reçoit le même
mail 168 fois. Il finit par ne plus les lire. Mon script ne mémorise pas ce qui a déjà
été signalé.

**Le script n'est pas très portable.** `Send-MailMessage` est marqué comme obsolète par
Microsoft : il ne gère pas bien les protocoles modernes d'authentification. Et
l'adresse du serveur, l'expéditeur et le destinataire sont écrits directement dans le
script, ce qui n'est pas pratique à maintenir.

## Question 3 : Quelles alternatives modernes en environnement réel ?

Dans une vraie entreprise, on n'enverrait pas un mail depuis un script comme ça. On
utiliserait plutôt :

- **Une messagerie d'équipe avec webhook** (Microsoft Teams, Slack) : le script envoie
  un message à un canal avec une requête HTTPS, et toute l'équipe d'administration le
  voit tout de suite, sur son téléphone aussi.
- **Une API de messagerie moderne** (Microsoft Graph, SendGrid) : l'envoi passe par un
  jeton OAuth2 au lieu d'un mot de passe, et on peut le révoquer ou limiter ses droits.
- **Un outil de supervision ou un SIEM** (Zabbix, Nagios, Splunk, Microsoft Sentinel) :
  les résultats sont envoyés comme des événements, avec des seuils, des alertes qui
  s'escaladent et un historique. Ça évite aussi le problème des mails répétés.
- **Un coffre-fort de secrets** (Azure Key Vault, HashiCorp Vault, module
  SecretManagement de PowerShell) pour stocker les identifiants, au lieu d'un fichier
  sur le disque.
- **Un outil de gestion de tickets** (GLPI, ServiceNow, Jira) : une anomalie crée
  automatiquement un ticket avec un responsable et un suivi jusqu'à la résolution.
- **Une solution de gestion des correctifs dédiée** (WSUS, Intune, SCCM/Configuration
  Manager) qui fait déjà le suivi de conformité et les rapports, sans que l'on code
  tout nous-mêmes.

L'idée générale est de passer d'un mail "envoyé et oublié" à un système qui authentifie
proprement, qui trace, et qui s'assure que quelqu'un traite l'anomalie.