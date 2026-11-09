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
  'Listening… tap mic to stop':
      "J'écoute… touchez le micro pour arrêter",
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
  'Added 15 test prompts to the batch.':
      '15 prompts de test ajoutés au lot.',
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
};
