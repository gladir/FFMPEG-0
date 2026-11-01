# FFMPEG-0
Cette commande, ecrite en Pascal, permet de manipuler, convertir, encoder, décoder, enregistrer et diffuser des fichiers audio et vidéo.

Aperçu de AnyMP4 :

<img width="637" height="485" alt="image" src="https://github.com/user-attachments/assets/bfcce22f-6f3c-4b7e-8102-da1aa7f10562" />

<h3>Liste des fichiers</h3>

Voici la liste des différents fichiers proposés dans FFMPEG-0 :

<table>
	<tr>
		<th>Nom</th>
		<th>Description</th>
	</tr>
	<tr>
    <td><b>ANYMP4.PAS</b></td>
    <td>Cette commande permet de lancer un clone AnyMP4.</td>
  </tr>
  <tr>	
    <td><b>FFMPEG.PAS</b></td>
    <td>Cette commande permet de manipuler, convertir, encoder, décoder, enregistrer et diffuser des fichiers audio et vidéo.</td>
  </tr>
</table>

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
Codecs ajoutes en entree (MP4/MOV, MKV/WebM, FLV, AVI, TS, MXF selon le codec) : HEVC / H.265 (Main, Main10, RExt courants), VP9 (profils 0-3,
8-12 bits), AV1 (intra, inter, film grain, 8/10/12 bits), ProRes, VP6 / VP6A, Opus (WebM/MKV, MP4 dOps, .opus ; 1 a 8 canaux), ainsi que
MPEG-TS / M2TS / MTS (H.264, HEVC, MPEG-2 ; AAC, AC-3, MP2, MP3, DTS, LPCM), flux bruts .264 / .hevc / .m2v, et MXF (H.264, MPEG-2, ProRes).
Sources 10/12 bits et 4:2:2 / 4:4:4 : conversion vers 8 bits 4:2:0 identique a `ffmpeg -pix_fmt yuv420p` (port de swscale, verifie bit a bit
sur 512 comparaisons) ; sources HDR (PQ/HLG) : mappage de tonalite vers SDR, ou passthrough 10 bits avec metadonnees (VUI, SEI, colr/mdcv/clli).
Sorties video : H.264 (intra 4x4, partitions, images B, CABAC, references multiples, 8x8), HEVC (Main et Main10), VP9 (WebM/MP4/MKV), AV1 (WebM/MP4/MKV),
ProRes (Proxy, LT, 422, HQ, 4444 ; identique a prores_ks), DNxHD / DNxHR (MOV, AVI, MXF), MJPEG (MOV, AVI, MKV), H.263 (3GP, 3GP2, MP4), MPEG-TS /
M2TS / MTS (H.264, HEVC), MXF OP1a (H.264, DNxHD, ProRes + PCM), plus les formats historiques (AVI MPEG-4, WMV, MPG, OGV, FLV, WebM VP8, ...).
Audio multicanal 5.1 / 7.1 : decodage AC-3, AAC, Opus, Vorbis, DTS (core), FLAC, WAV, AIFF ; mixage vers stereo/mono comme ffmpeg ; encodage AAC, AC-3,
FLAC, WAV 5.1 ; choix des canaux dans la boite Format de sortie.
Ripper : DVD (dossier VIDEO_TS ou image ISO/UDF) et Blu-ray (dossier BDMV ou image) avec liste des titres, chapitres et duree ; copie sans
reencodage (MPEG-2 PS, M2TS). Les disques proteges (CSS, AACS, BD+) sont detectes et refuses : aucun dechiffrement n'est tente.
Option `-maxscreen` : resolution maximale sous Free Pascal (voir plus haut).
Limites : les encodeurs VP9 et AV1 sont simples (pas de prediction composee, pas de segmentation / restauration de boucle ; AV1 sans images B) et lents
(environ 0,5 a 1 s par image en 320x240) ; l'encodeur HEVC n'a pas d'images B ; pas d'H.264 High10 ; M4V protege par DRM : non pris en charge (aucun
contournement de protection) ; E-AC-3, DTS-HD, TrueHD, AAC LATM, HE-AAC non decodes ; le decalage audio/video initial d'un fichier TS n'est pas applique ;
les retouches (rotation, recadrage...) travaillent en 8 bits ; fichiers de plus de 2 Go non pris en charge (entiers 32 bits) ; DNxHD/MJPEG non decodes dans
MXF ; VP6 teste sur un seul fichier reel ; tout a ete verifie sur des clips synthetiques de quelques secondes, aucun disque ni fichier de camera reel. Si
l'audio d'une source n'est pas decodable, la video est convertie sans audio et le message l'indique.
