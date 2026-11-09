// French UI text.
//
// Keys are the English text the code translates with `.tr` / `.trParams`;
// keep @placeholders as they are. test/translations_test.dart checks that
// every translated text has an entry here and that no entry is left over.

const Map<String, String> fr = {
  // ── Common ────────────────────────────────────────────────────────────
  'Cancel': 'Annuler',
  'Save': 'Enregistrer',
  'Saved': 'Enregistré',
  'Off': 'Désactivé',
  'Auto': 'Auto',
  'Default': 'Par défaut',
  'Custom': 'Personnalisé',
  'Local': 'Local',
  'Cloud': 'Cloud',
  'Light': 'Clair',
  'Dark': 'Sombre',
  'System': 'Système',
  'Recommended': 'Recommandé',
  'Small': 'Petit',
  'Large': 'Grand',
  'just now': "à l'instant",
  '@count min ago': 'il y a @count min',
  '@count h ago': 'il y a @count h',
  '@count d ago': 'il y a @count j',
  '@size GB': '@size Go',
  '@size MB': '@size Mo',
  '@ram GB RAM': '@ram Go de RAM',
  'Active: @name': 'Actif : @name',
  'No model loaded': 'Aucun modèle chargé',

  // ── Settings ──────────────────────────────────────────────────────────
  'Settings': 'Paramètres',
  'General': 'Général',
  'Appearance': 'Apparence',
  'Language': 'Langue',
  'Same language as the phone': 'Même langue que le téléphone',
  'Haptic feedback': 'Retour haptique',
  'Chat': 'Discussion',
  'Inference mode': "Mode d'inférence",
  'System prompt': 'Prompt système',
  'Model parameters': 'Paramètres du modèle',
  'Stop sequences': "Séquences d'arrêt",
  'Performance': 'Performances',
  'GPU fast': 'GPU rapide',
  'CPU safe': 'CPU sûr',
  'Auto fast': 'Auto rapide',
  'Image generation': "Génération d'images",
  'Phone cluster': 'Cluster de téléphones',
  'Master': 'Principal',
  'Worker': 'Auxiliaire',
  'About': 'À propos',
  'Device': 'Appareil',
  'Logs': 'Journaux',
  'by orailnoor & techjarves': 'par orailnoor & techjarves',
  'Version @version · by orailnoor & techjarves':
      'Version @version · par orailnoor & techjarves',
  'Theme': 'Thème',
  'Local (on-device)': "Local (sur l'appareil)",
  'Cloud API': 'API cloud',
  'Applies to local and cloud models.':
      "S'applique aux modèles locaux et cloud.",
  'System prompt saved': 'Prompt système enregistré',
  'Local models stop when they write one of these. '
          'One per line; use \\n for a newline.':
      "Les modèles locaux s'arrêtent dès qu'ils écrivent l'une de ces "
          'séquences. Une par ligne ; utilisez \\n pour un retour à la ligne.',
  'Stop sequences saved': "Séquences d'arrêt enregistrées",
  'App updates': "Mises à jour de l'app",
  '@version available': '@version disponible',
  'Up to date': 'À jour',
  "You have @current · see what's new":
      'Version installée : @current · voir les nouveautés',
  'Up to date · checked @ago': 'À jour · vérifié @ago',
  'Not checked yet': 'Pas encore vérifié',
  'Update to @version': 'Mettre à jour vers la @version',
  'Check for updates': 'Rechercher des mises à jour',
  'Check automatically': 'Vérifier automatiquement',
  'Look for a new release once a day':
      'Chercher une nouvelle version une fois par jour',
  'Text size': 'Taille du texte',
  'Small (default)': 'Petit (par défaut)',
  'Low RAM': 'Peu de RAM',
  'Use small models only': 'Petits modèles uniquement',
  'Mid-range': 'Milieu de gamme',
  'Good for 1–3B models': 'Adapté aux modèles 1–3B',
  'High-end': 'Haut de gamme',
  'Can run 3–7B models': 'Peut faire tourner des modèles 3–7B',
  'Full performance mode': 'Mode performances maximales',
  'Available memory': 'Mémoire disponible',
  'Recommended context': 'Contexte recommandé',
  'Recommended max tokens': 'Tokens max recommandés',
  'Chipset': 'Puce',
  'Recommended quant': 'Quantification recommandée',
  "Uses the GPU when supported, CPU if the GPU can't load the model":
      "Utilise le GPU s'il est pris en charge, le CPU si le GPU ne peut pas "
          'charger le modèle',
  'Always tries the GPU. Fastest, may crash on some devices':
      'Essaie toujours le GPU. Le plus rapide, peut planter sur certains '
          'appareils',
  'CPU only. Most stable, slower': 'CPU uniquement. Le plus stable, plus lent',
  'Applies to both GGUF and LiteRT models. Takes effect the next '
          'time a model is loaded.':
      "S'applique aux modèles GGUF et LiteRT. Prend effet au prochain "
          "chargement d'un modèle.",
  'Temperature': 'Température',
  'High temperature = unpredictable output!':
      'Température élevée = réponses imprévisibles !',
  'Max tokens': 'Tokens max',
  'Your phone may crash with this value!':
      'Votre téléphone risque de planter avec cette valeur !',
  'Context size': 'Taille du contexte',
  'Context capped at 4096 to prevent driver memory crash for LiteRT models.':
      'Contexte limité à 4096 pour éviter un plantage mémoire du pilote avec '
          'les modèles LiteRT.',
  'Context this large will eat all your RAM!':
      'Un contexte aussi grand va dévorer toute votre RAM !',
  'Recommended max: @value': 'Maximum recommandé : @value',
  'Above recommended': 'Au-dessus du recommandé',
  'Steps': 'Étapes',
  'Recommended: 15-20 steps': 'Recommandé : 15-20 étapes',
  'More steps = better quality but MUCH slower!':
      "Plus d'étapes = meilleure qualité, mais BEAUCOUP plus lent !",
  'Image size': "Taille de l'image",
  'Auto recommended. Bigger size = better detail, but much slower and more memory use.':
      'Auto recommandé. Plus grand = plus de détails, mais beaucoup plus lent '
          'et plus gourmand en mémoire.',
  '512 gives more detail but can be MUCH slower, heat the phone, and may fail on some devices.':
      '512 donne plus de détails mais peut être BEAUCOUP plus lent, faire '
          'chauffer le téléphone et échouer sur certains appareils.',
  'GPU safety': 'Sécurité GPU',
  'Models at or above this size use CPU. Smaller models can use GPU Experimental.':
      'Les modèles de cette taille ou plus utilisent le CPU. Les plus petits '
          'peuvent utiliser le GPU (expérimental).',
  'GPU Safety is off. Large models may crash or freeze on GPU.':
      'La sécurité GPU est désactivée. Les gros modèles peuvent planter ou se '
          'figer sur le GPU.',
  'High GPU Safety allows larger models on GPU and may crash, freeze, or overheat some phones.':
      'Une sécurité GPU élevée autorise de plus gros modèles sur le GPU et '
          'peut faire planter, figer ou surchauffer certains téléphones.',
  'Backend': 'Moteur',
  'GPU is experimental and only used below GPU Safety size.':
      "Le GPU est expérimental et n'est utilisé qu'en dessous de la taille de "
          'sécurité GPU.',

  // ── Home ──────────────────────────────────────────────────────────────
  'Models': 'Modèles',
  'Server': 'Serveur',
  'Up late?': 'Encore debout ?',
  'Good morning,': 'Bonjour,',
  'Good afternoon,': 'Bon après-midi,',
  'Good evening,': 'Bonsoir,',
  "@salutation\nwhat's on your mind?": '@salutation\nà quoi pensez-vous ?',
  'a custom endpoint': 'un point de terminaison personnalisé',
  'the cloud': 'le cloud',
  'No model selected': 'Aucun modèle sélectionné',
  'Change': 'Changer',
  'Loading · @percent%': 'Chargement · @percent %',
  'Ready': 'Prêt',
  'Switch': 'Changer',
  'Ready · Image generation · @backend':
      "Prêt · Génération d'images · @backend",
  'No model on this device': 'Aucun modèle sur cet appareil',
  'Download one to chat offline': 'Téléchargez-en un pour discuter hors ligne',
  'Browse': 'Parcourir',
  '@count downloaded': '@count téléchargé(s)',
  'Not loaded · last used': 'Non chargé · dernier utilisé',
  'Choose': 'Choisir',
  'Load': 'Charger',
  'Explain quantum computing simply':
      "Expliquer l'informatique quantique simplement",
  "Explain quantum computing simply, like I'm new to it.":
      "Explique-moi l'informatique quantique simplement, comme si je "
          'débutais.',
  'Write a polite follow-up email': 'Écrire un e-mail de relance poli',
  "Write a short, polite follow-up email to someone who hasn't replied in a week.":
      "Écris un e-mail de relance court et poli à quelqu'un qui n'a pas "
          'répondu depuis une semaine.',
  'Plan a 3-day trip to Tokyo': 'Préparer 3 jours à Tokyo',
  'Plan a relaxed 3-day trip to Tokyo with food and sightseeing.':
      'Prépare un séjour tranquille de 3 jours à Tokyo, entre gastronomie et '
          'visites.',
  'A mountain lake at golden hour': "Un lac de montagne à l'heure dorée",
  'Mountain lake at golden hour, wide shot, photorealistic':
      "Lac de montagne à l'heure dorée, plan large, photoréaliste",
  'A portrait in soft studio light': 'Un portrait en lumière studio douce',
  'Portrait of a person, soft studio lighting, 85mm, detailed':
      "Portrait d'une personne, éclairage studio doux, 85 mm, détaillé",
  'A flat editorial illustration': 'Une illustration éditoriale en aplat',
  'Flat editorial illustration of a city street, muted palette':
      "Illustration éditoriale en aplat d'une rue de ville, palette sourde",
  'How it works': 'Comment ça marche',
  'Pick a model': 'Choisissez un modèle',
  'Smaller models are faster; larger ones are smarter.':
      'Les petits modèles sont plus rapides, les grands plus intelligents.',
  'Download it once': 'Téléchargez-le une fois',
  'Usually 0.5–3 GB. Wi-Fi recommended.':
      'En général 0,5 à 3 Go. Wi-Fi recommandé.',
  'Chat offline': 'Discutez hors ligne',
  'Runs on this device. No account, no server.':
      'Tourne sur cet appareil. Sans compte, sans serveur.',

  // ── Chat list and messages ────────────────────────────────────────────
  'This conversation will be permanently deleted.':
      'Cette conversation sera définitivement supprimée.',
  'Delete': 'Supprimer',
  'Today': "Aujourd'hui",
  'Yesterday': 'Hier',
  'Previous 7 days': '7 derniers jours',
  'Previous 30 days': '30 derniers jours',
  'Older': 'Plus ancien',
  'Chats': 'Discussions',
  'New chat': 'Nouvelle discussion',
  'Search': 'Rechercher',
  'No conversations yet': 'Aucune conversation pour le moment',
  'No matches': 'Aucun résultat',
  'Your chats will show up here.': 'Vos discussions apparaîtront ici.',
  'Try a different word.': 'Essayez un autre mot.',
  'Long-press a chat to delete it':
      'Appuyez longuement sur une discussion pour la supprimer',
  'Copy': 'Copier',
  '@count tokens': '@count tokens',
  'thinking…': 'réflexion…',
  'Thinking for @seconds s…': 'Réflexion depuis @seconds s…',
  'Thinking…': 'Réflexion…',
  'Thought for @seconds s': 'Réflexion de @seconds s',
  'Thought': 'Réflexion',
  '@size KB': '@size Ko',
  '@size B': '@size o',
  'Image': 'Image',
  'Audio': 'Audio',
  'Text file': 'Fichier texte',
  'Attachment': 'Pièce jointe',

  // ── Image viewer ──────────────────────────────────────────────────────
  'Image saved to gallery': 'Image enregistrée dans la galerie',
  'Not saved': 'Non enregistrée',
  'Failed to save image: @error': "Échec de l'enregistrement : @error",
  'Error saving image: @error': "Erreur lors de l'enregistrement : @error",
  'Generated with PrivateLM': 'Générée avec PrivateLM',
  'Not shared': 'Non partagée',
  'Error sharing image: @error': 'Erreur lors du partage : @error',
  'Close': 'Fermer',
  'Download': 'Télécharger',
  'Share': 'Partager',

  // ── App update ────────────────────────────────────────────────────────
  'Update available': 'Mise à jour disponible',
  'you have @version': 'vous avez la @version',
  'Allow PrivateLM to install apps, then come back. '
          'The installer opens automatically.':
      "Autorisez PrivateLM à installer des applis, puis revenez. "
          "L'installateur s'ouvrira automatiquement.",
  'No APK for this device in the release. Download it from GitHub: @url':
      "Pas d'APK pour cet appareil dans cette version. Téléchargez-le depuis "
          'GitHub : @url',
  '@done of @total': '@done sur @total',
  'Starting download…': 'Démarrage du téléchargement…',
  'Opening installer…': "Ouverture de l'installateur…",
  'Download & install': 'Télécharger et installer',
  'Skip this version': 'Ignorer cette version',
  'Later': 'Plus tard',

  // ── Chat ──────────────────────────────────────────────────────────────
  'Context @percent% used': 'Contexte utilisé à @percent %',
  'Cloud · @provider': 'Cloud · @provider',
  'Loading model…': 'Chargement du modèle…',
  'Load a model to continue this chat':
      'Chargez un modèle pour continuer cette discussion',
  'Model': 'Modèle',
  'Context': 'Contexte',
  '@used / @total tokens': '@used / @total tokens',
  'Almost full. Start a new chat for best results.':
      'Presque plein. Lancez une nouvelle discussion pour de meilleurs '
          'résultats.',
  'Switch model': 'Changer de modèle',
  'Unload': 'Décharger',
  'Loading model': 'Chargement du modèle',
  'Reading image…': "Lecture de l'image…",
  'Listening to audio…': "Écoute de l'audio…",
  'Listening… tap mic to stop': "J'écoute… touchez le micro pour arrêter",
  'Image gen · @steps · @size · @backend':
      "Génération d'image · @steps · @size · @backend",
  '@count step': '@count étape',
  '@count steps': '@count étapes',
  'Batch complete! (@count images)': 'Lot terminé ! (@count images)',
  'Dismiss': 'Ignorer',
  'Save All': 'Tout enregistrer',
  '@count/20 batch prompts': '@count/20 prompts dans le lot',
  'Clear': 'Effacer',
  'Start Batch': 'Lancer le lot',
  'Ask anything': 'Posez votre question',
  'Load a model to start chatting':
      'Chargez un modèle pour commencer à discuter',
  'Test mode': 'Mode test',
  'Added 15 test prompts to the batch.': '15 prompts de test ajoutés au lot.',
  'Batch limit': 'Limite du lot',
  'You can add up to 20 prompts per batch.':
      "Vous pouvez ajouter jusqu'à 20 prompts par lot.",
  'Batch generation': 'Génération par lot',
  'Generating multiple images back-to-back is demanding. Your device may get warm and use more battery.':
      "Générer plusieurs images à la suite est exigeant. Votre appareil peut "
          'chauffer et consommer plus de batterie.',
  'Continue': 'Continuer',
  'Camera': 'Appareil photo',
  'Photos': 'Photos',
  'Files': 'Fichiers',
  'Needs a vision model': 'Nécessite un modèle de vision',
  '~@seconds s remaining': '~@seconds s restantes',
  '~@minutes m @seconds s remaining': '~@minutes min @seconds s restantes',
  '~@minutes m remaining': '~@minutes min restantes',
  'CPU · Slow': 'CPU · Lent',
  'Decoding image': "Décodage de l'image",
  'Generating image': "Génération de l'image",
  'VAE decode in progress…': 'Décodage VAE en cours…',
  '@percent% · Step @step of @total': '@percent % · Étape @step sur @total',
  'Elapsed: @time': 'Écoulé : @time',

  // ── Models ────────────────────────────────────────────────────────────
  'Import': 'Importer',
  'My models': 'Mes modèles',
  'Import file': 'Importer un fichier',
  'Uncensored': 'Non censuré',
  'Vision': 'Vision',
  'Imported': 'Importé',
  'Import model': 'Importer un modèle',
  'Add .gguf, .litertlm or .safetensors files from your phone.':
      'Ajoutez des fichiers .gguf, .litertlm ou .safetensors depuis votre '
          'téléphone.',
  'Choose a single model file': 'Choisir un seul fichier de modèle',
  'Import from folder': 'Importer depuis un dossier',
  'Scan a folder and pick the models to add':
      'Parcourir un dossier et choisir les modèles à ajouter',
  'No models found': 'Aucun modèle trouvé',
  'That folder has no .gguf, .litertlm or .safetensors files.':
      "Ce dossier ne contient aucun fichier .gguf, .litertlm ou .safetensors.",
  'Models in folder': 'Modèles du dossier',
  '1 file found': '1 fichier trouvé',
  '@count files found': '@count fichiers trouvés',
  'No models on this phone yet': 'Aucun modèle sur ce téléphone pour le moment',
  'Download one from Browse, or import a model file.':
      'Téléchargez-en un depuis Parcourir, ou importez un fichier de modèle.',
  'Browse models': 'Parcourir les modèles',
  'Loaded · Image generation · GPU accelerated':
      "Chargé · Génération d'images · Accéléré par GPU",
  'Loaded · Image generation · CPU': "Chargé · Génération d'images · CPU",
  'Loaded · GPU': 'Chargé · GPU',
  'Loaded · GPU · @gpu': 'Chargé · GPU · @gpu',
  'Loaded · CPU': 'Chargé · CPU',
  'Saving to Downloads · @name': 'Enregistrement dans Téléchargements · @name',
  'Vision file · @name': 'Fichier de vision · @name',
  'Image decoder (TAESD)': "Décodeur d'image (TAESD)",
  '@time left': '@time restant',
  'Pause download': 'Mettre en pause',
  'Cancel download': 'Annuler le téléchargement',
  'No online model selected': 'Aucun modèle en ligne sélectionné',
  'Loading into memory': 'Chargement en mémoire',
  'Downloading': 'Téléchargement',
  'Importing': 'Importation',
  'Providers': 'Fournisseurs',
  'Tap a provider to choose a model. Keys are stored on this device.':
      'Touchez un fournisseur pour choisir un modèle. Les clés restent sur '
          'cet appareil.',
  'Needs API key': 'Clé API requise',
  'Active': 'Actif',
  'Provider settings': 'Réglages du fournisseur',
  'Update API key': 'Modifier la clé API',
  'Add API key': 'Ajouter une clé API',
  'Required before selecting live models':
      'Nécessaire pour choisir parmi les modèles disponibles',
  'Configure and select': 'Configurer et sélectionner',
  'Select model': 'Choisir un modèle',
  'Set base URL, key, and model ID':
      "Définir l'URL de base, la clé et l'ID du modèle",
  'Search provider models or enter a model ID':
      "Chercher parmi les modèles du fournisseur ou saisir un ID de modèle",
  '@provider API key': 'Clé API @provider',
  'Save the key to verify it and load live models.':
      'Enregistrez la clé pour la vérifier et charger les modèles disponibles.',
  'Paste @provider key': 'Collez la clé @provider',
  'Show API key': 'Afficher la clé API',
  'Hide API key': 'Masquer la clé API',
  'Verifying': 'Vérification',
  'Save key': 'Enregistrer la clé',
  'Custom provider': 'Fournisseur personnalisé',
  'Use any OpenAI-compatible endpoint. Enter the base URL without /chat/completions.':
      "Utilisez n'importe quel point de terminaison compatible OpenAI. Saisissez "
          "l'URL de base sans /chat/completions.",
  'Saved provider': 'Fournisseur enregistré',
  'Choose a provider': 'Choisir un fournisseur',
  'Custom API': 'API personnalisée',
  'Add another provider': 'Ajouter un autre fournisseur',
  'Provider name': 'Nom du fournisseur',
  'My endpoint': 'Mon point de terminaison',
  'Base URL': 'URL de base',
  'API key': 'Clé API',
  'Optional for local servers': 'Facultative pour les serveurs locaux',
  'Model ID': 'ID du modèle',
  'e.g. llama-3.1-8b': 'p. ex. llama-3.1-8b',
  'Save and select': 'Enregistrer et sélectionner',
  'Remove selected provider': 'Supprimer le fournisseur sélectionné',
  'Clear form': 'Vider le formulaire',
  'Select @provider model': 'Choisir un modèle @provider',
  'Search models': 'Rechercher des modèles',
  '@count models · @fetched': '@count modèles · @fetched',
  'Free': 'Gratuit',
  'Free first (@count)': "Gratuits d'abord (@count)",
  'Refresh': 'Actualiser',
  'Use a custom model ID': 'Utiliser un ID de modèle personnalisé',
  'No models loaded': 'Aucun modèle chargé',
  'Add an API key to update the live list, or use a custom model ID.':
      'Ajoutez une clé API pour mettre à jour la liste, ou utilisez un ID de '
          'modèle personnalisé.',
  'Custom @provider model': 'Modèle @provider personnalisé',
  'Enter the exact model ID the provider expects.':
      "Saisissez l'ID exact du modèle attendu par le fournisseur.",
  'Select': 'Choisir',
  'Add key': 'Ajouter une clé',
  'Save to Downloads': 'Enregistrer dans Téléchargements',
  'Download model': 'Télécharger le modèle',
  "Save @name to your phone's public Downloads folder.":
      'Enregistrer @name dans le dossier Téléchargements public du téléphone.',
  'Download @name for use in the app.':
      "Télécharger @name pour l'utiliser dans l'app.",
  'Size': 'Taille',
  'Wi-Fi is recommended. Keep the app open while it downloads.':
      "Wi-Fi recommandé. Gardez l'app ouverte pendant le téléchargement.",
  'Delete model?': 'Supprimer le modèle ?',
  '@name will be permanently removed from this device.':
      '@name sera définitivement supprimé de cet appareil.',
  'Loading…': 'Chargement…',
  'Loaded': 'Chargé',
  'On phone': 'Sur le téléphone',
  'Save to Downloads folder (with vision file)':
      'Enregistrer dans Téléchargements (avec le fichier de vision)',
  'Save to Downloads folder': 'Enregistrer dans Téléchargements',
  'Delete model': 'Supprimer le modèle',
  'Save to phone Downloads folder':
      'Enregistrer dans les Téléchargements du téléphone',
  'Remove from list': 'Retirer de la liste',
  '★ Recommended · ': '★ Recommandé · ',
  'By size': 'Par taille',
  'By name': 'Par nom',
  'On this phone · @count': 'Sur ce téléphone · @count',
  'No models here yet': 'Aucun modèle ici pour le moment',
  'Try another type.': 'Essayez un autre type.',
  'All @count': 'Tous · @count',
  'Best for chat': 'Idéal pour discuter',
  'Understands photos': 'Comprend les photos',
  'No filters': 'Sans filtre',
  'Creates images': 'Crée des images',
  'Load model': 'Charger le modèle',
  'Downloading the vision file… images will work once it finishes.':
      'Téléchargement du fichier de vision… les images fonctionneront une '
          'fois terminé.',
  'Supports images. Download its vision file to use '
          'them; text chat works without it.':
      'Accepte les images. Téléchargez son fichier de vision pour les '
          "utiliser ; la discussion texte fonctionne sans.",
  'Supports images. Download its vision file (@size) '
          'to use them; text chat works without it.':
      'Accepte les images. Téléchargez son fichier de vision (@size) pour '
          'les utiliser ; la discussion texte fonctionne sans.',
  'Download vision file': 'Télécharger le fichier de vision',
  'Remove from list?': 'Retirer de la liste ?',
  '@name will be removed from your models. You can add it '
          'again later with the correct URL.':
      '@name sera retiré de vos modèles. Vous pourrez le rajouter plus tard '
          'avec la bonne URL.',
  'Remove': 'Retirer',
  '@size · Already in the app': "@size · Déjà dans l'app",
  'Nothing selected': 'Aucune sélection',
  'Import @count · @size': 'Importer @count · @size',
  'Files are copied into app storage, so make sure there is room.':
      "Les fichiers sont copiés dans le stockage de l'app : vérifiez qu'il "
          'reste de la place.',

  // ── Models: downloads, imports and loading ────────────────────────────
  'Imported · can read images with its vision file':
      'Importé · peut lire les images avec son fichier de vision',
  'Imported from local storage': 'Importé depuis le stockage local',
  'Local File': 'Fichier local',
  'Already downloading': 'Déjà en téléchargement',
  'This model is downloading to your Downloads folder. Wait for it to finish first.':
      "Ce modèle est en cours de téléchargement dans votre dossier "
          "Téléchargements. Attendez qu'il soit terminé.",
  'Download Failed': 'Échec du téléchargement',
  'Could not save @name.': "Impossible d'enregistrer @name.",
  'Saved to Downloads': 'Enregistré dans Téléchargements',
  '@name is in your Downloads folder.':
      '@name est dans votre dossier Téléchargements.',
  '@count files (model + vision file) are in your Downloads folder.':
      '@count fichiers (modèle + fichier de vision) sont dans votre dossier '
          'Téléchargements.',
  'Download Unavailable': 'Téléchargement indisponible',
  'This model has no download URL.':
      "Ce modèle n'a pas d'URL de téléchargement.",
  'Android Only': 'Android uniquement',
  'Use the app download button or import a local model on this platform.':
      "Utilisez le bouton de téléchargement de l'app ou importez un modèle "
          'local sur cette plateforme.',
  'Wait for the in-app download of this model to finish first.':
      "Attendez d'abord la fin du téléchargement de ce modèle dans l'app.",
  'Starting download...': 'Démarrage du téléchargement...',
  'Download Started': 'Téléchargement lancé',
  '@name is downloading to your Downloads folder.':
      '@name se télécharge dans votre dossier Téléchargements.',
  'Download cancelled': 'Téléchargement annulé',
  'Model Loading': 'Chargement du modèle',
  'Another model is already loading.':
      'Un autre modèle est déjà en cours de chargement.',
  'Helper File': 'Fichier auxiliaire',
  '@name is a helper file used by another model and cannot be loaded on its own.':
      '@name est un fichier auxiliaire utilisé par un autre modèle et ne '
          'peut pas être chargé seul.',
  'Incomplete Model File': 'Fichier de modèle incomplet',
  '@name is only @size. Delete it and download again.':
      '@name ne fait que @size. Supprimez-le et téléchargez-le à nouveau.',
  'Corrupt Model File': 'Fichier de modèle corrompu',
  '@name did not download correctly. Delete it and download again.':
      "@name ne s'est pas téléchargé correctement. Supprimez-le et "
          'téléchargez-le à nouveau.',
  '@name is not a valid LiteRT-LM file. Delete it and download again.':
      "@name n'est pas un fichier LiteRT-LM valide. Supprimez-le et "
          'téléchargez-le à nouveau.',
  'Model Not Loaded': 'Modèle non chargé',
  'Image Model': "Modèle d'image",
  'Vision file is still downloading, so images will '
          'work after you reload the model.':
      'Le fichier de vision est encore en téléchargement : les images '
          'fonctionneront après avoir rechargé le modèle.',
  'Model Loaded': 'Modèle chargé',
  'Unknown size': 'Taille inconnue',
  'Unknown': 'Inconnue',
  "This probably won't fit in free memory at a context of "
          '@context tokens. A context of @fitting tokens '
          'should fit.':
      'Il ne tiendra probablement pas dans la mémoire libre avec un contexte '
          'de @context tokens. Un contexte de @fitting tokens devrait passer.',
  'This model is probably too large for the free memory on this '
          'phone, even with a small context. Try a smaller model.':
      'Ce modèle est probablement trop gros pour la mémoire libre de ce '
          'téléphone, même avec un petit contexte. Essayez un modèle plus '
          'petit.',
  'Available RAM is lower than recommended. This can crash the app if Android cannot reserve enough memory.':
      "La RAM disponible est inférieure à la recommandation. L'app peut "
          "planter si Android ne parvient pas à réserver assez de mémoire.",
  'This can crash the app if Android cannot reserve enough memory for the model.':
      "L'app peut planter si Android ne parvient pas à réserver assez de "
          'mémoire pour le modèle.',
  'Loading local models can use more memory than the file size.':
      'Un modèle local chargé peut occuper plus de mémoire que la taille de '
          'son fichier.',
  'Image model': "Modèle d'image",
  'Local model': 'Modèle local',
  'Reload model?': 'Recharger le modèle ?',
  'Switch model?': 'Changer de modèle ?',
  'Restart recommended': 'Redémarrage recommandé',
  'Load model?': 'Charger le modèle ?',
  'Runtime': "Moteur d'exécution",
  'Available after unload': 'Disponible après déchargement',
  'Available RAM': 'RAM disponible',
  'Model size': 'Taille du modèle',
  'Estimated memory': 'Mémoire estimée',
  'Context @size for @count tokens': 'Contexte @size pour @count tokens',
  'This model is already loaded. It will be unloaded and '
          'loaded again.':
      'Ce modèle est déjà chargé. Il sera déchargé puis rechargé.',
  '@name is loaded. It will be unloaded first.':
      "@name est chargé. Il sera d'abord déchargé.",
  'Unload & continue': 'Décharger et continuer',
  'Load with @count tokens': 'Charger avec @count tokens',
  'Restart app': "Redémarrer l'app",
  '@mode LiteRT speed': 'Vitesse LiteRT : @mode',
  'GPU can make LiteRT models much faster, closer to Edge Gallery speed. '
          'On some phones GPU/OpenCL can crash the app while loading. '
          'If that happens, Auto Fast will use CPU on the next load.':
      'Le GPU peut rendre les modèles LiteRT bien plus rapides, proches de '
          "la vitesse d'Edge Gallery. Sur certains téléphones, GPU/OpenCL "
          "peut faire planter l'app au chargement. Dans ce cas, Auto rapide "
          'utilisera le CPU au chargement suivant.',
  'Import in Progress': 'Importation en cours',
  'Wait for the current import to finish.':
      "Attendez la fin de l'importation en cours.",
  'Unsupported Model': 'Modèle non pris en charge',
  'Only .gguf, .litertlm, and .safetensors files can be imported.':
      'Seuls les fichiers .gguf, .litertlm et .safetensors peuvent être '
          'importés.',
  'Import Failed': "Échec de l'importation",
  'The selected file is empty.': 'Le fichier sélectionné est vide.',
  'Unable to read the selected file. Try selecting it from local storage.':
      'Impossible de lire le fichier sélectionné. Essayez de le choisir '
          'depuis le stockage local.',
  'Copying to app storage...': "Copie dans le stockage de l'app...",
  'Import complete': 'Importation terminée',
  'Import Successful': 'Importation réussie',
  'Model @name imported.': 'Modèle @name importé.',
  'Select a model file...': 'Sélectionnez un fichier de modèle...',
  "Couldn't read folder": 'Impossible de lire le dossier',
  '1 model imported.': '1 modèle importé.',
  '@count models imported.': '@count modèles importés.',
  'Some imports failed': 'Certaines importations ont échoué',
  "@count imported · couldn't import @names":
      '@count importé(s) · échec pour @names',
  'Model already exists': 'Le modèle existe déjà',
  'A model file named "@name" is already imported in your local app storage. Would you like to replace it?':
      "Un fichier de modèle nommé « @name » est déjà importé dans le "
          "stockage de l'app. Voulez-vous le remplacer ?",
  'Replace file': 'Remplacer le fichier',
  'This GGUF uses a model architecture that is not supported by the bundled llama.cpp runtime. Update the app runtime or try a GGUF exported for a supported architecture.':
      "Ce GGUF utilise une architecture de modèle non prise en charge par le "
          "moteur llama.cpp intégré. Mettez l'app à jour ou essayez un GGUF "
          'exporté pour une architecture prise en charge.',
  'This appears to be a split GGUF model, but one or more required model files are missing. Import every split into the same folder before loading it.':
      'Ce modèle GGUF semble découpé en plusieurs parties, mais il en manque '
          'au moins une. Importez toutes les parties dans le même dossier '
          'avant de le charger.',
  'The model file appears to be incomplete or corrupted. This usually happens when the download is interrupted or the file is invalid.':
      'Le fichier du modèle semble incomplet ou corrompu. Cela arrive '
          'généralement quand le téléchargement est interrompu ou que le '
          "fichier n'est pas valide.",
  'Your device ran out of memory (RAM) trying to load this model. Mobile devices have strict memory limits; try using a smaller or more highly quantized model (e.g., 1B or 3B parameters, q4_k_m quantized).':
      "Votre appareil a manqué de mémoire (RAM) en chargeant ce modèle. Les "
          'mobiles ont des limites de mémoire strictes : essayez un modèle '
          'plus petit ou plus quantifié (p. ex. 1B ou 3B paramètres, '
          'quantifié en q4_k_m).',
  'A hardware or GPU driver error occurred while initializing the model. Try disabling GPU acceleration or switching to CPU-only inference in Settings.':
      "Une erreur matérielle ou du pilote GPU s'est produite à "
          "l'initialisation du modèle. Essayez de désactiver l'accélération "
          'GPU ou de passer en inférence CPU dans les Paramètres.',
  'The native AI engine encountered an unexpected error while loading the model. Please check the technical details below for more information.':
      "Le moteur d'IA natif a rencontré une erreur inattendue en chargeant "
          'le modèle. Consultez les détails techniques ci-dessous pour en '
          'savoir plus.',
  'Model load failed': 'Échec du chargement du modèle',
  "Phone cluster couldn't load": "Le cluster n'a pas pu charger le modèle",
  'Troubleshooting tips': 'Conseils de dépannage',
  'On each worker, open PrivateLM > Phone cluster and check that Worker is on and shows its QR code.':
      'Sur chaque auxiliaire, ouvrez PrivateLM > Cluster de téléphones et '
          'vérifiez que le mode Auxiliaire est activé et affiche son code QR.',
  'Keep every device on the same Wi-Fi. iPads must keep PrivateLM open.':
      'Gardez tous les appareils sur le même Wi-Fi. Les iPad doivent garder '
          'PrivateLM ouvert.',
  'Delete the model and try redownloading it completely.':
      'Supprimez le modèle et téléchargez-le à nouveau entièrement.',
  'Ensure your device has at least 2-3 GB of free RAM.':
      'Vérifiez que votre appareil a au moins 2 à 3 Go de RAM libre.',
  'Double check if this LiteRT-LM file matches your architecture.':
      'Vérifiez que ce fichier LiteRT-LM correspond à votre architecture.',
  'Hide technical details': 'Masquer les détails techniques',
  'Show technical details': 'Afficher les détails techniques',

  // ── Phone cluster ─────────────────────────────────────────────────────
  'Turn on Wi-Fi. All phones in the cluster must be on the same Wi-Fi network.':
      'Activez le Wi-Fi. Tous les téléphones du cluster doivent être sur le '
          'même réseau Wi-Fi.',
  'Run models too big for one phone by sharing the work across phones on the same Wi-Fi.\n\nMaster: the phone you chat on. It runs the model.\nWorker: a phone that lends its memory to the master.':
      'Faites tourner des modèles trop gros pour un seul téléphone en '
          'partageant le travail entre plusieurs téléphones sur le même '
          'Wi-Fi.\n\nPrincipal : le téléphone sur lequel vous discutez. Il '
          'exécute le modèle.\nAuxiliaire : un téléphone qui prête sa mémoire '
          'au principal.',
  "Help an Android phone running PrivateLM run models too big for it alone: choose Worker, then scan this device's QR code from that phone.":
      'Aidez un téléphone Android sous PrivateLM à faire tourner des modèles '
          'trop gros pour lui seul : choisissez Auxiliaire, puis scannez le '
          'code QR de cet appareil depuis ce téléphone.',
  'Worker stopped': 'Auxiliaire arrêté',
  'Unknown error': 'Erreur inconnue',
  'Try again': 'Réessayer',
  'Sharing with master': 'Partage avec le principal',
  'Holding': 'Hébergé',
  'Free at start': 'Libre au départ',
  'Memory speed': 'Vitesse mémoire',
  '@size GB/s': '@size Go/s',
  'Waiting for Wi-Fi…': 'En attente du Wi-Fi…',
  'Measuring this phone…': 'Mesure de ce téléphone…',
  'Scan this from the master phone': 'Scannez ce code depuis le principal',
  'Ready · @address': 'Prêt · @address',
  'Free memory': 'Mémoire libre',
  "Android is slowing this worker down (slow cores only), which slows the whole cluster. Set PrivateLM's battery use to Unrestricted, then turn Worker off and on.":
      'Android bride cet auxiliaire (cœurs lents uniquement), ce qui ralentit '
          "tout le cluster. Réglez l'utilisation de la batterie de PrivateLM "
          'sur Non restreinte, puis désactivez et réactivez Auxiliaire.',
  'Set Unrestricted': 'Passer en Non restreinte',
  'Keep this device plugged in, on the same Wi-Fi, with PrivateLM open: iOS pauses apps in the background. Close PrivateLM to stop sharing.':
      'Gardez cet appareil branché, sur le même Wi-Fi, avec PrivateLM ouvert : '
          'iOS met en pause les applis en arrière-plan. Fermez PrivateLM pour '
          'arrêter le partage.',
  'Keep this phone plugged in and on the same Wi-Fi, with PrivateLM open: the screen stays on while sharing, because Android slows background work. Set Phone cluster to Off to stop.':
      'Gardez ce téléphone branché et sur le même Wi-Fi, avec PrivateLM '
          "ouvert : l'écran reste allumé pendant le partage, car Android "
          "ralentit le travail en arrière-plan. Réglez Cluster de téléphones "
          'sur Désactivé pour arrêter.',
  "Scan a worker's QR code": "Scanner le code QR d'un auxiliaire",
  'Workers (@count)': 'Auxiliaires (@count)',
  'No workers yet': "Aucun auxiliaire pour l'instant",
  'On each other phone, open Phone cluster, choose Worker, then scan the QR code it shows.':
      'Sur chaque autre téléphone, ouvrez Cluster de téléphones, choisissez '
          'Auxiliaire, puis scannez le code QR affiché.',
  '@size free': '@size libres',
  "Used the next time you load a GGUF model. If the model fits on this phone you can keep it here, which is faster. If it doesn't, the fastest phones get the biggest share and phones that aren't needed are left out.":
      "Utilisé au prochain chargement d'un modèle GGUF. Si le modèle tient "
          "sur ce téléphone, vous pouvez le garder ici, c'est plus rapide. "
          'Sinon, les téléphones les plus rapides en prennent la plus grande '
          'part et ceux qui ne sont pas nécessaires sont laissés de côté.',
  'Other ways to add': "Autres façons d'ajouter",
  'Searching…': 'Recherche…',
  'Find nearby': 'Chercher à proximité',
  'Enter IP': "Saisir l'IP",
  'Add': 'Ajouter',
  'Enter worker IP': "Saisir l'IP de l'auxiliaire",
  "Shown under the worker's QR code":
      "Affichée sous le code QR de l'auxiliaire",
  "Couldn't add worker": "Impossible d'ajouter l'auxiliaire",
  'Worker added': 'Auxiliaire ajouté',
  'Used the next time you load a GGUF model.':
      "Utilisé au prochain chargement d'un modèle GGUF.",
  'Loaded model': 'Modèle chargé',
  'Running on @count phones · @size': 'Réparti sur @count téléphones · @size',
  '@name (this phone)': '@name (ce téléphone)',
  'Scan worker QR code': "Scanner le code QR de l'auxiliaire",
  'Point at the QR code on the worker phone':
      "Visez le code QR affiché sur l'auxiliaire",
  'Still sharing': 'Partage en cours',
  'Close PrivateLM to stop sharing this device.':
      'Fermez PrivateLM pour arrêter de partager cet appareil.',
  "That isn't a PrivateLM worker code":
      "Ce n'est pas un code d'auxiliaire PrivateLM",
  "Enter the worker phone's IP address":
      "Saisissez l'adresse IP du téléphone auxiliaire",
  'Use the form 192.168.1.20:50052': 'Utilisez le format 192.168.1.20:50052',
  "Can't reach @endpoint. Check that the phone is a worker and on the same Wi-Fi.":
      'Impossible de joindre @endpoint. Vérifiez que le téléphone est en mode '
          'auxiliaire et sur le même Wi-Fi.',
  'Not reachable, loading without: @names':
      'Injoignable(s), chargement sans : @names',
  // Cluster load errors must keep the word "cluster": the Models screen
  // uses it to recognise them.
  'This model (@size) is too big for these @count phones: together they have about @free free. Add another worker, close apps on the phones, or pick a smaller model.':
      'Ce modèle (@size) est trop gros pour les @count téléphones du cluster : '
          'ensemble, ils ont environ @free de libre. Ajoutez un auxiliaire, '
          'fermez des applis sur les téléphones ou choisissez un modèle plus '
          'petit.',
  'This model (@size) is too big for these @count phones: together they have about @free free. Not reachable: @names. Add another worker, close apps on the phones, or pick a smaller model.':
      'Ce modèle (@size) est trop gros pour les @count téléphones du cluster : '
          'ensemble, ils ont environ @free de libre. Injoignable(s) : @names. '
          'Ajoutez un auxiliaire, fermez des applis sur les téléphones ou '
          'choisissez un modèle plus petit.',
  "@error. Turn on Worker on that phone, or set this phone's Phone cluster to Off.":
      '@error. Activez Auxiliaire sur ce téléphone, ou réglez le Cluster de '
          'téléphones de cet appareil sur Désactivé.',
  'A worker is unreachable': 'Un auxiliaire est injoignable',
  "This model can't use your workers":
      'Ce modèle ne peut pas utiliser vos auxiliaires',
  '@name is a LiteRT model, and only GGUF models can be shared across phones. It will run on this phone only. To use your workers, load a GGUF model instead.':
      '@name est un modèle LiteRT, et seuls les modèles GGUF peuvent être '
          'répartis entre téléphones. Il tournera uniquement sur ce téléphone. '
          'Pour utiliser vos auxiliaires, chargez plutôt un modèle GGUF.',
  'Load on this phone only': 'Charger sur ce téléphone uniquement',
  'This model fits on this phone': 'Ce modèle tient sur ce téléphone',
  '@name needs about @size, and this phone has room for it. Running it here is faster, because sharing sends every word over Wi-Fi. Share it to free up memory on this phone.':
      "@name a besoin d'environ @size, et ce téléphone a la place. Le faire "
          'tourner ici est plus rapide, car le partage envoie chaque mot par '
          'Wi-Fi. Partagez-le pour libérer de la mémoire sur ce téléphone.',
  'Share with 1 worker': 'Partager avec 1 auxiliaire',
  'Share with @count workers': 'Partager avec @count auxiliaires',
  'This phone': 'Ce téléphone',

  // ── API server ────────────────────────────────────────────────────────
  'Loaded on this device': 'Chargé sur cet appareil',
  'Load a GGUF or LiteRT-LM model to serve it':
      'Chargez un modèle GGUF ou LiteRT-LM pour le servir',
  'Not loaded': 'Non chargé',
  'Access': 'Accès',
  'Allow network access': "Autoriser l'accès réseau",
  'Reachable from other devices on your network':
      'Accessible depuis les autres appareils de votre réseau',
  'Only apps on this device can connect':
      'Seules les applis de cet appareil peuvent se connecter',
  'Require API key': 'Exiger une clé API',
  'Always on while network access is enabled':
      "Toujours activé quand l'accès réseau est autorisé",
  'Clients send Authorization: Bearer <key>':
      'Les clients envoient Authorization: Bearer <clé>',
  'Required for every request.': 'Exigée pour chaque requête.',
  'Optional. Only checked when "Require API key" is on.':
      'Facultative. Vérifiée seulement si « Exiger une clé API » est activé.',
  'Required': 'Obligatoire',
  'Optional': 'Facultative',
  'Generate key': 'Générer une clé',
  'Copy key': 'Copier la clé',
  'Endpoints': 'Points de terminaison',
  'OpenAI base URL': 'URL de base OpenAI',
  'Usage examples': "Exemples d'utilisation",
  'List models': 'Lister les modèles',
  'Chat completion': 'Complétion de chat',
  'OpenAI SDK': 'SDK OpenAI',
  'Starting…': 'Démarrage…',
  'Running on port @port': 'En marche sur le port @port',
  'Serving @name · open to your network': 'Sert @name · ouvert à votre réseau',
  'Serving @name · this device only': 'Sert @name · cet appareil uniquement',
  'Stopped': 'Arrêté',
  'Expose @name as an OpenAI-compatible API':
      'Exposer @name comme API compatible OpenAI',
  'Expose a local model as an OpenAI-compatible API':
      'Exposer un modèle local comme API compatible OpenAI',
  'Local API server': 'Serveur API local',
  'Stop server': 'Arrêter le serveur',
  'Start server': 'Démarrer le serveur',
  'Copied': 'Copié',
  'Not available': 'Indisponible',
  'Copy @label': 'Copier : @label',
  'Server is healthy · HTTP @code': 'Le serveur fonctionne · HTTP @code',
  'Health check returned HTTP @code': 'La vérification a renvoyé HTTP @code',
  'Health check failed: @error': 'Échec de la vérification : @error',
  'Testing…': 'Test…',
  'Test connection': 'Tester la connexion',
  'Calls GET /health': 'Appelle GET /health',
  'Copy snippet': "Copier l'extrait",
  'Server stopped': 'Serveur arrêté',
  'Load a local GGUF or LiteRT-LM model first.':
      "Chargez d'abord un modèle local GGUF ou LiteRT-LM.",
  'Server not started': 'Serveur non démarré',
  'Starting server...': 'Démarrage du serveur...',
  'Server running': 'Serveur en marche',
  'Server failed': 'Échec du serveur',
  '@label copied.': '@label copié.',

  // ── Tasks ─────────────────────────────────────────────────────────────
  'Tasks': 'Tâches',
  'New task': 'Nouvelle tâche',
  'Task': 'Tâche',
  'All tasks': 'Toutes les tâches',
  'Delete task': 'Supprimer la tâche',
  'No tasks yet': "Aucune tâche pour l'instant",
  'Describe a goal and the model will plan it\ninto steps, then run them for you.':
      'Décrivez un objectif : le modèle le découpera\nen étapes, puis les '
          'exécutera pour vous.',
  'Recent': 'Récentes',
  'Swipe a task left to delete it.':
      'Balayez une tâche vers la gauche pour la supprimer.',
  '@done of @total steps · @date': '@done étape(s) sur @total · @date',
  'Planning steps…': 'Planification des étapes…',
  'No steps generated': 'Aucune étape générée',
  'The model did not return a plan for this goal.':
      "Le modèle n'a pas renvoyé de plan pour cet objectif.",
  'Task completed': 'Tâche terminée',
  'Running…': 'Exécution…',
  'Run all steps': 'Exécuter toutes les étapes',
  'The model will break your goal into steps you can run.':
      'Le modèle découpera votre objectif en étapes exécutables.',
  'Goal': 'Objectif',
  'Describe what you want done…': 'Décrivez ce que vous voulez faire…',
  'Create task': 'Créer la tâche',
  'Delete task?': 'Supprimer la tâche ?',
  'This removes the task and its steps.':
      'La tâche et ses étapes seront supprimées.',
  'Today, @time': "Aujourd'hui, @time",
  'Planning': 'Planification',
  'Running': 'En cours',
  'Completed': 'Terminée',
  'Failed': 'Échec',
  'Command execution is not available.':
      "L'exécution de commandes n'est pas disponible.",

  // ── Logs ──────────────────────────────────────────────────────────────
  'All': 'Tous',
  'Errors': 'Erreurs',
  'Warnings': 'Avertissements',
  'Info': 'Infos',
  'Debug': 'Débogage',
  'Important logs copied to the clipboard.':
      'Journaux importants copiés dans le presse-papiers.',
  'Clear logs?': 'Effacer les journaux ?',
  'All captured log entries will be removed.':
      'Toutes les entrées de journal seront supprimées.',
  'Copy important logs': 'Copier les journaux importants',
  'Clear logs': 'Effacer les journaux',
  'No logs yet': "Aucun journal pour l'instant",
  'No errors': 'Aucune erreur',
  'No warnings': 'Aucun avertissement',
  'No info': 'Aucune info',
  'No debug': 'Aucun débogage',
  'Errors, warnings and debug details will appear here.':
      'Les erreurs, avertissements et détails de débogage apparaîtront ici.',
  'Nothing at this level has been captured.':
      "Rien n'a été enregistré à ce niveau.",
  'Error': 'Erreur',
  'Warning': 'Avertissement',
  'Hide details': 'Masquer les détails',
  'Show details': 'Afficher les détails',

  // ── Cloud providers and chat messages ─────────────────────────────────
  'Free model list · OpenAI compatible':
      'Liste de modèles gratuits · compatible OpenAI',
  'Native OpenAI chat models': 'Modèles de chat OpenAI natifs',
  'OpenAI compatible V4 models': 'Modèles V4 compatibles OpenAI',
  'Gemini native API models': "Modèles de l'API Gemini native",
  'OpenAI compatible hosted NIM models':
      'Modèles NIM hébergés compatibles OpenAI',
  'Manual OpenAI-compatible endpoint':
      'Point de terminaison compatible OpenAI saisi à la main',
  'Connected': 'Connecté',
  'Needs Key': 'Clé requise',
  'Built-in list': 'Liste intégrée',
  'Not fetched yet': 'Pas encore récupérée',
  'Updated just now': "Mise à jour à l'instant",
  'Updated @count min ago': 'Mise à jour il y a @count min',
  'Updated @count h ago': 'Mise à jour il y a @count h',
  'Updated @count d ago': 'Mise à jour il y a @count j',
  'Cloud Model Active': 'Modèle cloud actif',
  'Base URL is required.': "L'URL de base est obligatoire.",
  'Enter a valid OpenAI-compatible base URL.':
      'Saisissez une URL de base valide compatible OpenAI.',
  'API key is required.': 'La clé API est obligatoire.',
  'Model ID is required.': "L'ID du modèle est obligatoire.",
  'Warning: Text-Only Model': 'Attention : modèle texte uniquement',
  'The selected model (@name) might not support images. If you get an error, switch to a vision model (like Gemini, GPT-4o, or Claude 3).':
      "Le modèle sélectionné (@name) ne gère peut-être pas les images. En cas "
          "d'erreur, passez à un modèle de vision (comme Gemini, GPT-4o ou "
          'Claude 3).',
  'Not supported by this model': 'Non pris en charge par ce modèle',
  'This model reads text only. Attach a PDF, DOCX, or text/code file.':
      'Ce modèle ne lit que du texte. Joignez un fichier PDF, DOCX ou '
          'texte/code.',
  'Unsupported file': 'Fichier non pris en charge',
  'Only images, audio, PDF, DOCX, and text/code files are supported.':
      "Seuls les images, l'audio, les PDF, les DOCX et les fichiers "
          'texte/code sont pris en charge.',
  'File not attached': 'Fichier non joint',
  'Permission Denied': 'Autorisation refusée',
  'Cannot save images without gallery access.':
      "Impossible d'enregistrer les images sans accès à la galerie.",
  'Success': 'Terminé',
  'Saved @count images to gallery.':
      '@count images enregistrées dans la galerie.',
  'Failed to save images: @error':
      "Échec de l'enregistrement des images : @error",
  'Auto size': 'Taille auto',
  'Local image generation failed.': "Échec de la génération d'image locale.",
  'Here is your generated image:': 'Voici votre image générée :',
  'Error: @error': 'Erreur : @error',
  'Describe this image.': 'Décris cette image.',
  'Summarize this PDF.': 'Résume ce PDF.',
  'Summarize this document.': 'Résume ce document.',
  'Transcribe or analyze this audio.': 'Transcris ou analyse cet audio.',
  'Review this file.': 'Analyse ce fichier.',
  'Review this attachment.': 'Analyse cette pièce jointe.',
  'Stop sequences cleared.': "Séquences d'arrêt effacées.",
  '@count stop sequence(s) saved.':
      "@count séquence(s) d'arrêt enregistrée(s).",
  'Detecting': 'Détection',
  'Unknown GPU': 'GPU inconnu',
  'GPU unavailable': 'GPU indisponible',

  // ── Local engine: loading and generation ──────────────────────────────
  'GPU (@layers layers, @gpu)': 'GPU (@layers couches, @gpu)',
  'CPU (@threads threads)': 'CPU (@threads threads)',
  'Model loaded (@accel).': 'Modèle chargé (@accel).',
  'Model loaded across @split.': 'Modèle chargé sur @split.',
  '@count phones': '@count téléphones',
  'LiteRT-LM is enabled for Android only in this app.':
      "Dans cette app, LiteRT-LM n'est disponible que sur Android.",
  'LiteRT-LM model loaded (@backend backend).':
      'Modèle LiteRT-LM chargé (moteur @backend).',
  'This LiteRT-LM file is text-only, but it was loaded as a vision model. Turn off Vision for this model or re-import it as a normal chat model.':
      'Ce fichier LiteRT-LM ne gère que le texte, mais il a été chargé comme '
          'modèle de vision. Désactivez Vision pour ce modèle ou réimportez-le '
          'comme modèle de chat normal.',
  'Model loaded in text-only mode. Its vision features are incompatible with the LiteRT engine (expected 1 signature, found multiple).':
      'Modèle chargé en mode texte seul. Ses fonctions de vision sont '
          'incompatibles avec le moteur LiteRT (1 signature attendue, '
          'plusieurs trouvées).',
  'LiteRT load failed: @error': 'Échec du chargement LiteRT : @error',
  'This vision model is incompatible with the LiteRT engine (expected 1 signature, found multiple). Please try a standard GGUF model or a text-only LiteRT model instead.':
      "Ce modèle de vision est incompatible avec le moteur LiteRT (1 "
          'signature attendue, plusieurs trouvées). Essayez plutôt un modèle '
          'GGUF standard ou un modèle LiteRT texte seul.',
  "This model can't read images. Load a vision model (one marked Vision in Models) to ask about photos.":
      'Ce modèle ne peut pas lire les images. Chargez un modèle de vision '
          '(marqué Vision dans Modèles) pour poser des questions sur des '
          'photos.',
  'GGUF audio input is not available in this build yet. Text files can be read when their content is attached, but audio needs a model/runtime path that supports audio input.':
      "L'entrée audio GGUF n'est pas encore disponible dans cette version. "
          'Les fichiers texte peuvent être lus quand leur contenu est joint, '
          "mais l'audio nécessite un modèle et un moteur qui le prennent en "
          'charge.',
  'ERROR: Generation failed — @error':
      'ERREUR : échec de la génération — @error',
  'ERROR: Model did not respond. Try a smaller model or shorter conversation.':
      "ERREUR : le modèle n'a pas répondu. Essayez un modèle plus petit ou une "
          'conversation plus courte.',
  'ERROR: Generation timed out.': 'ERREUR : délai de génération dépassé.',
  'ERROR: LiteRT-LM multimodal generation failed - @error':
      'ERREUR : échec de la génération multimodale LiteRT-LM — @error',
  'ERROR: LiteRT-LM multimodal model did not respond.':
      "ERREUR : le modèle multimodal LiteRT-LM n'a pas répondu.",
  'ERROR: LiteRT-LM multimodal generation timed out.':
      'ERREUR : délai de génération multimodale LiteRT-LM dépassé.',
  'ERROR: LiteRT-LM generation failed - @error':
      'ERREUR : échec de la génération LiteRT-LM — @error',
  'ERROR: LiteRT-LM model did not respond. Try a smaller model.':
      "ERREUR : le modèle LiteRT-LM n'a pas répondu. Essayez un modèle plus "
          'petit.',
  'ERROR: LiteRT-LM generation timed out.':
      'ERREUR : délai de génération LiteRT-LM dépassé.',
  'Stopped: this reply hit the time limit for one response.':
      'Arrêté : cette réponse a atteint la durée maximale autorisée.',
  'ERROR: Local inference is not available on this platform. Use Cloud mode.':
      "ERREUR : l'inférence locale n'est pas disponible sur cette plateforme. "
          'Utilisez le mode Cloud.',
  'Local inference is not available on this platform.':
      "L'inférence locale n'est pas disponible sur cette plateforme.",
  'ERROR: Model is already loading.':
      'ERREUR : le modèle est déjà en cours de chargement.',
  'ERROR: LiteRT models need 64-bit Android. This phone runs 32-bit Android; use a small GGUF model (under 1.5 GB) instead.':
      'ERREUR : les modèles LiteRT nécessitent Android 64 bits. Ce téléphone '
          'tourne sous Android 32 bits ; utilisez plutôt un petit modèle GGUF '
          '(moins de 1,5 Go).',
  'ERROR: This model is too large for 32-bit Android. Choose a GGUF model under 1.5 GB (for example a 1B Q4 model).':
      'ERREUR : ce modèle est trop gros pour Android 32 bits. Choisissez un '
          'modèle GGUF de moins de 1,5 Go (par exemple un modèle 1B Q4).',
  'ERROR: Cannot load image generation models (.safetensors) into the local text engine. Native local image generation requires the upcoming stable-diffusion engine update. Use Cloud Stability AI for now.':
      "ERREUR : impossible de charger un modèle de génération d'images "
          '(.safetensors) dans le moteur de texte local. La génération '
          "d'images locale native nécessite la future mise à jour du moteur "
          'stable-diffusion. Utilisez Stability AI dans le cloud pour le '
          'moment.',
  'ERROR: Failed to load model — @error':
      'ERREUR : échec du chargement du modèle — @error',
  'ERROR: No model loaded. Go to Models tab to download and load one.':
      "ERREUR : aucun modèle chargé. Allez dans l'onglet Modèles pour en "
          'télécharger et en charger un.',
  "⚠️ This Gemma model is incompatible with your Pixel's Google Tensor chip. The Q4_K_M quantization format has a known bug on Tensor SoC that produces empty responses.\n\nTry one of these fixes:\n1. Download a Q4_0 or Q5_K_M version of the same model\n2. Use a different model (Qwen, Phi, or Llama-3)\n3. Switch to Cloud mode in Settings":
      '⚠️ Ce modèle Gemma est incompatible avec la puce Google Tensor de '
          'votre Pixel. Le format de quantification Q4_K_M a un bug connu sur '
          "les SoC Tensor qui produit des réponses vides.\n\nEssayez l'une de "
          'ces solutions :\n1. Téléchargez une version Q4_0 ou Q5_K_M du même '
          'modèle\n2. Utilisez un autre modèle (Qwen, Phi ou Llama-3)\n3. '
          'Passez en mode Cloud dans les Paramètres',

  // ── Downloads and device ──────────────────────────────────────────────
  'Import this file to use it in the app.':
      "Importez ce fichier pour l'utiliser dans l'app.",
  'ERROR: Downloading models is not supported on web.':
      "ERREUR : le téléchargement de modèles n'est pas pris en charge sur le "
          'web.',
  'Download failed': 'Échec du téléchargement',
  'Switching to direct download...': 'Passage au téléchargement direct...',
  'Download was interrupted at @done of @total bytes. Tap download again to resume.':
      'Le téléchargement a été interrompu à @done octets sur @total. Touchez '
          'Télécharger à nouveau pour reprendre.',
  'Downloaded file is larger than expected; please retry.':
      'Le fichier téléchargé est plus gros que prévu ; réessayez.',
  'Download failed: @error. Tap download again to resume.':
      'Le téléchargement a échoué : @error. Touchez Télécharger à nouveau '
          'pour reprendre.',
  'Q4_K_M (safe default) · Q5_K_M for quality':
      'Q4_K_M (choix sûr) · Q5_K_M pour la qualité',
  'Q4_K_M (recommended) · Q4_0_4_8 on X Elite':
      'Q4_K_M (recommandé) · Q4_0_4_8 sur X Elite',
  'Q4_K_M (recommended)': 'Q4_K_M (recommandé)',
  'Q4_0 or Q5_K_M · AVOID Q4_K_M': 'Q4_0 ou Q5_K_M · ÉVITER Q4_K_M',
  'Q4_K_M (universal default)': 'Q4_K_M (choix universel)',
  'Google Tensor has a known bug with Q4_K_M quantization that produces empty or garbled responses. Use Q4_0 or Q5_K_M models instead.':
      'Les puces Google Tensor ont un bug connu avec la quantification Q4_K_M '
          'qui produit des réponses vides ou incohérentes. Utilisez plutôt des '
          'modèles Q4_0 ou Q5_K_M.',
  // ── Image generation, updates and cloud errors ────────────────────────
  'Image generation running': "Génération d'image en cours",
  'Progress updates for local image generation':
      "Progression de la génération d'images locale",
  'You can leave the app. We will notify you when it finishes.':
      "Vous pouvez quitter l'app. Vous serez averti à la fin.",
  '@time elapsed': '@time écoulé',
  'Working': 'En cours',
  'Finishing image': "Finalisation de l'image",
  'Decoding image...': "Décodage de l'image...",
  'Image ready': 'Image prête',
  'Generation finished in @time.': 'Génération terminée en @time.',
  'Image generation failed': "Échec de la génération d'image",
  'Open PrivateLM to check the error and try again.':
      "Ouvrez PrivateLM pour voir l'erreur et réessayer.",
  'ERROR: An image is still generating. Wait for it to finish, then load the model.':
      'ERREUR : une image est encore en cours de génération. Attendez la fin, '
          'puis chargez le modèle.',
  'Image model loaded successfully.': "Modèle d'image chargé.",
  'Failed to load CoreML model.': 'Échec du chargement du modèle CoreML.',
  'Failed to load model on iOS backend.':
      'Échec du chargement du modèle avec le moteur iOS.',
  'Could not load this model. Try CyberRealistic, Realistic Vision, or AbsoluteReality - these work reliably on most devices.\n\nTechnical detail: @error':
      'Impossible de charger ce modèle. Essayez CyberRealistic, Realistic '
          'Vision ou AbsoluteReality : ils fonctionnent bien sur la plupart '
          'des appareils.\n\nDétail technique : @error',
  'Image still generating': 'Image en cours de génération',
  'Wait for the current image to finish, then unload the model.':
      "Attendez la fin de l'image en cours, puis déchargez le modèle.",
  'The previous image is still finishing in the background. Try again in a few seconds.':
      "L'image précédente se termine encore en arrière-plan. Réessayez dans "
          'quelques secondes.',
  "You're up to date": 'Vous êtes à jour',
  'PrivateLM @version is the latest version.':
      'PrivateLM @version est la dernière version.',
  "Couldn't check for updates": 'Impossible de vérifier les mises à jour',
  'Check your connection and try again.':
      'Vérifiez votre connexion et réessayez.',
  "Couldn't start the download.": 'Impossible de lancer le téléchargement.',
  'The download failed. Try again.': 'Le téléchargement a échoué. Réessayez.',
  'Update folder unavailable.': 'Dossier de mise à jour indisponible.',
  "Couldn't open the installer.": "Impossible d'ouvrir l'installateur.",
  'ERROR: No API key configured for @provider. Go to Settings.':
      'ERREUR : aucune clé API configurée pour @provider. Allez dans les '
          'Paramètres.',
  "ERROR: @provider didn't respond in time. Check your connection and try again.":
      "ERREUR : @provider n'a pas répondu à temps. Vérifiez votre connexion "
          'et réessayez.',
  'ERROR: Cloud API request failed — @error':
      "ERREUR : échec de la requête à l'API cloud — @error",
  'ERROR: @provider returned @code — @body':
      'ERREUR : @provider a renvoyé @code — @body',
  'ERROR: @provider returned an error — @error':
      'ERREUR : @provider a renvoyé une erreur — @error',
  '@provider stopped with an error: @error':
      "@provider s'est arrêté sur une erreur : @error",
  'ERROR: @provider returned an empty response.':
      'ERREUR : @provider a renvoyé une réponse vide.',
  'The response was cut off before it finished.':
      'La réponse a été coupée avant la fin.',
  'ERROR: No user prompt found for image generation.':
      "ERREUR : aucun prompt trouvé pour la génération d'image.",
  'ERROR: No image generated.': 'ERREUR : aucune image générée.',
  'Received empty command.': 'Commande vide reçue.',
  'Executed: @command': 'Exécuté : @command',
  'Command execution is not available. Command: @command':
      "L'exécution de commandes n'est pas disponible. Commande : @command",
  'An API key is required for network access.':
      "Une clé API est obligatoire pour l'accès réseau.",

  // ── Model catalog descriptions ────────────────────────────────────────
  'Smallest LiteRT-LM general-purpose chat model for low-RAM phones':
      'Le plus petit modèle de chat LiteRT-LM polyvalent, pour les téléphones '
          'avec peu de RAM',
  'Balanced LiteRT-LM chat model with int8 quantization':
      'Modèle de chat LiteRT-LM équilibré, quantifié en int8',
  'Reasoning-focused LiteRT-LM model with int8 quantization':
      'Modèle LiteRT-LM orienté raisonnement, quantifié en int8',
  'Strong general chat LiteRT-LM model from Google Gemma':
      'Solide modèle de chat LiteRT-LM polyvalent, de Google Gemma',
  'Highest quality LiteRT-LM option; needs about 5 GB RAM':
      'Option LiteRT-LM de la meilleure qualité ; demande environ 5 Go de RAM',
  'Moonshot AI (Kimi) — 3B active MoE, high quality':
      'Moonshot AI (Kimi) — MoE 3B actifs, haute qualité',
  'Google Gemma 4 MoE, 4B active — too big for one phone: run it as a Phone cluster master with workers (~11 GB free across devices)':
      'Google Gemma 4 MoE, 4B actifs — trop gros pour un seul téléphone : '
          'lancez-le depuis un principal du Cluster de téléphones avec des '
          'auxiliaires (~11 Go libres au total)',
  'Best balance of speed and quality for mobile':
      'Meilleur équilibre vitesse/qualité sur mobile',
  "Liquid AI's fast on-device model — quick replies on mid-range phones":
      'Modèle embarqué rapide de Liquid AI — réponses vives sur les '
          'téléphones milieu de gamme',
  "Liquid AI's small vision model — fast, light enough for the GPU on most phones":
      'Petit modèle de vision de Liquid AI — rapide, assez léger pour le GPU '
          'de la plupart des téléphones',
  'Small vision model — describe photos, read text in images':
      'Petit modèle de vision — décrit les photos, lit le texte des images',
  'Uncensored Gemma 4 with image understanding — smallest quant, needs ~4 GB free RAM':
      'Gemma 4 non censuré avec compréhension des images — plus petite '
          'quantification, demande ~4 Go de RAM libre',
  "Google's multimodal Gemma — stronger image understanding, needs ~4 GB free RAM":
      'Gemma multimodal de Google — meilleure compréhension des images, '
          'demande ~4 Go de RAM libre',
  "Microsoft's compact reasoning model":
      'Modèle de raisonnement compact de Microsoft',
  "Google's newer compact chat model — fast, small, and capable":
      'Le nouveau modèle de chat compact de Google — rapide, petit et '
          'efficace',
  '🔓 Abliterated — Permanently uncensored, very smart':
      '🔓 Abliterated — définitivement non censuré, très intelligent',
  'Ultra-compact and unrestricted assistant':
      'Assistant ultra-compact et sans restriction',
  'Uncensored Dolphin 3.0 — Fast and unrestricted':
      'Dolphin 3.0 non censuré — rapide et sans restriction',
  'Uncensored Llama 3.2 3B — Smarter and unrestricted':
      'Llama 3.2 3B non censuré — plus intelligent et sans restriction',
  'Ultra-lightweight text model': 'Modèle de texte ultra-léger',
  'Extremely fast 4-step local image generation':
      "Génération d'images locale ultra-rapide en 4 étapes",
  'Photorealistic, uncensored local image generation — FP16 for mobile':
      "Génération d'images locale photoréaliste et non censurée — FP16 pour "
          'mobile',
  'Optimized for Apple devices with M-series chips or 8GB+ RAM':
      'Optimisé pour les appareils Apple à puce série M ou avec 8 Go de RAM '
          'ou plus',
  'Compressed 6-bit model optimized for Apple devices with 4GB/6GB RAM':
      'Modèle compressé 6 bits optimisé pour les appareils Apple avec 4 ou '
          '6 Go de RAM',
  'Highly popular photorealistic portrait and scene model':
      'Modèle photoréaliste très populaire pour les portraits et les scènes',
  'Photorealistic general-purpose image generation':
      "Génération d'images photoréaliste polyvalente",
  'Highly versatile Anime / Stylized image generator':
      "Générateur d'images anime / stylisées très polyvalent",
};

/// Download statuses the Android code reports in English (shown through
/// DownloadService.statusLabel). They are not in the Dart code, so the
/// translation test does not look for them there.
const Map<String, String> frNativeStatuses = {
  'Waiting to start...': 'En attente de démarrage...',
  'Downloading...': 'Téléchargement...',
  'Downloading to phone...': 'Téléchargement sur le téléphone...',
  'Paused': 'En pause',
  'Paused: waiting for network': 'En pause : en attente du réseau',
  'Paused: waiting for Wi-Fi': 'En pause : en attente du Wi-Fi',
  'Paused: retrying': 'En pause : nouvelle tentative',
  'Importing to app storage...': "Importation dans le stockage de l'app...",
  'Saving to Downloads...': 'Enregistrement dans Téléchargements...',
  'Saved to Downloads': 'Enregistré dans Téléchargements',
  'Save failed': "Échec de l'enregistrement",
  'Download stalled': 'Téléchargement bloqué',
  'Download complete': 'Téléchargement terminé',
  'Download cancelled': 'Téléchargement annulé',
  'Download failed: import error':
      "Échec du téléchargement : erreur d'importation",
};
