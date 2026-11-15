# Les agents de PrivateLM

Un **agent** est un assistant avec un rôle et des outils qu'il décide seul
d'utiliser, en plusieurs étapes, avant de répondre. On le choisit dans la
discussion : **menu + > Agents** (« Qui répond ? »). On les règle dans
**Paramètres > Outils > Agents**.

## 1. Les assistants fournis

| Assistant | Ce qu'il fait | Outils | Mode approfondi |
| --- | --- | --- | --- |
| Chercheur | Cherche sur le Web, lit les pages, cite ses sources | Web, pages, calcul, date | non |
| **Chercheur approfondi** | Plusieurs recherches, recoupe les sources, structure sa réponse | Web, pages, calcul, date | **oui** |
| Documentaliste | Répond d'après vos documents | Mes documents, calcul | non |
| Analyste | Chiffres, budgets, conversions | Calcul, date | non |
| **Chef de projet** | Répartit une grosse demande entre les autres assistants, plusieurs à la fois, puis rassemble leur travail | Les autres assistants, calcul, date | **oui** |
| **Programmeur** | Écrit et exécute du Python pour calculer, analyser vos fichiers, vérifier son travail | Python (ordinateur), fichiers, calcul | **oui** |
| **Assistant fichiers** | Lit, résume et écrit des fichiers dans son dossier de travail | Fichiers | non |
| Planificateur, Rédacteur, Relecteur, Traducteur, Coach | Un rôle, sans outils | — | non |

Et les **équipes** (Recherche, Rédaction, Documents), où chacun passe son
travail au suivant.

## 2. Comment un agent travaille

1. **Plan** (mode approfondi) : il écrit d'abord un plan de quelques étapes.
2. **Action** : il appelle ses outils ; le résultat lui revient ; il
   recommence jusqu'à avoir ce qu'il faut. Sur ordinateur et avec un modèle
   en ligne compatible OpenAI, le modèle appelle ses outils **lui-même**,
   **plusieurs à la fois** quand ils sont indépendants. Sur téléphone, il les
   écrit en texte, un à la fois.
3. **Vérification** (mode approfondi) : un relecteur compare la réponse aux
   éléments trouvés. Trois issues : **validée**, **corrigée**, ou **il manque
   quelque chose** : l'agent repart chercher, puis répond à nouveau.

Tout est visible dans le bloc **Réflexion** au-dessus de la réponse : le plan,
chaque outil, le travail des assistants appelés en renfort (sous « Demande à
… »), et le résultat de la vérification.

Garde-fous du moteur :

- un même appel avec les mêmes arguments n'est pas refait ;
- les vieux résultats sont raccourcis quand la mémoire du modèle se remplit ;
- au bout du nombre d'étapes permis (4 sur téléphone, 10 sur ordinateur ou en
  ligne), il doit répondre avec ce qu'il a.

## 3. Ce qu'un agent a le droit de faire

| Outil | Demande votre accord |
| --- | --- |
| Rechercher sur le Web, lire une page | non (le réseau local est interdit) |
| Chercher dans Mes documents, calculer, la date | non |
| Voir et lire les fichiers du **dossier de travail** | non |
| **Écrire un fichier** dans le dossier de travail | **oui**, avec le texte complet |
| **Exécuter du Python** (ordinateur) | **oui**, avec le code complet |
| **Retenir un fait** sur vous (Mémoire) | **oui**, avec la phrase |
| Faire appel aux autres assistants | non (ils gardent leurs propres limites) |

Le **dossier de travail** est le seul que les outils de fichiers voient :
un chemin qui en sort (`..`, chemin absolu, lien vers l'extérieur) est
refusé. Sur ordinateur, on le choisit dans **Paramètres > Outils > Agents**.

Le code Python tourne avec vos droits, dans le dossier de travail, avec une
limite d'une minute. N'autorisez que du code que vous comprenez ou que vous
jugez sûr : une page Web lue par l'agent pourrait essayer de lui dicter quoi
faire, c'est pour cela que tout ce qui écrit ou exécute vous est montré
avant.

## 4. Créer son agent

**Paramètres > Outils > Agents > Nouvel assistant** : un nom, une
description (les autres agents la lisent quand ils cherchent de l'aide), des
instructions, les outils, le **mode approfondi** si la qualité compte plus
que la vitesse, et éventuellement un modèle à charger quand on le choisit.

Les assistants fournis ne se modifient pas, mais **Copier et modifier** en
fait une version à vous.

## 5. Quel modèle pour les agents ?

| Où | Conseil |
| --- | --- |
| Téléphone | Qwen 3.5 4B au minimum ; avec un 2B, les agents se trompent plus souvent d'outil. Préférer les assistants sans mode approfondi (plus courts). |
| Ordinateur | gpt-oss 20B ou Qwen 3.5 35B-A3B : rapides et fiables avec les outils. Le Chef de projet et le Programmeur y donnent leur meilleur. |
| En ligne | Tout modèle récent compatible OpenAI (OpenAI, OpenRouter, DeepSeek, Kimi, NVIDIA, serveur perso). Anthropic et Google passent par le texte. |
