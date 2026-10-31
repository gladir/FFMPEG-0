# FFMPEG-0
Cette commande, ecrite en Pascal, permet de manipuler, convertir, encoder, décoder, enregistrer et diffuser des fichiers audio et vidéo.

## ANYMP4.PAS

Clone graphique (Free Pascal / PtcGraph, 640x480) du convertisseur AnyMP4 Video Converter Ultimate : onglets
Convertisseur, Ripper, MV, Collage et Boite a outils, menus deroulants, dialogues Modifier / Couper / Format de sortie.
Tout le code est dans `ANYMP4.PAS` (aucun fichier d'inclusion, aucune unite externe, aucun appel EXEC).

```
fpc ANYMP4.PAS
```

Pris en charge par le moteur integre : decodage MP3, AAC-LC, FLAC, AIFF, VOC, MOD, WAV (PCM, IMA ADPCM, A-law,
mu-law, float) et extraction de l'audio des fichiers AVI, FLV, MP4/MOV/M4A ; sortie MP3 (encodeur de FFMPEG.PAS),
WAV (16/8 bits, IMA ADPCM), AIFF, AU ; images BMP et GIF anime (lecture/ecriture, rotation, rognage, effets,
filigrane texte), collage, diaporama MV (GIF + musique), copie des titres DVD (VIDEO_TS) vers MPEG-PS.
Les sorties video (H.264, HEVC, ...) ne sont pas disponibles : l'application l'indique au lieu de simuler la conversion.
