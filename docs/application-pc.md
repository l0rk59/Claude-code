# PrivateLM sur ordinateur (Windows, Linux et macOS)

La même application que sur le téléphone, avec la même interface et les
mêmes réglages, mais qui profite de la mémoire et de la carte graphique de
l'ordinateur. Elle remplace les scripts `start-serveur` et `start-worker` :
tout se règle depuis l'application.

> **Testé** :
> - le **vrai moteur** (llama.cpp b11157, téléchargé comme le fait
>   l'application) avec un **vrai modèle** (Qwen 3.5 0.8B), sur Windows et sur
>   Linux, à chaque modification, par GitHub : installation (1 s), chargement
>   (1,6 s), discussion avec réflexion, appel d'outil, agent, mode approfondi,
>   arrêt d'une réponse et du moteur — tout passe ;
> - l'application Linux utilisée de bout en bout sur un écran virtuel, en
>   français, en largeur ordinateur et téléphone ;
> - l'ajout d'un téléphone auxiliaire contre le vrai `ggml-rpc-server` ;
> - les versions Windows, Linux et macOS se compilent sur GitHub.
>
> **Pas encore testé** : l'application lancée sur un vrai PC avec sa carte
> graphique, et un gros modèle. Voir la partie 7 du [plan de test](plan-de-test.md).

## 1. Installer

1. Dans le dépôt GitHub : **Actions > Computer app**, ouvrir la dernière
   exécution réussie, télécharger :
   - `PrivateLM-…-windows-x64.zip` pour Windows ;
   - `PrivateLM-…-linux-x64.tar.gz` pour Linux ;
   - `PrivateLM-…-macos.zip` pour macOS.

   Pour une version publiée (étiquette `v…`), les mêmes fichiers sont dans
   **Releases**, à côté de l'APK.
2. Décompresser, puis lancer `PrivateLM\privatelm.exe` (Windows) ou
   `PrivateLM/privatelm` (Linux).
   - Windows peut afficher « Windows a protégé votre ordinateur » : le
     programme n'est pas signé. **Informations complémentaires > Exécuter
     quand même**.
   - Linux : les bibliothèques GTK 3 sont nécessaires (présentes sur Ubuntu,
     Fedora, Mint… de bureau).
   - macOS : décompresser donne `PrivateLM.app`. L'application n'est pas
     signée par Apple : la première fois, **clic droit > Ouvrir**, puis
     **Ouvrir** (ou Réglages > Confidentialité et sécurité > **Ouvrir
     quand même**). Sur une puce Apple, le moteur utilise sa partie
     graphique (Metal).

## 2. Premier lancement

L'accueil propose un modèle **recommandé pour cet ordinateur**, choisi selon
sa mémoire **et** celle de sa carte graphique :

| Mémoire de l'ordinateur | Carte graphique séparée | Modèle proposé |
| --- | --- | --- |
| 8 Go | aucune | Qwen 3.5 4B |
| 16 Go | aucune | Qwen 3.5 9B |
| 16 Go | 8 Go | gpt-oss 20B |
| 32 Go | aucune | gpt-oss 20B |
| 32 Go | 12 Go ou plus | Qwen 3.5 35B-A3B |
| 64 Go | — | Qwen 3.5 35B-A3B |

La mémoire d'une carte graphique séparée (NVIDIA, AMD Radeon RX, Intel Arc)
compte en plus ; une puce graphique intégrée partage celle de l'ordinateur.
Les modèles « MoE » (35B-A3B, gpt-oss) n'activent qu'une petite partie
d'eux-mêmes à chaque mot : ils restent rapides même quand ils débordent de
la carte graphique.

Au premier chargement, l'application télécharge aussi le **moteur**
(llama.cpp, environ 30 Mo), une seule fois.

Nouveaux modèles « ordinateur » du catalogue (**Modèles > Parcourir**) :
gpt-oss 20B (12 Go, excellent avec les outils et les agents), Qwen 3.5 27B
(17 Go), Qwen 3.5 35B-A3B (22 Go, rapide car seuls 3B sont actifs), Gemma 4
26B-A4B (17 Go). Les modèles LiteRT et la génération d'images restent sur
téléphone.

## 3. Paramètres > Performances > Moteur de l'ordinateur

| Réglage | Ce qu'il fait |
| --- | --- |
| **Moteur** | **Carte graphique (Vulkan)** par défaut : NVIDIA, AMD et Intel, et le processeur s'il n'y a pas de carte. **NVIDIA (CUDA)** : plus rapide sur carte NVIDIA, 650 Mo à télécharger (Windows). **Processeur seul** : si la carte graphique pose problème. |
| Carte graphique | Celle que le moteur a trouvée, avec sa mémoire libre. |
| **Utiliser mon propre llama-server** | Pour une version de llama.cpp faite pour votre carte (ROCm, SYCL…). |
| **Dossier des modèles** | Par exemple un second disque. Les modèles déjà téléchargés restent dans l'ancien dossier. |
| **Partager avec mes téléphones** | Les téléphones du réseau utilisent le modèle chargé sur l'ordinateur. |
| **Téléphones qui prêtent leur mémoire** | Pour un modèle trop gros pour l'ordinateur seul. |

Le moteur choisit seul combien de couches mettre sur la carte graphique
(selon sa mémoire libre). **Paramètres > Performances > GGUF & LiteRT > CPU
sûr** force le processeur seul.

## 4. Les téléphones utilisent le modèle de l'ordinateur

1. Sur l'ordinateur : **Moteur de l'ordinateur > Partager avec mes
   téléphones**. L'adresse de l'ordinateur et une **clé** s'affichent. Le
   modèle se recharge.
2. Le pare-feu peut demander si `llama-server` peut accepter des connexions :
   autoriser sur les **réseaux privés** seulement.
3. Sur chaque téléphone : **Modèles > Cloud > Un ordinateur de votre réseau**,
   toucher l'ordinateur trouvé, saisir la clé, choisir le modèle.

C'est la même chose que [ordinateur.md](ordinateur.md), sans ligne de
commande. Les échanges ne sont pas chiffrés : chez vous, jamais sur un Wi-Fi
public.

## 5. Les téléphones prêtent leur mémoire à l'ordinateur

L'ordinateur devient le chef du cluster : il garde le fichier du modèle et
emprunte la mémoire des téléphones.

1. Sur chaque téléphone : **Cluster > Auxiliaire**.
2. Sur l'ordinateur : **Téléphones qui prêtent leur mémoire > Chercher les
   téléphones du réseau** (ou **Ajouter un téléphone par son adresse**).
   Chaque téléphone affiche la mémoire qu'il peut prêter.
3. Activer **Utiliser les téléphones en mode Auxiliaire**, puis charger le
   modèle.

llama.cpp répartit le modèle entre l'ordinateur et les téléphones. Plus lent
qu'une seule machine : le réseau transporte chaque étape. Le premier
chargement envoie la part de chaque téléphone par le Wi-Fi : comptez quelques
minutes pour 10 Go.

## 6. Les agents sur l'ordinateur

Les agents y sont les plus forts (voir [agents.md](agents.md)) :

- le modèle **appelle lui-même ses outils**, plusieurs à la fois, au lieu de
  les écrire en texte : beaucoup moins d'erreurs ;
- **jusqu'à 10 étapes**, des résultats plus longs (pages, fichiers) ;
- l'outil **Python** (le **Programmeur**) : il écrit et exécute du code pour
  calculer ou analyser vos fichiers, **après votre accord** à chaque fois.
  Python 3 doit être installé ([python.org](https://www.python.org) sous
  Windows, déjà présent sous Linux).
- le **dossier de travail** se choisit dans **Paramètres > Outils > Agents**.

## 7. Mises à jour et raccourcis

Les mises à jour : **Paramètres > À propos > Mises à jour** dit quand une
nouvelle version est publiée et ouvre le bon fichier à télécharger ;
remplacer l'ancien dossier par le nouveau, les modèles et les discussions
restent.

| Touche | Effet |
| --- | --- |
| Entrée | Envoyer |
| Maj + Entrée | Nouvelle ligne |
| Clic droit sur une discussion | La supprimer |

## 8. En cas de problème

| Message | Que faire |
| --- | --- |
| « Le moteur n'a pas pu être téléchargé » | Vérifier la connexion ; GitHub doit être joignable. |
| « Pas assez de mémoire pour ce modèle » | Un modèle plus petit, un contexte plus court (Paramètres > Discussion > Paramètres du modèle), ou Processeur seul. |
| « Le port réseau est déjà utilisé » | Un autre programme (LM Studio, un ancien `start-serveur`) occupe le port 8080 : le fermer, ou désactiver le partage. |
| « Ce moteur ne connaît pas encore ce type de modèle » | Le modèle est trop récent pour llama.cpp b11157. |
| La carte graphique n'est pas trouvée | Mettre à jour son pilote ; essayer **NVIDIA (CUDA)** sur une carte NVIDIA. |

Les détails sont dans **Paramètres > Journaux** (la commande du moteur y est
notée, sans la clé).

Le moteur s'arrête avec la fenêtre. Si l'application a planté, le moteur
resté ouvert est arrêté au lancement suivant.

Où sont les fichiers : `%APPDATA%\l0rk59\PrivateLM` (Windows),
`~/.local/share/com.l0rk59.privatelm` (Linux),
`~/Library/Application Support/com.l0rk59.privatelm` (macOS) : réglages, discussions,
modèles (sauf dossier choisi), moteur, dossier de travail des agents.
