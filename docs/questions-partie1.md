## Quelle difference existe-t-il entre tester la connectivite avec Test-Connection et tester WinRM avec Test-WSMan ?

Test-Connection et Test-WSMan ne testent pas la meme chose. Test-Connection envoie un ping (ICMP), donc ca verifie juste que la machine est allumee et joignable sur le reseau, rien de plus. Ca ne dit pas du tout si PowerShell Remoting va fonctionner dessus.

Test-WSMan, lui, verifie specifiquement que le service WinRM tourne et repond sur la machine distante, donc que l'administration a distance est possible. Une machine peut tres bien repondre au ping mais avoir WinRM desactive (Test-WSMan echouera), et a l'inverse le pare-feu peut parfois bloquer le ping ICMP alors que WinRM fonctionne quand meme. Du coup les deux tests sont complementaires : Test-Connection verifie que la machine est joignable sur le reseau, Test-WSMan verifie que l'administration a distance est possible dessus.
