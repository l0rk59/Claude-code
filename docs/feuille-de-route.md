# Feuille de route

État du projet, ce qui reste, et ce qui dépend de vous. Mis à jour après la
première mesure sur un vrai téléphone (Dimensity 9400+, 12 Go).

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
| Clés et jetons | dans le coffre du téléphone (Keystore) | tests |
| Identité de l'application | `com.l0rk59.privatelm`, version 1.1.0 | — |
| Fabrication de l'APK sur GitHub | en place | premier essai lancé ; voir l'onglet Actions |
| Mises à jour de l'application | pointent sur ce dépôt | aucune version publiée pour l'instant |
| Télémétrie | inactive | aucun fichier de configuration Firebase : rien n'est envoyé |

## 2. Ce qui a été fait dans ce tour

- **Réglage automatique** (Paramètres > Mesurer la vitesse > Trouver le
  meilleur réglage) : essaie la carte graphique et le processeur, mesure,
  garde le plus rapide pour chaque modèle. Votre mesure (5,9 s avant le
  premier mot sur la carte Mali) laisse penser que le processeur gagnera.
- **Identité propre** : l'application s'installe à côté de celle d'origine.
- **Clés protégées** : toutes les clés passent dans le Keystore d'Android.
- **Jeton Hugging Face** : accès aux modèles officiels sous licence (Gemma,
  Llama…).
- **Modèles en plusieurs fichiers** : téléchargés, comptés et supprimés
  ensemble.
- **Serveur de l'ordinateur protégé par une clé**, créée et affichée par le
  script, demandée une fois par l'application.
- **Outils de discussion** (menu +) : recherche Web (DuckDuckGo, Brave
  Search ou votre SearXNG), Mes documents (recherche dans vos fichiers, sur
  le téléphone), Tâches (demandes prêtes à l'emploi et les vôtres), avec les
  sources sous la réponse. Plus la mémoire (« Souviens-toi que… ») et la
  lecture à voix haute.
- **APK fabriqué par GitHub**, signé avec votre clé : voir
  [publier.md](publier.md).

## 3. Ce qui reste

### À faire de votre côté

| Quoi | Pourquoi |
| --- | --- |
| Lancer « Trouver le meilleur réglage » sur Qwen 3.5 2B puis 4B | savoir ce qui est réellement le plus rapide sur votre téléphone |
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
| Le modèle décide lui-même de chercher sur le Web | moyen | Aujourd'hui c'est vous qui activez la recherche. Fiable seulement avec les modèles qui gèrent les « outils » (Qwen 3.5 4B et plus). |
| L'ordinateur chef d'orchestre du cluster, depuis l'application | moyen | Garder le fichier du modèle sur l'ordinateur tout en empruntant la mémoire des téléphones, sans ligne de commande. |
| Application pour ordinateur | élevé | Remplacer les scripts par PrivateLM lui-même sur Windows et Linux. |

## 4. Ce que je ne peux pas faire d'ici

- essayer l'application sur un téléphone ou mesurer une vitesse réelle ;
- détenir votre clé de signature ;
- lancer `llama-server` ou un cluster réel ;
- faire une vraie recherche DuckDuckGo ou Wikipédia (ce serveur est refusé).
