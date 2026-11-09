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
};
