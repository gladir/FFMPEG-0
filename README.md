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
WebM / MKV : lecture video VP8 (decodeur VP8 complet ecrit d'apres la specification RFC 6386 : images cle et inter,
interpolation au quart de pixel, 6 taps / bilineaire, filtre de boucle, images de reference or / alt-ref, partitions multiples ;
verifie identique bit a bit a la sortie de FFmpeg sur plusieurs fichiers libvpx).
Encodeur H.264 : filtre de deblocage dans la boucle (meme algorithme que le decodeur) et controle de debit adaptatif
(QP de l'image cle cherche par essais, modele de complexite pour les images P, correction de l'ecart cumule).
Limites : la video source doit etre en H.264, MPEG-4 Part 2 ou VP8 (AVI, MKV, WebM, MP4...) ; VP9 n'est pas decode, pas plus
que WMV, MS-MPEG4, etc., et les sorties autres que MP4/MOV/M4V/3GP (dont WebM) produisent un message d'erreur explicite. Si l'audio d'une source n'est pas decodable
(Vorbis, AC3...), la video est convertie sans audio et le message l'indique.
