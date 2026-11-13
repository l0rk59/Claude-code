# Publier une version de PrivateLM

GitHub fabrique l'APK lui-même. Pour qu'il soit **signé avec votre clé**
(et que les mises à jour s'installent par-dessus la version précédente), il
faut créer cette clé une fois et la confier aux « secrets » du dépôt.

## 1. Créer la clé de signature (une seule fois)

Sur un ordinateur où Java est installé (Android Studio l'installe aussi) :

```
keytool -genkeypair -v -keystore privatelm-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias privatelm
```

`keytool` demande un mot de passe et quelques informations (nom, ville…,
facultatives). **Gardez le fichier `privatelm-release.jks` et le mot de passe
en lieu sûr**, hors du dépôt : sans eux, aucune mise à jour ne pourra
s'installer par-dessus les versions déjà distribuées.

## 2. Confier la clé à GitHub

Transformez le fichier en texte :

- Linux et macOS : `base64 -w0 privatelm-release.jks > cle.txt` (macOS :
  `base64 -i privatelm-release.jks -o cle.txt`)
- Windows (PowerShell) :
  `[Convert]::ToBase64String([IO.File]::ReadAllBytes("privatelm-release.jks")) | Out-File cle.txt`

Puis sur GitHub : **Settings > Secrets and variables > Actions > New
repository secret**, quatre fois :

| Nom | Valeur |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | le contenu de `cle.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | le mot de passe du fichier |
| `ANDROID_KEY_ALIAS` | `privatelm` |
| `ANDROID_KEY_PASSWORD` | le mot de passe de la clé (le même, sauf choix contraire) |

Supprimez ensuite `cle.txt`.

## 3. Publier une version

1. Mettez à jour la version dans `pubspec.yaml` (par exemple
   `version: 1.2.0+9` : le nombre après `+` doit augmenter à chaque
   version).
2. Créez l'étiquette correspondante et poussez-la :

```
git tag v1.2.0
git push origin v1.2.0
```

GitHub construit alors l'APK (comptez 30 à 60 minutes), le signe et publie
une « release ». Sur les téléphones, **Paramètres > Rechercher des mises à
jour** la propose.

Garde-fous : sans clé dans les secrets, ou si l'étiquette ne correspond pas à
la version de `pubspec.yaml`, rien n'est publié.

## Un APK d'essai, sans publier

**Actions > APK > Run workflow** construit l'APK et le joint au résultat de
l'exécution, à télécharger depuis cette page. Sans clé dans les secrets, il
est signé avec une clé de test (son nom se termine par `-test-debug-key`) :
à installer pour essayer, jamais à diffuser.
