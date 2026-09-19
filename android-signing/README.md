# Clé de signature Android (chiffrée)

`release.jks.enc` est la clé de signature de l'APK, chiffrée (AES-256).
Elle n'est utilisable que par la CI, avec le secret GitHub
`ANDROID_KEYSTORE_PASSPHRASE`. Sans ce secret, la CI signe avec la clé de
debug (les mises à jour par-dessus une version installée sont alors
impossibles). Ne jamais supprimer ni régénérer ce fichier : changer la clé
oblige à désinstaller l'app (et donc à perdre les données locales).
