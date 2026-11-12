# Un gros modèle sur plusieurs appareils : téléphones et ordinateur

Le cluster de PrivateLM répartit un modèle GGUF entre plusieurs appareils du
même Wi-Fi. Leurs mémoires s'additionnent : un modèle trop gros pour un seul
téléphone peut tenir sur trois téléphones et un PC portable. Tout reste sur
votre réseau local, rien ne passe par Internet.

> La liaison entre appareils n'a ni mot de passe ni chiffrement. À utiliser
> uniquement sur un réseau de confiance (chez vous), jamais sur un Wi-Fi
> public.

## Comment ça marche

- Un téléphone Android est le **principal** : c'est lui qui charge le modèle et
  avec lequel vous discutez. Le fichier du modèle doit être sur son stockage.
- Les autres appareils sont des **auxiliaires** : ils prêtent leur mémoire et
  leur processeur. Un téléphone devient auxiliaire depuis l'application ; un
  ordinateur le devient en lançant `ggml-rpc-server`, un petit programme de
  llama.cpp.
- Au chargement, l'application découpe le modèle en tranches de couches et en
  confie une à chaque appareil, selon la mémoire que chacun peut donner.
  L'ordinateur est rempli en premier.

## Mise en place : 3 téléphones et 1 ordinateur

### 1. Sur l'ordinateur

Téléchargez llama.cpp **b11157**, la version sur laquelle l'application est
construite (les deux côtés doivent parler le même protocole), depuis
<https://github.com/ggml-org/llama.cpp/releases/tag/b11157> :

| Ordinateur | Fichier |
| --- | --- |
| Windows | `llama-b11157-bin-win-cpu-x64.zip` |
| Windows avec carte graphique | `llama-b11157-bin-win-vulkan-x64.zip` |
| Linux | `llama-b11157-bin-ubuntu-x64.tar.gz` |
| Linux avec carte graphique | `llama-b11157-bin-ubuntu-vulkan-x64.tar.gz` |
| Mac Apple Silicon | `llama-b11157-bin-macos-arm64.tar.gz` |
| Mac Intel | `llama-b11157-bin-macos-x64.tar.gz` |

La version « processeur » prête la mémoire vive de l'ordinateur. La version
« carte graphique » prête la mémoire de la carte : c'est plus rapide, mais il
y en a souvent moins (6 à 8 Go sur un portable).

Décompressez l'archive, copiez-y le script de ce dépôt qui correspond à votre
système, puis lancez-le :

- Windows : [`tools/cluster/start-worker.ps1`](../tools/cluster/start-worker.ps1),
  clic droit puis « Exécuter avec PowerShell ». Windows demande une fois
  d'autoriser l'accès au réseau : acceptez pour les réseaux privés.
- Linux et macOS : [`tools/cluster/start-worker.sh`](../tools/cluster/start-worker.sh),
  dans un terminal : `./start-worker.sh`.

Le script affiche l'adresse à saisir dans l'application et laisse le
programme tourner. Sans script, la commande est :

```
ggml-rpc-server -H 0.0.0.0 -p 50052 -c
```

`-c` garde sur le disque de l'ordinateur les couches reçues : elles ne
traversent le Wi-Fi qu'au premier chargement.

### 2. Sur les deux téléphones auxiliaires

Ouvrez **Cluster de téléphones**, choisissez **Auxiliaire**. Le téléphone affiche un QR code.
Laissez l'application ouverte, écran allumé, téléphone branché : Android
ralentit fortement une application en arrière-plan.

### 3. Sur le téléphone principal

Ouvrez **Cluster de téléphones**, choisissez **Principal**, puis :

1. **Scanner le code QR d'un auxiliaire**, une fois par téléphone.
2. **Ajouter un ordinateur** : saisissez l'adresse affichée par le script
   (par exemple `192.168.1.20:50052`), touchez **Vérifier**. L'application
   interroge l'ordinateur, affiche sa mémoire et vous laisse choisir combien
   lui confier. Gardez-en pour le système : sur 16 Go, 10 à 12 Go.

### 4. Charger le modèle

Chargez le modèle GGUF comme d'habitude depuis **Modèles**. Si l'ensemble des
appareils a assez de mémoire, le modèle est réparti ; l'écran Cluster de téléphones
montre ensuite la part de chacun. Sinon l'application dit combien il manque.

## Quelle taille de modèle ?

L'application compte, pour un fichier de modèle de taille T :

- besoin : T × 1,1 (le modèle, plus le contexte de discussion) ;
- téléphone principal : 70 % de sa mémoire libre ;
- chaque téléphone auxiliaire : 75 % de la mémoire libre qu'il a annoncée ;
- ordinateur : ce que vous lui avez confié.

Exemple : trois téléphones de 8 Go ayant chacun environ 5 Go libres, et un
portable de 16 Go auquel on confie 12 Go : 3,5 + 3,75 + 3,75 + 12 ≈ 23 Go,
soit un fichier d'environ 21 Go au maximum. Pour un modèle qui demande 25 Go
il faut donc un peu plus : des téléphones de 12 Go, ou un ordinateur de 32 Go.

Fermez les autres applications sur chaque téléphone avant de démarrer : la
mémoire libre qu'un auxiliaire annonce est mesurée au moment où il démarre.

## Quels modèles choisir ?

Avec plusieurs appareils, chaque mot généré traverse tous les appareils l'un
après l'autre. Les modèles « MoE » (mélange d'experts) sont alors de loin les
plus intéressants : ils sont gros en mémoire, mais n'activent qu'une petite
partie de leurs paramètres à chaque mot, donc ils restent utilisables.

| Modèle (Hugging Face) | Fichier | Taille |
| --- | --- | --- |
| `unsloth/gemma-4-26B-A4B-it-GGUF` | UD-IQ2_M (dans le catalogue de l'application) | 10 Go |
| `LiquidAI/LFM2.5-24B-A2B-GGUF` | Q4_K_M | 14,5 Go |
| `unsloth/Qwen3.5-35B-A3B-GGUF` | Q3_K_M | 16,4 Go |
| `unsloth/Qwen3.5-35B-A3B-GGUF` | Q4_K_M | 22 Go |

Ils se téléchargent depuis **Modèles > Parcourir > Rechercher sur Hugging
Face**, sur le téléphone principal (qui doit avoir la place sur son stockage).
Un modèle « dense » de même taille fonctionne aussi, mais bien plus lentement.

## À quoi s'attendre

- **Premier chargement long** : le téléphone principal envoie à chaque appareil sa tranche
  du modèle par le Wi-Fi. Pour 15 à 20 Go, comptez plusieurs minutes. Les
  chargements suivants sont rapides, chaque appareil gardant sa tranche.
- **Vitesse** : elle dépend du Wi-Fi et de l'appareil le plus lent. Un
  modèle qui tient sur un seul appareil y sera toujours plus rapide que
  réparti : le cluster sert à faire tourner ce qui ne tiendrait pas
  autrement. Ces vitesses n'ont pas été mesurées sur de vrais appareils pour
  cette version.
- Un Wi-Fi 5 GHz, les appareils près de la box, les téléphones branchés et
  écran allumé font une vraie différence.

## Variante : l'ordinateur aux commandes

Si le modèle tient sur l'ordinateur seul, ne passez pas par le cluster : faites
tourner le modèle sur l'ordinateur et discutez depuis le téléphone. C'est plus
rapide et plus simple. Voir [ordinateur.md](ordinateur.md), qui décrit aussi
comment l'ordinateur peut emprunter la mémoire des téléphones.

## En cas de problème

| Message | Cause probable |
| --- | --- |
| Impossible de joindre l'adresse | `ggml-rpc-server` n'est pas lancé, le pare-feu bloque le port 50052, ou les appareils ne sont pas sur le même Wi-Fi (un réseau « invité » isole souvent les appareils entre eux). |
| Autre version de llama.cpp | L'ordinateur n'utilise pas la version b11157. |
| Connexion acceptée sans réponse | L'ordinateur sert déjà un autre téléphone : déchargez le modèle là-bas ou relancez `ggml-rpc-server`. |
| Modèle trop gros pour ces appareils | La somme des mémoires ne suffit pas : fermez des applications, confiez plus de mémoire à l'ordinateur, ou prenez un fichier plus petit (Q3 au lieu de Q4). |
