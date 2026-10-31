# FFMPEG-0
Cette commande, ecrite en Pascal, permet de manipuler, convertir, encoder, décoder, enregistrer et diffuser des fichiers audio et vidéo.

## ANYMP4.PAS

Clone graphique (Free Pascal / PtcGraph, 640x480) du convertisseur AnyMP4 Video Converter Ultimate : onglets
Convertisseur, Ripper, MV, Collage et Boite a outils, menus deroulants, dialogues Modifier / Couper / Format de sortie.
Tout le code est dans `ANYMP4.PAS` (aucun fichier d'inclusion, aucune unite externe, aucun appel EXEC).

```
fpc ANYMP4.PAS
```

Option `-maxscreen` (Free Pascal uniquement) : utilise la resolution maximale disponible au lieu de 640x480 (meme technique que
OUTLOOK.PAS : pilote D8bit, mode le plus eleve, geometrie recalculee depuis GetMaxX/GetMaxY). Les listes, le pied de page et les
dialogues s'etirent ; `ANYMP4 -h` affiche l'aide.

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
sortie FLV (H.264 + AAC) par copie de flux ou transcodage. Les FLV VP6 sont decodes (voir plus bas).
Encodeur H.264 : filtre de deblocage dans la boucle (meme algorithme que le decodeur) et controle de debit adaptatif
(QP de l'image cle cherche par essais, modele de complexite pour les images P, correction de l'ecart cumule).
Formats video supplementaires (decodeurs et encodeurs de FFMPEG.PAS integres par extraction de dependances, ou ecrits pour ANYMP4) :
lecture WMV/ASF (VC-1, WMV1, WMV2), AVI WMV, MPEG-1/2 (ES et PS), Theora (OGV), FLV Screen Video ; sorties MKV (H.264 + AAC),
AVI (MPEG-4 + MP3), WMV (WMV2 + WMA, ASF), MPG (MPEG-2 + MP2, PS), OGV (Theora + Vorbis), WebM (encodeur VP8 ecrit pour ANYMP4 + Vorbis).
Audio : AC-3 (decodage et encodage), DTS (decodage), Vorbis (decodage OGG/WebM/MKV, encodage OGG), WMA (decodage, encodage), MP2.
Interface : lecture video animee (sans son) en cliquant sur la miniature d'un fichier, enregistrement hors ligne par cle
(exemple de cle valide : ABCDE-FGHJK-LMNPQ-RSTUH), fichier de configuration ANYMP4.INI (dossiers, options, profil, cle), fichiers
passes en argument (glisser-deposer sur l'executable), MJPEG/DV dans AVI. Le programme n'ouvre aucune connexion reseau.
Codecs ajoutes en entree (MP4/MOV, MKV/WebM, FLV, AVI selon le codec) : HEVC / H.265 (Main, Main10, RExt courants, verifie bit a bit
contre ffmpeg), VP9 (profils 0-3, 8-12 bits ; bit a bit contre ffmpeg/libvpx sur plus de 150 flux), AV1 (intra et inter, film grain,
8/10/12 bits ; bit a bit contre dav1d sur les flux testes), ProRes, VP6 / VP6A (FLV, AVI), Opus (WebM/MKV, MP4 dOps, fichiers .opus ;
ecart d'au plus 1 LSB avec ffmpeg, pas bit a bit). Les sources 10/12 bits ou 4:2:2/4:4:4 sont ramenees en 8 bits 4:2:0 par une
conversion simple (pas identique a swscale).
Sorties HEVC : profils « MP4 HEVC (H.265) » et « MKV HEVC (H.265) » (encodeur HEVC ecrit pour ANYMP4, sans images B ; lent : de l'ordre
de 0,5 s par image en 320x240). Copie de flux HEVC -> HEVC possible.
Encodeur H.264 ameliore : intra 4x4, partitions 16x8/8x16/8x8 et sous-partitions, images B (jusqu'a 3), references multiples
(jusqu'a 4), CABAC (profil Main), transformee 8x8 (profil High), choix RD ; reconstruction identique a ffmpeg sur 49 cas de test.
Gain mesure a PSNR egal : 25 a 34 % de debit en moins sur trois clips de test 320x240.
Limites : pas d'encodeur VP9 ni AV1 ; pas d'Annex B ni de couches de scalabilite pour AV1 ; Opus limite a 2 canaux et sans rognage de
fin WebM ; VP6 teste sur un seul fichier reel ; le HEVC/H.264 haute resolution est lent (non optimise). Si l'audio d'une source n'est
pas decodable, la video est convertie sans audio et le message l'indique.
