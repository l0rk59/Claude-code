# Le modèle sur l'ordinateur, la conversation sur le téléphone

C'est la façon la plus simple de discuter avec un modèle vraiment gros :
l'ordinateur le fait tourner, et PrivateLM sur le téléphone sert d'écran et de
clavier. Tout reste sur votre réseau local, rien ne passe par Internet.

> Avec les scripts de ce dépôt, le serveur est protégé par une clé : les
> autres appareils du réseau ne peuvent pas s'en servir. Les échanges ne sont
> pas chiffrés pour autant : à utiliser sur un réseau de confiance (chez
> vous), jamais sur un Wi-Fi public.

## Laquelle des deux méthodes choisir ?

| | Ordinateur seul (ce guide) | Cluster ([guide](cluster-ordinateur.md)) |
| --- | --- | --- |
| Qui fait tourner le modèle | l'ordinateur | tous les appareils, chacun sa tranche |
| Taille du modèle | ce que l'ordinateur peut porter | la somme des mémoires |
| Vitesse | la meilleure : rien ne traverse le Wi-Fi pendant le calcul | plus lente : chaque mot traverse tous les appareils |
| Où est le fichier du modèle | sur le disque de l'ordinateur | sur le stockage du téléphone principal |
| Plusieurs téléphones en même temps | oui | non, un seul téléphone discute |

Si le modèle tient sur l'ordinateur, prenez cette méthode. Le cluster sert
quand il n'y tient pas.

## 1. Sur l'ordinateur

Trois programmes conviennent ; PrivateLM les reconnaît tous les trois.

### llama.cpp

Téléchargez llama.cpp depuis
<https://github.com/ggml-org/llama.cpp/releases> (archive « win-cpu-x64 »,
« win-vulkan-x64 » avec une carte graphique, « ubuntu-x64 », « macos-arm64 »…),
décompressez-la, et placez-y le fichier `.gguf` du modèle ainsi que le script
de ce dépôt :

- Windows : [`tools/serveur/start-serveur.ps1`](../tools/serveur/start-serveur.ps1),
  clic droit puis « Exécuter avec PowerShell ». Windows demande une fois
  d'autoriser l'accès au réseau : acceptez pour les réseaux privés.
- Linux et macOS : [`tools/serveur/start-serveur.sh`](../tools/serveur/start-serveur.sh),
  dans un terminal : `./start-serveur.sh modele.gguf`.

Le script affiche l'adresse de l'ordinateur et **une clé**, puis laisse le
serveur tourner. La clé est créée au premier lancement et gardée dans le
fichier `.privatelm-cle` à côté du script : elle reste la même d'une fois sur
l'autre, et l'application ne la demande qu'une fois. Pour la choisir :
`CLE=monsecret ./start-serveur.sh modele.gguf` (Windows : `-Cle monsecret`) ;
pour s'en passer : `CLE=aucune` (Windows : `-Cle aucune`).

Sans script, la commande est :

```
llama-server -m modele.gguf --host 0.0.0.0 --port 8080 --api-key maclé
```

Par défaut, llama.cpp place lui-même le modèle entre la carte graphique et la
mémoire vive, et réduit le contexte si nécessaire.

### Ollama

Installez Ollama, téléchargez un modèle (`ollama pull` suivi de son nom), puis
autorisez les connexions du réseau en définissant la variable d'environnement
`OLLAMA_HOST=0.0.0.0` avant de le lancer. Port : 11434.

### LM Studio

Chargez un modèle, ouvrez l'onglet du serveur local, démarrez-le et activez
dans ses réglages l'accès depuis le réseau local. Port : 1234.

## 2. Sur le téléphone

**Modèles > Cloud > Un ordinateur de votre réseau.** L'application cherche sur
votre Wi-Fi les ordinateurs qui font tourner un modèle et affiche ce qu'elle
trouve. Si l'ordinateur est protégé, saisissez la clé affichée par le script.
Touchez un modèle : c'est fait, la discussion passe par l'ordinateur.

Si la recherche ne trouve rien, saisissez l'adresse affichée par le script
(par exemple `192.168.1.20`). Causes fréquentes : le pare-feu de l'ordinateur
bloque le port, le programme n'accepte que les connexions locales, ou les
appareils sont sur un Wi-Fi « invité » qui les isole.

Pour revenir à un modèle du téléphone : **Modèles > Mes modèles**, chargez-en
un.

## Quel modèle selon l'ordinateur ?

Ordre de grandeur, pour un fichier au format GGUF : il faut à peu près la
taille du fichier en mémoire, plus 1 à 2 Go.

| Mémoire de l'ordinateur | Modèles possibles |
| --- | --- |
| 8 Go | jusqu'à 4-5 Go : Qwen 3.5 4B, Gemma 4 E4B |
| 16 Go | jusqu'à 10-11 Go : Qwen 3.5 9B (Q4_K_M, 5,7 Go), Gemma 4 26B-A4B (UD-IQ2_M, 10 Go) |
| 32 Go | jusqu'à 24-26 Go : Qwen 3.5 35B-A3B (Q4_K_M, 22 Go), LFM2.5 24B-A2B (Q4_K_M, 14,5 Go) |

Les modèles « MoE » (noms en A2B, A3B, A4B) n'activent qu'une petite partie
de leurs paramètres à chaque mot : à taille égale, ils sont nettement plus
rapides sur un processeur.

## Aller plus loin : prêter la mémoire des téléphones à l'ordinateur

Expérimental, non testé pour cette version. L'ordinateur peut emprunter la
mémoire des téléphones pour un modèle qui ne tient pas chez lui :

1. Sur chaque téléphone : **Cluster de téléphones > Auxiliaire**.
2. Sur l'ordinateur, avec la même version de llama.cpp que l'application
   (**b11157**), ajoutez les adresses des téléphones :

```
./start-serveur.sh modele.gguf 8080 --rpc 192.168.1.11:50052,192.168.1.12:50052 --fit-target 4096,4096
```

`--fit-target` indique, pour chaque téléphone dans l'ordre, la mémoire à
laisser libre, en Mio. C'est indispensable : dans ce sens, llama.cpp croit que
toute la mémoire d'un téléphone est disponible et lui en confierait trop.
Comptez la moitié de la mémoire du téléphone : 4096 pour 8 Go, 6144 pour
12 Go. Si l'ordinateur a une carte graphique, ajoutez une valeur de plus pour
elle (1024).

Les téléphones discutent ensuite avec l'ordinateur comme au point 2.
