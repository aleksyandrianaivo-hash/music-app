# LiquidGlass pour Spotify (EeveeSpotify 9.1.0)

## Compiler (depuis Windows 11)
1. Crée un dépôt GitHub (privé ou public), pousse ces fichiers (LiquidGlass.m + .github/workflows/build.yml).
2. Onglet **Actions** > "Build LiquidGlass.dylib" > **Run workflow**.
3. Télécharge l'artefact `LiquidGlass-dylib` (zip contenant LiquidGlass.dylib).

## Injecter et installer
1. Ouvre **Sideloadly**, glisse EeveeSpotify-9_1_0.ipa.
2. **Advanced Options** > **Inject dylibs/frameworks** > **+ Dylib** > choisis LiquidGlass.dylib.
3. Lance l'installation avec ton Apple ID.

## Itérer
La v1 est compilée avec `-DDUMP=1` : 8 secondes après le lancement, la hiérarchie des vues est copiée dans le presse-papiers.
Colle-la moi dans le chat : j'ajusterai les classes ciblées (cartes de l'accueil, écran lecteur, etc.).
Retire `-DDUMP=1` du workflow une fois le réglage terminé.
