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
| **Application pour ordinateur** (Windows, Linux, macOS) | nouveau | compilée pour les trois sur GitHub ; version Linux utilisée de bout en bout sur un écran virtuel, en français, en largeur ordinateur et téléphone ; pas encore lancée sur un vrai PC |
| Moteur de l'ordinateur (llama.cpp b11157 `llama-server`) | **testé pour de vrai** | à chaque modification, GitHub télécharge le vrai moteur et le fait tourner avec Qwen 3.5 0.8B, sur Windows et Linux : installation, chargement, discussion, appel d'outil, agent, mode approfondi, arrêt — tout passe |
| L'ordinateur chef du cluster (téléphones en Auxiliaire) | nouveau | dialogue avec le vrai `ggml-rpc-server` b11157 vérifié ; aucun chargement réel réparti |
| Clés et jetons | dans le coffre du téléphone (Keystore) | tests |
| Identité de l'application | `com.l0rk59.privatelm`, version 1.1.0 | — |
| Fabrication de l'APK sur GitHub | en place | construit avec succès sur GitHub (environ 18 minutes) |
| Fabrication de l'application pour ordinateur sur GitHub | en place | construite avec succès : Windows (zip, 16 Mo), Linux (tar.gz, 19 Mo), macOS (zip, 26 Mo) ; ajoutées à la version publiée |
| Modèles en ligne : Claude et Kimi | en place | Anthropic (Claude Opus 5.5, Sonnet 5.5, Haiku 5.5, Fable 5.2) et Kimi apparaissent dans Modèles > Cloud ; requêtes Claude mises à jour (version 2026-10-21, réponses au fil de l'eau, modèle de secours si Claude refuse) ; tests du format, pas d'essai avec une vraie clé |
| Mises à jour de l'application | pointent sur ce dépôt | aucune version publiée pour l'instant |
| Télémétrie | retirée | Firebase, inactif, a été enlevé : il bloquait la version Windows ; les erreurs restent dans Paramètres > Journaux |

## 2. Ce qui a été fait dans ce tour

**Le moteur de l'ordinateur testé pour de vrai.** GitHub télécharge à chaque
modification le vrai llama.cpp et le fait tourner avec un petit modèle, sur
Windows et Linux. Ce test a trouvé un vrai défaut, corrigé : en mode
approfondi, la réflexion de Qwen 3.5 épuisait la place du plan.

**Version macOS**, construite par GitHub, et **mise à jour sur ordinateur**
(Paramètres > À propos).

**Perfectionnement de l'ensemble** (revue du code et de chaque écran, en
français, en largeur ordinateur et téléphone) :

- l'ordinateur parle d'« ordinateur » partout (adéquation des modèles,
  documents, espace disque, langue…), vérifie l'espace disque avant un
  téléchargement, recommande d'abord les modèles faits pour lui, centre les
  pages sur grand écran ;
- nombres et tailles à la française (« 5,49 Go ») ; noms de modèles au lieu
  des noms de fichiers ; majuscule après « Encore debout ? » ;
- une longue discussion qui dépasse la mémoire du modèle repart sans ses plus
  anciens messages au lieu d'échouer ; un téléphone auxiliaire éteint est
  écarté au lieu de bloquer le chargement ; messages clairs si le moteur
  manque ;
- les agents reconnaissent un assistant même mal orthographié (« Analyst »
  pour « Analyste ») ; noms d'outils courts dans la liste ;
- **Claude et Kimi** ajoutés aux modèles en ligne ; requêtes Claude corrigées
  (elles envoyaient un réglage que les modèles actuels refusent, et ne
  lisaient pas la réponse des modèles qui réfléchissent) ;
- le **prompt système par défaut** demande de répondre dans la langue de la
  question (les petits modèles répondaient parfois en anglais) et s'appelle
  PrivateLM ; l'écran ne l'affiche plus « Personnalisé » à tort ;
- le test des traductions refuse désormais une forme d'écriture qui lui avait
  caché un texte resté en anglais.

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
| Signer l'application macOS | faible | Éviter le clic droit > Ouvrir au premier lancement (compte développeur Apple payant). |
| Signer l'application Windows | faible | Éviter l'avertissement « Windows a protégé votre ordinateur » (certificat payant). |
| Agents qui naviguent sur le Web (clics, formulaires) | élevé | Demande un navigateur piloté ; risques à encadrer. |

## 4. Ce que je ne peux pas faire d'ici

- essayer l'application sur un téléphone ou un vrai PC, ou mesurer une vitesse réelle ;
- détenir votre clé de signature ;
- lancer le vrai `llama-server` avec un vrai modèle, ou un cluster réel (tout a été vérifié contre un faux serveur qui parle le même protocole) ;
- faire une vraie recherche DuckDuckGo ou Wikipédia (ce serveur est refusé).
