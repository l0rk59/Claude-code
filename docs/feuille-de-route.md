# Feuille de route

État du projet, ce qui reste, et ce qui dépend de vous. Mis à jour avec
l'application pour ordinateur et les agents avancés.

## 1. Où en est le projet

| Domaine | État | Comment c'est vérifié |
| --- | --- | --- |
| Interface (français, refonte, accueil guidé) | en place | tests, captures ; utilisée sur un vrai téléphone |
| Modèles sur le téléphone (GGUF, LiteRT) | en place | **mesuré sur un vrai téléphone** : 12,7 tokens/s (Qwen 3.5 2B, carte graphique Mali) |
| Meilleur réglage par modèle | nouveau | tests ; à lancer sur le téléphone |
| Recherche Hugging Face, jeton, modèles en plusieurs fichiers | en place | tests, réponses réelles de Hugging Face |
| Un ordinateur fait tourner le modèle (avec clé) | en place | tests contre de faux serveurs ; options de `llama-server` vérifiées dans son code |
| Cluster téléphones + ordinateur | en place | dialogue vérifié contre le vrai `ggml-rpc-server` b11157 ; aucun chargement réel réparti |
| Recherche Web, Mes documents, Mémoire, Tâches, lecture à voix haute | nouveau | tests ; DuckDuckGo et Wikipédia refusent ce serveur de développement, donc pas d'essai réel d'ici |
| Agents : assistants spécialisés et équipes | en place | tests du moteur ; parcours complet vérifié avec un modèle simulé dans la version web |
| **Agents avancés** : outils appelés par le modèle, mode approfondi (plan, vérification), délégation, fichiers, Python, mémoire | nouveau | tests ; parcours vérifié dans l'application Linux avec un faux `llama-server` (plan → délégation → vérification, Python après accord) |
| **Application pour ordinateur** (Windows, Linux) | nouveau | version Linux compilée et utilisée de bout en bout sur un écran virtuel avec un faux `llama-server` ; pas encore sur un vrai PC ni avec un vrai modèle |
| Moteur de l'ordinateur (llama.cpp b11157 `llama-server`) | nouveau | noms des fichiers vérifiés sur GitHub ; installation, démarrage, discussion et arrêt testés contre un faux serveur ; options vérifiées dans la documentation de b11157 |
| L'ordinateur chef du cluster (téléphones en Auxiliaire) | nouveau | dialogue avec le vrai `ggml-rpc-server` b11157 vérifié ; aucun chargement réel réparti |
| Clés et jetons | dans le coffre du téléphone (Keystore) | tests |
| Identité de l'application | `com.l0rk59.privatelm`, version 1.1.0 | — |
| Fabrication de l'APK sur GitHub | en place | construit avec succès sur GitHub (environ 18 minutes) |
| Fabrication de l'application pour ordinateur sur GitHub | nouveau | Windows (zip) et Linux (tar.gz) à chaque exécution, ajoutés à la version publiée |
| Mises à jour de l'application | pointent sur ce dépôt | aucune version publiée pour l'instant |
| Télémétrie | retirée | Firebase, inactif, a été enlevé : il bloquait la version Windows ; les erreurs restent dans Paramètres > Journaux |

## 2. Ce qui a été fait dans ce tour

- **Application pour ordinateur** (Windows et Linux), la même que sur le
  téléphone : voir [application-pc.md](application-pc.md). Elle installe
  seule le moteur llama.cpp (carte graphique Vulkan, NVIDIA CUDA ou
  processeur), recommande un modèle selon la mémoire et la carte graphique,
  partage le modèle avec les téléphones (clé), et peut emprunter la mémoire
  des téléphones en Auxiliaire. Raccourcis clavier, fenêtre large.
- **Modèles « ordinateur »** au catalogue : gpt-oss 20B, Qwen 3.5 27B et
  35B-A3B, Gemma 4 26B-A4B.
- **Agents avancés** : voir [agents.md](agents.md). Outils appelés par le
  modèle lui-même (plusieurs à la fois) sur ordinateur et en ligne ; **mode
  approfondi** (plan, puis vérification qui valide, corrige ou relance la
  recherche) ; **Chef de projet** qui délègue aux autres assistants ;
  **Programmeur** (Python sur ordinateur) ; **Assistant fichiers** ; outil
  **Mémoire** ; tout ce qui écrit ou exécute demande votre accord.
- **Fabrication sur GitHub** des versions Windows et Linux.

## 3. Ce qui reste

### À faire de votre côté

| Quoi | Pourquoi |
| --- | --- |
| Lancer « Trouver le meilleur réglage » sur Qwen 3.5 2B puis 4B | savoir ce qui est réellement le plus rapide sur votre téléphone |
| Essayer l'application sur votre PC portable (partie 7 du plan de test) | premier essai réel du moteur llama.cpp et de la carte graphique |
| Installer Python 3 sur le PC (Windows) | pour le Programmeur |
| Suivre le [plan de test](plan-de-test.md) | trouver ce que les tests ne voient pas, surtout le cluster et l'ordinateur |
| Créer la clé de signature ([publier.md](publier.md)) | publier des versions qui se mettent à jour d'elles-mêmes |

### Étudié et écarté pour l'instant

| Piste | Constat |
| --- | --- |
| Puce NPU de votre téléphone (MediaTek MT6991) | Google publie des modèles précompilés pour elle, mais seulement Gemma 3 1B et 270M (sous licence). L'application sait déjà demander le NPU ; il manque la bibliothèque d'accès propre à MediaTek, distribuée à part par Google. Gain faible pour des modèles aussi petits. |
| Puce NPU Snapdragon (Hexagon) | Ne concerne pas votre téléphone. |
| KleidiAI | N'accélère que les modèles Q4_0 et active des chemins que l'auteur du moteur a vus planter. Votre processeur (Cortex-X925) n'a pas les instructions SME2 qui en tirent le plus. |
| Chiffrer le cluster | Le protocole RPC de llama.cpp n'a ni mot de passe ni chiffrement ; on ne peut que le réserver à un réseau de confiance. |
| iPhone chef de cluster | Demande de compiler pour iOS, impossible depuis ce serveur. |

### Prochaines étapes possibles

| Piste | Effort | Ce que ça apporte |
| --- | --- | --- |
| Recherche par le sens dans les documents | moyen | Trouver un passage qui répond sans reprendre les mêmes mots (aujourd'hui : recherche par mots). Demande un petit modèle d'« embeddings ». |
| Version macOS | moyen | Le moteur Metal existe ; il faut un Mac pour compiler et signer. |
| Signer l'application Windows | faible | Éviter l'avertissement « Windows a protégé votre ordinateur » (certificat payant). |
| Agents qui naviguent sur le Web (clics, formulaires) | élevé | Demande un navigateur piloté ; risques à encadrer. |

## 4. Ce que je ne peux pas faire d'ici

- essayer l'application sur un téléphone ou un vrai PC, ou mesurer une vitesse réelle ;
- détenir votre clé de signature ;
- lancer le vrai `llama-server` avec un vrai modèle, ou un cluster réel (tout a été vérifié contre un faux serveur qui parle le même protocole) ;
- faire une vraie recherche DuckDuckGo ou Wikipédia (ce serveur est refusé).
