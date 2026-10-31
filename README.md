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
FLV : lecture video H.264 et Sorenson Spark (H.263 / FLV1, decodeur de FFMPEG.PAS, identique a FFmpeg image par image),
sortie FLV (H.264 + AAC) par copie de flux ou transcodage. Les FLV VP6 et Screen Video ne sont pas decodes (message d'erreur).
Encodeur H.264 : filtre de deblocage dans la boucle (meme algorithme que le decodeur) et controle de debit adaptatif
(QP de l'image cle cherche par essais, modele de complexite pour les images P, correction de l'ecart cumule).
Formats video supplementaires (decodeurs et encodeurs de FFMPEG.PAS integres par extraction de dependances, ou ecrits pour ANYMP4) :
lecture WMV/ASF (VC-1, WMV1, WMV2), AVI WMV, MPEG-1/2 (ES et PS), Theora (OGV), FLV Screen Video ; sorties MKV (H.264 + AAC),
AVI (MPEG-4 + MP3), WMV (WMV2 + WMA, ASF), MPG (MPEG-2 + MP2, PS), OGV (Theora + Vorbis), WebM (encodeur VP8 ecrit pour ANYMP4 + Vorbis).
Audio : AC-3 (decodage et encodage), DTS (decodage), Vorbis (decodage OGG/WebM/MKV, encodage OGG), WMA (decodage, encodage), MP2.
Interface : lecture video animee (sans son) en cliquant sur la miniature d'un fichier, enregistrement hors ligne par cle
(exemple de cle valide : ABCDE-FGHJK-LMNPQ-RSTUH), fichier de configuration ANYMP4.INI (dossiers, options, profil, cle), fichiers
passes en argument (glisser-deposer sur l'executable), MJPEG/DV dans AVI. Le programme n'ouvre aucune connexion reseau.
Limites : VP9 n est pas decode, pas plus
que HEVC, AV1, VP6 ; Opus n'est pas decode ; les sorties HEVC/VP9/AV1 n'existent pas. Si l'audio d'une source n'est pas decodable
(Opus, par exemple), la video est convertie sans audio et le message l indique.
