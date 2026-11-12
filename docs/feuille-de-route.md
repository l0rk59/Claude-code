# Feuille de route

État du projet, ce qui manque, dans quel ordre le traiter, et ce qui dépend de
vous. Rédigé après l'audit complet du dépôt.

## 1. Où en est le projet

| Domaine | État | Comment c'est vérifié |
| --- | --- | --- |
| Interface (français, refonte, accueil guidé) | en place | tests, captures de la version web |
| Modèles sur le téléphone (GGUF, LiteRT) | en place et réglés | tests ; jamais mesuré sur un vrai téléphone |
| Recherche Hugging Face | en place | tests, réponses réelles de Hugging Face |
| Un ordinateur fait tourner le modèle | nouveau | tests contre de faux serveurs ; `llama-server` n'a pas été lancé |
| Cluster téléphones + ordinateur | en place | dialogue vérifié contre le vrai `ggml-rpc-server` b11157 ; aucun chargement réel réparti |
| Mesure de vitesse | nouveau | tests |
| Mises à jour de l'application | pointent sur ce dépôt | aucune version publiée pour l'instant |
| Tests automatiques sur GitHub | en place | première exécution réussie sur GitHub |
| Télémétrie | inactive | aucun fichier de configuration Firebase : rien n'est envoyé |

Le point faible est unique et il est partout : **rien n'a tourné sur un vrai
appareil**. Tant que ce n'est pas fait, « ça marche » veut dire « ça compile
et les tests passent ».

## 2. Ce qui a changé avec cet audit

- La vérification de mise à jour interrogeait le projet d'origine. Ses APK
  sont signés avec une autre clé : Android les aurait refusés, et ils n'ont
  aucune des fonctions ajoutées ici. Elle interroge maintenant ce dépôt.
- Un téléchargement qui ne tient pas sur le stockage est refusé avant de
  commencer, au lieu d'échouer après des heures.
- Nouvelle méthode d'utilisation : l'ordinateur fait tourner le modèle, le
  téléphone le trouve sur le Wi-Fi et sert d'écran ([ordinateur.md](ordinateur.md)).
- Un test de vitesse intégré, pour comparer deux réglages sur le téléphone
  lui-même.
- Des tests automatiques lancés à chaque envoi sur GitHub.

## 3. Ce qui manque, par priorité

### Priorité 0 : valider sur de vrais appareils

Dépend de vous. Le [plan de test](plan-de-test.md) dit quoi essayer et quoi
noter. C'est la seule façon de savoir quels réglages sont réellement les
meilleurs sur vos téléphones, et de trouver les défauts que les tests ne
voient pas.

### Priorité 1 : pouvoir diffuser l'application

| Manque | Qui | Détail |
| --- | --- | --- |
| Clé de signature | vous | L'APK actuel est signé avec une clé de test. Il faut créer une clé une fois et remplir `android/key.properties` (modèle : `android/key.properties.example`). Je ne peux pas détenir cette clé à votre place. |
| Première version publiée | vous, puis moi | Publier une « release » sur ce dépôt avec l'APK : la mise à jour intégrée la proposera alors aux téléphones. |
| Nom de l'application | décision | Le paquet s'appelle encore `com.orailnoor.privatelm`, comme l'application d'origine : les deux ne peuvent pas être installées ensemble. Le changer oblige à réinstaller une fois. |

### Priorité 1 : des modèles vraiment puissants

Ce qui existe : l'ordinateur du réseau, le cluster avec ordinateur, la
recherche Hugging Face avec indication de compatibilité.

| Manque | Effort | Ce que ça apporte |
| --- | --- | --- |
| Modèles en plusieurs fichiers | moyen | Les plus gros modèles (au-delà de 50 Go environ) ne sont publiés qu'en plusieurs parties, que l'application ne sait pas télécharger. |
| Jeton Hugging Face | moyen | Les dépôts officiels sous licence (Gemma, Llama) demandent un compte. Aujourd'hui il faut passer par un autre éditeur du même modèle. |
| Puce NPU des Snapdragon | élevé | llama.cpp sait l'utiliser dans cette version ; l'intégrer demande le kit de Qualcomm et un téléphone de test. Gain potentiel important. |
| KleidiAI (processeurs Arm récents) | faible à tester | Désactivé, l'auteur du moteur ayant signalé des plantages. À réessayer avec un appareil sous la main. |
| L'ordinateur chef d'orchestre du cluster | moyen | Aujourd'hui en ligne de commande et expérimental. L'intégrer permettrait de garder le fichier du modèle sur l'ordinateur tout en empruntant la mémoire des téléphones. |
| Application pour ordinateur | élevé | Remplacerait les scripts par PrivateLM lui-même sur Windows et Linux. |

### Priorité 2 : des modèles plus utiles, pas seulement plus gros

Un modèle plus gros répond mieux ; un modèle outillé fait plus de choses.
Rien de ceci n'existe encore :

- recherche sur le Web et outils appelés par le modèle ;
- questions sur vos propres documents (la lecture des fichiers existe, pas la
  recherche dans un ensemble de documents) ;
- mémoire d'une discussion à l'autre ;
- lecture des réponses à voix haute (la dictée existe) ;
- la vue « Tâches » annoncée par le projet d'origine.

### Priorité 2 : qualité et sécurité

| Manque | Détail |
| --- | --- |
| Liaisons sans mot de passe | Le cluster et le serveur de l'ordinateur n'ont ni mot de passe ni chiffrement : réseau de confiance uniquement. Une clé partagée est possible côté serveur, pas côté cluster (limite de llama.cpp). |
| Clés stockées en clair | Les clés des services en ligne sont enregistrées sans chiffrement sur le téléphone. |
| Fabrication de l'APK en automatique | Les tests tournent sur GitHub, pas encore la construction de l'APK. |
| iPhone | Peut prêter sa mémoire à un cluster, pas le diriger. |

## 4. Les décisions que j'attends de vous

1. **Les résultats du plan de test**, même partiels.
2. **Diffusion** : pour vous seul, ou pour d'autres ? Cela décide de la clé de
   signature et du nom de l'application.
3. **La suite** : mon conseil est de ne pas chercher des modèles encore plus
   gros. Les modèles en plusieurs fichiers ne concernent que ceux de plus de
   50 Go, que trois téléphones et un portable ne porteraient pas. Ce qui
   rendra l'ensemble plus puissant à l'usage, ce sont les outils de la
   priorité 2 : recherche sur le Web et questions sur vos documents.

## 5. Ce que je ne peux pas faire d'ici

- essayer l'application sur un téléphone, ou mesurer une vitesse réelle ;
- signer l'APK pour une diffusion publique ;
- lancer `llama-server` ou un cluster réel ;
- intégrer la puce NPU sans le kit de Qualcomm et sans appareil.
