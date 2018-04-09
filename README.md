# Setup_auto
Utilitaire d'installation configurable avec d�lai d'ex�cution automatique

Permet de proposer l'installation d'une application que l'utilisateur peut soit accepter soit refuser.
Sans r�ponse, l'ex�cution est automatique apr�s un d�lai d�fini.

![screenshot](./screenshot/setup_auto_1.png)

## Fonctionnalit�s
Le param�trage se fait via fichier 'ini' :
- D�lai avant et apr�s installation
- Textes d'information concernant la proc�dure et sa progression
- Commandes � lancer en d�but de proc�dure avec choix de l'indiquer ou non � l'utilisateur
- D�sinstaller un programme en cherchant sa commande de d�sinstallation dans les programmes install�s dans le syst�me
- Installer le logiciel sous des conditions permettant de v�rifier son existence par nom et version afin d'�viter une installation inutile
- Commandes de post-installation

## Usage

### Fichier 'ini'
Voir l'exemple "setup_auto.ini".

### Utilitaire "setup_auto.exe"
(Ex�cutable g�n�r� avec l'outil NSIS et le script 'nsi' fourni)

OPTIONS :
- aucun argument : utilisation de "setup_auto.ini" situ� dand le m�me r�pertoire que "setup_auto.exe"
- /config inifile : sp�cifie l'emplacement du fichier de configuration (par d�faut setup_auto.ini o� se trouve setup_auto.exe)
- /help ou /? : afficher cette aide

VALEUR DE RETOUR (ERRORLEVEL) :
- 0 - Execution normale (aucune erreur)
- 1 - Installation annuler par l'utilisateur (bouton [Annuler])
- 2 - Installation annuler par Setup_auto (probl�me d'ouverture du fichier de configuration, erreur de d�sinstallation, ex�cution impossible de la commande de pr�installation ou d'installation de l'application)
- AUTRE - errorlevel retourn� par l'application � installer

Des copies d'�cran son disponibles dans le r�pertoire 'screenshot'.

### Aller plus loin !
En tant qu'administrateur syst�me ayant des clients windows dont les droits son "simple utilisateur", en utilisant conjointement [**ExecAs**](https://github.com/noelmartinon/ExecAs), un outil de d�ploiement peut tr�s bien ex�cuter la commande suivante :
1. G�n�rer une commande crypt�e qui est ex�cut�e par un compte administrateur :
    ```
    ExecAs.exe -c -n -r -uadmin -ppasswd -d -w setup_auto.exe
    ```
    ce qui donne par exemple dans le presse-papier :
    ```
    T05LU0dPaEU40pIY6ET56pru+D3yO1eJEBRxjU+8i0sy+GRUm3QNRfbi+IZrS7EDjs73m+OqJuvKECSuTBzlJofmjlN1dNSBdS9fYY/SUK4PLeoN0dQBFw==
    ```
2. Dans l'outil de d�ploiement utiliser par exemple :
    ```
    ExecAs.exe -i -h -w ExecAs.exe T05LU0dPaEU40pIY6ET56pru+D3yO1eJEBRxjU+8i0sy+GRUm3QNRfbi+IZrS7EDjs73m+OqJuvKECSuTBzlJofmjlN1dNSBdS9fYY/SUK4PLeoN0dQBFw==
    ```
    Ici le -h permet de masquer la fen�tre de console cr��e par le second ExecAs.exe

## License
GNU General Public License v3.0

Copyright (C) 2017  No�l Martinon