# Environnement de test

## Contexte

Projet realise en monome (Arshdeep Singh) dans le cadre du cours Securite des systemes (S. Benayoune, EFREI).
Date limite de remise : 31 octobre 2026.

## Virtualisation

- Machine hote : MacBook (Apple Silicon M2 Pro)
- Hyperviseur : VMware Fusion (mode Apple Silicon natif)
- Systeme des VM : Windows 11 ARM64 (ISO officielle Microsoft, edition multi-edition Arm64), compte local (sans compte Microsoft)

Note : un premier essai a ete fait avec une ISO Windows 11 x64 (standard), qui a echoue au demarrage
("architecture X86 incompatible avec l'hote Arm"). Sur Apple Silicon, seule une ISO ARM64 peut etre virtualisee,
quel que soit l'hyperviseur utilise (UTM, VMware Fusion, Parallels). Corrige en telechargeant l'ISO
"Windows 11 (ISO multi-edition pour Arm64)" depuis microsoft.com/fr-ca/software-download/windows11arm64.

## Topologie

Le Mac hote ne peut pas servir de poste d'administration PowerShell (ce n'est pas du Windows).
L'ensemble du TP se deroule donc entre VM Windows :

| Machine | Role                    |
|---------|--------------------------|
| ADMIN01 | Poste d'administration  |
| PC01    | Poste supervise          |
| PC02    | Poste supervise (option) |

## Plan d'adressage

Reseau prive isole entre les VM, sans passerelle.

| Machine | IP             |
|---------|----------------|
| ADMIN01 | 192.168.10.10  |
| PC01    | 192.168.10.11  |
| PC02    | 192.168.10.12  |

## Points de configuration valides

- [ ] Profil reseau des VM passe en "Prive" (Set-NetConnectionProfile)
- [ ] Regle pare-feu ICMPv4 entrant autorisee
- [ ] Test-Connection reussi dans les deux sens entre toutes les machines
- [ ] PowerShell Remoting active (Enable-PSRemoting)
- [ ] Test-WSMan fonctionnel entre ADMIN01 et les postes supervises
- [ ] Enter-PSSession et Invoke-Command testes avec succes

## Notes

A completer au fil de l'avancement (captures dans docs/screenshots/).