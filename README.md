# FFMPEG-0
Cette commande, ecrite en Pascal, permet de manipuler, convertir, encoder, décoder, enregistrer et diffuser des fichiers audio et vidéo.

## ANYMP4.PAS

Clone graphique (Free Pascal / PtcGraph, 640x480) du convertisseur AnyMP4 Video Converter Ultimate : onglets
Convertisseur, Ripper, MV, Collage et Boite a outils, menus deroulants, dialogues Modifier / Couper / Format de sortie.
Tout le code est dans `ANYMP4.PAS` (aucun fichier d'inclusion, aucune unite externe, aucun appel EXEC).

```
fpc ANYMP4.PAS
```

Video MP4 (H.264 + AAC) : lecture des fichiers MP4/MOV/M4V/3GP/FLV (miniatures et apercu decodes par le decodeur
H.264 de FFMPEG.PAS : CAVLC/CABAC, I/P/B), sortie MP4/MOV/M4V/3GP par copie de flux (sans perte, avec decoupe) ou par
transcodage (rotation, rognage, effets, filigrane, redimensionnement, encodeur H.264 + AAC), image/GIF anime -> MP4,
audio -> M4A/AAC.

Audio : decodage MP3, AAC-LC, FLAC, AIFF, VOC, MOD, WAV et extraction de l'audio des fichiers AVI, FLV, MP4/MOV/M4A ;
sortie MP3, WAV (16/8 bits, IMA ADPCM), AIFF, AU, AAC, M4A. Images BMP et GIF anime (lecture/ecriture, rotation,
rognage, effets, filigrane texte), collage, diaporama MV (GIF + musique), copie des titres DVD (VIDEO_TS) vers MPEG-PS.
Limites : la video source doit etre en H.264 (MP4/MOV/M4V/3GP/FLV) ; les autres codecs/conteneurs video (AVI, MKV,
WebM, WMV...) et les sorties autres que MP4/MOV/M4V/3GP produisent un message d'erreur explicite.
