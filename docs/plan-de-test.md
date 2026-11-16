# Plan de test sur de vrais appareils

Tout ce qui suit a été vérifié par des tests automatiques et par la
compilation de l'APK, mais **jamais sur un vrai téléphone**. Ce plan dit quoi
essayer, dans quel ordre, et ce qu'il est utile de noter. Comptez une heure
pour les parties 1 à 4, une heure de plus pour les parties 5 et 6, et une heure
pour l'ordinateur (partie 7).

Pour chaque ligne, notez : ✅ fonctionne, ❌ ne fonctionne pas (avec le message
affiché), ou ⚠️ fonctionne mal (lent, plantage). En cas de plantage, les
détails sont dans **Paramètres > Journaux**.

Matériel à noter une fois : modèle de chaque téléphone, sa mémoire vive, sa
version d'Android ; système, mémoire et carte graphique de l'ordinateur.

## 1. Installation et premier lancement

| # | À faire | Attendu |
| --- | --- | --- |
| 1.1 | Installer l'APK sur un téléphone sans version précédente | L'application s'ouvre sur l'accueil, en français |
| 1.2 | Regarder la carte « Recommandé pour ce téléphone » | Le modèle proposé correspond à la mémoire du téléphone (0.8B sous 6 Go, 2B de 6 à 11 Go, 4B au-delà) |
| 1.3 | Toucher « Installer et démarrer » | Téléchargement avec progression, puis chargement automatique, puis l'accueil propose des idées de questions |
| 1.4 | Poser une question | La réponse s'affiche au fil de l'eau, la bulle de la question est en dégradé violet |

## 2. Discussion et vitesse

| # | À faire | Attendu |
| --- | --- | --- |
| 2.1 | Demander un texte long (« écris 500 mots sur… ») | L'affichage reste fluide jusqu'au bout ; noter les tok/s affichés sous la réponse |
| 2.2 | Arrêter une réponse en cours | Le texte déjà écrit est conservé, rien ne manque à la fin |
| 2.3 | Avec un modèle « Vision » : envoyer d'abord un message texte, puis une photo | Le texte répond tout de suite ; la première photo prend quelques secondes de plus (le fichier de vision se charge à ce moment) |
| 2.4 | **Paramètres > Performances > Mesurer la vitesse** | Un résultat en tokens/s ; le noter |
| 2.5 | Changer **GGUF & LiteRT** (CPU sûr, Auto rapide, GPU rapide), recharger le modèle, mesurer à nouveau | Trois résultats listés côte à côte ; noter le meilleur réglage pour ce téléphone |
| 2.5b | **Mesurer la vitesse > Trouver le meilleur réglage** | Trois essais (carte graphique, processeur, processeur 4 cœurs), puis le réglage retenu ; noter les trois résultats |
| 2.6 | Sur un téléphone Snapdragon récent : dans **GGUF & LiteRT**, choisir le moteur GPU **OpenCL**, recharger, mesurer | Noter le résultat face à Vulkan (expérimental : peut planter) |

## 3. Modèles et Hugging Face

| # | À faire | Attendu |
| --- | --- | --- |
| 3.1 | **Modèles > Parcourir** | Chaque modèle indique Idéal, Juste ou Trop gros |
| 3.2 | **Rechercher sur Hugging Face**, chercher « qwen3.5 » | Une liste de dépôts, les plus téléchargés en premier |
| 3.3 | Ouvrir un dépôt | Un fichier « Recommandé pour ce téléphone » en tête, puis toutes les tailles |
| 3.4 | Télécharger le fichier recommandé | Il apparaît dans **Mes modèles** et se charge |
| 3.5 | Chercher « LFM3 », ouvrir un dépôt GGUF | Un message dit que le moteur ne sait pas encore faire tourner ce type de modèle |
| 3.6 | Lancer un téléchargement plus gros que la place libre | Refus immédiat avec la place nécessaire et la place libre |

## 3b. Outils de la discussion

| # | À faire | Attendu |
| --- | --- | --- |
| 3b.1 | Menu **+ > Recherche Web**, demander « Quel temps fera-t-il demain à Lille ? » | Une ligne « Recherche sur le Web… », puis une réponse suivie de **Sources** avec des liens ; sinon, un message disant pourquoi (noter lequel) |
| 3b.2 | **Paramètres > Outils > Mes documents**, ajouter un PDF ; puis menu **+ > Mes documents**, poser une question dont la réponse est dans le PDF | Réponse tirée du PDF, avec **Extraits utilisés** et le nom du fichier |
| 3b.3 | Écrire « Souviens-toi que je suis végétarien », puis dans une **nouvelle** discussion demander une recette | Un message « Mémorisé », puis une recette végétarienne |
| 3b.4 | Menu **+ > Tâches > Résumer**, coller un texte, envoyer | Un résumé en cinq points |
| 3b.5 | Toucher le haut-parleur sous une réponse | Lecture à voix haute, sans lire les liens ni le code |
| 3b.6 | Ouvrir un dépôt Gemma officiel dans la recherche Hugging Face, ajouter un jeton (icône clé) | Après acceptation de la licence sur le site : téléchargement possible |

## 3c. Agents

À faire avec Qwen 3.5 4B (ou plus), ou un modèle sur l'ordinateur : avec un
modèle 2B, les agents se trompent plus souvent d'outil.

| # | À faire | Attendu |
| --- | --- | --- |
| 3c.1 | Menu **+ > Agents > Chercheur**, demander « Quel est le prix du litre de gazole en France cette semaine ? » | Une pastille « Chercheur » ; pendant le travail, « Recherche sur le Web : … » puis peut-être « Lecture de … » ; une réponse avec ses sources et un bloc **Réflexion** qui liste les étapes |
| 3c.2 | **Analyste** : « Si j'épargne 85 € par mois à 3 % par an, combien ai-je au bout de 10 ans ? » | Des étapes « Calcul : … » et un résultat chiffré |
| 3c.3 | **Documentaliste** (avec un PDF dans Mes documents) : une question sur ce PDF | Étapes « Recherche dans vos documents », réponse citant le fichier |
| 3c.4 | **Équipe de recherche** sur une question d'actualité | « Planificateur au travail (1 sur 3) », puis Chercheur, puis Relecteur ; noter la durée totale |
| 3c.5 | **Paramètres > Outils > Agents > Nouvel assistant** : créer « Organisateur de voyages » avec la recherche Web, l'utiliser | Il apparaît dans **Qui répond ?** et suit ses instructions |
| 3c.6 | Arrêter un agent pendant qu'il travaille | Il s'arrête ; aucune réponse fantôme n'arrive ensuite |

## 3d. Agents avancés

Voir [agents.md](agents.md). Avec Qwen 3.5 4B sur le téléphone, ou mieux sur
l'ordinateur (partie 7) avec gpt-oss 20B.

| # | À faire | Attendu |
| --- | --- | --- |
| 3d.1 | **Chercheur approfondi** : « Compare les forfaits mobiles 100 Go en France cette semaine » | Dans **Réflexion** : un **Plan**, plusieurs recherches et lectures, puis **Réponse vérifiée** (ou corrigée, ou « il manque quelque chose » suivi d'une nouvelle recherche) |
| 3d.2 | **Chef de projet** : « Prépare un week-end à Lyon pour deux avec 400 € : activités, budget détaillé » | « Demande à Chercheur », « Demande à Analyste », avec leurs étapes en dessous ; une réponse qui rassemble les deux |
| 3d.3 | **Assistant fichiers** : « Écris une liste de courses pour la semaine dans courses.md » | Une demande d'accord montrant le texte ; **Autoriser** ; la réponse indique le fichier écrit |
| 3d.4 | Refaire 3d.3 et **Refuser** | L'agent dit que le fichier n'a pas été écrit |
| 3d.5 | N'importe quel agent avec l'outil Mémoire : « Retiens que je suis allergique aux noix » | Une demande d'accord ; ensuite le fait apparaît dans **Paramètres > Outils > Mémoire** |
| 3d.6 | Arrêter le Chef de projet pendant qu'un assistant travaille pour lui | Tout s'arrête ; aucune réponse n'arrive ensuite |

## 3e. Modèles en ligne

| # | À faire | Attendu |
| --- | --- | --- |
| 3e.1 | **Modèles > Cloud > Anthropic (Claude)**, saisir une clé, choisir Claude Opus 5.5, poser une question | La réponse s'affiche au fil de l'eau, en français |
| 3e.2 | Même chose avec **Kimi** | Liste des modèles Kimi, réponse |

## 4. Un ordinateur fait tourner le modèle

Voir [ordinateur.md](ordinateur.md).

| # | À faire | Attendu |
| --- | --- | --- |
| 4.1 | Sur l'ordinateur, lancer `start-serveur` avec un modèle | Le script affiche l'adresse de l'ordinateur et une clé |
| 4.2 | Sur le téléphone : **Modèles > Cloud > Un ordinateur de votre réseau** | L'ordinateur est trouvé en quelques secondes, avec son modèle |
| 4.3 | Saisir la clé affichée, toucher le modèle, poser une question | La réponse vient de l'ordinateur ; noter la vitesse |
| 4.4 | Si 4.2 ne trouve rien : saisir l'adresse à la main | L'ordinateur est trouvé ; noter que la recherche automatique a échoué |
| 4.5 | Même chose depuis un deuxième téléphone en même temps | Les deux discutent avec le même ordinateur |

## 5. Cluster : 3 téléphones et l'ordinateur

Voir [cluster-ordinateur.md](cluster-ordinateur.md).

| # | À faire | Attendu |
| --- | --- | --- |
| 5.1 | Sur l'ordinateur, lancer `start-worker` | Le script affiche l'adresse à saisir |
| 5.2 | Téléphone principal : **Ajouter un ordinateur**, saisir l'adresse, **Vérifier** | La mémoire de l'ordinateur s'affiche ; noter la valeur proposée |
| 5.3 | Deux autres téléphones en **Auxiliaire**, scanner leur code QR | Trois appareils dans la liste, avec leur mémoire |
| 5.4 | Charger un modèle qui tient sur le téléphone principal | L'application demande s'il faut le garder ici ou le partager |
| 5.5 | Charger un modèle trop gros pour un seul téléphone (par exemple Gemma 4 26B-A4B, 10 Go) | Il se charge ; l'écran Cluster montre la part de chaque appareil ; noter la durée du premier chargement |
| 5.6 | Poser une question, puis **Mesurer la vitesse** | Noter les tokens/s (étiquetés « cluster × 4 ») |
| 5.7 | Recharger le même modèle | Chargement nettement plus rapide que la première fois |
| 5.8 | Éteindre un auxiliaire, recharger | Un message dit quel appareil est injoignable ; le modèle se charge sans lui si la mémoire suffit |

## 6. Limites à chercher

| # | À faire | Attendu |
| --- | --- | --- |
| 6.1 | Charger un modèle marqué « Juste » avec d'autres applications ouvertes | Chargement, ou message clair proposant un contexte plus petit ; pas de fermeture brutale |
| 6.2 | Laisser un auxiliaire écran éteint pendant une réponse | Ralentissement possible : le noter |
| 6.3 | Passer de français à anglais dans **Paramètres > Langue** | Tout l'écran change, sans redémarrage |

## 7. L'application sur ordinateur

Voir [application-pc.md](application-pc.md). Noter le système, la mémoire et
la carte graphique.

| # | À faire | Attendu |
| --- | --- | --- |
| 7.1 | Télécharger et lancer la version Windows (ou Linux) | La fenêtre PrivateLM s'ouvre ; l'accueil dit « Recommandé pour cet ordinateur » avec la mémoire (et celle de la carte graphique une fois le moteur installé) |
| 7.2 | **Installer et démarrer** le modèle proposé | Téléchargement du modèle, puis du moteur (environ 30 Mo), puis chargement ; le message dit **GPU (… couches, nom de la carte)** ou Processeur ; noter la durée |
| 7.3 | Poser une question longue, puis **Mesurer la vitesse** | Réponse fluide ; noter les tokens/s |
| 7.4 | **Paramètres > Performances > Moteur de l'ordinateur** | Le moteur installé, la carte graphique et sa mémoire |
| 7.5 | Sur une carte NVIDIA : choisir **NVIDIA (CUDA)**, recharger, mesurer | Noter la vitesse face à Vulkan |
| 7.6 | **Partager avec mes téléphones**, puis depuis un téléphone : **Modèles > Cloud > Un ordinateur de votre réseau** | L'ordinateur est trouvé ; avec la clé affichée, le téléphone discute avec le modèle de l'ordinateur |
| 7.7 | Deux téléphones en **Auxiliaire** ; sur l'ordinateur **Chercher les téléphones du réseau**, activer, charger un modèle trop gros pour l'ordinateur seul | Les téléphones apparaissent avec la mémoire prêtée ; le modèle se charge ; noter la durée et la vitesse |
| 7.8 | **Programmeur** : mettre un fichier CSV dans le dossier de travail, demander « Quelle est la moyenne de la colonne prix de ventes.csv ? » | Il lit le fichier, demande l'accord pour exécuter du Python (le code est montré), puis répond avec le résultat |
| 7.9 | Fermer la fenêtre pendant qu'un modèle est chargé | Le programme `llama-server` s'arrête aussi (Gestionnaire des tâches / `ps`) |
| 7.10 | Entrée envoie, Maj+Entrée va à la ligne, clic droit sur une discussion la supprime | Comme décrit |
| 7.11 | Sur un Mac : ouvrir `PrivateLM.app` (clic droit > Ouvrir la première fois), charger un modèle | Le moteur Metal s'installe ; le message dit GPU |
| 7.12 | **Paramètres > À propos > Mises à jour** | « Version 1.1.0 » ; toucher vérifie s'il y a plus récent |
| 7.13 | Forcer la fermeture de PrivateLM (Gestionnaire des tâches > Fin de tâche) pendant qu'un modèle est chargé, puis relancer et recharger | Le `llama-server` resté en mémoire est arrêté au lancement ; le modèle se recharge sans erreur de port ni de mémoire |

## Ce qu'il est le plus utile de me renvoyer

1. Les lignes en ❌ ou ⚠️, avec le message affiché.
2. Les mesures de vitesse (2.4 à 2.6, 4.3, 5.6, 7.3, 7.5) avec le modèle et l'appareil.
3. La durée du premier chargement en cluster (5.5, 7.7).
4. Pour les agents (3d) : si l'agent s'est trompé d'outil ou a tourné en rond, le modèle utilisé.
