{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/ffmpeg-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application ANYMP4 (Convertisseur Video Ultimate).
   Interface graphique complete. Video MP4/MOV/M4V/3GP (H.264 + AAC) : lecture,
   copie de flux, transcodage, miniatures. Moteurs audio (MP3, AAC, WAV, AIFF, VOC, MOD,
   encodeur MP3) adaptes de FFMPEG.PAS, extraction audio AVI/FLV/MP4/MOV/M4A, FLAC natif,
   GIF anime, collage et diaporama. Aucune dependance externe.
   Les moteurs (decodeur/encodeur H.264, MP3, AAC-LC, AIFF, VOC, MOD, encodeur MP3,
   primitives ADPCM) proviennent de FFMPEG.PAS et sont adaptes de FFmpeg (LGPL-2.1+). }

Program ANYMP4;

{$IFDEF FPC}
 {$MODE TP}
 {$R-}{$Q-}{$S-}
{$ELSE}
 {$N+,E+}{$R-}{$S-}{$M 32768,0,655360}
{$ENDIF}

Uses {$IFDEF FPC}
      {$IFDEF UNIX}cthreads,{$ENDIF}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

{$IFNDEF FPC}
 Function MouseDriverFound: Boolean;
 Var
  Regs: Registers;
 Begin
  Regs.AX := 0;
  Intr($33, Regs);
  MouseDriverFound := Regs.AX = $FFFF;
 End;

 Procedure ShowMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0001;
  Intr($33, Regs);
 End;

 Procedure HideMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0003;
  Intr($33, Regs);
  Button := Regs.BX;
  X := Regs.CX;
  Y := Regs.DX;
 End;
{$ELSE}
 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 Procedure ShowMouse;
 Begin
  { Le curseur est gere par la fenetre PtcGraph }
 End;

 Procedure HideMouse;
 Begin
  { Le curseur est gere par la fenetre PtcGraph }
 End;
{$ENDIF}

{ ====================================================================== }
{ Constantes, types et variables globales                                 }
{ ====================================================================== }
Const
 ScrW = 640;
 ScrH = 480;
 { Indices de la palette personnalisee }
 cBlack = 0;  cBlue = 1;   cGreen = 2;  cSky = 3;    cRed = 4;    cNavy = 5;
 cOrange = 6; cPanel = 7;  cGrayD = 8;  cBlueL = 9;  cGreenL = 10;
 cSteel = 11; cOrangeL = 12; cLine = 13; cGold = 14; cWhite = 15;

 PalRGB: Array[0..15,0..2] Of Byte = (
  (0,0,0),(28,110,214),(40,160,70),(214,230,248),(220,50,50),(20,60,130),
  (255,126,20),(242,244,248),(120,126,138),(90,160,240),(150,215,150),
  (176,190,210),(255,200,150),(208,214,224),(250,200,50),(255,255,255));
 DacReg: Array[0..15] Of Byte = (0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63);

 { Evenements }
 evNone = 0; evDown = 1; evUp = 2; evKey = 3;
 kEnter = 13; kEsc = 27; kBack = 8; kTab = 9;
 kUp = 328; kDown = 336; kLeft = 331; kRight = 333; kHome = 327; kEnd = 335;
 kPgUp = 329; kPgDn = 337; kDel = 339;

 MaxHot = 200;
 MaxFiles = 24;
 MaxProf = 64;

Type
 TEvent = Record
  Kind: Byte;
  X,Y: Integer;
  Key: Integer;
 End;
 THot = Record
  X1,Y1,X2,Y2: Integer;
  Id: Integer;
 End;
 TStr80 = String[80];

Var
 Hot: Array[0..MaxHot] Of THot;
 HotN: Integer;
 MBtn0: LongInt;
 Font8: Array[32..255,0..7] Of Byte;
 LastClickT: LongInt;
 LastClickX,LastClickY: Integer;
 DblClick: Boolean;
 Quit: Boolean;

{ ---------------------------------------------------------------------- }
{ Utilitaires generaux                                                     }
{ ---------------------------------------------------------------------- }
Function IStr(N: LongInt): String;
Var S: String;
Begin
 Str(N,S); IStr:=S;
End;

Function Pad2(N: LongInt): String;
Begin
 If N<10 Then Pad2:='0'+IStr(N) Else Pad2:=IStr(N);
End;

Function Max(A,B: LongInt): LongInt;
Begin
 If A>B Then Max:=A Else Max:=B;
End;

Function Min(A,B: LongInt): LongInt;
Begin
 If A<B Then Min:=A Else Min:=B;
End;

Function UpStr(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 UpStr:=S;
End;

Function ValL(S: String): LongInt;
Var N: LongInt; C: Integer;
Begin
 Val(S,N,C);
 If C<>0 Then N:=0;
 ValL:=N;
End;

Function TimeStr(Ms: LongInt): String;
Var S: LongInt;
Begin
 If Ms<0 Then Ms:=0;
 S:=Ms Div 1000;
 TimeStr:=Pad2(S Div 3600)+':'+Pad2((S Div 60) Mod 60)+':'+Pad2(S Mod 60);
End;

Function TimeStrMs(Ms: LongInt): String;
Var T: String;
Begin
 T:=IStr((Ms Mod 1000)+1000);
 TimeStrMs:=TimeStr(Ms)+'.'+Copy(T,2,3);
End;

Function ParseTime(S: String): LongInt;
Var P,A: Integer; Sec,Ms: LongInt; Part: String;
Begin
 { hh:mm:ss[.mmm] ou mm:ss ou ss }
 Sec:=0; Ms:=0;
 P:=Pos('.',S);
 If P>0 Then Begin
  Part:=Copy(S,P+1,3); While Length(Part)<3 Do Part:=Part+'0';
  Ms:=ValL(Part); S:=Copy(S,1,P-1);
 End;
 While Length(S)>0 Do Begin
  A:=Pos(':',S);
  If A=0 Then Begin Sec:=Sec*60+ValL(S); S:='' End
  Else Begin Sec:=Sec*60+ValL(Copy(S,1,A-1)); S:=Copy(S,A+1,255) End;
 End;
 ParseTime:=Sec*1000+Ms;
End;

Function SizeStr(N: LongInt): String;
Var V: LongInt;
Begin
 If N<1024 Then SizeStr:=IStr(N)+' o'
 Else If N<1048576 Then Begin
  V:=(N*10) Div 1024; SizeStr:=IStr(V Div 10)+'.'+IStr(V Mod 10)+' Ko';
 End Else If N<1073741824 Then Begin
  V:=(N Div 1024)*10 Div 1024; SizeStr:=IStr(V Div 10)+'.'+IStr(V Mod 10)+' Mo';
 End Else Begin
  V:=(N Div 1048576)*10 Div 1024; SizeStr:=IStr(V Div 10)+'.'+IStr(V Mod 10)+' Go';
 End;
End;

Function FileExists(Const Name: String): Boolean;
Var F: File; A: Word;
Begin
 Assign(F,Name); GetFAttr(F,A);
 FileExists:=(DosError=0) And ((A And Directory)=0);
End;

Function DirExists(Const Name: String): Boolean;
Var F: File; A: Word; N: String;
Begin
 N:=Name;
 If (Length(N)>3) And ((N[Length(N)]='\') Or (N[Length(N)]='/')) Then Dec(N[0]);
 Assign(F,N); GetFAttr(F,A);
 DirExists:=(DosError=0) And ((A And Directory)<>0);
End;

Function FileSizeOf(Const Name: String): LongInt;
Var F: File; Old: Byte;
Begin
 FileSizeOf:=0;
 Assign(F,Name); Old:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Exit;
 FileSizeOf:=FileSize(F); Close(F);
End;

Procedure DelFile(Const Name: String);
Var F: File;
Begin
 Assign(F,Name);
 {$I-}Erase(F);{$I+}
 If IOResult<>0 Then ;
End;

Function ExtOf(Const P: String): String;
Var I: Integer;
Begin
 ExtOf:='';
 For I:=Length(P) DownTo 1 Do Begin
  If (P[I]='\') Or (P[I]='/') Or (P[I]=':') Then Exit;
  If P[I]='.' Then Begin ExtOf:=UpStr(Copy(P,I+1,10)); Exit End;
 End;
End;

Function BaseOf(Const P: String): String;
Var I: Integer; N: String;
Begin
 N:=P;
 For I:=Length(P) DownTo 1 Do
  If (P[I]='\') Or (P[I]='/') Or (P[I]=':') Then Begin N:=Copy(P,I+1,255); Break End;
 For I:=Length(N) DownTo 1 Do
  If N[I]='.' Then Begin N:=Copy(N,1,I-1); Break End;
 BaseOf:=N;
End;

Function NameOf(Const P: String): String;
Var I: Integer;
Begin
 NameOf:=P;
 For I:=Length(P) DownTo 1 Do
  If (P[I]='\') Or (P[I]='/') Or (P[I]=':') Then Begin NameOf:=Copy(P,I+1,255); Exit End;
End;

Function DirOf(Const P: String): String;
Var I: Integer;
Begin
 DirOf:='';
 For I:=Length(P) DownTo 1 Do
  If (P[I]='\') Or (P[I]='/') Or (P[I]=':') Then Begin DirOf:=Copy(P,1,I); Exit End;
End;

Function AddSlash(Const P: String): String;
Begin
 If (P<>'') And (P[Length(P)]<>'\') And (P[Length(P)]<>'/') Then
 {$IFDEF UNIX} AddSlash:=P+'/' {$ELSE} AddSlash:=P+'\' {$ENDIF}
 Else AddSlash:=P;
End;

Function Clip(V,Lo,Hi: LongInt): LongInt;
Begin
 If V<Lo Then V:=Lo; If V>Hi Then V:=Hi; Clip:=V;
End;

Function Ticks: LongInt;
Var H,M,S,C: Word;
Begin
 GetTime(H,M,S,C);
 Ticks:=((H*60+M)*60+S)*100+C;
End;

{ ---------------------------------------------------------------------- }
{ Texte : UTF-8 vers CP437 (police BGI par defaut)                         }
{ ---------------------------------------------------------------------- }
Function CP(U: Word): Char;
Begin
 Case U Of
  $E9: CP:=#130; $E8: CP:=#138; $EA: CP:=#136; $EB: CP:=#137; $E0: CP:=#133;
  $E2: CP:=#131; $E4: CP:=#132; $E7: CP:=#135; $EE: CP:=#140; $EF: CP:=#139;
  $F4: CP:=#147; $F6: CP:=#148; $F9: CP:=#151; $FB: CP:=#150; $FC: CP:=#129;
  $C9: CP:=#144; $C7: CP:=#128; $B0: CP:=#248; $B7: CP:=#250; $D7: CP:='x';
  $AB: CP:=#174; $BB: CP:=#175; $C0,$C2: CP:='A'; $C8,$CA: CP:='E';
  $A0: CP:=' '; $2026: CP:='.'; $25BE: CP:=#31; $25B8: CP:=#16; $2713: CP:=#251;
  $2022: CP:=#7; $2192: CP:=#26; $2013: CP:='-';
  $20..$7E: CP:=Chr(U);
  Else CP:='?';
 End;
End;

Function U2A(Const S: String): String;
Var I,L: Integer; C: Byte; R: String; U: Word;
Begin
 R:=''; I:=1; L:=Length(S);
 While I<=L Do Begin
  C:=Ord(S[I]);
  If C<128 Then Begin R:=R+Chr(C); Inc(I); End
  Else If ((C And $E0)=$C0) And (I<L) And ((Ord(S[I+1]) And $C0)=$80) Then Begin
   U:=((C And $1F) Shl 6) Or (Ord(S[I+1]) And $3F); R:=R+CP(U); Inc(I,2);
  End
  Else If ((C And $F0)=$E0) And (I+1<L) And ((Ord(S[I+1]) And $C0)=$80)
   And ((Ord(S[I+2]) And $C0)=$80) Then Begin
   U:=((C And $0F) Shl 12) Or ((Ord(S[I+1]) And $3F) Shl 6) Or (Ord(S[I+2]) And $3F);
   R:=R+CP(U); Inc(I,3);
  End
  Else Begin
   If C>=$C0 Then R:=R+CP(C) Else R:=R+Chr(C);
   Inc(I);
  End;
 End;
 U2A:=R;
End;

Function TextW(Const S: String): Integer;
Begin
 TextW:=Length(U2A(S))*8;
End;

Procedure Txt(X,Y: Integer; Const S: String; C: Byte);
Begin
 SetColor(C);
 OutTextXY(X,Y,U2A(S));
End;

Procedure TxtC(X1,X2,Y: Integer; Const S: String; C: Byte);
Begin
 Txt(X1+((X2-X1)-TextW(S)) Div 2,Y,S,C);
End;

Procedure TxtR(X,Y: Integer; Const S: String; C: Byte);
Begin
 Txt(X-TextW(S),Y,S,C);
End;

{ Texte tronque a une largeur donnee (pixels) }
Function Fit(Const S: String; W: Integer): String;
Var A: String; N: Integer;
Begin
 A:=U2A(S); N:=W Div 8;
 If Length(A)<=N Then Fit:=S
 Else If N<4 Then Fit:=''
 Else Begin
  A:=Copy(S,1,N-3);
  { eviter de couper une sequence UTF-8 }
  While (Length(A)>0) And (Ord(A[Length(A)])>=$C0) Do Dec(A[0]);
  Fit:=A+'...';
 End;
End;

{ ---------------------------------------------------------------------- }
{ Primitives graphiques                                                     }
{ ---------------------------------------------------------------------- }
Procedure SetPal(C,R,G,B: Integer);
Begin
 {$IFDEF FPC}
  SetRGBPalette(C,R,G,B);
 {$ELSE}
  SetRGBPalette(DacReg[C],R Shr 2,G Shr 2,B Shr 2);
 {$ENDIF}
End;

Procedure InitPalette;
Var I: Integer;
Begin
 For I:=0 To 15 Do SetPal(I,PalRGB[I,0],PalRGB[I,1],PalRGB[I,2]);
End;

Procedure Rect(X1,Y1,X2,Y2: Integer; Fill: Byte);
Begin
 SetFillStyle(SolidFill,Fill);
 Bar(X1,Y1,X2,Y2);
End;

Procedure Frame(X1,Y1,X2,Y2: Integer; C: Byte);
Begin
 SetColor(C);
 Rectangle(X1,Y1,X2,Y2);
End;

Procedure Panel(X1,Y1,X2,Y2: Integer; Fill,Border: Byte);
Begin
 Rect(X1,Y1,X2,Y2,Fill);
 Frame(X1,Y1,X2,Y2,Border);
End;

Procedure HLn(X1,X2,Y: Integer; C: Byte);
Begin
 SetColor(C); Line(X1,Y,X2,Y);
End;

Procedure VLn(X,Y1,Y2: Integer; C: Byte);
Begin
 SetColor(C); Line(X,Y1,X,Y2);
End;

Procedure Disc(X,Y,R: Integer; C: Byte);
Begin
 SetFillStyle(SolidFill,C); SetColor(C);
 FillEllipse(X,Y,R,R);
End;

Procedure Tri(X,Y: Integer; Dir: Integer; C: Byte);
Var P: Array[0..2] Of PointType;
Begin
 { Dir: 0 bas, 1 haut, 2 droite, 3 gauche ; (X,Y) = centre ; demi-taille 4 }
 Case Dir Of
  0: Begin P[0].X:=X-4; P[0].Y:=Y-2; P[1].X:=X+4; P[1].Y:=Y-2; P[2].X:=X; P[2].Y:=Y+3; End;
  1: Begin P[0].X:=X-4; P[0].Y:=Y+2; P[1].X:=X+4; P[1].Y:=Y+2; P[2].X:=X; P[2].Y:=Y-3; End;
  2: Begin P[0].X:=X-2; P[0].Y:=Y-4; P[1].X:=X-2; P[1].Y:=Y+4; P[2].X:=X+3; P[2].Y:=Y; End;
  Else Begin P[0].X:=X+2; P[0].Y:=Y-4; P[1].X:=X+2; P[1].Y:=Y+4; P[2].X:=X-3; P[2].Y:=Y; End;
 End;
 SetFillStyle(SolidFill,C); SetColor(C);
 FillPoly(3,P);
End;

Procedure CaptureFont;
Var C,R,K: Integer;
Begin
 SetTextStyle(DefaultFont,HorizDir,1);
 SetTextJustify(LeftText,TopText);
 For C:=32 To 255 Do Begin
  Rect(0,0,15,15,0);
  SetColor(15);
  OutTextXY(0,0,Chr(C));
  For R:=0 To 7 Do Begin
   Font8[C,R]:=0;
   For K:=0 To 7 Do
    If GetPixel(K,R)<>0 Then Font8[C,R]:=Font8[C,R] Or (128 Shr K);
  End;
 End;
 Rect(0,0,15,15,0);
End;

{ ---------------------------------------------------------------------- }
{ Zones cliquables et evenements                                            }
{ ---------------------------------------------------------------------- }
Procedure HotClear;
Begin
 HotN:=0;
End;

Procedure HotAdd(X,Y,W,H,Id: Integer);
Begin
 If HotN>=MaxHot Then Exit;
 Hot[HotN].X1:=X; Hot[HotN].Y1:=Y; Hot[HotN].X2:=X+W-1; Hot[HotN].Y2:=Y+H-1;
 Hot[HotN].Id:=Id; Inc(HotN);
End;

Function HotAt(X,Y: Integer): Integer;
Var I: Integer;
Begin
 HotAt:=0;
 For I:=HotN-1 DownTo 0 Do
  If (X>=Hot[I].X1) And (X<=Hot[I].X2) And (Y>=Hot[I].Y1) And (Y<=Hot[I].Y2) Then Begin
   HotAt:=Hot[I].Id; Exit;
  End;
End;

Function GetHot(Id: Integer; Var X,Y,W,H: Integer): Boolean;
Var I: Integer;
Begin
 GetHot:=False;
 For I:=HotN-1 DownTo 0 Do
  If Hot[I].Id=Id Then Begin
   X:=Hot[I].X1; Y:=Hot[I].Y1; W:=Hot[I].X2-X+1; H:=Hot[I].Y2-Y+1;
   GetHot:=True; Exit;
  End;
End;

Procedure ReadMouse(Var X,Y: Integer; Var B: LongInt);
Var MX,MY: LongInt;
Begin
 GetMouseState(MX,MY,B);
 X:=MX; Y:=MY;
End;

Function PollEvent(Var E: TEvent): Boolean;
Var C: Char; X,Y: Integer; B: LongInt;
Begin
 PollEvent:=False; E.Kind:=evNone; E.Key:=0;
 If KeyPressed Then Begin
  C:=ReadKey;
  If C=#0 Then Begin C:=ReadKey; E.Key:=256+Ord(C); End Else E.Key:=Ord(C);
  E.Kind:=evKey; PollEvent:=True; Exit;
 End;
 ReadMouse(X,Y,B);
 E.X:=X; E.Y:=Y;
 If ((B And 1)<>0) And ((MBtn0 And 1)=0) Then Begin
  E.Kind:=evDown; PollEvent:=True;
 End Else If ((B And 1)=0) And ((MBtn0 And 1)<>0) Then Begin
  E.Kind:=evUp; PollEvent:=True;
  DblClick:=(Ticks-LastClickT<35) And (Ticks>=LastClickT) And
   (Abs(X-LastClickX)<6) And (Abs(Y-LastClickY)<6);
  LastClickT:=Ticks; LastClickX:=X; LastClickY:=Y;
 End;
 MBtn0:=B;
End;

Procedure WaitEvent(Var E: TEvent);
Begin
 While Not PollEvent(E) Do Delay(8);
End;

Function MouseDown: Boolean;
Var X,Y: Integer; B: LongInt;
Begin
 ReadMouse(X,Y,B);
 MouseDown:=(B And 1)<>0;
End;

{ ---------------------------------------------------------------------- }
{ Widgets                                                                    }
{ ---------------------------------------------------------------------- }
Const
 bsNormal = 0; bsPrimary = 1; bsBlue = 2; bsFlat = 3; bsSel = 4; bsOff = 5;

Procedure Button(X,Y,W,H: Integer; Const S: String; Id: Integer; Style: Integer);
Var Bg,Fg,Bd: Byte;
Begin
 Case Style Of
  bsPrimary: Begin Bg:=cOrange; Fg:=cWhite; Bd:=cOrange; End;
  bsBlue: Begin Bg:=cBlue; Fg:=cWhite; Bd:=cBlue; End;
  bsFlat: Begin Bg:=cPanel; Fg:=cNavy; Bd:=cPanel; End;
  bsSel: Begin Bg:=cSky; Fg:=cNavy; Bd:=cBlue; End;
  bsOff: Begin Bg:=cLine; Fg:=cGrayD; Bd:=cSteel; End;
  Else Begin Bg:=cWhite; Fg:=cBlack; Bd:=cSteel; End;
 End;
 Panel(X,Y,X+W-1,Y+H-1,Bg,Bd);
 TxtC(X,X+W-1,Y+(H-8) Div 2,S,Fg);
 If Id<>0 Then HotAdd(X,Y,W,H,Id);
End;

Procedure CheckBox(X,Y: Integer; Const S: String; On: Boolean; Id: Integer);
Begin
 Panel(X,Y,X+11,Y+11,cWhite,cGrayD);
 If On Then Begin
  SetColor(cBlue); Line(X+2,Y+6,X+4,Y+9); Line(X+4,Y+9,X+9,Y+2);
  Line(X+2,Y+5,X+4,Y+8); Line(X+4,Y+8,X+9,Y+1);
 End;
 Txt(X+16,Y+2,S,cBlack);
 If Id<>0 Then HotAdd(X,Y,16+TextW(S),12,Id);
End;

Procedure Radio(X,Y: Integer; Const S: String; On: Boolean; Id: Integer);
Begin
 Disc(X+6,Y+6,6,cGrayD); Disc(X+6,Y+6,5,cWhite);
 If On Then Disc(X+6,Y+6,3,cBlue);
 Txt(X+16,Y+2,S,cBlack);
 If Id<>0 Then HotAdd(X,Y,16+TextW(S),12,Id);
End;

Procedure Toggle(X,Y: Integer; On: Boolean; Id: Integer);
Begin
 If On Then Begin
  Panel(X,Y,X+27,Y+12,cOrange,cOrange);
  Disc(X+21,Y+6,4,cWhite);
 End Else Begin
  Panel(X,Y,X+27,Y+12,cLine,cSteel);
  Disc(X+6,Y+6,4,cWhite);
 End;
 If Id<>0 Then HotAdd(X,Y,28,13,Id);
End;

Procedure Combo(X,Y,W,H: Integer; Const S: String; Id: Integer);
Begin
 Panel(X,Y,X+W-1,Y+H-1,cWhite,cSteel);
 Txt(X+4,Y+(H-8) Div 2,Fit(S,W-22),cBlack);
 Tri(X+W-9,Y+H Div 2,0,cGrayD);
 If Id<>0 Then HotAdd(X,Y,W,H,Id);
End;

Procedure SliderBar(X,Y,W: Integer; V,Lo,Hi: LongInt; Id: Integer);
Var P: Integer;
Begin
 Rect(X,Y+4,X+W-1,Y+6,cLine);
 If Hi=Lo Then P:=0 Else P:=((V-Lo)*(W-8)) Div (Hi-Lo);
 Rect(X,Y+4,X+P+3,Y+6,cBlue);
 Panel(X+P,Y,X+P+7,Y+10,cWhite,cBlue);
 If Id<>0 Then HotAdd(X,Y-2,W,14,Id);
End;

Function SliderVal(X,W: Integer; MX: Integer; Lo,Hi: LongInt): LongInt;
Begin
 SliderVal:=Lo+((Clip(MX-X-4,0,W-8))*(Hi-Lo)) Div (W-8);
End;

Procedure ProgBar(X,Y,W,H: Integer; Pct: Integer);
Begin
 Panel(X,Y,X+W-1,Y+H-1,cLine,cSteel);
 If Pct>0 Then Rect(X+1,Y+1,X+1+((W-2)*Clip(Pct,0,100)) Div 100,Y+H-2,cBlue);
End;

Procedure Shadow(X1,Y1,X2,Y2: Integer);
Begin
 Rect(X1+3,Y2+1,X2+3,Y2+3,cGrayD);
 Rect(X2+1,Y1+3,X2+3,Y2+3,cGrayD);
End;

{ ---------------------------------------------------------------------- }
{ Icones                                                                     }
{ ---------------------------------------------------------------------- }
Procedure IcoPlus(X,Y,R: Integer; C: Byte);
Begin
 SetColor(C); Circle(X,Y,R);
 Line(X-R+3,Y,X+R-3,Y); Line(X,Y-R+3,X,Y+R-3);
End;

Procedure IcoFolder(X,Y: Integer; C: Byte);
Begin
 Rect(X,Y+2,X+5,Y+4,C);
 Rect(X,Y+4,X+13,Y+12,C);
 Rect(X+1,Y+6,X+12,Y+11,cWhite);
 Rect(X+1,Y+6,X+12,Y+7,C);
End;

Procedure IcoFilm(X,Y: Integer; C: Byte);
Var I: Integer;
Begin
 { cercle de conversion }
 SetColor(C); Circle(X+16,Y+16,12); Circle(X+16,Y+16,11);
 Rect(X+4,Y+10,X+28,Y+20,cBlue);
 SetColor(C);
 Line(X+9,Y+8,X+16,Y+4); Line(X+16,Y+4,X+16,Y+8);
 Line(X+23,Y+24,X+16,Y+28); Line(X+16,Y+28,X+16,Y+24);
 For I:=0 To 2 Do Rect(X+11+I*4,Y+14,X+12+I*4,Y+17,C);
End;

Procedure IcoDisc(X,Y: Integer; C: Byte);
Begin
 SetColor(C); Circle(X+16,Y+16,12); Circle(X+16,Y+16,11);
 Circle(X+16,Y+16,4); Circle(X+16,Y+16,3);
 Line(X+16,Y+4,X+22,Y+6); Line(X+22,Y+6,X+16,Y+8);
End;

Procedure IcoMV(X,Y: Integer; C: Byte);
Begin
 Panel(X+4,Y+6,X+28,Y+24,cBlue,C);
 Tri(X+17,Y+15,2,C);
 Rect(X+7,Y+9,X+9,Y+11,C); Rect(X+7,Y+19,X+9,Y+21,C);
 Rect(X+25,Y+9,X+27,Y+11,C); Rect(X+25,Y+19,X+27,Y+21,C);
 SetColor(C); Line(X+9,Y+3,X+23,Y+3); Line(X+9,Y+3,X+9,Y+6);
End;

Procedure IcoCollage(X,Y: Integer; C: Byte);
Begin
 Panel(X+4,Y+4,X+28,Y+28,cBlue,C);
 Line(X+16,Y+4,X+16,Y+28); Line(X+4,Y+16,X+28,Y+16);
 Rect(X+6,Y+6,X+14,Y+14,cSky); Rect(X+18,Y+18,X+26,Y+26,cSky);
End;

Procedure IcoToolbox(X,Y: Integer; C: Byte);
Begin
 Panel(X+4,Y+10,X+28,Y+27,cBlue,C);
 Rect(X+5,Y+17,X+27,Y+18,C);
 Rect(X+14,Y+15,X+18,Y+20,cWhite);
 SetColor(C); Rectangle(X+11,Y+5,X+21,Y+10);
End;

Procedure IcoStar(X,Y: Integer; C: Byte);
Begin
 SetColor(C);
 Line(X+6,Y,X+6,Y+12); Line(X,Y+6,X+12,Y+6);
 Line(X+2,Y+2,X+10,Y+10); Line(X+10,Y+2,X+2,Y+10);
 Circle(X+6,Y+6,3);
End;

Procedure IcoScissors(X,Y: Integer; C: Byte);
Begin
 SetColor(C);
 Circle(X+3,Y+10,2); Circle(X+9,Y+10,2);
 Line(X+4,Y+8,X+9,Y); Line(X+8,Y+8,X+3,Y);
End;

Procedure IcoPalette(X,Y: Integer; C: Byte);
Begin
 SetColor(C); Ellipse(X+6,Y+6,0,360,6,5);
 Disc(X+3,Y+5,1,C); Disc(X+6,Y+3,1,C); Disc(X+9,Y+5,1,C);
End;

Procedure IcoGear(X,Y: Integer; C: Byte);
Var I: Integer;
Begin
 SetColor(C); Circle(X+6,Y+6,4); Circle(X+6,Y+6,2);
 For I:=0 To 7 Do Begin
  Case I Of
   0: Rect(X+5,Y,X+7,Y+1,C); 1: Rect(X+5,Y+11,X+7,Y+12,C);
   2: Rect(X,Y+5,X+1,Y+7,C); 3: Rect(X+11,Y+5,X+12,Y+7,C);
   4: Rect(X+1,Y+1,X+2,Y+2,C); 5: Rect(X+10,Y+1,X+11,Y+2,C);
   6: Rect(X+1,Y+10,X+2,Y+11,C); 7: Rect(X+10,Y+10,X+11,Y+11,C);
  End;
 End;
End;

Procedure IcoPlay(X,Y: Integer; C: Byte);
Begin
 Tri(X+4,Y+5,2,C);
End;

Procedure IcoInfo(X,Y: Integer; C: Byte);
Begin
 SetColor(C); Circle(X+5,Y+5,5);
 Rect(X+4,Y+4,X+5,Y+8,C); Rect(X+4,Y+2,X+5,Y+2,C);
End;

Procedure IcoMove(X,Y: Integer; C: Byte);
Begin
 SetColor(C);
 Line(X+5,Y,X+5,Y+10); Line(X,Y+5,X+10,Y+5);
 Tri(X+5,Y+1,1,C); Tri(X+5,Y+9,0,C); Tri(X+1,Y+5,3,C); Tri(X+9,Y+5,2,C);
End;

Procedure IcoClose(X,Y: Integer; C: Byte);
Begin
 SetColor(C); Line(X,Y,X+8,Y+8); Line(X,Y+8,X+8,Y); Line(X+1,Y,X+8,Y+7); Line(X,Y+1,X+7,Y+8);
End;

Procedure IcoKey(X,Y: Integer; C: Byte);
Begin
 SetColor(C); Circle(X+3,Y+4,3);
 Line(X+6,Y+4,X+13,Y+4); Line(X+11,Y+4,X+11,Y+7); Line(X+13,Y+4,X+13,Y+7);
End;

Procedure IcoSpeaker(X,Y: Integer; C: Byte);
Begin
 Rect(X,Y+3,X+3,Y+7,C);
 SetColor(C); Line(X+3,Y+3,X+7,Y); Line(X+7,Y,X+7,Y+10); Line(X+3,Y+7,X+7,Y+10);
 Arc(X+7,Y+5,300,60,4); Arc(X+7,Y+5,300,60,6);
End;

{ ====================================================================== }
{ Menus deroulants (style PAINT), boites de dialogue, selecteur fichiers   }
{ ====================================================================== }
Type
 TBarHit = Function(X: Integer): Integer;

Var
 BarHitProc: TBarHit;
 RedrawHook: Procedure;
 PopX,PopY: Integer;       { position du clic ayant ferme le menu }
 PopSwitch: Integer;       { titre de la barre de menus survole (>0) }
 PopMenuBarH: Integer;
 PopCurMenu: Integer;
 Dirty: Boolean;
 LastDir: String;

Procedure Refresh;
Begin
 Dirty:=True;
 If @RedrawHook<>Nil Then RedrawHook;
End;

Function SaveBG(X1,Y1,X2,Y2: Integer): Pointer;
Var P: Pointer; Sz: LongInt;
Begin
 SaveBG:=Nil;
 If X2>=ScrW Then X2:=ScrW-1;
 If Y2>=ScrH Then Y2:=ScrH-1;
 Sz:=ImageSize(X1,Y1,X2,Y2);
 {$IFNDEF FPC}
 If (Sz>65000) Or (Sz>MaxAvail) Then Begin Dirty:=True; Exit; End;
 {$ENDIF}
 GetMem(P,Sz);
 GetImage(X1,Y1,X2,Y2,P^);
 SaveBG:=P;
End;

Procedure RestBG(P: Pointer; X1,Y1,X2,Y2: Integer);
Var Sz: LongInt;
Begin
 If P=Nil Then Exit;
 If X2>=ScrW Then X2:=ScrW-1;
 If Y2>=ScrH Then Y2:=ScrH-1;
 PutImage(X1,Y1,P^,NormalPut);
 Sz:=ImageSize(X1,Y1,X2,Y2);
 FreeMem(P,Sz);
End;

{ Menu deroulant. Items separes par '|', '-' = separateur, 'texte^raccourci'.
  Retourne l'index (1..n) ou 0 si annule. }
Function PopupMenu(X,Y: Integer; Const Items: String; Sel,MinW: Integer): Integer;
Const MaxItems = 80;
Var
 Lab: Array[1..MaxItems] Of String[60];
 Acc: Array[1..MaxItems] Of String[16];
 N,I,P,W,H,Vis,Top,Hov,RowH,X2,Y2,Res,Tmp,LW,AW: Integer;
 S: String;
 BG: Pointer;
 E: TEvent;
 Done: Boolean;
 Up,Dn: Boolean;

 Procedure Draw;
 Var K,Idx,YY: Integer; Fg: Byte;
 Begin
  Panel(X,Y,X2,Y2,cWhite,cBlack);
  Shadow(X,Y,X2,Y2);
  For K:=0 To Vis-1 Do Begin
   Idx:=Top+K; YY:=Y+2+K*RowH;
   If Idx>N Then Break;
   If Lab[Idx]='-' Then Begin
    HLn(X+3,X2-3,YY+RowH Div 2,cSteel);
   End Else Begin
    If Idx=Hov Then Begin Rect(X+2,YY,X2-2,YY+RowH-1,cBlue); Fg:=cWhite; End
    Else Fg:=cBlack;
    If Idx=Sel Then Txt(X+5,YY+3,#251,Fg);
    Txt(X+18,YY+3,Lab[Idx],Fg);
    If Acc[Idx]<>'' Then TxtR(X2-6,YY+3,Acc[Idx],Fg);
   End;
  End;
  If Top>1 Then Tri(X2-8,Y+5,1,cGrayD);
  If Top+Vis<=N Then Tri(X2-8,Y2-5,0,cGrayD);
 End;

Begin
 N:=0; S:=Items;
 While S<>'' Do Begin
  P:=Pos('|',S);
  If P=0 Then Begin Inc(N); Lab[N]:=Copy(S,1,60); S:='' End
  Else Begin Inc(N); Lab[N]:=Copy(S,1,Min(P-1,60)); S:=Copy(S,P+1,255) End;
  If N>=MaxItems Then Break;
 End;
 LW:=0; AW:=0;
 For I:=1 To N Do Begin
  P:=Pos('^',Lab[I]);
  If P>0 Then Begin Acc[I]:=Copy(Lab[I],P+1,16); Lab[I]:=Copy(Lab[I],1,P-1) End
  Else Acc[I]:='';
  If TextW(Lab[I])>LW Then LW:=TextW(Lab[I]);
  If TextW(Acc[I])>AW Then AW:=TextW(Acc[I]);
 End;
 RowH:=14;
 W:=18+LW+8+AW+10; If AW>0 Then Inc(W,12);
 If W<MinW Then W:=MinW;
 Vis:=N; If Vis>24 Then Vis:=24;
 H:=Vis*RowH+4;
 If X+W>=ScrW Then X:=ScrW-W-2;
 If Y+H>=ScrH Then Y:=ScrH-H-2;
 If Y<0 Then Y:=0;
 X2:=X+W-1; Y2:=Y+H-1;
 BG:=SaveBG(X,Y,X2+4,Y2+4);
 Top:=1; If Sel>Vis Then Top:=Sel-Vis+1;
 Hov:=Sel; Res:=0; Done:=False; PopSwitch:=0;
 HideMouse; Draw; ShowMouse;
 Repeat
  If PollEvent(E) Then Begin
   Case E.Kind Of
    evKey: Begin
     Case E.Key Of
      kEsc: Done:=True;
      kEnter: Begin If (Hov>=1) And (Hov<=N) And (Lab[Hov]<>'-') Then Res:=Hov; Done:=True; End;
      kDown: Begin
       Tmp:=Hov; Repeat Inc(Tmp) Until (Tmp>N) Or (Lab[Tmp]<>'-');
       If Tmp<=N Then Hov:=Tmp;
       If Hov>=Top+Vis Then Top:=Hov-Vis+1;
       HideMouse; Draw; ShowMouse;
      End;
      kUp: Begin
       Tmp:=Hov; Repeat Dec(Tmp) Until (Tmp<1) Or (Lab[Tmp]<>'-');
       If Tmp>=1 Then Hov:=Tmp;
       If Hov<Top Then Top:=Hov;
       HideMouse; Draw; ShowMouse;
      End;
     End;
    End;
    evUp: Begin
     PopX:=E.X; PopY:=E.Y;
     If (E.X>=X) And (E.X<=X2) And (E.Y>=Y) And (E.Y<=Y2) Then Begin
      If (E.Y<Y+8) And (Top>1) Then Begin Dec(Top); HideMouse; Draw; ShowMouse; End
      Else If (E.Y>Y2-8) And (Top+Vis<=N) Then Begin Inc(Top); HideMouse; Draw; ShowMouse; End
      Else Begin
       I:=Top+(E.Y-Y-2) Div RowH;
       If (I>=1) And (I<=N) And (Lab[I]<>'-') Then Begin Res:=I; Done:=True; End;
      End;
     End Else Done:=True;
    End;
   End;
  End Else Begin
   { survol }
   If (E.X>=X) And (E.X<=X2) And (E.Y>=Y+2) And (E.Y<=Y2) Then Begin
    I:=Top+(E.Y-Y-2) Div RowH;
    If (I>=1) And (I<=N) And (I<>Hov) And (Lab[I]<>'-') Then Begin
     Hov:=I; HideMouse; Draw; ShowMouse;
    End;
   End;
   If (PopMenuBarH>0) And (E.Y<PopMenuBarH) And (@BarHitProc<>Nil) Then Begin
    I:=BarHitProc(E.X);
    If (I>0) And (I<>PopCurMenu) Then Begin PopSwitch:=I; Done:=True; End;
   End;
   Delay(8);
  End;
 Until Done;
 HideMouse; RestBG(BG,X,Y,X2+4,Y2+4); ShowMouse;
 PopupMenu:=Res;
End;

{ ---------------------------------------------------------------------- }
{ Cadre de dialogue standard                                                }
{ ---------------------------------------------------------------------- }
Procedure DlgFrame(X1,Y1,X2,Y2: Integer; Const Title: String);
Begin
 Shadow(X1,Y1,X2,Y2);
 Panel(X1,Y1,X2,Y2,cPanel,cNavy);
 Rect(X1+1,Y1+1,X2-1,Y1+19,cBlue);
 Txt(X1+8,Y1+7,Title,cWhite);
 IcoClose(X2-15,Y1+6,cWhite);
End;

Function WrapLine(Var S: String; Max: Integer): String;
Var I: Integer;
Begin
 If Length(S)<=Max Then Begin WrapLine:=S; S:=''; Exit End;
 I:=Max;
 While (I>1) And (S[I]<>' ') Do Dec(I);
 If I<=1 Then I:=Max;
 WrapLine:=Copy(S,1,I); S:=Copy(S,I+1,255);
 While (S<>'') And (S[1]=' ') Do Delete(S,1,1);
End;

{ Boite de message : Msg avec '|' comme saut de ligne ; Btns 'OK' ou 'Oui|Non|Annuler' }
Function MsgBox(Const Title,Msg,Btns: String): Integer;
Var
 Lines: Array[1..14] Of String[70];
 NL,NB,I,W,H,X1,Y1,X2,Y2,BW,Res: Integer;
 S,L: String;
 Bt: Array[1..4] Of String[16];
 BG: Pointer;
 E: TEvent;
 Done: Boolean;
Begin
 NL:=0; S:=Msg;
 While (S<>'') And (NL<14) Do Begin
  I:=Pos('|',S);
  If I=0 Then Begin L:=S; S:='' End Else Begin L:=Copy(S,1,I-1); S:=Copy(S,I+1,255) End;
  Repeat
   Inc(NL); Lines[NL]:=WrapLine(L,52);
  Until (L='') Or (NL>=14);
 End;
 NB:=0; S:=Btns;
 While (S<>'') And (NB<4) Do Begin
  I:=Pos('|',S);
  If I=0 Then Begin Inc(NB); Bt[NB]:=S; S:='' End
  Else Begin Inc(NB); Bt[NB]:=Copy(S,1,I-1); S:=Copy(S,I+1,255) End;
 End;
 W:=440; H:=NL*12+78;
 X1:=(ScrW-W) Div 2; Y1:=(ScrH-H) Div 2; X2:=X1+W-1; Y2:=Y1+H-1;
 BG:=SaveBG(X1,Y1,X2+4,Y2+4);
 HideMouse;
 DlgFrame(X1,Y1,X2,Y2,Title);
 For I:=1 To NL Do Txt(X1+16,Y1+32+(I-1)*12,Lines[I],cBlack);
 HotClear;
 BW:=84;
 For I:=1 To NB Do Begin
  Button(X2-12-(NB-I+1)*(BW+8)+8,Y2-30,BW,22,Bt[I],100+I,Ord(I=1)*bsBlue);
 End;
 ShowMouse;
 Res:=0; Done:=False;
 Repeat
  WaitEvent(E);
  If E.Kind=evUp Then Begin
   I:=HotAt(E.X,E.Y);
   If (I>100) And (I<=100+NB) Then Begin Res:=I-100; Done:=True; End
   Else If (E.X>=X2-18) And (E.X<=X2-4) And (E.Y>=Y1+3) And (E.Y<=Y1+18) Then Begin Res:=0; Done:=True; End;
  End Else If E.Kind=evKey Then Begin
   If E.Key=kEnter Then Begin Res:=1; Done:=True; End;
   If E.Key=kEsc Then Begin Res:=0; Done:=True; End;
   If (NB=2) And ((UpCase(Chr(E.Key And 255))='N')) Then Begin Res:=2; Done:=True; End;
   If (NB>=2) And ((UpCase(Chr(E.Key And 255))='O')) Then Begin Res:=1; Done:=True; End;
  End;
 Until Done;
 HideMouse; RestBG(BG,X1,Y1,X2+4,Y2+4); ShowMouse;
 MsgBox:=Res;
End;

Procedure Info(Const Msg: String);
Var R: Integer;
Begin
 R:=MsgBox('AnyMP4',Msg,'OK');
End;

{ Saisie d'une chaine. Retourne True si valide. }
Function InputBox(Const Title,Prompt: String; Var S: String; MaxLen: Integer): Boolean;
Var
 W,H,X1,Y1,X2,Y2,Cur,I,FX,FW,Off,VisC: Integer;
 BG: Pointer;
 E: TEvent;
 Done,Ok,Fresh,Blink: Boolean;
 T: String;
 C: Char;
 Tm: LongInt;

 Procedure DrawField;
 Var Shown: String; CX: Integer;
 Begin
  If Cur<Off Then Off:=Cur;
  If Cur-Off>VisC Then Off:=Cur-VisC;
  Shown:=Copy(T,Off+1,VisC+1);
  Panel(FX,Y1+52,FX+FW-1,Y1+68,cWhite,cBlue);
  If Fresh And (T<>'') Then Rect(FX+3,Y1+55,FX+3+TextW(Shown)-1,Y1+65,cSky);
  Txt(FX+4,Y1+57,Shown,cBlack);
  CX:=FX+4+TextW(Copy(T,Off+1,Cur-Off));
  If Blink Then VLn(CX,Y1+55,Y1+65,cBlack);
 End;

Begin
 W:=420; H:=118;
 X1:=(ScrW-W) Div 2; Y1:=(ScrH-H) Div 2; X2:=X1+W-1; Y2:=Y1+H-1;
 BG:=SaveBG(X1,Y1,X2+4,Y2+4);
 FX:=X1+14; FW:=W-28; VisC:=(FW-8) Div 8-1; Off:=0;
 T:=S; Cur:=Length(T); Fresh:=True; Blink:=True; Done:=False; Ok:=False; Tm:=Ticks;
 HideMouse;
 DlgFrame(X1,Y1,X2,Y2,Title);
 Txt(X1+14,Y1+32,Fit(Prompt,W-28),cBlack);
 HotClear;
 Button(X2-190,Y2-30,84,22,'OK',101,bsBlue);
 Button(X2-98,Y2-30,84,22,'Annuler',102,bsNormal);
 DrawField;
 ShowMouse;
 Repeat
  If PollEvent(E) Then Begin
   If E.Kind=evUp Then Begin
    I:=HotAt(E.X,E.Y);
    If I=101 Then Begin Ok:=True; Done:=True; End
    Else If I=102 Then Done:=True
    Else If (E.X>=X2-18) And (E.Y<=Y1+18) And (E.Y>=Y1+3) Then Done:=True;
   End Else If E.Kind=evKey Then Begin
    Case E.Key Of
     kEnter: Begin Ok:=True; Done:=True; End;
     kEsc: Done:=True;
     kBack: Begin
      If Fresh Then Begin T:=''; Cur:=0; End
      Else If Cur>0 Then Begin Delete(T,Cur,1); Dec(Cur); End;
      Fresh:=False;
     End;
     kDel: Begin If Fresh Then Begin T:=''; Cur:=0 End Else If Cur<Length(T) Then Delete(T,Cur+1,1); Fresh:=False; End;
     kLeft: Begin If Cur>0 Then Dec(Cur); Fresh:=False; End;
     kRight: Begin If Cur<Length(T) Then Inc(Cur); Fresh:=False; End;
     kHome: Begin Cur:=0; Fresh:=False; End;
     kEnd: Begin Cur:=Length(T); Fresh:=False; End;
     32..126,128..255: Begin
      If Fresh Then Begin T:=''; Cur:=0; End;
      Fresh:=False;
      If Length(T)<MaxLen Then Begin Insert(Chr(E.Key),T,Cur+1); Inc(Cur); End;
     End;
    End;
    Blink:=True; Tm:=Ticks;
    HideMouse; DrawField; ShowMouse;
   End;
  End Else Begin
   If Ticks-Tm>40 Then Begin
    Blink:=Not Blink; Tm:=Ticks; HideMouse; DrawField; ShowMouse;
   End;
   Delay(8);
  End;
 Until Done;
 HideMouse; RestBG(BG,X1,Y1,X2+4,Y2+4); ShowMouse;
 If Ok Then S:=T;
 InputBox:=Ok;
End;

Function InputNum(Const Title,Prompt: String; Var V: LongInt; Lo,Hi: LongInt): Boolean;
Var S: String;
Begin
 S:=IStr(V);
 InputNum:=False;
 If InputBox(Title,Prompt,S,10) Then Begin
  V:=Clip(ValL(S),Lo,Hi); InputNum:=True;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Type de media selon l'extension                                           }
{ ---------------------------------------------------------------------- }
Function InList(Const E,L: String): Boolean;
Begin
 InList:=Pos(','+E+',',','+L+',')>0;
End;

Function MediaKind(Const E: String): Integer;
Begin
 MediaKind:=0;
 If E='' Then Exit;
 If InList(E,'AVI,MP4,MKV,MOV,WMV,FLV,WEBM,MPG,MPEG,VOB,TS,M2TS,MTS,3GP,3G2,M4V,ASF,OGV,F4V,MXF,DAT,RM,RMVB,DIVX,VIDEO') Then MediaKind:=2
 Else If InList(E,'MP3,WAV,AIF,AIFF,AIFC,VOC,MOD,AAC,M4A,FLAC,OGG,OGA,WMA,AU,AC3,MP2,MPA,MKA,OPUS,AMR,WV,M4B,RA,CAF') Then MediaKind:=1
 Else If InList(E,'GIF,BMP,PNG,JPG,JPEG,PCX,TGA,TIF,TIFF,WEBP') Then MediaKind:=3;
End;

{ ---------------------------------------------------------------------- }
{ Selecteur de fichiers                                                     }
{ ---------------------------------------------------------------------- }
Type
 TDirEnt = Record
  Name: String[64];
  Size: LongInt;
  IsDir: Boolean;
  Mark: Boolean;
 End;
 PDirEnt = ^TDirEnt;
 TDirList = Array[1..300] Of PDirEnt;

Var
 PickList: Array[1..MaxFiles] Of String[200];
 PickN: Integer;

Const
 FilterNames = 'Tous les m'#233'dias|Vid'#233'o|Audio|Images|Tous les fichiers';

Function FileDlg(Const Title: String; Multi,FolderMode: Boolean; FilterIdx: Integer): Boolean;
Const Rows = 13;
Var
 L: TDirList; N,I,J,Top,Cur,X1,Y1,X2,Y2,Filt,Id,Cnt: Integer;
 Dir,Tmp: String;
 SR: SearchRec;
 E: TEvent;
 Done,Ok: Boolean;
 BG: Pointer;
 K: Integer;
 Q: PDirEnt;

 Function Keep(Const Nm: String): Boolean;
 Var Ex: String; Kd: Integer;
 Begin
  Ex:=ExtOf(Nm); Kd:=MediaKind(Ex);
  Case Filt Of
   1: Keep:=Kd<>0; 2: Keep:=Kd=2; 3: Keep:=Kd=1; 4: Keep:=Kd=3; Else Keep:=True;
  End;
 End;

 Procedure Clear;
 Var K: Integer;
 Begin
  For K:=1 To N Do Dispose(L[K]);
  N:=0;
 End;

 Procedure Scan;
 Var A: PDirEnt; I,J: Integer; Q: PDirEnt;
 Begin
  Clear; Top:=1; Cur:=1;
  New(A); A^.Name:='..'; A^.Size:=0; A^.IsDir:=True; A^.Mark:=False; Inc(N); L[N]:=A;
  FindFirst(AddSlash(Dir)+'*',AnyFile,SR);
  While (DosError=0) And (N<300) Do Begin
   If (SR.Name<>'.') And (SR.Name<>'..') And ((Copy(SR.Name,1,1)<>'.') Or True) Then Begin
    If (SR.Attr And Directory)<>0 Then Begin
     If Copy(SR.Name,1,1)<>'.' Then Begin
      New(A); A^.Name:=Copy(SR.Name,1,64); A^.Size:=0; A^.IsDir:=True; A^.Mark:=False; Inc(N); L[N]:=A;
     End;
    End Else If (Not FolderMode) And Keep(SR.Name) Then Begin
     New(A); A^.Name:=Copy(SR.Name,1,64); A^.Size:=SR.Size; A^.IsDir:=False; A^.Mark:=False; Inc(N); L[N]:=A;
    End;
   End;
   FindNext(SR);
  End;
  { tri : dossiers d'abord, puis noms }
  For I:=2 To N Do Begin
   Q:=L[I]; J:=I-1;
   While (J>=2) And ((Ord(L[J]^.IsDir)<Ord(Q^.IsDir)) Or
     ((L[J]^.IsDir=Q^.IsDir) And (UpStr(L[J]^.Name)>UpStr(Q^.Name)))) Do Begin
    L[J+1]:=L[J]; Dec(J);
   End;
   L[J+1]:=Q;
  End;
 End;

 Procedure Draw;
 Var R,Idx,YY,Z: Integer; S: String;
 Begin
  HotClear;
  DlgFrame(X1,Y1,X2,Y2,Title);
  Txt(X1+12,Y1+30,'Dossier :',cBlack);
  Panel(X1+80,Y1+26,X2-134,Y1+42,cWhite,cSteel);
  Txt(X1+84,Y1+30,Fit(Dir,X2-X1-224),cBlack);
  HotAdd(X1+80,Y1+26,X2-X1-214,17,200);
  Button(X2-128,Y1+26,48,17,'Haut',201,bsNormal);
  Button(X2-76,Y1+26,64,17,'Racine',202,bsNormal);
  Txt(X1+12,Y1+52,'Type :',cBlack);
  If FolderMode Then Txt(X1+80,Y1+52,'Dossiers',cGrayD)
  Else Begin
   Case Filt Of
    0: S:='Tous les m'#233'dias'; 1: S:='Vid'#233'o'; 2: S:='Audio'; 3: S:='Images'; Else S:='Tous les fichiers';
   End;
   Combo(X1+80,Y1+48,200,17,S,203);
  End;
  Panel(X1+12,Y1+72,X2-30,Y1+72+Rows*14+3,cWhite,cSteel);
  For R:=0 To Rows-1 Do Begin
   Idx:=Top+R;
   If Idx>N Then Break;
   YY:=Y1+74+R*14;
   If L[Idx]^.Mark Then Begin Rect(X1+13,YY,X2-31,YY+13,cSky); End;
   If Idx=Cur Then Frame(X1+13,YY,X2-31,YY+13,cBlue);
   If L[Idx]^.IsDir Then Begin
    IcoFolder(X1+16,YY,cGold);
    Txt(X1+34,YY+3,Fit(L[Idx]^.Name,X2-X1-130),cNavy);
   End Else Begin
    Txt(X1+34,YY+3,Fit(L[Idx]^.Name,X2-X1-200),cBlack);
    TxtR(X2-36,YY+3,SizeStr(L[Idx]^.Size),cGrayD);
   End;
   HotAdd(X1+13,YY,X2-X1-44,14,1000+Idx);
  End;
  { ascenseur }
  Panel(X2-28,Y1+72,X2-12,Y1+72+Rows*14+3,cLine,cSteel);
  Tri(X2-20,Y1+80,1,cNavy); Tri(X2-20,Y1+72+Rows*14-4,0,cNavy);
  HotAdd(X2-28,Y1+72,16,20,210); HotAdd(X2-28,Y1+72+Rows*14-16,16,20,211);
  If N>Rows Then Begin
   YY:=Y1+92+((Top-1)*(Rows*14-40)) Div (N-Rows+1);
   Rect(X2-27,YY,X2-13,YY+8,cBlue);
  End;
  { pied }
  Cnt:=0; For Z:=1 To N Do If L[Z]^.Mark Then Inc(Cnt);
  If FolderMode Then S:='Dossier courant'
  Else If Cnt>0 Then S:=IStr(Cnt)+' fichier(s) s'#233'lectionn'#233'(s)'
  Else S:='Cliquez pour s'#233'lectionner'+Copy(' (clic = multiple)',1,Ord(Multi)*18);
  Txt(X1+12,Y2-24,Fit(S,X2-X1-230),cGrayD);
  If FolderMode Then Button(X2-200,Y2-30,110,22,'Choisir',220,bsBlue)
  Else Button(X2-200,Y2-30,90,22,'Ouvrir',220,bsBlue);
  Button(X2-98,Y2-30,84,22,'Annuler',221,bsNormal);
 End;

 Procedure GoDir(Const D: String);
 Var T: String;
 Begin
  T:=D;
  {$I-} ChDir(T); {$I+}
  If IOResult<>0 Then Exit;
  GetDir(0,Dir); Scan;
 End;

 Procedure Activate(Idx: Integer);
 Begin
  If (Idx<1) Or (Idx>N) Then Exit;
  If L[Idx]^.IsDir Then Begin
   If L[Idx]^.Name='..' Then GoDir(AddSlash(Dir)+'..') Else GoDir(AddSlash(Dir)+L[Idx]^.Name);
  End;
 End;

Begin
 N:=0; Filt:=FilterIdx; Ok:=False; Done:=False;
 X1:=60; Y1:=40; X2:=ScrW-60; Y2:=ScrH-40;
 GetDir(0,Tmp);
 If LastDir<>'' Then Begin {$I-} ChDir(LastDir); {$I+} If IOResult<>0 Then ChDir(Tmp); End;
 GetDir(0,Dir);
 Scan;
 HideMouse; Draw; ShowMouse;
 Repeat
  WaitEvent(E);
  If E.Kind=evUp Then Begin
   Id:=HotAt(E.X,E.Y);
   If (E.X>=X2-18) And (E.Y<=Y1+18) And (E.Y>=Y1+3) And (E.X<=X2-3) Then Done:=True
   Else If Id>=1000 Then Begin
    I:=Id-1000;
    If DblClick And (I=Cur) Then Begin
     If L[I]^.IsDir Then Activate(I)
     Else Begin
      For K:=1 To N Do L[K]^.Mark:=False;
      L[I]^.Mark:=True; Ok:=True; Done:=True;
     End;
    End Else Begin
     Cur:=I;
     If Not L[I]^.IsDir Then Begin
      If Multi Then L[I]^.Mark:=Not L[I]^.Mark
      Else Begin For K:=1 To N Do L[K]^.Mark:=False; L[I]^.Mark:=True; End;
     End;
    End;
    HideMouse; Draw; ShowMouse;
   End Else Case Id Of
    200: Begin
     Tmp:=Dir;
     If InputBox('Dossier','Chemin du dossier :',Tmp,200) Then GoDir(Tmp);
     HideMouse; Draw; ShowMouse;
    End;
    201: Begin GoDir(AddSlash(Dir)+'..'); HideMouse; Draw; ShowMouse; End;
    202: Begin
     {$IFDEF UNIX} GoDir('/'); {$ELSE} GoDir(Copy(Dir,1,3)); {$ENDIF}
     HideMouse; Draw; ShowMouse;
    End;
    203: Begin
     I:=PopupMenu(X1+80,Y1+65,FilterNames,Filt+1,200);
     If I>0 Then Begin Filt:=I-1; Scan; End;
     HideMouse; Draw; ShowMouse;
    End;
    210: Begin If Top>1 Then Dec(Top,3); If Top<1 Then Top:=1; HideMouse; Draw; ShowMouse; End;
    211: Begin If Top+Rows<=N Then Inc(Top,3); HideMouse; Draw; ShowMouse; End;
    220: Begin
     If FolderMode Then Begin Ok:=True; Done:=True; End
     Else Begin
      Cnt:=0; For I:=1 To N Do If L[I]^.Mark Then Inc(Cnt);
      If Cnt=0 Then Begin
       If (Cur>=1) And (Cur<=N) And (Not L[Cur]^.IsDir) Then L[Cur]^.Mark:=True
       Else If (Cur>=1) And (Cur<=N) Then Activate(Cur);
      End;
      Cnt:=0; For I:=1 To N Do If L[I]^.Mark Then Inc(Cnt);
      If Cnt>0 Then Begin Ok:=True; Done:=True; End Else Begin HideMouse; Draw; ShowMouse; End;
     End;
    End;
    221: Done:=True;
   End;
  End Else If E.Kind=evKey Then Begin
   Case E.Key Of
    kEsc: Done:=True;
    kDown: Begin If Cur<N Then Inc(Cur); If Cur>=Top+Rows Then Top:=Cur-Rows+1; HideMouse; Draw; ShowMouse; End;
    kUp: Begin If Cur>1 Then Dec(Cur); If Cur<Top Then Top:=Cur; HideMouse; Draw; ShowMouse; End;
    kPgDn: Begin Cur:=Min(N,Cur+Rows); If Cur>=Top+Rows Then Top:=Cur-Rows+1; HideMouse; Draw; ShowMouse; End;
    kPgUp: Begin Cur:=Max(1,Cur-Rows); If Cur<Top Then Top:=Cur; HideMouse; Draw; ShowMouse; End;
    kEnter: Begin
     If (Cur>=1) And (Cur<=N) Then Begin
      If L[Cur]^.IsDir Then Begin Activate(Cur); HideMouse; Draw; ShowMouse; End
      Else Begin
       Cnt:=0; For I:=1 To N Do If L[I]^.Mark Then Inc(Cnt);
       If Cnt=0 Then L[Cur]^.Mark:=True;
       Ok:=True; Done:=True;
      End;
     End;
    End;
    32: Begin
     If (Cur>=1) And (Cur<=N) And (Not L[Cur]^.IsDir) Then Begin
      If Multi Then L[Cur]^.Mark:=Not L[Cur]^.Mark
      Else Begin For K:=1 To N Do L[K]^.Mark:=False; L[Cur]^.Mark:=True; End;
      HideMouse; Draw; ShowMouse;
     End;
    End;
   End;
  End;
 Until Done;
 PickN:=0;
 If Ok Then Begin
  LastDir:=Dir;
  If FolderMode Then Begin PickN:=1; PickList[1]:=Dir; End
  Else For I:=1 To N Do
   If L[I]^.Mark And (PickN<MaxFiles) Then Begin
    Inc(PickN); PickList[PickN]:=AddSlash(Dir)+L[I]^.Name;
   End;
 End;
 Clear;
 {$I-} ChDir(Tmp); {$I+} If IOResult<>0 Then ;
 Refresh;
 FileDlg:=Ok And (PickN>0);
End;

{ ====================================================================== }
{ Modele de donnees : fichiers medias et profils de sortie                 }
{ ====================================================================== }
Type
 TMedia = Record
  Path: String[200];
  Kind: Byte;                 { 1 audio, 2 video, 3 image }
  Fmt: String[8];
  VCodec,ACodec: String[14];
  W,H: Integer;
  FpsX100: Integer;
  DurMs: LongInt;
  Size: LongInt;
  Rate: LongInt;
  Chans: Integer;
  Bits: Integer;
  KBps: Integer;
  Frames: Integer;
  Title: String[60];
  { parametres d'edition }
  Rot: Integer;               { 0..3 quarts de tour }
  FlipH,FlipV: Boolean;
  CropX,CropY,CropW,CropH: Integer;
  Aspect: Integer;            { 0 personnalise, 1 original, 2 16:9, 3 4:3, 4 1:1 }
  ZoomMode: Integer;
  Bright,Contr,Satur,Hue: Integer;
  Deint: Boolean;
  WmOn: Boolean;
  WmText: String[40];
  WmPos: Integer;             { 0..8 }
  WmSize: Integer;            { 1..4 }
  WmAlpha: Integer;           { 0..100 }
  Vol: Integer;               { 0..200 }
  ADelay: Integer;            { ms }
  SubFile: String[200];
  SubPos: Integer;
  TrimS,TrimE: LongInt;       { ms, TrimE=0 : jusqu'a la fin }
  Status: Byte;               { 0 attente, 1 en cours, 2 termine, 3 erreur }
  Pct: Integer;
  Msg: String[90];
  OutFile: String[200];
  Sel: Boolean;
 End;
 PMedia = ^TMedia;

 TProf = Record
  Cat: Byte;                  { 0 video, 1 audio, 2 appareil, 3 image }
  Name: String[30];
  Ext: String[4];
  VC,AC: String[10];
  Res: String[10];
  VKb,AKb: Integer;
  Rate: LongInt;
  Ch: Integer;
 End;

Var
 Files: Array[1..MaxFiles+1] Of PMedia;
 NFiles: Integer;
 Profs: Array[1..MaxProf] Of TProf;
 NProf: Integer;
 CurProf: Integer;
 OutDir: String;
 MergeAll: Boolean;
 Fast120: Boolean;
 HwAccel: Boolean;
 AfterAct: Integer;           { 0 rien, 1 ouvrir dossier, 2 quitter }
 OverwriteAll: Boolean;
 Tab: Integer;                { onglet principal 0..4 }
 SubTab: Integer;             { 0 Conversion, 1 Converti }
 ListTop: Integer;
 CustVKb,CustAKb: Integer;
 CustRate: LongInt;
 CustCh: Integer;
 CustFps: Integer;
 Converted: Array[1..64] Of String[200];
 NConv: Integer;
 TmpDir: String;
 Stopped: Boolean;

Procedure AddProf(pCat: Byte; Const pName,pExt,pVC,pAC,pRes: String; pVKb,pAKb: Integer; pRate: LongInt; pCh: Integer);
Begin
 If NProf>=MaxProf Then Exit;
 Inc(NProf);
 Profs[NProf].Cat:=pCat; Profs[NProf].Name:=pName; Profs[NProf].Ext:=pExt;
 Profs[NProf].VC:=pVC; Profs[NProf].AC:=pAC; Profs[NProf].Res:=pRes;
 Profs[NProf].VKb:=pVKb; Profs[NProf].AKb:=pAKb; Profs[NProf].Rate:=pRate; Profs[NProf].Ch:=pCh;
End;

Procedure InitProfiles;
Begin
 NProf:=0;
 AddProf(0,'MP4 H.264/HEVC','MP4','H264','AAC','Auto',5000,192,44100,2);
 AddProf(0,'MP4 4K','MP4','H264','AAC','3840x2160',20000,256,48000,2);
 AddProf(0,'MP4 HD 1080P','MP4','H264','AAC','1920x1080',8000,192,44100,2);
 AddProf(0,'MP4 HD 720P','MP4','H264','AAC','1280x720',4000,192,44100,2);
 AddProf(0,'MP4 SD 480P','MP4','H264','AAC','854x480',1500,128,44100,2);
 AddProf(0,'MOV QuickTime','MOV','H264','AAC','Auto',5000,192,44100,2);
 AddProf(0,'MKV','MKV','H264','AAC','Auto',5000,192,44100,2);
 AddProf(0,'AVI','AVI','MPEG4','MP3','Auto',3000,192,44100,2);
 AddProf(0,'WMV','WMV','WMV2','WMA','Auto',2500,128,44100,2);
 AddProf(0,'WebM VP9','WEBM','VP9','Opus','Auto',3000,128,48000,2);
 AddProf(0,'FLV','FLV','H264','MP3','Auto',2000,128,44100,2);
 AddProf(0,'MPEG-2 PS','MPG','MPEG2','MP2','Auto',6000,192,48000,2);
 AddProf(0,'3GP','3GP','H263','AAC','352x288',512,64,22050,1);
 AddProf(0,'DVD (NTSC)','VOB','MPEG2','AC3','720x480',6000,192,48000,2);
 AddProf(0,'OGV Theora','OGV','Theora','Vorbis','Auto',2000,128,44100,2);
 AddProf(0,'GIF anim'+#233,'GIF','GIF','-','Auto',0,0,0,0);
 AddProf(1,'MP3 320 kbps','MP3','-','MP3','-',0,320,44100,2);
 AddProf(1,'MP3 192 kbps','MP3','-','MP3','-',0,192,44100,2);
 AddProf(1,'MP3 128 kbps','MP3','-','MP3','-',0,128,44100,2);
 AddProf(1,'MP3 64 kbps mono','MP3','-','MP3','-',0,64,22050,1);
 AddProf(1,'WAV PCM 16 bits','WAV','-','PCM16','-',0,1411,44100,2);
 AddProf(1,'WAV PCM 8 bits mono','WAV','-','PCM8','-',0,352,22050,1);
 AddProf(1,'WAV IMA ADPCM','WAV','-','ADPCM','-',0,352,44100,2);
 AddProf(1,'AIFF','AIF','-','PCM16','-',0,1411,44100,2);
 AddProf(1,'AU (Sun/NeXT)','AU','-','PCM16','-',0,1411,44100,2);
 AddProf(1,'FLAC','FLAC','-','FLAC','-',0,0,44100,2);
 AddProf(1,'AAC','AAC','-','AAC','-',0,256,44100,2);
 AddProf(1,'M4A','M4A','-','AAC','-',0,256,44100,2);
 AddProf(1,'OGG Vorbis','OGG','-','Vorbis','-',0,160,44100,2);
 AddProf(1,'WMA','WMA','-','WMA','-',0,128,44100,2);
 AddProf(2,'iPhone / iPad','MP4','H264','AAC','1920x1080',6000,160,44100,2);
 AddProf(2,'Android','MP4','H264','AAC','1280x720',3000,128,44100,2);
 AddProf(2,'Samsung Galaxy','MP4','H264','AAC','1920x1080',6000,160,44100,2);
 AddProf(2,'Apple TV','M4V','H264','AAC','1920x1080',8000,160,48000,2);
 AddProf(2,'PlayStation 5','MP4','H264','AAC','3840x2160',20000,256,48000,2);
 AddProf(2,'Xbox Series X','MP4','H264','AAC','3840x2160',20000,256,48000,2);
 AddProf(2,'Smart TV','MP4','H264','AAC','1920x1080',8000,192,44100,2);
 AddProf(2,'YouTube','MP4','H264','AAC','1920x1080',8000,192,44100,2);
 AddProf(2,'Facebook','MP4','H264','AAC','1280x720',4000,128,44100,2);
 AddProf(2,'Instagram','MP4','H264','AAC','1080x1080',5000,128,44100,2);
 AddProf(2,'TikTok','MP4','H264','AAC','1080x1920',5000,128,44100,2);
 AddProf(3,'Image GIF','GIF','GIF','-','Auto',0,0,0,0);
 AddProf(3,'Image BMP','BMP','BMP','-','Auto',0,0,0,0);
 CurProf:=1;
End;

Function ProfLabel(I: Integer): String;
Begin
 If (I<1) Or (I>NProf) Then Begin ProfLabel:='?'; Exit End;
 ProfLabel:=Profs[I].Name;
End;

{ Le moteur integre sait produire ces sorties }
Function EngineOut(Const Ext: String): Boolean;
Begin
 EngineOut:=InList(Ext,'MP3,WAV,AIF,AU,GIF,BMP,MP4,MOV,M4V,3GP,M4A,AAC');
End;

{ ====================================================================== }
{ Lecture bufferisee de fichiers pour l'analyse                           }
{ ====================================================================== }
Var
 CF: File;
 COpened: Boolean;
 CSize: LongInt;
 CBuf: Array[0..4095] Of Byte;
 COfs,CLen: LongInt;

Function COpen(Const Name: String): Boolean;
Var Old: Byte;
Begin
 COpen:=False; COpened:=False; COfs:=-1; CLen:=0;
 Assign(CF,Name); Old:=FileMode; FileMode:=0;
 {$I-}Reset(CF,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Exit;
 CSize:=FileSize(CF); COpened:=True; COpen:=True;
End;

Procedure CClose;
Begin
 If COpened Then Begin Close(CF); COpened:=False; End;
End;

Function CB(P: LongInt): Byte;
Var N: Word;
Begin
 CB:=0;
 If (P<0) Or (P>=CSize) Then Exit;
 If (COfs<0) Or (P<COfs) Or (P>=COfs+CLen) Then Begin
  COfs:=P-(P And 4095)+0;
  {$I-}Seek(CF,COfs); BlockRead(CF,CBuf,4096,N);{$I+}
  If IOResult<>0 Then N:=0;
  CLen:=N;
  If (P<COfs) Or (P>=COfs+CLen) Then Exit;
 End;
 CB:=CBuf[P-COfs];
End;

Function L16(P: LongInt): LongInt;
Begin
 L16:=CB(P)+LongInt(CB(P+1))*256;
End;

Function L32(P: LongInt): LongInt;
Begin
 L32:=CB(P)+LongInt(CB(P+1))*256+LongInt(CB(P+2))*65536+LongInt(CB(P+3))*16777216;
End;

Function B16(P: LongInt): LongInt;
Begin
 B16:=CB(P)*256+LongInt(CB(P+1));
End;

Function B32(P: LongInt): LongInt;
Begin
 B32:=LongInt(CB(P))*16777216+LongInt(CB(P+1))*65536+LongInt(CB(P+2))*256+CB(P+3);
End;

Function C4(P: LongInt): String;
Begin
 C4:=Chr(CB(P))+Chr(CB(P+1))+Chr(CB(P+2))+Chr(CB(P+3));
End;

Function CStr(P: LongInt; N: Integer): String;
Var S: String; I: Integer; C: Byte;
Begin
 S:='';
 For I:=0 To N-1 Do Begin
  C:=CB(P+I);
  If C=0 Then Break;
  If Length(S)<250 Then S:=S+Chr(C);
 End;
 CStr:=S;
End;

Function BEN(P: LongInt; N: Integer): LongInt;
Var I: Integer; V: LongInt;
Begin
 V:=0;
 For I:=0 To N-1 Do V:=V*256+CB(P+I);
 BEN:=V;
End;

Function BEDouble(P: LongInt; Len: Integer): Double;
Var I: Integer; Q: Array[0..7] Of Byte; S: Single; D: Double;
Begin
 BEDouble:=0;
 If Len=4 Then Begin
  For I:=0 To 3 Do Q[3-I]:=CB(P+I);
  Move(Q,S,4); BEDouble:=S;
 End Else If Len=8 Then Begin
  For I:=0 To 7 Do Q[7-I]:=CB(P+I);
  Move(Q,D,8); BEDouble:=D;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Analyse des fichiers                                                      }
{ ---------------------------------------------------------------------- }
Procedure ResetEdit(Var M: TMedia);
Begin
 M.Rot:=0; M.FlipH:=False; M.FlipV:=False;
 M.CropX:=0; M.CropY:=0; M.CropW:=0; M.CropH:=0; M.Aspect:=0; M.ZoomMode:=0;
 M.Bright:=0; M.Contr:=0; M.Satur:=0; M.Hue:=0; M.Deint:=False;
 M.WmOn:=False; M.WmText:=''; M.WmPos:=8; M.WmSize:=2; M.WmAlpha:=70;
 M.Vol:=100; M.ADelay:=0; M.SubFile:=''; M.SubPos:=0; M.TrimS:=0; M.TrimE:=0;
End;

Function FourCCName(Const S: String): String;
Var U: String;
Begin
 U:=UpStr(S);
 If (U='MP4V') Or (U='XVID') Or (U='DIVX') Or (U='DX50') Or (U='FMP4') Or (U='MP4S') Then FourCCName:='MPEG-4'
 Else If (U='AVC1') Or (U='H264') Or (U='X264') Or (U='AVC3') Then FourCCName:='H.264'
 Else If (U='HEV1') Or (U='HVC1') Or (U='H265') Then FourCCName:='HEVC'
 Else If (U='MJPG') Or (U='JPEG') Then FourCCName:='MJPEG'
 Else If (U='WMV1') Or (U='WMV2') Or (U='WMV3') Then FourCCName:='WMV'
 Else If (U='MP42') Or (U='MP43') Or (U='MPG4') Then FourCCName:='MSMPEG4'
 Else If (U='VP80') Then FourCCName:='VP8'
 Else If (U='VP90') Then FourCCName:='VP9'
 Else If (U='AV01') Then FourCCName:='AV1'
 Else If (U='CVID') Then FourCCName:='Cinepak'
 Else If (U='IV50') Or (U='IV41') Or (U='IV32') Then FourCCName:='Indeo'
 Else If (U='YUY2') Or (U='UYVY') Or (U='I420') Or (U='YV12') Then FourCCName:='YUV brut'
 Else FourCCName:=S;
End;

Function WavTagName(T: LongInt): String;
Begin
 Case T Of
  1: WavTagName:='PCM'; 2: WavTagName:='MS ADPCM'; 3: WavTagName:='PCM float';
  6: WavTagName:='A-law'; 7: WavTagName:='mu-law'; $11: WavTagName:='IMA ADPCM';
  $50: WavTagName:='MP2'; $55: WavTagName:='MP3'; $160,$161,$162,$163: WavTagName:='WMA';
  $2000: WavTagName:='AC3'; $FF,$706D: WavTagName:='AAC'; $FFFE: WavTagName:='PCM';
  Else WavTagName:='0x'+IStr(T);
 End;
End;

Procedure ProbeMP3(Var M: TMedia; P0: LongInt);
Const
 BR1: Array[1..3,0..15] Of Integer = (
  (0,32,64,96,128,160,192,224,256,288,320,352,384,416,448,0),
  (0,32,48,56,64,80,96,112,128,160,192,224,256,320,384,0),
  (0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0));
 BR2: Array[1..3,0..15] Of Integer = (
  (0,32,48,56,64,80,96,112,128,144,160,176,192,224,256,0),
  (0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0),
  (0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0));
 SR1: Array[0..2] Of LongInt = (44100,48000,32000);
Var
 P,Lim: LongInt; H,Ver,Lay,Bi,Si: LongInt; Br,Spf,Fr,X: LongInt; Rate: LongInt; Mono: Boolean;
Begin
 P:=P0; Lim:=P0+65536; If Lim>CSize-4 Then Lim:=CSize-4;
 While P<Lim Do Begin
  If (CB(P)=$FF) And ((CB(P+1) And $E0)=$E0) Then Begin
   H:=B32(P); Ver:=(H Shr 19) And 3; Lay:=4-((H Shr 17) And 3); Bi:=(H Shr 12) And 15; Si:=(H Shr 10) And 3;
   If (Ver<>1) And (Lay<4) And (Bi<>0) And (Bi<>15) And (Si<3) Then Begin
    If Ver=3 Then Br:=BR1[Lay,Bi] Else Br:=BR2[Lay,Bi];
    Rate:=SR1[Si]; If Ver=2 Then Rate:=Rate Div 2 Else If Ver=0 Then Rate:=Rate Div 4;
    Mono:=((H Shr 6) And 3)=3;
    M.Rate:=Rate; If Mono Then M.Chans:=1 Else M.Chans:=2; M.KBps:=Br;
    If Lay=1 Then Spf:=384 Else If (Lay=3) And (Ver<>3) Then Spf:=576 Else Spf:=1152;
    M.ACodec:='MP'+IStr(Lay);
    { Xing / Info / VBRI }
    If Ver=3 Then Begin If Mono Then X:=P+4+17 Else X:=P+4+32; End
    Else Begin If Mono Then X:=P+4+9 Else X:=P+4+17; End;
    If ((C4(X)='Xing') Or (C4(X)='Info')) And ((CB(X+7) And 1)<>0) Then Begin
     Fr:=B32(X+8); M.DurMs:=(Fr*Spf*1000) Div Rate; If M.DurMs>0 Then M.KBps:=((CSize-P)*8) Div M.DurMs;
    End Else If C4(P+36)='VBRI' Then Begin
     Fr:=B32(P+36+14); M.DurMs:=(Fr*Spf*1000) Div Rate;
    End Else If Br>0 Then M.DurMs:=((CSize-P)*8) Div Br;
    Exit;
   End;
  End;
  Inc(P);
 End;
End;

Procedure ProbeID3(Var M: TMedia; Var Start: LongInt);
Var Sz: LongInt; P,E,Len: LongInt; Id: String;
Begin
 Start:=0;
 If C4(0)<>'ID3'+#3 Then Begin
  If Copy(C4(0),1,3)<>'ID3' Then Exit;
 End;
 Sz:=(LongInt(CB(6) And $7F) Shl 21) Or (LongInt(CB(7) And $7F) Shl 14) Or (LongInt(CB(8) And $7F) Shl 7) Or (CB(9) And $7F);
 Start:=Sz+10;
 If CB(3)<3 Then Exit;
 P:=10; E:=10+Sz;
 While P+10<E Do Begin
  Id:=C4(P);
  If CB(P)=0 Then Break;
  If CB(3)=4 Then Len:=(LongInt(CB(P+4) And $7F) Shl 21) Or (LongInt(CB(P+5) And $7F) Shl 14) Or (LongInt(CB(P+6) And $7F) Shl 7) Or (CB(P+7) And $7F)
  Else Len:=B32(P+4);
  If (Len<=0) Or (Len>2000) Then Break;
  If (Id='TIT2') And (CB(P+10)=0) Then M.Title:=CStr(P+11,Min(Len-1,59));
  P:=P+10+Len;
 End;
End;

Procedure ProbeWAV(Var M: TMedia);
Var P,Sz,DataSz: LongInt; Id: String; Br: LongInt;
Begin
 P:=12; DataSz:=0; Br:=0;
 While P+8<=CSize Do Begin
  Id:=C4(P); Sz:=L32(P+4);
  If Id='fmt ' Then Begin
   M.ACodec:=WavTagName(L16(P+8)); M.Chans:=L16(P+10); M.Rate:=L32(P+12); Br:=L32(P+16); M.Bits:=L16(P+22);
   M.KBps:=(Br*8) Div 1000;
  End Else If Id='data' Then Begin
   DataSz:=Sz; If (DataSz<=0) Or (DataSz>CSize-P-8) Then DataSz:=CSize-P-8; Break;
  End;
  If Sz<0 Then Break;
  P:=P+8+Sz+(Sz And 1);
 End;
 If Br>0 Then M.DurMs:=(DataSz*1000) Div Br;
End;

Procedure ProbeAIFF(Var M: TMedia);
Var P,Sz,Frames,Mant: LongInt; Id: String; Ex: LongInt;
Begin
 P:=12;
 While P+8<=CSize Do Begin
  Id:=C4(P); Sz:=B32(P+4);
  If Id='COMM' Then Begin
   M.Chans:=B16(P+8); Frames:=B32(P+10); M.Bits:=B16(P+14);
   Ex:=B16(P+16)-16383; Mant:=B32(P+18);
   M.Rate:=Mant Shr (31-Ex);
   M.ACodec:='PCM';
   If C4(0+8)='AIFC' Then M.ACodec:=C4(P+26);
   If M.Rate>0 Then M.DurMs:=(Frames*1000) Div M.Rate;
   M.KBps:=(M.Rate*M.Chans*M.Bits) Div 1000;
   Exit;
  End;
  If Sz<0 Then Break;
  P:=P+8+Sz+(Sz And 1);
 End;
End;

Procedure ProbeAVI(Var M: TMedia);
Var P,Sz,E,Q,Qe,StrLen,Us,Tot: LongInt; Id,T,Ty: String; Scale,Rt,Len: LongInt;
 Depth: Integer;
 Procedure Walk(S,En: LongInt);
 Var Q,Z,Ze: LongInt; I,Typ: String; Tag: LongInt;
 Begin
  Q:=S;
  While Q+8<=En Do Begin
   I:=C4(Q); Z:=L32(Q+4);
   If Z<0 Then Break;
   If I='LIST' Then Begin
    If (C4(Q+8)='hdrl') Or (C4(Q+8)='strl') Then Begin
     If C4(Q+8)='strl' Then Ty:='';
     Walk(Q+12,Min(Q+8+Z,En));
    End;
   End Else If I='avih' Then Begin
    Us:=L32(Q+8); Tot:=L32(Q+24); M.W:=L32(Q+8+32); M.H:=L32(Q+8+36);
   End Else If I='strh' Then Begin
    Ty:=C4(Q+8); Scale:=L32(Q+8+20); Rt:=L32(Q+8+24); Len:=L32(Q+8+32);
    If (Ty='vids') And (Scale>0) Then Begin
     M.FpsX100:=(Rt*100) Div Scale; M.VCodec:=FourCCName(C4(Q+8+4));
     M.DurMs:=(Len*1000*Scale) Div Max(Rt,1);
    End;
   End Else If I='strf' Then Begin
    If Ty='vids' Then Begin
     M.W:=L32(Q+12); M.H:=Abs(L32(Q+16));
     If L32(Q+8+16)<>0 Then M.VCodec:=FourCCName(C4(Q+8+16)) Else M.VCodec:='RGB';
    End Else If Ty='auds' Then Begin
     Tag:=L16(Q+8); M.ACodec:=WavTagName(Tag); M.Chans:=L16(Q+10); M.Rate:=L32(Q+12);
     M.KBps:=(L32(Q+16)*8) Div 1000; M.Bits:=L16(Q+22);
    End;
   End;
   Q:=Q+8+Z+(Z And 1);
  End;
 End;
Begin
 Ty:=''; Us:=0; Tot:=0;
 Walk(12,Min(CSize,400000));
 If (M.DurMs=0) And (Us>0) Then M.DurMs:=(Tot*Us) Div 1000;
 If M.DurMs=0 Then M.DurMs:=(Tot*Us) Div 1000;
End;

Procedure ProbeMP4(Var M: TMedia);
Var P,Sz,Hdr: LongInt; Id: String; Brand: String; TS,Dur: LongInt;
 Cur: String;
 Procedure Walk(S,En: LongInt);
 Var Q,Z,H: LongInt; I: String; Ver: Integer; Ts2: LongInt; Fc: String;
 Begin
  Q:=S;
  While Q+8<=En Do Begin
   Z:=B32(Q); I:=C4(Q+4); H:=8;
   If Z=1 Then Begin Z:=B32(Q+12); H:=16; End;
   If (Z<8) And (Z<>0) Then Break;
   If Z=0 Then Z:=En-Q;
   If (I='moov') Or (I='trak') Or (I='mdia') Or (I='minf') Or (I='stbl') Then Begin
    If I='trak' Then Cur:='';
    Walk(Q+H,Min(Q+Z,En));
   End Else If I='mvhd' Then Begin
    If CB(Q+H)=1 Then Begin TS:=B32(Q+H+20); Dur:=B32(Q+H+28); End
    Else Begin TS:=B32(Q+H+12); Dur:=B32(Q+H+16); End;
    If TS>0 Then M.DurMs:=(Dur Div TS)*1000+((Dur Mod TS)*1000) Div TS;
   End Else If I='tkhd' Then Begin
    If CB(Q+H)=0 Then Begin
     If (B32(Q+H+76) Shr 16>0) Then Begin M.W:=B32(Q+H+76) Shr 16; M.H:=B32(Q+H+80) Shr 16; End;
    End Else Begin
     If (B32(Q+H+88) Shr 16>0) Then Begin M.W:=B32(Q+H+88) Shr 16; M.H:=B32(Q+H+92) Shr 16; End;
    End;
   End Else If I='hdlr' Then Cur:=C4(Q+H+8)
   Else If I='stsd' Then Begin
    Fc:=C4(Q+H+12);
    If Cur='vide' Then M.VCodec:=FourCCName(Fc)
    Else If Cur='soun' Then Begin
     If Fc='mp4a' Then M.ACodec:='AAC' Else M.ACodec:=Fc;
     M.Chans:=B16(Q+H+32); M.Rate:=B16(Q+H+40);
    End;
   End;
   Q:=Q+Z;
  End;
 End;
Begin
 Brand:=C4(8);
 Cur:='';
 If Brand='qt  ' Then M.Fmt:='MOV' Else If (Brand='M4A ') Or (Brand='M4B ') Then M.Fmt:='M4A'
 Else If Brand='3gp4' Then M.Fmt:='3GP' Else M.Fmt:='MP4';
 TS:=0; Dur:=0;
 Walk(0,CSize);
End;

Procedure ProbeMKV(Var M: TMedia);
Var Scale: LongInt; DurF: Double; TType: Integer; DocT: String;
 Function VInt(Var P: LongInt; KeepMarker: Boolean): LongInt;
 Var B,Mask: Byte; N,I: Integer; V: Double;
 Begin
  B:=CB(P); Mask:=$80; N:=1;
  While (N<=8) And ((B And Mask)=0) Do Begin Mask:=Mask Shr 1; Inc(N); End;
  If N>8 Then Begin VInt:=-1; Inc(P,N); Exit; End;
  If KeepMarker Then V:=B Else V:=B And (Mask-1);
  For I:=1 To N-1 Do V:=V*256+CB(P+I);
  Inc(P,N);
  If V>2000000000.0 Then V:=2000000000.0;
  VInt:=Round(V);
 End;
 Procedure Walk(S,En: LongInt; Lv: Integer);
 Var Q,Id,Sz,Dp: LongInt; Cd: String; K: Integer;
 Begin
  Q:=S;
  While Q<En Do Begin
   Id:=VInt(Q,True); Sz:=VInt(Q,False);
   If (Id<0) Or (Sz<0) Then Break;
   Dp:=Q;
   If Q+Sz>En Then Sz:=En-Q;
   Case Id Of
    $1A45DFA3,$18538067,$1549A966,$1654AE6B,$AE,$E0,$E1: Begin
     If Id=$AE Then TType:=0;
     Walk(Dp,Dp+Sz,Lv+1);
    End;
    $2AD7B1: Begin Scale:=0; For K:=0 To Sz-1 Do Scale:=Scale*256+CB(Dp+K); End;
    $4489: DurF:=BEDouble(Dp,Sz);
    $4282: DocT:=CStr(Dp,Sz);
    $83: TType:=CB(Dp);
    $86: Begin
     Cd:=CStr(Dp,Sz);
     If Copy(Cd,1,2)='V_' Then Begin
      If Cd='V_MPEG4/ISO/AVC' Then M.VCodec:='H.264' Else If Cd='V_MPEGH/ISO/HEVC' Then M.VCodec:='HEVC'
      Else If Cd='V_VP8' Then M.VCodec:='VP8' Else If Cd='V_VP9' Then M.VCodec:='VP9' Else If Cd='V_AV1' Then M.VCodec:='AV1'
      Else M.VCodec:=Copy(Cd,3,12);
     End Else If Copy(Cd,1,2)='A_' Then Begin
      If Copy(Cd,1,5)='A_AAC' Then M.ACodec:='AAC' Else If Cd='A_MPEG/L3' Then M.ACodec:='MP3' Else If Cd='A_VORBIS' Then M.ACodec:='Vorbis'
      Else If Cd='A_OPUS' Then M.ACodec:='Opus' Else If Cd='A_AC3' Then M.ACodec:='AC3' Else If Cd='A_FLAC' Then M.ACodec:='FLAC'
      Else M.ACodec:=Copy(Cd,3,12);
     End;
    End;
    $B0: M.W:=BEN(Dp,Sz);
    $BA: M.H:=BEN(Dp,Sz);
    $9F: M.Chans:=CB(Dp);
    $B5: M.Rate:=Round(BEDouble(Dp,Sz));
   End;
   If (Id<>$18538067) And (Id<>$1549A966) And (Id<>$1654AE6B) And (Id<>$AE) And (Id<>$E0) And (Id<>$E1) Then Q:=Dp+Sz
   Else Q:=Dp+Sz;
   If Id=$1F43B675 Then Break;
  End;
 End;
Begin
 Scale:=1000000; DurF:=0; TType:=0; DocT:='';
 Walk(0,Min(CSize,2000000),0);
 M.Fmt:='MKV'; If DocT='webm' Then M.Fmt:='WEBM';
 M.DurMs:=Round((DurF*Scale)/1000000);
 If M.W<0 Then M.W:=0;
End;

Procedure ProbeFLV(Var M: TMedia);
Var P,Sz,Ts,Cnt,Last: LongInt; Typ,B: Byte; I,K: Integer; Nm: String; V: Double; Q: LongInt;
Begin
 P:=B32(5)+4; Cnt:=0;
 While (P+11<CSize) And (Cnt<60) Do Begin
  Typ:=CB(P); Sz:=LongInt(CB(P+1))*65536+B16(P+2);
  If Typ=18 Then Begin
   { onMetaData : recherche des cles connues }
   For I:=0 To Min(Sz,600)-20 Do Begin
    Q:=P+11+I;
    If CB(Q)=0 Then Begin
     K:=CB(Q+1);
     If (K>=5) And (K<=12) And (CB(Q+2+K)=0) Then Begin
      Nm:=CStr(Q+2,K);
      V:=BEDouble(Q+2+K+1,8);
      If Nm='duration' Then M.DurMs:=Round(V*1000)
      Else If Nm='width' Then M.W:=Round(V)
      Else If Nm='height' Then M.H:=Round(V)
      Else If Nm='framerate' Then M.FpsX100:=Round(V*100)
      Else If Nm='videocodecid' Then Begin If Round(V)=7 Then M.VCodec:='H.264' Else If Round(V)=2 Then M.VCodec:='H.263' Else If Round(V)=4 Then M.VCodec:='VP6' End;
     End;
    End;
   End;
  End Else If Typ=9 Then Begin
   B:=CB(P+11) And 15;
   If M.VCodec='' Then Case B Of 2: M.VCodec:='H.263'; 3: M.VCodec:='Screen'; 4,5: M.VCodec:='VP6'; 7: M.VCodec:='H.264'; Else M.VCodec:='FLV'+IStr(B) End;
  End Else If Typ=8 Then Begin
   B:=CB(P+11) Shr 4;
   If M.ACodec='' Then Begin
    Case B Of 0,3: M.ACodec:='PCM'; 1: M.ACodec:='ADPCM'; 2: M.ACodec:='MP3'; 10: M.ACodec:='AAC'; 11: M.ACodec:='Speex'; Else M.ACodec:='FLV'+IStr(B) End;
    Case (CB(P+11) Shr 2) And 3 Of 0: M.Rate:=5512; 1: M.Rate:=11025; 2: M.Rate:=22050; Else M.Rate:=44100 End;
    M.Chans:=1+(CB(P+11) And 1);
   End;
  End;
  P:=P+11+Sz+4; Inc(Cnt);
 End;
 If M.DurMs=0 Then Begin
  Last:=B32(CSize-4);
  If (Last>0) And (Last<CSize) Then Begin
   P:=CSize-4-Last;
   M.DurMs:=LongInt(CB(P+4))*65536+B16(P+5)+LongInt(CB(P+7))*16777216;
  End;
 End;
End;

Procedure ProbeASF(Var M: TMedia);
Var P,Sz,N,Cnt: LongInt; Hv,Ha: Boolean; I: Integer; Ms: LongInt; Dur: Double;
Begin
 Hv:=False; Ha:=False;
 N:=L32(16+8); P:=30; Cnt:=0;
 While (P+24<CSize) And (Cnt<N) And (Cnt<40) Do Begin
  Sz:=L32(P+16);
  If (CB(P)=$A1) And (CB(P+1)=$DC) And (CB(P+2)=$AB) And (CB(P+3)=$8C) Then Begin
   Dur:=L32(P+64)+L32(P+68)*4294967296.0;
   Ms:=Round(Dur/10000.0)-L32(P+80);
   M.DurMs:=Ms;
  End Else If (CB(P)=$91) And (CB(P+1)=$07) And (CB(P+2)=$DC) And (CB(P+3)=$B7) Then Begin
   If (CB(P+24)=$C0) And (CB(P+25)=$EF) And (CB(P+26)=$19) Then Begin
    Hv:=True; M.W:=L32(P+78); M.H:=L32(P+82); M.VCodec:=FourCCName(C4(P+78+11+16));
   End Else If (CB(P+24)=$40) And (CB(P+25)=$9E) Then Begin
    Ha:=True; M.ACodec:=WavTagName(L16(P+78)); M.Chans:=L16(P+80); M.Rate:=L32(P+82);
   End;
  End;
  If (Sz<24) Or (Sz>CSize) Then Break;
  P:=P+Sz; Inc(Cnt);
 End;
 If Hv Then M.Fmt:='WMV' Else M.Fmt:='WMA';
End;

Procedure ProbeOGG(Var M: TMedia);
Var P: LongInt; Gran: Double; I: Integer;
Begin
 P:=28+CB(26);
 M.Fmt:='OGG';
 If (CB(P)=1) And (C4(P+1)='vor') Then Begin
  M.ACodec:='Vorbis'; M.Chans:=CB(P+11); M.Rate:=L32(P+12); M.KBps:=L32(P+20) Div 1000;
 End Else If C4(P)='Opus' Then Begin
  M.ACodec:='Opus'; M.Chans:=CB(P+9); M.Rate:=48000; M.Fmt:='OPUS';
 End Else If (CB(P)=$80) And (C4(P+1)='theo') Then Begin
  M.VCodec:='Theora'; M.W:=LongInt(CB(P+14))*65536+B16(P+15); M.H:=LongInt(CB(P+17))*65536+B16(P+18); M.Fmt:='OGV';
 End Else If (CB(P)=$7F) And (C4(P+1)='FLAC') Then M.ACodec:='FLAC';
 { granule de la derniere page }
 P:=CSize-5;
 While (P>CSize-70000) And (P>0) Do Begin
  If (CB(P)=Ord('O')) And (CB(P+1)=Ord('g')) And (CB(P+2)=Ord('g')) And (CB(P+3)=Ord('S')) Then Begin
   Gran:=L32(P+6)+L32(P+10)*4294967296.0;
   If (M.Rate>0) And (Gran>0) Then M.DurMs:=Round(Gran*1000.0/M.Rate);
   Break;
  End;
  Dec(P);
 End;
End;

Procedure ProbeFLAC(Var M: TMedia);
Var Tot: Double;
Begin
 M.Fmt:='FLAC'; M.ACodec:='FLAC';
 M.Rate:=(LongInt(CB(18)) Shl 12) Or (LongInt(CB(19)) Shl 4) Or (CB(20) Shr 4);
 M.Chans:=((CB(20) Shr 1) And 7)+1;
 M.Bits:=(((CB(20) And 1) Shl 4) Or (CB(21) Shr 4))+1;
 Tot:=(CB(21) And 15)*4294967296.0+B32(22);
 If M.Rate>0 Then M.DurMs:=Round(Tot*1000.0/M.Rate);
End;

Procedure ProbeGIF(Var M: TMedia);
Var P,Z: LongInt; Flags,B: Byte; Cnt,Dly: LongInt; Done: Boolean; Ct: LongInt;
Begin
 M.W:=L16(6); M.H:=L16(8);
 Flags:=CB(10); P:=13;
 If (Flags And $80)<>0 Then P:=P+3*(1 Shl ((Flags And 7)+1));
 Cnt:=0; Dly:=0; Done:=False;
 While (P<CSize) And Not Done Do Begin
  B:=CB(P);
  Case B Of
   $3B: Done:=True;
   $21: Begin
    If CB(P+1)=$F9 Then Dly:=Dly+L16(P+4);
    P:=P+2;
    While (P<CSize) And (CB(P)<>0) Do P:=P+CB(P)+1;
    Inc(P);
   End;
   $2C: Begin
    Inc(Cnt);
    Flags:=CB(P+9); P:=P+10;
    If (Flags And $80)<>0 Then P:=P+3*(1 Shl ((Flags And 7)+1));
    Inc(P);
    While (P<CSize) And (CB(P)<>0) Do P:=P+CB(P)+1;
    Inc(P);
   End;
   Else Done:=True;
  End;
 End;
 M.Frames:=Cnt; M.DurMs:=Dly*10;
 If Cnt>1 Then Begin M.Kind:=2; M.VCodec:='GIF'; End;
End;

Procedure ProbeJPEG(Var M: TMedia);
Var P: LongInt; Mk: Byte;
Begin
 P:=2;
 While P<CSize-8 Do Begin
  If CB(P)<>$FF Then Begin Inc(P); Continue; End;
  Mk:=CB(P+1);
  If (Mk>=$C0) And (Mk<=$CF) And (Mk<>$C4) And (Mk<>$C8) And (Mk<>$CC) Then Begin
   M.H:=B16(P+5); M.W:=B16(P+7); Exit;
  End;
  If (Mk=$D8) Or (Mk=$01) Or ((Mk>=$D0) And (Mk<=$D7)) Then Inc(P,2) Else P:=P+2+B16(P+2);
 End;
End;

Procedure ProbeMPEG(Var M: TMedia);
Var P,Lim: LongInt; S0,S1: Double; Got: Boolean;
 Function Scr(Q: LongInt): Double;
 Begin
  Scr:=((CB(Q+4) And $38) Shr 3)*1073741824.0*1.0 + (CB(Q+4) And 3)*268435456.0
   + CB(Q+5)*1048576.0 + ((CB(Q+6) And $F8) Shr 3)*32768.0 + (CB(Q+6) And 3)*8192.0
   + CB(Q+7)*32.0 + ((CB(Q+8) And $F8) Shr 3);
 End;
Begin
 M.Fmt:='MPG'; Got:=False;
 P:=0; Lim:=Min(CSize-14,600000);
 While P<Lim Do Begin
  If (CB(P)=0) And (CB(P+1)=0) And (CB(P+2)=1) Then Begin
   If (CB(P+3)=$BA) And Not Got Then Begin S0:=Scr(P); Got:=True; End
   Else If (CB(P+3)=$B3) And (M.W=0) Then Begin
    M.W:=(LongInt(CB(P+4)) Shl 4) Or (CB(P+5) Shr 4); M.H:=(LongInt(CB(P+5) And 15) Shl 8) Or CB(P+6);
    M.VCodec:='MPEG'; M.FpsX100:=0;
   End;
  End;
  Inc(P);
 End;
 If Got Then Begin
  P:=CSize-14; Lim:=Max(0,CSize-3000000);
  While P>Lim Do Begin
   If (CB(P)=0) And (CB(P+1)=0) And (CB(P+2)=1) And (CB(P+3)=$BA) Then Begin
    S1:=Scr(P); If S1>S0 Then M.DurMs:=Round((S1-S0)/90.0); Break;
   End;
   Dec(P);
  End;
 End;
End;

Procedure Analyze(Var M: TMedia; Const Path: String);
Var E,Mg: String; St: LongInt;
Begin
 FillChar(M,SizeOf(M),0);
 ResetEdit(M);
 M.Path:=Path; M.Size:=FileSizeOf(Path); M.Vol:=100;
 E:=ExtOf(Path); M.Fmt:=Copy(E,1,8);
 M.Kind:=MediaKind(E);
 M.Title:=BaseOf(Path);
 If Not COpen(Path) Then Begin M.Msg:='Fichier illisible'; Exit; End;
 Mg:=C4(0);
 If (Mg='RIFF') And (C4(8)='WAVE') Then Begin M.Fmt:='WAV'; M.Kind:=1; ProbeWAV(M); End
 Else If (Mg='RIFF') And (C4(8)='AVI ') Then Begin M.Fmt:='AVI'; M.Kind:=2; ProbeAVI(M); End
 Else If (Mg='FORM') And ((C4(8)='AIFF') Or (C4(8)='AIFC')) Then Begin M.Fmt:='AIFF'; M.Kind:=1; ProbeAIFF(M); End
 Else If Mg='fLaC' Then Begin M.Kind:=1; ProbeFLAC(M); End
 Else If Mg='OggS' Then Begin ProbeOGG(M); If M.VCodec<>'' Then M.Kind:=2 Else M.Kind:=1; End
 Else If Copy(Mg,1,3)='FLV' Then Begin M.Fmt:='FLV'; M.Kind:=2; ProbeFLV(M); End
 Else If C4(4)='ftyp' Then Begin ProbeMP4(M); If M.VCodec='' Then M.Kind:=1 Else M.Kind:=2; End
 Else If (C4(4)='moov') Or (C4(4)='mdat') Or (C4(4)='wide') Then Begin ProbeMP4(M); M.Fmt:='MOV'; M.Kind:=2; End
 Else If Mg=#$1A#$45#$DF#$A3 Then Begin ProbeMKV(M); If M.VCodec<>'' Then M.Kind:=2 Else M.Kind:=1; End
 Else If (CB(0)=$30) And (CB(1)=$26) And (CB(2)=$B2) And (CB(3)=$75) Then Begin M.Kind:=2; ProbeASF(M); End
 Else If Copy(Mg,1,3)='GIF' Then Begin M.Fmt:='GIF'; M.Kind:=3; ProbeGIF(M); End
 Else If Copy(Mg,1,2)='BM' Then Begin M.Fmt:='BMP'; M.Kind:=3; M.W:=L32(18); M.H:=Abs(L32(22)); End
 Else If Mg=#$89'PNG' Then Begin M.Fmt:='PNG'; M.Kind:=3; M.W:=B32(16); M.H:=B32(20); End
 Else If (CB(0)=$FF) And (CB(1)=$D8) Then Begin M.Fmt:='JPEG'; M.Kind:=3; ProbeJPEG(M); End
 Else If Copy(Mg,1,4)=#0#0#1#$BA Then Begin ProbeMPEG(M); M.Kind:=2; If E='VOB' Then M.Fmt:='VOB'; End
 Else If Mg='Crea' Then Begin M.Fmt:='VOC'; M.Kind:=1; M.ACodec:='PCM'; End
 Else If (C4(1080)='M.K.') Or (C4(1080)='4CHN') Or (C4(1080)='FLT4') Then Begin M.Fmt:='MOD'; M.Kind:=1; M.ACodec:='MOD'; M.Chans:=2; M.Rate:=22050; End
 Else If (CB(0)=$FF) And ((CB(1) And $E0)=$E0) Then Begin M.Kind:=1; ProbeMP3(M,0); M.Fmt:='MP3'; End
 Else If Copy(Mg,1,3)='ID3' Then Begin
  M.Kind:=1; ProbeID3(M,St); ProbeMP3(M,St); M.Fmt:='MP3';
  If M.Title='' Then M.Title:=BaseOf(Path);
 End
 Else If (CB(0)=$47) And (CB(188)=$47) Then Begin M.Fmt:='TS'; M.Kind:=2; End
 Else If (M.Kind=0) Then M.Msg:='Format non reconnu';
 CClose;
 If M.Kind=0 Then M.Kind:=MediaKind(E);
 If (M.Kind=1) And (M.ACodec='') And (M.Fmt<>'') Then M.ACodec:=M.Fmt;
End;

Function MediaInfoLine(Const M: TMedia): String;
Var S: String;
Begin
 S:=M.Fmt;
 If M.W>0 Then S:=S+'  '+IStr(M.W)+'x'+IStr(M.H);
 If M.Kind=1 Then Begin
  If M.Rate>0 Then S:=S+'  '+IStr(M.Rate)+' Hz';
  If M.Chans=1 Then S:=S+' mono' Else If M.Chans=2 Then S:=S+' st'#233'r'#233'o';
 End;
 S:=S+'  '+TimeStr(M.DurMs)+'  '+SizeStr(M.Size);
 MediaInfoLine:=S;
End;
{ ---- Primitives ADPCM (adaptees de FFMPEG.PAS / FFmpeg adpcm.c, LGPL-2.1+) ---- }
{ Primitives ADPCM communes (ADX, 4X Movie, Creative CT), adaptees de FFmpeg
  libavcodec/adpcm.c et adpcm_data.c, LGPL-2.1-or-later. }
Const
 ADPCMStepTable: Array[0..88] Of Integer=(
 7,8,9,10,11,12,13,14,16,17,
 19,21,23,25,28,31,34,37,41,45,
 50,55,60,66,73,80,88,97,107,118,
 130,143,157,173,190,209,230,253,279,307,
 337,371,408,449,494,544,598,658,724,796,
 876,963,1060,1166,1282,1411,1552,1707,1878,2066,
 2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,
 5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,
 15289,16818,18500,20350,22385,24623,27086,29794,32767);
 ADPCMIndexTable: Array[0..15] Of ShortInt=(-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,
  6,8);
 ADPCMCTAdapt: Array[0..7] Of Integer=(230,230,230,230,307,409,512,614);
{ Decalage arithmetique a droite (valeur signee). }

Function ADPCMSar(V: LongInt; N: Integer): LongInt;
Var
 D: LongInt;
Begin
 D:=LongInt(1) Shl N;
 If V>=0 Then ADPCMSar:=V Div D Else ADPCMSar:=-1-((-1-V) Div D);
End;

Function ADPCMClip16(V: LongInt): LongInt;Begin
 If V<-32768 Then V:=-32768; If V>32767 Then V:=32767; ADPCMClip16:=V;
End;
{ adpcm_ct: Pred et Step initialises a 0 et 511. }

Function ADPCMExpandCT(Var Pred,Step: LongInt; Nibble: Integer): Integer;
Var
 Diff,NewStep: LongInt;
Begin
 Diff:=((2*LongInt(Nibble And 7)+1)*Step) Shr 3;
 If (Nibble And 8)<>0 Then Diff:=-Diff;
 Pred:=ADPCMClip16(ADPCMSar(Pred*254,8)+Diff);
 NewStep:=(LongInt(ADPCMCTAdapt[Nibble And 7])*Step) Shr 8;
 If NewStep<511 Then NewStep:=511; If NewStep>32767 Then NewStep:=32767;
 Step:=NewStep; ADPCMExpandCT:=Pred;
End;
{ IMA 4X Movie: decalage 4, index borne a 0..88. }

Function ADPCMExpandIMA(Var Pred,Index: LongInt; Nibble: Integer): Integer;
Var
 Diff,NewIndex: LongInt;
Begin
 Diff:=((2*LongInt(Nibble And 7)+1)*ADPCMStepTable[Index]) Shr 4;
 NewIndex:=Index+ADPCMIndexTable[Nibble];
 If NewIndex<0 Then NewIndex:=0; If NewIndex>88 Then NewIndex:=88;
 If (Nibble And 8)<>0 Then Pred:=Pred-Diff Else Pred:=Pred+Diff;
 Pred:=ADPCMClip16(Pred); Index:=NewIndex; ADPCMExpandIMA:=Pred;
End;
{$IFDEF FPC}
{ ---- Moteurs audio integres (adaptes de FFMPEG.PAS) ---- }
Var
 EngOut: Text;
 EngMsg: String;
 EngJmp: jmp_buf;
 EngTickProc: Procedure(Pos,Total: LongInt);

Procedure EngAbort;
Begin
 LongJmp(EngJmp,1);
End;

Procedure EngTick(Pos,Total: LongInt);
Begin
 If @EngTickProc<>Nil Then EngTickProc(Pos,Total);
End;

{ Moteur integre depuis MP32WAV.PAS }

Procedure DecodeMP3(Const Source,Target: String);
Const
 MaxFrame = 2048;
 MaxWaveData = 2147483600;
 MP3Pi = 3.14159265358979323846;
Type
 TBytes = Array[0..4095] Of Byte;
 PBytes = ^TBytes;
 TBits = Record
  Data: PBytes;
  Position, Limit: Integer;
  Failed: Boolean;
 End;
 TBands = Array[0..39] Of Byte;
 TGranule = Record
  PartLength, BigValues, Gain, Compress, BlockType, Mixed: Integer;
  Region0, Region1, Scale, PreFlag, CountTable: Integer;
  Tables, SubGain: Array[0..2] Of Integer;
  LongBands, ShortBands: Integer;
  Bands: TBands;
  Factors, Intensity: Array[0..39] Of Integer;
 End;
 THeader = Record
  Version, Layer, Channels, Mode, Extension, FrequencyIndex, BandIndex: Integer;
  FrameSize, SideSize, SideOffset, Granules: Integer;
  Rate, BitRate: LongInt;
  Protected: Boolean;
 End;
 TDecoder = Record
  X: Array[0..1,0..575] Of Double;
  Overlap: Array[0..1,0..31,0..17] Of Double;
  V: Array[0..1,0..1023] Of Double;
  Scratch: Array[0..575] Of Double;
  PCM: Array[0..4607] Of Byte;
  Main: TBytes;
  Reservoir: Array[0..510] Of Byte;
  ReservoirSize: Integer;
  G: Array[0..1,0..1] Of TGranule;
  SCFSI: Array[0..1,0..3] Of Integer;
 End;
 PDecoder = ^TDecoder;
 TTransforms = Record
  Synthesis: Array[0..63,0..31] Of Double;
  LongCos: Array[0..35,0..17] Of Double;
  ShortCos: Array[0..11,0..5] Of Double;
  Window: Array[0..3,0..35] Of Double;
  CS, CA: Array[0..7] Of Double;
 End;
 PTransforms = ^TTransforms;
Const
 HuffTree: Array[0..2803] Of Word = (
 $0201,$0000,$0201,$0010,$0201,$0001,$0011,$0201,$0000,$0401,$0201,$0010,
 $0001,$0201,$0011,$0401,$0201,$0020,$0021,$0201,$0012,$0201,$0002,$0022,
 $0401,$0201,$0000,$0001,$0201,$0011,$0201,$0010,$0401,$0201,$0020,$0021,
 $0201,$0012,$0201,$0002,$0022,$0201,$0000,$0401,$0201,$0010,$0001,$0201,
 $0011,$0801,$0401,$0201,$0020,$0002,$0201,$0021,$0012,$0801,$0401,$0201,
 $0022,$0030,$0201,$0003,$0013,$0201,$0031,$0201,$0032,$0201,$0023,$0033,
 $0601,$0401,$0201,$0000,$0010,$0011,$0601,$0201,$0001,$0201,$0020,$0021,
 $0601,$0201,$0012,$0201,$0002,$0022,$0401,$0201,$0031,$0013,$0401,$0201,
 $0030,$0032,$0201,$0023,$0201,$0003,$0033,$0201,$0000,$0401,$0201,$0010,
 $0001,$0801,$0201,$0011,$0401,$0201,$0020,$0002,$0021,$1201,$0601,$0201,
 $0012,$0201,$0022,$0030,$0401,$0201,$0031,$0013,$0401,$0201,$0003,$0032,
 $0201,$0023,$0004,$0a01,$0401,$0201,$0040,$0041,$0201,$0014,$0201,$0042,
 $0024,$0c01,$0601,$0401,$0201,$0033,$0043,$0050,$0401,$0201,$0034,$0005,
 $0051,$0601,$0201,$0015,$0201,$0052,$0025,$0401,$0201,$0044,$0035,$0401,
 $0201,$0053,$0054,$0201,$0045,$0055,$0601,$0201,$0000,$0201,$0010,$0001,
 $0201,$0011,$0401,$0201,$0021,$0012,$0e01,$0401,$0201,$0020,$0002,$0201,
 $0022,$0401,$0201,$0030,$0003,$0201,$0031,$0013,$0e01,$0801,$0401,$0201,
 $0032,$0023,$0201,$0040,$0004,$0201,$0041,$0201,$0014,$0042,$0c01,$0601,
 $0201,$0024,$0201,$0033,$0050,$0401,$0201,$0043,$0034,$0051,$0601,$0201,
 $0015,$0201,$0005,$0052,$0601,$0201,$0025,$0201,$0044,$0035,$0201,$0053,
 $0201,$0045,$0201,$0054,$0055,$0801,$0401,$0201,$0000,$0010,$0201,$0001,
 $0011,$0a01,$0401,$0201,$0020,$0021,$0201,$0012,$0201,$0002,$0022,$0c01,
 $0601,$0401,$0201,$0030,$0003,$0031,$0201,$0013,$0201,$0032,$0023,$0c01,
 $0401,$0201,$0041,$0014,$0401,$0201,$0040,$0033,$0201,$0042,$0024,$0a01,
 $0601,$0401,$0201,$0004,$0050,$0043,$0201,$0034,$0051,$0801,$0401,$0201,
 $0015,$0052,$0201,$0025,$0044,$0601,$0401,$0201,$0005,$0054,$0053,$0201,
 $0035,$0201,$0045,$0055,$0201,$0000,$0401,$0201,$0010,$0001,$0a01,$0201,
 $0011,$0401,$0201,$0020,$0002,$0201,$0021,$0012,$1c01,$0801,$0401,$0201,
 $0022,$0030,$0201,$0031,$0013,$0801,$0401,$0201,$0003,$0032,$0201,$0023,
 $0040,$0401,$0201,$0041,$0014,$0401,$0201,$0004,$0033,$0201,$0042,$0024,
 $1c01,$0a01,$0601,$0401,$0201,$0050,$0005,$0060,$0201,$0061,$0016,$0c01,
 $0601,$0401,$0201,$0043,$0034,$0051,$0201,$0015,$0201,$0052,$0025,$0401,
 $0201,$0026,$0036,$0071,$1401,$0801,$0201,$0017,$0401,$0201,$0044,$0053,
 $0006,$0601,$0401,$0201,$0035,$0045,$0062,$0201,$0070,$0201,$0007,$0064,
 $0e01,$0401,$0201,$0072,$0027,$0601,$0201,$0063,$0201,$0054,$0055,$0201,
 $0046,$0073,$0801,$0401,$0201,$0037,$0065,$0201,$0056,$0074,$0601,$0201,
 $0047,$0201,$0066,$0075,$0401,$0201,$0057,$0076,$0201,$0067,$0077,$0601,
 $0201,$0000,$0201,$0010,$0001,$0801,$0201,$0011,$0401,$0201,$0020,$0002,
 $0012,$1801,$0801,$0201,$0021,$0201,$0022,$0201,$0030,$0003,$0401,$0201,
 $0031,$0013,$0401,$0201,$0032,$0023,$0401,$0201,$0040,$0004,$0201,$0041,
 $0014,$1e01,$1001,$0a01,$0401,$0201,$0042,$0024,$0401,$0201,$0033,$0043,
 $0050,$0401,$0201,$0034,$0051,$0061,$0601,$0201,$0016,$0201,$0006,$0026,
 $0201,$0062,$0201,$0015,$0201,$0005,$0052,$1001,$0a01,$0601,$0401,$0201,
 $0025,$0044,$0060,$0201,$0063,$0036,$0401,$0201,$0070,$0017,$0071,$1001,
 $0601,$0401,$0201,$0007,$0064,$0072,$0201,$0027,$0401,$0201,$0053,$0035,
 $0201,$0054,$0045,$0a01,$0401,$0201,$0046,$0073,$0201,$0037,$0201,$0065,
 $0056,$0a01,$0601,$0401,$0201,$0055,$0057,$0074,$0201,$0047,$0066,$0401,
 $0201,$0075,$0076,$0201,$0067,$0077,$0c01,$0401,$0201,$0010,$0001,$0201,
 $0011,$0201,$0000,$0201,$0020,$0002,$1001,$0401,$0201,$0021,$0012,$0401,
 $0201,$0022,$0031,$0201,$0013,$0201,$0030,$0201,$0003,$0040,$1a01,$0801,
 $0401,$0201,$0032,$0023,$0201,$0041,$0033,$0a01,$0401,$0201,$0014,$0042,
 $0201,$0024,$0201,$0004,$0050,$0401,$0201,$0043,$0034,$0201,$0051,$0015,
 $1c01,$0e01,$0801,$0401,$0201,$0052,$0025,$0201,$0053,$0035,$0401,$0201,
 $0060,$0016,$0061,$0401,$0201,$0062,$0026,$0601,$0401,$0201,$0005,$0006,
 $0044,$0201,$0054,$0045,$1201,$0a01,$0401,$0201,$0063,$0036,$0401,$0201,
 $0070,$0007,$0071,$0401,$0201,$0017,$0064,$0201,$0046,$0072,$0a01,$0601,
 $0201,$0027,$0201,$0055,$0073,$0201,$0037,$0056,$0801,$0401,$0201,$0065,
 $0074,$0201,$0047,$0066,$0401,$0201,$0075,$0057,$0201,$0076,$0201,$0067,
 $0077,$0201,$0000,$0601,$0201,$0010,$0201,$0001,$0011,$1c01,$0801,$0401,
 $0201,$0020,$0002,$0201,$0021,$0012,$0801,$0401,$0201,$0022,$0030,$0201,
 $0003,$0031,$0601,$0201,$0013,$0201,$0032,$0023,$0401,$0201,$0040,$0004,
 $0041,$4601,$1c01,$0e01,$0601,$0201,$0014,$0201,$0033,$0042,$0401,$0201,
 $0024,$0050,$0201,$0043,$0034,$0401,$0201,$0051,$0015,$0401,$0201,$0005,
 $0052,$0201,$0025,$0201,$0044,$0053,$0e01,$0801,$0401,$0201,$0060,$0006,
 $0201,$0061,$0016,$0401,$0201,$0080,$0008,$0081,$1001,$0801,$0401,$0201,
 $0035,$0062,$0201,$0026,$0054,$0401,$0201,$0045,$0063,$0201,$0036,$0070,
 $0601,$0401,$0201,$0007,$0055,$0071,$0201,$0017,$0201,$0027,$0037,$4801,
 $1801,$0c01,$0401,$0201,$0018,$0082,$0201,$0028,$0401,$0201,$0064,$0046,
 $0072,$0801,$0401,$0201,$0084,$0048,$0201,$0090,$0009,$0201,$0091,$0019,
 $1801,$0e01,$0801,$0401,$0201,$0073,$0065,$0201,$0056,$0074,$0401,$0201,
 $0047,$0066,$0083,$0601,$0201,$0038,$0201,$0075,$0057,$0201,$0092,$0029,
 $0e01,$0801,$0401,$0201,$0067,$0085,$0201,$0058,$0039,$0201,$0093,$0201,
 $0049,$0086,$0601,$0201,$00a0,$0201,$0068,$000a,$0201,$00a1,$001a,$4401,
 $1801,$0c01,$0401,$0201,$00a2,$002a,$0401,$0201,$0095,$0059,$0201,$00a3,
 $003a,$0801,$0401,$0201,$004a,$0096,$0201,$00b0,$000b,$0201,$00b1,$001b,
 $1401,$0801,$0201,$00b2,$0401,$0201,$0076,$0077,$0094,$0601,$0401,$0201,
 $0087,$0078,$00a4,$0401,$0201,$0069,$00a5,$002b,$0c01,$0601,$0401,$0201,
 $005a,$0088,$00b3,$0201,$003b,$0201,$0079,$00a6,$0601,$0401,$0201,$006a,
 $00b4,$00c0,$0401,$0201,$000c,$0098,$00c1,$3c01,$1601,$0a01,$0601,$0201,
 $001c,$0201,$0089,$00b5,$0201,$005b,$00c2,$0401,$0201,$002c,$003c,$0401,
 $0201,$00b6,$006b,$0201,$00c4,$004c,$1001,$0801,$0401,$0201,$00a8,$008a,
 $0201,$00d0,$000d,$0201,$00d1,$0201,$004b,$0201,$0097,$00a7,$0c01,$0601,
 $0201,$00c3,$0201,$007a,$0099,$0401,$0201,$00c5,$005c,$00b7,$0401,$0201,
 $001d,$00d2,$0201,$002d,$0201,$007b,$00d3,$3401,$1c01,$0c01,$0401,$0201,
 $003d,$00c6,$0401,$0201,$006c,$00a9,$0201,$009a,$00d4,$0801,$0401,$0201,
 $00b8,$008b,$0201,$004d,$00c7,$0401,$0201,$007c,$00d5,$0201,$005d,$00e0,
 $0a01,$0401,$0201,$00e1,$001e,$0401,$0201,$000e,$002e,$00e2,$0801,$0401,
 $0201,$00e3,$006d,$0201,$008c,$00e4,$0401,$0201,$00e5,$00ba,$00f0,$2601,
 $1001,$0401,$0201,$00f1,$001f,$0601,$0401,$0201,$00aa,$009b,$00b9,$0201,
 $003e,$0201,$00d6,$00c8,$0c01,$0601,$0201,$004e,$0201,$00d7,$007d,$0201,
 $00ab,$0201,$005e,$00c9,$0601,$0201,$000f,$0201,$009c,$006e,$0201,$00f2,
 $002f,$2001,$1001,$0601,$0401,$0201,$00d8,$008d,$003f,$0601,$0201,$00f3,
 $0201,$00e6,$00ca,$0201,$00f4,$004f,$0801,$0401,$0201,$00bb,$00ac,$0201,
 $00e7,$00f5,$0401,$0201,$00d9,$009d,$0201,$005f,$00e8,$1e01,$0c01,$0601,
 $0201,$006f,$0201,$00f6,$00cb,$0401,$0201,$00bc,$00ad,$00da,$0801,$0201,
 $00f7,$0401,$0201,$007e,$007f,$008e,$0601,$0401,$0201,$009e,$00ae,$00cc,
 $0201,$00f8,$008f,$1201,$0801,$0401,$0201,$00db,$00bd,$0201,$00ea,$00f9,
 $0401,$0201,$009f,$00eb,$0201,$00be,$0201,$00cd,$00fa,$0e01,$0401,$0201,
 $00dd,$00ec,$0601,$0401,$0201,$00e9,$00af,$00dc,$0201,$00ce,$00fb,$0801,
 $0401,$0201,$00bf,$00de,$0201,$00cf,$00ee,$0401,$0201,$00df,$00ef,$0201,
 $00ff,$0201,$00ed,$0201,$00fd,$0201,$00fc,$00fe,$1001,$0601,$0201,$0000,
 $0201,$0010,$0001,$0201,$0011,$0401,$0201,$0020,$0002,$0201,$0021,$0012,
 $3201,$1001,$0601,$0201,$0022,$0201,$0030,$0031,$0601,$0201,$0013,$0201,
 $0003,$0040,$0201,$0032,$0023,$0e01,$0601,$0401,$0201,$0004,$0014,$0041,
 $0401,$0201,$0033,$0042,$0201,$0024,$0043,$0a01,$0601,$0201,$0034,$0201,
 $0050,$0005,$0201,$0051,$0015,$0401,$0201,$0052,$0025,$0401,$0201,$0044,
 $0053,$0061,$5a01,$2401,$1201,$0a01,$0601,$0201,$0035,$0201,$0060,$0006,
 $0201,$0016,$0062,$0401,$0201,$0026,$0054,$0201,$0045,$0063,$0a01,$0601,
 $0201,$0036,$0201,$0070,$0007,$0201,$0071,$0055,$0401,$0201,$0017,$0064,
 $0201,$0072,$0027,$1801,$1001,$0801,$0401,$0201,$0046,$0073,$0201,$0037,
 $0065,$0401,$0201,$0056,$0080,$0201,$0008,$0074,$0401,$0201,$0081,$0018,
 $0201,$0082,$0028,$1001,$0801,$0401,$0201,$0047,$0066,$0201,$0083,$0038,
 $0401,$0201,$0075,$0057,$0201,$0084,$0048,$0601,$0401,$0201,$0090,$0019,
 $0091,$0401,$0201,$0092,$0076,$0201,$0067,$0029,$5c01,$2401,$1201,$0a01,
 $0401,$0201,$0085,$0058,$0401,$0201,$0009,$0077,$0093,$0401,$0201,$0039,
 $0094,$0201,$0049,$0086,$0a01,$0601,$0201,$0068,$0201,$00a0,$000a,$0201,
 $00a1,$001a,$0401,$0201,$00a2,$002a,$0201,$0095,$0059,$1a01,$0e01,$0601,
 $0201,$00a3,$0201,$003a,$0087,$0401,$0201,$0078,$00a4,$0201,$004a,$0096,
 $0601,$0401,$0201,$0069,$00b0,$00b1,$0401,$0201,$001b,$00a5,$00b2,$0e01,
 $0801,$0401,$0201,$005a,$002b,$0201,$0088,$0097,$0201,$00b3,$0201,$0079,
 $003b,$0801,$0401,$0201,$006a,$00b4,$0201,$004b,$00c1,$0401,$0201,$0098,
 $0089,$0201,$001c,$00b5,$5001,$2201,$1001,$0601,$0401,$0201,$005b,$002c,
 $00c2,$0601,$0401,$0201,$000b,$00c0,$00a6,$0201,$00a7,$007a,$0a01,$0401,
 $0201,$00c3,$003c,$0401,$0201,$000c,$0099,$00b6,$0401,$0201,$006b,$00c4,
 $0201,$004c,$00a8,$1401,$0a01,$0401,$0201,$008a,$00c5,$0401,$0201,$00d0,
 $005c,$00d1,$0401,$0201,$00b7,$007b,$0201,$001d,$0201,$000d,$002d,$0c01,
 $0401,$0201,$00d2,$00d3,$0401,$0201,$003d,$00c6,$0201,$006c,$00a9,$0601,
 $0401,$0201,$009a,$00b8,$00d4,$0401,$0201,$008b,$004d,$0201,$00c7,$007c,
 $4401,$2201,$1201,$0a01,$0401,$0201,$00d5,$005d,$0401,$0201,$00e0,$000e,
 $00e1,$0401,$0201,$001e,$00e2,$0201,$00aa,$002e,$0801,$0401,$0201,$00b9,
 $009b,$0201,$00e3,$00d6,$0401,$0201,$006d,$003e,$0201,$00c8,$008c,$1001,
 $0801,$0401,$0201,$00e4,$004e,$0201,$00d7,$007d,$0401,$0201,$00e5,$00ba,
 $0201,$00ab,$005e,$0801,$0401,$0201,$00c9,$009c,$0201,$00f1,$001f,$0601,
 $0401,$0201,$00f0,$006e,$00f2,$0201,$002f,$00e6,$2601,$1201,$0801,$0401,
 $0201,$00d8,$00f3,$0201,$003f,$00f4,$0601,$0201,$004f,$0201,$008d,$00d9,
 $0201,$00bb,$00ca,$0801,$0401,$0201,$00ac,$00e7,$0201,$007e,$00f5,$0801,
 $0401,$0201,$009d,$005f,$0201,$00e8,$008e,$0201,$00f6,$00cb,$2201,$1201,
 $0a01,$0601,$0401,$0201,$000f,$00ae,$006f,$0201,$00bc,$00da,$0401,$0201,
 $00ad,$00f7,$0201,$007f,$00e9,$0801,$0401,$0201,$009e,$00cc,$0201,$00f8,
 $008f,$0401,$0201,$00db,$00bd,$0201,$00ea,$00f9,$1001,$0801,$0401,$0201,
 $009f,$00dc,$0201,$00cd,$00eb,$0401,$0201,$00be,$00fa,$0201,$00af,$00dd,
 $0e01,$0601,$0401,$0201,$00ec,$00ce,$00fb,$0401,$0201,$00bf,$00ed,$0201,
 $00de,$00fc,$0601,$0401,$0201,$00cf,$00fd,$00ee,$0401,$0201,$00df,$00fe,
 $0201,$00ef,$00ff,$0201,$0000,$0601,$0201,$0010,$0201,$0001,$0011,$2a01,
 $0801,$0401,$0201,$0020,$0002,$0201,$0021,$0012,$0a01,$0601,$0201,$0022,
 $0201,$0030,$0003,$0201,$0031,$0013,$0a01,$0401,$0201,$0032,$0023,$0401,
 $0201,$0040,$0004,$0041,$0601,$0201,$0014,$0201,$0033,$0042,$0401,$0201,
 $0024,$0050,$0201,$0043,$0034,$8a01,$2801,$1001,$0601,$0401,$0201,$0005,
 $0015,$0051,$0401,$0201,$0052,$0025,$0401,$0201,$0044,$0035,$0053,$0a01,
 $0601,$0401,$0201,$0060,$0006,$0061,$0201,$0016,$0062,$0801,$0401,$0201,
 $0026,$0054,$0201,$0045,$0063,$0401,$0201,$0036,$0070,$0071,$2801,$1201,
 $0801,$0201,$0017,$0201,$0007,$0201,$0055,$0064,$0401,$0201,$0072,$0027,
 $0401,$0201,$0046,$0065,$0073,$0a01,$0601,$0201,$0037,$0201,$0056,$0008,
 $0201,$0080,$0081,$0601,$0201,$0018,$0201,$0074,$0047,$0201,$0082,$0201,
 $0028,$0066,$1801,$0e01,$0801,$0401,$0201,$0083,$0038,$0201,$0075,$0084,
 $0401,$0201,$0048,$0090,$0091,$0601,$0201,$0019,$0201,$0009,$0076,$0201,
 $0092,$0029,$0e01,$0801,$0401,$0201,$0085,$0058,$0201,$0093,$0039,$0401,
 $0201,$00a0,$000a,$001a,$0801,$0201,$00a2,$0201,$0067,$0201,$0057,$0049,
 $0601,$0201,$0094,$0201,$0077,$0086,$0201,$00a1,$0201,$0068,$0095,$dc01,
 $7e01,$3201,$1a01,$0c01,$0601,$0201,$002a,$0201,$0059,$003a,$0201,$00a3,
 $0201,$0087,$0078,$0801,$0401,$0201,$00a4,$004a,$0201,$0096,$0069,$0401,
 $0201,$00b0,$000b,$00b1,$0a01,$0401,$0201,$001b,$00b2,$0201,$002b,$0201,
 $00a5,$005a,$0601,$0201,$00b3,$0201,$00a6,$006a,$0401,$0201,$00b4,$004b,
 $0201,$000c,$00c1,$1e01,$0e01,$0601,$0401,$0201,$00b5,$00c2,$002c,$0401,
 $0201,$00a7,$00c3,$0201,$006b,$00c4,$0801,$0201,$001d,$0401,$0201,$0088,
 $0097,$003b,$0401,$0201,$00d1,$00d2,$0201,$002d,$00d3,$1201,$0601,$0401,
 $0201,$001e,$002e,$00e2,$0601,$0401,$0201,$0079,$0098,$00c0,$0201,$001c,
 $0201,$0089,$005b,$0e01,$0601,$0201,$003c,$0201,$007a,$00b6,$0401,$0201,
 $004c,$0099,$0201,$00a8,$008a,$0601,$0201,$000d,$0201,$00c5,$005c,$0401,
 $0201,$003d,$00c6,$0201,$006c,$009a,$5801,$5601,$2401,$1001,$0801,$0401,
 $0201,$008b,$004d,$0201,$00c7,$007c,$0401,$0201,$00d5,$005d,$0201,$00e0,
 $000e,$0801,$0201,$00e3,$0401,$0201,$00d0,$00b7,$007b,$0601,$0401,$0201,
 $00a9,$00b8,$00d4,$0201,$00e1,$0201,$00aa,$00b9,$1801,$0a01,$0601,$0401,
 $0201,$009b,$00d6,$006d,$0201,$003e,$00c8,$0601,$0401,$0201,$008c,$00e4,
 $004e,$0401,$0201,$00d7,$00e5,$0201,$00ba,$00ab,$0c01,$0401,$0201,$009c,
 $00e6,$0401,$0201,$006e,$00d8,$0201,$008d,$00bb,$0801,$0401,$0201,$00e7,
 $009d,$0201,$00e8,$008e,$0401,$0201,$00cb,$00bc,$009e,$00f1,$0201,$001f,
 $0201,$000f,$002f,$4201,$3801,$0201,$00f2,$3401,$3201,$1401,$0801,$0201,
 $00bd,$0201,$005e,$0201,$007d,$00c9,$0601,$0201,$00ca,$0201,$00ac,$007e,
 $0401,$0201,$00da,$00ad,$00cc,$0a01,$0601,$0201,$00ae,$0201,$00db,$00dc,
 $0201,$00cd,$00be,$0601,$0401,$0201,$00eb,$00ed,$00ee,$0601,$0401,$0201,
 $00d9,$00ea,$00e9,$0201,$00de,$0401,$0201,$00dd,$00ec,$00ce,$003f,$00f0,
 $0401,$0201,$00f3,$00f4,$0201,$004f,$0201,$00f5,$005f,$0a01,$0201,$00ff,
 $0401,$0201,$00f6,$006f,$0201,$00f7,$007f,$0c01,$0601,$0201,$008f,$0201,
 $00f8,$00f9,$0401,$0201,$009f,$00fa,$00af,$0801,$0401,$0201,$00fb,$00bf,
 $0201,$00fc,$00cf,$0401,$0201,$00fd,$00df,$0201,$00fe,$00ef,$3c01,$0801,
 $0401,$0201,$0000,$0010,$0201,$0001,$0011,$0e01,$0601,$0401,$0201,$0020,
 $0002,$0021,$0201,$0012,$0201,$0022,$0201,$0030,$0003,$0e01,$0401,$0201,
 $0031,$0013,$0401,$0201,$0032,$0023,$0401,$0201,$0040,$0004,$0041,$0801,
 $0401,$0201,$0014,$0033,$0201,$0042,$0024,$0601,$0401,$0201,$0043,$0034,
 $0051,$0601,$0401,$0201,$0050,$0005,$0015,$0201,$0052,$0025,$fa01,$6201,
 $2201,$1201,$0a01,$0401,$0201,$0044,$0053,$0201,$0035,$0201,$0060,$0006,
 $0401,$0201,$0061,$0016,$0201,$0062,$0026,$0801,$0401,$0201,$0054,$0045,
 $0201,$0063,$0036,$0401,$0201,$0071,$0055,$0201,$0064,$0046,$2001,$0e01,
 $0601,$0201,$0072,$0201,$0027,$0037,$0201,$0073,$0401,$0201,$0070,$0007,
 $0017,$0a01,$0401,$0201,$0065,$0056,$0401,$0201,$0080,$0008,$0081,$0401,
 $0201,$0074,$0047,$0201,$0018,$0082,$1001,$0801,$0401,$0201,$0028,$0066,
 $0201,$0083,$0038,$0401,$0201,$0075,$0057,$0201,$0084,$0048,$0801,$0401,
 $0201,$0091,$0019,$0201,$0092,$0076,$0401,$0201,$0067,$0029,$0201,$0085,
 $0058,$5c01,$2201,$1001,$0801,$0401,$0201,$0093,$0039,$0201,$0094,$0049,
 $0401,$0201,$0077,$0086,$0201,$0068,$00a1,$0801,$0401,$0201,$00a2,$002a,
 $0201,$0095,$0059,$0401,$0201,$00a3,$003a,$0201,$0087,$0201,$0078,$004a,
 $1601,$0c01,$0401,$0201,$00a4,$0096,$0401,$0201,$0069,$00b1,$0201,$001b,
 $00a5,$0601,$0201,$00b2,$0201,$005a,$002b,$0201,$0088,$00b3,$1001,$0a01,
 $0601,$0201,$0090,$0201,$0009,$00a0,$0201,$0097,$0079,$0401,$0201,$00a6,
 $006a,$00b4,$0c01,$0601,$0201,$001a,$0201,$000a,$00b0,$0201,$003b,$0201,
 $000b,$00c0,$0401,$0201,$004b,$00c1,$0201,$0098,$0089,$4301,$2201,$1001,
 $0801,$0401,$0201,$001c,$00b5,$0201,$005b,$00c2,$0401,$0201,$002c,$00a7,
 $0201,$007a,$00c3,$0a01,$0601,$0201,$003c,$0201,$000c,$00d0,$0201,$00b6,
 $006b,$0401,$0201,$00c4,$004c,$0201,$0099,$00a8,$1001,$0801,$0401,$0201,
 $008a,$00c5,$0201,$005c,$00d1,$0401,$0201,$00b7,$007b,$0201,$001d,$00d2,
 $0901,$0401,$0201,$002d,$00d3,$0201,$003d,$00c6,$55fa,$0401,$0201,$006c,
 $00a9,$0201,$009a,$00d4,$2001,$1001,$0801,$0401,$0201,$00b8,$008b,$0201,
 $004d,$00c7,$0401,$0201,$007c,$00d5,$0201,$005d,$00e1,$0801,$0401,$0201,
 $001e,$00e2,$0201,$00aa,$00b9,$0401,$0201,$009b,$00e3,$0201,$00d6,$006d,
 $1401,$0a01,$0601,$0201,$003e,$0201,$002e,$004e,$0201,$00c8,$008c,$0401,
 $0201,$00e4,$00d7,$0401,$0201,$007d,$00ab,$00e5,$0a01,$0401,$0201,$00ba,
 $005e,$0201,$00c9,$0201,$009c,$006e,$0801,$0201,$00e6,$0201,$000d,$0201,
 $00e0,$000e,$0401,$0201,$00d8,$008d,$0201,$00bb,$00ca,$4a01,$0201,$00ff,
 $4001,$3a01,$2001,$1001,$0801,$0401,$0201,$00ac,$00e7,$0201,$007e,$00d9,
 $0401,$0201,$009d,$00e8,$0201,$008e,$00cb,$0801,$0401,$0201,$00bc,$00da,
 $0201,$00ad,$00e9,$0401,$0201,$009e,$00cc,$0201,$00db,$00bd,$1001,$0801,
 $0401,$0201,$00ea,$00ae,$0201,$00dc,$00cd,$0401,$0201,$00eb,$00be,$0201,
 $00dd,$00ec,$0801,$0401,$0201,$00ce,$00ed,$0201,$00de,$00ee,$000f,$0401,
 $0201,$00f0,$001f,$00f1,$0401,$0201,$00f2,$002f,$0201,$00f3,$003f,$1201,
 $0801,$0401,$0201,$00f4,$004f,$0201,$00f5,$005f,$0401,$0201,$00f6,$006f,
 $0201,$00f7,$0201,$007f,$008f,$0a01,$0401,$0201,$00f8,$00f9,$0401,$0201,
 $009f,$00af,$00fa,$0801,$0401,$0201,$00fb,$00bf,$0201,$00fc,$00cf,$0401,
 $0201,$00fd,$00df,$0201,$00fe,$00ef,$0201,$0000,$0801,$0401,$0201,$0008,
 $0004,$0201,$0001,$0002,$0801,$0401,$0201,$000c,$000a,$0201,$0003,$0006,
 $0601,$0201,$0009,$0201,$0005,$0007,$0401,$0201,$000e,$000d,$0201,$000f,
 $000b,$1001,$0801,$0401,$0201,$0000,$0001,$0201,$0002,$0003,$0401,$0201,
 $0004,$0005,$0201,$0006,$0007,$0801,$0401,$0201,$0008,$0009,$0201,$000a,
 $000b,$0401,$0201,$000c,$000d,$0201,$000e,$000f);
 SynthWindow: Array[0..511] Of Double = (
 0.000000000,-0.000015259,-0.000015259,-0.000015259,-0.000015259,-0.000015259,
 -0.000015259,-0.000030518,-0.000030518,-0.000030518,-0.000030518,-0.000045776,
 -0.000045776,-0.000061035,-0.000061035,-0.000076294,-0.000076294,-0.000091553,
 -0.000106812,-0.000106812,-0.000122070,-0.000137329,-0.000152588,-0.000167847,
 -0.000198364,-0.000213623,-0.000244141,-0.000259399,-0.000289917,-0.000320435,
 -0.000366211,-0.000396729,-0.000442505,-0.000473022,-0.000534058,-0.000579834,
 -0.000625610,-0.000686646,-0.000747681,-0.000808716,-0.000885010,-0.000961304,
 -0.001037598,-0.001113892,-0.001205444,-0.001296997,-0.001388550,-0.001480103,
 -0.001586914,-0.001693726,-0.001785278,-0.001907349,-0.002014160,-0.002120972,
 -0.002243042,-0.002349854,-0.002456665,-0.002578735,-0.002685547,-0.002792358,
 -0.002899170,-0.002990723,-0.003082275,-0.003173828,0.003250122,0.003326416,
 0.003387451,0.003433228,0.003463745,0.003479004,0.003479004,0.003463745,
 0.003417969,0.003372192,0.003280640,0.003173828,0.003051758,0.002883911,
 0.002700806,0.002487183,0.002227783,0.001937866,0.001617432,0.001266479,
 0.000869751,0.000442505,-0.000030518,-0.000549316,-0.001098633,-0.001693726,
 -0.002334595,-0.003005981,-0.003723145,-0.004486084,-0.005294800,-0.006118774,
 -0.007003784,-0.007919312,-0.008865356,-0.009841919,-0.010848999,-0.011886597,
 -0.012939453,-0.014022827,-0.015121460,-0.016235352,-0.017349243,-0.018463135,
 -0.019577026,-0.020690918,-0.021789551,-0.022857666,-0.023910522,-0.024932861,
 -0.025909424,-0.026840210,-0.027725220,-0.028533936,-0.029281616,-0.029937744,
 -0.030532837,-0.031005859,-0.031387329,-0.031661987,-0.031814575,-0.031845093,
 -0.031738281,-0.031478882,0.031082153,0.030517578,0.029785156,0.028884888,
 0.027801514,0.026535034,0.025085449,0.023422241,0.021575928,0.019531250,
 0.017257690,0.014801025,0.012115479,0.009231567,0.006134033,0.002822876,
 -0.000686646,-0.004394531,-0.008316040,-0.012420654,-0.016708374,-0.021179199,
 -0.025817871,-0.030609131,-0.035552979,-0.040634155,-0.045837402,-0.051132202,
 -0.056533813,-0.061996460,-0.067520142,-0.073059082,-0.078628540,-0.084182739,
 -0.089706421,-0.095169067,-0.100540161,-0.105819702,-0.110946655,-0.115921021,
 -0.120697021,-0.125259399,-0.129562378,-0.133590698,-0.137298584,-0.140670776,
 -0.143676758,-0.146255493,-0.148422241,-0.150115967,-0.151306152,-0.151962280,
 -0.152069092,-0.151596069,-0.150497437,-0.148773193,-0.146362305,-0.143264771,
 -0.139450073,-0.134887695,-0.129577637,-0.123474121,-0.116577148,-0.108856201,
 0.100311279,0.090927124,0.080688477,0.069595337,0.057617188,0.044784546,
 0.031082153,0.016510010,0.001068115,-0.015228271,-0.032379150,-0.050354004,
 -0.069168091,-0.088775635,-0.109161377,-0.130310059,-0.152206421,-0.174789429,
 -0.198059082,-0.221984863,-0.246505737,-0.271591187,-0.297210693,-0.323318481,
 -0.349868774,-0.376800537,-0.404083252,-0.431655884,-0.459472656,-0.487472534,
 -0.515609741,-0.543823242,-0.572036743,-0.600219727,-0.628295898,-0.656219482,
 -0.683914185,-0.711318970,-0.738372803,-0.765029907,-0.791213989,-0.816864014,
 -0.841949463,-0.866363525,-0.890090942,-0.913055420,-0.935195923,-0.956481934,
 -0.976852417,-0.996246338,-1.014617920,-1.031936646,-1.048156738,-1.063217163,
 -1.077117920,-1.089782715,-1.101211548,-1.111373901,-1.120223999,-1.127746582,
 -1.133926392,-1.138763428,-1.142211914,-1.144287109,1.144989014,1.144287109,
 1.142211914,1.138763428,1.133926392,1.127746582,1.120223999,1.111373901,
 1.101211548,1.089782715,1.077117920,1.063217163,1.048156738,1.031936646,
 1.014617920,0.996246338,0.976852417,0.956481934,0.935195923,0.913055420,
 0.890090942,0.866363525,0.841949463,0.816864014,0.791213989,0.765029907,
 0.738372803,0.711318970,0.683914185,0.656219482,0.628295898,0.600219727,
 0.572036743,0.543823242,0.515609741,0.487472534,0.459472656,0.431655884,
 0.404083252,0.376800537,0.349868774,0.323318481,0.297210693,0.271591187,
 0.246505737,0.221984863,0.198059082,0.174789429,0.152206421,0.130310059,
 0.109161377,0.088775635,0.069168091,0.050354004,0.032379150,0.015228271,
 -0.001068115,-0.016510010,-0.031082153,-0.044784546,-0.057617188,-0.069595337,
 -0.080688477,-0.090927124,0.100311279,0.108856201,0.116577148,0.123474121,
 0.129577637,0.134887695,0.139450073,0.143264771,0.146362305,0.148773193,
 0.150497437,0.151596069,0.152069092,0.151962280,0.151306152,0.150115967,
 0.148422241,0.146255493,0.143676758,0.140670776,0.137298584,0.133590698,
 0.129562378,0.125259399,0.120697021,0.115921021,0.110946655,0.105819702,
 0.100540161,0.095169067,0.089706421,0.084182739,0.078628540,0.073059082,
 0.067520142,0.061996460,0.056533813,0.051132202,0.045837402,0.040634155,
 0.035552979,0.030609131,0.025817871,0.021179199,0.016708374,0.012420654,
 0.008316040,0.004394531,0.000686646,-0.002822876,-0.006134033,-0.009231567,
 -0.012115479,-0.014801025,-0.017257690,-0.019531250,-0.021575928,-0.023422241,
 -0.025085449,-0.026535034,-0.027801514,-0.028884888,-0.029785156,-0.030517578,
 0.031082153,0.031478882,0.031738281,0.031845093,0.031814575,0.031661987,
 0.031387329,0.031005859,0.030532837,0.029937744,0.029281616,0.028533936,
 0.027725220,0.026840210,0.025909424,0.024932861,0.023910522,0.022857666,
 0.021789551,0.020690918,0.019577026,0.018463135,0.017349243,0.016235352,
 0.015121460,0.014022827,0.012939453,0.011886597,0.010848999,0.009841919,
 0.008865356,0.007919312,0.007003784,0.006118774,0.005294800,0.004486084,
 0.003723145,0.003005981,0.002334595,0.001693726,0.001098633,0.000549316,
 0.000030518,-0.000442505,-0.000869751,-0.001266479,-0.001617432,-0.001937866,
 -0.002227783,-0.002487183,-0.002700806,-0.002883911,-0.003051758,-0.003173828,
 -0.003280640,-0.003372192,-0.003417969,-0.003463745,-0.003479004,-0.003479004,
 -0.003463745,-0.003433228,-0.003387451,-0.003326416,0.003250122,0.003173828,
 0.003082275,0.002990723,0.002899170,0.002792358,0.002685547,0.002578735,
 0.002456665,0.002349854,0.002243042,0.002120972,0.002014160,0.001907349,
 0.001785278,0.001693726,0.001586914,0.001480103,0.001388550,0.001296997,
 0.001205444,0.001113892,0.001037598,0.000961304,0.000885010,0.000808716,
 0.000747681,0.000686646,0.000625610,0.000579834,0.000534058,0.000473022,
 0.000442505,0.000396729,0.000366211,0.000320435,0.000289917,0.000259399,
 0.000244141,0.000213623,0.000198364,0.000167847,0.000152588,0.000137329,
 0.000122070,0.000106812,0.000106812,0.000091553,0.000076294,0.000076294,
 0.000061035,0.000061035,0.000045776,0.000045776,0.000030518,0.000030518,
 0.000030518,0.000030518,0.000015259,0.000015259,0.000015259,0.000015259,
 0.000015259,0.000015259);
 HuffOffset: Array[0..33] Of Integer = (
 0,0,7,24,0,41,72,103,174,245,316,443,
 570,697,0,1208,1719,1719,1719,1719,1719,1719,1719,1719,
 2230,2230,2230,2230,2230,2230,2230,2230,2742,2773);
 HuffLength: Array[0..33] Of Integer = (
 0,7,17,17,0,31,31,71,71,71,127,127,
 127,511,0,511,511,511,511,511,511,511,511,511,
 512,512,512,512,512,512,512,512,31,31);
 HuffLinBits: Array[0..33] Of Integer = (
 0,0,0,0,0,0,0,0,0,0,0,0,
 0,0,0,0,1,2,3,4,6,8,10,13,
 4,5,6,7,8,9,11,13,0,0);
 LongWidths: Array[0..7] Of TBands = (
 (6,6,6,6,6,6,8,10,12,14,16,20,24,28,32,38,46,52,60,68,58,54,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,
 0,0,0,0),
 (12,12,12,12,12,12,16,20,24,28,32,40,48,56,64,76,90,2,2,2,2,2,0,0,0,0,0,0,0,0,
  0,0,0,0,0,
 0,0,0,0,0),
 (6,6,6,6,6,6,8,10,12,14,16,20,24,28,32,38,46,52,60,68,58,54,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,
 0,0,0,0),
 (6,6,6,6,6,6,8,10,12,14,16,18,22,26,32,38,46,54,62,70,76,36,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,
 0,0,0,0),
 (6,6,6,6,6,6,8,10,12,14,16,20,24,28,32,38,46,52,60,68,58,54,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,
 0,0,0,0),
 (4,4,4,4,4,4,6,6,8,8,10,12,16,20,24,28,34,42,50,54,76,158,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,
 0,0,0),
 (4,4,4,4,4,4,6,6,6,8,10,12,16,18,22,28,34,40,46,54,54,192,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,
 0,0,0),
 (4,4,4,4,4,4,6,6,8,10,12,16,20,24,30,38,46,56,68,84,102,26,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,
 0,0,0));
 ShortWidths: Array[0..7] Of TBands = (
 (4,4,4,4,4,4,4,4,4,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,18,18,18,24,24,24,30,
  30,30,40,
 40,40,18,18,18,0),
 (8,8,8,8,8,8,8,8,8,12,12,12,16,16,16,20,20,20,24,24,24,28,28,28,36,36,36,2,2,2,
  2,2,2,2,2,
 2,26,26,26,0),
 (4,4,4,4,4,4,4,4,4,6,6,6,6,6,6,8,8,8,10,10,10,14,14,14,18,18,18,26,26,26,32,32,
  32,42,42,
 42,18,18,18,0),
 (4,4,4,4,4,4,4,4,4,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,18,18,18,24,24,24,32,
  32,32,44,
 44,44,12,12,12,0),
 (4,4,4,4,4,4,4,4,4,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,18,18,18,24,24,24,30,
  30,30,40,
 40,40,18,18,18,0),
 (4,4,4,4,4,4,4,4,4,4,4,4,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,18,18,18,22,22,
  22,30,30,
 30,56,56,56,0),
 (4,4,4,4,4,4,4,4,4,4,4,4,6,6,6,6,6,6,10,10,10,12,12,12,14,14,14,16,16,16,20,20,
  20,26,26,
 26,66,66,66,0),
 (4,4,4,4,4,4,4,4,4,4,4,4,6,6,6,8,8,8,12,12,12,16,16,16,20,20,20,26,26,26,34,34,
  34,42,42,
 42,12,12,12,0));
 MixedWidths: Array[0..7] Of TBands = (
 (6,6,6,6,6,6,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,18,18,18,24,24,24,30,30,30,
  40,40,40,
 18,18,18,0,0,0,0),
 (12,12,12,4,4,4,8,8,8,12,12,12,16,16,16,20,20,20,24,24,24,28,28,28,36,36,36,2,
  2,2,2,2,2,
 2,2,2,26,26,26,0),
 (6,6,6,6,6,6,6,6,6,6,6,6,8,8,8,10,10,10,14,14,14,18,18,18,26,26,26,32,32,32,42,
  42,42,18,
 18,18,0,0,0,0),
 (6,6,6,6,6,6,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,18,18,18,24,24,24,32,32,32,
  44,44,44,
 12,12,12,0,0,0,0),
 (6,6,6,6,6,6,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,18,18,18,24,24,24,30,30,30,
  40,40,40,
 18,18,18,0,0,0,0),
 (4,4,4,4,4,4,6,6,4,4,4,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,18,18,18,22,22,
  22,30,30,30,
 56,56,56,0,0),
 (4,4,4,4,4,4,6,6,4,4,4,6,6,6,6,6,6,10,10,10,12,12,12,14,14,14,16,16,16,20,20,
  20,26,26,26,
 66,66,66,0,0),
 (4,4,4,4,4,4,6,6,4,4,4,6,6,6,8,8,8,12,12,12,16,16,16,20,20,20,26,26,26,34,34,
  34,42,42,42,
 12,12,12,0,0));
 FactorPartitions: Array[0..2,0..27] Of Byte = (
 (6,5,5,5,6,5,5,5,6,5,7,3,11,10,0,0,7,7,7,0,6,6,6,3,8,8,5,0),
 (8,9,6,12,6,9,9,9,6,9,12,6,15,18,0,0,6,15,12,0,6,12,9,6,6,18,9,0),
 (9,9,6,12,9,9,9,9,9,9,12,6,18,18,0,0,12,12,12,0,12,9,9,6,15,12,9,0));
Var
 InputFile, OutputFile: File;
 InputName, OutputName: String;
 InputOpen, OutputOpen, OutputCreated: Boolean;
 InputSize, InputEnd, InputPosition, Written, Frames: LongInt;
 Frame: Array[0..MaxFrame-1] Of Byte;
 D: PDecoder;
 Transform: PTransforms;
 Header, FirstHeader: THeader;

Procedure Fail(MessageText: String);
Var
 ErrorCode: Integer;
Begin
 EngMsg:=MessageText;
 If InputOpen Then Begin
  {$I-}Close(InputFile); ErrorCode := IOResult;{$I+}
  InputOpen := False;
 End;
 If OutputOpen Then Begin
  {$I-}Close(OutputFile); ErrorCode := IOResult;{$I+}
  OutputOpen := False;
 End;
 If OutputCreated Then Begin
  {$I-}Erase(OutputFile); ErrorCode := IOResult;{$I+}
  If ErrorCode <> 0 Then WriteLn(EngOut,'Sortie incomplete a supprimer: ', OutputName);
 End;
 EngAbort;
End;

Function Exists(Name: String): Boolean;
Var
 F: File;
 Attributes: Word;
Begin
 Assign(F, Name); GetFAttr(F, Attributes); Exists := DosError = 0;
End;

Function DefaultOutput(Name: String): String;
Var
 I: Integer;
Begin
 I := Length(Name);
 While (I > 0) And Not (Name[I] In ['.', '/', '\', ':']) Do Dec(I);
 If (I > 0) And (Name[I] = '.') Then Name := Copy(Name, 1, I - 1);
 If Length(Name) > 251 Then Fail('Nom de sortie trop long.');
 DefaultOutput := Name + '.wav';
End;

Procedure Help;Begin
 WriteLn(EngOut,'MP32WAV - Cette commande permet de convertir un MP3 vers ',
 'WAV PCM 16 bits, decodeur integre');
 WriteLn(EngOut);
 WriteLn(EngOut,'Syntaxe : MP32WAV entree.mp3 [sortie.wav]');
 WriteLn(EngOut,'          MP32WAV /?   ou --help');
 WriteLn(EngOut);
 WriteLn(EngOut,'MPEG-1/2/2.5 Layer III, mono/stereo, CBR/VBR, 8..48 kHz.');
 WriteLn(EngOut,'Frequence et nombre de canaux conserves. Aucun outil externe.');
 WriteLn(EngOut,'Sortie existante refusee. Limite: 2 Go par fichier.');
 WriteLn(EngOut,'Free-format, changements de format et preaccentuation refuses.');
 WriteLn(EngOut,'Blocs mixtes a 8 kHz non pris en charge.');
 WriteLn(EngOut,
  'Derniere trame incomplete ignoree avec avertissement si audio deja decode.');
 WriteLn(EngOut,'Delai/remplissage encodeur conserves (pas de correction gapless).');
End;

Procedure ReadAt(Position: LongInt; Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 If (Position < 0) Or (Position > InputSize) Then Fail(
  'Position MP3 incorrecte.');
 If Count > InputSize - Position Then Fail('Fichier MP3 tronque.');
 {$I-}Seek(InputFile, Position); ErrorCode := IOResult;{$I+}
 If ErrorCode <> 0 Then Fail('Positionnement MP3 impossible.');
 {$I-}BlockRead(InputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Lecture MP3 incomplete.');
End;

Procedure WriteBytes(Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 {$I-}BlockWrite(OutputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Ecriture WAV incomplete.');
End;

Procedure Put16(Value: Word);
Var
 B: Array[0..1] Of Byte;
Begin
 B[0] := Value And 255; B[1] := Value Shr 8; WriteBytes(B, 2);
End;

Procedure Put32(Value: LongInt);
Var
 B: Array[0..3] Of Byte;
 I: Integer;
Begin
 For I := 0 To 3 Do Begin
  B[I] := Value And 255; Value := Value Shr 8;
 End;
 WriteBytes(B, 4);
End;

Procedure WriteWaveHeader;
Var
 ErrorCode: Integer;
 Tag: String[4];
Begin
 {$I-}Seek(OutputFile, 0); ErrorCode := IOResult;{$I+}
 If ErrorCode <> 0 Then Fail('Positionnement WAV impossible.');
 Tag := 'RIFF'; WriteBytes(Tag[1], 4); Put32(Written + 36);
 Tag := 'WAVE'; WriteBytes(Tag[1], 4);
 Tag := 'fmt '; WriteBytes(Tag[1], 4); Put32(16); Put16(1);
 Put16(FirstHeader.Channels); Put32(FirstHeader.Rate);
 Put32(FirstHeader.Rate * FirstHeader.Channels * 2);
 Put16(FirstHeader.Channels * 2); Put16(16);
 Tag := 'data'; WriteBytes(Tag[1], 4); Put32(Written);
End;

Function ReadBits(Var B: TBits; Count: Integer): Integer;
Var
 I, Value: Integer;
Begin
 Value := 0;
 If (Count < 0) Or (Count > 15) Or (Count > B.Limit - B.Position) Then Begin
  B.Failed := True; ReadBits := 0; Exit;
 End;
 For I := 1 To Count Do Begin
  Value := (Value Shl 1) Or ((B.Data^[B.Position Div 8] Shr (7 - B.Position Mod
   8)) And 1)
  ;
  Inc(B.Position);
 End;
 ReadBits := Value;
End;

Procedure StartBits(Var B: TBits; Buffer: PBytes; FirstBit, LastBit:
 Integer);Begin
 B.Data := Buffer; B.Position := FirstBit; B.Limit := LastBit; B.Failed :=
  False;
End;

Procedure ParseHeader;
Const
 Rates: Array[0..2] Of LongInt = (44100,48000,32000);
 BR1: Array[0..14] Of Integer = (0,32,40,48,56,64,80,96,112,128,160,192,224,256,
  320);
 BR2: Array[0..14] Of Integer = (0,8,16,24,32,40,48,56,64,80,96,112,128,144,
  160);
 L1BR: Array[0..14] Of Integer = (0,32,64,96,128,160,192,224,256,288,320,352,
  384,416,448);
 L1LSF: Array[0..14] Of Integer = (0,32,48,56,64,80,96,112,128,144,160,176,192,
  224,256);
Var
 Index, Layer: Integer;
Begin
 If (Frame[0] <> 255) Or ((Frame[1] And $E0) <> $E0) Then Fail(
 'Synchronisation MP3 incorrecte.');
 Header.Version := (Frame[1] Shr 3) And 3;
 If Header.Version = 1 Then Fail('Version MPEG reservee.');
 Layer := (Frame[1] Shr 1) And 3;
 Header.Layer:=Layer;
 If (Layer<>1) And (Layer<>3) Then Fail(
  'MPEG Layer I (MP1) ou III (MP3) requis.');
 Index := Frame[2] Shr 4;
 If Index = 0 Then Fail('MP3 free-format non pris en charge.');
 If Index = 15 Then Fail('Debit MP3 invalide.');
 Header.FrequencyIndex := (Frame[2] Shr 2) And 3;
 If Header.FrequencyIndex = 3 Then Fail('Frequence MP3 invalide.');
 Header.Rate := Rates[Header.FrequencyIndex];
 Header.BandIndex := Header.FrequencyIndex;
 If Header.Version = 3 Then Begin
  Header.BitRate := LongInt(BR1[Index]) * 1000; Header.Granules := 2;
  Inc(Header.BandIndex, 6);
 End Else
 Begin
  Header.BitRate := LongInt(BR2[Index]) * 1000; Header.Granules := 1;
  If Header.Version = 2 Then Begin
   Header.Rate := Header.Rate Div 2; Inc(Header.BandIndex, 3);
  End
  Else Header.Rate := Header.Rate Div 4;
 End;
 If Header.BandIndex > 0 Then Dec(Header.BandIndex);
 Header.Mode := Frame[3] Shr 6; Header.Extension := (Frame[3] Shr 4) And 3;
 Header.Channels := 2; If Header.Mode = 3 Then Header.Channels := 1;
 If (Frame[3] And 3) <> 0 Then Fail(
  'MP3 avec preaccentuation non pris en charge.');
 Header.Protected := (Frame[1] And 1) = 0;
 Header.SideOffset := 4; If Header.Protected Then Inc(Header.SideOffset, 2);
 If Header.Version = 3 Then Header.SideSize := 15 * Header.Channels + 2
                       Else Header.SideSize := 8 * Header.Channels + 1;
 Header.FrameSize := (72 * Header.Granules * Header.BitRate) Div Header.Rate + (
  (
 Frame[2] Shr 1) And 1);
 If Layer=3 Then Begin
  If Header.Version=3 Then Header.BitRate:=LongInt(L1BR[Index])*1000
                      Else Header.BitRate:=LongInt(L1LSF[Index])*1000;
  Header.FrameSize:=((12*Header.BitRate) Div Header.Rate+((Frame[2] Shr 1) And
   1))*4;
  Header.SideSize:=0;
 End;
 If (Header.FrameSize > MaxFrame) Or (Header.FrameSize <= Header.SideOffset +
 Header.SideSize) Then  Fail('Taille de trame MP3 incorrecte.');
End;

Procedure CheckCRC;
Var
 CRC, Expected: Word;
 I, J, Feedback: Integer;
Begin
 If Not Header.Protected Then Exit;
 CRC := $FFFF; Expected := Word(Frame[4]) Shl 8 Or Frame[5];
 For I := 2 To Header.SideOffset + Header.SideSize - 1 Do If (I < 4) Or (I >= 6)
  Then
 For J := 7 Downto 0 Do Begin
  Feedback := ((CRC Shr 15) Xor (Frame[I] Shr J)) And 1;
  CRC := (LongInt(CRC) Shl 1) And $FFFF;
  If Feedback <> 0 Then CRC := CRC Xor $8005;
 End;
 If CRC <> Expected Then Fail('CRC MP3 incorrect.');
End;

Procedure ReadSideInfo(Var Back: Integer);
Var
 B: TBits;
 G, C, I, Dummy: Integer;
Begin
 FillChar(D^.G, SizeOf(D^.G), 0); FillChar(D^.SCFSI, SizeOf(D^.SCFSI), 0);
 StartBits(B, @Frame, Header.SideOffset * 8, (Header.SideOffset +
  Header.SideSize) * 8);
 If Header.Version = 3 Then Begin
  Back := ReadBits(B, 9);
  If Header.Channels = 1 Then Dummy := ReadBits(B, 5) Else Dummy := ReadBits(B,
   3);
  For C := 0 To Header.Channels - 1 Do
  For I := 0 To 3 Do D^.SCFSI[C,I] := ReadBits(B, 1);
 End Else
 Begin
  Back := ReadBits(B, 8); Dummy := ReadBits(B, Header.Channels);
 End;
 For G := 0 To Header.Granules - 1 Do
 For C := 0 To Header.Channels - 1 Do With D^.G[G,C] Do Begin
  PartLength := ReadBits(B, 12); BigValues := ReadBits(B, 9); Gain := ReadBits(
   B, 8);
  If BigValues > 288 Then Fail('Nombre de valeurs Huffman invalide.');
  If Header.Version = 3 Then Compress := ReadBits(B, 4) Else Compress :=
   ReadBits(B, 9);
  LongBands := 22; Bands := LongWidths[Header.BandIndex];
  If ReadBits(B, 1) <> 0 Then Begin
   BlockType := ReadBits(B, 2); Mixed := ReadBits(B, 1);
   If BlockType = 0 Then Fail('Type de bloc MP3 invalide.');
   Region0 := 7; Region1 := 255;
   For I := 0 To 1 Do Tables[I] := ReadBits(B, 5);
   For I := 0 To 2 Do SubGain[I] := ReadBits(B, 3);
   If BlockType = 2 Then Begin
    If Mixed = 0 Then Begin
     Region0 := 8; LongBands := 0; ShortBands := 39;
     Bands := ShortWidths[Header.BandIndex];
    End Else
    Begin
     LongBands := 6; If Header.Version = 3 Then LongBands := 8;
     ShortBands := 30; Bands := MixedWidths[Header.BandIndex];
     If Header.Rate = 8000 Then Fail(
      'Blocs mixtes MPEG-2.5 a 8 kHz non pris en charge.');
    End;
   End;
  End Else
  Begin
   For I := 0 To 2 Do Tables[I] := ReadBits(B, 5);
   Region0 := ReadBits(B, 4); Region1 := ReadBits(B, 3);
   If Region0 + Region1 > 20 Then Fail('Regions Huffman invalides.');
  End;
  If Header.Version = 3 Then PreFlag := ReadBits(B, 1) Else
  If Compress >= 500 Then PreFlag := 1;
  Scale := ReadBits(B, 1); CountTable := ReadBits(B, 1);
  For I := 0 To 2 Do If (Tables[I] = 4) Or (Tables[I] = 14) Then Fail(
  'Table Huffman reservee.');
 End;
 If B.Failed Then Fail('Informations laterales tronquees.');
End;

Procedure ReadFactors(Var B: TBits; G, C: Integer);
Const
 Decode: Array[0..15] Of Byte = (0,1,2,3,12,5,6,7,9,10,11,13,14,15,18,19);
 Mods: Array[0..23] Of Byte = (5,5,4,4,5,5,4,1,4,3,1,1,5,6,6,1,4,4,4,1,4,3,1,1);
Var
 Widths: Array[0..3] Of Integer;
 I, J, K, Kind, Product, Value, Index, Partition, N, IntensityChannel: Integer;
Begin
 With D^.G[G,C] Do Begin
  Kind := 0; If ShortBands > 0 Then Begin
   Kind := 1; If LongBands = 0 Then Kind := 2;
  End;
  Partition := 0;
  If Header.Version = 3 Then Begin
   Value := Decode[Compress]; Widths[0] := Value Shr 2; Widths[1] := Widths[0];
   Widths[2] := Value And 3; Widths[3] := Widths[2];
  End Else
  Begin
   IntensityChannel := 0;
   If (Header.Mode = 1) And Odd(Header.Extension) And (C = 1) Then
    IntensityChannel := 1;
   Value := Compress Shr IntensityChannel; K := IntensityChannel * 12;
   Repeat
   If K > 20 Then Fail('Facteurs MPEG-2 invalides.');
   Product := 1;
   For I := 3 Downto 0 Do Begin
    Widths[I] := (Value Div Product) Mod Mods[K + I]; Product := Product * Mods[
     K + I];
   End;
   Dec(Value, Product); Inc(K, 4);
   Until Value < 0;
   Partition := K;
  End;
  Index := 0;
  For I := 0 To 3 Do Begin
   N := FactorPartitions[Kind, Partition + I];
   For J := 1 To N Do Begin
    If (Header.Version = 3) And (G = 1) And (ShortBands = 0) And (D^.SCFSI[C,I]
     <> 0)
    Then     Value := D^.G[0,C].Factors[Index]
    Else Value := ReadBits(B, Widths[I]);
    Factors[Index] := Value; Intensity[Index] := Value;
    If (Header.Version <> 3) And (Widths[I] > 0) And (Value = (1 Shl Widths[I])
     - 1)
    Then Intensity[Index] := 255;
    Inc(Index);
   End;
  End;
 End;
 If B.Failed Then Fail('Facteurs d''echelle tronques.');
End;

Function HuffLeaf(Var B: TBits; Table: Integer): Integer;
Var
 Point, Offset, Direction, Steps: Integer;
 Value: Word;
Begin
 HuffLeaf := 0; If Table = 0 Then Exit;
 Point := 0; Steps := 0;
 While Not B.Failed Do Begin
  If (Point < 0) Or (Point >= HuffLength[Table]) Or (Steps > 32) Then Begin
   B.Failed := True; Exit;
  End;
  Value := HuffTree[HuffOffset[Table] + Point];
  If Value < 256 Then Begin
   HuffLeaf := Value; Exit;
  End;
  Direction := ReadBits(B, 1);
  Repeat
  Value := HuffTree[HuffOffset[Table] + Point];
  If Direction = 0 Then Offset := Value Shr 8 Else Offset := Value And 255;
  Inc(Point, Offset);
  If Point >= HuffLength[Table] Then Begin
   B.Failed := True; Exit;
  End;
  Until Offset < 250;
  Inc(Steps);
 End;
End;

Function SignedValue(Var B: TBits; Value, Extra: Integer): Integer;Begin
 If (Value = 15) And (Extra > 0) Then Inc(Value, ReadBits(B, Extra));
 If Value <> 0 Then If ReadBits(B, 1) <> 0 Then Value := -Value;
 SignedValue := Value;
End;

Procedure ReadHuffman(Var B: TBits; G, C: Integer);
Var
 I, J, P, R1, R2, Table, Leaf, X, Y, Start: Integer;
 Quad: Array[0..3] Of Integer;
Begin
 With D^.G[G,C] Do Begin
  R1 := 0; R2 := 0;
  For I := 0 To LongBands + ShortBands - 1 Do Begin
   If I <= Region0 Then Inc(R1, Bands[I]);
   If I <= Region0 + Region1 + 1 Then Inc(R2, Bands[I]);
  End;
  P := 0;
  For I := 1 To BigValues Do Begin
   If P < R1 Then Table := Tables[0] Else If P < R2 Then Table := Tables[1] Else
    Table :=
   Tables[2];
   Leaf := HuffLeaf(B, Table);
   X := SignedValue(B, Leaf Shr 4, HuffLinBits[Table]);
   Y := SignedValue(B, Leaf And 15, HuffLinBits[Table]);
   If B.Failed Then Fail('Donnees Huffman tronquees ou invalides.');
   D^.X[C,P] := X; D^.X[C,P + 1] := Y; Inc(P, 2);
  End;
  While (P <= 572) And (B.Position < B.Limit) Do Begin
   Start := B.Position; Leaf := HuffLeaf(B, 32 + CountTable);
   For J := 0 To 3 Do Quad[J] := SignedValue(B, (Leaf Shr (3 - J)) And 1, 0);
   If B.Failed Then Begin
    B.Failed := False; B.Position := B.Limit;
   End
    Else
   Begin
    For J := 0 To 3 Do D^.X[C,P + J] := Quad[J]; Inc(P, 4);
    If B.Position <= Start Then Fail('Huffman sans progression.');
   End;
  End;
  For I := P To 575 Do D^.X[C,I] := 0;
 End;
 B.Position := B.Limit;
End;

Procedure Requantize(G, C: Integer);
Const
 Pre: Array[0..21] Of Byte = (0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,2,2,3,3,3,2,0);
Var
 I, J, P, Factor, Exponent: Integer;
 V, GainValue: Double;
Begin
 P := 0;
 With D^.G[G,C] Do
 For I := 0 To LongBands + ShortBands - 1 Do Begin
  Factor := Factors[I];
  If ShortBands = 0 Then Inc(Factor, PreFlag * Pre[I]);
  Exponent := Gain - 210 - (Factor Shl (Scale + 1));
  If I >= LongBands Then Dec(Exponent, 8 * SubGain[(I - LongBands) Mod 3]);
  GainValue := Exp(Exponent * (Ln(2) / 4));
  For J := 1 To Bands[I] Do Begin
   V := D^.X[C,P];
   If V <> 0 Then Begin
    If V > 0 Then V := Exp(Ln(V) * (4 / 3)) * GainValue
             Else V := -Exp(Ln(-V) * (4 / 3)) * GainValue;
    D^.X[C,P] := V;
   End;
   Inc(P);
  End;
 End;
 If P <> 576 Then Fail('Bandes frequentielles incoherentes.');
End;

Procedure Stereo(G: Integer);
Const
 Pan: Array[0..6] Of Double = (0,0.211324865405187,0.366025403784439,0.5,
 0.633974596215561,0.788675134594813,1);
Var
 Top: Array[0..2] Of Integer;
 I, J, P, N, Blocks, Position, Previous, Maximum: Integer;
 IStereo, MStereo, UseIntensity: Boolean;
 Left, Right, KL, KR: Double;
Begin
 If (Header.Channels <> 2) Or (Header.Mode <> 1) Then Exit;
 IStereo := Odd(Header.Extension); MStereo := (Header.Extension And 2) <> 0;
 If Not IStereo And Not MStereo Then Exit;
 If IStereo Then Begin
  If (D^.G[G,0].LongBands <> D^.G[G,1].LongBands) Or
  (D^.G[G,0].ShortBands <> D^.G[G,1].ShortBands) Then Fail(
  'Blocs stereo intensite incompatibles.');
  With D^.G[G,1] Do Begin
   For I := 0 To 2 Do Top[I] := -1;
   P := 0; N := LongBands + ShortBands;
   For I := 0 To N - 1 Do Begin
    For J := 0 To Bands[I] - 1 Do If D^.X[1,P + J] <> 0 Then Top[I Mod 3] := I;
    Inc(P, Bands[I]);
   End;
   If LongBands <> 0 Then Begin
    Maximum := Top[0];
    For I := 1 To 2 Do If Top[I] > Maximum Then Maximum := Top[I];
    For I := 0 To 2 Do Top[I] := Maximum;
   End;
   Blocks := 1; If ShortBands <> 0 Then Blocks := 3;
   For I := 0 To Blocks - 1 Do Begin
    Position := N - Blocks + I; Previous := Position - Blocks;
    If Top[I] >= Previous Then Begin
     Intensity[Position] := 0; If Header.Version = 3 Then Intensity[Position] :=
      3;
    End Else Intensity[Position] := Intensity[Previous];
   End;
  End;
 End;
 P := 0;
 With D^.G[G,1] Do
 For I := 0 To LongBands + ShortBands - 1 Do Begin
  Position := Intensity[I]; UseIntensity := False;
  If IStereo Then Begin
   UseIntensity := (I > Top[I Mod 3]);
   If Header.Version = 3 Then UseIntensity := UseIntensity And (Position < 7)
                         Else UseIntensity := UseIntensity And (Position < 64);
  End;
  If UseIntensity Then Begin
   If Header.Version = 3 Then Begin
    KL := Pan[Position]; KR := 1 - KL;
   End
    Else
   Begin
    KL := 1; KR := Exp(-Ln(2) * (((Position + 1) Div 2) Shl (Compress And 1)) /
     4);
    If Odd(Position) Then Begin
     KL := KR; KR := 1;
    End;
   End;
   For J := 0 To Bands[I] - 1 Do Begin
    Left := D^.X[0,P + J]; D^.X[0,P + J] := Left * KL; D^.X[1,P + J] := Left *
     KR;
   End;
  End Else If MStereo Then
  For J := 0 To Bands[I] - 1 Do Begin
   Left := D^.X[0,P + J]; Right := D^.X[1,P + J];
   D^.X[0,P + J] := (Left + Right) / Sqrt(2); D^.X[1,P + J] := (Left - Right) /
    Sqrt(2);
  End;
  Inc(P, Bands[I]);
 End;
End;

Procedure Reorder(G, C: Integer);
Var
 I, J, W, P, Width: Integer;
Begin
 With D^.G[G,C] Do Begin
  If ShortBands = 0 Then Exit;
  P := 0;
  For I := 0 To LongBands - 1 Do Inc(P, Bands[I]);
  Move(D^.X[C], D^.Scratch, SizeOf(D^.Scratch));
  I := LongBands;
  While I < LongBands + ShortBands Do Begin
   Width := Bands[I];
   For W := 0 To 2 Do
   For J := 0 To Width - 1 Do D^.X[C,P + 3 * J + W] := D^.Scratch[P + W * Width
    + J];
   Inc(P, 3 * Width); Inc(I, 3);
  End;
 End;
End;

Procedure Hybrid(G, C: Integer);
Var
 SB, I, J, W, Block, Boundaries: Integer;
 A, B, Sum: Double;
 OutSamples: Array[0..35] Of Double;
Begin
 Boundaries := 31;
 With D^.G[G,C] Do If BlockType = 2 Then Begin
  Boundaries := 0; If Mixed <> 0 Then Boundaries := 1;
 End;
 For SB := 1 To Boundaries Do
 For I := 0 To 7 Do Begin
  A := D^.X[C,SB * 18 - 1 - I]; B := D^.X[C,SB * 18 + I];
  D^.X[C,SB * 18 - 1 - I] := A * Transform^.CS[I] - B * Transform^.CA[I];
  D^.X[C,SB * 18 + I] := B * Transform^.CS[I] + A * Transform^.CA[I];
 End;
 For SB := 0 To 31 Do Begin
  Block := D^.G[G,C].BlockType;
  If (D^.G[G,C].Mixed <> 0) And (SB < 2) Then Block := 0;
  FillChar(OutSamples, SizeOf(OutSamples), 0);
  If Block = 2 Then Begin
   For W := 0 To 2 Do
   For I := 0 To 11 Do Begin
    Sum := 0;
    For J := 0 To 5 Do Sum := Sum + D^.X[C,SB * 18 + W + 3 * J] *
     Transform^.ShortCos[I,
    J];
    OutSamples[6 * W + I + 6] := OutSamples[6 * W + I + 6] + Sum *
     Transform^.Window[2,I];
   End;
  End Else
  For I := 0 To 35 Do Begin
   Sum := 0;
   For J := 0 To 17 Do Sum := Sum + D^.X[C,SB * 18 + J] * Transform^.LongCos[I,
    J];
   OutSamples[I] := Sum * Transform^.Window[Block,I];
  End;
  For I := 0 To 17 Do Begin
   Sum := OutSamples[I] + D^.Overlap[C,SB,I];
   If Odd(SB) And Odd(I) Then Sum := -Sum;
   D^.X[C,SB * 18 + I] := Sum; D^.Overlap[C,SB,I] := OutSamples[I + 18];
  End;
 End;
End;

Procedure Synthesize(G, C: Integer);
Var
 T, I, J, P, Offset, Slots: Integer;
 Sum: Double;
 Sample: LongInt;
Begin
 Slots:=18; If Header.Layer=3 Then Slots:=12;
 For T := 0 To Slots-1 Do Begin
  For I := 1023 Downto 64 Do D^.V[C,I] := D^.V[C,I - 64];
  For I := 0 To 63 Do Begin
   Sum := 0;
   For J := 0 To 31 Do Sum := Sum + D^.X[C,J * 18 + T] * Transform^.Synthesis[I,
    J];
   D^.V[C,I] := Sum;
  End;
  For I := 0 To 31 Do Begin
   Sum := 0;
   For J := 0 To 15 Do Begin
    Offset := (J Div 2) * 128 + I; If Odd(J) Then Inc(Offset, 96);
    Sum := Sum + D^.V[C,Offset] * SynthWindow[J * 32 + I];
   End;
   Sum := Sum * 32768;
   If Sum > 32767 Then Sample := 32767 Else If Sum < -32768 Then Sample := -
   32768 Else Sample := Round(Sum);
   P := ((G * 576 + T * 32 + I) * Header.Channels + C) * 2;
   D^.PCM[P] := Sample And 255; D^.PCM[P + 1] := (Sample Shr 8) And 255;
  End;
 End;
End;

Procedure InitializeTransforms;
Const
 CI: Array[0..7] Of Double = (-0.6,-0.535,-0.33,-0.185,-0.095,-0.041,-0.0142,-
  0.0037);
Var
 I, J: Integer;
Begin
 FillChar(Transform^, SizeOf(Transform^), 0);
 For I := 0 To 7 Do Begin
  Transform^.CS[I] := 1 / Sqrt(1 + Sqr(CI[I]));
  Transform^.CA[I] := CI[I] * Transform^.CS[I];
 End;
 For I := 0 To 63 Do
 For J := 0 To 31 Do Transform^.Synthesis[I,J] := Cos((16 + I) * (2 * J + 1) * (
  MP3Pi /
 64));
 For I := 0 To 35 Do
 For J := 0 To 17 Do Transform^.LongCos[I,J] := Cos((2 * I + 19) * (2 * J + 1) *
  (MP3Pi /
 72));
 For I := 0 To 11 Do
 For J := 0 To 5 Do Transform^.ShortCos[I,J] := Cos((2 * I + 7) * (2 * J + 1) *
  (MP3Pi /
 24));
 For I := 0 To 35 Do Transform^.Window[0,I] := Sin(MP3Pi / 36 * (I + 0.5));
 For I := 0 To 17 Do Transform^.Window[1,I] := Transform^.Window[0,I];
 For I := 18 To 23 Do Transform^.Window[1,I] := 1;
 For I := 24 To 29 Do Transform^.Window[1,I] := Sin(MP3Pi / 12 * (I - 17.5));
 For I := 0 To 11 Do Transform^.Window[2,I] := Sin(MP3Pi / 12 * (I + 0.5));
 For I := 6 To 11 Do Transform^.Window[3,I] := Sin(MP3Pi / 12 * (I - 5.5));
 For I := 12 To 17 Do Transform^.Window[3,I] := 1;
 For I := 18 To 35 Do Transform^.Window[3,I] := Transform^.Window[0,I];
End;
{ Layer I subband allocation, inverse quantization and shared synthesis. }

Procedure DecodeLayerI;
Var
 B: TBits;
 Alloc,SF: Array[0..1,0..31] Of Integer;
 Factors: Array[0..63] Of Double;
 Bound,C,SB,T,N,Value,I,Feedback,Count: Integer;
 CRC,Expected: Word;
 Sample: Double;
Begin
 FillChar(Alloc,SizeOf(Alloc),0); FillChar(SF,SizeOf(SF),0);
 StartBits(B,@Frame,Header.SideOffset*8,Header.FrameSize*8);
 Bound:=32; If Header.Mode=1 Then Bound:=(Header.Extension+1)*4;
 For SB:=0 To 31 Do Begin
  For C:=0 To Header.Channels-1 Do Begin
   If (SB>=Bound) And (C=1) Then Alloc[C,SB]:=Alloc[0,SB]
                            Else Alloc[C,SB]:=ReadBits(B,4);
   If Alloc[C,SB]=15 Then Fail('MP1: allocation de bits reservee.');
  End;
 End;
 If B.Failed Then Fail('MP1: allocations tronquees.');
 If Header.Protected Then Begin
  CRC:=$FFFF; Expected:=Word(Frame[4])*256+Frame[5];
  For I:=16 To B.Position-1 Do If (I<32) Or (I>=48) Then Begin
   Feedback:=((CRC Shr 15) Xor (Frame[I Div 8] Shr (7-I Mod 8))) And 1;
   CRC:=(LongInt(CRC)*2) And $FFFF; If Feedback<>0 Then CRC:=CRC Xor $8005;
  End;
  If CRC<>Expected Then Fail('MP1: CRC incorrect.');
 End;
 For I:=0 To 63 Do Factors[I]:=2*Exp(-I*Ln(2)/3);
 For SB:=0 To 31 Do
 For C:=0 To Header.Channels-1 Do  If Alloc[C,SB]<>0 Then SF[C,SB]:=ReadBits(B,
  6);
 For T:=0 To 11 Do
 For SB:=0 To 31 Do Begin
  Value:=0;
  For C:=0 To Header.Channels-1 Do Begin
   N:=Alloc[C,SB]; Sample:=0;
   If N<>0 Then Begin
    Inc(N);
    If (C=0) Or (SB<Bound) Then Value:=ReadBits(B,N);
    Sample:=(2.0*Value+2-(LongInt(1) Shl N))/((LongInt(1) Shl N)-1)*Factors[SF[
     C,SB]];
   End;
   D^.X[C,SB*18+T]:=Sample;
  End;
 End;
 If B.Failed Then Fail('MP1: echantillons tronques.');
 For C:=0 To Header.Channels-1 Do Synthesize(0,C);
 Count:=384*Header.Channels*2;
 If Written>MaxWaveData-Count Then Fail('Sortie WAV depassant 2 Go.');
 WriteBytes(D^.PCM,Count); Inc(Written,Count);
End;

Procedure DecodeFrame;
Var
 Back, Offset, Count, Keep, OldSize, G, C, Limit, WholeLimit: Integer;
 B: TBits;
Begin
 If Header.Layer=3 Then Begin
  DecodeLayerI; Exit;
 End;
 CheckCRC; ReadSideInfo(Back);
 If Back > D^.ReservoirSize Then Fail(
  'Reservoir MP3 incomplet; debut de flux manquant.');
 Offset := Header.SideOffset + Header.SideSize; Count := Header.FrameSize -
  Offset;
 OldSize := D^.ReservoirSize;
 If OldSize > 0 Then Move(D^.Reservoir[0], D^.Main[0], OldSize);
 Move(Frame[Offset], D^.Main[OldSize], Count);
 Keep := OldSize + Count; If Keep > 511 Then Keep := 511;
 Move(D^.Main[OldSize + Count - Keep], D^.Reservoir[0], Keep); D^.ReservoirSize
  := Keep;
 WholeLimit := (OldSize + Count) * 8;
 StartBits(B, @D^.Main, (OldSize - Back) * 8, WholeLimit);
 For G := 0 To Header.Granules - 1 Do Begin
  For C := 0 To Header.Channels - 1 Do Begin
   Limit := B.Position + D^.G[G,C].PartLength;
   If Limit > WholeLimit Then Fail('Donnees principales MP3 tronquees.');
   B.Limit := Limit; ReadFactors(B, G, C); ReadHuffman(B, G, C); Requantize(G,
    C);
  End;
  Stereo(G);
  For C := 0 To Header.Channels - 1 Do Begin
   Reorder(G, C); Hybrid(G, C); Synthesize(G, C);
  End;
 End;
 Count := Header.Granules * 576 * Header.Channels * 2;
 If Written > MaxWaveData - Count Then Fail(
  'Sortie WAV depassant la limite de 2 Go.');
 WriteBytes(D^.PCM, Count); Inc(Written, Count);
End;

Procedure SkipTags;
Var
 I: Integer;
 TagSize: LongInt;
Begin
 InputPosition := 0; InputEnd := InputSize;
 While InputEnd - InputPosition >= 10 Do Begin
  ReadAt(InputPosition, Frame, 10);
  If (Frame[0] <> Ord('I')) Or (Frame[1] <> Ord('D')) Or (Frame[2] <> Ord('3'))
   Then Exit;
  If (Frame[3] < 2) Or (Frame[3] > 4) Or (Frame[4] = 255) Then Fail(
  'Version ID3v2 invalide.');
  TagSize := 0;
  For I := 6 To 9 Do Begin
   If Frame[I] > 127 Then Fail('Taille ID3v2 invalide.');
   TagSize := TagSize * 128 + Frame[I];
  End;
  Inc(TagSize, 10);
  If (Frame[3] = 4) And ((Frame[5] And $10) <> 0) Then Inc(TagSize, 10);
  If TagSize > InputEnd - InputPosition Then Fail('Etiquette ID3v2 tronquee.');
  Inc(InputPosition, TagSize);
 End;
End;

Procedure RemoveTrailingTags;
Var
 Size: LongInt;
 I: Integer;
Begin
 If InputEnd >= 128 Then Begin
  ReadAt(InputEnd - 128, Frame, 3);
  If (Frame[0] = Ord('T')) And (Frame[1] = Ord('A')) And (Frame[2] = Ord('G'))
   Then Dec(
  InputEnd, 128);
 End;
 If InputEnd >= 32 Then Begin
  ReadAt(InputEnd - 32, Frame, 32);
  If (Frame[0] = Ord('A')) And (Frame[1] = Ord('P')) And (Frame[2] = Ord('E'))
   And
  (Frame[3] = Ord('T')) And (Frame[4] = Ord('A')) And (Frame[5] = Ord('G')) And
   (
  Frame[6] = Ord('E')) And (Frame[7] = Ord('X')) Then Begin
   If Frame[15] >= 128 Then Fail('Taille APE invalide.');
   Size := 0;
   For I := 15 Downto 12 Do Size := Size * 256 + Frame[I];
   If (Size < 32) Or (Size > InputEnd) Then Fail('Etiquette APE tronquee.');
   Dec(InputEnd, Size);
   If (Frame[23] And $80) <> 0 Then Begin
    If InputEnd < 32 Then Fail('Entete APE tronquee.');
    Dec(InputEnd, 32);
   End;
  End;
 End;
 If InputPosition >= InputEnd Then Fail('Aucune trame audio MP3.');
End;

Function ReadNextFrame: Boolean;
Var
 Remaining: LongInt;
Begin
 ReadNextFrame := False;
 Remaining := InputEnd - InputPosition;
 If Remaining < 4 Then Begin
  ReadAt(InputPosition, Frame, Remaining);
  If Frame[0] <> 255 Then Fail(
   'Donnees inattendues apres la derniere trame MP3.');
  If Remaining >= 2 Then   If (Frame[1] And $E0) <> $E0 Then Fail(
  'Synchronisation MP3 incorrecte.');
 End Else
 Begin
  ReadAt(InputPosition, Frame, 4); ParseHeader;
  If Frames > 0 Then   If (Header.Rate <> FirstHeader.Rate) Or (Header.Channels
   <>
  FirstHeader.Channels) Or
  (Header.Version <> FirstHeader.Version) Or (Header.Layer<>FirstHeader.Layer)
   Then Fail(
  'Changement de format au milieu du MP3.');
  If Header.FrameSize <= Remaining Then Begin
   ReadAt(InputPosition, Frame, Header.FrameSize);
   ReadNextFrame := True; Exit;
  End;
 End;
 If (Frames>0) And (FirstHeader.Layer=3) Then Fail(
  'MP1: derniere trame tronquee.');
 If Frames = 0 Then Fail('Derniere trame MP3 tronquee; aucune trame complete.');
 WriteLn(EngOut,'MP32WAV: avertissement: derniere trame MP3 incomplete ignoree (',
 Remaining, ' octets restants). Les ', Frames,
  ' trames completes sont conservees.');
End;

Procedure Convert;
Var
 ErrorCode: Integer;
 OldMode: Byte;
Begin
 If Exists(OutputName) Then Fail('Le fichier de sortie existe deja: ' +
  OutputName);
 Assign(InputFile, InputName); OldMode := FileMode; FileMode := 0;
 {$I-}Reset(InputFile, 1); ErrorCode := IOResult;{$I+}
 FileMode := OldMode;
 If ErrorCode <> 0 Then Fail('Ouverture MP3 impossible: ' + InputName);
 InputOpen := True;
 {$I-}
 If FileSize(InputFile) > 2147483647 Then InputSize := -1
                                     Else InputSize := FileSize(InputFile);
 ErrorCode := IOResult;
 {$I+}
 If (ErrorCode <> 0) Or (InputSize < 4) Then Fail(
 'Fichier MP3 vide, trop grand ou illisible.');
 New(D); New(Transform); FillChar(D^, SizeOf(D^), 0); InitializeTransforms;
 SkipTags; RemoveTrailingTags;
 While InputPosition < InputEnd Do Begin
  If ReadNextFrame Then Begin
   If Frames = 0 Then Begin
    FirstHeader := Header;
    Assign(OutputFile, OutputName);
   {$I-}Rewrite(OutputFile, 1); ErrorCode := IOResult;{$I+}
    If ErrorCode <> 0 Then Fail('Creation WAV impossible: ' + OutputName);
    OutputOpen := True; OutputCreated := True; WriteWaveHeader;
   End;
   DecodeFrame; Inc(Frames); Inc(InputPosition, Header.FrameSize); EngTick(InputPosition,InputEnd);
  End Else InputPosition := InputEnd;
 End;
 If Frames = 0 Then Fail('Aucune trame audio MP3.');
 WriteWaveHeader;
 {$I-}Close(OutputFile); ErrorCode := IOResult;{$I+}
 OutputOpen := False;
 If ErrorCode <> 0 Then Fail('Fermeture WAV impossible.');
 {$I-}Close(InputFile); ErrorCode := IOResult;{$I+}
 InputOpen := False;
 If ErrorCode <> 0 Then Fail('Fermeture MP3 impossible.');
 Dispose(Transform); Dispose(D);
 WriteLn(EngOut,'WAV cree: ', OutputName);
 WriteLn(EngOut,FirstHeader.Rate, ' Hz, ', FirstHeader.Channels,
  ' canal/canaux, PCM 16 bits, ',
 Written, ' octets audio.');
End;
Begin
 InputName := Source; OutputName := Target; InputOpen := False; OutputOpen :=
  False;
 OutputCreated := False; Written := 0; Frames := 0;
 Convert;
End;
{ Moteur integre depuis AIFF2WAV.PAS }

Procedure DecodeAIFF(Const Source,Target: String);
Type
 TAudioFormat = Record
  Channels: Integer;
  Rate: LongInt;
 End;
Var
 InputFile, OutputFile: File;
 InputName, OutputName: String;
 InputOpen, OutputOpen, OutputCreated: Boolean;
 InputSize: LongInt;
 Header: TAudioFormat;

Procedure Cleanup;
Var
 Code: Integer;
Begin
 If InputOpen Then Begin
  {$I-}Close(InputFile); Code := IOResult;{$I+} InputOpen := False;
 End;
 If OutputOpen Then Begin
  {$I-}Close(OutputFile); Code := IOResult;{$I+} OutputOpen := False;
 End;
 If OutputCreated Then Begin
  {$I-}Erase(OutputFile); Code := IOResult;{$I+}
  If Code <> 0 Then WriteLn(EngOut,'Fichier incomplet a supprimer: ', OutputName);
  OutputCreated := False;
 End;
End;

Procedure Fail(MessageText: String);Begin
 EngMsg:=MessageText; Cleanup; EngAbort;
End;

Function Exists(Name: String): Boolean;
Var
 F: File;
 Attributes: Word;
Begin
 Assign(F, Name); GetFAttr(F, Attributes); Exists := DosError = 0;
End;

Function DefaultOutput(Name: String): String;
Var
 I: Integer;
Begin
 I := Length(Name);
 While (I > 0) And Not (Name[I] In ['.', '/', '\', ':']) Do Dec(I);
 If (I > 0) And (Name[I] = '.') Then Name := Copy(Name, 1, I - 1);
 If Length(Name) > 251 Then Fail('Nom de sortie trop long.');
 DefaultOutput := Name + '.wav';
End;

Procedure Help;Begin
 WriteLn(EngOut,
 'AIFF2WAV - Cette commande permet de lancer le convertisseur AIFF/AIFF-C PCM '+
  'vers WAV PCM.');
 WriteLn(EngOut);
 WriteLn(EngOut,'Syntaxe: AIFF2WAV entree.aiff [sortie.wav]');
 WriteLn(EngOut);
 WriteLn(EngOut,'AIFF/AIFF-C NONE ou sowt -> WAV PCM, mono/stereo, 8/16/24/32 bits.');
 WriteLn(EngOut,'Sans sortie explicite: meme chemin avec extension .wav.');
 WriteLn(EngOut,'Resolution et canaux conserves; frequence arrondie au hertz.');
 WriteLn(EngOut,'4000..192000 Hz, fichiers < 2 Go. Sortie existante refusee.');
 WriteLn(EngOut,'Aide: /? ou --help');
End;

Procedure ReadAt(Position: LongInt; Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 If (Position < 0) Or (Position > InputSize) Then Fail(
  'Position AIFF incorrecte.');
 If Count > InputSize - Position Then Fail('Fichier AIFF tronque.');
 {$I-}Seek(InputFile, Position); ErrorCode := IOResult;{$I+}
 If ErrorCode <> 0 Then Fail('Positionnement AIFF impossible.');
 {$I-}BlockRead(InputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Lecture AIFF incomplete.');
End;

Procedure WriteBytes(Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 {$I-}BlockWrite(OutputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Ecriture WAV incomplete.')
 ;
End;

Procedure Put16(Value: Word);
Var
 B: Array[0..1] Of Byte;
Begin
 B[0] := Value And 255; B[1] := Value Shr 8; WriteBytes(B,2);
End;

Procedure Put32(Value: LongInt);
Var
 B: Array[0..3] Of Byte;
 J: Integer;
Begin
 For J := 0 To 3 Do Begin
  B[J] := Value And 255; Value := Value Shr 8;
 End;
 WriteBytes(B,4);
End;

Procedure WriteWaveHeader(DataSize: LongInt; Bits: Integer);
Var
 Tag: String[4];
 Align: Word;
 RiffSize: LongInt;
Begin
 Align := Header.Channels*(Bits Div 8);
 RiffSize := DataSize+36; If Odd(DataSize) Then Inc(RiffSize);
 Tag := 'RIFF'; WriteBytes(Tag[1],4); Put32(RiffSize);
 Tag := 'WAVE'; WriteBytes(Tag[1],4);
 Tag := 'fmt '; WriteBytes(Tag[1],4); Put32(16); Put16(1);
 Put16(Header.Channels); Put32(Header.Rate); Put32(Header.Rate*Align);
 Put16(Align); Put16(Bits);
 Tag := 'data'; WriteBytes(Tag[1],4); Put32(DataSize);
End;

Type
 THeaderBytes = Array[0..63] Of Byte;

Function BE16(Const B: THeaderBytes; Offset: Integer): Word;Begin
 BE16 := Word(B[Offset])*256+B[Offset+1];
End;

Function BE32(Const B: THeaderBytes; Offset: Integer): LongInt;Begin
 If B[Offset] >= 128 Then Fail('Valeur AIFF depassant 2 Go.');
 BE32 := LongInt(B[Offset])*16777216+LongInt(B[Offset+1])*65536+
 LongInt(B[Offset+2])*256+B[Offset+3];
End;

Function TagIs(Const B: THeaderBytes; Offset: Integer; Const Tag: String):
 Boolean;
Var
 J: Integer;
 Equal: Boolean;
Begin
 Equal := True;
 For J := 1 To 4 Do If B[Offset+J-1] <> Ord(Tag[J]) Then Equal := False;
 TagIs := Equal;
End;

Function ReadRate(Const B: THeaderBytes): LongInt;
Var
 Exponent, J: Integer;
 Value: Double;
Begin
 { COMM[8..17]: reel IEEE 80 bits big-endian, mantisse explicite.
   Decoder les octets evite une dependance au format Extended du compilateur. }
 If (B[8] And $80) <> 0 Then Fail('Frequence AIFF negative.');
 Exponent := BE16(B,8);
 If (Exponent < 16383+11) Or (Exponent > 16383+17) Or ((B[10] And $80) = 0) Then
  Fail(
 'Frequence AIFF invalide (4000..192000 Hz attendus).');
 Dec(Exponent,16383);
 Value := 0;
 For J := 17 Downto 10 Do Value := (Value+B[J])/256;
 Value := Value*2;
 For J := 1 To Exponent Do Value := Value*2;
 If (Value < 4000) Or (Value > 192000) Then Fail(
  'Frequence AIFF hors limites.');
 ReadRate := Round(Value);
End;

Procedure Convert;
Var
 B: THeaderBytes;
 Raw: Array[0..4095] Of Byte;
 Position, FormEnd, ChunkSize, DataStart, DataSize, FrameCount, Offset,
 Remaining, CountFrames: LongInt;
 Bits, BlockAlign, BytesPerSample, Code, J, K, C, OutCount: Integer;
 Value: LongInt;
 OldMode: Byte;
 HasFormat, HasData, HasVersion, CompressedForm, LittleEndian: Boolean;
Begin
 Assign(InputFile, InputName); OldMode := FileMode; FileMode := 0;
 {$I-}Reset(InputFile,1); Code := IOResult;{$I+}
 FileMode := OldMode;
 If Code <> 0 Then Fail('Ouverture AIFF impossible: '+InputName);
 InputOpen := True;
 {$I-}InputSize := FileSize(InputFile); Code := IOResult;{$I+}
 If (Code <> 0) Or (InputSize < 12) Then Fail(
  'AIFF vide, trop grand ou tronque.');
 ReadAt(0,B,12);
 If Not TagIs(B,0,'FORM') Then Fail('Signature FORM manquante.');
 CompressedForm := TagIs(B,8,'AIFC');
 If Not CompressedForm And Not TagIs(B,8,'AIFF') Then Fail(
  'Format AIFF ou AIFC requis.');
 FormEnd := BE32(B,4);
 If (FormEnd < 4) Or (FormEnd > InputSize-8) Then Fail(
  'Taille FORM incorrecte.');
 Inc(FormEnd,8); Position := 12;
 HasFormat := False; HasData := False; HasVersion := False; LittleEndian :=
  False;
 DataStart := 0; DataSize := 0; FrameCount := 0; Bits := 0;
 While Position < FormEnd Do Begin
  If FormEnd-Position < 8 Then Fail('Entete de bloc AIFF tronquee.');
  ReadAt(Position,B,8); ChunkSize := BE32(B,4); Inc(Position,8);
  If ChunkSize > FormEnd-Position Then Fail('Bloc AIFF tronque.');
  If TagIs(B,0,'COMM') Then Begin
   If HasFormat Then Fail('Plusieurs blocs COMM non pris en charge.');
   If ChunkSize < 18 Then Fail('Bloc COMM trop court.');
   ReadAt(Position,B,18);
   Header.Channels := BE16(B,0); FrameCount := BE32(B,2); Bits := BE16(B,6);
   Header.Rate := ReadRate(B);
   If Not (Header.Channels In [1,2]) Then Fail('AIFF mono ou stereo requis.');
   If Not (Bits In [8,16,24,32]) Then Fail(
    'PCM AIFF attendu: 8/16/24/32 bits.');
   If CompressedForm Then Begin
    If ChunkSize < 24 Then Fail('Bloc COMM AIFC trop court.');
    ReadAt(Position+18,B,5);
    LittleEndian := TagIs(B,0,'sowt');
    If Not LittleEndian And Not TagIs(B,0,'NONE') Then Fail(
    'Codec AIFC non pris en charge: NONE ou sowt requis.');
    If 23+Word(B[4])+((1+Word(B[4])) Mod 2) > ChunkSize Then Fail(
    'Nom de compression AIFC tronque.');
   End;
   HasFormat := True;
  End
  Else If TagIs(B,0,'SSND') Then Begin
   If HasData Then Fail('Plusieurs blocs SSND non pris en charge.');
   If ChunkSize < 8 Then Fail('Bloc SSND trop court.');
   ReadAt(Position,B,8); Offset := BE32(B,0);
   If Offset > ChunkSize-8 Then Fail('Offset SSND hors du bloc.');
   { blockSize indique l'alignement physique; les trames restent contigues. }
   DataStart := Position+8+Offset; DataSize := ChunkSize-8-Offset; HasData :=
    True;
  End
  Else If TagIs(B,0,'FVER') And CompressedForm Then Begin
   If HasVersion Or (ChunkSize <> 4) Then Fail('Bloc FVER incorrect.');
   ReadAt(Position,B,4);
   If (B[0] <> $A2) Or (B[1] <> $80) Or (B[2] <> $51) Or (B[3] <> $40) Then
    Fail(
   'Version AIFC non prise en charge.');
   HasVersion := True;
  End;
  Inc(Position,ChunkSize);
  If Odd(ChunkSize) Then Begin
   If Position >= FormEnd Then Fail('Octet de bourrage AIFF manquant.');
   Inc(Position);
  End;
 End;
 If Not HasFormat Or Not HasData Then Fail('Bloc COMM ou SSND manquant.');
 If CompressedForm And Not HasVersion Then Fail('Bloc FVER AIFC manquant.');
 BytesPerSample := Bits Div 8; BlockAlign := Header.Channels*BytesPerSample;
 If (FrameCount = 0) Or (FrameCount > DataSize Div BlockAlign) Then Fail(
 'Trames AIFF vides ou tronquees.');
 Remaining := FrameCount*BlockAlign; Position := DataStart;
 If Remaining > 2147483600 Then Fail('Sortie WAV depassant 2 Go.');
 { Creer la sortie seulement apres validation de tous les blocs AIFF. }
 If Exists(OutputName) Then Fail('Le fichier de sortie existe deja: '+
  OutputName);
 Assign(OutputFile,OutputName);
 {$I-}Rewrite(OutputFile,1); Code := IOResult;{$I+}
 If Code <> 0 Then Fail('Creation WAV impossible: '+OutputName);
 OutputOpen := True; OutputCreated := True;
 WriteWaveHeader(Remaining,Bits);
 While Remaining > 0 Do Begin
  CountFrames := Remaining Div BlockAlign;
  If CountFrames > 512 Then CountFrames := 512;
  OutCount := CountFrames*BlockAlign;
  ReadAt(Position,Raw,OutCount);
  If Bits = 8 Then
  For J := 0 To OutCount-1 Do Raw[J] := Raw[J] Xor $80
  Else If Not LittleEndian Then Begin
   K := 0;
   While K < OutCount Do Begin
    For C := 0 To BytesPerSample Div 2-1 Do Begin
     Value := Raw[K+C];
     Raw[K+C] := Raw[K+BytesPerSample-1-C];
     Raw[K+BytesPerSample-1-C] := Value;
    End;
    Inc(K,BytesPerSample);
   End;
  End;
  WriteBytes(Raw,OutCount);
  Inc(Position,OutCount); Dec(Remaining,OutCount);
 End;
 If Odd(FrameCount*BlockAlign) Then Begin
  Raw[0] := 0; WriteBytes(Raw,1);
 End;
 {$I-}Close(InputFile); Code := IOResult;{$I+} InputOpen := False;
 If Code <> 0 Then Fail('Fermeture AIFF impossible.');
 {$I-}Close(OutputFile); Code := IOResult;{$I+} OutputOpen := False;
 If Code <> 0 Then Fail('Fermeture WAV impossible.');
 OutputCreated := False;
 WriteLn(EngOut,'WAV cree: ',OutputName);
 WriteLn(EngOut,Header.Rate,' Hz, ',Header.Channels,' canal/canaux, PCM ',Bits,
  ' bits, ',
 FrameCount,' trames.');
End;
Begin
 InputName := Source; OutputName := Target; InputOpen := False; OutputOpen :=
  False;
 OutputCreated := False;
 Convert;
End;
{ Moteur integre depuis VOC2WAV.PAS }

Procedure DecodeVOC(Const Source,Target: String);
Type
 TAudioFormat = Record
  Channels: Integer;
  Rate: LongInt;
 End;
Var
 InputFile, OutputFile: File;
 InputName, OutputName: String;
 InputOpen, OutputOpen, OutputCreated: Boolean;
 InputSize, Written: LongInt;
 PCM: Array[0..4095] Of Byte;
 Header: TAudioFormat;

Procedure Cleanup;
Var
 Code: Integer;
Begin
 If InputOpen Then Begin
  {$I-}Close(InputFile); Code := IOResult;{$I+} InputOpen := False;
 End;
 If OutputOpen Then Begin
  {$I-}Close(OutputFile); Code := IOResult;{$I+} OutputOpen := False;
 End;
 If OutputCreated Then Begin
  {$I-}Erase(OutputFile); Code := IOResult;{$I+}
  If Code <> 0 Then WriteLn(EngOut,'Fichier incomplet a supprimer: ', OutputName);
  OutputCreated := False;
 End;
End;

Procedure Fail(MessageText: String);Begin
 EngMsg:=MessageText; Cleanup; EngAbort;
End;

Function Exists(Name: String): Boolean;
Var
 F: File;
 Attributes: Word;
Begin
 Assign(F, Name); GetFAttr(F, Attributes); Exists := DosError = 0;
End;

Function DefaultOutput(Name: String): String;
Var
 I: Integer;
Begin
 I := Length(Name);
 While (I > 0) And Not (Name[I] In ['.', '/', '\', ':']) Do Dec(I);
 If (I > 0) And (Name[I] = '.') Then Name := Copy(Name, 1, I - 1);
 If Length(Name) > 251 Then Fail('Nom de sortie trop long.');
 DefaultOutput := Name + '.wav';
End;

Procedure Help;Begin
 WriteLn(EngOut,
 'VOC2WAV - Cette commande permet de lancer le convertisseur Creative VOC PCM '+
  'vers WAV PCM16');
 WriteLn(EngOut);
 WriteLn(EngOut,'Syntaxe : VOC2WAV entree.voc [sortie.wav]');
 WriteLn(EngOut);
 WriteLn(EngOut,'Creative VOC PCM 8/16 bits -> WAV PCM16, mono/stereo.');
 WriteLn(EngOut,'Continuations, silences et boucles internes finies pris en charge.');
 WriteLn(EngOut,
 'ADPCM CT pris en charge; autres ADPCM, A-law, mu-law et changements de frequ'+
  'ence/canaux refuses.');
 WriteLn(EngOut,'Sans sortie explicite: meme chemin avec extension .wav.');
 WriteLn(EngOut,
  'Fichiers < 2 Go; aucune sortie existante ecrasee. Aide: /? ou --help');
End;

Procedure ReadAt(Position: LongInt; Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 If (Position < 0) Or (Position > InputSize) Then Fail(
  'Position VOC incorrecte.');
 If Count > InputSize - Position Then Fail('Fichier VOC tronque.');
 {$I-}Seek(InputFile, Position); ErrorCode := IOResult;{$I+}
 If ErrorCode <> 0 Then Fail('Positionnement VOC impossible.');
 {$I-}BlockRead(InputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Lecture VOC incomplete.');
End;

Procedure WriteBytes(Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 {$I-}BlockWrite(OutputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Ecriture WAV incomplete.')
 ;
End;

Procedure Put16(Value: Word);
Var
 B: Array[0..1] Of Byte;
Begin
 B[0] := Value And 255; B[1] := Value Shr 8; WriteBytes(B,2);
End;

Procedure Put32(Value: LongInt);
Var
 B: Array[0..3] Of Byte;
 J: Integer;
Begin
 For J := 0 To 3 Do Begin
  B[J] := Value And 255; Value := Value Shr 8;
 End;
 WriteBytes(B,4);
End;

Procedure WriteWaveHeader(DataSize: LongInt; Bits: Integer);
Var
 Tag: String[4];
 Align: Word;
 RiffSize: LongInt;
Begin
 Align := Header.Channels*(Bits Div 8);
 RiffSize := DataSize+36; If Odd(DataSize) Then Inc(RiffSize);
 Tag := 'RIFF'; WriteBytes(Tag[1],4); Put32(RiffSize);
 Tag := 'WAVE'; WriteBytes(Tag[1],4);
 Tag := 'fmt '; WriteBytes(Tag[1],4); Put32(16); Put16(1);
 Put16(Header.Channels); Put32(Header.Rate); Put32(Header.Rate*Align);
 Put16(Align); Put16(Bits);
 Tag := 'data'; WriteBytes(Tag[1],4); Put32(DataSize);
End;

Procedure CreateOutput;
Var
 Code: Integer;
Begin
 If Exists(OutputName) Then Fail('Le fichier de sortie existe deja: '+
  OutputName);
 Assign(OutputFile,OutputName);
 {$I-}Rewrite(OutputFile,1); Code := IOResult;{$I+}
 If Code <> 0 Then Fail('Creation WAV impossible: '+OutputName);
 OutputOpen := True; OutputCreated := True;
 FillChar(PCM,44,0); WriteBytes(PCM,44); Written := 0;
End;

Function LE16(Const B; Offset: Integer): Word;
Type
 TSmallBytes = Array[0..63] Of Byte;
Begin
 LE16 := Word(TSmallBytes(B)[Offset]) Or (Word(TSmallBytes(B)[Offset+1]) Shl 8);
End;

Function LE32(Const B; Offset: Integer): LongInt;
Type
 TSmallBytes = Array[0..63] Of Byte;
Begin
 If TSmallBytes(B)[Offset+3] >= 128 Then Fail('Valeur VOC depassant 2 Go.');
 LE32 := LongInt(TSmallBytes(B)[Offset]) + LongInt(TSmallBytes(B)[Offset+1])*256
  +
 LongInt(TSmallBytes(B)[Offset+2])*65536 + LongInt(TSmallBytes(B)[Offset+3])*
  16777216;
End;

Var
 HaveFormat, HaveSound: Boolean;
 CTPred, CTStep: Array[0..1] Of LongInt;
 SBPredV, SBStepV: Array[0..1] Of LongInt;
 SBStartedV: Boolean;

Procedure SetFormat(Rate: LongInt; Channels: Integer);Begin
 If (Rate < 4000) Or (Rate > 192000) Or Not (Channels In [1,2]) Then  Fail(
 'Format VOC attendu: 4000..192000 Hz, mono/stereo.');
 If HaveFormat Then Begin
  If (Header.Rate <> Rate) Or (Header.Channels <> Channels) Then   Fail(
  'Changement de frequence ou de canaux non pris en charge.');
 End Else
 Begin
  Header.Rate := Rate; Header.Channels := Channels;
  HaveFormat := True;
 End;
End;

Procedure SubmitPCM(Count: Word);Begin
 If Written > 2147483600 - Count Then Fail('Sortie WAV depassant 2 Go.');
 WriteBytes(PCM,Count); Inc(Written,Count);
End;

Type
 TRawBytes = Array[0..2047] Of Byte;

Var
 SBN: Integer;

Procedure SBPut(V: LongInt);Begin
 If V < 0 Then Inc(V, 65536);
 PCM[SBN] := V And 255; PCM[SBN+1] := V Shr 8; Inc(SBN, 2);
 If SBN >= 4096 Then Begin
  SubmitPCM(SBN); SBN := 0;
 End;
End;

Function SBExpandV(C: Integer; Nibble, Bits, Shift: Integer): LongInt;
Var
 Delta, Diff: LongInt;
Begin
 Delta := Nibble And ((1 Shl (Bits-1))-1);
 Diff := Delta Shl (7+SBStepV[C]+Shift);
 If (Nibble And (1 Shl (Bits-1))) <> 0 Then SBPredV[C] := SBPredV[C]-Diff
                                       Else SBPredV[C] := SBPredV[C]+Diff;
 If SBPredV[C] < -16384 Then SBPredV[C] := -16384;
 If SBPredV[C] > 16256 Then SBPredV[C] := 16256;
 If (Delta >= 2*Bits-3) And (SBStepV[C] < 3) Then Inc(SBStepV[C]) Else
 If (Delta = 0) And (SBStepV[C] > 0) Then Dec(SBStepV[C]);
 SBExpandV := SBPredV[C];
End;
{ Paquet Sound Blaster Pro (2048 octets au plus); Mode: 4, 3 ou 2. }

Procedure SBPacket(Const R: TRawBytes; Size, Mode: Integer);
Var
 Buf, Nb, At, I, V: LongInt;
 St, Spb: Integer;
Begin
 St := Header.Channels-1; Buf := Size; Nb := 0;
 If Mode = 4 Then Spb := 2 Else If Mode = 3 Then Spb := 3 Else Spb := 4;
 If Not SBStartedV Then Begin
  If Buf < Header.Channels Then Exit;
  Nb := 1; Dec(Buf, Header.Channels);
 End;
 Inc(Nb, Buf*Spb Div Header.Channels); At := 0; SBN := 0;
 If Not SBStartedV Then Begin
  SBPut(128*(LongInt(R[At])-128)); Inc(At);
  If St = 1 Then Begin
   SBPut(128*(LongInt(R[At])-128)); Inc(At);
  End;
  SBStartedV := True; Dec(Nb);
 End;
 If Mode = 4 Then Begin
  For I := 1 To Nb Shr (1-St) Do Begin
   V := R[At]; Inc(At);
   SBPut(SBExpandV(0, V Shr 4, 4, 0)); SBPut(SBExpandV(St, V And 15, 4, 0));
  End;
 End Else If Mode = 3 Then Begin
  For I := 1 To (Nb Shl St) Div 3 Do Begin
   V := R[At]; Inc(At);
   SBPut(SBExpandV(0, V Shr 5, 3, 0)); SBPut(SBExpandV(0, (V Shr 2) And 7, 3,
    0));
   SBPut(SBExpandV(0, V And 3, 2, 0));
  End;
 End Else
 Begin
  For I := 1 To Nb Shr (2-St) Do Begin
   V := R[At]; Inc(At);
   SBPut(SBExpandV(0, V Shr 6, 2, 2)); SBPut(SBExpandV(St, (V Shr 4) And 3, 2,
    2));
   SBPut(SBExpandV(0, (V Shr 2) And 3, 2, 2)); SBPut(SBExpandV(St, V And 3, 2,
    2));
  End;
 End;
 If SBN > 0 Then Begin
  SubmitPCM(SBN); SBN := 0;
 End;
End;

Procedure ConvertData(Position, Count: LongInt; Bits: Integer);
Var
 Raw: Array[0..2047] Of Byte;
 N, J, OutCount, Align
, Drop
: Integer;
 Value: LongInt;
Begin
 Drop := 0;
 If Bits >= 206 Then Begin
  { F1 : A-law (206) / mu-law (207) }
  If Count > 0 Then HaveSound := True;
  While Count > 0 Do Begin
   If Count > 1024 Then N := 1024 Else N := Count;
   ReadAt(Position, Raw, N); OutCount := 0;
   For J := 0 To N-1 Do Begin
    Align := Raw[J];
    If Bits = 206 Then Begin
     Align := Align Xor $55; Value := Align And 15; OutCount := (Align And $70)
      Shr 4;
     If OutCount <> 0 Then Value := (Value+Value+1+32) Shl (OutCount+2) Else
      Value := (Value+Value+1) Shl 3;
     If (Align And $80) = 0 Then Value := -Value;
    End Else Begin
     Align := (Not Align) And 255; Value := ((Align And 15) Shl 3)+$84; Value :=
      Value Shl ((Align And $70) Shr 4);
     If (Align And $80) <> 0 Then Value := $84-Value Else Value := Value-$84;
    End;
    If Value < 0 Then Inc(Value, 65536);
    PCM[2*J] := Value And 255; PCM[2*J+1] := Value Shr 8;
   End;
   OutCount := 2*N;
   SubmitPCM(OutCount); Inc(Position, N); Dec(Count, N);
  End;
  Exit;
 End;

 If Bits >= 102 Then Begin
  { ADPCM Sound Blaster Pro: 4 bits (104), 2.6 bits (103), 2 bits (102). }
  If Count > 0 Then HaveSound := True;
  While Count > 0 Do Begin
   If Count > SizeOf(Raw) Then N := SizeOf(Raw) Else N := Count;
   ReadAt(Position, Raw, N); OutCount := 0;
   SBPacket(TRawBytes(Raw), N, Bits-100);
   Inc(Position, N); Dec(Count, N);
  End;
  Exit;
 End;
 If Bits = 4 Then Begin
  { ADPCM Creative Technology (codec 0x0200): deux echantillons par octet. }
  If Count > 0 Then HaveSound := True;
  While Count > 0 Do Begin
   If Count > 1024 Then N := 1024 Else N := Count;
   ReadAt(Position, Raw, N); OutCount := 0;
   For J := 0 To N-1 Do Begin
    Value := ADPCMExpandCT(CTPred[0], CTStep[0], Raw[J] Shr 4);
    PCM[OutCount] := Value And 255; PCM[OutCount+1] := (Value Shr 8) And 255;
    Inc(OutCount, 2);
    Value := ADPCMExpandCT(CTPred[Header.Channels-1], CTStep[Header.Channels-1],
    Raw[J] And 15);
    PCM[OutCount] := Value And 255; PCM[OutCount+1] := (Value Shr 8) And 255;
    Inc(OutCount, 2);
   End;
   SubmitPCM(OutCount); Inc(Position, N); Dec(Count, N);
  End;
  Exit;
 End;
 Align := Header.Channels * (Bits Div 8);
 If  Count > 0 Then HaveSound := True;
 While Count > 0 Do Begin
  If Count > SizeOf(Raw) Then N := SizeOf(Raw) Else N := Count;
  ReadAt(Position, Raw, N); OutCount := 0;
  Drop := N Mod Align; If Drop <> 0 Then Begin N := N - Drop; If N = 0 Then
   Begin Inc(Position, Drop); Dec(Count, Drop); Continue; End; End;

  If Bits = 8 Then Begin
   For J := 0 To N-1 Do Begin
    Value := (LongInt(Raw[J])-128)*256;
    If Value < 0 Then Inc(Value, 65536);
    PCM[OutCount] := Value And 255; PCM[OutCount+1] := Value Shr 8;
    Inc(OutCount, 2);
   End;
  End Else
  Begin
   Move(Raw, PCM, N); OutCount := N;
  End;
  SubmitPCM(OutCount); Inc(Position, N
+Drop
); Dec(Count, N
+Drop
);
 End;
End;

Procedure WriteSilence(Cycles: LongInt; TimeConstant: Byte);
Var
 Frames, Count: LongInt;
Begin
 If Not HaveFormat Then SetFormat(1000000 Div (256-Word(TimeConstant)), 1);
 { Convertir la duree en nombre d'echantillons du format courant. }
 Frames := Round(Cycles * (256.0-TimeConstant) * Header.Rate / 1000000.0);
 FillChar(PCM, SizeOf(PCM), 0);
 While Frames > 0 Do Begin
  Count := Frames;
  If Count > 1024 Then Count := 1024;
  SubmitPCM(Count * Header.Channels * 2); Dec(Frames, Count);
 End;
 HaveSound := True;
End;

Procedure Convert;
Const
 { Une constante chaine non typee ne peut pas etre indexee sous Turbo Pascal. }
 Signature: String[19] = 'Creative Voice File';
Type
 TRepeatState = Record
  Position: LongInt;
  Left: Word;
  Bits: Integer;
 End;
Var
 B: Array[0..63] Of Byte;
 Stack: Array[1..8] Of TRepeatState;
 Position, Size, Next, Rate, ExtendedRate, Steps: LongInt;
 Bits, Channels, ExtendedChannels, Depth, J, Code, Kind, Codec: Integer;
 Version, Check: Word;
 OldMode: Byte;
 Extended, Terminated: Boolean;
Codec0: Integer;

Begin
 Codec0 := -1;

 HaveFormat := False; HaveSound := False;
 Extended := False; Terminated := False; Depth := 0; Bits := 0; Steps := 0;
 ExtendedRate := 0; ExtendedChannels := 0;
 CTPred[0] := 0; CTPred[1] := 0; CTStep[0] := 511; CTStep[1] := 511;
 SBPredV[0] := 0; SBPredV[1] := 0; SBStepV[0] := 0; SBStepV[1] := 0; SBStartedV
  := False;
 Assign(InputFile, InputName); OldMode := FileMode; FileMode := 0;
 {$I-}Reset(InputFile, 1); Code := IOResult;{$I+}
 FileMode := OldMode;
 If Code <> 0 Then Fail('Ouverture VOC impossible: ' + InputName);
 InputOpen := True;
 {$I-}InputSize := FileSize(InputFile); Code := IOResult;{$I+}
 If (Code <> 0) Or (InputSize < 26) Then Fail(
  'VOC vide, trop grand ou tronque.');
 ReadAt(0, B, 26);
 For J := 1 To 19 Do  If B[J-1] <> Ord(Signature[J]) Then Fail(
 'Signature Creative Voice File manquante.');
 If B[19] <> $1A Then Fail('Signature VOC incorrecte.');
 Version := LE16(B,22); Check := LE16(B,24);
 If Check <> Word((LongInt(Version Xor $FFFF)+$1234) And $FFFF) Then Fail(
 'Controle de version VOC incorrect.');
 If (Version < $0100) Or (Version > $0114) Then Fail(
 'Version VOC non prise en charge (1.00..1.20).');
 Position := LE16(B,20);
 If (Position < 26) Or (Position >= InputSize) Then Fail(
 'Position initiale VOC incorrecte.');
 CreateOutput;
 WriteLn(EngOut,'Conversion VOC vers WAV PCM16...');
 { F1 : comportement de libavformat/vocdec.c + voc_packet.c : silences, boucles,
  marqueurs et textes sont ignores ;
   le format (frequence, canaux, codec) est fixe par le premier bloc audio ; le
    bloc 8 ne sert qu'au premier bloc 1 suivant }

 While Position < InputSize Do Begin
  Inc(Steps);
  If Steps > 1000000 Then Fail(
   'Trop de blocs VOC developpes (limite 1000000).');
  ReadAt(Position, B, 1); Kind := B[0]; Inc(Position);
  If  Kind = 0 Then Begin
   Terminated := True; Break;
  End;
  If InputSize-Position < 3 Then Begin Terminated := True; Break; End;

  ReadAt(Position, B, 3); Inc(Position, 3);
  Size := LongInt(B[0])+LongInt(B[1])*256+LongInt(B[2])*65536;
  If Size
= 0 Then Size := InputSize-Position;
  If Size
 > InputSize-Position Then Size := InputSize-Position ;
  Next := Position + Size;
  Case Kind Of
  1:
  Begin
   If Size < 2 Then Fail('Bloc VOC 1 trop court.');
   ReadAt(Position, B, 2);
   If Not HaveFormat Then Begin
    Rate :=  1000000 Div (256-Word(B[0])); Channels := 1;
   If ExtendedRate <> 0 Then Rate := ExtendedRate;
    If Extended Then Channels := ExtendedChannels ;
   SetFormat(Rate, Channels); End;
   If Codec0 < 0 Then Begin
    Case B[1] Of 0: Codec0 := 8;
   1 : Codec0 := 104 ;
  2:
  Codec0 := 103 ;
  3:
  Codec0 := 102 ;
  4: Codec0 := 16 ;
  6:
  Codec0 := 206 ;
  7:
  Codec0 := 207 ;
    Else Fail ( 'Etiquette de codec VOC inconnue.' );
  End;
   End;
   Bits := Codec0;
   ConvertData(Position+2, Size-2, Bits);
   Extended := False; ExtendedRate := 0;
  End;
  2:
  Begin
   If Not HaveFormat Then Fail('Frequence VOC invalide.');
   ConvertData(Position, Size, Codec0);
   Extended := False; ExtendedRate := 0;
  End;

  8:
  Begin
   If Size < 4 Then Fail('Taille du bloc VOC 8 incorrecte.');
   ReadAt(Position, B, 4);

   ExtendedChannels := B[3]+1;
   ExtendedRate := 256000000 Div ((65536-LongInt(LE16(B,0)))*ExtendedChannels);
   Extended := True;
   Next := Position + 4;

  End;
  9:
  Begin
   If Size < 12 Then Fail('Bloc VOC 9 trop court.');
   ReadAt(Position, B, 12);
   If Not HaveFormat Then SetFormat( LE32(B,0) , B[5]
)
; Codec := LE16(B,6);
   If Codec0 < 0 Then Begin
    Case Codec Of 0: Codec0 := 8 ; 1: Codec0 := 104; 2: Codec0 := 103; 3: Codec0
     := 102; 4: Codec0 := 16 ; 6: Codec0 := 206; 7: Codec0 := 207; $200: Codec0
     := 4 ;
    Else     Fail(
   'Etiquette de codec VOC inconnue.' );
   End ;
   End ;
   ConvertData(Position+12, Size-12, Codec0 );
   Extended := False; ExtendedRate := 0;

  End;
  Else ;
 End;
 Position := Next;
End;
If Not  HaveSound Or (Written = 0) Then Fail('Aucun son VOC.');
{$I-}Seek(OutputFile,0); Code := IOResult;{$I+}
If Code <> 0 Then Fail('Positionnement entete WAV impossible.');
WriteWaveHeader(Written,16);
{$I-}Close(InputFile); Code := IOResult;{$I+} InputOpen := False;
If Code <> 0 Then Fail('Fermeture VOC impossible.');
{$I-}Close(OutputFile); Code := IOResult;{$I+} OutputOpen := False;
If Code <> 0 Then Fail('Fermeture WAV impossible.');
OutputCreated := False;
WriteLn(EngOut,'WAV cree: ',OutputName);
WriteLn(EngOut,Header.Rate,' Hz, ',Header.Channels,' canal/canaux, PCM 16 bits, ',
 Written Div (
Header.Channels*2),' trames.');
End;
Begin
 InputName := Source; OutputName := Target; InputOpen := False; OutputOpen :=
  False;
 OutputCreated := False;
 Convert;
End;
{ Moteur integre depuis MOD2WAV.PAS }

Procedure DecodeMOD(Const Source,Target: String);
Type
 TAudioFormat = Record
  Channels: Integer;
  Rate: LongInt;
 End;
Var
 InputFile, OutputFile: File;
 InputName, OutputName: String;
 InputOpen, OutputOpen, OutputCreated: Boolean;
 InputSize, Written: LongInt;
 PCM: Array[0..4095] Of Byte;
 Header: TAudioFormat;

Procedure Cleanup;
Var
 Code: Integer;
Begin
 If InputOpen Then Begin
  {$I-}Close(InputFile); Code := IOResult;{$I+} InputOpen := False;
 End;
 If OutputOpen Then Begin
  {$I-}Close(OutputFile); Code := IOResult;{$I+} OutputOpen := False;
 End;
 If OutputCreated Then Begin
  {$I-}Erase(OutputFile); Code := IOResult;{$I+}
  If Code <> 0 Then WriteLn(EngOut,'Fichier incomplet a supprimer: ', OutputName);
  OutputCreated := False;
 End;
End;

Procedure Fail(MessageText: String);Begin
 EngMsg:=MessageText; Cleanup; EngAbort;
End;

Function Exists(Name: String): Boolean;
Var
 F: File;
 Attributes: Word;
Begin
 Assign(F, Name); GetFAttr(F, Attributes); Exists := DosError = 0;
End;

Function DefaultOutput(Name: String): String;
Var
 I: Integer;
Begin
 I := Length(Name);
 While (I > 0) And Not (Name[I] In ['.', '/', '\', ':']) Do Dec(I);
 If (I > 0) And (Name[I] = '.') Then Name := Copy(Name, 1, I - 1);
 If Length(Name) > 251 Then Fail('Nom de sortie trop long.');
 DefaultOutput := Name + '.wav';
End;

Procedure Help;Begin
 WriteLn(EngOut,
 'MOD2WAV - Cette commande permet de lancer le convertisseur MOD ProTracker ve'+
  'rs WAV PCM16');
 WriteLn(EngOut);
 WriteLn(EngOut,'Syntaxe: MOD2WAV entree.mod [sortie.wav]');
 WriteLn(EngOut);
 WriteLn(EngOut,'MOD 4 canaux/31 instruments: M.K., M!K!, 4CHN, FLT4.');
 WriteLn(EngOut,
  'Rendu integre WAV PCM16 stereo 22050 Hz. Voir MOD2WAV.md pour les effets.');
 WriteLn(EngOut,'Sans sortie explicite: meme chemin avec extension .wav.');
 WriteLn(EngOut,'Aucun outil externe. Sortie existante refusee. Aide: /? ou --help');
End;

Procedure ReadAt(Position: LongInt; Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 If (Position < 0) Or (Position > InputSize) Then Fail(
  'Position MOD incorrecte.');
 If Count > InputSize - Position Then Fail('Fichier MOD tronque.');
 {$I-}Seek(InputFile, Position); ErrorCode := IOResult;{$I+}
 If ErrorCode <> 0 Then Fail('Positionnement MOD impossible.');
 {$I-}BlockRead(InputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Lecture MOD incomplete.');
End;

Procedure WriteBytes(Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 {$I-}BlockWrite(OutputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Ecriture WAV incomplete.')
 ;
End;

Procedure Put16(Value: Word);
Var
 B: Array[0..1] Of Byte;
Begin
 B[0] := Value And 255; B[1] := Value Shr 8; WriteBytes(B,2);
End;

Procedure Put32(Value: LongInt);
Var
 B: Array[0..3] Of Byte;
 J: Integer;
Begin
 For J := 0 To 3 Do Begin
  B[J] := Value And 255; Value := Value Shr 8;
 End;
 WriteBytes(B,4);
End;

Procedure WriteWaveHeader(DataSize: LongInt; Bits: Integer);
Var
 Tag: String[4];
 Align: Word;
 RiffSize: LongInt;
Begin
 Align := Header.Channels*(Bits Div 8);
 RiffSize := DataSize+36; If Odd(DataSize) Then Inc(RiffSize);
 Tag := 'RIFF'; WriteBytes(Tag[1],4); Put32(RiffSize);
 Tag := 'WAVE'; WriteBytes(Tag[1],4);
 Tag := 'fmt '; WriteBytes(Tag[1],4); Put32(16); Put16(1);
 Put16(Header.Channels); Put32(Header.Rate); Put32(Header.Rate*Align);
 Put16(Align); Put16(Bits);
 Tag := 'data'; WriteBytes(Tag[1],4); Put32(DataSize);
End;

Procedure CreateOutput;
Var
 Code: Integer;
Begin
 If Exists(OutputName) Then Fail('Le fichier de sortie existe deja: '+
  OutputName);
 Assign(OutputFile,OutputName);
 {$I-}Rewrite(OutputFile,1); Code := IOResult;{$I+}
 If Code <> 0 Then Fail('Creation WAV impossible: '+OutputName);
 OutputOpen := True; OutputCreated := True;
 FillChar(PCM,44,0); WriteBytes(PCM,44); Written := 0;
End;

Const
 MixRate = 22050;

Type
 TSample = Record
  Start, Length, LoopStart, LoopLength: LongInt;
  Volume, Fine: Integer;
 End;
 TVoice = Record
  Instrument, ActiveSample, Volume, MixVolume, Pan, Fine: Integer;
  Effect, Param, PortaSpeed, OffsetMemory, VibratoSpeed, VibratoDepth: Integer;
  TremoloSpeed, TremoloDepth, VibratoPhase, TremoloPhase: Integer;
  LoopRow, LoopCount, DelayPeriod: Integer;
  Period, Target, Position, Step: Double;
  Active: Boolean;
  CacheStart: LongInt;
  CacheCount: Integer;
  Cache: Array[0..1023] Of Byte;
 End;

Var
 Samples: Array[1..31] Of TSample;
 Voices: Array[0..3] Of TVoice;
 Orders: Array[0..127] Of Byte;
 Pattern: Array[0..1023] Of Byte;
 SongLength, PatternCount, LoadedPattern, Speed, BPM, Order, Row: Integer;
 PCMUsed: Integer;
 Rendered: LongInt;
 TickFraction: Double;

Function BE16(Const B; Index: Integer): LongInt;
Type
 TBytes = Array[0..1083] Of Byte;
Begin
 BE16 := LongInt(TBytes(B)[Index])*256 + TBytes(B)[Index+1];
End;

Function Clamp(Value, Low, High: Integer): Integer;Begin
 If Value < Low Then Value := Low;
 If Value > High Then Value := High;
 Clamp := Value;
End;

Procedure FlushMix;Begin
 If PCMUsed = 0 Then Exit;
 If Written > 2147483600 - PCMUsed Then Fail('Sortie WAV trop grande.');
 WriteBytes(PCM,PCMUsed); Inc(Written,PCMUsed); PCMUsed := 0;
End;

Procedure PutSample(Value: LongInt);Begin
 If Value < -32768 Then Value := -32768;
 If Value > 32767 Then Value := 32767;
 If Value < 0 Then Inc(Value, 65536);
 PCM[PCMUsed] := Value And 255; PCM[PCMUsed+1] := Value Shr 8;
 Inc(PCMUsed, 2);
 If PCMUsed = SizeOf(PCM) Then FlushMix;
End;

Procedure Trigger(Var V: TVoice; Note: Integer; Offset: LongInt);Begin
 If (V.Instrument < 1) Or (Note = 0) Then Exit;
 V.ActiveSample := V.Instrument;
 V.Period := Note * Exp(-V.Fine*Ln(2)/96);
 V.Position := Offset; V.CacheStart := -1; V.CacheCount := 0;
 V.Active := Offset < Samples[V.ActiveSample].Length;
 V.VibratoPhase := 0; V.TremoloPhase := 0;
End;

Procedure SlideVolume(Var V: TVoice; Param: Integer);Begin
 If (Param Shr 4) > 0 Then Inc(V.Volume, Param Shr 4)
                      Else Dec(V.Volume, Param And 15);
 V.Volume := Clamp(V.Volume,0,64);
End;

Procedure TonePorta(Var V: TVoice);Begin
 If (V.Target <= 0) Or (V.Period <= 0) Then Exit;
 If V.Period < V.Target Then Begin
  V.Period := V.Period + V.PortaSpeed;
  If V.Period > V.Target Then V.Period := V.Target;
 End Else
 Begin
  V.Period := V.Period - V.PortaSpeed;
  If V.Period < V.Target Then V.Period := V.Target;
 End;
End;

Procedure RowEvents(Var JumpOrder, BreakRow, LoopTo, DelayRows: Integer;
                    Var Stop: Boolean);
Var
 C, At, Inst, Note, Fx, CellParam, X, Y: Integer;
Begin
 For C := 0 To 3 Do Begin
  At := Row*16+C*4;
  Inst := (Pattern[At] And $F0) Or (Pattern[At+2] Shr 4);
  Note := (Word(Pattern[At] And 15) Shl 8) Or Pattern[At+1];
  Fx := Pattern[At+2] And 15; CellParam := Pattern[At+3]; X := CellParam Shr 4;
  Y := CellParam And 15;
  If Inst > 31 Then Fail('Instrument MOD invalide.');
  If (Note <> 0) And ((Note < 28) Or (Note > 3424)) Then Fail(
   'Periode MOD invalide.');
  With Voices[C] Do Begin
   Effect := Fx; Voices[C].Param := CellParam; DelayPeriod := 0;
   If Inst > 0 Then Begin
    Instrument := Inst; Volume := Samples[Inst].Volume; Fine := Samples[
     Inst].Fine;
   End;
   If (Fx = 14) And (X = 5) Then Begin
    Fine := Y; If Fine > 7 Then Dec(Fine,16);
   End;
   If (Fx = 9) And (CellParam > 0) Then OffsetMemory := CellParam;
   If (Fx = 3) And (CellParam > 0) Then PortaSpeed := CellParam;
   If Fx = 4 Then Begin
    If X > 0 Then VibratoSpeed := X;
    If Y > 0 Then VibratoDepth := Y;
   End;
   If Fx = 7 Then Begin
    If X > 0 Then TremoloSpeed := X;
    If Y > 0 Then TremoloDepth := Y;
   End;
   If Note > 0 Then Begin
    If (Fx = 3) Or (Fx = 5) Then Target := Note*Exp(-Fine*Ln(2)/96) Else
    If (Fx = 14) And (X = 13) And (Y > 0) Then DelayPeriod := Note Else
    If Fx = 9 Then Trigger(Voices[C], Note, LongInt(OffsetMemory)*256)
              Else Trigger(Voices[C], Note, 0);
   End;
   Case Fx Of
   8: Pan := CellParam;
   11: JumpOrder := CellParam;
   12: Volume := Clamp(CellParam,0,64);
   13:
   Begin
    If (X > 6) Or (Y > 9) Or (X*10+Y > 63) Then Fail(
     'Pattern break MOD invalide.');
    BreakRow := X*10+Y;
   End;
   14: Case X Of
   1: If Period > 0 Then Period := Clamp(Round(Period)-Y,113,856);
   2: If Period > 0 Then Period := Clamp(Round(Period)+Y,113,856);
   5:
   Begin
   End;
   6: If Y = 0 Then LoopRow := Row Else
   Begin
    If LoopCount = 0 Then LoopCount := Y Else Dec(LoopCount);
    If LoopCount > 0 Then LoopTo := LoopRow;
   End;
   8: Pan := Y*17;
   9:
   Begin
   End;
   10: Volume := Clamp(Volume+Y,0,64);
   11: Volume := Clamp(Volume-Y,0,64);
   12: If Y = 0 Then Volume := 0;
   13:
   Begin
   End;
   14: DelayRows := Y;
   Else Fail('Effet MOD E0/E3/E4/E7/EF non pris en charge.');
  End;
  15: If CellParam = 0 Then Stop := True Else
  If CellParam < 32 Then Speed := CellParam Else BPM := CellParam;
 End;
End;
End;
End;

Procedure TickEffects(Tick: Integer);
Var
 C, X, Y, Semitone: Integer;
 PlayPeriod: Double;
Begin
 For C := 0 To 3 Do With Voices[C] Do Begin
  X := Param Shr 4; Y := Param And 15;
  If Tick > 0 Then Begin
   Case Effect Of
   1: If Period > 0 Then Period := Clamp(Round(Period)-Param,113,856);
   2: If Period > 0 Then Period := Clamp(Round(Period)+Param,113,856);
   3: TonePorta(Voices[C]);
   5:
   Begin
    TonePorta(Voices[C]); SlideVolume(Voices[C], Param);
   End;
   6,10: SlideVolume(Voices[C], Param);
   14: Case X Of
   9: If Y > 0 Then If (Tick Mod Y) = 0 Then Begin
    Position := 0; Active := ActiveSample > 0;
   End;
   12: If Tick = Y Then Volume := 0;
   13: If (Tick = Y) And (DelayPeriod > 0) Then Trigger(Voices[C], DelayPeriod,
    0);
  End;
 End;
End;
PlayPeriod := Period; MixVolume := Volume;
If (Effect = 0) And (Param <> 0) And (Period > 0) Then Begin
 Semitone := 0;
 Case Tick Mod 3 Of 1: Semitone := X; 2: Semitone := Y;
End;
PlayPeriod := Period*Exp(-Semitone*Ln(2)/12);
End;
If (Tick > 0) And ((Effect = 4) Or (Effect = 6)) Then Begin
 PlayPeriod := Period + Sin(VibratoPhase*2*Pi/64)*VibratoDepth*2;
 VibratoPhase := (VibratoPhase+VibratoSpeed) Mod 64;
End;
If (Tick > 0) And (Effect = 7) Then Begin
 MixVolume := Clamp(Volume+Round(Sin(TremoloPhase*2*Pi/64)*TremoloDepth*4),0,
  64);
 TremoloPhase := (TremoloPhase+TremoloSpeed) Mod 64;
End;
If PlayPeriod > 0 Then Step := 3546894.6 / (PlayPeriod*MixRate) Else Step := 0;
End;
End;

Function VoiceValue(Var V: TVoice): LongInt;
Var
 Index, EndPoint, RemainingBytes: LongInt;
 N, Value: Integer;
Begin
 VoiceValue := 0;
 If Not V.Active Or (V.ActiveSample < 1) Then Exit;
 With Samples[V.ActiveSample] Do Begin
  EndPoint := Length;
  If LoopLength > 2 Then EndPoint := LoopStart+LoopLength;
  If V.Position >= EndPoint Then Begin
   If LoopLength > 2 Then    V.Position := LoopStart + (V.Position-LoopStart) -
    Trunc((
   V.Position-LoopStart)/LoopLength)*LoopLength
    Else
   Begin
    V.Active := False; Exit;
   End;
  End;
  Index := Trunc(V.Position);
  If (Index < 0) Or (Index >= Length) Then Begin
   V.Active := False; Exit;
  End;
  If (V.CacheStart < 0) Or (Index < V.CacheStart) Or (Index >= V.CacheStart+
   V.CacheCount)
  Then Begin
   V.CacheStart := (Index Div 1024)*1024;
   RemainingBytes := Length-V.CacheStart;
   If RemainingBytes > 1024 Then N := 1024 Else N := RemainingBytes;
   ReadAt(Samples[V.ActiveSample].Start+V.CacheStart, V.Cache, N);
   V.CacheCount := N;
  End;
  Value := V.Cache[Index-V.CacheStart]; If Value >= 128 Then Dec(Value,256);
  VoiceValue := LongInt(Value)*V.MixVolume*2;
  V.Position := V.Position+V.Step;
 End;
End;

Procedure MixTick;
Var
 N, J, C: Integer;
 L, R, Value: LongInt;
Begin
 TickFraction := TickFraction + MixRate*2.5/BPM;
 N := Trunc(TickFraction); TickFraction := TickFraction-N;
 If Rendered > MixRate*1800-N Then Fail(
  'Morceau MOD trop long (limite 30 minutes).');
 Inc(Rendered, N);
 For J := 1 To N Do Begin
  L := 0; R := 0;
  For C := 0 To 3 Do Begin
   Value := VoiceValue(Voices[C]);
   Inc(L, Value*(255-Voices[C].Pan) Div 255);
   Inc(R, Value*Voices[C].Pan Div 255);
  End;
  PutSample(L); PutSample(R);
 End;
End;

Procedure Convert;
Var
 B: Array[0..1083] Of Byte;
 Code, I, J, SampleFine, Tick, DelayRows, JumpOrder,
 BreakRow, LoopTo, NextOrder, NextRow: Integer;
 DataStart, LengthBytes, Steps: LongInt;
 OldMode: Byte;
 Signature: String[4];
 Stop: Boolean;
Begin
 Assign(InputFile, InputName); OldMode := FileMode; FileMode := 0;
 {$I-}Reset(InputFile,1); Code := IOResult;{$I+}
 FileMode := OldMode;
 If Code <> 0 Then Fail('Ouverture MOD impossible: '+InputName);
 InputOpen := True;
 {$I-}InputSize := FileSize(InputFile); Code := IOResult;{$I+}
 If (Code <> 0) Or (InputSize < 1084) Then Fail('Entete MOD tronquee.');
 ReadAt(0,B,1084);
 Signature := '';
 For I := 1080 To 1083 Do Signature := Signature+Chr(B[I]);
 If (Signature <> 'M.K.') And (Signature <> 'M!K!') And (Signature <> '4CHN')
  And (
 Signature <> 'FLT4') Then  Fail(
 'MOD 4 canaux/31 instruments requis: M.K., M!K!, 4CHN ou FLT4.');
 SongLength := B[950];
 If (SongLength < 1) Or (SongLength > 128) Then Fail(
  'Longueur de chanson MOD invalide.');
 PatternCount := 0;
 For I := 0 To 127 Do Begin
  Orders[I] := B[952+I];
  If Orders[I] > 127 Then Fail('Numero de pattern MOD invalide.');
  If Orders[I]+1 > PatternCount Then PatternCount := Orders[I]+1;
 End;
 DataStart := 1084+LongInt(PatternCount)*1024;
 If DataStart > InputSize Then Fail('Patterns MOD tronques.');
 For I := 1 To 31 Do Begin
  J := 20+(I-1)*30;
  LengthBytes := BE16(B,J+22)*2; SampleFine := B[J+24];
  If (SampleFine > 15) Or (B[J+25] > 64) Then Fail(
   'Finetune ou volume MOD invalide.');
  If SampleFine > 7 Then Dec(SampleFine,16);
  With Samples[I] Do Begin
   Start := DataStart; Length := LengthBytes; Volume := B[J+25];
   Samples[I].Fine := SampleFine;
   LoopStart := BE16(B,J+26)*2; LoopLength := BE16(B,J+28)*2;
   If (LoopLength > 2) And ((LoopStart > Length) Or (LoopLength > Length-
    LoopStart))
   Then Fail('Boucle echantillon MOD invalide.');
  End;
  If LengthBytes > InputSize-DataStart Then Fail('Echantillon MOD tronque.');
  Inc(DataStart, LengthBytes);
 End;
 FillChar(Voices,SizeOf(Voices),0);
 For I := 0 To 3 Do Begin
  Voices[I].CacheStart := -1;
  If I In [1,2] Then Voices[I].Pan := 255;
 End;
 Header.Rate := MixRate; Header.Channels := 2;
 PCMUsed := 0; Rendered := 0; TickFraction := 0; Speed := 6; BPM := 125;
 Order := 0; Row := 0; LoadedPattern := -1; Steps := 0; Stop := False;
 CreateOutput; WriteLn(EngOut,'Rendu MOD 4 canaux vers PCM stereo 22050 Hz...');
 While (Order < SongLength) And Not Stop Do Begin
  Inc(Steps); If Steps > 65536 Then Fail('Trop de lignes MOD executees.');
  If Orders[Order] <> LoadedPattern Then Begin
   ReadAt(1084+LongInt(Orders[Order])*1024,Pattern,1024); LoadedPattern :=
    Orders[Order];
  End;
  JumpOrder := -1; BreakRow := -1; LoopTo := -1; DelayRows := 0;
  RowEvents(JumpOrder,BreakRow,LoopTo,DelayRows,Stop);
  If Stop Then Break;
  For Tick := 0 To Speed*(DelayRows+1)-1 Do Begin
   TickEffects(Tick Mod Speed); MixTick;
  End;
  NextOrder := Order; NextRow := Row+1;
  If NextRow = 64 Then Begin
   Inc(NextOrder); NextRow := 0;
  End;
  If LoopTo >= 0 Then Begin
   NextOrder := Order; NextRow := LoopTo;
  End;
  If (JumpOrder >= 0) Or (BreakRow >= 0) Then Begin
   If JumpOrder >= 0 Then NextOrder := JumpOrder Else NextOrder := Order+1;
   If BreakRow >= 0 Then NextRow := BreakRow Else NextRow := 0;
   { Un saut de chanson en arriere termine le rendu; les boucles E6 sont
    executees. }
   If (NextOrder < Order) Or ((NextOrder = Order) And (NextRow <= Row)) Then
    Stop := True;
  End;
  If NextOrder <> Order Then
  For I := 0 To 3 Do Begin
   Voices[I].LoopRow := 0; Voices[I].LoopCount := 0;
  End;
  Order := NextOrder; Row := NextRow;
 End;
 FlushMix;
 If Written = 0 Then Fail('Aucune duree audio MOD.');
 {$I-}Seek(OutputFile,0); Code := IOResult;{$I+}
 If Code <> 0 Then Fail('Positionnement entete WAV impossible.');
 WriteWaveHeader(Written,16);
 {$I-}Close(InputFile); Code := IOResult;{$I+} InputOpen := False;
 If Code <> 0 Then Fail('Fermeture MOD impossible.');
 {$I-}Close(OutputFile); Code := IOResult;{$I+} OutputOpen := False;
 If Code <> 0 Then Fail('Fermeture WAV impossible.');
 OutputCreated := False;
 WriteLn(EngOut,'WAV cree: ',OutputName);
 WriteLn(EngOut,'PCM16 stereo 22050 Hz, ',Rendered,' trames, ',Rendered/MixRate:0:3,
  ' secondes.')
 ;
End;
Begin
 InputName := Source; OutputName := Target; InputOpen := False; OutputOpen :=
  False;
 OutputCreated := False;
 Convert;
End;
{ Moteur integre depuis WAV2MP3.PAS }

Procedure EncodeMP3(Const Source,Target: String; BitRateK: Integer);
Type
 TAudioFormat = Record
  Channels: Integer;
  Rate: LongInt;
 End;
Var
 InputFile, OutputFile: File;
 InputName, OutputName: String;
 InputOpen, OutputOpen, OutputCreated: Boolean;
 InputSize, Written: LongInt;
 Header: TAudioFormat;

Procedure Cleanup;
Var
 Code: Integer;
Begin
 If InputOpen Then Begin
  {$I-}Close(InputFile); Code := IOResult;{$I+} InputOpen := False;
 End;
 If OutputOpen Then Begin
  {$I-}Close(OutputFile); Code := IOResult;{$I+} OutputOpen := False;
 End;
 If OutputCreated Then Begin
  {$I-}Erase(OutputFile); Code := IOResult;{$I+}
  If Code <> 0 Then WriteLn(EngOut,'Fichier incomplet a supprimer: ', OutputName);
  OutputCreated := False;
 End;
End;

Procedure Fail(MessageText: String);Begin
 EngMsg:=MessageText; Cleanup; EngAbort;
End;

Function Exists(Name: String): Boolean;
Var
 F: File;
 Attributes: Word;
Begin
 Assign(F, Name); GetFAttr(F, Attributes); Exists := DosError = 0;
End;

Function DefaultOutput(Name: String): String;
Var
 I: Integer;
Begin
 I := Length(Name);
 While (I > 0) And Not (Name[I] In ['.', '/', '\', ':']) Do Dec(I);
 If (I > 0) And (Name[I] = '.') Then Name := Copy(Name, 1, I - 1);
 If Length(Name) > 251 Then Fail('Nom de sortie trop long.');
 DefaultOutput := Name + '.mp3';
End;

Procedure Help;Begin
 WriteLn(EngOut,'WAV2MP3 entree.wav [sortie.mp3]');
 WriteLn(EngOut,'Encodeur MPEG-1 Layer III integre, 320 kbit/s, mono/stereo.');
 WriteLn(EngOut,'WAV PCM entier 8/16/24/32 bits, 32000/44100/48000 Hz.');
 WriteLn(EngOut,'Encodeur simple sans modele psychoacoustique ni correction gapless.');
 WriteLn(EngOut,'Sortie existante refusee. Aide: /? ou --help. Voir WAV2MP3.md.');
End;

Procedure ReadAt(Position: LongInt; Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 If (Position < 0) Or (Position > InputSize) Then Fail(
  'Position WAV incorrecte.');
 If Count > InputSize - Position Then Fail('Fichier WAV tronque.');
 {$I-}Seek(InputFile, Position); ErrorCode := IOResult;{$I+}
 If ErrorCode <> 0 Then Fail('Positionnement WAV impossible.');
 {$I-}BlockRead(InputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Lecture WAV incomplete.');
End;

Procedure WriteBytes(Var Buffer; Count: Word);
Var
 Actual: Word;
 ErrorCode: Integer;
Begin
 {$I-}BlockWrite(OutputFile, Buffer, Count, Actual); ErrorCode := IOResult;{$I+}
 If (ErrorCode <> 0) Or (Actual <> Count) Then Fail('Ecriture MP3 incomplete.')
 ;
End;

Const
 HuffTree: Array[0..2803] Of Word = (
 $0201,$0000,$0201,$0010,$0201,$0001,$0011,$0201,$0000,$0401,$0201,$0010,
 $0001,$0201,$0011,$0401,$0201,$0020,$0021,$0201,$0012,$0201,$0002,$0022,
 $0401,$0201,$0000,$0001,$0201,$0011,$0201,$0010,$0401,$0201,$0020,$0021,
 $0201,$0012,$0201,$0002,$0022,$0201,$0000,$0401,$0201,$0010,$0001,$0201,
 $0011,$0801,$0401,$0201,$0020,$0002,$0201,$0021,$0012,$0801,$0401,$0201,
 $0022,$0030,$0201,$0003,$0013,$0201,$0031,$0201,$0032,$0201,$0023,$0033,
 $0601,$0401,$0201,$0000,$0010,$0011,$0601,$0201,$0001,$0201,$0020,$0021,
 $0601,$0201,$0012,$0201,$0002,$0022,$0401,$0201,$0031,$0013,$0401,$0201,
 $0030,$0032,$0201,$0023,$0201,$0003,$0033,$0201,$0000,$0401,$0201,$0010,
 $0001,$0801,$0201,$0011,$0401,$0201,$0020,$0002,$0021,$1201,$0601,$0201,
 $0012,$0201,$0022,$0030,$0401,$0201,$0031,$0013,$0401,$0201,$0003,$0032,
 $0201,$0023,$0004,$0a01,$0401,$0201,$0040,$0041,$0201,$0014,$0201,$0042,
 $0024,$0c01,$0601,$0401,$0201,$0033,$0043,$0050,$0401,$0201,$0034,$0005,
 $0051,$0601,$0201,$0015,$0201,$0052,$0025,$0401,$0201,$0044,$0035,$0401,
 $0201,$0053,$0054,$0201,$0045,$0055,$0601,$0201,$0000,$0201,$0010,$0001,
 $0201,$0011,$0401,$0201,$0021,$0012,$0e01,$0401,$0201,$0020,$0002,$0201,
 $0022,$0401,$0201,$0030,$0003,$0201,$0031,$0013,$0e01,$0801,$0401,$0201,
 $0032,$0023,$0201,$0040,$0004,$0201,$0041,$0201,$0014,$0042,$0c01,$0601,
 $0201,$0024,$0201,$0033,$0050,$0401,$0201,$0043,$0034,$0051,$0601,$0201,
 $0015,$0201,$0005,$0052,$0601,$0201,$0025,$0201,$0044,$0035,$0201,$0053,
 $0201,$0045,$0201,$0054,$0055,$0801,$0401,$0201,$0000,$0010,$0201,$0001,
 $0011,$0a01,$0401,$0201,$0020,$0021,$0201,$0012,$0201,$0002,$0022,$0c01,
 $0601,$0401,$0201,$0030,$0003,$0031,$0201,$0013,$0201,$0032,$0023,$0c01,
 $0401,$0201,$0041,$0014,$0401,$0201,$0040,$0033,$0201,$0042,$0024,$0a01,
 $0601,$0401,$0201,$0004,$0050,$0043,$0201,$0034,$0051,$0801,$0401,$0201,
 $0015,$0052,$0201,$0025,$0044,$0601,$0401,$0201,$0005,$0054,$0053,$0201,
 $0035,$0201,$0045,$0055,$0201,$0000,$0401,$0201,$0010,$0001,$0a01,$0201,
 $0011,$0401,$0201,$0020,$0002,$0201,$0021,$0012,$1c01,$0801,$0401,$0201,
 $0022,$0030,$0201,$0031,$0013,$0801,$0401,$0201,$0003,$0032,$0201,$0023,
 $0040,$0401,$0201,$0041,$0014,$0401,$0201,$0004,$0033,$0201,$0042,$0024,
 $1c01,$0a01,$0601,$0401,$0201,$0050,$0005,$0060,$0201,$0061,$0016,$0c01,
 $0601,$0401,$0201,$0043,$0034,$0051,$0201,$0015,$0201,$0052,$0025,$0401,
 $0201,$0026,$0036,$0071,$1401,$0801,$0201,$0017,$0401,$0201,$0044,$0053,
 $0006,$0601,$0401,$0201,$0035,$0045,$0062,$0201,$0070,$0201,$0007,$0064,
 $0e01,$0401,$0201,$0072,$0027,$0601,$0201,$0063,$0201,$0054,$0055,$0201,
 $0046,$0073,$0801,$0401,$0201,$0037,$0065,$0201,$0056,$0074,$0601,$0201,
 $0047,$0201,$0066,$0075,$0401,$0201,$0057,$0076,$0201,$0067,$0077,$0601,
 $0201,$0000,$0201,$0010,$0001,$0801,$0201,$0011,$0401,$0201,$0020,$0002,
 $0012,$1801,$0801,$0201,$0021,$0201,$0022,$0201,$0030,$0003,$0401,$0201,
 $0031,$0013,$0401,$0201,$0032,$0023,$0401,$0201,$0040,$0004,$0201,$0041,
 $0014,$1e01,$1001,$0a01,$0401,$0201,$0042,$0024,$0401,$0201,$0033,$0043,
 $0050,$0401,$0201,$0034,$0051,$0061,$0601,$0201,$0016,$0201,$0006,$0026,
 $0201,$0062,$0201,$0015,$0201,$0005,$0052,$1001,$0a01,$0601,$0401,$0201,
 $0025,$0044,$0060,$0201,$0063,$0036,$0401,$0201,$0070,$0017,$0071,$1001,
 $0601,$0401,$0201,$0007,$0064,$0072,$0201,$0027,$0401,$0201,$0053,$0035,
 $0201,$0054,$0045,$0a01,$0401,$0201,$0046,$0073,$0201,$0037,$0201,$0065,
 $0056,$0a01,$0601,$0401,$0201,$0055,$0057,$0074,$0201,$0047,$0066,$0401,
 $0201,$0075,$0076,$0201,$0067,$0077,$0c01,$0401,$0201,$0010,$0001,$0201,
 $0011,$0201,$0000,$0201,$0020,$0002,$1001,$0401,$0201,$0021,$0012,$0401,
 $0201,$0022,$0031,$0201,$0013,$0201,$0030,$0201,$0003,$0040,$1a01,$0801,
 $0401,$0201,$0032,$0023,$0201,$0041,$0033,$0a01,$0401,$0201,$0014,$0042,
 $0201,$0024,$0201,$0004,$0050,$0401,$0201,$0043,$0034,$0201,$0051,$0015,
 $1c01,$0e01,$0801,$0401,$0201,$0052,$0025,$0201,$0053,$0035,$0401,$0201,
 $0060,$0016,$0061,$0401,$0201,$0062,$0026,$0601,$0401,$0201,$0005,$0006,
 $0044,$0201,$0054,$0045,$1201,$0a01,$0401,$0201,$0063,$0036,$0401,$0201,
 $0070,$0007,$0071,$0401,$0201,$0017,$0064,$0201,$0046,$0072,$0a01,$0601,
 $0201,$0027,$0201,$0055,$0073,$0201,$0037,$0056,$0801,$0401,$0201,$0065,
 $0074,$0201,$0047,$0066,$0401,$0201,$0075,$0057,$0201,$0076,$0201,$0067,
 $0077,$0201,$0000,$0601,$0201,$0010,$0201,$0001,$0011,$1c01,$0801,$0401,
 $0201,$0020,$0002,$0201,$0021,$0012,$0801,$0401,$0201,$0022,$0030,$0201,
 $0003,$0031,$0601,$0201,$0013,$0201,$0032,$0023,$0401,$0201,$0040,$0004,
 $0041,$4601,$1c01,$0e01,$0601,$0201,$0014,$0201,$0033,$0042,$0401,$0201,
 $0024,$0050,$0201,$0043,$0034,$0401,$0201,$0051,$0015,$0401,$0201,$0005,
 $0052,$0201,$0025,$0201,$0044,$0053,$0e01,$0801,$0401,$0201,$0060,$0006,
 $0201,$0061,$0016,$0401,$0201,$0080,$0008,$0081,$1001,$0801,$0401,$0201,
 $0035,$0062,$0201,$0026,$0054,$0401,$0201,$0045,$0063,$0201,$0036,$0070,
 $0601,$0401,$0201,$0007,$0055,$0071,$0201,$0017,$0201,$0027,$0037,$4801,
 $1801,$0c01,$0401,$0201,$0018,$0082,$0201,$0028,$0401,$0201,$0064,$0046,
 $0072,$0801,$0401,$0201,$0084,$0048,$0201,$0090,$0009,$0201,$0091,$0019,
 $1801,$0e01,$0801,$0401,$0201,$0073,$0065,$0201,$0056,$0074,$0401,$0201,
 $0047,$0066,$0083,$0601,$0201,$0038,$0201,$0075,$0057,$0201,$0092,$0029,
 $0e01,$0801,$0401,$0201,$0067,$0085,$0201,$0058,$0039,$0201,$0093,$0201,
 $0049,$0086,$0601,$0201,$00a0,$0201,$0068,$000a,$0201,$00a1,$001a,$4401,
 $1801,$0c01,$0401,$0201,$00a2,$002a,$0401,$0201,$0095,$0059,$0201,$00a3,
 $003a,$0801,$0401,$0201,$004a,$0096,$0201,$00b0,$000b,$0201,$00b1,$001b,
 $1401,$0801,$0201,$00b2,$0401,$0201,$0076,$0077,$0094,$0601,$0401,$0201,
 $0087,$0078,$00a4,$0401,$0201,$0069,$00a5,$002b,$0c01,$0601,$0401,$0201,
 $005a,$0088,$00b3,$0201,$003b,$0201,$0079,$00a6,$0601,$0401,$0201,$006a,
 $00b4,$00c0,$0401,$0201,$000c,$0098,$00c1,$3c01,$1601,$0a01,$0601,$0201,
 $001c,$0201,$0089,$00b5,$0201,$005b,$00c2,$0401,$0201,$002c,$003c,$0401,
 $0201,$00b6,$006b,$0201,$00c4,$004c,$1001,$0801,$0401,$0201,$00a8,$008a,
 $0201,$00d0,$000d,$0201,$00d1,$0201,$004b,$0201,$0097,$00a7,$0c01,$0601,
 $0201,$00c3,$0201,$007a,$0099,$0401,$0201,$00c5,$005c,$00b7,$0401,$0201,
 $001d,$00d2,$0201,$002d,$0201,$007b,$00d3,$3401,$1c01,$0c01,$0401,$0201,
 $003d,$00c6,$0401,$0201,$006c,$00a9,$0201,$009a,$00d4,$0801,$0401,$0201,
 $00b8,$008b,$0201,$004d,$00c7,$0401,$0201,$007c,$00d5,$0201,$005d,$00e0,
 $0a01,$0401,$0201,$00e1,$001e,$0401,$0201,$000e,$002e,$00e2,$0801,$0401,
 $0201,$00e3,$006d,$0201,$008c,$00e4,$0401,$0201,$00e5,$00ba,$00f0,$2601,
 $1001,$0401,$0201,$00f1,$001f,$0601,$0401,$0201,$00aa,$009b,$00b9,$0201,
 $003e,$0201,$00d6,$00c8,$0c01,$0601,$0201,$004e,$0201,$00d7,$007d,$0201,
 $00ab,$0201,$005e,$00c9,$0601,$0201,$000f,$0201,$009c,$006e,$0201,$00f2,
 $002f,$2001,$1001,$0601,$0401,$0201,$00d8,$008d,$003f,$0601,$0201,$00f3,
 $0201,$00e6,$00ca,$0201,$00f4,$004f,$0801,$0401,$0201,$00bb,$00ac,$0201,
 $00e7,$00f5,$0401,$0201,$00d9,$009d,$0201,$005f,$00e8,$1e01,$0c01,$0601,
 $0201,$006f,$0201,$00f6,$00cb,$0401,$0201,$00bc,$00ad,$00da,$0801,$0201,
 $00f7,$0401,$0201,$007e,$007f,$008e,$0601,$0401,$0201,$009e,$00ae,$00cc,
 $0201,$00f8,$008f,$1201,$0801,$0401,$0201,$00db,$00bd,$0201,$00ea,$00f9,
 $0401,$0201,$009f,$00eb,$0201,$00be,$0201,$00cd,$00fa,$0e01,$0401,$0201,
 $00dd,$00ec,$0601,$0401,$0201,$00e9,$00af,$00dc,$0201,$00ce,$00fb,$0801,
 $0401,$0201,$00bf,$00de,$0201,$00cf,$00ee,$0401,$0201,$00df,$00ef,$0201,
 $00ff,$0201,$00ed,$0201,$00fd,$0201,$00fc,$00fe,$1001,$0601,$0201,$0000,
 $0201,$0010,$0001,$0201,$0011,$0401,$0201,$0020,$0002,$0201,$0021,$0012,
 $3201,$1001,$0601,$0201,$0022,$0201,$0030,$0031,$0601,$0201,$0013,$0201,
 $0003,$0040,$0201,$0032,$0023,$0e01,$0601,$0401,$0201,$0004,$0014,$0041,
 $0401,$0201,$0033,$0042,$0201,$0024,$0043,$0a01,$0601,$0201,$0034,$0201,
 $0050,$0005,$0201,$0051,$0015,$0401,$0201,$0052,$0025,$0401,$0201,$0044,
 $0053,$0061,$5a01,$2401,$1201,$0a01,$0601,$0201,$0035,$0201,$0060,$0006,
 $0201,$0016,$0062,$0401,$0201,$0026,$0054,$0201,$0045,$0063,$0a01,$0601,
 $0201,$0036,$0201,$0070,$0007,$0201,$0071,$0055,$0401,$0201,$0017,$0064,
 $0201,$0072,$0027,$1801,$1001,$0801,$0401,$0201,$0046,$0073,$0201,$0037,
 $0065,$0401,$0201,$0056,$0080,$0201,$0008,$0074,$0401,$0201,$0081,$0018,
 $0201,$0082,$0028,$1001,$0801,$0401,$0201,$0047,$0066,$0201,$0083,$0038,
 $0401,$0201,$0075,$0057,$0201,$0084,$0048,$0601,$0401,$0201,$0090,$0019,
 $0091,$0401,$0201,$0092,$0076,$0201,$0067,$0029,$5c01,$2401,$1201,$0a01,
 $0401,$0201,$0085,$0058,$0401,$0201,$0009,$0077,$0093,$0401,$0201,$0039,
 $0094,$0201,$0049,$0086,$0a01,$0601,$0201,$0068,$0201,$00a0,$000a,$0201,
 $00a1,$001a,$0401,$0201,$00a2,$002a,$0201,$0095,$0059,$1a01,$0e01,$0601,
 $0201,$00a3,$0201,$003a,$0087,$0401,$0201,$0078,$00a4,$0201,$004a,$0096,
 $0601,$0401,$0201,$0069,$00b0,$00b1,$0401,$0201,$001b,$00a5,$00b2,$0e01,
 $0801,$0401,$0201,$005a,$002b,$0201,$0088,$0097,$0201,$00b3,$0201,$0079,
 $003b,$0801,$0401,$0201,$006a,$00b4,$0201,$004b,$00c1,$0401,$0201,$0098,
 $0089,$0201,$001c,$00b5,$5001,$2201,$1001,$0601,$0401,$0201,$005b,$002c,
 $00c2,$0601,$0401,$0201,$000b,$00c0,$00a6,$0201,$00a7,$007a,$0a01,$0401,
 $0201,$00c3,$003c,$0401,$0201,$000c,$0099,$00b6,$0401,$0201,$006b,$00c4,
 $0201,$004c,$00a8,$1401,$0a01,$0401,$0201,$008a,$00c5,$0401,$0201,$00d0,
 $005c,$00d1,$0401,$0201,$00b7,$007b,$0201,$001d,$0201,$000d,$002d,$0c01,
 $0401,$0201,$00d2,$00d3,$0401,$0201,$003d,$00c6,$0201,$006c,$00a9,$0601,
 $0401,$0201,$009a,$00b8,$00d4,$0401,$0201,$008b,$004d,$0201,$00c7,$007c,
 $4401,$2201,$1201,$0a01,$0401,$0201,$00d5,$005d,$0401,$0201,$00e0,$000e,
 $00e1,$0401,$0201,$001e,$00e2,$0201,$00aa,$002e,$0801,$0401,$0201,$00b9,
 $009b,$0201,$00e3,$00d6,$0401,$0201,$006d,$003e,$0201,$00c8,$008c,$1001,
 $0801,$0401,$0201,$00e4,$004e,$0201,$00d7,$007d,$0401,$0201,$00e5,$00ba,
 $0201,$00ab,$005e,$0801,$0401,$0201,$00c9,$009c,$0201,$00f1,$001f,$0601,
 $0401,$0201,$00f0,$006e,$00f2,$0201,$002f,$00e6,$2601,$1201,$0801,$0401,
 $0201,$00d8,$00f3,$0201,$003f,$00f4,$0601,$0201,$004f,$0201,$008d,$00d9,
 $0201,$00bb,$00ca,$0801,$0401,$0201,$00ac,$00e7,$0201,$007e,$00f5,$0801,
 $0401,$0201,$009d,$005f,$0201,$00e8,$008e,$0201,$00f6,$00cb,$2201,$1201,
 $0a01,$0601,$0401,$0201,$000f,$00ae,$006f,$0201,$00bc,$00da,$0401,$0201,
 $00ad,$00f7,$0201,$007f,$00e9,$0801,$0401,$0201,$009e,$00cc,$0201,$00f8,
 $008f,$0401,$0201,$00db,$00bd,$0201,$00ea,$00f9,$1001,$0801,$0401,$0201,
 $009f,$00dc,$0201,$00cd,$00eb,$0401,$0201,$00be,$00fa,$0201,$00af,$00dd,
 $0e01,$0601,$0401,$0201,$00ec,$00ce,$00fb,$0401,$0201,$00bf,$00ed,$0201,
 $00de,$00fc,$0601,$0401,$0201,$00cf,$00fd,$00ee,$0401,$0201,$00df,$00fe,
 $0201,$00ef,$00ff,$0201,$0000,$0601,$0201,$0010,$0201,$0001,$0011,$2a01,
 $0801,$0401,$0201,$0020,$0002,$0201,$0021,$0012,$0a01,$0601,$0201,$0022,
 $0201,$0030,$0003,$0201,$0031,$0013,$0a01,$0401,$0201,$0032,$0023,$0401,
 $0201,$0040,$0004,$0041,$0601,$0201,$0014,$0201,$0033,$0042,$0401,$0201,
 $0024,$0050,$0201,$0043,$0034,$8a01,$2801,$1001,$0601,$0401,$0201,$0005,
 $0015,$0051,$0401,$0201,$0052,$0025,$0401,$0201,$0044,$0035,$0053,$0a01,
 $0601,$0401,$0201,$0060,$0006,$0061,$0201,$0016,$0062,$0801,$0401,$0201,
 $0026,$0054,$0201,$0045,$0063,$0401,$0201,$0036,$0070,$0071,$2801,$1201,
 $0801,$0201,$0017,$0201,$0007,$0201,$0055,$0064,$0401,$0201,$0072,$0027,
 $0401,$0201,$0046,$0065,$0073,$0a01,$0601,$0201,$0037,$0201,$0056,$0008,
 $0201,$0080,$0081,$0601,$0201,$0018,$0201,$0074,$0047,$0201,$0082,$0201,
 $0028,$0066,$1801,$0e01,$0801,$0401,$0201,$0083,$0038,$0201,$0075,$0084,
 $0401,$0201,$0048,$0090,$0091,$0601,$0201,$0019,$0201,$0009,$0076,$0201,
 $0092,$0029,$0e01,$0801,$0401,$0201,$0085,$0058,$0201,$0093,$0039,$0401,
 $0201,$00a0,$000a,$001a,$0801,$0201,$00a2,$0201,$0067,$0201,$0057,$0049,
 $0601,$0201,$0094,$0201,$0077,$0086,$0201,$00a1,$0201,$0068,$0095,$dc01,
 $7e01,$3201,$1a01,$0c01,$0601,$0201,$002a,$0201,$0059,$003a,$0201,$00a3,
 $0201,$0087,$0078,$0801,$0401,$0201,$00a4,$004a,$0201,$0096,$0069,$0401,
 $0201,$00b0,$000b,$00b1,$0a01,$0401,$0201,$001b,$00b2,$0201,$002b,$0201,
 $00a5,$005a,$0601,$0201,$00b3,$0201,$00a6,$006a,$0401,$0201,$00b4,$004b,
 $0201,$000c,$00c1,$1e01,$0e01,$0601,$0401,$0201,$00b5,$00c2,$002c,$0401,
 $0201,$00a7,$00c3,$0201,$006b,$00c4,$0801,$0201,$001d,$0401,$0201,$0088,
 $0097,$003b,$0401,$0201,$00d1,$00d2,$0201,$002d,$00d3,$1201,$0601,$0401,
 $0201,$001e,$002e,$00e2,$0601,$0401,$0201,$0079,$0098,$00c0,$0201,$001c,
 $0201,$0089,$005b,$0e01,$0601,$0201,$003c,$0201,$007a,$00b6,$0401,$0201,
 $004c,$0099,$0201,$00a8,$008a,$0601,$0201,$000d,$0201,$00c5,$005c,$0401,
 $0201,$003d,$00c6,$0201,$006c,$009a,$5801,$5601,$2401,$1001,$0801,$0401,
 $0201,$008b,$004d,$0201,$00c7,$007c,$0401,$0201,$00d5,$005d,$0201,$00e0,
 $000e,$0801,$0201,$00e3,$0401,$0201,$00d0,$00b7,$007b,$0601,$0401,$0201,
 $00a9,$00b8,$00d4,$0201,$00e1,$0201,$00aa,$00b9,$1801,$0a01,$0601,$0401,
 $0201,$009b,$00d6,$006d,$0201,$003e,$00c8,$0601,$0401,$0201,$008c,$00e4,
 $004e,$0401,$0201,$00d7,$00e5,$0201,$00ba,$00ab,$0c01,$0401,$0201,$009c,
 $00e6,$0401,$0201,$006e,$00d8,$0201,$008d,$00bb,$0801,$0401,$0201,$00e7,
 $009d,$0201,$00e8,$008e,$0401,$0201,$00cb,$00bc,$009e,$00f1,$0201,$001f,
 $0201,$000f,$002f,$4201,$3801,$0201,$00f2,$3401,$3201,$1401,$0801,$0201,
 $00bd,$0201,$005e,$0201,$007d,$00c9,$0601,$0201,$00ca,$0201,$00ac,$007e,
 $0401,$0201,$00da,$00ad,$00cc,$0a01,$0601,$0201,$00ae,$0201,$00db,$00dc,
 $0201,$00cd,$00be,$0601,$0401,$0201,$00eb,$00ed,$00ee,$0601,$0401,$0201,
 $00d9,$00ea,$00e9,$0201,$00de,$0401,$0201,$00dd,$00ec,$00ce,$003f,$00f0,
 $0401,$0201,$00f3,$00f4,$0201,$004f,$0201,$00f5,$005f,$0a01,$0201,$00ff,
 $0401,$0201,$00f6,$006f,$0201,$00f7,$007f,$0c01,$0601,$0201,$008f,$0201,
 $00f8,$00f9,$0401,$0201,$009f,$00fa,$00af,$0801,$0401,$0201,$00fb,$00bf,
 $0201,$00fc,$00cf,$0401,$0201,$00fd,$00df,$0201,$00fe,$00ef,$3c01,$0801,
 $0401,$0201,$0000,$0010,$0201,$0001,$0011,$0e01,$0601,$0401,$0201,$0020,
 $0002,$0021,$0201,$0012,$0201,$0022,$0201,$0030,$0003,$0e01,$0401,$0201,
 $0031,$0013,$0401,$0201,$0032,$0023,$0401,$0201,$0040,$0004,$0041,$0801,
 $0401,$0201,$0014,$0033,$0201,$0042,$0024,$0601,$0401,$0201,$0043,$0034,
 $0051,$0601,$0401,$0201,$0050,$0005,$0015,$0201,$0052,$0025,$fa01,$6201,
 $2201,$1201,$0a01,$0401,$0201,$0044,$0053,$0201,$0035,$0201,$0060,$0006,
 $0401,$0201,$0061,$0016,$0201,$0062,$0026,$0801,$0401,$0201,$0054,$0045,
 $0201,$0063,$0036,$0401,$0201,$0071,$0055,$0201,$0064,$0046,$2001,$0e01,
 $0601,$0201,$0072,$0201,$0027,$0037,$0201,$0073,$0401,$0201,$0070,$0007,
 $0017,$0a01,$0401,$0201,$0065,$0056,$0401,$0201,$0080,$0008,$0081,$0401,
 $0201,$0074,$0047,$0201,$0018,$0082,$1001,$0801,$0401,$0201,$0028,$0066,
 $0201,$0083,$0038,$0401,$0201,$0075,$0057,$0201,$0084,$0048,$0801,$0401,
 $0201,$0091,$0019,$0201,$0092,$0076,$0401,$0201,$0067,$0029,$0201,$0085,
 $0058,$5c01,$2201,$1001,$0801,$0401,$0201,$0093,$0039,$0201,$0094,$0049,
 $0401,$0201,$0077,$0086,$0201,$0068,$00a1,$0801,$0401,$0201,$00a2,$002a,
 $0201,$0095,$0059,$0401,$0201,$00a3,$003a,$0201,$0087,$0201,$0078,$004a,
 $1601,$0c01,$0401,$0201,$00a4,$0096,$0401,$0201,$0069,$00b1,$0201,$001b,
 $00a5,$0601,$0201,$00b2,$0201,$005a,$002b,$0201,$0088,$00b3,$1001,$0a01,
 $0601,$0201,$0090,$0201,$0009,$00a0,$0201,$0097,$0079,$0401,$0201,$00a6,
 $006a,$00b4,$0c01,$0601,$0201,$001a,$0201,$000a,$00b0,$0201,$003b,$0201,
 $000b,$00c0,$0401,$0201,$004b,$00c1,$0201,$0098,$0089,$4301,$2201,$1001,
 $0801,$0401,$0201,$001c,$00b5,$0201,$005b,$00c2,$0401,$0201,$002c,$00a7,
 $0201,$007a,$00c3,$0a01,$0601,$0201,$003c,$0201,$000c,$00d0,$0201,$00b6,
 $006b,$0401,$0201,$00c4,$004c,$0201,$0099,$00a8,$1001,$0801,$0401,$0201,
 $008a,$00c5,$0201,$005c,$00d1,$0401,$0201,$00b7,$007b,$0201,$001d,$00d2,
 $0901,$0401,$0201,$002d,$00d3,$0201,$003d,$00c6,$55fa,$0401,$0201,$006c,
 $00a9,$0201,$009a,$00d4,$2001,$1001,$0801,$0401,$0201,$00b8,$008b,$0201,
 $004d,$00c7,$0401,$0201,$007c,$00d5,$0201,$005d,$00e1,$0801,$0401,$0201,
 $001e,$00e2,$0201,$00aa,$00b9,$0401,$0201,$009b,$00e3,$0201,$00d6,$006d,
 $1401,$0a01,$0601,$0201,$003e,$0201,$002e,$004e,$0201,$00c8,$008c,$0401,
 $0201,$00e4,$00d7,$0401,$0201,$007d,$00ab,$00e5,$0a01,$0401,$0201,$00ba,
 $005e,$0201,$00c9,$0201,$009c,$006e,$0801,$0201,$00e6,$0201,$000d,$0201,
 $00e0,$000e,$0401,$0201,$00d8,$008d,$0201,$00bb,$00ca,$4a01,$0201,$00ff,
 $4001,$3a01,$2001,$1001,$0801,$0401,$0201,$00ac,$00e7,$0201,$007e,$00d9,
 $0401,$0201,$009d,$00e8,$0201,$008e,$00cb,$0801,$0401,$0201,$00bc,$00da,
 $0201,$00ad,$00e9,$0401,$0201,$009e,$00cc,$0201,$00db,$00bd,$1001,$0801,
 $0401,$0201,$00ea,$00ae,$0201,$00dc,$00cd,$0401,$0201,$00eb,$00be,$0201,
 $00dd,$00ec,$0801,$0401,$0201,$00ce,$00ed,$0201,$00de,$00ee,$000f,$0401,
 $0201,$00f0,$001f,$00f1,$0401,$0201,$00f2,$002f,$0201,$00f3,$003f,$1201,
 $0801,$0401,$0201,$00f4,$004f,$0201,$00f5,$005f,$0401,$0201,$00f6,$006f,
 $0201,$00f7,$0201,$007f,$008f,$0a01,$0401,$0201,$00f8,$00f9,$0401,$0201,
 $009f,$00af,$00fa,$0801,$0401,$0201,$00fb,$00bf,$0201,$00fc,$00cf,$0401,
 $0201,$00fd,$00df,$0201,$00fe,$00ef,$0201,$0000,$0801,$0401,$0201,$0008,
 $0004,$0201,$0001,$0002,$0801,$0401,$0201,$000c,$000a,$0201,$0003,$0006,
 $0601,$0201,$0009,$0201,$0005,$0007,$0401,$0201,$000e,$000d,$0201,$000f,
 $000b,$1001,$0801,$0401,$0201,$0000,$0001,$0201,$0002,$0003,$0401,$0201,
 $0004,$0005,$0201,$0006,$0007,$0801,$0401,$0201,$0008,$0009,$0201,$000a,
 $000b,$0401,$0201,$000c,$000d,$0201,$000e,$000f);
 SynthWindow: Array[0..511] Of Double = (
 0.000000000,-0.000015259,-0.000015259,-0.000015259,-0.000015259,-0.000015259,
 -0.000015259,-0.000030518,-0.000030518,-0.000030518,-0.000030518,-0.000045776,
 -0.000045776,-0.000061035,-0.000061035,-0.000076294,-0.000076294,-0.000091553,
 -0.000106812,-0.000106812,-0.000122070,-0.000137329,-0.000152588,-0.000167847,
 -0.000198364,-0.000213623,-0.000244141,-0.000259399,-0.000289917,-0.000320435,
 -0.000366211,-0.000396729,-0.000442505,-0.000473022,-0.000534058,-0.000579834,
 -0.000625610,-0.000686646,-0.000747681,-0.000808716,-0.000885010,-0.000961304,
 -0.001037598,-0.001113892,-0.001205444,-0.001296997,-0.001388550,-0.001480103,
 -0.001586914,-0.001693726,-0.001785278,-0.001907349,-0.002014160,-0.002120972,
 -0.002243042,-0.002349854,-0.002456665,-0.002578735,-0.002685547,-0.002792358,
 -0.002899170,-0.002990723,-0.003082275,-0.003173828,0.003250122,0.003326416,
 0.003387451,0.003433228,0.003463745,0.003479004,0.003479004,0.003463745,
 0.003417969,0.003372192,0.003280640,0.003173828,0.003051758,0.002883911,
 0.002700806,0.002487183,0.002227783,0.001937866,0.001617432,0.001266479,
 0.000869751,0.000442505,-0.000030518,-0.000549316,-0.001098633,-0.001693726,
 -0.002334595,-0.003005981,-0.003723145,-0.004486084,-0.005294800,-0.006118774,
 -0.007003784,-0.007919312,-0.008865356,-0.009841919,-0.010848999,-0.011886597,
 -0.012939453,-0.014022827,-0.015121460,-0.016235352,-0.017349243,-0.018463135,
 -0.019577026,-0.020690918,-0.021789551,-0.022857666,-0.023910522,-0.024932861,
 -0.025909424,-0.026840210,-0.027725220,-0.028533936,-0.029281616,-0.029937744,
 -0.030532837,-0.031005859,-0.031387329,-0.031661987,-0.031814575,-0.031845093,
 -0.031738281,-0.031478882,0.031082153,0.030517578,0.029785156,0.028884888,
 0.027801514,0.026535034,0.025085449,0.023422241,0.021575928,0.019531250,
 0.017257690,0.014801025,0.012115479,0.009231567,0.006134033,0.002822876,
 -0.000686646,-0.004394531,-0.008316040,-0.012420654,-0.016708374,-0.021179199,
 -0.025817871,-0.030609131,-0.035552979,-0.040634155,-0.045837402,-0.051132202,
 -0.056533813,-0.061996460,-0.067520142,-0.073059082,-0.078628540,-0.084182739,
 -0.089706421,-0.095169067,-0.100540161,-0.105819702,-0.110946655,-0.115921021,
 -0.120697021,-0.125259399,-0.129562378,-0.133590698,-0.137298584,-0.140670776,
 -0.143676758,-0.146255493,-0.148422241,-0.150115967,-0.151306152,-0.151962280,
 -0.152069092,-0.151596069,-0.150497437,-0.148773193,-0.146362305,-0.143264771,
 -0.139450073,-0.134887695,-0.129577637,-0.123474121,-0.116577148,-0.108856201,
 0.100311279,0.090927124,0.080688477,0.069595337,0.057617188,0.044784546,
 0.031082153,0.016510010,0.001068115,-0.015228271,-0.032379150,-0.050354004,
 -0.069168091,-0.088775635,-0.109161377,-0.130310059,-0.152206421,-0.174789429,
 -0.198059082,-0.221984863,-0.246505737,-0.271591187,-0.297210693,-0.323318481,
 -0.349868774,-0.376800537,-0.404083252,-0.431655884,-0.459472656,-0.487472534,
 -0.515609741,-0.543823242,-0.572036743,-0.600219727,-0.628295898,-0.656219482,
 -0.683914185,-0.711318970,-0.738372803,-0.765029907,-0.791213989,-0.816864014,
 -0.841949463,-0.866363525,-0.890090942,-0.913055420,-0.935195923,-0.956481934,
 -0.976852417,-0.996246338,-1.014617920,-1.031936646,-1.048156738,-1.063217163,
 -1.077117920,-1.089782715,-1.101211548,-1.111373901,-1.120223999,-1.127746582,
 -1.133926392,-1.138763428,-1.142211914,-1.144287109,1.144989014,1.144287109,
 1.142211914,1.138763428,1.133926392,1.127746582,1.120223999,1.111373901,
 1.101211548,1.089782715,1.077117920,1.063217163,1.048156738,1.031936646,
 1.014617920,0.996246338,0.976852417,0.956481934,0.935195923,0.913055420,
 0.890090942,0.866363525,0.841949463,0.816864014,0.791213989,0.765029907,
 0.738372803,0.711318970,0.683914185,0.656219482,0.628295898,0.600219727,
 0.572036743,0.543823242,0.515609741,0.487472534,0.459472656,0.431655884,
 0.404083252,0.376800537,0.349868774,0.323318481,0.297210693,0.271591187,
 0.246505737,0.221984863,0.198059082,0.174789429,0.152206421,0.130310059,
 0.109161377,0.088775635,0.069168091,0.050354004,0.032379150,0.015228271,
 -0.001068115,-0.016510010,-0.031082153,-0.044784546,-0.057617188,-0.069595337,
 -0.080688477,-0.090927124,0.100311279,0.108856201,0.116577148,0.123474121,
 0.129577637,0.134887695,0.139450073,0.143264771,0.146362305,0.148773193,
 0.150497437,0.151596069,0.152069092,0.151962280,0.151306152,0.150115967,
 0.148422241,0.146255493,0.143676758,0.140670776,0.137298584,0.133590698,
 0.129562378,0.125259399,0.120697021,0.115921021,0.110946655,0.105819702,
 0.100540161,0.095169067,0.089706421,0.084182739,0.078628540,0.073059082,
 0.067520142,0.061996460,0.056533813,0.051132202,0.045837402,0.040634155,
 0.035552979,0.030609131,0.025817871,0.021179199,0.016708374,0.012420654,
 0.008316040,0.004394531,0.000686646,-0.002822876,-0.006134033,-0.009231567,
 -0.012115479,-0.014801025,-0.017257690,-0.019531250,-0.021575928,-0.023422241,
 -0.025085449,-0.026535034,-0.027801514,-0.028884888,-0.029785156,-0.030517578,
 0.031082153,0.031478882,0.031738281,0.031845093,0.031814575,0.031661987,
 0.031387329,0.031005859,0.030532837,0.029937744,0.029281616,0.028533936,
 0.027725220,0.026840210,0.025909424,0.024932861,0.023910522,0.022857666,
 0.021789551,0.020690918,0.019577026,0.018463135,0.017349243,0.016235352,
 0.015121460,0.014022827,0.012939453,0.011886597,0.010848999,0.009841919,
 0.008865356,0.007919312,0.007003784,0.006118774,0.005294800,0.004486084,
 0.003723145,0.003005981,0.002334595,0.001693726,0.001098633,0.000549316,
 0.000030518,-0.000442505,-0.000869751,-0.001266479,-0.001617432,-0.001937866,
 -0.002227783,-0.002487183,-0.002700806,-0.002883911,-0.003051758,-0.003173828,
 -0.003280640,-0.003372192,-0.003417969,-0.003463745,-0.003479004,-0.003479004,
 -0.003463745,-0.003433228,-0.003387451,-0.003326416,0.003250122,0.003173828,
 0.003082275,0.002990723,0.002899170,0.002792358,0.002685547,0.002578735,
 0.002456665,0.002349854,0.002243042,0.002120972,0.002014160,0.001907349,
 0.001785278,0.001693726,0.001586914,0.001480103,0.001388550,0.001296997,
 0.001205444,0.001113892,0.001037598,0.000961304,0.000885010,0.000808716,
 0.000747681,0.000686646,0.000625610,0.000579834,0.000534058,0.000473022,
 0.000442505,0.000396729,0.000366211,0.000320435,0.000289917,0.000259399,
 0.000244141,0.000213623,0.000198364,0.000167847,0.000152588,0.000137329,
 0.000122070,0.000106812,0.000106812,0.000091553,0.000076294,0.000076294,
 0.000061035,0.000061035,0.000045776,0.000045776,0.000030518,0.000030518,
 0.000030518,0.000030518,0.000015259,0.000015259,0.000015259,0.000015259,
 0.000015259,0.000015259);
 HuffOffset: Array[0..33] Of Integer = (
 0,0,7,24,0,41,72,103,174,245,316,443,
 570,697,0,1208,1719,1719,1719,1719,1719,1719,1719,1719,
 2230,2230,2230,2230,2230,2230,2230,2230,2742,2773);
 HuffLength: Array[0..33] Of Integer = (
 0,7,17,17,0,31,31,71,71,71,127,127,
 127,511,0,511,511,511,511,511,511,511,511,511,
 512,512,512,512,512,512,512,512,31,31);
 HuffLinBits: Array[0..33] Of Integer = (
 0,0,0,0,0,0,0,0,0,0,0,0,
 0,0,0,0,1,2,3,4,6,8,10,13,
 4,5,6,7,8,9,11,13,0,0);

Type
 TState = Record
  History: Array[0..1,0..511] Of Double;
  Previous: Array[0..1,0..575] Of Double;
  Spectrum: Array[0..1,0..1,0..575] Of Double;
  Quantized: Array[0..1,0..1,0..575] Of Integer;
  Gain, TableNumber, PairCount, BitCount: Array[0..1,0..1] Of Integer;
 End;
 PState = ^TState;
 TTransforms = Record
  Filter: Array[0..31,0..63] Of Double;
  MDCT: Array[0..17,0..35] Of Double;
  CS, CA: Array[0..7] Of Double;
 End;
 PTransforms = ^TTransforms;

Var
 State: PState;
 Transform: PTransforms;
 WAVPosition, WAVRemaining: LongInt;
 WAVBits, WAVAlign, RateIndex, BitRateIndex: Integer;
 Codes: Array[0..1,0..255] Of LongInt;
 CodeLengths: Array[0..1,0..255] Of Byte;
 Frame: Array[0..2047] Of Byte;
 BitPosition, FrameBytes: Integer;
 PaddingRemainder, EncodedFrames: LongInt;

Function LE16(Const B; Offset: Integer): Word;
Type
 TSmallBytes = Array[0..63] Of Byte;
Begin
 LE16 := Word(TSmallBytes(B)[Offset]) Or (Word(TSmallBytes(B)[Offset+1]) Shl 8);
End;

Function LE32(Const B; Offset: Integer): LongInt;
Type
 TSmallBytes = Array[0..63] Of Byte;
Begin
 If TSmallBytes(B)[Offset+3] >= 128 Then Fail('Valeur RIFF depassant 2 Go.');
 LE32 := LongInt(TSmallBytes(B)[Offset]) + LongInt(TSmallBytes(B)[Offset+1])*256
  +
 LongInt(TSmallBytes(B)[Offset+2])*65536 + LongInt(TSmallBytes(B)[Offset+3])*
  16777216;
End;

Function TagIs(Const B; Const Tag: String): Boolean;
Type
 TSmallBytes = Array[0..63] Of Byte;
Var
 J: Integer;
 Equal: Boolean;
Begin
 Equal := True;
 For J := 1 To 4 Do  If TSmallBytes(B)[J-1] <> Ord(Tag[J]) Then Equal := False;
 TagIs := Equal;
End;

Procedure OpenWave;
Var
 B: Array[0..63] Of Byte;
 Position, RiffEnd, ChunkSize, DataStart, DataSize: LongInt;
 Bits, BlockAlign, Code: Integer;
 OldMode: Byte;
 HasFormat, HasData: Boolean;
Begin
 Assign(InputFile, InputName); OldMode := FileMode; FileMode := 0;
 {$I-}Reset(InputFile, 1); Code := IOResult;{$I+}
 FileMode := OldMode;
 If Code <> 0 Then Fail('Ouverture WAV impossible: ' + InputName);
 InputOpen := True;
 {$I-}InputSize := FileSize(InputFile); Code := IOResult;{$I+}
 If (Code <> 0) Or (InputSize < 12) Then Fail(
  'WAV vide, trop grand ou tronque.');
 ReadAt(0, B, 12);
 If Not TagIs(B, 'RIFF') Then Fail(
  'RIFF/WAVE requis (RF64 et RIFX non pris en charge).');
 If (B[8] <> Ord('W')) Or (B[9] <> Ord('A')) Or (B[10] <> Ord('V')) Or (B[11] <>
  Ord('E'))
 Then  Fail('Signature WAVE manquante.');
 RiffEnd := LE32(B, 4);
 If (RiffEnd < 4) Or (RiffEnd > InputSize - 8) Then Fail(
  'Taille RIFF incorrecte.');
 Inc(RiffEnd, 8); Position := 12; HasFormat := False; HasData := False;
 DataStart := 0; DataSize := 0; Bits := 0; BlockAlign := 0;
 While Position < RiffEnd Do Begin
  If RiffEnd - Position < 8 Then Fail('Entete de bloc WAV tronquee.');
  ReadAt(Position, B, 8); ChunkSize := LE32(B, 4); Inc(Position, 8);
  If ChunkSize > RiffEnd - Position Then Fail('Bloc WAV tronque.');
  If TagIs(B, 'fmt ') Then Begin
   If HasFormat Then Fail('Plusieurs blocs fmt non pris en charge.');
   If ChunkSize < 16 Then Fail('Bloc fmt trop court.');
   ReadAt(Position, B, 16);
   If LE16(B, 0) <> 1 Then Fail(
   'WAV PCM entier requis; float, ADPCM et extensible non pris en charge.');
   Header.Channels := LE16(B, 2); Header.Rate := LE32(B, 4);
   BlockAlign := LE16(B, 12); Bits := LE16(B, 14);
   If Not (Header.Channels In [1,2]) Then Fail('WAV mono ou stereo requis.');
   If Not (Bits In [8,16,24,32]) Then Fail(
    'Resolution PCM attendue: 8/16/24/32 bits.');
   If (Header.Rate < 8000) Or (Header.Rate > 192000) Then Fail(
   'Frequence attendue: 8000..192000 Hz.');
   If (BlockAlign <> Header.Channels*(Bits Div 8)) Or
   (LE32(B, 8) <> Header.Rate*BlockAlign) Then Fail(
    'Alignement ou debit PCM incoherent.')
   ;
   HasFormat := True;
  End
  Else If TagIs(B, 'data') Then Begin
   If HasData Then Fail('Plusieurs blocs data non pris en charge.');
   DataStart := Position; DataSize := ChunkSize; HasData := True;
  End;
  Inc(Position, ChunkSize);
  If Odd(ChunkSize) Then Begin
   If Position >= RiffEnd Then Fail('Octet de bourrage RIFF manquant.');
   Inc(Position);
  End;
 End;
 If Not HasFormat Or Not HasData Then Fail('Bloc fmt ou data manquant.');
 If (DataSize = 0) Or (DataSize Mod BlockAlign <> 0) Then Fail(
 'Donnees PCM vides ou echantillon incomplet.');
 WAVPosition := DataStart; WAVRemaining := DataSize;
 WAVBits := Bits; WAVAlign := BlockAlign;
 Case Header.Rate Of 44100: RateIndex := 0; 48000: RateIndex := 1; 32000:
  RateIndex := 2;
 Else Fail('Frequence MPEG-1 requise: 32000, 44100 ou 48000 Hz.');
End;
End;

Procedure PutBits(Value: LongInt; Count: Integer);
Var
 I: Integer;
Begin
 If BitPosition+Count > FrameBytes*8 Then Fail('Depassement de trame MP3.');
 For I := Count-1 Downto 0 Do Begin
  If ((Value Shr I) And 1) <> 0 Then   Frame[BitPosition Div 8] :=
  Frame[BitPosition Div 8] Or (1 Shl (7-(BitPosition Mod 8)));
  Inc(BitPosition);
 End;
End;

Procedure BuildCodes(SetIndex, Table, Node, Length: Integer; Value: LongInt);
Var
 Leaf: Word;
 Direction, Next, Jump: Integer;
Begin
 If (Node < 0) Or (Node >= HuffLength[Table]) Or (Length > 24) Then Fail(
 'Table Huffman invalide.');
 Leaf := HuffTree[HuffOffset[Table]+Node];
 If Leaf < 256 Then Begin
  Codes[SetIndex,Leaf] := Value; CodeLengths[SetIndex,Leaf] := Length; Exit;
 End;
 For Direction := 0 To 1 Do Begin
  Next := Node;
  Repeat
  Leaf := HuffTree[HuffOffset[Table]+Next];
  If Direction = 0 Then Jump := Leaf Shr 8 Else Jump := Leaf And 255;
  Inc(Next,Jump);
  Until Jump < 250;
  BuildCodes(SetIndex,Table,Next,Length+1,Value*2+Direction);
 End;
End;

Procedure InitializeEncoder;
Const
 CI: Array[0..7] Of Double = (-0.6,-0.535,-0.33,-0.185,-0.095,-0.041,-0.0142,-
  0.0037);
Var
 I,J: Integer;
Begin
 New(State); New(Transform); FillChar(State^,SizeOf(State^),0);
 For I := 0 To 31 Do
 For J := 0 To 63 Do  Transform^.Filter[I,J] := Cos((2*I+1)*(16-J)*Pi/64);
 For I := 0 To 17 Do
 For J := 0 To 35 Do  Transform^.MDCT[I,J] := Sin(Pi*(J+0.5)/36)*Cos(Pi*(2*J+
  19)*(2*I+1)/
 72)/9;
 For I := 0 To 7 Do Begin
  Transform^.CS[I] := 1/Sqrt(1+Sqr(CI[I]));
  Transform^.CA[I] := CI[I]*Transform^.CS[I];
 End;
 BuildCodes(0,15,0,0,0); BuildCodes(1,24,0,0,0);
 PaddingRemainder := 0; EncodedFrames := 0;
End;

Procedure AnalyzeGranule(G: Integer);
Var
 Raw: Array[0..255] Of Byte;
 Current: Array[0..1,0..575] Of Double;
 Y: Array[0..63] Of Double;
 T,C,I,J,K,SB,N,Bps,Take: Integer;
 Sample: LongInt;
 Sum,A,B: Double;
Begin
 Bps := WAVBits Div 8;
 For T := 0 To 17 Do Begin
  Take := 32*WAVAlign;
  If WAVRemaining < Take Then Take := WAVRemaining;
  FillChar(Raw,SizeOf(Raw),0);
  If Take > 0 Then Begin
   ReadAt(WAVPosition,Raw,Take); Inc(WAVPosition,Take); Dec(WAVRemaining,Take);
  End;
  For C := 0 To Header.Channels-1 Do Begin
   For I := 511 Downto 32 Do State^.History[C,I] := State^.History[C,I-32];
   For I := 0 To 31 Do Begin
    K := I*WAVAlign+C*Bps; Sample := 0;
    If K < Take Then Begin
     If WAVBits = 8 Then Sample := (LongInt(Raw[K])-128)*256
      Else
     Begin
      Sample := LongInt(Raw[K+Bps-2])+LongInt(Raw[K+Bps-1])*256;
      If Sample >= 32768 Then Dec(Sample,65536);
     End;
    End;
    State^.History[C,31-I] := Sample/32768;
   End;
   For I := 0 To 63 Do Begin
    Sum := 0;
    For J := 0 To 7 Do Begin
     K := I+J*64;
     Sum := Sum+State^.History[C,K]*SynthWindow[K]/32;
    End;
    Y[I] := Sum;
   End;
   For SB := 0 To 31 Do Begin
    Sum := 0;
    For I := 0 To 63 Do Sum := Sum+Y[I]*Transform^.Filter[SB,I];
    If Odd(SB) And Odd(T) Then Sum := -Sum;
    Current[C,SB*18+T] := Sum;
   End;
  End;
 End;
 For C := 0 To Header.Channels-1 Do Begin
  For SB := 0 To 31 Do
  For I := 0 To 17 Do Begin
   Sum := 0;
   For J := 0 To 17 Do Sum := Sum+
   State^.Previous[C,SB*18+J]*Transform^.MDCT[I,J]+
   Current[C,SB*18+J]*Transform^.MDCT[I,J+18];
   State^.Spectrum[G,C,SB*18+I] := Sum;
  End;
  Move(Current[C],State^.Previous[C],SizeOf(Current[C]));
  { Inverse des papillons de reduction d'alias du decodeur. }
  For SB := 1 To 31 Do
  For I := 0 To 7 Do Begin
   K := SB*18-1-I; N := SB*18+I;
   A := State^.Spectrum[G,C,K]; B := State^.Spectrum[G,C,N];
   State^.Spectrum[G,C,K] := A*Transform^.CS[I]+B*Transform^.CA[I];
   State^.Spectrum[G,C,N] := B*Transform^.CS[I]-A*Transform^.CA[I];
  End;
 End;
End;

Function Magnitude(G,C,I: Integer): Integer;Begin
 Magnitude := Abs(State^.Quantized[G,C,I]);
End;

Function HuffCost(G,C,Table,Pairs: Integer): Integer;
Var
 I,X,Y,L,SetIndex,Cost,Limit: Integer;
Begin
 If Table = 15 Then Begin
  SetIndex := 0; Limit := 15;
 End
  Else
 Begin
  SetIndex := 1; Limit := 15+(1 Shl HuffLinBits[Table])-1;
 End;
 Cost := 0;
 For I := 0 To Pairs-1 Do Begin
  X := Magnitude(G,C,I*2); Y := Magnitude(G,C,I*2+1);
  If (X > Limit) Or (Y > Limit) Then Begin
   HuffCost := 30000; Exit;
  End;
  If X > 0 Then Inc(Cost); If Y > 0 Then Inc(Cost);
  If Table <> 15 Then Begin
   If X >= 15 Then Inc(Cost,HuffLinBits[Table]);
   If Y >= 15 Then Inc(Cost,HuffLinBits[Table]);
  End;
  If X > 15 Then X := 15; If Y > 15 Then Y := 15;
  L := CodeLengths[SetIndex,X*16+Y]; Inc(Cost,L);
 End;
 HuffCost := Cost;
End;

Procedure Quantize(G,C,Budget: Integer);
Var
 Powered: Array[0..575] Of Double;
 I,Gain,Pairs,Table,BestTable,BestBits,Cost,Q: Integer;
 Peak,Scale,V: Double;
 TooLarge: Boolean;
Begin
 Peak := 0;
 For I := 0 To 575 Do Begin
  V := Abs(State^.Spectrum[G,C,I]);
  If V > 0 Then Powered[I] := Exp(Ln(V)*0.75) Else Powered[I] := 0;
  If Powered[I] > Peak Then Peak := Powered[I];
 End;
 Gain := 0;
 If Peak > 0 Then Gain := Trunc(210+Ln(Peak/8205)*16/(3*Ln(2)));
 If Gain < 0 Then Gain := 0;
 Repeat
 If Gain > 255 Then Fail('Quantification MP3 impossible.');
 Scale := Exp((210-Gain)*3*Ln(2)/16); TooLarge := False; Pairs := 0;
 For I := 0 To 575 Do Begin
  V := Powered[I]*Scale+0.4054;
  If V > 8206 Then Begin
   TooLarge := True; Q := 8206;
  End Else Q := Trunc(V);
  If Q <> 0 Then Pairs := I Div 2+1;
  If State^.Spectrum[G,C,I] < 0 Then Q := -Q;
  State^.Quantized[G,C,I] := Q;
 End;
 BestBits := 30000; BestTable := 0;
 If Not TooLarge Then Begin
  If Pairs = 0 Then BestBits := 0
   Else
  Begin
   BestTable := 15; BestBits := HuffCost(G,C,15,Pairs);
   For Table := 24 To 31 Do Begin
    Cost := HuffCost(G,C,Table,Pairs);
    If Cost < BestBits Then Begin
     BestBits := Cost; BestTable := Table;
    End;
   End;
  End;
 End;
 If BestBits <= Budget Then Break;
 Inc(Gain);
 Until False;
 State^.Gain[G,C] := Gain; State^.PairCount[G,C] := Pairs;
 State^.TableNumber[G,C] := BestTable; State^.BitCount[G,C] := BestBits;
End;

Procedure EncodePairs(G,C: Integer);
Var
 I,X,Y,A,B,Table,SetIndex: Integer;
Begin
 Table := State^.TableNumber[G,C];
 If Table = 0 Then Exit;
 If Table = 15 Then SetIndex := 0 Else SetIndex := 1;
 For I := 0 To State^.PairCount[G,C]-1 Do Begin
  X := Magnitude(G,C,I*2); Y := Magnitude(G,C,I*2+1); A := X; B := Y;
  If A > 15 Then A := 15; If B > 15 Then B := 15;
  PutBits(Codes[SetIndex,A*16+B],CodeLengths[SetIndex,A*16+B]);
  If (Table <> 15) And (X >= 15) Then PutBits(X-15,HuffLinBits[Table]);
  If X > 0 Then PutBits(Ord(State^.Quantized[G,C,I*2] < 0),1);
  If (Table <> 15) And (Y >= 15) Then PutBits(Y-15,HuffLinBits[Table]);
  If Y > 0 Then PutBits(Ord(State^.Quantized[G,C,I*2+1] < 0),1);
 End;
End;

Procedure EncodeFrame;
Var
 G,C,J,SideBytes,Budget,Padding: Integer;
Begin
 Padding := 0; Inc(PaddingRemainder,(LongInt(BitRateK)*144000) Mod Header.Rate);
 If PaddingRemainder >= Header.Rate Then Begin
  Padding := 1; Dec(PaddingRemainder,Header.Rate);
 End;
 FrameBytes := (LongInt(BitRateK)*144000) Div Header.Rate+Padding;
 If Header.Channels = 1 Then SideBytes := 17 Else SideBytes := 32;
 Budget := (FrameBytes-4-SideBytes)*8 Div (2*Header.Channels);
 If Budget > 4095 Then Budget := 4095;
 For G := 0 To 1 Do Begin
  AnalyzeGranule(G);
  For C := 0 To Header.Channels-1 Do Quantize(G,C,Budget);
 End;
 FillChar(Frame,SizeOf(Frame),0); BitPosition := 0;
 PutBits($7FF,11); PutBits(3,2); PutBits(1,2); PutBits(1,1);
 PutBits(BitRateIndex,4); PutBits(RateIndex,2); PutBits(Padding,1); PutBits(0,
  1);
 If Header.Channels = 1 Then PutBits(3,2) Else PutBits(0,2);
 PutBits(0,2); PutBits(0,1); PutBits(1,1); PutBits(0,2);
 PutBits(0,9);
 If Header.Channels = 1 Then PutBits(0,5) Else PutBits(0,3);
 For C := 0 To Header.Channels-1 Do PutBits(0,4);
 For G := 0 To 1 Do
 For C := 0 To Header.Channels-1 Do Begin
  PutBits(State^.BitCount[G,C],12); PutBits(State^.PairCount[G,C],9);
  PutBits(State^.Gain[G,C],8); PutBits(0,4); PutBits(0,1);
  For J := 0 To 2 Do PutBits(State^.TableNumber[G,C],5);
  PutBits(7,4); PutBits(5,3);
  PutBits(0,1); PutBits(0,1); PutBits(0,1);
 End;
 If BitPosition <> (4+SideBytes)*8 Then Fail('Entete MP3 interne incorrecte.');
 For G := 0 To 1 Do
 For C := 0 To Header.Channels-1 Do EncodePairs(G,C);
 If Written > 2147483600-FrameBytes Then Fail('Sortie MP3 depassant 2 Go.');
 WriteBytes(Frame,FrameBytes); Inc(Written,FrameBytes); Inc(EncodedFrames);
End;

Procedure Convert;
Var
 Code,J: Integer;
Begin
 OpenWave; InitializeEncoder;
 If Exists(OutputName) Then Fail('Le fichier de sortie existe deja: '+
  OutputName);
 Assign(OutputFile,OutputName);
 {$I-}Rewrite(OutputFile,1); Code := IOResult;{$I+}
 If Code <> 0 Then Fail('Creation MP3 impossible.');
 OutputOpen := True; OutputCreated := True; Written := 0;
 WriteLn(EngOut,'Encodage MPEG-1 Layer III ',BitRateK,' kbit/s...');
 While WAVRemaining > 0 Do Begin EngTick(WAVRemaining,-1); EncodeFrame; End;
 { Vidange des retards du filtre polyphase et de la MDCT. }
 For J := 1 To 2 Do EncodeFrame;
 {$I-}Close(InputFile); Code := IOResult;{$I+} InputOpen := False;
 If Code <> 0 Then Fail('Fermeture WAV impossible.');
 {$I-}Close(OutputFile); Code := IOResult;{$I+} OutputOpen := False;
 If Code <> 0 Then Fail('Fermeture MP3 impossible.');
 OutputCreated := False; Dispose(State); Dispose(Transform);
 WriteLn(EngOut,'MP3 cree: ',OutputName);
 WriteLn(EngOut,Header.Rate,' Hz, ',Header.Channels,' canal/canaux, ',EncodedFrames,
 ' trames MPEG.');
End;
Begin
 InputName:=Source; OutputName:=Target; InputOpen:=False; OutputOpen:=False;
 OutputCreated:=False;
 Case BitRateK Of
 32: BitRateIndex:=1; 40: BitRateIndex:=2; 48: BitRateIndex:=3;
 56: BitRateIndex:=4; 64: BitRateIndex:=5; 80: BitRateIndex:=6;
 96: BitRateIndex:=7; 112: BitRateIndex:=8; 128: BitRateIndex:=9;
 160: BitRateIndex:=10; 192: BitRateIndex:=11; 224: BitRateIndex:=12;
 256: BitRateIndex:=13; 320: BitRateIndex:=14;
 Else Fail('Debit MPEG-1 Layer III non pris en charge.');
End;
Convert;
End;

{ Couche d'entree/sortie requise par le decodeur AAC-LC de FFMPEG.PAS }
Var
 ActiveOutput,AacInput: File;
 InputSize: LongInt;
 AacInOpen,AacOutOpen: Boolean;
 AacOutName: String;

Procedure Fail(MessageText: String);
Begin
 EngMsg:=MessageText;
 EngAbort;
End;

Procedure OpenRead(Const Path: String);
Var Old: Byte; Code: Integer;
Begin
 Assign(AacInput,Path); Old:=FileMode; FileMode:=0;
 {$I-}Reset(AacInput,1); Code:=IOResult;{$I+}
 FileMode:=Old;
 If Code<>0 Then Fail('Ouverture impossible: '+Path);
 AacInOpen:=True; InputSize:=FileSize(AacInput);
End;

Procedure ReadAt(Position: LongInt; Var Buffer; Count: Word);
Var Actual: Word; Code: Integer;
Begin
 If (Position<0) Or (Position>InputSize) Or (Count>InputSize-Position) Then Fail('Fichier AAC tronque.');
 {$I-}Seek(AacInput,Position); BlockRead(AacInput,Buffer,Count,Actual); Code:=IOResult;{$I+}
 If (Code<>0) Or (Actual<>Count) Then Fail('Lecture AAC incomplete.');
End;

Procedure OpenWrite(Const Path: String);
Var Code: Integer;
Begin
 Assign(ActiveOutput,Path); AacOutName:=Path;
 {$I-}Rewrite(ActiveOutput,1); Code:=IOResult;{$I+}
 If Code<>0 Then Fail('Creation impossible: '+Path);
 AacOutOpen:=True;
End;

Procedure WriteBytes(Var Buffer; Count: Word);
Var Actual: Word; Code: Integer;
Begin
 {$I-}BlockWrite(ActiveOutput,Buffer,Count,Actual); Code:=IOResult;{$I+}
 If (Code<>0) Or (Actual<>Count) Then Fail('Ecriture impossible (disque plein ?).');
End;

Procedure CloseRead;
Begin
 If AacInOpen Then Begin {$I-}Close(AacInput);{$I+} If IOResult<>0 Then ; AacInOpen:=False; End;
End;

Procedure CloseWrite;
Begin
 If AacOutOpen Then Begin {$I-}Close(ActiveOutput);{$I+} If IOResult<>0 Then ; AacOutOpen:=False; End;
End;

Procedure AacCleanup(Failed: Boolean);
Begin
 CloseRead;
 If AacOutOpen Then Begin
  CloseWrite;
  If Failed Then DelFile(AacOutName);
 End;
End;

{ Native AAC-LC ADTS decoder. Tables/tools adapted from FFmpeg aactab.c,
  aacdec.c, aacdec_proc_template.c and aacdec_dsp_template.c.
  LGPL-2.1-or-later; see THIRD_PARTY_NOTICES.md. }

Procedure DecodeAAC(Const Source,Target:String);
Const
 APi=3.14159265358979323846;
 Roots:Array[0..11] Of Integer=(
 0,120,200,280,360,440,520,600,663,726,894,1062);
 HuffLeft:Array[0..1349] Of Integer=(
 -61,92,90,87,83,79,74,72,67,62,56,52,44,14,18,16,17,-1,42,21,
 -2,-20,29,24,27,26,-120,28,-11,110,113,32,-119,-8,-9,39,37,-12,-15,40,
 -17,-21,-24,-91,49,48,-89,-26,-29,51,-27,-87,55,97,-31,-85,60,58,-86,-37,
 -84,-38,66,65,-83,-82,-81,70,71,-43,-46,-45,73,-75,78,77,-74,-73,-50,82,
 -52,-71,-53,86,-68,-54,-67,89,-56,-57,-63,-58,-60,-62,95,-77,-78,-88,99,100,
 -98,-93,103,-95,-97,-99,107,-101,-103,-104,116,119,-111,114,-107,-109,117,-112,
  -114,-116,
 -41,158,139,153,148,131,136,145,129,130,-1,132,133,-22,135,-19,143,138,-12,172,
 141,142,-5,144,-6,170,152,-73,167,162,151,-8,-81,154,194,-11,157,-13,159,160,
 -68,-15,192,-26,165,-17,-18,168,169,-74,171,-61,173,174,-59,199,-24,-25,-63,-
  28,
 189,-44,-71,187,-34,186,-35,-48,-77,-42,-39,-40,-66,-65,-53,-62,-55,-60,-76,-
  70,
 238,220,209,216,229,206,207,-21,-57,246,257,261,-16,227,215,-55,235,218,226,-6,
 221,222,237,-65,256,-81,-8,245,-9,230,255,-10,242,234,-31,236,-12,-13,239,-41,
 -68,-14,244,-29,-17,-63,273,275,-20,-74,-60,262,253,-50,-35,-54,-25,278,-72,
  260,
 -28,-30,269,-32,268,-69,267,-58,-37,-38,272,-49,-47,-45,-64,-48,-77,-78,-62,-
  75,
 -1,282,283,-28,291,286,332,335,-38,-55,-10,292,-37,294,295,296,-6,298,312,-67,
 -49,-8,314,304,305,336,-9,308,-13,313,-19,-31,-46,-22,324,337,317,-35,328,326,
 330,322,-54,-21,347,-23,327,-25,329,-26,331,-27,-29,349,-30,-41,-65,-44,-47,
  340,
 -36,342,-39,-68,-45,346,-48,-58,-71,-76,-73,357,354,-57,-72,-62,-75,-66,-70,-
  81,
 361,392,414,-37,365,376,391,-2,374,377,371,382,415,-3,375,-4,-5,394,416,390,
 -22,-19,397,-30,408,398,405,388,389,-9,-56,-29,393,-41,395,-17,-15,-16,399,400,
 -18,-21,403,-23,-24,435,439,-25,426,432,433,-70,413,-81,-32,-34,417,-35,419,-
  36,
 -38,-47,423,425,-50,-68,434,-71,-58,-48,438,-49,-51,-52,-53,-66,-79,-75,-67,-
  72,
 -41,508,506,493,478,474,459,456,453,468,471,470,-81,467,490,-64,472,458,-3,463,
 461,462,-4,464,-37,513,-6,-71,469,-8,-73,-74,473,-65,491,476,477,-12,482,480,
 481,-13,483,-14,485,-15,518,-16,-17,-18,-19,501,-21,497,495,496,-22,498,-23,
  500,
 -24,-25,-26,-76,-69,-30,510,-31,509,-32,-49,-34,-47,-54,-38,-59,-42,-55,-70,-
  78,
 580,567,552,548,535,532,542,597,531,541,-1,-8,533,534,-7,545,537,576,-6,540,
 -5,-81,594,-45,-10,560,547,-65,556,550,-70,-12,565,558,555,-13,557,-68,559,-15,
 -16,-17,-63,596,-56,574,-21,568,-31,595,-24,572,573,-23,-57,-75,-28,-47,588,-
  30,
 589,582,-32,-33,-67,593,-36,-38,-52,591,-40,-41,-59,-54,-77,-58,-62,598,-64,-
  72,
 -1,602,-9,604,-10,628,-17,608,629,610,-4,612,613,639,-5,616,640,-43,619,641,
 636,622,-31,643,625,650,-32,-57,-18,630,-26,632,-13,-14,654,-15,-51,-19,-20,-
  28,
 -35,646,-44,648,645,-52,-30,-49,649,-58,-46,652,656,-61,-50,-59,-54,658,-48,-
  60,
 661,-63,-56,664,692,668,-19,-1,-11,670,671,672,-3,674,675,676,-4,698,714,-45,
 700,682,683,684,-53,703,687,720,-7,725,722,-8,-10,-18,-12,705,697,-13,707,-14,
 708,702,-50,704,-16,-20,-21,-42,718,-23,711,-59,-28,-29,-30,716,-31,-32,-38,-
  39,
 -49,-46,-48,-54,-55,-63,-1,728,-14,730,-15,779,-27,734,735,800,-17,-40,780,782,
 816,-5,743,744,783,838,-56,-6,785,750,751,-93,753,754,789,756,757,-8,759,-47,
 761,762,809,764,765,-10,797,820,769,-148,812,772,773,836,775,-12,847,778,-13,-
  28,
 801,-18,-31,802,-20,786,787,-66,-45,790,-23,806,793,794,-24,832,-111,843,799,-
  38,
 -41,-30,-67,804,-46,-107,807,808,-36,845,-110,-134,813,833,815,-39,-55,-48,831,
  -49,
 821,-50,823,853,-51,826,867,-162,829,-106,-58,-61,-158,881,-63,-125,837,-137,-
  68,-69,
 841,-79,-84,878,-73,-74,-101,848,-138,-82,-132,-122,-86,-144,-89,856,857,869,-
  164,876,
 -104,-105,863,-95,-98,866,-149,-113,-102,-139,-121,-114,873,874,875,-115,-116,-
  117,-123,
 880,
 -129,-131,883,884,-141,-142,893,888,-143,-159,-161,-165,-156,-167,900,896,897,
  898,953,-1,
 949,902,903,-2,980,906,-27,996,-4,954,983,1005,-80,914,957,916,917,1015,-93,
  920,
 921,1018,1029,999,-36,926,969,928,929,930,-8,1023,-149,934,1002,1037,937,-158,
  976,940,
 941,942,-11,1060,-12,1048,1053,948,-168,952,-28,-29,-15,-18,982,956,-19,958,
  959,-20,
 961,-106,988,964,-22,966,1009,968,-23,1011,1043,972,-137,993,1013,-25,977,995,-
  115,-128,
 -30,-31,-32,1006,-81,1007,987,-47,989,-60,1021,992,-37,994,-148,-163,-44,-42,-
  69,-49,
 -50,-136,1024,1058,-162,-82,-70,-59,-109,1045,-62,1035,-63,-138,-65,-95,-71,-
  72,1019,-73,
 -74,1042,-75,-76,1051,-150,1027,1059,-103,1030,-120,-84,-85,-98,-87,-88,-102,
  1038,-90,
 1040,
 -91,-108,-100,-146,-101,-111,-112,-116,1052,-157,-145,-126,-129,1057,-130,-139,
  -144,-166,
 -161,-152,
 -153,-167,1063,1064,1065,-1,1133,-2,1134,1070,1071,-38,1178,1074,-52,1076,1077,
  1140,1143,
 1231,
 1081,-5,1083,1084,1085,1237,1264,-6,1089,1090,1253,1155,-174,1094,1095,1129,
  1097,1098,
 1099,-8,
 1101,1102,1103,1104,1163,-9,1226,1298,1283,-154,1172,1112,1113,1315,1314,-11,
  1117,1118,
 1331,-222,
 1333,1122,-254,-15,1322,1126,-14,1346,-16,1197,1307,1279,-17,-289,1135,-20,
  1137,-21,-55,-
 70,
 1141,1180,-23,1144,1212,-24,1147,1184,1274,1285,-34,1152,1153,1154,-221,-128,
  1157,1292,
 1159,-191,
 1266,1336,-29,-30,1165,1166,1167,1223,-31,1208,1171,-260,1271,1174,1284,1329,-
  33,-54,
 1179,-71,
 -40,1211,1233,-41,1185,1348,-281,1234,1189,1190,-43,1192,1193,-127,1241,1196,-
  45,1198,-
 225,1200,
 1201,1202,-196,1335,-48,1258,1328,-49,1270,-50,-72,-57,-106,1214,-122,1289,-60,
  1252,-61,-
 62,
 1221,1222,-129,-189,1225,-131,1295,1228,-101,1230,-68,1261,-69,-74,1235,1236,-
  76,1332,-
 125,1305,
 -78,1304,-159,1244,-80,1246,1247,-243,-165,-87,-91,-108,-94,1260,-95,-96,-273,-
  98,1310,-
 180,
 -103,-107,1303,-109,-110,-224,1267,-147,1269,-116,-206,1311,1319,-215,1275,-
  119,-120,-
 123,-124,-130,
 1281,-132,-133,-257,-135,-282,1337,-211,-138,-140,-141,-143,1293,-175,-258,
  1297,-231,-
 246,1338,-263,
 1320,1302,-200,-153,-173,-157,-176,-193,-192,-163,-164,1312,-167,-168,-216,
  1340,-249,-
 179,-182,-184,
 1321,-185,1325,-186,-187,-188,-194,-195,-197,-199,-232,-203,-287,1345,-237,-
  226,-241,-
 210,-213,-214,
 -218,1344,-269,-250,-236,-239,-270,-266,-280,-276);
 HuffRight:Array[0..1349] Of Integer=(
 1,2,3,4,5,6,7,8,9,10,11,12,13,22,15,98,106,105,19,20,
 -3,-4,23,35,25,33,-5,109,-6,30,31,34,-7,-16,-10,36,38,-13,-14,41,
 -19,-18,43,-22,45,46,47,-23,-25,50,-28,-30,53,54,-32,-33,57,59,-34,-35,
 61,-36,63,64,-39,-40,-41,68,69,-42,-44,-80,94,-47,75,76,-48,-49,-72,80,
 81,-51,-70,84,85,-69,-55,88,-66,-65,91,-64,93,-59,96,-76,-79,-90,102,101,
 -92,-94,104,-96,-105,-100,108,-102,-118,-121,111,112,-106,115,-108,-110,118,-
  113,-115,-
 117,
 121,122,123,124,125,126,127,128,134,178,-75,175,179,-2,196,-3,137,166,-4,140,
 164,193,-29,198,-10,146,147,-7,149,150,197,-30,-9,156,155,-69,161,-67,180,191,
 -14,-31,163,-16,182,-45,-72,183,195,-20,177,-21,185,190,-23,176,-80,-57,-27,-
  54,
 181,-32,-33,184,-56,188,-43,-36,-37,-38,-47,-50,-46,-49,-51,-52,-79,-58,-64,-
  78,
 201,202,203,204,205,213,224,208,-1,210,211,212,-2,214,279,-3,217,259,219,-4,
 232,264,223,-5,225,-7,-18,228,-73,266,231,-52,233,276,-11,249,-56,-59,251,240,
 241,-42,243,-15,-51,-19,247,248,-34,250,-22,252,270,254,-23,-24,-27,258,-26,
  274,
 -70,-80,263,-44,265,-33,277,-36,-71,-40,271,-39,-43,-67,-46,-66,-53,-61,-76,-
  79,
 281,284,290,-2,285,293,287,288,289,-3,-4,307,-5,302,297,300,-64,309,299,-7,
 301,-17,303,318,333,306,-18,311,-11,310,-12,-14,-15,-16,315,316,343,-20,319,
  320,
 321,345,323,-61,325,-43,339,-24,341,350,348,-80,-40,334,-56,-32,-33,338,-34,
  358,
 -74,344,-59,-42,-77,351,355,-50,-51,-52,-53,352,353,356,-60,-69,-63,359,-79,-
  78,
 364,362,363,-1,368,366,367,-11,369,370,384,372,373,381,422,-10,-31,378,379,380,
 -6,-7,383,-8,385,386,387,412,401,-61,-12,-13,420,-14,402,396,-43,-20,418,404,
 -74,-57,421,-33,-62,406,407,-73,409,410,411,-26,436,-27,-28,-55,428,-64,429,-
  80,
 -40,-39,430,424,-42,-44,427,-45,-46,-60,431,-59,-69,-76,-77,-54,437,-63,-65,-
  78,
 441,442,443,444,445,446,447,448,449,450,451,452,-1,454,455,-2,457,517,-79,460,
 465,503,-45,519,-5,466,-46,-7,489,-72,-9,-10,488,-11,475,486,502,-66,479,484,
 504,-53,514,-68,512,-67,487,-20,-27,-80,-75,492,-57,494,499,505,-60,515,-43,
  511,
 -58,-61,-56,-28,-29,-52,507,-51,516,-50,-33,-48,-35,-36,-44,-39,-40,-63,-62,-
  77,
 521,522,523,524,525,526,527,528,529,530,-73,-2,539,562,-3,536,585,538,-4,575,
 -79,-9,543,544,-18,546,561,-11,549,563,551,-26,553,554,577,-53,587,-14,584,-69,
 -71,-46,-19,564,-20,566,-61,571,569,570,-22,578,592,-34,-25,-27,-78,-29,579,-
  43,
 581,583,-51,-49,-35,586,-37,-44,-39,590,-42,-50,-48,-76,-55,-60,-66,599,-74,-
  80,
 601,603,-2,607,605,606,-3,611,609,631,638,618,615,614,-33,634,617,-6,623,620,
 621,647,-7,624,651,626,627,-8,-11,637,-12,633,-34,-42,635,-36,-16,-25,-27,-21,
 -22,642,-23,644,659,-24,-29,-37,655,-38,-39,657,653,-40,-41,-45,-47,660,-62,-
  53,
 662,-55,-64,669,665,666,667,-17,-2,673,695,694,-26,680,677,713,-36,678,679,-5,
 681,685,710,719,-6,686,689,688,-62,690,691,-64,693,-9,-27,696,706,-35,699,-44,
 701,715,-15,717,-47,712,-25,-22,709,-51,723,-24,-34,-43,-37,721,-52,724,-33,-
  58,
 -40,-41,-57,-60,-61,-56,727,729,-2,733,731,732,-3,742,738,736,737,-4,739,740,
 741,-53,752,748,745,746,747,-33,749,803,805,-7,760,791,755,758,817,-120,850,-9,
 770,766,763,795,851,-146,767,768,864,-11,771,855,776,774,854,-163,777,871,-151,
  -16,
 781,-54,-19,784,-44,828,788,-21,-22,840,-94,792,818,842,-96,796,-25,798,889,-
  26,
 -29,-42,-32,830,-34,-35,862,861,-71,810,811,-37,822,814,835,-124,-43,-59,819,-
  145,
 852,-75,825,824,-76,865,827,-52,839,-57,-119,-60,-62,834,-87,-64,846,-65,-80,-
  81,
 849,-70,-72,844,-97,-118,-77,868,-78,-108,-83,-85,-112,-88,-157,872,859,858,-
  90,860,
 -91,-92,870,-133,-160,890,-99,-100,-126,-103,-109,-127,882,879,877,-140,-152,-
  128,-135,
 885,
 -130,-136,886,891,-153,-166,887,892,-155,-147,-150,-154,-169,-168,895,913,909,
  907,899,-
 56,
 901,904,997,-17,905,981,-3,908,-57,910,911,912,-5,919,915,962,960,918,-6,925,
 965,922,923,924,-7,933,927,973,931,1001,-113,932,-9,938,935,936,1014,-10,939,
  945,
 943,1056,-104,944,-155,946,947,1061,-13,950,951,-14,-16,-54,955,998,-67,985,
  1016,-46,
 1041,-21,963,1008,-48,990,967,1046,-99,970,971,1050,-24,974,975,-159,1026,978,
  979,-26,
 -43,-55,-68,984,-33,986,1017,-34,1032,-35,991,1000,-132,1036,-38,-39,-40,-41,-
  45,-119,
 -124,-51,1003,1004,-52,-53,-58,1031,-61,1010,-133,1012,-92,-64,-127,-66,-83,-
  107,1020,-
 110,
 1033,1022,-135,-114,1025,-77,1039,1028,-78,1034,-79,-94,-97,-86,-121,-105,-89,
  1055,-118,
 1047,
 -140,-96,-134,1044,-147,-122,-123,-165,1049,-117,-125,-160,-142,1054,-156,-131,
  -141,-143,
 -151,-164,
 -154,-169,1075,1068,1066,-19,1067,-36,1069,1072,1138,-3,1073,1249,-4,1082,1146,
  1078,1079,
 1080,
 1250,-51,1093,1088,1151,1086,1087,1290,1156,1194,1091,1092,-7,1100,1164,1096,
  1160,1203,
 1326,-65,
 1110,1106,1169,1280,1105,-229,1107,1108,1109,-10,1111,1116,1124,1114,1115,-217,
  1120,1341,
 1119,-12,
 1121,1127,1123,-13,1125,1347,-251,1128,-271,1130,1131,1132,-82,-18,1136,-37,
  1177,-53,
 1139,-22,
 1181,1142,-89,1229,1145,-85,1187,1148,1149,1150,-25,1191,1217,1288,-26,-27,
  1220,1158,
 1276,-28,
 1161,1162,-81,-230,1199,1245,1224,1168,-207,1170,1248,-32,1173,1300,1175,1176,-
  183,-35,
 1210,-39,
 -73,1182,1183,-104,1213,1186,-42,1188,1215,1324,-93,1239,1291,-44,1195,1219,-
  160,1256,-
 46,1205,
 1268,1309,-47,1204,-227,1206,1207,-115,1209,-261,-56,-90,-58,1251,-59,1216,-86,
  1218,-142,
 -112,
 1243,1255,-63,-64,1257,-66,1227,1318,-67,1349,-278,1232,-75,-105,1262,1278,-
  284,1238,-77,
 1240,
 -111,1242,-79,1265,-190,1286,1327,-83,-84,-88,-102,-92,-238,1254,-144,-172,-97,
  -99,1259,-
 100,
 -158,-279,1263,-170,-126,-113,1317,-114,1294,-181,-117,1272,1273,-118,1277,-
  283,-177,-
 121,-285,-146,
 1282,-212,-259,-134,1313,-136,1287,-137,-255,-139,-288,-156,1306,-145,-148,
  1296,-149,-
 150,1299,-151,
 1301,1343,-152,-274,-155,-272,-161,1308,-162,-244,-245,1339,-166,-264,-169,
  1316,-171,-
 178,-198,-248,
 1330,-233,1323,-235,-286,-219,-223,-242,-240,-202,-201,-252,-204,1334,-205,-
  208,-209,-
 228,-262,-247,
 -265,1342,-220,-234,-268,-253,-256,-267,-275,-277);
 LongBands:Array[0..12] Of Integer=(
 41,41,47,49,49,51,47,47,43,43,43,40,40);
 LongOffsets:Array[0..12,0..51] Of Integer=(
 (0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,64,72,80,88,96,108,120,132,144,156,
  172,188,
 212,240,276,320,384,448,512,576,640,704,768,832,896,960,1024,1024,1024,1024,
  1024,1024,
 1024,1024,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,64,72,80,88,96,108,120,132,144,156,
  172,188,
 212,240,276,320,384,448,512,576,640,704,768,832,896,960,1024,1024,1024,1024,
  1024,1024,
 1024,1024,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,64,72,80,88,100,112,124,140,156,172,
  192,216,
 240,268,304,344,384,424,464,504,544,584,624,664,704,744,784,824,864,904,944,
  984,1024,
 1024,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,48,56,64,72,80,88,96,108,120,132,144,160,176,
  196,216,240,
 264,292,320,352,384,416,448,480,512,544,576,608,640,672,704,736,768,800,832,
  864,896,928,
 1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,48,56,64,72,80,88,96,108,120,132,144,160,176,
  196,216,240,
 264,292,320,352,384,416,448,480,512,544,576,608,640,672,704,736,768,800,832,
  864,896,928,
 1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,48,56,64,72,80,88,96,108,120,132,144,160,176,
  196,216,240,
 264,292,320,352,384,416,448,480,512,544,576,608,640,672,704,736,768,800,832,
  864,896,928,
 960,992,1024),
 (0,4,8,12,16,20,24,28,32,36,40,44,52,60,68,76,84,92,100,108,116,124,136,148,
  160,172,188,
 204,220,240,260,284,308,336,364,396,432,468,508,552,600,652,704,768,832,896,
  960,1024,
 1024,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,44,52,60,68,76,84,92,100,108,116,124,136,148,
  160,172,188,
 204,220,240,260,284,308,336,364,396,432,468,508,552,600,652,704,768,832,896,
  960,1024,
 1024,1024,1024,1024),
 (0,8,16,24,32,40,48,56,64,72,80,88,100,112,124,136,148,160,172,184,196,212,228,
  244,260,
 280,300,320,344,368,396,424,456,492,532,572,616,664,716,772,832,896,960,1024,
  1024,1024,
 1024,1024,1024,1024,1024,1024),
 (0,8,16,24,32,40,48,56,64,72,80,88,100,112,124,136,148,160,172,184,196,212,228,
  244,260,
 280,300,320,344,368,396,424,456,492,532,572,616,664,716,772,832,896,960,1024,
  1024,1024,
 1024,1024,1024,1024,1024,1024),
 (0,8,16,24,32,40,48,56,64,72,80,88,100,112,124,136,148,160,172,184,196,212,228,
  244,260,
 280,300,320,344,368,396,424,456,492,532,572,616,664,716,772,832,896,960,1024,
  1024,1024,
 1024,1024,1024,1024,1024,1024),
 (0,12,24,36,48,60,72,84,96,108,120,132,144,156,172,188,204,220,236,252,268,288,
  308,328,
 348,372,396,420,448,476,508,544,580,620,664,712,764,820,880,944,1024,1024,1024,
  1024,1024,
 1024,1024,1024,1024,1024,1024,1024),
 (0,12,24,36,48,60,72,84,96,108,120,132,144,156,172,188,204,220,236,252,268,288,
  308,328,
 348,372,396,420,448,476,508,544,580,620,664,712,764,820,880,944,1024,1024,1024,
  1024,1024,
 1024,1024,1024,1024,1024,1024,1024));
 LongTNS:Array[0..12] Of Integer=(
 31,31,34,40,42,51,46,46,42,42,42,39,39);
 ShortBands:Array[0..12] Of Integer=(
 12,12,12,14,14,14,15,15,15,15,15,15,15);
 ShortOffsets:Array[0..12,0..51] Of Integer=(
 (0,4,8,12,16,20,24,32,40,48,64,92,128,128,128,128,128,128,128,128,128,128,128,
  128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128),
 (0,4,8,12,16,20,24,32,40,48,64,92,128,128,128,128,128,128,128,128,128,128,128,
  128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128),
 (0,4,8,12,16,20,24,32,40,48,64,92,128,128,128,128,128,128,128,128,128,128,128,
  128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128),
 (0,4,8,12,16,20,28,36,44,56,68,80,96,112,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,28,36,44,56,68,80,96,112,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,28,36,44,56,68,80,96,112,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,24,28,36,44,52,64,76,92,108,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,24,28,36,44,52,64,76,92,108,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,24,28,32,40,48,60,72,88,108,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,24,28,32,40,48,60,72,88,108,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,24,28,32,40,48,60,72,88,108,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,24,28,36,44,52,60,72,88,108,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128),
 (0,4,8,12,16,20,24,28,36,44,52,60,72,88,108,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,
  128,128,128,
 128,128,128,128));
 ShortTNS:Array[0..12] Of Integer=(
 9,9,10,14,14,14,14,14,14,14,14,14,14);
 Rates:Array[0..12] Of LongInt=(
 96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350);
Type
 TInfo=Record
  Seq,Shape,MaxBand,Groups,Windows,Bands,TNSMax:Integer;
  GroupLen:Array[0..7] Of Integer;
  Off:Array[0..51] Of Integer;
 End;
 TFilter=Record
  Len,Order,Direction:Integer;
  Coef:Array[0..11] Of Double;
 End;
 TChannel=Record
  Info:TInfo;
  PrevShape:Integer;
  Book:Array[0..119] Of Integer;
  Scale:Array[0..119] Of Double;
  Spec,Overlap:Array[0..1023] Of Double;
  Filters:Array[0..7,0..2] Of TFilter;
  NFilter:Array[0..7] Of Integer;
 End;
 PChannel=^TChannel;
 TWork=Record
  Data:Array[0..8191] Of Byte;
  PCM:Array[0..4095] Of Byte;
  Time:Array[0..2047] Of Double;
  Block:Array[0..2047] Of Double;
  WinLong:Array[0..1,0..1023] Of Double;
  WinShort:Array[0..1,0..127] Of Double;
  MS:Array[0..119] Of Boolean;
 End;
 PWork=^TWork;
Var
 Work:PWork;
 Ch:Array[0..1] Of PChannel;
 Pos,Limit,BitPos,BitLimit,Written,FrameCount,TagSize,Rate:LongInt;
 Header:Array[0..9] Of Byte;
 Channels,RateIndex,FrameSize,HeaderSize,Kind,I,J,C,Count,MSPresent:Integer;
 NoiseLo,NoiseHi:Word;
 Common,GotAudio:Boolean;

Procedure Bad(Const S:String);Begin
 Fail('aac: '+S);
End;

Function Bits(N:Integer):LongInt;
Var
 V:LongInt;
 K:Integer;
Begin
 If (N<0) Or (N>24) Or (N>BitLimit-BitPos) Then Bad(
  'Donnees de trame tronquees.');
 V:=0;
 For K:=1 To N Do Begin
  V:=V*2+((Work^.Data[BitPos Div 8] Shr (7-(BitPos Mod 8))) And 1); Inc(BitPos);
 End; Bits:=V;
End;

Function Huff(Book:Integer):Integer;
Var
 Node,Depth:Integer;
Begin
 Node:=Roots[Book]; Depth:=0;
 Repeat
 If Bits(1)=0 Then Node:=HuffLeft[Node] Else Node:=HuffRight[Node]; Inc(Depth);
 If (Depth>20) Or (Node=0) Then Bad('Code Huffman incorrect.');
 Until Node<0;
 Huff:=-Node-1;
End;

Function Power2(X:Double):Double;Begin
 Power2:=Exp(X*0.69314718055994530942);
End;

Function Dequant(V:Integer):Double;Begin
 If V=0 Then Dequant:=0 Else If V<0 Then Dequant:=-Exp(Ln(-V)*4/3) Else
  Dequant:=Exp(Ln(V)
 *4/3);
End;

Function Noise:Double;
Var
 A,B:LongInt;
Begin
 { Unsigned LCG modulo 2^32 using 16-bit limbs, also with overflow checks. }
 A:=LongInt(NoiseLo)*26125+62303;
 B:=((A Shr 16)+LongInt(NoiseHi)*26125+LongInt(NoiseLo)*25+15470) And 65535;
 NoiseLo:=A And 65535; NoiseHi:=B;
 If B>=32768 Then B:=B-65536;
 Noise:=B*65536.0+NoiseLo;
End;

Procedure ReadInfo(Var Q:TInfo);
Var
 K:Integer;
Begin
 FillChar(Q,SizeOf(Q),0);
 If Bits(1)<>0 Then Bad('Bit ICS reserve non nul.');
 Q.Seq:=Bits(2); Q.Shape:=Bits(1); Q.Groups:=1; Q.GroupLen[0]:=1;
 If Q.Seq=2 Then Begin
  Q.MaxBand:=Bits(4); Q.Windows:=8; Q.Bands:=ShortBands[RateIndex];
  Q.TNSMax:=ShortTNS[RateIndex];
  For K:=0 To 6 Do If Bits(1)<>0 Then Inc(Q.GroupLen[Q.Groups-1]) Else
  Begin
   Inc(Q.Groups); Q.GroupLen[Q.Groups-1]:=1;
  End;
  For K:=0 To 51 Do Q.Off[K]:=ShortOffsets[RateIndex,K];
 End Else
 Begin
  Q.MaxBand:=Bits(6); Q.Windows:=1; Q.Bands:=LongBands[RateIndex];
  Q.TNSMax:=LongTNS[RateIndex];
  For K:=0 To 51 Do Q.Off[K]:=LongOffsets[RateIndex,K];
  If Bits(1)<>0 Then Bad('Prediction interdite en AAC-LC.');
 End;
 If Q.MaxBand>Q.Bands Then Bad('Nombre de bandes ICS incorrect.');
End;

Procedure DecodeChannel(Index:Integer; Shared:Boolean);
Var
 P:PChannel;
 G,B,At,Stop,CB,L,Part,Esc,GlobalGain,SF,NS,ISF,K,W,Base,StartWin,Size:Integer;
 N,V,Dim,Radix,D,T,Width,Res,Comp,NF,PulseCount,PulseBand:Integer;
 Values:Array[0..3] Of Integer;
 PulsePos,PulseAmp:Array[0..3] Of Integer;
 FirstNoise:Boolean;
 Energy,Scale,X:Double;
Begin
 P:=Ch[Index]; GlobalGain:=Bits(8); If Not Shared Then ReadInfo(P^.Info);
 FillChar(P^.Spec,SizeOf(P^.Spec),0); FillChar(P^.Book,SizeOf(P^.Book),0);
 FillChar(P^.NFilter,SizeOf(P^.NFilter),0);
 With P^.Info Do Begin
  If Seq=2 Then L:=3 Else L:=5; Esc:=(1 Shl L)-1;
  For G:=0 To Groups-1 Do Begin
   B:=0;
   While B<MaxBand Do Begin
    CB:=Bits(4); If CB=12 Then Bad('Livre spectral reserve.'); Stop:=B;
    Repeat Part:=Bits(L); Inc(Stop,Part);
    If Stop>MaxBand Then Bad('Section spectrale hors limites.'); Until
     Part<>Esc;
    If Stop=B Then Bad('Section spectrale vide.');
    While B<Stop Do Begin
     P^.Book[G*MaxBand+B]:=CB; Inc(B);
    End;
   End;
  End;
  SF:=GlobalGain; NS:=GlobalGain-90; ISF:=0; FirstNoise:=True;
  For At:=0 To Groups*MaxBand-1 Do Begin
   CB:=P^.Book[At]; Scale:=0;
   Case CB Of
   0: ;
   14,15:
   Begin
    Inc(ISF,Huff(0)-60); If ISF < -155 Then ISF:=-155; If ISF>100 Then ISF:=100;
    Scale:=Power2(-ISF/4);
   End;
   13:
   Begin
    If FirstNoise Then Begin
     Inc(NS,Bits(9)-256); FirstNoise:=False;
    End Else Inc(NS,Huff(0)-60);
    If NS < -100 Then NS:=-100; If NS>155 Then NS:=155; Scale:=Power2(NS/4);
   End;
    Else
   Begin
    Inc(SF,Huff(0)-60); If (SF<0) Or (SF>255) Then Bad(
     'Facteur echelle hors limites.');
    Scale:=Power2((SF-100)/4);
   End;
  End;
  P^.Scale[At]:=Scale;
 End;
 PulseCount:=0;
 If Bits(1)<>0 Then Begin
  If Seq=2 Then Bad('Impulsions interdites avec fenetres courtes.');
  PulseCount:=Bits(2)+1; PulseBand:=Bits(6);
  If PulseBand>=Bands Then Bad('Bande impulsion incorrecte.');
  K:=Off[PulseBand];
  For B:=0 To PulseCount-1 Do Begin
   Inc(K,Bits(5)); If K>=1024 Then Bad('Impulsion hors limites.'); PulsePos[B]:=
    K;
   PulseAmp[B]:=Bits(4);
  End;
 End;
 If Bits(1)<>0 Then
 For W:=0 To Windows-1 Do Begin
  If Seq=2 Then NF:=Bits(1) Else NF:=Bits(2); P^.NFilter[W]:=NF;
  If NF>0 Then Begin
   Res:=Bits(1)+3;
   For B:=0 To NF-1 Do With P^.Filters[W,B] Do Begin
    If Seq=2 Then Begin
     Len:=Bits(4); Order:=Bits(3);
    End Else
    Begin
     Len:=Bits(6); Order:=Bits(5);
    End;
    If (Order>12) Or ((Seq=2) And (Order>7)) Then Bad('Ordre TNS incorrect.');
    If Order>0 Then Begin
     Direction:=Bits(1); Comp:=Bits(1); Width:=Res-Comp;
     For K:=0 To Order-1 Do Begin
      V:=Bits(Width); If V>=(1 Shl (Width-1)) Then Dec(V,1 Shl Width);
      If V>=0 Then X:=(1 Shl (Res-1))-0.5 Else X:=(1 Shl (Res-1))+0.5;
      Coef[K]:=-Sin(V*APi/(2*X));
     End;
    End;
   End;
  End;
 End;
 If Bits(1)<>0 Then Bad('Gain control SSR non pris en charge.');
 StartWin:=0;
 For G:=0 To Groups-1 Do Begin
  For B:=0 To MaxBand-1 Do Begin
   At:=G*MaxBand+B; CB:=P^.Book[At]; Scale:=P^.Scale[At]; Size:=Off[B+1]-Off[B];
   For W:=0 To GroupLen[G]-1 Do Begin
    Base:=(StartWin+W)*128+Off[B];
    If CB=13 Then Begin
     Energy:=0;
     For K:=0 To Size-1 Do Begin
      X:=Noise; P^.Spec[Base+K]:=X; Energy:=Energy+X*X;
     End;
     If Energy>0 Then
     For K:=0 To Size-1 Do P^.Spec[Base+K]:=P^.Spec[Base+K]*Scale/Sqrt(Energy);
    End Else If (CB>0) And (CB<12) Then Begin
     If CB<=4 Then Begin
      Dim:=4; Radix:=3;
     End Else
     Begin
      Dim:=2;
      If CB<=6 Then Radix:=9 Else If CB<=8 Then Radix:=8 Else If CB<=10 Then
       Radix:=
      13 Else Radix:=17;
     End;
     If Size Mod Dim<>0 Then Bad('Largeur bande spectrale incorrecte.');
     K:=0;
     While K<Size Do Begin
      N:=Huff(CB);
      For D:=Dim-1 Downto 0 Do Begin
       Values[D]:=N Mod Radix; N:=N Div Radix;
      End;
      If CB<=2 Then
      For D:=0 To Dim-1 Do Dec(Values[D])
      Else If CB<=6 Then Begin
       If CB>=5 Then
       For D:=0 To Dim-1 Do Dec(Values[D],4)
        Else
       For D:=0 To Dim-1 Do If Values[D]<>0 Then If Bits(1)<>0 Then Values[D]:=-
        Values[D];
      End Else
      For D:=0 To Dim-1 Do If Values[D]<>0 Then If Bits(1)<>0 Then Values[D]:=-
       Values[D];
      If CB=11 Then
      For D:=0 To Dim-1 Do If Abs(Values[D])=16 Then Begin
       Width:=4;
       While Bits(1)<>0 Do Begin
        Inc(Width); If Width>12 Then Bad('Echappement spectral hors limites.');
       End;
       V:=(1 Shl Width)+Bits(Width); If Values[D]<0 Then V:=-V; Values[D]:=V;
      End;
      For D:=0 To Dim-1 Do Begin
       V:=Values[D];
       For T:=0 To PulseCount-1 Do If Base+K+D=PulsePos[T] Then Begin
        If V>0 Then Inc(V,PulseAmp[T]) Else Dec(V,PulseAmp[T]);
       End;
       P^.Spec[Base+K+D]:=Dequant(V)*Scale;
      End;
      Inc(K,Dim);
     End;
    End;
   End;
  End;
  Inc(StartWin,GroupLen[G]);
 End;
End;
End;

Procedure Stereo;
Var
 G,B,W,K,At,Base,Win:Integer;
 L,R,Scale:Double;
Begin
 Win:=0;
 With Ch[1]^.Info Do
 For G:=0 To Groups-1 Do Begin
  For B:=0 To MaxBand-1 Do Begin
   At:=G*MaxBand+B;
   For W:=0 To GroupLen[G]-1 Do Begin
    Base:=(Win+W)*128;
    For K:=Off[B] To Off[B+1]-1 Do Begin
     L:=Ch[0]^.Spec[Base+K]; R:=Ch[1]^.Spec[Base+K];
     If Common And Work^.MS[At] And (Ch[0]^.Book[At]<13) And (Ch[1]^.Book[
      At]<13)
     Then Begin
      Ch[0]^.Spec[Base+K]:=L+R; Ch[1]^.Spec[Base+K]:=L-R;
     End;
     If Ch[1]^.Book[At]>=14 Then Begin
      Scale:=Ch[1]^.Scale[At]; If Ch[1]^.Book[At]=14 Then Scale:=-Scale;
      If (MSPresent<>0) And Work^.MS[At] Then Scale:=-Scale;
      Ch[1]^.Spec[Base+K]:=L*Scale;
     End;
    End;
   End;
  End;
  Inc(Win,GroupLen[G]);
 End;
End;

Procedure ApplyTNS(Index:Integer);
Var
 P:PChannel;
 W,F,Top,Bottom,MaxBand,Start,Stop,Step,K,J,M,N,Order:Integer;
 LPC,Tmp:Array[0..11] Of Double;
 X:Double;
Begin
 P:=Ch[Index]; MaxBand:=P^.Info.MaxBand;
 If MaxBand>P^.Info.TNSMax Then MaxBand:=P^.Info.TNSMax;
 For W:=0 To P^.Info.Windows-1 Do Begin
  Bottom:=P^.Info.Bands;
  For F:=0 To P^.NFilter[W]-1 Do Begin
   Top:=Bottom; Dec(Bottom,P^.Filters[W,F].Len); If Bottom<0 Then Bottom:=0;
   Order:=P^.Filters[W,F].Order;
   If Order>0 Then Begin
    FillChar(LPC,SizeOf(LPC),0);
    For M:=0 To Order-1 Do Begin
     X:=-P^.Filters[W,F].Coef[M];
     For J:=0 To M-1 Do Tmp[J]:=LPC[J]+X*LPC[M-1-J];
     For J:=0 To M-1 Do LPC[J]:=Tmp[J]; LPC[M]:=X;
    End;
    K:=Bottom; If K>MaxBand Then K:=MaxBand; Start:=P^.Info.Off[K];
    K:=Top; If K>MaxBand Then K:=MaxBand; Stop:=P^.Info.Off[K]; N:=Stop-Start;
     Step:=1;
    If P^.Filters[W,F].Direction<>0 Then Begin
     Start:=Stop-1; Step:=-1;
    End;
    Inc(Start,W*128);
    For M:=0 To N-1 Do Begin
     X:=P^.Spec[Start]; K:=M; If K>Order Then K:=Order;
     For J:=1 To K Do X:=X-LPC[J-1]*P^.Spec[Start-J*Step];
     P^.Spec[Start]:=X; Inc(Start,Step);
    End;
   End;
  End;
 End;
End;

Function Bessel(X:Double):Double;
Var
 Term,Sum:Double;
 K:Integer;
Begin
 Term:=1; Sum:=1;
 For K:=1 To 60 Do Begin
  Term:=Term*X*X/(4.0*K*K); Sum:=Sum+Term; If Term<Sum*1E-16 Then Break;
 End; Bessel:=Sum;
End;

Procedure Windows;
Var
 K,N,Which:Integer;
 Sum,X,Alpha:Double;
Begin
 For Which:=0 To 1 Do Begin
  If Which=0 Then Begin
   N:=1024; Alpha:=4;
  End Else
  Begin
   N:=128; Alpha:=6;
  End;
  Sum:=0;
  For K:=0 To N Do Begin
   X:=2.0*K/N-1; Work^.Block[K]:=Bessel(APi*Alpha*Sqrt(1-X*X)); Sum:=Sum+
    Work^.Block[K];
  End;
  X:=0;
  For K:=0 To N-1 Do Begin
   X:=X+Work^.Block[K];
   If Which=0 Then Begin
    Work^.WinLong[0,K]:=Sin(APi*(K+0.5)/(2*N)); Work^.WinLong[1,K]:=Sqrt(X/Sum);
   End
    Else
   Begin
    Work^.WinShort[0,K]:=Sin(APi*(K+0.5)/(2*N)); Work^.WinShort[1,K]:=Sqrt(X/
     Sum);
   End;
  End;
 End;
End;

Procedure Transform(Index,Base,N:Integer);
Var
 I,K:Integer;
 A,C0,C1,C2,Step,Sum:Double;
Begin
 { IMDCT with cosine recurrence: no platform DSP library. }
 For I:=0 To 2*N-1 Do Begin
  A:=APi/N*(I+0.5+N/2); C0:=Cos(A/2); C1:=Cos(1.5*A); Step:=2*Cos(A);
  Sum:=Ch[Index]^.Spec[Base]*C0;
  For K:=1 To N-1 Do Begin
   Sum:=Sum+Ch[Index]^.Spec[Base+K]*C1; C2:=Step*C1-C0; C0:=C1; C1:=C2;
  End;
  Work^.Block[I]:=Sum/N;
 End;
End;

Procedure Synthesis(Index:Integer);
Var
 P:PChannel;
 I,W,At,Shape,Prev,Seq:Integer;
 V:LongInt;
 X,Weight:Double;
Begin
 P:=Ch[Index]; Shape:=P^.Info.Shape; Prev:=P^.PrevShape; Seq:=P^.Info.Seq;
 FillChar(Work^.Time,SizeOf(Work^.Time),0);
 If Seq=2 Then Begin
  For W:=0 To 7 Do Begin
   Transform(Index,W*128,128); At:=448+W*128;
   For I:=0 To 127 Do Begin
    If W=0 Then Weight:=Work^.WinShort[Prev,I] Else Weight:=Work^.WinShort[
     Shape,I];
    Work^.Time[At+I]:=Work^.Time[At+I]+Work^.Block[I]*Weight;
    Work^.Time[At+128+I]:=Work^.Time[At+128+I]+Work^.Block[128+I]*
     Work^.WinShort[Shape,
    127-I];
   End;
  End;
 End Else
 Begin
  Transform(Index,0,1024);
  For I:=0 To 1023 Do Begin
   If Seq=3 Then Begin
    If I<448 Then Weight:=0 Else If I<576 Then Weight:=Work^.WinShort[Prev,I-
    448] Else Weight:=1;
   End
   Else Weight:=Work^.WinLong[Prev,I];
   Work^.Time[I]:=Work^.Block[I]*Weight;
   If Seq=1 Then Begin
    If I<448 Then Weight:=1 Else If I<576 Then Weight:=Work^.WinShort[Shape,575-
    I] Else Weight:=0;
   End
   Else Weight:=Work^.WinLong[Shape,1023-I];
   Work^.Time[I+1024]:=Work^.Block[I+1024]*Weight;
  End;
 End;
 For I:=0 To 1023 Do Begin
  X:=Work^.Time[I]+P^.Overlap[I]; P^.Overlap[I]:=Work^.Time[I+1024];
  If X>32767 Then V:=32767 Else If X < -32768 Then V:=-32768 Else V:=Round(X);
  If V<0 Then Inc(V,65536); At:=(I*Channels+Index)*2; Work^.PCM[At]:=V And 255;
  Work^.PCM[At+1]:=V Shr 8;
 End;
 P^.PrevShape:=Shape;
End;

Procedure WaveHeader;
Var
 B:Array[0..43] Of Byte;
 S:String[4];
 Code:Integer;

Procedure Put16(At:Integer; V:LongInt);Begin
 B[At]:=V And 255; B[At+1]:=(V Shr 8) And 255;
End;

Procedure Put32(At:Integer; V:LongInt);Begin
 Put16(At,V); Put16(At+2,V Shr 16);
End;
Begin
 FillChar(B,SizeOf(B),0); S:='RIFF'; Move(S[1],B[0],4); S:='WAVE'; Move(S[1],B[
  8],4);
 S:='fmt '; Move(S[1],B[12],4); S:='data'; Move(S[1],B[36],4);
 Put32(4,Written+36); Put32(16,16); Put16(20,1); Put16(22,Channels); Put32(24,
  Rate);
 Put32(28,Rate*Channels*2); Put16(32,Channels*2); Put16(34,16); Put32(40,
  Written);
 {$I-}Seek(ActiveOutput,0); Code:=IOResult;{$I+} If Code<>0 Then Bad(
  'Reecriture WAV impossible.'); WriteBytes(B,44);
End;
Begin
 OpenRead(Source); Limit:=InputSize; Pos:=0; Written:=0; FrameCount:=0;
  RateIndex:=-1;
 Channels:=0;
 New(Work); FillChar(Work^,SizeOf(Work^),0);
 For C:=0 To 1 Do Begin
  New(Ch[C]); FillChar(Ch[C]^,SizeOf(TChannel),0);
 End;
 NoiseLo:=$3D4C; NoiseHi:=$1F2E; Windows;
 While Pos<Limit Do Begin
  If Limit-Pos<7 Then Bad('En-tete ADTS tronquee.'); ReadAt(Pos,Header,7);
  If (Header[0]=73) And (Header[1]=68) And (Header[2]=51) Then Begin
   If Limit-Pos<10 Then Bad('ID3 tronque.'); ReadAt(Pos,Header,10);
   If (Header[3]<2) Or (Header[3]>4) Or (Header[4]=255) Then Bad(
   'Version ID3 incorrecte.');
   TagSize:=0;
   For I:=6 To 9 Do Begin
    If Header[I]>127 Then Bad('Taille ID3 incorrecte.'); TagSize:=TagSize*128+
     Header[I];
   End;
   Inc(TagSize,10); If (Header[3]=4) And ((Header[5] And 16)<>0) Then Inc(
    TagSize,10);
   If TagSize>Limit-Pos Then Bad('ID3 tronque.'); Inc(Pos,TagSize);
  End Else
  Begin
   If (Header[0]<>255) Or ((Header[1] And $F6)<>$F0) Then Bad(
   'Synchronisation ADTS incorrecte.');
   If Header[2] Shr 6<>1 Then Bad('Seul le profil AAC-LC est decode.');
   I:=(Header[2] Shr 2) And 15; J:=((Header[2] And 1) Shl 2)+(Header[3] Shr 6);
   If I>12 Then Bad('Frequence ADTS reservee.');
   If (J<1) Or (J>2) Then Bad('Configuration ADTS mono/stereo 1 ou 2 requise.');
   If RateIndex<0 Then Begin
    RateIndex:=I; Rate:=Rates[I]; Channels:=J; OpenWrite(Target); WaveHeader;
   End
   Else If (RateIndex<>I) Or (Channels<>J) Then Bad(
    'Changement de configuration ADTS.');
   If Header[6] And 3<>0 Then Bad(
    'Plusieurs blocs par trame ADTS non pris en charge.');
   HeaderSize:=7; If Header[1] And 1=0 Then HeaderSize:=9;
   FrameSize:=(LongInt(Header[3] And 3) Shl 11)+(Integer(Header[4]) Shl 3)+(
   Header[5] Shr 5);
   If (FrameSize<=HeaderSize) Or (FrameSize>Limit-Pos) Then Bad(
   'Taille ADTS incorrecte ou trame tronquee.');
   ReadAt(Pos+HeaderSize,Work^.Data,FrameSize-HeaderSize); BitPos:=0;
   BitLimit:=LongInt(FrameSize-HeaderSize)*8;
   GotAudio:=False; Common:=False; MSPresent:=0; FillChar(Work^.MS,SizeOf(
    Work^.MS),0);
   Repeat
   Kind:=Bits(3);
   Case Kind Of
   0,1:
   Begin
    If GotAudio Then Bad('Plusieurs elements audio non pris en charge.'); I:=
     Bits(4);
    If ((Kind=0) And (Channels<>1)) Or ((Kind=1) And (Channels<>2)) Then Bad(
    'Element incompatible avec les canaux ADTS.');
    If Kind=1 Then Begin
     Common:=Bits(1)<>0;
     If Common Then Begin
      ReadInfo(Ch[0]^.Info); Ch[1]^.Info:=Ch[0]^.Info; MSPresent:=Bits(2);
      If MSPresent=3 Then Bad('Masque stereo reserve.');
      For I:=0 To Ch[0]^.Info.Groups*Ch[0]^.Info.MaxBand-1 Do Begin
       If MSPresent=1 Then Work^.MS[I]:=Bits(1)<>0 Else Work^.MS[I]:=
        MSPresent=2;
      End;
     End;
    End;
    For C:=0 To Channels-1 Do DecodeChannel(C,Common); If Channels=2 Then
     Stereo;
    GotAudio:=True;
   End;
   4:
   Begin
    I:=Bits(4); J:=Bits(1); Count:=Bits(8); If Count=255 Then Inc(Count,Bits(
     8));
    If J<>0 Then BitPos:=((BitPos+7) Div 8)*8;
    For I:=1 To Count Do J:=Bits(8);
   End;
   6:
   Begin
    Count:=Bits(4); If Count=15 Then Count:=14+Bits(8);
    If Count>0 Then Begin
     I:=Bits(4);
     If (I=13) Or (I=14) Then Bad(
      'Extension HE-AAC SBR/PS non prise en charge.');
     If (I<>0) And (I<>1) Then Bad('Extension AAC non prise en charge.');
     J:=Bits(4);
     For I:=2 To Count Do J:=Bits(8);
    End;
   End;
   7: ;
   Else Bad('Element AAC (PCE/couplage/LFE) non pris en charge.');
  End;
  Until Kind=7;
  If Not GotAudio Then Bad('Trame sans element audio.');
  For C:=0 To Channels-1 Do Begin
   ApplyTNS(C); Synthesis(C);
  End;
  If Written>2147483600-Channels*2048 Then Bad('WAV trop grand.');
  WriteBytes(Work^.PCM,Channels*2048); Inc(Written,Channels*2048); Inc(
   FrameCount);
  Inc(Pos,FrameSize);
 End;
End;
If FrameCount=0 Then Bad('Aucune trame ADTS.');
WaveHeader; CloseRead; CloseWrite;
For C:=0 To 1 Do Dispose(Ch[C]); Dispose(Work);
End;
{$ENDIF}
{$IFDEF FPC}
{ ---- H.264 : decodeur (CAVLC/CABAC, I/P/B) et encodeur Baseline, AAC-LC encodeur ;
  adaptes de FFMPEG.PAS / FFmpeg (LGPL-2.1+) ---- }
Var
 H4VidHook: Procedure(B: Pointer; W,H: LongInt);
Type TEABuffer=Array[0..2147483000] Of Byte; PEABuffer=^TEABuffer;
Const
 H4ChromaDcCoeffTokenLen: Array[0..19] Of Byte=(
  2,0,0,0,6,1,0,0,6,6,3,0,6,7,7,6,
  6,8,8,7
 );
 H4ChromaDcCoeffTokenBits: Array[0..19] Of Byte=(
  1,0,0,0,7,1,0,0,4,6,1,0,3,3,2,5,
  2,3,2,0
 );
 H4Chroma422DcCoeffTokenLen: Array[0..35] Of Byte=(
  1,0,0,0,7,2,0,0,7,7,3,0,9,7,7,5,
  9,9,7,6,10,10,9,7,11,11,10,7,12,12,11,10,
  13,12,12,11
 );
 H4Chroma422DcCoeffTokenBits: Array[0..35] Of Byte=(
  1,0,0,0,15,1,0,0,14,13,1,0,7,12,11,1,
  6,5,10,1,7,6,4,9,7,6,5,8,7,6,5,4,
  7,5,4,4
 );
 H4CoeffTokenLen: Array[0..271] Of Byte=(
  1,0,0,0,6,2,0,0,8,6,3,0,9,8,7,5,10,
  9,8,6,11,10,9,7,13,11,10,8,13,13,11,9,13,13,
  13,10,14,14,13,11,14,14,14,13,15,15,14,14,15,15,15,
  14,16,15,15,15,16,16,16,15,16,16,16,16,16,16,16,16,
  2,0,0,0,6,2,0,0,6,5,3,0,7,6,6,4,8,
  6,6,4,8,7,7,5,9,8,8,6,11,9,9,6,11,11,
  11,7,12,11,11,9,12,12,12,11,12,12,12,11,13,13,13,
  12,13,13,13,13,13,14,13,13,14,14,14,13,14,14,14,14,
  4,0,0,0,6,4,0,0,6,5,4,0,6,5,5,4,7,
  5,5,4,7,5,5,4,7,6,6,4,7,6,6,4,8,7,
  7,5,8,8,7,6,9,8,8,7,9,9,8,8,9,9,9,
  8,10,9,9,9,10,10,10,10,10,10,10,10,10,10,10,10,
  6,0,0,0,6,6,0,0,6,6,6,0,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
 );
 H4CoeffTokenBits: Array[0..271] Of Byte=(
  1,0,0,0,5,1,0,0,7,4,1,0,7,6,5,3,7,
  6,5,3,7,6,5,4,15,6,5,4,11,14,5,4,8,10,
  13,4,15,14,9,4,11,10,13,12,15,14,9,12,11,10,13,
  8,15,1,9,12,11,14,13,8,7,10,9,12,4,6,5,8,
  3,0,0,0,11,2,0,0,7,7,3,0,7,10,9,5,7,
  6,5,4,4,6,5,6,7,6,5,8,15,6,5,4,11,14,
  13,4,15,10,9,4,11,14,13,12,8,10,9,8,15,14,13,
  12,11,10,9,12,7,11,6,8,9,8,10,1,7,6,5,4,
  15,0,0,0,15,14,0,0,11,15,13,0,8,12,14,12,15,
  10,11,11,11,8,9,10,9,14,13,9,8,10,9,8,15,14,
  13,13,11,14,10,12,15,10,13,12,11,14,9,12,8,10,13,
  8,13,7,9,12,9,12,11,10,5,8,7,6,1,4,3,2,
  3,0,0,0,0,1,0,0,4,5,6,0,8,9,10,11,12,
  13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,
  30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,
  47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63
 );
 H4TotalZerosLen: Array[0..255] Of Byte=(
  1,3,3,4,4,5,5,6,6,7,7,8,8,9,9,9,
  3,3,3,3,3,4,4,4,4,5,5,6,6,6,6,0,
  4,3,3,3,4,4,3,3,4,5,5,6,5,6,0,0,
  5,3,4,4,3,3,3,4,3,4,5,5,5,0,0,0,
  4,4,4,3,3,3,3,3,4,5,4,5,0,0,0,0,
  6,5,3,3,3,3,3,3,4,3,6,0,0,0,0,0,
  6,5,3,3,3,2,3,4,3,6,0,0,0,0,0,0,
  6,4,5,3,2,2,3,3,6,0,0,0,0,0,0,0,
  6,6,4,2,2,3,2,5,0,0,0,0,0,0,0,0,
  5,5,3,2,2,2,4,0,0,0,0,0,0,0,0,0,
  4,4,3,3,1,3,0,0,0,0,0,0,0,0,0,0,
  4,4,2,1,3,0,0,0,0,0,0,0,0,0,0,0,
  3,3,1,2,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 );
 H4TotalZerosBits: Array[0..255] Of Byte=(
  1,3,2,3,2,3,2,3,2,3,2,3,2,3,2,1,
  7,6,5,4,3,5,4,3,2,3,2,3,2,1,0,0,
  5,7,6,5,4,3,4,3,2,3,2,1,1,0,0,0,
  3,7,5,4,6,5,4,3,3,2,2,1,0,0,0,0,
  5,4,3,7,6,5,4,3,2,1,1,0,0,0,0,0,
  1,1,7,6,5,4,3,2,1,1,0,0,0,0,0,0,
  1,1,5,4,3,3,2,1,1,0,0,0,0,0,0,0,
  1,1,1,3,3,2,2,1,0,0,0,0,0,0,0,0,
  1,0,1,3,2,1,1,1,0,0,0,0,0,0,0,0,
  1,0,1,3,2,1,1,0,0,0,0,0,0,0,0,0,
  0,1,1,2,1,3,0,0,0,0,0,0,0,0,0,0,
  0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,
  0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
  0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 );
 H4ChromaDcTotalZerosLen: Array[0..11] Of Byte=(
  1,2,3,3,
  1,2,2,0,
  1,1,0,0
 );
 H4ChromaDcTotalZerosBits: Array[0..11] Of Byte=(
  1,1,1,0,
  1,1,0,0,
  1,0,0,0
 );
 H4Chroma422DcTotalZerosLen: Array[0..55] Of Byte=(
  1,3,3,4,4,4,5,5,
  3,2,3,3,3,3,3,0,
  3,3,2,2,3,3,0,0,
  3,2,2,2,3,0,0,0,
  2,2,2,2,0,0,0,0,
  2,2,1,0,0,0,0,0,
  1,1,0,0,0,0,0,0
 );
 H4Chroma422DcTotalZerosBits: Array[0..55] Of Byte=(
  1,2,3,2,3,1,1,0,
  0,1,1,4,5,6,7,0,
  0,1,1,2,6,7,0,0,
  6,0,1,2,7,0,0,0,
  0,1,2,3,0,0,0,0,
  0,1,1,0,0,0,0,0,
  0,1,0,0,0,0,0,0
 );
 H4RunLen: Array[0..111] Of Byte=(
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,2,3,3,0,0,0,0,0,0,0,0,0,0,0,
  2,2,3,3,3,3,0,0,0,0,0,0,0,0,0,0,
  2,3,3,3,3,3,3,0,0,0,0,0,0,0,0,0,
  3,3,3,3,3,3,3,4,5,6,7,8,9,10,11,0
 );
 H4RunBits: Array[0..111] Of Byte=(
  1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,3,2,1,0,0,0,0,0,0,0,0,0,0,0,
  3,0,1,3,2,5,4,0,0,0,0,0,0,0,0,0,
  7,6,5,4,3,2,1,1,1,1,1,1,1,1,1,0
 );
 H4GolombToIntra4X4Cbp: Array[0..47] Of Byte=(
  47,31,15,0,23,27,29,30,7,11,13,14,39,43,45,46,
  16,3,5,10,12,19,21,26,28,35,37,42,44,1,2,4,
  8,17,18,20,24,6,9,22,25,32,33,34,36,40,38,41
 );
 H4GolombToInterCbp: Array[0..47] Of Byte=(
  0,16,1,2,4,8,32,3,5,10,12,15,47,7,11,13,
  14,6,9,31,35,37,42,44,33,34,36,40,39,43,45,46,
  17,18,20,24,19,21,26,28,23,27,29,30,22,25,38,41
 );
 H4CbpGrayIntra: Array[0..15] Of Byte=(
  15,0,7,11,13,14,3,5,10,12,1,2,4,8,6,9
 );
 H4CbpGrayInter: Array[0..15] Of Byte=(
  0,1,2,4,8,3,5,10,12,15,7,11,13,14,6,9
 );
 H4Alpha: Array[0..155] Of Byte=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,5,6,7,8,9,10,12,13,
  15,17,20,22,25,28,32,36,40,45,50,56,63,71,80,90,101,113,127,144,162,182,203,
   226,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
   255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
   255,255,255,255,255,255,255
 );
 H4Beta: Array[0..155] Of Byte=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,3,3,3,3,4,4,4,
  6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,
  18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,
  18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18
 );
 H4Tc0: Array[0..623] Of ShortInt=(
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,1,-1,0,0,1,-1,0,0,1,
  -1,0,0,1,-1,0,1,1,-1,0,1,1,
  -1,1,1,1,-1,1,1,1,-1,1,1,1,
  -1,1,1,1,-1,1,1,2,-1,1,1,2,
  -1,1,1,2,-1,1,1,2,-1,1,2,3,
  -1,1,2,3,-1,2,2,3,-1,2,2,4,
  -1,2,3,4,-1,2,3,4,-1,3,3,5,
  -1,3,4,6,-1,3,4,6,-1,4,5,7,
  -1,4,5,8,-1,4,6,9,-1,5,7,10,
  -1,6,8,11,-1,6,8,13,-1,7,10,14,
  -1,8,11,16,-1,9,12,18,-1,10,13,20,
  -1,11,15,23,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25
 );
 H4CabacInitI: Array[0..2047] Of ShortInt=(
  20,-15,2,54,3,74,20,-15,2,54,3,74,-28,127,-23,104,-6,53,-1,54,7,51,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,41,0,63,0,63,0,63,-9,83,4,86,0,97,-7,72,13,41,3,62,0,11,1,55,
  0,69,-17,127,-13,102,0,82,-7,74,-21,107,-27,127,-31,127,-24,127,-18,95,-27,
   127,-21,114,
  -30,127,-17,123,-12,115,-16,122,-11,115,-12,63,-2,68,-15,84,-13,104,-3,70,-8,
   93,-10,90,
  -30,127,-1,74,-6,97,-7,91,-20,127,-4,56,-5,82,-7,76,-22,125,-7,93,-11,87,-3,
   77,
  -5,71,-4,63,-4,68,-12,84,-7,62,-7,65,8,61,5,56,-2,66,1,64,0,61,-2,78,
  1,50,7,52,10,35,0,44,11,38,1,45,0,46,5,44,31,17,1,51,7,50,28,19,
  16,33,14,62,-13,108,-15,100,-13,101,-13,91,-12,94,-10,88,-16,84,-10,86,-7,83,-
   13,87,
  -19,94,1,70,0,72,-5,74,18,59,-8,102,-15,100,0,95,-4,75,2,72,-11,75,-3,71,
  15,46,-13,69,0,62,0,65,21,37,-15,72,9,57,16,54,0,62,12,72,24,0,15,9,
  8,25,13,18,15,9,13,19,10,37,12,18,6,29,20,33,15,30,4,45,1,58,0,62,
  7,61,12,38,11,45,15,39,11,42,13,44,16,45,12,41,10,49,30,34,18,42,10,55,
  17,51,17,46,0,89,26,-19,22,-17,26,-17,30,-25,28,-20,33,-23,37,-27,33,-23,40,-
   28,
  38,-17,33,-11,40,-15,41,-6,38,1,41,17,30,-6,27,3,26,22,37,-16,35,-4,38,-8,
  38,-3,37,3,38,5,42,0,35,16,39,22,14,48,27,37,21,60,12,68,2,97,-3,71,
  -6,42,-5,50,-3,54,-2,62,0,58,1,63,-2,72,-1,74,-9,91,-5,67,-5,27,-3,39,
  -2,44,0,46,-16,64,-8,68,-10,78,-6,77,-10,86,-12,92,-15,55,-10,60,-6,62,-4,65,
  -12,73,-8,76,-7,80,-9,88,-17,110,-11,97,-20,84,-11,79,-6,73,-4,74,-13,86,-13,
   96,
  -11,97,-19,117,-8,78,-5,33,-4,48,-2,53,-3,62,-13,71,-10,79,-12,86,-13,90,-14,
   97,
  0,0,-6,93,-6,84,-8,79,0,66,-1,71,0,62,-2,60,-2,59,-5,75,-3,62,-4,58,
  -9,66,-1,79,0,71,3,68,10,44,-7,62,15,36,14,40,16,27,12,29,1,44,20,36,
  18,32,5,42,1,48,10,62,17,46,9,64,-12,104,-11,97,-16,96,-7,88,-8,85,-7,85,
  -9,85,-13,88,4,66,-3,77,-3,76,-6,76,10,58,-1,76,-1,83,-7,99,-14,95,2,95,
  0,76,-5,74,0,70,-11,75,1,68,0,65,-14,73,3,62,4,62,-1,68,-13,75,11,55,
  5,64,12,70,15,6,6,19,7,16,12,14,18,13,13,11,13,15,15,16,12,23,13,23,
  15,20,14,26,14,44,17,40,17,47,24,17,21,21,25,22,31,27,22,29,19,35,14,50,
  10,57,7,63,-2,77,-4,82,-3,94,9,69,-12,109,36,-35,36,-34,32,-26,37,-30,44,-32,
  34,-18,34,-15,40,-15,33,-7,35,-5,33,0,38,2,33,13,23,35,13,58,29,-3,26,0,
  22,30,31,-7,35,-15,34,-3,34,3,36,-1,34,5,32,11,35,5,34,12,39,11,30,29,
  34,26,29,39,19,66,31,21,31,31,25,50,-17,120,-20,112,-18,114,-11,85,-15,92,-14,
   89,
  -26,71,-15,81,-14,80,0,68,-14,70,-24,56,-23,68,-24,50,-11,74,23,-13,26,-13,40,
   -15,
  49,-14,44,3,45,6,44,34,33,54,19,82,-3,75,-1,23,1,34,1,43,0,54,-2,55,
  0,61,1,64,0,68,-9,92,-14,106,-13,97,-15,90,-12,90,-18,88,-10,73,-9,79,-14,86,
  -10,73,-10,70,-10,69,-5,66,-9,64,-5,58,2,59,21,-10,24,-11,28,-8,28,-1,29,3,
  29,9,35,20,29,36,14,67,-17,123,-12,115,-16,122,-11,115,-12,63,-2,68,-15,84,-
   13,104,
  -3,70,-8,93,-10,90,-30,127,-17,123,-12,115,-16,122,-11,115,-12,63,-2,68,-15,
   84,-13,104,
  -3,70,-8,93,-10,90,-30,127,-7,93,-11,87,-3,77,-5,71,-4,63,-4,68,-12,84,-7,62,
  -7,65,8,61,5,56,-2,66,1,64,0,61,-2,78,1,50,7,52,10,35,0,44,11,38,
  1,45,0,46,5,44,31,17,1,51,7,50,28,19,16,33,14,62,-13,108,-15,100,-13,101,
  -13,91,-12,94,-10,88,-16,84,-10,86,-7,83,-13,87,-19,94,1,70,0,72,-5,74,18,59,
  -7,93,-11,87,-3,77,-5,71,-4,63,-4,68,-12,84,-7,62,-7,65,8,61,5,56,-2,66,
  1,64,0,61,-2,78,1,50,7,52,10,35,0,44,11,38,1,45,0,46,5,44,31,17,
  1,51,7,50,28,19,16,33,14,62,-13,108,-15,100,-13,101,-13,91,-12,94,-10,88,-16,
   84,
  -10,86,-7,83,-13,87,-19,94,1,70,0,72,-5,74,18,59,24,0,15,9,8,25,13,18,
  15,9,13,19,10,37,12,18,6,29,20,33,15,30,4,45,1,58,0,62,7,61,12,38,
  11,45,15,39,11,42,13,44,16,45,12,41,10,49,30,34,18,42,10,55,17,51,17,46,
  0,89,26,-19,22,-17,26,-17,30,-25,28,-20,33,-23,37,-27,33,-23,40,-28,38,-17,33,
   -11,
  40,-15,41,-6,38,1,41,17,24,0,15,9,8,25,13,18,15,9,13,19,10,37,12,18,
  6,29,20,33,15,30,4,45,1,58,0,62,7,61,12,38,11,45,15,39,11,42,13,44,
  16,45,12,41,10,49,30,34,18,42,10,55,17,51,17,46,0,89,26,-19,22,-17,26,-17,
  30,-25,28,-20,33,-23,37,-27,33,-23,40,-28,38,-17,33,-11,40,-15,41,-6,38,1,41,
   17,
  -17,120,-20,112,-18,114,-11,85,-15,92,-14,89,-26,71,-15,81,-14,80,0,68,-14,70,
   -24,56,
  -23,68,-24,50,-11,74,-14,106,-13,97,-15,90,-12,90,-18,88,-10,73,-9,79,-14,86,-
   10,73,
  -10,70,-10,69,-5,66,-9,64,-5,58,2,59,23,-13,26,-13,40,-15,49,-14,44,3,45,6,
  44,34,33,54,19,82,21,-10,24,-11,28,-8,28,-1,29,3,29,9,35,20,29,36,14,67,
  -3,75,-1,23,1,34,1,43,0,54,-2,55,0,61,1,64,0,68,-9,92,-17,120,-20,112,
  -18,114,-11,85,-15,92,-14,89,-26,71,-15,81,-14,80,0,68,-14,70,-24,56,-23,68,-
   24,50,
  -11,74,-14,106,-13,97,-15,90,-12,90,-18,88,-10,73,-9,79,-14,86,-10,73,-10,70,-
   10,69,
  -5,66,-9,64,-5,58,2,59,23,-13,26,-13,40,-15,49,-14,44,3,45,6,44,34,33,54,
  19,82,21,-10,24,-11,28,-8,28,-1,29,3,29,9,35,20,29,36,14,67,-3,75,-1,23,
  1,34,1,43,0,54,-2,55,0,61,1,64,0,68,-9,92,-6,93,-6,84,-8,79,0,66,
  -1,71,0,62,-2,60,-2,59,-5,75,-3,62,-4,58,-9,66,-1,79,0,71,3,68,10,44,
  -7,62,15,36,14,40,16,27,12,29,1,44,20,36,18,32,5,42,1,48,10,62,17,46,
  9,64,-12,104,-11,97,-16,96,-7,88,-8,85,-7,85,-9,85,-13,88,4,66,-3,77,-3,76,
  -6,76,10,58,-1,76,-1,83,-6,93,-6,84,-8,79,0,66,-1,71,0,62,-2,60,-2,59,
  -5,75,-3,62,-4,58,-9,66,-1,79,0,71,3,68,10,44,-7,62,15,36,14,40,16,27,
  12,29,1,44,20,36,18,32,5,42,1,48,10,62,17,46,9,64,-12,104,-11,97,-16,96,
  -7,88,-8,85,-7,85,-9,85,-13,88,4,66,-3,77,-3,76,-6,76,10,58,-1,76,-1,83,
  15,6,6,19,7,16,12,14,18,13,13,11,13,15,15,16,12,23,13,23,15,20,14,26,
  14,44,17,40,17,47,24,17,21,21,25,22,31,27,22,29,19,35,14,50,10,57,7,63,
  -2,77,-4,82,-3,94,9,69,-12,109,36,-35,36,-34,32,-26,37,-30,44,-32,34,-18,34,-
   15,
  40,-15,33,-7,35,-5,33,0,38,2,33,13,23,35,13,58,15,6,6,19,7,16,12,14,
  18,13,13,11,13,15,15,16,12,23,13,23,15,20,14,26,14,44,17,40,17,47,24,17,
  21,21,25,22,31,27,22,29,19,35,14,50,10,57,7,63,-2,77,-4,82,-3,94,9,69,
  -12,109,36,-35,36,-34,32,-26,37,-30,44,-32,34,-18,34,-15,40,-15,33,-7,35,-5,
   33,0,
  38,2,33,13,23,35,13,58,-3,71,-6,42,-5,50,-3,54,-2,62,0,58,1,63,-2,72,
  -1,74,-9,91,-5,67,-5,27,-3,39,-2,44,0,46,-16,64,-8,68,-10,78,-6,77,-10,86,
  -12,92,-15,55,-10,60,-6,62,-4,65,-12,73,-8,76,-7,80,-9,88,-17,110,-3,71,-6,42,
  -5,50,-3,54,-2,62,0,58,1,63,-2,72,-1,74,-9,91,-5,67,-5,27,-3,39,-2,44,
  0,46,-16,64,-8,68,-10,78,-6,77,-10,86,-12,92,-15,55,-10,60,-6,62,-4,65,-12,73,
  -8,76,-7,80,-9,88,-17,110,-3,70,-8,93,-10,90,-30,127,-3,70,-8,93,-10,90,-30,
   127,
  -3,70,-8,93,-10,90,-30,127
 );
 H4CabacInitPB: Array[0..6143] Of ShortInt=(
  20,-15,2,54,3,74,20,-15,2,54,3,74,-28,127,-23,104,-6,53,-1,54,7,51,23,33,
  23,2,21,0,1,9,0,49,-37,118,5,57,-13,78,-11,65,1,62,12,49,-4,73,17,50,
  18,64,9,43,29,0,26,67,16,90,9,104,-46,127,-20,104,1,67,-13,78,-11,65,1,62,
  -6,86,-17,95,-6,61,9,45,-3,69,-6,81,-11,96,6,55,7,67,-5,86,2,88,0,58,
  -3,76,-10,94,5,54,4,69,-3,81,0,88,-7,67,-5,74,-4,74,-5,80,-7,72,1,58,
  0,41,0,63,0,63,0,63,-9,83,4,86,0,97,-7,72,13,41,3,62,0,45,-4,78,
  -3,96,-27,126,-28,98,-25,101,-23,67,-28,82,-20,94,-16,83,-22,110,-21,91,-18,
   102,-13,93,
  -29,127,-7,92,-5,89,-7,96,-13,108,-3,46,-1,65,-1,57,-9,93,-3,74,-9,92,-8,87,
  -23,126,5,54,6,60,6,59,6,69,-1,48,0,68,-4,69,-8,88,-2,85,-6,78,-1,75,
  -7,77,2,54,5,50,-3,68,1,50,6,42,-4,81,1,63,-4,70,0,67,2,57,-2,76,
  11,35,4,64,1,61,11,35,18,25,12,24,13,29,13,36,-10,93,-7,73,-2,73,13,46,
  9,49,-7,100,9,53,2,53,5,53,-2,61,0,56,0,56,-13,63,-5,60,-1,62,4,57,
  -6,69,4,57,14,39,4,51,13,68,3,64,1,61,9,63,7,50,16,39,5,44,4,52,
  11,48,-5,60,-1,59,0,59,22,33,5,44,14,43,-1,78,0,60,9,69,11,28,2,40,
  3,44,0,49,0,46,2,44,2,51,0,47,4,39,2,62,6,46,0,54,3,54,2,58,
  4,63,6,51,6,57,7,53,6,52,6,55,11,45,14,36,8,53,-1,82,7,55,-3,78,
  15,46,22,31,-1,84,25,7,30,-7,28,3,28,4,32,0,34,-1,30,6,30,6,32,9,
  31,19,26,27,26,30,37,20,28,34,17,70,1,67,5,59,9,67,16,30,18,32,18,35,
  22,29,24,31,23,38,18,43,20,41,11,63,9,59,9,64,-1,94,-2,89,-9,108,-6,76,
  -2,44,0,45,0,52,-3,64,-2,59,-4,70,-4,75,-8,82,-17,102,-9,77,3,24,0,42,
  0,48,0,55,-6,59,-7,71,-12,83,-11,87,-30,119,1,58,-3,29,-1,36,1,38,2,43,
  -6,55,0,58,0,64,-3,74,-10,90,0,70,-4,29,5,31,7,42,1,59,-2,58,-3,72,
  -3,81,-11,97,0,58,8,5,10,14,14,18,13,27,2,40,0,58,-3,70,-6,79,-8,85,
  0,0,-13,106,-16,106,-10,87,-21,114,-18,110,-14,98,-22,110,-21,106,-18,103,-21,
   107,-23,108,
  -26,112,-10,96,-12,95,-5,91,-9,93,-22,94,-5,86,9,67,-4,80,-10,85,-1,70,7,60,
  9,58,5,61,12,50,15,50,18,49,17,54,10,41,7,46,-1,51,7,49,8,52,9,41,
  6,47,2,55,13,41,10,44,6,50,5,53,13,49,4,63,6,64,-2,69,-2,59,6,70,
  10,44,9,31,12,43,3,53,14,34,10,38,-3,52,13,40,17,32,7,44,7,38,13,50,
  10,57,26,43,14,11,11,14,9,11,18,11,21,9,23,-2,32,-15,32,-15,34,-21,39,-23,
  42,-33,41,-31,46,-28,38,-12,21,29,45,-24,53,-45,48,-26,65,-43,43,-19,39,-10,
   30,9,
  18,26,20,27,0,57,-14,82,-5,75,-19,97,-35,125,27,0,28,0,31,-4,27,6,34,8,
  30,10,24,22,33,19,22,32,26,31,21,41,26,44,23,47,16,65,14,71,8,60,6,63,
  17,65,21,24,23,20,26,23,27,32,28,23,28,24,23,40,24,32,28,29,23,42,19,57,
  22,53,22,61,11,86,12,40,11,51,14,59,-4,79,-7,71,-5,69,-9,70,-8,66,-10,68,
  -19,73,-12,69,-16,70,-15,67,-20,62,-19,70,-16,66,-22,65,-20,63,9,-2,26,-9,33,-
   9,
  39,-7,41,-2,45,3,49,9,45,27,36,59,-6,66,-7,35,-7,42,-8,45,-5,48,-12,56,
  -6,60,-5,62,-8,66,-8,76,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,
  -9,71,-9,67,-1,61,-8,66,-14,66,0,59,2,59,21,-13,33,-14,39,-7,46,-2,51,2,
  60,6,61,17,55,34,42,62,-7,92,-5,89,-7,96,-13,108,-3,46,-1,65,-1,57,-9,93,
  -3,74,-9,92,-8,87,-23,126,-7,92,-5,89,-7,96,-13,108,-3,46,-1,65,-1,57,-9,93,
  -3,74,-9,92,-8,87,-23,126,-2,85,-6,78,-1,75,-7,77,2,54,5,50,-3,68,1,50,
  6,42,-4,81,1,63,-4,70,0,67,2,57,-2,76,11,35,4,64,1,61,11,35,18,25,
  12,24,13,29,13,36,-10,93,-7,73,-2,73,13,46,9,49,-7,100,9,53,2,53,5,53,
  -2,61,0,56,0,56,-13,63,-5,60,-1,62,4,57,-6,69,4,57,14,39,4,51,13,68,
  -2,85,-6,78,-1,75,-7,77,2,54,5,50,-3,68,1,50,6,42,-4,81,1,63,-4,70,
  0,67,2,57,-2,76,11,35,4,64,1,61,11,35,18,25,12,24,13,29,13,36,-10,93,
  -7,73,-2,73,13,46,9,49,-7,100,9,53,2,53,5,53,-2,61,0,56,0,56,-13,63,
  -5,60,-1,62,4,57,-6,69,4,57,14,39,4,51,13,68,11,28,2,40,3,44,0,49,
  0,46,2,44,2,51,0,47,4,39,2,62,6,46,0,54,3,54,2,58,4,63,6,51,
  6,57,7,53,6,52,6,55,11,45,14,36,8,53,-1,82,7,55,-3,78,15,46,22,31,
  -1,84,25,7,30,-7,28,3,28,4,32,0,34,-1,30,6,30,6,32,9,31,19,26,27,
  26,30,37,20,28,34,17,70,11,28,2,40,3,44,0,49,0,46,2,44,2,51,0,47,
  4,39,2,62,6,46,0,54,3,54,2,58,4,63,6,51,6,57,7,53,6,52,6,55,
  11,45,14,36,8,53,-1,82,7,55,-3,78,15,46,22,31,-1,84,25,7,30,-7,28,3,
  28,4,32,0,34,-1,30,6,30,6,32,9,31,19,26,27,26,30,37,20,28,34,17,70,
  -4,79,-7,71,-5,69,-9,70,-8,66,-10,68,-19,73,-12,69,-16,70,-15,67,-20,62,-19,
   70,
  -16,66,-22,65,-20,63,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,-9,
   71,
  -9,67,-1,61,-8,66,-14,66,0,59,2,59,9,-2,26,-9,33,-9,39,-7,41,-2,45,3,
  49,9,45,27,36,59,21,-13,33,-14,39,-7,46,-2,51,2,60,6,61,17,55,34,42,62,
  -6,66,-7,35,-7,42,-8,45,-5,48,-12,56,-6,60,-5,62,-8,66,-8,76,-4,79,-7,71,
  -5,69,-9,70,-8,66,-10,68,-19,73,-12,69,-16,70,-15,67,-20,62,-19,70,-16,66,-22,
   65,
  -20,63,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,-9,71,-9,67,-1,61,
  -8,66,-14,66,0,59,2,59,9,-2,26,-9,33,-9,39,-7,41,-2,45,3,49,9,45,27,
  36,59,21,-13,33,-14,39,-7,46,-2,51,2,60,6,61,17,55,34,42,62,-6,66,-7,35,
  -7,42,-8,45,-5,48,-12,56,-6,60,-5,62,-8,66,-8,76,-13,106,-16,106,-10,87,-21,
   114,
  -18,110,-14,98,-22,110,-21,106,-18,103,-21,107,-23,108,-26,112,-10,96,-12,95,-
   5,91,-9,93,
  -22,94,-5,86,9,67,-4,80,-10,85,-1,70,7,60,9,58,5,61,12,50,15,50,18,49,
  17,54,10,41,7,46,-1,51,7,49,8,52,9,41,6,47,2,55,13,41,10,44,6,50,
  5,53,13,49,4,63,6,64,-13,106,-16,106,-10,87,-21,114,-18,110,-14,98,-22,110,-
   21,106,
  -18,103,-21,107,-23,108,-26,112,-10,96,-12,95,-5,91,-9,93,-22,94,-5,86,9,67,-
   4,80,
  -10,85,-1,70,7,60,9,58,5,61,12,50,15,50,18,49,17,54,10,41,7,46,-1,51,
  7,49,8,52,9,41,6,47,2,55,13,41,10,44,6,50,5,53,13,49,4,63,6,64,
  14,11,11,14,9,11,18,11,21,9,23,-2,32,-15,32,-15,34,-21,39,-23,42,-33,41,-31,
  46,-28,38,-12,21,29,45,-24,53,-45,48,-26,65,-43,43,-19,39,-10,30,9,18,26,20,
   27,
  0,57,-14,82,-5,75,-19,97,-35,125,27,0,28,0,31,-4,27,6,34,8,30,10,24,22,
  33,19,22,32,26,31,21,41,26,44,23,47,16,65,14,71,14,11,11,14,9,11,18,11,
  21,9,23,-2,32,-15,32,-15,34,-21,39,-23,42,-33,41,-31,46,-28,38,-12,21,29,45,-
   24,
  53,-45,48,-26,65,-43,43,-19,39,-10,30,9,18,26,20,27,0,57,-14,82,-5,75,-19,97,
  -35,125,27,0,28,0,31,-4,27,6,34,8,30,10,24,22,33,19,22,32,26,31,21,41,
  26,44,23,47,16,65,14,71,-6,76,-2,44,0,45,0,52,-3,64,-2,59,-4,70,-4,75,
  -8,82,-17,102,-9,77,3,24,0,42,0,48,0,55,-6,59,-7,71,-12,83,-11,87,-30,119,
  1,58,-3,29,-1,36,1,38,2,43,-6,55,0,58,0,64,-3,74,-10,90,-6,76,-2,44,
  0,45,0,52,-3,64,-2,59,-4,70,-4,75,-8,82,-17,102,-9,77,3,24,0,42,0,48,
  0,55,-6,59,-7,71,-12,83,-11,87,-30,119,1,58,-3,29,-1,36,1,38,2,43,-6,55,
  0,58,0,64,-3,74,-10,90,-3,74,-9,92,-8,87,-23,126,-3,74,-9,92,-8,87,-23,126,
  -3,74,-9,92,-8,87,-23,126,20,-15,2,54,3,74,20,-15,2,54,3,74,-28,127,-23,104,
  -6,53,-1,54,7,51,22,25,34,0,16,0,-2,9,4,41,-29,118,2,65,-6,71,-13,79,
  5,52,9,50,-3,70,10,54,26,34,19,22,40,0,57,2,41,36,26,69,-45,127,-15,101,
  -4,76,-6,71,-13,79,5,52,6,69,-13,90,0,52,8,43,-2,69,-5,82,-10,96,2,59,
  2,75,-3,87,-3,100,1,56,-3,74,-6,85,0,59,-3,81,-7,86,-5,95,-1,66,-1,77,
  1,70,-2,86,-5,72,0,61,0,41,0,63,0,63,0,63,-9,83,4,86,0,97,-7,72,
  13,41,3,62,13,15,7,51,2,80,-39,127,-18,91,-17,96,-26,81,-35,98,-24,102,-23,97,
  -27,119,-24,99,-21,110,-18,102,-36,127,0,80,-5,89,-7,94,-4,92,0,39,0,65,-15,
   84,
  -35,127,-2,73,-12,104,-9,91,-31,127,3,55,7,56,7,55,8,61,-3,53,0,68,-7,74,
  -9,88,-13,103,-13,91,-9,89,-14,92,-8,76,-12,87,-23,110,-24,105,-10,78,-20,112,
   -17,99,
  -78,127,-70,127,-50,127,-46,127,-4,66,-5,78,-4,71,-8,72,2,59,-1,55,-7,70,-6,
   75,
  -8,89,-34,119,-3,75,32,20,30,22,-44,127,0,54,-5,61,0,58,-1,60,-3,61,-8,67,
  -25,84,-14,74,-5,65,5,52,2,57,0,61,-9,69,-11,70,18,55,-4,71,0,58,7,61,
  9,41,18,25,9,32,5,43,9,47,0,44,0,51,2,46,19,38,-4,66,15,38,12,42,
  9,34,0,89,4,45,10,28,10,31,33,-11,52,-43,18,15,28,0,35,-22,38,-25,34,0,
  39,-18,32,-12,102,-94,0,0,56,-15,33,-4,29,10,37,-5,51,-29,39,-9,52,-34,69,-58,
  67,-63,44,-5,32,7,55,-29,32,1,0,0,27,36,33,-25,34,-30,36,-28,38,-28,38,-27,
  34,-18,35,-16,34,-14,32,-8,37,-6,35,0,30,10,28,18,26,25,29,41,0,75,2,72,
  8,77,14,35,18,31,17,35,21,30,17,45,20,42,18,45,27,26,16,54,7,66,16,56,
  11,73,10,67,-10,116,-23,112,-15,71,-7,61,0,53,-5,66,-11,77,-9,80,-9,84,-10,87,
  -34,127,-21,101,-3,39,-5,53,-7,61,-11,75,-15,77,-17,91,-25,107,-25,111,-28,
   122,-11,76,
  -10,44,-10,52,-10,57,-9,58,-16,72,-7,69,-4,69,-5,74,-9,86,2,66,-9,34,1,32,
  11,31,5,52,-2,55,-2,67,0,73,-8,89,3,52,7,4,10,8,17,8,16,19,3,37,
  -1,61,-5,73,-1,70,-4,78,0,0,-21,126,-23,124,-20,110,-26,126,-25,124,-17,105,-
   27,121,
  -27,117,-17,102,-26,117,-27,116,-33,122,-10,95,-14,100,-8,95,-17,111,-28,114,-
   6,89,-2,80,
  -4,82,-9,85,-8,81,-1,72,5,64,1,67,9,56,0,69,1,69,7,69,-7,69,-6,67,
  -16,77,-2,64,2,61,-6,67,-3,64,2,57,-3,65,-3,66,0,62,9,51,-1,66,-2,71,
  -2,75,-1,70,-9,72,14,60,16,37,0,47,18,35,11,37,12,41,10,41,2,48,12,41,
  13,41,0,59,3,50,19,40,3,66,18,50,19,-6,18,-6,14,0,26,-12,31,-16,33,-25,
  33,-22,37,-28,39,-30,42,-30,47,-42,45,-36,49,-34,41,-17,32,9,69,-71,63,-63,66,
   -64,
  77,-74,54,-39,52,-35,41,-10,36,0,40,-1,30,14,28,26,23,37,12,55,11,65,37,-33,
  39,-36,40,-37,38,-30,46,-33,42,-30,40,-24,49,-29,38,-12,40,-10,38,-3,46,-5,31,
   20,
  29,30,25,44,12,48,11,49,26,45,22,22,23,22,27,21,33,20,26,28,30,24,27,34,
  18,42,25,39,18,50,12,70,21,54,14,71,11,83,25,32,21,49,21,54,-5,85,-6,81,
  -10,77,-7,81,-17,80,-18,73,-4,74,-10,83,-9,71,-9,67,-1,61,-8,66,-14,66,0,59,
  2,59,17,-10,32,-13,42,-9,49,-5,53,0,64,3,68,10,66,27,47,57,-5,71,0,24,
  -1,36,-2,42,-2,52,-9,57,-6,63,-4,65,-4,67,-7,82,-3,81,-3,76,-7,72,-6,78,
  -12,72,-14,68,-3,70,-6,76,-5,66,-5,62,0,57,-4,61,-9,60,1,54,2,58,17,-10,
  32,-13,42,-9,49,-5,53,0,64,3,68,10,66,27,47,57,0,80,-5,89,-7,94,-4,92,
  0,39,0,65,-15,84,-35,127,-2,73,-12,104,-9,91,-31,127,0,80,-5,89,-7,94,-4,92,
  0,39,0,65,-15,84,-35,127,-2,73,-12,104,-9,91,-31,127,-13,103,-13,91,-9,89,-14,
   92,
  -8,76,-12,87,-23,110,-24,105,-10,78,-20,112,-17,99,-78,127,-70,127,-50,127,-
   46,127,-4,66,
  -5,78,-4,71,-8,72,2,59,-1,55,-7,70,-6,75,-8,89,-34,119,-3,75,32,20,30,22,
  -44,127,0,54,-5,61,0,58,-1,60,-3,61,-8,67,-25,84,-14,74,-5,65,5,52,2,57,
  0,61,-9,69,-11,70,18,55,-13,103,-13,91,-9,89,-14,92,-8,76,-12,87,-23,110,-24,
   105,
  -10,78,-20,112,-17,99,-78,127,-70,127,-50,127,-46,127,-4,66,-5,78,-4,71,-8,72,
   2,59,
  -1,55,-7,70,-6,75,-8,89,-34,119,-3,75,32,20,30,22,-44,127,0,54,-5,61,0,58,
  -1,60,-3,61,-8,67,-25,84,-14,74,-5,65,5,52,2,57,0,61,-9,69,-11,70,18,55,
  4,45,10,28,10,31,33,-11,52,-43,18,15,28,0,35,-22,38,-25,34,0,39,-18,32,-12,
  102,-94,0,0,56,-15,33,-4,29,10,37,-5,51,-29,39,-9,52,-34,69,-58,67,-63,44,-5,
  32,7,55,-29,32,1,0,0,27,36,33,-25,34,-30,36,-28,38,-28,38,-27,34,-18,35,-16,
  34,-14,32,-8,37,-6,35,0,30,10,28,18,26,25,29,41,4,45,10,28,10,31,33,-11,
  52,-43,18,15,28,0,35,-22,38,-25,34,0,39,-18,32,-12,102,-94,0,0,56,-15,33,-4,
  29,10,37,-5,51,-29,39,-9,52,-34,69,-58,67,-63,44,-5,32,7,55,-29,32,1,0,0,
  27,36,33,-25,34,-30,36,-28,38,-28,38,-27,34,-18,35,-16,34,-14,32,-8,37,-6,35,
   0,
  30,10,28,18,26,25,29,41,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,
  -9,71,-9,67,-1,61,-8,66,-14,66,0,59,2,59,-3,81,-3,76,-7,72,-6,78,-12,72,
  -14,68,-3,70,-6,76,-5,66,-5,62,0,57,-4,61,-9,60,1,54,2,58,17,-10,32,-13,
  42,-9,49,-5,53,0,64,3,68,10,66,27,47,57,17,-10,32,-13,42,-9,49,-5,53,0,
  64,3,68,10,66,27,47,57,-5,71,0,24,-1,36,-2,42,-2,52,-9,57,-6,63,-4,65,
  -4,67,-7,82,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,-9,71,-9,67,
  -1,61,-8,66,-14,66,0,59,2,59,-3,81,-3,76,-7,72,-6,78,-12,72,-14,68,-3,70,
  -6,76,-5,66,-5,62,0,57,-4,61,-9,60,1,54,2,58,17,-10,32,-13,42,-9,49,-5,
  53,0,64,3,68,10,66,27,47,57,17,-10,32,-13,42,-9,49,-5,53,0,64,3,68,10,
  66,27,47,57,-5,71,0,24,-1,36,-2,42,-2,52,-9,57,-6,63,-4,65,-4,67,-7,82,
  -21,126,-23,124,-20,110,-26,126,-25,124,-17,105,-27,121,-27,117,-17,102,-26,
   117,-27,116,-33,122,
  -10,95,-14,100,-8,95,-17,111,-28,114,-6,89,-2,80,-4,82,-9,85,-8,81,-1,72,5,64,
  1,67,9,56,0,69,1,69,7,69,-7,69,-6,67,-16,77,-2,64,2,61,-6,67,-3,64,
  2,57,-3,65,-3,66,0,62,9,51,-1,66,-2,71,-2,75,-21,126,-23,124,-20,110,-26,126,
  -25,124,-17,105,-27,121,-27,117,-17,102,-26,117,-27,116,-33,122,-10,95,-14,
   100,-8,95,-17,111,
  -28,114,-6,89,-2,80,-4,82,-9,85,-8,81,-1,72,5,64,1,67,9,56,0,69,1,69,
  7,69,-7,69,-6,67,-16,77,-2,64,2,61,-6,67,-3,64,2,57,-3,65,-3,66,0,62,
  9,51,-1,66,-2,71,-2,75,19,-6,18,-6,14,0,26,-12,31,-16,33,-25,33,-22,37,-28,
  39,-30,42,-30,47,-42,45,-36,49,-34,41,-17,32,9,69,-71,63,-63,66,-64,77,-74,54,
   -39,
  52,-35,41,-10,36,0,40,-1,30,14,28,26,23,37,12,55,11,65,37,-33,39,-36,40,-37,
  38,-30,46,-33,42,-30,40,-24,49,-29,38,-12,40,-10,38,-3,46,-5,31,20,29,30,25,
   44,
  19,-6,18,-6,14,0,26,-12,31,-16,33,-25,33,-22,37,-28,39,-30,42,-30,47,-42,45,-
   36,
  49,-34,41,-17,32,9,69,-71,63,-63,66,-64,77,-74,54,-39,52,-35,41,-10,36,0,40,-
   1,
  30,14,28,26,23,37,12,55,11,65,37,-33,39,-36,40,-37,38,-30,46,-33,42,-30,40,-
   24,
  49,-29,38,-12,40,-10,38,-3,46,-5,31,20,29,30,25,44,-23,112,-15,71,-7,61,0,53,
  -5,66,-11,77,-9,80,-9,84,-10,87,-34,127,-21,101,-3,39,-5,53,-7,61,-11,75,-15,
   77,
  -17,91,-25,107,-25,111,-28,122,-11,76,-10,44,-10,52,-10,57,-9,58,-16,72,-7,69,
   -4,69,
  -5,74,-9,86,-23,112,-15,71,-7,61,0,53,-5,66,-11,77,-9,80,-9,84,-10,87,-34,127,
  -21,101,-3,39,-5,53,-7,61,-11,75,-15,77,-17,91,-25,107,-25,111,-28,122,-11,76,
   -10,44,
  -10,52,-10,57,-9,58,-16,72,-7,69,-4,69,-5,74,-9,86,-2,73,-12,104,-9,91,-31,
   127,
  -2,73,-12,104,-9,91,-31,127,-2,73,-12,104,-9,91,-31,127,20,-15,2,54,3,74,20,-
   15,
  2,54,3,74,-28,127,-23,104,-6,53,-1,54,7,51,29,16,25,0,14,0,-10,51,-3,62,
  -27,99,26,16,-4,85,-24,102,5,57,6,57,-17,73,14,57,20,40,20,10,29,0,54,0,
  37,42,12,97,-32,127,-22,117,-2,74,-4,85,-24,102,5,57,-6,93,-14,88,-6,44,4,55,
  -11,89,-15,103,-21,116,19,57,20,58,4,84,6,96,1,63,-5,85,-13,106,5,63,6,75,
  -3,90,-1,101,3,55,-4,79,-2,75,-12,97,-7,50,1,60,0,41,0,63,0,63,0,63,
  -9,83,4,86,0,97,-7,72,13,41,3,62,7,34,-9,88,-20,127,-36,127,-17,91,-14,95,
  -25,84,-25,86,-12,89,-17,91,-31,127,-14,76,-18,103,-13,90,-37,127,11,80,5,76,
   2,84,
  5,78,-6,55,4,61,-14,83,-37,127,-5,79,-11,104,-11,91,-30,127,0,65,-2,79,0,72,
  -4,92,-6,56,3,68,-8,71,-13,98,-4,86,-12,88,-5,82,-3,72,-4,67,-8,72,-16,89,
  -9,69,-1,59,5,66,4,57,-4,71,-2,71,2,58,-1,74,-4,44,-1,69,0,62,-7,51,
  -4,47,-6,42,-3,41,-6,53,8,76,-9,78,-11,83,9,52,0,67,-5,90,1,67,-15,72,
  -5,75,-8,80,-21,83,-21,64,-13,31,-25,64,-29,94,9,75,17,63,-8,74,-5,35,-2,27,
  13,91,3,65,-7,69,8,77,-10,66,3,62,-3,68,-20,81,0,30,1,7,-3,23,-21,74,
  16,66,-23,124,17,37,44,-18,50,-34,-22,127,4,39,0,42,7,34,11,29,8,31,6,37,
  7,42,3,40,8,33,13,43,13,36,4,47,3,55,2,58,6,60,8,44,11,44,14,42,
  7,48,4,56,4,52,13,37,9,49,19,58,10,48,12,45,0,69,20,33,8,63,35,-18,
  33,-25,28,-3,24,10,27,0,34,-14,52,-44,39,-24,19,17,31,25,36,29,24,33,34,15,
  30,20,22,73,20,34,19,31,27,44,19,16,15,36,15,36,21,28,25,21,30,20,31,12,
  27,16,24,42,0,93,14,56,15,57,26,38,-24,127,-24,115,-22,82,-9,62,0,53,0,59,
  -14,85,-13,89,-13,94,-11,92,-29,127,-21,100,-14,57,-12,67,-11,71,-10,77,-21,
   85,-16,88,
  -23,104,-15,98,-37,127,-10,82,-8,48,-8,61,-8,66,-7,70,-14,75,-10,79,-9,83,-12,
   92,
  -18,108,-4,79,-22,69,-16,75,-2,58,1,58,-13,78,-9,83,-4,81,-13,99,-13,81,-6,38,
  -13,62,-6,58,-2,59,-16,73,-10,76,-13,86,-9,83,-10,87,0,0,-22,127,-25,127,-25,
   120,
  -27,127,-19,114,-23,117,-25,118,-26,117,-24,113,-28,118,-31,120,-37,124,-10,
   94,-15,102,-10,99,
  -13,106,-50,127,-5,92,17,57,-5,86,-13,94,-12,91,-2,77,0,71,-1,73,4,64,-7,81,
  5,64,15,57,1,67,0,68,-10,67,1,68,0,77,2,64,0,68,-5,78,7,55,5,59,
  2,65,14,54,15,44,5,60,2,70,-2,76,-18,86,12,70,5,64,-12,70,11,55,5,56,
  0,69,2,65,-6,74,5,54,7,54,-6,76,-11,82,-2,77,-2,77,25,42,17,-13,16,-9,
  17,-12,27,-21,37,-30,41,-40,42,-41,48,-47,39,-32,46,-40,52,-51,46,-41,52,-39,
   43,-19,
  32,11,61,-55,56,-46,62,-50,81,-67,45,-20,35,-2,28,15,34,1,39,1,30,17,20,38,
  18,45,15,54,0,79,36,-16,37,-14,37,-17,32,1,34,15,29,15,24,25,34,22,31,16,
  35,18,31,28,33,41,36,28,27,47,21,62,18,31,19,26,36,24,24,23,27,16,24,30,
  31,29,22,41,22,42,16,60,15,52,14,60,3,78,-16,123,21,53,22,56,25,61,21,33,
  19,50,17,61,-3,78,-8,74,-9,72,-10,72,-18,75,-12,71,-11,63,-5,70,-17,75,-14,72,
  -16,67,-8,53,-14,59,-9,52,-11,68,9,-2,30,-10,31,-4,33,-1,33,7,31,12,37,23,
  31,38,20,64,-9,71,-7,37,-8,44,-11,49,-10,56,-12,59,-8,63,-9,67,-6,68,-10,79,
  -3,78,-8,74,-9,72,-10,72,-18,75,-12,71,-11,63,-5,70,-17,75,-14,72,-16,67,-8,
   53,
  -14,59,-9,52,-11,68,9,-2,30,-10,31,-4,33,-1,33,7,31,12,37,23,31,38,20,64,
  11,80,5,76,2,84,5,78,-6,55,4,61,-14,83,-37,127,-5,79,-11,104,-11,91,-30,127,
  11,80,5,76,2,84,5,78,-6,55,4,61,-14,83,-37,127,-5,79,-11,104,-11,91,-30,127,
  -4,86,-12,88,-5,82,-3,72,-4,67,-8,72,-16,89,-9,69,-1,59,5,66,4,57,-4,71,
  -2,71,2,58,-1,74,-4,44,-1,69,0,62,-7,51,-4,47,-6,42,-3,41,-6,53,8,76,
  -9,78,-11,83,9,52,0,67,-5,90,1,67,-15,72,-5,75,-8,80,-21,83,-21,64,-13,31,
  -25,64,-29,94,9,75,17,63,-8,74,-5,35,-2,27,13,91,-4,86,-12,88,-5,82,-3,72,
  -4,67,-8,72,-16,89,-9,69,-1,59,5,66,4,57,-4,71,-2,71,2,58,-1,74,-4,44,
  -1,69,0,62,-7,51,-4,47,-6,42,-3,41,-6,53,8,76,-9,78,-11,83,9,52,0,67,
  -5,90,1,67,-15,72,-5,75,-8,80,-21,83,-21,64,-13,31,-25,64,-29,94,9,75,17,63,
  -8,74,-5,35,-2,27,13,91,4,39,0,42,7,34,11,29,8,31,6,37,7,42,3,40,
  8,33,13,43,13,36,4,47,3,55,2,58,6,60,8,44,11,44,14,42,7,48,4,56,
  4,52,13,37,9,49,19,58,10,48,12,45,0,69,20,33,8,63,35,-18,33,-25,28,-3,
  24,10,27,0,34,-14,52,-44,39,-24,19,17,31,25,36,29,24,33,34,15,30,20,22,73,
  4,39,0,42,7,34,11,29,8,31,6,37,7,42,3,40,8,33,13,43,13,36,4,47,
  3,55,2,58,6,60,8,44,11,44,14,42,7,48,4,56,4,52,13,37,9,49,19,58,
  10,48,12,45,0,69,20,33,8,63,35,-18,33,-25,28,-3,24,10,27,0,34,-14,52,-44,
  39,-24,19,17,31,25,36,29,24,33,34,15,30,20,22,73,-3,78,-8,74,-9,72,-10,72,
  -18,75,-12,71,-11,63,-5,70,-17,75,-14,72,-16,67,-8,53,-14,59,-9,52,-11,68,-3,
   78,
  -8,74,-9,72,-10,72,-18,75,-12,71,-11,63,-5,70,-17,75,-14,72,-16,67,-8,53,-14,
   59,
  -9,52,-11,68,9,-2,30,-10,31,-4,33,-1,33,7,31,12,37,23,31,38,20,64,9,-2,
  30,-10,31,-4,33,-1,33,7,31,12,37,23,31,38,20,64,-9,71,-7,37,-8,44,-11,49,
  -10,56,-12,59,-8,63,-9,67,-6,68,-10,79,-3,78,-8,74,-9,72,-10,72,-18,75,-12,71,
  -11,63,-5,70,-17,75,-14,72,-16,67,-8,53,-14,59,-9,52,-11,68,-3,78,-8,74,-9,72,
  -10,72,-18,75,-12,71,-11,63,-5,70,-17,75,-14,72,-16,67,-8,53,-14,59,-9,52,-11,
   68,
  9,-2,30,-10,31,-4,33,-1,33,7,31,12,37,23,31,38,20,64,9,-2,30,-10,31,-4,
  33,-1,33,7,31,12,37,23,31,38,20,64,-9,71,-7,37,-8,44,-11,49,-10,56,-12,59,
  -8,63,-9,67,-6,68,-10,79,-22,127,-25,127,-25,120,-27,127,-19,114,-23,117,-25,
   118,-26,117,
  -24,113,-28,118,-31,120,-37,124,-10,94,-15,102,-10,99,-13,106,-50,127,-5,92,
   17,57,-5,86,
  -13,94,-12,91,-2,77,0,71,-1,73,4,64,-7,81,5,64,15,57,1,67,0,68,-10,67,
  1,68,0,77,2,64,0,68,-5,78,7,55,5,59,2,65,14,54,15,44,5,60,2,70,
  -22,127,-25,127,-25,120,-27,127,-19,114,-23,117,-25,118,-26,117,-24,113,-28,
   118,-31,120,-37,124,
  -10,94,-15,102,-10,99,-13,106,-50,127,-5,92,17,57,-5,86,-13,94,-12,91,-2,77,0,
   71,
  -1,73,4,64,-7,81,5,64,15,57,1,67,0,68,-10,67,1,68,0,77,2,64,0,68,
  -5,78,7,55,5,59,2,65,14,54,15,44,5,60,2,70,17,-13,16,-9,17,-12,27,-21,
  37,-30,41,-40,42,-41,48,-47,39,-32,46,-40,52,-51,46,-41,52,-39,43,-19,32,11,
   61,-55,
  56,-46,62,-50,81,-67,45,-20,35,-2,28,15,34,1,39,1,30,17,20,38,18,45,15,54,
  0,79,36,-16,37,-14,37,-17,32,1,34,15,29,15,24,25,34,22,31,16,35,18,31,28,
  33,41,36,28,27,47,21,62,17,-13,16,-9,17,-12,27,-21,37,-30,41,-40,42,-41,48,-
   47,
  39,-32,46,-40,52,-51,46,-41,52,-39,43,-19,32,11,61,-55,56,-46,62,-50,81,-67,
   45,-20,
  35,-2,28,15,34,1,39,1,30,17,20,38,18,45,15,54,0,79,36,-16,37,-14,37,-17,
  32,1,34,15,29,15,24,25,34,22,31,16,35,18,31,28,33,41,36,28,27,47,21,62,
  -24,115,-22,82,-9,62,0,53,0,59,-14,85,-13,89,-13,94,-11,92,-29,127,-21,100,-
   14,57,
  -12,67,-11,71,-10,77,-21,85,-16,88,-23,104,-15,98,-37,127,-10,82,-8,48,-8,61,-
   8,66,
  -7,70,-14,75,-10,79,-9,83,-12,92,-18,108,-24,115,-22,82,-9,62,0,53,0,59,-14,
   85,
  -13,89,-13,94,-11,92,-29,127,-21,100,-14,57,-12,67,-11,71,-10,77,-21,85,-16,
   88,-23,104,
  -15,98,-37,127,-10,82,-8,48,-8,61,-8,66,-7,70,-14,75,-10,79,-9,83,-12,92,-18,
   108,
  -5,79,-11,104,-11,91,-30,127,-5,79,-11,104,-11,91,-30,127,-5,79,-11,104,-11,
   91,-30,127
 );
 H4Def4Intra: Array[0..15] Of Byte=(
  6,13,20,28,13,20,28,32,20,28,32,37,28,32,37,42
 );
 H4Def4Inter: Array[0..15] Of Byte=(
  10,14,20,24,14,20,24,27,20,24,27,30,24,27,30,34
 );
 H4Def8Intra: Array[0..63] Of Byte=(
  6,10,13,16,18,23,25,27,10,11,16,18,23,25,27,29,
  13,16,18,23,25,27,29,31,16,18,23,25,27,29,31,33,
  18,23,25,27,29,31,33,36,23,25,27,29,31,33,36,38,
  25,27,29,31,33,36,38,40,27,29,31,33,36,38,40,42
 );
 H4Def8Inter: Array[0..63] Of Byte=(
  9,13,15,17,19,21,22,24,13,13,17,19,21,22,24,25,
  15,17,19,21,22,24,25,27,17,19,21,22,24,25,27,28,
  19,21,22,24,25,27,28,30,21,22,24,25,27,28,30,32,
  22,24,25,27,28,30,32,33,24,25,27,28,30,32,33,35
 );

{ ---- H.264 / AVC (ITU-T H.264): decodeur progressif 4:2:0 8 bits, CAVLC et
 CABAC, I/P/B, transformee 8x8 ----
  Tables CAVLC/CABAC/deblocage extraites de libavcodec/h264_cavlc.c,
   h264_cabac.c, h264_loopfilter.c, h264data.c, h264_ps.c (LGPL-2.1-or-later). }
Type
 PWordArr=^TWordArr; TWordArr=Array[0..1048575] Of Word;
 PSmallArr=^TSmallArr; TSmallArr=Array[0..4800000] Of SmallInt;
 PLongArr=^TLongArr; TLongArr=Array[0..1048575] Of LongInt;
 TH4Sps=Record
  Valid: Boolean;
  ProfileIdc,ConstraintFlags,LevelIdc,SpsId,ChromaFormat,BitDepthY,BitDepthC,
   TransformBypass: LongInt;
  Log2MaxFrameNum,PocType,Log2MaxPocLsb,DeltaPicOrderAlwaysZero,
   OffsetForNonRefPic,OffsetForTopToBottom,PocCycleLength: LongInt;
  OffsetForRefFrame: Array[0..255] Of LongInt;
  RefFrameCount,GapsAllowed,MbW,MbH,FrameMbsOnly,Mbaff,Direct8x8Inference:
   LongInt;
  CropL,CropR,CropT,CropB: LongInt;
  VuiPresent,SarNum,SarDen,TimingInfo,FixedFrameRate,BitstreamRestriction,
   NumReorderFrames,MaxDecFrameBuffering: LongInt;
  NumUnitsInTick,TimeScale: Int64;
  ChromaLoc,FullRange,ColorDesc,ColorPrimaries,ColorTrc,ColorSpace: LongInt;
  ScalingPresent: LongInt;
  Sl4: Array[0..5,0..15] Of Byte; Sl8: Array[0..5,0..63] Of Byte;
 End;
 TH4Pps=Record
  Valid: Boolean;
  PpsId,SpsId,Cabac,BottomFieldPocPresent,NumSliceGroups,NumRefIdx0,NumRefIdx1,
   WeightedPred,WeightedBipred,InitQp,InitQs,ChromaQpOffset,ChromaQpOffset2:
   LongInt;
  DeblockCtrl,ConstrainedIntra,RedundantPicCnt,Transform8x8,ScalingPresent:
   LongInt;
  Sl4: Array[0..5,0..15] Of Byte; Sl8: Array[0..5,0..63] Of Byte;
 End;
 TH4Mmco=Record Op,A1,A2: LongInt; End;
 TH4Slice=Record
  FirstMb,SliceType,PpsId,FrameNum,FieldPic,BottomField,IdrPicId,PocLsb,
   DeltaPocBottom,RedundantPicCnt,DirectSpatial: LongInt;
  DeltaPoc: Array[0..1] Of LongInt;
  NumRef: Array[0..1] Of LongInt;
  ModFlag: Array[0..1] Of LongInt; ModCount: Array[0..1] Of LongInt;
  ModIdc,ModVal: Array[0..1,0..32] Of LongInt;
  LumaLog2Wd,ChromaLog2Wd: LongInt;
  LumaW,LumaO: Array[0..1,0..31] Of LongInt;
  ChromaW,ChromaO: Array[0..1,0..31,0..1] Of LongInt;
  LumaFlag,ChromaFlag: Array[0..1,0..31] Of LongInt;
  NoOutputPrior,LongTermRef,AdaptiveMarking,MmcoCount: LongInt;
  Mmco: Array[0..63] Of TH4Mmco;
  CabacInitIdc,QpDelta,Qp,SliceQs,DisableDeblock,AlphaOff,BetaOff,NalRefIdc,Idr:
   LongInt;
  SliceNum: LongInt;
 End;
Const
 H4MaxPics=40;
Var
 H4Rb: PEABuffer; H4RbSize: LongInt;       { RBSP courant (apres retrait des
  octets d'emulation) }
 H4Pos: LongInt;                            { position de lecture en bits }
 H4Sps: Array[0..31] Of TH4Sps; H4Pps: Array[0..255] Of TH4Pps;
 H4Err: Boolean;

Function H4Peek32: Int64;
Var B,I: LongInt; V: Int64;
Begin
 B:=H4Pos Shr 3; V:=0;
 For I:=0 To 4 Do Begin
  V:=V Shl 8;
  If B+I<H4RbSize Then V:=V Or H4Rb^[B+I];
 End;
 H4Peek32:=(V Shr (8-(H4Pos And 7))) And $FFFFFFFF;
End;
Function H4Bits(N: LongInt): LongInt;
Begin
 If N=0 Then Begin H4Bits:=0; Exit; End;
 H4Bits:=H4Peek32 Shr (32-N); Inc(H4Pos,N);
 If H4Pos>H4RbSize*8+64 Then H4Err:=True;
End;
Function H4Bit: LongInt;
Begin
 If (H4Pos Shr 3)<H4RbSize Then H4Bit:=(H4Rb^[H4Pos Shr 3] Shr (7-(H4Pos And
  7))) And 1 Else H4Bit:=0;
 Inc(H4Pos);
 If H4Pos>H4RbSize*8+64 Then H4Err:=True;
End;
Function H4Ue: LongInt;
Var Z,V: LongInt; P: Int64;
Begin
 Z:=0;
 P:=H4Peek32;
 While (Z<32) And ((P And (Int64(1) Shl (31-Z)))=0) Do Inc(Z);
 If Z>=32 Then Begin H4Err:=True; Inc(H4Pos,32); H4Ue:=0; Exit; End;
 If Z<=15 Then Begin
  V:=(P Shr (31-2*Z)) And ((Int64(1) Shl (Z+1))-1);
  Inc(H4Pos,2*Z+1); H4Ue:=V-1;
 End Else Begin
  Inc(H4Pos,Z+1); V:=H4Bits(Z); H4Ue:=((Int64(1) Shl Z)-1)+V;
 End;
End;
Function H4Se: LongInt;
Var K: LongInt;
Begin
 K:=H4Ue;
 If Odd(K) Then H4Se:=(K+1) Div 2 Else H4Se:=-(K Div 2);
End;
Function H4Te(Max: LongInt): LongInt;
Begin
 If Max>1 Then H4Te:=H4Ue Else H4Te:=1-H4Bit;
End;
Function H4Left: LongInt;Begin H4Left:=H4RbSize*8-H4Pos; End;
{ more_rbsp_data : reste-t-il des donnees avant le bit d'arret final ? }
Function H4MoreData: Boolean;
Var I,Last,B: LongInt;
Begin
 Last:=H4RbSize-1;
 While (Last>=0) And (H4Rb^[Last]=0) Do Dec(Last);
 If Last<0 Then Begin H4MoreData:=False; Exit; End;
 B:=H4Rb^[Last]; I:=0;
 While (B And 1)=0 Do Begin B:=B Shr 1; Inc(I); End;
 { bit d'arret a la position Last*8+7-I }
 H4MoreData:=H4Pos<Last*8+7-I;
End;

Const
 H4Zigzag4: Array[0..15] Of Byte=(0,1,4,8,5,2,3,6,9,12,13,10,7,11,14,15);
 H4Zigzag8: Array[0..63] Of Byte=(0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,
  26,33,40,48,41,34,27,20,13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,
  30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63);
 H4SarTab: Array[0..16,0..1] Of Word=((0,1),(1,1),(12,11),(10,11),(16,11),(40,
  33),(24,11),(20,11),(32,11),(80,33),(18,11),(15,11),(64,33),(160,99),(4,3),(3,
  2),(2,1));

Function H4Bits32: Int64;
Var V: Int64;
Begin
 V:=H4Peek32; Inc(H4Pos,32); H4Bits32:=V;
End;

{ lit une liste de ponderation (ordre de balayage -> raster) ; renvoie True si
 "liste par defaut" }
Function H4ReadList(Dst: PEABuffer; Size: LongInt): Boolean;
Var J,Last,Next,Idx: LongInt; UseDef: Boolean;
Begin
 Last:=8; Next:=8; UseDef:=False;
 For J:=0 To Size-1 Do Begin
  If Next<>0 Then Begin
   Next:=(Last+H4Se+256) And 255;
   If (J=0) And (Next=0) Then UseDef:=True;
  End;
  If Size=16 Then Idx:=H4Zigzag4[J] Else Idx:=H4Zigzag8[J];
  If Next=0 Then Dst^[Idx]:=Last Else Dst^[Idx]:=Next;
  Last:=Dst^[Idx];
 End;
 H4ReadList:=UseDef;
End;

{ decode_scaling_matrices ; Sp4/Sp8 = listes du SPS (regle B) si HaveSps, sinon
 valeurs par defaut (regle A) }
Procedure H4ParseScaling(D4,D8: PEABuffer; Count: LongInt; HaveSps: Boolean;
 Sp4,Sp8: PEABuffer);
Var I,Sz: LongInt; Pres,UseDef: Boolean; Tmp: Array[0..63] Of Byte;
Begin
 For I:=0 To Count-1 Do Begin
  Pres:=H4Bit<>0;
  If I<6 Then Sz:=16 Else Sz:=64;
  UseDef:=False;
  If Pres Then UseDef:=H4ReadList(@Tmp,Sz);
  If I<6 Then Begin
   If Pres And Not UseDef Then Move(Tmp,D4^[I*16],16)
   Else If Pres Then Begin If I<3 Then Move(H4Def4Intra,D4^[I*16],16) Else Move(
    H4Def4Inter,D4^[I*16],16); End
   Else Case I Of
    0: If HaveSps Then Move(Sp4^[0],D4^[0],16) Else Move(H4Def4Intra,D4^[0],16);
    3: If HaveSps Then Move(Sp4^[48],D4^[48],16) Else Move(H4Def4Inter,D4^[48],
     16);
   Else Move(D4^[(I-1)*16],D4^[I*16],16);
   End;
  End Else Begin
   If Pres And Not UseDef Then Move(Tmp,D8^[(I-6)*64],64)
   Else If Pres Then Begin If Odd(I) Then Move(H4Def8Inter,D8^[(I-6)*64],64)
    Else Move(H4Def8Intra,D8^[(I-6)*64],64); End
   Else Case I Of
    6: If HaveSps Then Move(Sp8^[0],D8^[0],64) Else Move(H4Def8Intra,D8^[0],64);
    7: If HaveSps Then Move(Sp8^[64],D8^[64],64) Else Move(H4Def8Inter,D8^[64],
     64);
   Else Move(D8^[(I-8)*64],D8^[(I-6)*64],64);
   End;
  End;
 End;
End;

Procedure H4ParseHrd;
Var Cnt,I: LongInt;
Begin
 Cnt:=H4Ue+1;
 H4Bits(4); H4Bits(4);
 For I:=1 To Cnt Do Begin H4Ue; H4Ue; H4Bit; End;
 H4Bits(5); H4Bits(5); H4Bits(5); H4Bits(5);
End;

Procedure H4ParseVui(Var S: TH4Sps);
Var Idc,Nal2: LongInt;
Begin
 S.VuiPresent:=1; S.SarNum:=0; S.SarDen:=1; S.ChromaLoc:=1; S.FullRange:=-1;
 If H4Bit<>0 Then Begin
  Idc:=H4Bits(8);
  If Idc=255 Then Begin S.SarNum:=H4Bits(16); S.SarDen:=H4Bits(16); End
  Else If (Idc>=1) And (Idc<=16) Then Begin S.SarNum:=H4SarTab[Idc,0];
   S.SarDen:=H4SarTab[Idc,1]; End;
 End;
 If H4Bit<>0 Then H4Bit;
 If H4Bit<>0 Then Begin
  H4Bits(3); S.FullRange:=H4Bit;
  If H4Bit<>0 Then Begin S.ColorDesc:=1; S.ColorPrimaries:=H4Bits(8);
   S.ColorTrc:=H4Bits(8); S.ColorSpace:=H4Bits(8); End;
 End;
 If H4Bit<>0 Then Begin
  Idc:=H4Ue; H4Ue;
  If Idc<=5 Then S.ChromaLoc:=Idc+1 Else S.ChromaLoc:=0;
 End;
 If H4Bit<>0 Then Begin
  S.TimingInfo:=1; S.NumUnitsInTick:=H4Bits32; S.TimeScale:=H4Bits32;
   S.FixedFrameRate:=H4Bit;
 End;
 Idc:=H4Bit; If Idc<>0 Then H4ParseHrd;
 Nal2:=H4Bit; If Nal2<>0 Then H4ParseHrd;
 If (Idc<>0) Or (Nal2<>0) Then H4Bit;
 H4Bit;
 If H4Bit<>0 Then Begin
  S.BitstreamRestriction:=1;
  H4Bit; H4Ue; H4Ue; H4Ue; H4Ue;
  S.NumReorderFrames:=H4Ue; S.MaxDecFrameBuffering:=H4Ue;
 End;
End;

{ SPS : renvoie 0 si ok, <0 sinon }
Function H4ParseSps: LongInt;
Var Prof,Id,I,T,Cnt: LongInt; S: TH4Sps; Hf: Boolean;
Begin
 H4ParseSps:=-1;
 FillChar(S,SizeOf(S),0);
 Prof:=H4Bits(8); S.ConstraintFlags:=H4Bits(8); S.LevelIdc:=H4Bits(8); Id:=H4Ue;
 If (Id>31) Or H4Err Then Exit;
 S.SpsId:=Id; S.ProfileIdc:=Prof;
 S.ChromaFormat:=1; S.BitDepthY:=8; S.BitDepthC:=8;
 FillChar(S.Sl4,SizeOf(S.Sl4),16); FillChar(S.Sl8,SizeOf(S.Sl8),16);
 If (Prof=100) Or (Prof=110) Or (Prof=122) Or (Prof=244) Or (Prof=44) Or (
  Prof=83) Or (Prof=86) Or (Prof=118) Or (Prof=128) Or (Prof=138) Or (Prof=144)
  Then Begin
  S.ChromaFormat:=H4Ue;
  If S.ChromaFormat>3 Then Exit;
  If S.ChromaFormat=3 Then If H4Bit<>0 Then Exit;
  S.BitDepthY:=H4Ue+8; S.BitDepthC:=H4Ue+8;
  If (S.BitDepthY<>S.BitDepthC) Or (S.BitDepthY<8) Or (S.BitDepthY>14) Then
   Exit;
  S.TransformBypass:=H4Bit;
  If H4Bit<>0 Then Begin
   S.ScalingPresent:=1;
   If S.ChromaFormat<>3 Then Cnt:=8 Else Cnt:=12;
   H4ParseScaling(@S.Sl4,@S.Sl8,Cnt,False,Nil,Nil);
  End;
 End;
 T:=H4Ue; If T>12 Then Exit; S.Log2MaxFrameNum:=T+4;
 S.PocType:=H4Ue;
 If S.PocType=0 Then Begin
  T:=H4Ue; If T>12 Then Exit; S.Log2MaxPocLsb:=T+4;
 End Else If S.PocType=1 Then Begin
  S.DeltaPicOrderAlwaysZero:=H4Bit; S.OffsetForNonRefPic:=H4Se;
   S.OffsetForTopToBottom:=H4Se;
  S.PocCycleLength:=H4Ue;
  If S.PocCycleLength>255 Then Exit;
  For I:=0 To S.PocCycleLength-1 Do S.OffsetForRefFrame[I]:=H4Se;
 End Else If S.PocType<>2 Then Exit;
 S.RefFrameCount:=H4Ue;
 If S.RefFrameCount>16 Then Exit;
 S.GapsAllowed:=H4Bit;
 S.MbW:=H4Ue+1; T:=H4Ue+1;
 S.FrameMbsOnly:=H4Bit;
 If S.FrameMbsOnly=0 Then S.Mbaff:=H4Bit;
 S.MbH:=T*(2-S.FrameMbsOnly);
 S.Direct8x8Inference:=H4Bit;
 If (S.MbW>1024) Or (S.MbH>1024) Or (S.MbW*S.MbH>139264) Then Exit;
 If H4Bit<>0 Then Begin
  S.CropL:=H4Ue; S.CropR:=H4Ue; S.CropT:=H4Ue; S.CropB:=H4Ue;
 End;
 S.ChromaLoc:=1; S.FullRange:=-1; S.SarNum:=0; S.SarDen:=1;
 If H4Bit<>0 Then H4ParseVui(S);
 If H4Err Then Exit;
 S.Valid:=True;
 H4Sps[Id]:=S;
 H4ParseSps:=0;
End;

Function H4ParsePps: LongInt;
Var P: TH4Pps; Id,Sid,Cnt: LongInt;
Begin
 H4ParsePps:=-1;
 FillChar(P,SizeOf(P),0);
 Id:=H4Ue; Sid:=H4Ue;
 If (Id>255) Or (Sid>31) Or H4Err Then Exit;
 If Not H4Sps[Sid].Valid Then Exit;
 P.PpsId:=Id; P.SpsId:=Sid;
 P.Cabac:=H4Bit; P.BottomFieldPocPresent:=H4Bit;
 P.NumSliceGroups:=H4Ue+1;
 If P.NumSliceGroups>1 Then Begin P.Valid:=True; H4Pps[Id]:=P; H4ParsePps:=0;
  Exit; End;
 P.NumRefIdx0:=H4Ue+1; P.NumRefIdx1:=H4Ue+1;
 If (P.NumRefIdx0>32) Or (P.NumRefIdx1>32) Then Exit;
 P.WeightedPred:=H4Bit; P.WeightedBipred:=H4Bits(2);
 P.InitQp:=H4Se+26; P.InitQs:=H4Se+26;
 P.ChromaQpOffset:=H4Se;
 P.DeblockCtrl:=H4Bit; P.ConstrainedIntra:=H4Bit; P.RedundantPicCnt:=H4Bit;
 P.ChromaQpOffset2:=P.ChromaQpOffset;
 Move(H4Sps[Sid].Sl4,P.Sl4,SizeOf(P.Sl4)); Move(H4Sps[Sid].Sl8,P.Sl8,SizeOf(
  P.Sl8));
 If H4MoreData Then Begin
  P.Transform8x8:=H4Bit;
  If H4Bit<>0 Then Begin
   P.ScalingPresent:=1;
   If H4Sps[Sid].ChromaFormat<>3 Then Cnt:=6+2*P.Transform8x8 Else Cnt:=6+6*
    P.Transform8x8;
   H4ParseScaling(@P.Sl4,@P.Sl8,Cnt,H4Sps[Sid].ScalingPresent<>0,@H4Sps[
    Sid].Sl4,@H4Sps[Sid].Sl8);
  End;
  P.ChromaQpOffset2:=H4Se;
 End;
 If H4Err Then Exit;
 P.Valid:=True;
 H4Pps[Id]:=P;
 H4ParsePps:=0;
End;

{ en-tete de tranche ; NalType/NalRef du NAL ; renvoie 0 si ok }
Function H4ParseSlice(Var Sh: TH4Slice; NalType,NalRef: LongInt): LongInt;
Var S: ^TH4Sps; P: ^TH4Pps; I,L,T,Idc,N,Mop: LongInt;
Begin
 H4ParseSlice:=-1;
 FillChar(Sh,SizeOf(Sh),0);
 Sh.NalRefIdc:=NalRef; Sh.Idr:=Ord(NalType=5);
 Sh.FirstMb:=H4Ue;
 T:=H4Ue; If T>9 Then Exit;
 Sh.SliceType:=T Mod 5;
 Sh.PpsId:=H4Ue;
 If Sh.PpsId>255 Then Exit;
 P:=@H4Pps[Sh.PpsId];
 If Not P^.Valid Then Exit;
 S:=@H4Sps[P^.SpsId];
 If Not S^.Valid Then Exit;
 If P^.NumSliceGroups>1 Then Exit;
 Sh.FrameNum:=H4Bits(S^.Log2MaxFrameNum);
 If S^.FrameMbsOnly=0 Then Begin
  Sh.FieldPic:=H4Bit;
  If Sh.FieldPic<>0 Then Sh.BottomField:=H4Bit;
 End;
 If Sh.Idr<>0 Then Sh.IdrPicId:=H4Ue;
 If S^.PocType=0 Then Begin
  Sh.PocLsb:=H4Bits(S^.Log2MaxPocLsb);
  If (P^.BottomFieldPocPresent<>0) And (Sh.FieldPic=0) Then Sh.DeltaPocBottom:=
   H4Se;
 End;
 If (S^.PocType=1) And (S^.DeltaPicOrderAlwaysZero=0) Then Begin
  Sh.DeltaPoc[0]:=H4Se;
  If (P^.BottomFieldPocPresent<>0) And (Sh.FieldPic=0) Then Sh.DeltaPoc[1]:=
   H4Se;
 End;
 If P^.RedundantPicCnt<>0 Then Sh.RedundantPicCnt:=H4Ue;
 If Sh.SliceType=1 Then Sh.DirectSpatial:=H4Bit;
 Sh.NumRef[0]:=0; Sh.NumRef[1]:=0;
 If (Sh.SliceType=0) Or (Sh.SliceType=1) Or (Sh.SliceType=3) Then Begin
  Sh.NumRef[0]:=P^.NumRefIdx0;
  If Sh.SliceType=1 Then Sh.NumRef[1]:=P^.NumRefIdx1;
  If H4Bit<>0 Then Begin
   Sh.NumRef[0]:=H4Ue+1;
   If Sh.SliceType=1 Then Sh.NumRef[1]:=H4Ue+1;
  End;
  If (Sh.NumRef[0]>32) Or (Sh.NumRef[1]>32) Then Exit;
 End;
 { modification des listes }
 For L:=0 To 1 Do Begin
  Sh.ModFlag[L]:=0; Sh.ModCount[L]:=0;
  If ((L=0) And (Sh.SliceType<>2) And (Sh.SliceType<>4)) Or ((L=1) And (
   Sh.SliceType=1)) Then Begin
   Sh.ModFlag[L]:=H4Bit;
   If Sh.ModFlag[L]<>0 Then Begin
    N:=0;
    Repeat
     Idc:=H4Ue;
     If Idc=3 Then Break;
     If (Idc>5) Or (N>=32) Or H4Err Then Exit;
     Sh.ModIdc[L,N]:=Idc; Sh.ModVal[L,N]:=H4Ue; Inc(N);
    Until False;
    Sh.ModCount[L]:=N;
   End;
  End;
 End;
 { table de ponderation }
 If ((P^.WeightedPred<>0) And ((Sh.SliceType=0) Or (Sh.SliceType=3))) Or ((
  P^.WeightedBipred=1) And (Sh.SliceType=1)) Then Begin
  Sh.LumaLog2Wd:=H4Ue; Sh.ChromaLog2Wd:=0;
  If S^.ChromaFormat<>0 Then Sh.ChromaLog2Wd:=H4Ue;
  If (Sh.LumaLog2Wd>7) Or (Sh.ChromaLog2Wd>7) Then Exit;
  For L:=0 To 1 Do Begin
   If (L=1) And (Sh.SliceType<>1) Then Break;
   For I:=0 To Sh.NumRef[L]-1 Do Begin
    Sh.LumaFlag[L,I]:=H4Bit;
    If Sh.LumaFlag[L,I]<>0 Then Begin Sh.LumaW[L,I]:=H4Se; Sh.LumaO[L,I]:=H4Se;
     End
    Else Begin Sh.LumaW[L,I]:=1 Shl Sh.LumaLog2Wd; Sh.LumaO[L,I]:=0; End;
    Sh.ChromaFlag[L,I]:=0;
    If S^.ChromaFormat<>0 Then Sh.ChromaFlag[L,I]:=H4Bit;
    If Sh.ChromaFlag[L,I]<>0 Then Begin
     For N:=0 To 1 Do Begin Sh.ChromaW[L,I,N]:=H4Se; Sh.ChromaO[L,I,N]:=H4Se;
      End;
    End Else Begin
     For N:=0 To 1 Do Begin Sh.ChromaW[L,I,N]:=1 Shl Sh.ChromaLog2Wd;
      Sh.ChromaO[L,I,N]:=0; End;
    End;
   End;
  End;
 End;
 { marquage des references }
 If NalRef<>0 Then Begin
  If Sh.Idr<>0 Then Begin
   Sh.NoOutputPrior:=H4Bit; Sh.LongTermRef:=H4Bit;
  End Else Begin
   Sh.AdaptiveMarking:=H4Bit;
   If Sh.AdaptiveMarking<>0 Then Begin
    N:=0;
    Repeat
     Mop:=H4Ue;
     If Mop=0 Then Break;
     If (Mop>6) Or (N>=64) Or H4Err Then Exit;
     Sh.Mmco[N].Op:=Mop; Sh.Mmco[N].A1:=0; Sh.Mmco[N].A2:=0;
     If (Mop=1) Or (Mop=3) Then Sh.Mmco[N].A1:=H4Ue;
     If Mop=2 Then Sh.Mmco[N].A1:=H4Ue;
     If Mop=3 Then Sh.Mmco[N].A2:=H4Ue
     Else If (Mop=6) Or (Mop=4) Then Sh.Mmco[N].A1:=H4Ue;
     Inc(N);
    Until False;
    Sh.MmcoCount:=N;
   End;
  End;
 End;
 If (P^.Cabac<>0) And (Sh.SliceType<>2) And (Sh.SliceType<>4) Then Begin
  Sh.CabacInitIdc:=H4Ue;
  If Sh.CabacInitIdc>2 Then Exit;
 End;
 Sh.QpDelta:=H4Se;
 Sh.Qp:=P^.InitQp+Sh.QpDelta;
 If (Sh.Qp<0) Or (Sh.Qp>51) Then Exit;
 If (Sh.SliceType=3) Or (Sh.SliceType=4) Then Begin
  If Sh.SliceType=3 Then H4Bit;
  Sh.SliceQs:=P^.InitQs+H4Se;
 End;
 Sh.DisableDeblock:=0; Sh.AlphaOff:=0; Sh.BetaOff:=0;
 If P^.DeblockCtrl<>0 Then Begin
  Sh.DisableDeblock:=H4Ue;
  If Sh.DisableDeblock>2 Then Exit;
  If Sh.DisableDeblock<>1 Then Begin
   Sh.AlphaOff:=H4Se*2; Sh.BetaOff:=H4Se*2;
   If (Sh.AlphaOff<-12) Or (Sh.AlphaOff>12) Or (Sh.BetaOff<-12) Or (
    Sh.BetaOff>12) Then Exit;
  End;
 End;
 If H4Err Then Exit;
 H4ParseSlice:=0;
End;


{ ---- images, DPB, POC, marquage, listes de references ---- }
Type
 TH4Pic=Record
  Used: Boolean;
  Y,U,V: PEABuffer;
  MbType: PWordArr;
  Mv: Array[0..1] Of Pointer; Ref: Array[0..1] Of Pointer; RefId: Array[0..1] Of
   Pointer;
  Id,FrameNum,FrameNumWrap,Poc,PocTop,PocBot,LongIdx,RefState: LongInt;
  Output,NonExist,Idr,Mmco5,Cleared: Boolean;
  Pts,Dur: Int64; Seq: LongInt;
 End;
Var
 H4Pics: Array[0..H4MaxPics-1] Of TH4Pic;
 H4W,H4H,H4MbW,H4MbH,H4MbNum,H4StrideY,H4StrideC,H4Seq: LongInt;
 H4ActSps: LongInt;
 H4Cur: LongInt;
 H4NextId: LongInt;
 { etat POC / numerotation }
 H4PrevPocMsb,H4PrevPocLsb,H4PrevFrameNumOffset,H4FrameNumOffset,H4PrevFrameNum,
  H4PrevRefFrameNum: LongInt;
 H4PrevHadMmco5: Boolean; H4MaxLongIdx: LongInt;
 H4CurSh: TH4Slice;
 H4FirstSh: TH4Slice;
 H4Started: Boolean;
 H4RefList: Array[0..1,0..32] Of LongInt;   { indices dans H4Pics, -1 si vide }
 H4RefCount: Array[0..1] Of LongInt;
 H4OutQueue: Array[0..H4MaxPics-1] Of LongInt; H4OutCount: LongInt;
 H4ReorderDepth: LongInt;

Procedure H4FreePic(I: LongInt);
Begin
 With H4Pics[I] Do Begin
  If Used Then Begin
   FreeMem(Y); FreeMem(U); FreeMem(V); FreeMem(MbType);
   FreeMem(Mv[0]); FreeMem(Mv[1]); FreeMem(Ref[0]); FreeMem(Ref[1]); FreeMem(
    RefId[0]); FreeMem(RefId[1]);
  End;
  Used:=False;
 End;
End;
Procedure H4FreeAll;
Var I: LongInt;
Begin
 For I:=0 To H4MaxPics-1 Do H4FreePic(I);
 H4OutCount:=0;
End;

{ nouvelle image : renvoie l'indice }
Function H4NewPic: LongInt;
Var I,J,Best: LongInt; Busy: Boolean;
Begin
 Best:=-1;
 For I:=0 To H4MaxPics-1 Do Begin
  Busy:=False;
  If H4Pics[I].Used Then Begin
   If (H4Pics[I].RefState<>0) Or H4Pics[I].Output Then Busy:=True;
   If I=H4Cur Then Busy:=True;
  End;
  If Not Busy Then Begin Best:=I; Break; End;
 End;
 If Best<0 Then Begin H4NewPic:=-1; Exit; End;
 With H4Pics[Best] Do Begin
  If Not Used Then Begin
   GetMem(Y,H4StrideY*H4MbH*16+64); GetMem(U,H4StrideC*H4MbH*8+64); GetMem(V,
    H4StrideC*H4MbH*8+64);
   GetMem(MbType,H4MbNum*2+16);
   For J:=0 To 1 Do Begin
    GetMem(Mv[J],H4MbNum*64+16); GetMem(Ref[J],H4MbNum*4+16); GetMem(RefId[J],
     H4MbNum*16+16);
   End;
   Used:=True;
  End;
  FillChar(MbType^,H4MbNum*2,0);
  For J:=0 To 1 Do Begin FillChar(Mv[J]^,H4MbNum*64,0); FillChar(Ref[J]^,
   H4MbNum*4,255); FillChar(RefId[J]^,H4MbNum*16,255); End;
  Id:=H4NextId; Inc(H4NextId);
  RefState:=0; Output:=False; NonExist:=False; Idr:=False; Mmco5:=False;
   LongIdx:=-1; Pts:=0; Poc:=0; PocTop:=0; PocBot:=0; FrameNum:=0;
   FrameNumWrap:=0;
  Seq:=H4Seq;
 End;
 H4NewPic:=Best;
End;

{ ---- POC (8.2.1) ---- }
Procedure H4ComputePoc(Var Sh: TH4Slice; Var S: TH4Sps; Var Top,Bot: LongInt);
Var Msb,Lsb,MaxLsb,I,AbsFn,CycleCnt,InCycle,Exp,DeltaCycle,Tmp,MaxFn: LongInt;
Begin
 MaxFn:=1 Shl S.Log2MaxFrameNum;
 If S.PocType=0 Then Begin
  MaxLsb:=1 Shl S.Log2MaxPocLsb;
  If Sh.Idr<>0 Then Begin H4PrevPocMsb:=0; H4PrevPocLsb:=0; End
  Else If H4PrevHadMmco5 Then Begin H4PrevPocMsb:=0; End;
  Lsb:=Sh.PocLsb;
  If (Lsb<H4PrevPocLsb) And (H4PrevPocLsb-Lsb>=MaxLsb Div 2) Then Msb:=
   H4PrevPocMsb+MaxLsb
  Else If (Lsb>H4PrevPocLsb) And (Lsb-H4PrevPocLsb>MaxLsb Div 2) Then Msb:=
   H4PrevPocMsb-MaxLsb
  Else Msb:=H4PrevPocMsb;
  Top:=Msb+Lsb; Bot:=Top+Sh.DeltaPocBottom;
  If Sh.NalRefIdc<>0 Then Begin H4PrevPocMsb:=Msb; H4PrevPocLsb:=Lsb; End;
 End Else Begin
  If Sh.Idr<>0 Then H4FrameNumOffset:=0
  Else Begin
   If H4PrevHadMmco5 Then H4PrevFrameNumOffset:=0;
   If H4PrevFrameNum>Sh.FrameNum Then H4FrameNumOffset:=H4PrevFrameNumOffset+
    MaxFn Else H4FrameNumOffset:=H4PrevFrameNumOffset;
  End;
  If S.PocType=1 Then Begin
   If S.PocCycleLength<>0 Then AbsFn:=H4FrameNumOffset+Sh.FrameNum Else AbsFn:=
    0;
   If (Sh.NalRefIdc=0) And (AbsFn>0) Then Dec(AbsFn);
   Exp:=0;
   If AbsFn>0 Then Begin
    CycleCnt:=(AbsFn-1) Div S.PocCycleLength; InCycle:=(AbsFn-1) Mod
     S.PocCycleLength;
    DeltaCycle:=0; For I:=0 To S.PocCycleLength-1 Do Inc(DeltaCycle,
     S.OffsetForRefFrame[I]);
    Exp:=CycleCnt*DeltaCycle;
    For I:=0 To InCycle Do Inc(Exp,S.OffsetForRefFrame[I]);
   End;
   If Sh.NalRefIdc=0 Then Inc(Exp,S.OffsetForNonRefPic);
   Top:=Exp+Sh.DeltaPoc[0];
   Bot:=Top+S.OffsetForTopToBottom+Sh.DeltaPoc[1];
  End Else Begin
   If Sh.Idr<>0 Then Tmp:=0
   Else If Sh.NalRefIdc=0 Then Tmp:=2*(H4FrameNumOffset+Sh.FrameNum)-1
   Else Tmp:=2*(H4FrameNumOffset+Sh.FrameNum);
   Top:=Tmp; Bot:=Tmp;
  End;
 End;
End;

{ ---- sortie ---- }
Var H4Sink: Pointer;
Procedure H4EmitPic(I: LongInt); Forward;
Procedure H4Bump(Flush: Boolean);
Var I,J,Best: LongInt; T: LongInt;
Begin
 While H4OutCount>0 Do Begin
  If (Not Flush) And (H4OutCount<=H4ReorderDepth) Then Break;
  Best:=0;
  For J:=1 To H4OutCount-1 Do
   If H4Pics[H4OutQueue[J]].Poc<H4Pics[H4OutQueue[Best]].Poc Then Best:=J;
  T:=H4OutQueue[Best];
  For J:=Best To H4OutCount-2 Do H4OutQueue[J]:=H4OutQueue[J+1];
  Dec(H4OutCount);
  H4Pics[T].Output:=False;
  If Not H4Pics[T].NonExist Then H4EmitPic(T);
 End;
End;

{ ---- marquage des references (8.2.5) ---- }
Procedure H4Unmark(I: LongInt);
Begin
 H4Pics[I].RefState:=0; H4Pics[I].LongIdx:=-1;
End;
Procedure H4Marking(Var Sh: TH4Slice; Var S: TH4Sps; Cur: LongInt);
Var I,J,N,MaxFn,CurNum,PicX,Op,A1,A2,NShort,NLong,Oldest,Mn: LongInt; Mark5:
 Boolean;
Begin
 MaxFn:=1 Shl S.Log2MaxFrameNum;
 H4Pics[Cur].Mmco5:=False;
 If Sh.NalRefIdc=0 Then Exit;
 If Sh.Idr<>0 Then Begin
  For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) Then H4Unmark(I);
  If Sh.LongTermRef<>0 Then Begin H4Pics[Cur].RefState:=2; H4Pics[Cur].LongIdx:=
   0; H4MaxLongIdx:=0; End
  Else Begin H4Pics[Cur].RefState:=1; H4MaxLongIdx:=-1; End;
  Exit;
 End;
 CurNum:=Sh.FrameNum;
 For I:=0 To H4MaxPics-1 Do
  If H4Pics[I].Used And (H4Pics[I].RefState=1) Then Begin
   If H4Pics[I].FrameNum>Sh.FrameNum Then H4Pics[I].FrameNumWrap:=H4Pics[
    I].FrameNum-MaxFn Else H4Pics[I].FrameNumWrap:=H4Pics[I].FrameNum;
  End;
 Mark5:=False;
 If Sh.AdaptiveMarking<>0 Then Begin
  For N:=0 To Sh.MmcoCount-1 Do Begin
   Op:=Sh.Mmco[N].Op; A1:=Sh.Mmco[N].A1; A2:=Sh.Mmco[N].A2;
   Case Op Of
    1: Begin
     PicX:=CurNum-(A1+1);
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (I<>Cur) And (H4Pics[I].RefState=1) And (H4Pics[
       I].FrameNumWrap=PicX) Then H4Unmark(I);
    End;
    2: For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (H4Pics[I].RefState=2) And (H4Pics[I].LongIdx=A1)
       Then H4Unmark(I);
    3: Begin
     PicX:=CurNum-(A1+1);
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (H4Pics[I].RefState=2) And (H4Pics[I].LongIdx=A2)
       Then H4Unmark(I);
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (I<>Cur) And (H4Pics[I].RefState=1) And (H4Pics[
       I].FrameNumWrap=PicX) Then Begin
       H4Pics[I].RefState:=2; H4Pics[I].LongIdx:=A2;
      End;
    End;
    4: Begin
     H4MaxLongIdx:=A1-1;
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (H4Pics[I].RefState=2) And (H4Pics[
       I].LongIdx>H4MaxLongIdx) Then H4Unmark(I);
    End;
    5: Begin
     For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) Then H4Unmark(I);
     H4MaxLongIdx:=-1; Mark5:=True;
    End;
    6: Begin
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (I<>Cur) And (H4Pics[I].RefState=2) And (H4Pics[
       I].LongIdx=A1) Then H4Unmark(I);
     H4Pics[Cur].RefState:=2; H4Pics[Cur].LongIdx:=A1;
    End;
   End;
  End;
 End Else Begin
  { fenetre glissante }
  NShort:=0; NLong:=0;
  For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) Then Begin
   If H4Pics[I].RefState=1 Then Inc(NShort) Else If H4Pics[I].RefState=2 Then
    Inc(NLong);
  End;
  N:=S.RefFrameCount; If N<1 Then N:=1;
  If NShort+NLong>=N Then Begin
   Oldest:=-1; Mn:=High(LongInt);
   For I:=0 To H4MaxPics-1 Do
    If H4Pics[I].Used And (I<>Cur) And (H4Pics[I].RefState=1) And (H4Pics[
     I].FrameNumWrap<Mn) Then Begin Mn:=H4Pics[I].FrameNumWrap; Oldest:=I; End;
   If Oldest>=0 Then H4Unmark(Oldest);
  End;
 End;
 If H4Pics[Cur].RefState<>2 Then Begin H4Pics[Cur].RefState:=1; End;
 If Mark5 Then Begin H4Pics[Cur].Mmco5:=True; End;
End;

{ ---- listes de references (8.2.4) ---- }
Procedure H4BuildRefLists(Var Sh: TH4Slice; Var S: TH4Sps; Cur: LongInt);
Var I,J,K,L,N,MaxFn,CurNum,Pred,NoWrap,PicNum,Target,Cnt: LongInt; Tmp: Array[
 0..39] Of LongInt; Sh2: Array[0..39] Of LongInt;
 Short0,Short1,Long0: Array[0..39] Of LongInt; NS0,NS1,NL: LongInt; Key: Array[
  0..39] Of LongInt; Found: Boolean; Lst: Array[0..39] Of LongInt; Fill:
  LongInt;
 CurPoc: LongInt;
Procedure SortBy(Var A: Array Of LongInt; Cnt: LongInt; Desc: Boolean; Mode:
 LongInt);
Var P,Q,T,Ka,Kb: LongInt;
Begin
 For P:=0 To Cnt-2 Do For Q:=P+1 To Cnt-1 Do Begin
  If Mode=0 Then Begin Ka:=H4Pics[A[P]].FrameNumWrap; Kb:=H4Pics[A[
   Q]].FrameNumWrap; End
  Else If Mode=1 Then Begin Ka:=H4Pics[A[P]].Poc; Kb:=H4Pics[A[Q]].Poc; End
  Else Begin Ka:=H4Pics[A[P]].LongIdx; Kb:=H4Pics[A[Q]].LongIdx; End;
  If (Desc And (Kb>Ka)) Or ((Not Desc) And (Kb<Ka)) Then Begin T:=A[P]; A[P]:=A[
   Q]; A[Q]:=T; End;
 End;
End;
Begin
 MaxFn:=1 Shl S.Log2MaxFrameNum; CurNum:=Sh.FrameNum; CurPoc:=H4Pics[Cur].Poc;
 For L:=0 To 1 Do For I:=0 To 32 Do H4RefList[L,I]:=-1;
 H4RefCount[0]:=Sh.NumRef[0]; H4RefCount[1]:=Sh.NumRef[1];
 If (Sh.SliceType=2) Or (Sh.SliceType=4) Then Exit;
 For I:=0 To H4MaxPics-1 Do
  If H4Pics[I].Used And (H4Pics[I].RefState=1) Then Begin
   If H4Pics[I].FrameNum>Sh.FrameNum Then H4Pics[I].FrameNumWrap:=H4Pics[
    I].FrameNum-MaxFn Else H4Pics[I].FrameNumWrap:=H4Pics[I].FrameNum;
  End;
 NL:=0;
 For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) And (H4Pics[
  I].RefState=2) Then Begin Long0[NL]:=I; Inc(NL); End;
 SortBy(Long0,NL,False,2);
 If Sh.SliceType<>1 Then Begin
  NS0:=0;
  For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) And (H4Pics[
   I].RefState=1) Then Begin Short0[NS0]:=I; Inc(NS0); End;
  SortBy(Short0,NS0,True,0);
  K:=0; For I:=0 To NS0-1 Do Begin H4RefList[0,K]:=Short0[I]; Inc(K); End;
  For I:=0 To NL-1 Do Begin H4RefList[0,K]:=Long0[I]; Inc(K); End;
  Cnt:=K;
 End Else Begin
  { B : liste 0 : POC inferieurs decroissants puis superieurs croissants }
  NS0:=0; NS1:=0;
  For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) And (H4Pics[
   I].RefState=1) Then Begin
   If H4Pics[I].Poc<=CurPoc Then Begin Short0[NS0]:=I; Inc(NS0); End Else Begin
    Short1[NS1]:=I; Inc(NS1); End;
  End;
  SortBy(Short0,NS0,True,1); SortBy(Short1,NS1,False,1);
  K:=0;
  For I:=0 To NS0-1 Do Begin H4RefList[0,K]:=Short0[I]; Inc(K); End;
  For I:=0 To NS1-1 Do Begin H4RefList[0,K]:=Short1[I]; Inc(K); End;
  For I:=0 To NL-1 Do Begin H4RefList[0,K]:=Long0[I]; Inc(K); End;
  Cnt:=K;
  K:=0;
  For I:=0 To NS1-1 Do Begin H4RefList[1,K]:=Short1[I]; Inc(K); End;
  For I:=0 To NS0-1 Do Begin H4RefList[1,K]:=Short0[I]; Inc(K); End;
  For I:=0 To NL-1 Do Begin H4RefList[1,K]:=Long0[I]; Inc(K); End;
  If (K>1) Then Begin
   Found:=True;
   For I:=0 To K-1 Do If H4RefList[0,I]<>H4RefList[1,I] Then Found:=False;
   If Found Then Begin I:=H4RefList[1,0]; H4RefList[1,0]:=H4RefList[1,1];
    H4RefList[1,1]:=I; End;
  End;
  N:=K;
 End;
 { modification }
 For L:=0 To 1 Do Begin
  If (L=1) And (Sh.SliceType<>1) Then Break;
  If Sh.ModFlag[L]<>0 Then Begin
   Pred:=CurNum; K:=0;
   For I:=0 To Sh.ModCount[L]-1 Do Begin
    If Sh.ModIdc[L,I]<2 Then Begin
     If Sh.ModIdc[L,I]=0 Then Begin
      NoWrap:=Pred-(Sh.ModVal[L,I]+1); If NoWrap<0 Then Inc(NoWrap,MaxFn);
     End Else Begin
      NoWrap:=Pred+(Sh.ModVal[L,I]+1); If NoWrap>=MaxFn Then Dec(NoWrap,MaxFn);
     End;
     Pred:=NoWrap;
     If NoWrap>CurNum Then PicNum:=NoWrap-MaxFn Else PicNum:=NoWrap;
     Target:=-1;
     For J:=0 To H4MaxPics-1 Do If H4Pics[J].Used And (J<>Cur) And (H4Pics[
      J].RefState=1) And (H4Pics[J].FrameNumWrap=PicNum) Then Target:=J;
    End Else Begin
     Target:=-1;
     For J:=0 To H4MaxPics-1 Do If H4Pics[J].Used And (J<>Cur) And (H4Pics[
      J].RefState=2) And (H4Pics[J].LongIdx=Sh.ModVal[L,I]) Then Target:=J;
    End;
    If K<33 Then Begin
     { insertion en position K, decalage, suppression du doublon }
     For J:=32 DownTo K+1 Do H4RefList[L,J]:=H4RefList[L,J-1];
     H4RefList[L,K]:=Target; Inc(K);
     N:=K;
     For J:=K To 32 Do If H4RefList[L,J]<>Target Then Begin H4RefList[L,N]:=
      H4RefList[L,J]; Inc(N); End;
     For J:=N To 32 Do H4RefList[L,J]:=-1;
    End;
   End;
  End;
 End;
 { remplissage des entrees absentes par la premiere reference (comme ffmpeg) }
 For L:=0 To 1 Do Begin
  If (L=1) And (Sh.SliceType<>1) Then Break;
  Fill:=-1;
  For I:=0 To Sh.NumRef[L]-1 Do If H4RefList[L,I]>=0 Then Begin Fill:=H4RefList[
   L,I]; Break; End;
  For I:=0 To Sh.NumRef[L]-1 Do If H4RefList[L,I]<0 Then H4RefList[L,I]:=Fill;
 End;
End;


{ ---- CAVLC ---- }
Type
 TH4Vlc=Record Bits: LongInt; T: PWord; End;
Var
 H4CoeffTok: Array[0..2] Of TH4Vlc;       { nC 0-1, 2-3, 4-7 }
 H4ChromaDcTok,H4Chroma422Tok: TH4Vlc;
 H4TotZeros: Array[1..15] Of TH4Vlc;
 H4ChromaDcZeros: Array[1..3] Of TH4Vlc;
 H4Chroma422Zeros: Array[1..7] Of TH4Vlc;
 H4RunBefore: Array[1..7] Of TH4Vlc;
 H4TabsReady: Boolean;

{ construit une table de decodage : entree = (symbole shl 5) or longueur }
Procedure H4MakeVlc(Var V: TH4Vlc; N: LongInt; Lens,Codes: PEABuffer; Stride:
 LongInt; MaxBits: LongInt);
Var I,J,L,C,Cnt: LongInt;
Begin
 V.Bits:=MaxBits; Cnt:=1 Shl MaxBits;
 GetMem(V.T,Cnt*2);
 FillChar(V.T^,Cnt*2,0);
 For I:=0 To N-1 Do Begin
  L:=Lens^[I*Stride]; C:=Codes^[I*Stride];
  If L=0 Then Continue;
  For J:=0 To (1 Shl (MaxBits-L))-1 Do
   PWordArr(V.T)^[(C Shl (MaxBits-L))+J]:=(I Shl 5) Or L;
 End;
End;
Function H4GetVlc(Var V: TH4Vlc): LongInt;
Var E: Word; P: Int64;
Begin
 P:=H4Peek32;
 E:=PWordArr(V.T)^[P Shr (32-V.Bits)];
 If (E And 31)=0 Then Begin H4Err:=True; H4GetVlc:=-1; Exit; End;
 Inc(H4Pos,E And 31);
 H4GetVlc:=E Shr 5;
End;
Procedure H4InitTabs;
Var I,J: LongInt; Len1,Cod1: Array[0..255] Of Byte; N: LongInt;
Begin
 If H4TabsReady Then Exit;
 For I:=0 To 2 Do H4MakeVlc(H4CoeffTok[I],68,@H4CoeffTokenLen[I*68],
  @H4CoeffTokenBits[I*68],1,16);
 H4MakeVlc(H4ChromaDcTok,20,@H4ChromaDcCoeffTokenLen,@H4ChromaDcCoeffTokenBits,
  1,8);
 H4MakeVlc(H4Chroma422Tok,36,@H4Chroma422DcCoeffTokenLen,
  @H4Chroma422DcCoeffTokenBits,1,13);
 For I:=1 To 15 Do H4MakeVlc(H4TotZeros[I],16,@H4TotalZerosLen[(I-1)*16],
  @H4TotalZerosBits[(I-1)*16],1,9);
 For I:=1 To 3 Do H4MakeVlc(H4ChromaDcZeros[I],4,@H4ChromaDcTotalZerosLen[(I-1)*
  4],@H4ChromaDcTotalZerosBits[(I-1)*4],1,3);
 For I:=1 To 7 Do H4MakeVlc(H4Chroma422Zeros[I],8,@H4Chroma422DcTotalZerosLen[(
  I-1)*8],@H4Chroma422DcTotalZerosBits[(I-1)*8],1,5);
 For I:=1 To 7 Do H4MakeVlc(H4RunBefore[I],16,@H4RunLen[(I-1)*16],@H4RunBits[(I-
  1)*16],1,11);
 H4TabsReady:=True;
End;

{ residu CAVLC d'un bloc : renvoie TotalCoeff (ou -3 si erreur) ; Lev recoit les
 niveaux par position de balayage (0..MaxCoeff-1)
  NC = -1 : DC chroma 4:2:0 ; -2 : DC chroma 4:2:2 ; sinon contexte nC }
Function H4CavlcBlock(Var Lev: Array Of LongInt; MaxCoeff,NC: LongInt): LongInt;
Var Tok,Total,T1,I,Suffix,Prefix,LevelCode,SufSize,ZerosLeft,Coeff,Idx,Lv:
 LongInt;
 Vals,RunV: Array[0..15] Of LongInt; Vl: ^TH4Vlc;
Begin
 For I:=0 To MaxCoeff-1 Do Lev[I]:=0;
 H4CavlcBlock:=0;
 If NC=-1 Then Tok:=H4GetVlc(H4ChromaDcTok)
 Else If NC=-2 Then Tok:=H4GetVlc(H4Chroma422Tok)
 Else If NC>=8 Then Begin
  Tok:=H4Bits(6);
  If Tok=3 Then Tok:=0 Else Tok:=((Tok Shr 2)+1)*4+(Tok And 3);
 End Else Begin
  If NC<2 Then Idx:=0 Else If NC<4 Then Idx:=1 Else Idx:=2;
  Tok:=H4GetVlc(H4CoeffTok[Idx]);
 End;
 If Tok<0 Then Begin H4CavlcBlock:=-3; Exit; End;
 Total:=Tok Shr 2; T1:=Tok And 3;
 If Total=0 Then Exit;
 If Total>MaxCoeff Then Begin H4Err:=True; H4CavlcBlock:=-3; Exit; End;
 If (Total>10) And (T1<3) Then Suffix:=1 Else Suffix:=0;
 For I:=0 To Total-1 Do Begin
  If I<T1 Then Begin
   If H4Bit<>0 Then Vals[I]:=-1 Else Vals[I]:=1;
  End Else Begin
   Prefix:=0;
   While (H4Bit=0) And (Prefix<32) Do Inc(Prefix);
   If Prefix>=32 Then Begin H4Err:=True; H4CavlcBlock:=-3; Exit; End;
   If (Prefix=14) And (Suffix=0) Then SufSize:=4
   Else If Prefix>=15 Then SufSize:=Prefix-3
   Else SufSize:=Suffix;
   If Prefix<15 Then LevelCode:=Prefix Shl Suffix Else LevelCode:=15 Shl Suffix;
   If SufSize>0 Then Inc(LevelCode,H4Bits(SufSize));
   If (Prefix>=15) And (Suffix=0) Then Inc(LevelCode,15);
   If Prefix>=16 Then Inc(LevelCode,(1 Shl (Prefix-3))-4096);
   If (I=T1) And (T1<3) Then Inc(LevelCode,2);
   If (LevelCode And 1)=0 Then Lv:=(LevelCode+2) Shr 1 Else Lv:=(-LevelCode-1)
    Div 2;
   If Suffix=0 Then Suffix:=1;
   If (Abs(Lv)>(3 Shl (Suffix-1))) And (Suffix<6) Then Inc(Suffix);
   Vals[I]:=Lv;
  End;
 End;
 If Total<MaxCoeff Then Begin
  If NC=-1 Then Vl:=@H4ChromaDcZeros[Total]
  Else If NC=-2 Then Vl:=@H4Chroma422Zeros[Total]
  Else Vl:=@H4TotZeros[Total];
  ZerosLeft:=H4GetVlc(Vl^);
  If ZerosLeft<0 Then Begin H4CavlcBlock:=-3; Exit; End;
 End Else ZerosLeft:=0;
 For I:=0 To Total-2 Do Begin
  If ZerosLeft>0 Then Begin
   Idx:=ZerosLeft; If Idx>7 Then Idx:=7;
   RunV[I]:=H4GetVlc(H4RunBefore[Idx]);
   If RunV[I]<0 Then Begin H4CavlcBlock:=-3; Exit; End;
   Dec(ZerosLeft,RunV[I]);
   If ZerosLeft<0 Then Begin H4Err:=True; H4CavlcBlock:=-3; Exit; End;
  End Else RunV[I]:=0;
 End;
 RunV[Total-1]:=ZerosLeft;
 Coeff:=-1;
 For I:=Total-1 DownTo 0 Do Begin
  Inc(Coeff,RunV[I]+1);
  If Coeff>=MaxCoeff Then Begin H4Err:=True; H4CavlcBlock:=-3; Exit; End;
  Lev[Coeff]:=Vals[I];
 End;
 H4CavlcBlock:=Total;
End;


{ ---- prediction intra et transformees ---- }
Function H4Sar(V: LongInt; N: LongInt): LongInt;
Begin If V>=0 Then H4Sar:=V Shr N Else H4Sar:=-((-V+(1 Shl N)-1) Shr N); End;
Function H4Clip(V: LongInt): LongInt;
Begin If V<0 Then H4Clip:=0 Else If V>255 Then H4Clip:=255 Else H4Clip:=V; End;
Function H4Clip3(Lo,Hi,V: LongInt): LongInt;
Begin If V<Lo Then H4Clip3:=Lo Else If V>Hi Then H4Clip3:=Hi Else H4Clip3:=V;
 End;

{ le mode de prediction intra demande est-il realisable avec les voisins
 disponibles ? }
Function H4OkMode(Mode: LongInt; L,T,TL: Boolean): Boolean;
Begin
 Case Mode Of
  0,3,7: H4OkMode:=T;
  1,8: H4OkMode:=L;
  2: H4OkMode:=True;
 Else H4OkMode:=L And T And TL;
 End;
End;
Function H4OkMode16(Mode: LongInt; L,T,TL: Boolean): Boolean;
Begin
 Case Mode Of
  0: H4OkMode16:=T;
  1: H4OkMode16:=L;
  2: H4OkMode16:=True;
 Else H4OkMode16:=L And T And TL;
 End;
End;
Function H4OkModeC(Mode: LongInt; L,T,TL: Boolean): Boolean;
Begin
 Case Mode Of
  0: H4OkModeC:=True;
  1: H4OkModeC:=L;
  2: H4OkModeC:=T;
 Else H4OkModeC:=L And T And TL;
 End;
End;

Procedure H4Pred4x4(Pl: PEABuffer; Stride,X,Y,Mode: LongInt; AvL,AvT,AvTR,AvTL:
 Boolean);
Var T: Array[0..7] Of LongInt; L: Array[0..3] Of LongInt; Tl,I,J,Z,Sum,V,Q:
 LongInt; E: Array[0..8] Of LongInt; Pr: Array[0..3,0..3] Of LongInt;
Function Tt(Idx: LongInt): LongInt; { Idx -1 = coin }
Begin If Idx<0 Then Tt:=Tl Else Tt:=T[Idx]; End;
Function Ll(Idx: LongInt): LongInt;
Begin If Idx<0 Then Ll:=Tl Else Ll:=L[Idx]; End;
Begin
 If AvT Then Begin
  For I:=0 To 3 Do T[I]:=Pl^[(Y-1)*Stride+X+I];
  If AvTR Then For I:=4 To 7 Do T[I]:=Pl^[(Y-1)*Stride+X+I] Else For I:=4 To 7
   Do T[I]:=T[3];
 End;
 If AvL Then For I:=0 To 3 Do L[I]:=Pl^[(Y+I)*Stride+X-1];
 If AvTL Then Tl:=Pl^[(Y-1)*Stride+X-1];
 Case Mode Of
  0: For J:=0 To 3 Do For I:=0 To 3 Do Pr[J,I]:=T[I];
  1: For J:=0 To 3 Do For I:=0 To 3 Do Pr[J,I]:=L[J];
  2: Begin
   If AvT And AvL Then V:=(T[0]+T[1]+T[2]+T[3]+L[0]+L[1]+L[2]+L[3]+4) Shr 3
   Else If AvL Then V:=(L[0]+L[1]+L[2]+L[3]+2) Shr 2
   Else If AvT Then V:=(T[0]+T[1]+T[2]+T[3]+2) Shr 2
   Else V:=128;
   For J:=0 To 3 Do For I:=0 To 3 Do Pr[J,I]:=V;
  End;
  3: For J:=0 To 3 Do For I:=0 To 3 Do
      If (I=3) And (J=3) Then Pr[J,I]:=(T[6]+3*T[7]+2) Shr 2
      Else Pr[J,I]:=(T[I+J]+2*T[I+J+1]+T[I+J+2]+2) Shr 2;
  4: Begin
   E[0]:=L[3]; E[1]:=L[2]; E[2]:=L[1]; E[3]:=L[0]; E[4]:=Tl; E[5]:=T[0]; E[6]:=
    T[1]; E[7]:=T[2]; E[8]:=T[3];
   For J:=0 To 3 Do For I:=0 To 3 Do
    Pr[J,I]:=(E[4+I-J-1]+2*E[4+I-J]+E[4+I-J+1]+2) Shr 2;
  End;
  5: For J:=0 To 3 Do For I:=0 To 3 Do Begin
      Z:=2*I-J;
      If Z>=0 Then Begin
       If (Z And 1)=0 Then Pr[J,I]:=(Tt(I-(J Shr 1)-1)+Tt(I-(J Shr 1))+1) Shr 1
       Else Pr[J,I]:=(Tt(I-(J Shr 1)-2)+2*Tt(I-(J Shr 1)-1)+Tt(I-(J Shr 1))+2)
        Shr 2;
      End Else If Z=-1 Then Pr[J,I]:=(L[0]+2*Tl+T[0]+2) Shr 2
      Else Pr[J,I]:=(Ll(J-1)+2*Ll(J-2)+Ll(J-3)+2) Shr 2;
     End;
  6: For J:=0 To 3 Do For I:=0 To 3 Do Begin
      Z:=2*J-I;
      If Z>=0 Then Begin
       If (Z And 1)=0 Then Pr[J,I]:=(Ll(J-(I Shr 1)-1)+Ll(J-(I Shr 1))+1) Shr 1
       Else Pr[J,I]:=(Ll(J-(I Shr 1)-2)+2*Ll(J-(I Shr 1)-1)+Ll(J-(I Shr 1))+2)
        Shr 2;
      End Else If Z=-1 Then Pr[J,I]:=(L[0]+2*Tl+T[0]+2) Shr 2
      Else Pr[J,I]:=(Tt(I-1)+2*Tt(I-2)+Tt(I-3)+2) Shr 2;
     End;
  7: For J:=0 To 3 Do For I:=0 To 3 Do Begin
      If (J And 1)=0 Then Pr[J,I]:=(T[I+(J Shr 1)]+T[I+(J Shr 1)+1]+1) Shr 1
      Else Pr[J,I]:=(T[I+(J Shr 1)]+2*T[I+(J Shr 1)+1]+T[I+(J Shr 1)+2]+2) Shr
       2;
     End;
  8: For J:=0 To 3 Do For I:=0 To 3 Do Begin
      Z:=I+2*J;
      If Z>5 Then Pr[J,I]:=L[3]
      Else If Z=5 Then Pr[J,I]:=(L[2]+3*L[3]+2) Shr 2
      Else If (Z And 1)=0 Then Pr[J,I]:=(L[J+(I Shr 1)]+L[J+(I Shr 1)+1]+1) Shr
       1
      Else Pr[J,I]:=(L[J+(I Shr 1)]+2*L[J+(I Shr 1)+1]+L[J+(I Shr 1)+2]+2) Shr
       2;
     End;
 End;
 For J:=0 To 3 Do For I:=0 To 3 Do Pl^[(Y+J)*Stride+X+I]:=Pr[J,I];
End;

{ prediction 8x8 avec filtrage des echantillons de reference (8.3.2.2) }
Procedure H4Pred8x8(Pl: PEABuffer; Stride,X,Y,Mode: LongInt; AvL,AvT,AvTR,AvTL:
 Boolean);
Var P: Array[-1..15] Of LongInt;   { haut : P[0..15] ; coin : P[-1] }
 Q: Array[0..7] Of LongInt;         { gauche filtre/brut }
 F: Array[-1..15] Of LongInt; G: Array[0..7] Of LongInt; Lr: Array[0..7] Of
  LongInt;
 Ftl: LongInt; I,J,Z,V,Sum: LongInt; Pr: Array[0..7,0..7] Of LongInt;
 Raw: Array[0..15] Of LongInt; Lraw: Array[0..7] Of LongInt; Tlraw: LongInt;
Function Ft(Idx: LongInt): LongInt; Begin If Idx<0 Then Ft:=Ftl Else Ft:=F[Idx];
 End;
Function Gl(Idx: LongInt): LongInt; Begin If Idx<0 Then Gl:=Ftl Else Gl:=G[Idx];
 End;
Begin
 If AvT Then Begin
  For I:=0 To 7 Do Raw[I]:=Pl^[(Y-1)*Stride+X+I];
  If AvTR Then For I:=8 To 15 Do Raw[I]:=Pl^[(Y-1)*Stride+X+I] Else For I:=8 To
   15 Do Raw[I]:=Raw[7];
 End;
 If AvL Then For I:=0 To 7 Do Lraw[I]:=Pl^[(Y+I)*Stride+X-1];
 If AvTL Then Tlraw:=Pl^[(Y-1)*Stride+X-1];
 { filtrage }
 If AvT Then Begin
  If AvTL Then F[0]:=(Tlraw+2*Raw[0]+Raw[1]+2) Shr 2 Else F[0]:=(3*Raw[0]+Raw[
   1]+2) Shr 2;
  For I:=1 To 14 Do F[I]:=(Raw[I-1]+2*Raw[I]+Raw[I+1]+2) Shr 2;
  F[15]:=(Raw[14]+3*Raw[15]+2) Shr 2;
 End;
 If AvTL Then Begin
  If AvT And AvL Then Ftl:=(Raw[0]+2*Tlraw+Lraw[0]+2) Shr 2
  Else If AvT Then Ftl:=(3*Tlraw+Raw[0]+2) Shr 2
  Else If AvL Then Ftl:=(3*Tlraw+Lraw[0]+2) Shr 2
  Else Ftl:=Tlraw;
 End;
 If AvL Then Begin
  If AvTL Then G[0]:=(Tlraw+2*Lraw[0]+Lraw[1]+2) Shr 2 Else G[0]:=(3*Lraw[0]+
   Lraw[1]+2) Shr 2;
  For I:=1 To 6 Do G[I]:=(Lraw[I-1]+2*Lraw[I]+Lraw[I+1]+2) Shr 2;
  G[7]:=(Lraw[6]+3*Lraw[7]+2) Shr 2;
 End;
 Case Mode Of
  0: For J:=0 To 7 Do For I:=0 To 7 Do Pr[J,I]:=F[I];
  1: For J:=0 To 7 Do For I:=0 To 7 Do Pr[J,I]:=G[J];
  2: Begin
   Sum:=0;
   If AvT And AvL Then Begin For I:=0 To 7 Do Inc(Sum,F[I]+G[I]); V:=(Sum+8) Shr
    4; End
   Else If AvL Then Begin For I:=0 To 7 Do Inc(Sum,G[I]); V:=(Sum+4) Shr 3; End
   Else If AvT Then Begin For I:=0 To 7 Do Inc(Sum,F[I]); V:=(Sum+4) Shr 3; End
   Else V:=128;
   For J:=0 To 7 Do For I:=0 To 7 Do Pr[J,I]:=V;
  End;
  3: For J:=0 To 7 Do For I:=0 To 7 Do
      If (I=7) And (J=7) Then Pr[J,I]:=(F[14]+3*F[15]+2) Shr 2
      Else Pr[J,I]:=(F[I+J]+2*F[I+J+1]+F[I+J+2]+2) Shr 2;
  4: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      If I>J Then Pr[J,I]:=(Ft(I-J-2)+2*Ft(I-J-1)+Ft(I-J)+2) Shr 2
      Else If I<J Then Pr[J,I]:=(Gl(J-I-2)+2*Gl(J-I-1)+Gl(J-I)+2) Shr 2
      Else Pr[J,I]:=(F[0]+2*Ftl+G[0]+2) Shr 2;
     End;
  5: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      Z:=2*I-J;
      If Z>=0 Then Begin
       If (Z And 1)=0 Then Pr[J,I]:=(Ft(I-(J Shr 1)-1)+Ft(I-(J Shr 1))+1) Shr 1
       Else Pr[J,I]:=(Ft(I-(J Shr 1)-2)+2*Ft(I-(J Shr 1)-1)+Ft(I-(J Shr 1))+2)
        Shr 2;
      End Else If Z=-1 Then Pr[J,I]:=(G[0]+2*Ftl+F[0]+2) Shr 2
      Else Pr[J,I]:=(Gl(J-2*I-1)+2*Gl(J-2*I-2)+Gl(J-2*I-3)+2) Shr 2;
     End;
  6: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      Z:=2*J-I;
      If Z>=0 Then Begin
       If (Z And 1)=0 Then Pr[J,I]:=(Gl(J-(I Shr 1)-1)+Gl(J-(I Shr 1))+1) Shr 1
       Else Pr[J,I]:=(Gl(J-(I Shr 1)-2)+2*Gl(J-(I Shr 1)-1)+Gl(J-(I Shr 1))+2)
        Shr 2;
      End Else If Z=-1 Then Pr[J,I]:=(G[0]+2*Ftl+F[0]+2) Shr 2
      Else Pr[J,I]:=(Ft(I-2*J-1)+2*Ft(I-2*J-2)+Ft(I-2*J-3)+2) Shr 2;
     End;
  7: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      If (J And 1)=0 Then Pr[J,I]:=(F[I+(J Shr 1)]+F[I+(J Shr 1)+1]+1) Shr 1
      Else Pr[J,I]:=(F[I+(J Shr 1)]+2*F[I+(J Shr 1)+1]+F[I+(J Shr 1)+2]+2) Shr
       2;
     End;
  8: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      Z:=I+2*J;
      If Z>13 Then Pr[J,I]:=G[7]
      Else If Z=13 Then Pr[J,I]:=(G[6]+3*G[7]+2) Shr 2
      Else If (Z And 1)=0 Then Pr[J,I]:=(G[J+(I Shr 1)]+G[J+(I Shr 1)+1]+1) Shr
       1
      Else Pr[J,I]:=(G[J+(I Shr 1)]+2*G[J+(I Shr 1)+1]+G[J+(I Shr 1)+2]+2) Shr
       2;
     End;
 End;
 For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(Y+J)*Stride+X+I]:=Pr[J,I];
End;

Procedure H4Pred16x16(Pl: PEABuffer; Stride,X,Y,Mode: LongInt; AvL,AvT:
 Boolean);
Var I,J,V,SumT,SumL,A,B,C,H,Vv: LongInt;
Begin
 Case Mode Of
  0: For J:=0 To 15 Do For I:=0 To 15 Do Pl^[(Y+J)*Stride+X+I]:=Pl^[(Y-1)*
   Stride+X+I];
  1: For J:=0 To 15 Do Begin V:=Pl^[(Y+J)*Stride+X-1]; For I:=0 To 15 Do Pl^[(Y+
   J)*Stride+X+I]:=V; End;
  2: Begin
   SumT:=0; SumL:=0;
   If AvT Then For I:=0 To 15 Do Inc(SumT,Pl^[(Y-1)*Stride+X+I]);
   If AvL Then For J:=0 To 15 Do Inc(SumL,Pl^[(Y+J)*Stride+X-1]);
   If AvT And AvL Then V:=(SumT+SumL+16) Shr 5
   Else If AvL Then V:=(SumL+8) Shr 4
   Else If AvT Then V:=(SumT+8) Shr 4
   Else V:=128;
   For J:=0 To 15 Do For I:=0 To 15 Do Pl^[(Y+J)*Stride+X+I]:=V;
  End;
  3: Begin
   H:=0; Vv:=0;
   For I:=0 To 7 Do Begin
    Inc(H,(I+1)*(Pl^[(Y-1)*Stride+X+8+I]-Pl^[(Y-1)*Stride+X+6-I]));
    Inc(Vv,(I+1)*(Pl^[(Y+8+I)*Stride+X-1]-Pl^[(Y+6-I)*Stride+X-1]));
   End;
   A:=16*(Pl^[(Y+15)*Stride+X-1]+Pl^[(Y-1)*Stride+X+15]);
   B:=H4Sar(5*H+32,6); C:=H4Sar(5*Vv+32,6);
   For J:=0 To 15 Do For I:=0 To 15 Do
    Pl^[(Y+J)*Stride+X+I]:=H4Clip(H4Sar(A+B*(I-7)+C*(J-7)+16,5));
  End;
 End;
End;

{ chroma 4:2:0 (8x8) : 0 DC, 1 horizontal, 2 vertical, 3 plan }
Procedure H4PredChroma(Pl: PEABuffer; Stride,X,Y,Mode: LongInt; AvL,AvT:
 Boolean);
Var I,J,V,A,B,C,H,Vv,Bx,By,S0,S1,SL0,SL1: LongInt;
Begin
 Case Mode Of
  0: For By:=0 To 1 Do For Bx:=0 To 1 Do Begin
      S0:=0; S1:=0;
      If AvT Then For I:=0 To 3 Do Inc(S0,Pl^[(Y-1)*Stride+X+Bx*4+I]);
      If AvL Then For J:=0 To 3 Do Inc(S1,Pl^[(Y+By*4+J)*Stride+X-1]);
      If (Bx=0) And (By=0) Or (Bx=1) And (By=1) Then Begin
       If AvT And AvL Then V:=(S0+S1+4) Shr 3
       Else If AvL Then V:=(S1+2) Shr 2
       Else If AvT Then V:=(S0+2) Shr 2
       Else V:=128;
      End Else If (Bx=1) And (By=0) Then Begin
       If AvT Then V:=(S0+2) Shr 2
       Else If AvL Then V:=(S1+2) Shr 2
       Else V:=128;
      End Else Begin
       If AvL Then V:=(S1+2) Shr 2
       Else If AvT Then V:=(S0+2) Shr 2
       Else V:=128;
      End;
      For J:=0 To 3 Do For I:=0 To 3 Do Pl^[(Y+By*4+J)*Stride+X+Bx*4+I]:=V;
     End;
  1: For J:=0 To 7 Do Begin V:=Pl^[(Y+J)*Stride+X-1]; For I:=0 To 7 Do Pl^[(Y+
   J)*Stride+X+I]:=V; End;
  2: For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(Y+J)*Stride+X+I]:=Pl^[(Y-1)*Stride+
   X+I];
  3: Begin
   H:=0; Vv:=0;
   For I:=0 To 3 Do Begin
    Inc(H,(I+1)*(Pl^[(Y-1)*Stride+X+4+I]-Pl^[(Y-1)*Stride+X+2-I]));
    Inc(Vv,(I+1)*(Pl^[(Y+4+I)*Stride+X-1]-Pl^[(Y+2-I)*Stride+X-1]));
   End;
   A:=16*(Pl^[(Y+7)*Stride+X-1]+Pl^[(Y-1)*Stride+X+7]);
   B:=H4Sar(34*H+32,6); C:=H4Sar(34*Vv+32,6);
   For J:=0 To 7 Do For I:=0 To 7 Do
    Pl^[(Y+J)*Stride+X+I]:=H4Clip(H4Sar(A+B*(I-3)+C*(J-3)+16,5));
  End;
 End;
End;

{ ---- transformees inverses ---- }
{ ajoute le residu 4x4 (D en raster, deja quantifie inverse) a l'image }
Procedure H4Idct4(Var D: Array Of LongInt; Pl: PEABuffer; Stride,X,Y: LongInt);
Var I,J,E0,E1,E2,E3: LongInt; T: Array[0..15] Of LongInt;
Begin
 For I:=0 To 3 Do Begin
  E0:=D[I*4]+D[I*4+2]; E1:=D[I*4]-D[I*4+2]; E2:=H4Sar(D[I*4+1],1)-D[I*4+3]; E3:=
   D[I*4+1]+H4Sar(D[I*4+3],1);
  T[I*4]:=E0+E3; T[I*4+1]:=E1+E2; T[I*4+2]:=E1-E2; T[I*4+3]:=E0-E3;
 End;
 For J:=0 To 3 Do Begin
  E0:=T[J]+T[8+J]; E1:=T[J]-T[8+J]; E2:=H4Sar(T[4+J],1)-T[12+J]; E3:=T[4+J]+
   H4Sar(T[12+J],1);
  Pl^[Y*Stride+X+J]:=H4Clip(Pl^[Y*Stride+X+J]+H4Sar(E0+E3+32,6));
  Pl^[(Y+1)*Stride+X+J]:=H4Clip(Pl^[(Y+1)*Stride+X+J]+H4Sar(E1+E2+32,6));
  Pl^[(Y+2)*Stride+X+J]:=H4Clip(Pl^[(Y+2)*Stride+X+J]+H4Sar(E1-E2+32,6));
  Pl^[(Y+3)*Stride+X+J]:=H4Clip(Pl^[(Y+3)*Stride+X+J]+H4Sar(E0-E3+32,6));
 End;
End;

Procedure H4Idct8(Var D: Array Of LongInt; Pl: PEABuffer; Stride,X,Y: LongInt);
Var I,J: LongInt; T: Array[0..63] Of LongInt; Cv: Array[0..7] Of LongInt; Out:
 Array[0..7] Of LongInt;
Procedure One(Var In0: Array Of LongInt);
Var A0,A1,A2,A3,A4,A5,A6,A7,B0,B1,B2,B3,B4,B5,B6,B7: LongInt;
Begin
 A0:=In0[0]+In0[4]; A4:=In0[0]-In0[4]; A2:=H4Sar(In0[2],1)-In0[6]; A6:=In0[2]+
  H4Sar(In0[6],1);
 B0:=A0+A6; B2:=A4+A2; B4:=A4-A2; B6:=A0-A6;
 A1:=-In0[3]+In0[5]-In0[7]-H4Sar(In0[7],1);
 A3:=In0[1]+In0[7]-In0[3]-H4Sar(In0[3],1);
 A5:=-In0[1]+In0[7]+In0[5]+H4Sar(In0[5],1);
 A7:=In0[3]+In0[5]+In0[1]+H4Sar(In0[1],1);
 B1:=A1+H4Sar(A7,2); B7:=A7-H4Sar(A1,2); B3:=A3+H4Sar(A5,2); B5:=H4Sar(A3,2)-A5;
 Out[0]:=B0+B7; Out[1]:=B2+B5; Out[2]:=B4+B3; Out[3]:=B6+B1; Out[4]:=B6-B1; Out[
  5]:=B4-B3; Out[6]:=B2-B5; Out[7]:=B0-B7;
End;
Begin
 For I:=0 To 7 Do Begin
  For J:=0 To 7 Do Cv[J]:=D[I*8+J];
  One(Cv);
  For J:=0 To 7 Do T[I*8+J]:=Out[J];
 End;
 For J:=0 To 7 Do Begin
  For I:=0 To 7 Do Cv[I]:=T[I*8+J];
  One(Cv);
  For I:=0 To 7 Do Pl^[(Y+I)*Stride+X+J]:=H4Clip(Pl^[(Y+I)*Stride+X+J]+H4Sar(
   Out[I]+32,6));
 End;
End;


{ ---- decodage de l'image courante ---- }
Const
 MT_I4=1; MT_I16=2; MT_PCM=4; MT_I8=8; MT_INTRA=15; MT_INTER=16; MT_SKIP=32;
  MT_DIRECT=64; MT_P8=128; MT_16X8=256; MT_8X16=512; MT_16X16=1024; MT_L0=2048;
  MT_L1=4096;
Var
 H4SliceTab: PLongArr;
 H4QpTab,H4NnzTab,H4IpmTab,H4CpmTab,H4Tx8Tab,H4MvdTab,H4Dir8Tab,H4CbfTab:
  PEABuffer;
 H4CbpTab: PWordArr;
 H4Sp: ^TH4Sps; H4Pp: ^TH4Pps;
 H4Ls4: Array[0..5,0..5,0..15] Of LongInt; H4Ls8: Array[0..1,0..5,0..63] Of
  LongInt;
 H4LsPps: LongInt; H4LsSps: LongInt;
 H4SliceNum,H4Qp,H4SliceType,H4LastDqp,H4MbAddr,H4MbX,H4MbY,H4MbsDone: LongInt;
 H4AvA,H4AvB,H4AvC,H4AvD: Boolean;     { disponibilite des macroblocs voisins }
 H4IiA,H4IiB,H4IiC,H4IiD: Boolean;     { disponibilite pour la prediction intra
  (contrainte intra) }
 H4Pw,H4Ph: LongInt;
 H4Coef: Array[0..767] Of LongInt;       { 16 blocs luma (raster 4x4 ou 4 blocs
  8x8), Cb, Cr }
 H4LumaDc: Array[0..15] Of LongInt; H4ChromaDc: Array[0..1,0..3] Of LongInt;
 H4CurType,H4CurCbp,H4I16Mode,H4ChromaMode,H4CurTx8: LongInt;
 H4Ipm: Array[0..15] Of LongInt;
 H4Nnz: Array[0..47] Of LongInt;        { luma 0..15, Cb 16..19, Cr 20..23 :
  nombres de coefficients du macrobloc courant }
 H4QpC: Array[0..1] Of LongInt;
 H4CabacOn: Boolean;
 H4CbSt: Array[0..1023] Of Byte;          { (etat shl 1) or valMPS }
 H4CbRange,H4CbOffset: LongInt;
 H4DcBits: LongInt;                        { bits 6,7 : DC chroma Cb/Cr ; bit 8
  : DC luma (comme cbp_table de libavcodec) }
 H4CurDir8: Array[0..3] Of Byte;           { blocs 8x8 predits en mode direct
  (macrobloc courant) }

Procedure H4SetupQuant;
Const N4: Array[0..5,0..2] Of Byte=((10,16,13),(11,18,14),(13,20,16),(14,23,18),
 (16,25,20),(18,29,23));
 N8: Array[0..5,0..5] Of Byte=((20,18,32,19,25,24),(22,19,35,21,28,26),(26,23,
  42,24,33,31),(28,25,45,26,35,33),(32,28,51,30,40,38),(36,32,58,34,46,43));
Var L,M,P,I,J,C: LongInt;
Begin
 For L:=0 To 5 Do For M:=0 To 5 Do For P:=0 To 15 Do Begin
  I:=P Shr 2; J:=P And 3;
  If ((I And 1)=0) And ((J And 1)=0) Then C:=N4[M,0] Else If ((I And 1)=1) And (
   (J And 1)=1) Then C:=N4[M,1] Else C:=N4[M,2];
  H4Ls4[L,M,P]:=H4Pp^.Sl4[L,P]*C;
 End;
 For L:=0 To 1 Do For M:=0 To 5 Do For P:=0 To 63 Do Begin
  I:=P Shr 3; J:=P And 7;
  If ((I And 3)=0) And ((J And 3)=0) Then C:=N8[M,0]
  Else If ((I And 1)=1) And ((J And 1)=1) Then C:=N8[M,1]
  Else If ((I And 3)=2) And ((J And 3)=2) Then C:=N8[M,2]
  Else If (((I And 3)=0) And ((J And 1)=1)) Or (((I And 1)=1) And ((J And 3)=0))
   Then C:=N8[M,3]
  Else If (((I And 3)=0) And ((J And 3)=2)) Or (((I And 3)=2) And ((J And 3)=0))
   Then C:=N8[M,4]
  Else C:=N8[M,5];
  H4Ls8[L,M,P]:=H4Pp^.Sl8[L,P]*C;
 End;
End;

Function H4ChromaQp(Qp,Off: LongInt): LongInt;
Const Tab: Array[0..21] Of Byte=(29,30,31,32,32,33,34,34,35,35,36,36,37,37,37,
 38,38,38,39,39,39,39);
Var Q: LongInt;
Begin
 Q:=H4Clip3(0,51,Qp+Off);
 If Q<30 Then H4ChromaQp:=Q Else H4ChromaQp:=Tab[Q-30];
End;

{ ---- voisinage ---- }
Procedure H4SetupNeighbors;
Var A: LongInt;
Begin
 A:=H4MbAddr;
 FillChar(H4MvdTab^[A*64],64,0); H4DcBits:=0; FillChar(H4CurDir8,4,0);
 H4AvA:=(H4MbX>0) And (H4SliceTab^[A-1]=H4SliceNum);
 H4AvB:=(H4MbY>0) And (H4SliceTab^[A-H4MbW]=H4SliceNum);
 H4AvC:=(H4MbY>0) And (H4MbX<H4MbW-1) And (H4SliceTab^[A-H4MbW+1]=H4SliceNum);
 H4AvD:=(H4MbX>0) And (H4MbY>0) And (H4SliceTab^[A-H4MbW-1]=H4SliceNum);
 H4IiA:=H4AvA; H4IiB:=H4AvB; H4IiC:=H4AvC; H4IiD:=H4AvD;
 If H4Pp^.ConstrainedIntra<>0 Then Begin
  If H4AvA Then H4IiA:=(H4Pics[H4Cur].MbType^[A-1] And MT_INTRA)<>0;
  If H4AvB Then H4IiB:=(H4Pics[H4Cur].MbType^[A-H4MbW] And MT_INTRA)<>0;
  If H4AvC Then H4IiC:=(H4Pics[H4Cur].MbType^[A-H4MbW+1] And MT_INTRA)<>0;
  If H4AvD Then H4IiD:=(H4Pics[H4Cur].MbType^[A-H4MbW-1] And MT_INTRA)<>0;
 End;
End;

{ nombre de coefficients voisins pour nC : Plane 0 luma, 1 Cb, 2 Cr ; (Bx,By)
 coordonnees de bloc }
Function H4NcAt(Plane,Bx,By: LongInt): LongInt;
Var NA,NB,Base,Gw,Mb: LongInt; HaveA,HaveB: Boolean;
Begin
 If Plane=0 Then Begin Gw:=4; Base:=0; End Else Begin Gw:=2; Base:=16+(Plane-1)*
  4; End;
 HaveA:=True; HaveB:=True;
 If Bx>0 Then NA:=H4Nnz[Base+By*Gw+Bx-1]
 Else If H4AvA Then NA:=H4NnzTab^[(H4MbAddr-1)*48+Base+By*Gw+Gw-1]
 Else Begin HaveA:=False; NA:=0; End;
 If By>0 Then NB:=H4Nnz[Base+(By-1)*Gw+Bx]
 Else If H4AvB Then NB:=H4NnzTab^[(H4MbAddr-H4MbW)*48+Base+(Gw-1)*Gw+Bx]
 Else Begin HaveB:=False; NB:=0; End;
 If HaveA And HaveB Then H4NcAt:=(NA+NB+1) Shr 1
 Else If HaveA Then H4NcAt:=NA
 Else If HaveB Then H4NcAt:=NB
 Else H4NcAt:=0;
End;

Const H4BlkX: Array[0..15] Of Byte=(0,1,0,1,2,3,2,3,0,1,0,1,2,3,2,3);
      H4BlkY: Array[0..15] Of Byte=(0,0,1,1,0,0,1,1,2,2,3,3,2,2,3,3);

{ quantification inverse d'un bloc 4x4 raster : C -> D ; Dc0 : valeur DC deja
 calculee (si Sep) }
Procedure H4Dequant4(Var C: Array Of LongInt; Off: LongInt; Var D: Array Of
 LongInt; List,Qp: LongInt; Sep: Boolean; Dc0: LongInt);
Var I,Qd,Qm,V: LongInt;
Begin
 Qd:=Qp Div 6; Qm:=Qp Mod 6;
 For I:=0 To 15 Do Begin
  V:=C[Off+I];
  If V=0 Then D[I]:=0
  Else If Qd>=4 Then D[I]:=(V*H4Ls4[List,Qm,I]) Shl (Qd-4)
  Else D[I]:=H4Sar(V*H4Ls4[List,Qm,I]+(1 Shl (3-Qd)),4-Qd);
 End;
 If Sep Then D[0]:=Dc0;
End;
Procedure H4Dequant8(Var C: Array Of LongInt; Off: LongInt; Var D: Array Of
 LongInt; List,Qp: LongInt);
Var I,Qd,Qm,V: LongInt;
Begin
 Qd:=Qp Div 6; Qm:=Qp Mod 6;
 For I:=0 To 63 Do Begin
  V:=C[Off+I];
  If V=0 Then D[I]:=0
  Else If Qd>=6 Then D[I]:=(V*H4Ls8[List,Qm,I]) Shl (Qd-6)
  Else D[I]:=H4Sar(V*H4Ls8[List,Qm,I]+(1 Shl (5-Qd)),6-Qd);
 End;
End;
{ DC luma Intra16x16 : Hadamard + mise a l'echelle ; Lv : 16 niveaux en raster
 4x4 ; Out en raster }
Procedure H4LumaDcTransform(Var Lv: Array Of LongInt; Var Out: Array Of LongInt;
 Qp: LongInt);
Var T,F: Array[0..15] Of LongInt; I,J,A,B,C,D,Qd,Qm,Ls: LongInt;
Begin
 For I:=0 To 3 Do Begin
  A:=Lv[I*4]; B:=Lv[I*4+1]; C:=Lv[I*4+2]; D:=Lv[I*4+3];
  T[I*4]:=A+B+C+D; T[I*4+1]:=A+B-C-D; T[I*4+2]:=A-B-C+D; T[I*4+3]:=A-B+C-D;
 End;
 For J:=0 To 3 Do Begin
  A:=T[J]; B:=T[4+J]; C:=T[8+J]; D:=T[12+J];
  F[J]:=A+B+C+D; F[4+J]:=A+B-C-D; F[8+J]:=A-B-C+D; F[12+J]:=A-B+C-D;
 End;
 Qd:=Qp Div 6; Qm:=Qp Mod 6; Ls:=H4Ls4[0,Qm,0];
 For I:=0 To 15 Do
  If Qd>=6 Then Out[I]:=(F[I]*Ls) Shl (Qd-6) Else Out[I]:=H4Sar(F[I]*Ls+(1 Shl (
   5-Qd)),6-Qd);
End;

Const
 H4CabacLps: Array[0..255] Of Byte=(
  128,176,208,240,128,167,197,227,128,158,187,216,123,150,178,205,
  116,142,169,195,111,135,160,185,105,128,152,175,100,122,144,166,
  95,116,137,158,90,110,130,150,85,104,123,142,81,99,117,135,
  77,94,111,128,73,89,105,122,69,85,100,116,66,80,95,110,
  62,76,90,104,59,72,86,99,56,69,81,94,53,65,77,89,
  51,62,73,85,48,59,69,80,46,56,66,76,43,53,63,72,
  41,50,59,69,39,48,56,65,37,45,54,62,35,43,51,59,
  33,41,48,56,32,39,46,53,30,37,43,50,29,35,41,48,
  27,33,39,45,26,31,37,43,24,30,35,41,23,28,33,39,
  22,27,32,37,21,26,30,35,20,24,29,33,19,23,27,31,
  18,22,26,30,17,21,25,28,16,20,23,27,15,19,22,25,
  14,18,21,24,14,17,20,23,13,16,19,22,12,15,18,21,
  12,14,17,20,11,14,16,19,11,13,15,18,10,12,15,17,
  10,12,14,16,9,11,13,15,9,11,12,14,8,10,12,14,
  8,9,11,13,7,9,11,12,7,9,10,12,7,8,10,11,
  6,8,9,11,6,7,9,10,6,7,8,9,2,2,2,2
 );
 H4CabacTransLps: Array[0..63] Of Byte=(
  0,0,1,2,2,4,4,5,6,7,8,9,9,11,11,12,
  13,13,15,15,16,16,18,18,19,19,21,21,22,22,23,24,
  24,25,26,26,27,27,28,29,29,30,30,30,31,32,32,33,
  33,33,34,34,35,35,35,36,36,36,37,37,37,38,38,63
 );
 H4CabacLast8: Array[0..62] Of Byte=(
  0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,
  5,5,5,5,6,6,6,6,7,7,7,7,8,8,8
 );
 H4CabacSig8: Array[0..62] Of Byte=(
  0,1,2,3,4,5,5,4,4,3,3,4,4,4,5,5,
  4,4,4,4,3,3,6,7,7,7,8,9,10,9,8,7,
  7,6,11,12,13,11,6,7,8,9,14,10,9,8,6,11,
  12,13,11,6,9,14,10,9,11,12,13,11,14,10,12
 );

{ ---- CABAC (9.3) : moteur arithmetique, elements de syntaxe et residu ---- }

Procedure H4CabacInit(SliceQp,InitIdc: LongInt; IsI: Boolean);
Var I,M,N,Pre: LongInt;
Begin
 For I:=0 To 1023 Do Begin
  If IsI Then Begin M:=H4CabacInitI[2*I]; N:=H4CabacInitI[2*I+1]; End
  Else Begin M:=H4CabacInitPB[InitIdc*2048+2*I]; N:=H4CabacInitPB[InitIdc*2048+
   2*I+1]; End;
  Pre:=H4Clip3(1,126,H4Sar(M*H4Clip3(0,51,SliceQp),4)+N);
  If Pre<=63 Then H4CbSt[I]:=(63-Pre)*2 Else H4CbSt[I]:=(Pre-64)*2+1;
 End;
 H4Pos:=(H4Pos+7) And -8;
 H4CbRange:=510; H4CbOffset:=H4Bits(9);
End;

Function H4CbDec(Ctx: LongInt): LongInt;
Var S,St,Mps,RLps,N: LongInt;
Begin
 S:=H4CbSt[Ctx]; St:=S Shr 1; Mps:=S And 1;
 RLps:=H4CabacLps[St*4+((H4CbRange Shr 6) And 3)];
 Dec(H4CbRange,RLps);
 If H4CbOffset>=H4CbRange Then Begin
  Dec(H4CbOffset,H4CbRange); H4CbRange:=RLps; H4CbDec:=1-Mps;
  If St=0 Then Mps:=1-Mps;
  St:=H4CabacTransLps[St];
 End Else Begin
  H4CbDec:=Mps;
  If St<62 Then Inc(St);
 End;
 H4CbSt[Ctx]:=St*2+Mps;
 If H4CbRange<256 Then Begin
  N:=0; While (H4CbRange Shl N)<256 Do Inc(N);
  H4CbRange:=H4CbRange Shl N; H4CbOffset:=(H4CbOffset Shl N) Or H4Bits(N);
 End;
End;
Function H4CbByp: LongInt;
Begin
 H4CbOffset:=(H4CbOffset Shl 1) Or H4Bit;
 If H4CbOffset>=H4CbRange Then Begin Dec(H4CbOffset,H4CbRange); H4CbByp:=1; End
  Else H4CbByp:=0;
End;
Function H4CbTerm: LongInt;
Begin
 Dec(H4CbRange,2);
 If H4CbOffset>=H4CbRange Then H4CbTerm:=1
 Else Begin
  H4CbTerm:=0;
  If H4CbRange<256 Then Begin H4CbRange:=H4CbRange Shl 1; H4CbOffset:=(
   H4CbOffset Shl 1) Or H4Bit; End;
 End;
End;

{ ---- elements de syntaxe ---- }
Function H4CbSkip: Boolean;
Var Ctx: LongInt;
Begin
 Ctx:=0;
 If H4AvA Then If (H4Pics[H4Cur].MbType^[H4MbAddr-1] And MT_SKIP)=0 Then Inc(
  Ctx);
 If H4AvB Then If (H4Pics[H4Cur].MbType^[H4MbAddr-H4MbW] And MT_SKIP)=0 Then
  Inc(Ctx);
 If H4SliceType=1 Then Inc(Ctx,13);
 H4CbSkip:=H4CbDec(11+Ctx)<>0;
End;

{ type de macrobloc intra : 0 I_NxN, 1..24 I16x16, 25 PCM ; Base 3 (tranche I) /
 17 (P) / 32 (B) }
Function H4CbIntraType(Base: LongInt; IntraSlice: Boolean): LongInt;
Var Ctx,S,T: LongInt;
Begin
 S:=Base;
 If IntraSlice Then Begin
  Ctx:=0;
  If H4AvA Then If (H4Pics[H4Cur].MbType^[H4MbAddr-1] And (MT_I16 Or MT_PCM))<>0
   Then Inc(Ctx);
  If H4AvB Then If (H4Pics[H4Cur].MbType^[H4MbAddr-H4MbW] And (MT_I16 Or
   MT_PCM))<>0 Then Inc(Ctx);
  If H4CbDec(S+Ctx)=0 Then Begin H4CbIntraType:=0; Exit; End;
  Inc(S,2);
 End Else Begin
  If H4CbDec(S)=0 Then Begin H4CbIntraType:=0; Exit; End;
 End;
 If H4CbTerm<>0 Then Begin H4CbIntraType:=25; Exit; End;
 T:=1;
 Inc(T,12*H4CbDec(S+1));
 If H4CbDec(S+2)<>0 Then Begin
  If IntraSlice Then Inc(T,4+4*H4CbDec(S+3)) Else Inc(T,4+4*H4CbDec(S+2));
 End;
 If IntraSlice Then Begin Inc(T,2*H4CbDec(S+4)); Inc(T,H4CbDec(S+5)); End
 Else Begin Inc(T,2*H4CbDec(S+3)); Inc(T,H4CbDec(S+3)); End;
 H4CbIntraType:=T;
End;

{ type de macrobloc d'une tranche P : 0..3 inter, 5+x intra }
Function H4CbMbTypeP: LongInt;
Begin
 If H4CbDec(14)=0 Then Begin
  If H4CbDec(15)=0 Then H4CbMbTypeP:=3*H4CbDec(16) Else H4CbMbTypeP:=2-H4CbDec(
   17);
 End Else H4CbMbTypeP:=5+H4CbIntraType(17,False);
End;

{ type de macrobloc d'une tranche B : 0..22 inter, 23+x intra }
Function H4CbMbTypeB: LongInt;
Var Ctx,Bits: LongInt;
Begin
 Ctx:=0;
 If H4AvA Then If (H4Pics[H4Cur].MbType^[H4MbAddr-1] And MT_DIRECT)=0 Then Inc(
  Ctx);
 If H4AvB Then If (H4Pics[H4Cur].MbType^[H4MbAddr-H4MbW] And MT_DIRECT)=0 Then
  Inc(Ctx);
 If H4CbDec(27+Ctx)=0 Then Begin H4CbMbTypeB:=0; Exit; End;
 If H4CbDec(27+3)=0 Then Begin H4CbMbTypeB:=1+H4CbDec(27+5); Exit; End;
 Bits:=H4CbDec(27+4) Shl 3;
 Bits:=Bits+(H4CbDec(27+5) Shl 2);
 Bits:=Bits+(H4CbDec(27+5) Shl 1);
 Bits:=Bits+H4CbDec(27+5);
 If Bits<8 Then H4CbMbTypeB:=Bits+3
 Else If Bits=13 Then H4CbMbTypeB:=23+H4CbIntraType(32,False)
 Else If Bits=14 Then H4CbMbTypeB:=11
 Else If Bits=15 Then H4CbMbTypeB:=22
 Else Begin
  Bits:=(Bits Shl 1)+H4CbDec(27+5);
  H4CbMbTypeB:=Bits-4;
 End;
End;

Function H4CbSubP: LongInt;
Begin
 If H4CbDec(21)<>0 Then Begin H4CbSubP:=0; Exit; End;
 If H4CbDec(22)=0 Then Begin H4CbSubP:=1; Exit; End;
 If H4CbDec(23)<>0 Then H4CbSubP:=2 Else H4CbSubP:=3;
End;
Function H4CbSubB: LongInt;
Var T: LongInt;
Begin
 If H4CbDec(36)=0 Then Begin H4CbSubB:=0; Exit; End;
 If H4CbDec(37)=0 Then Begin H4CbSubB:=1+H4CbDec(39); Exit; End;
 T:=3;
 If H4CbDec(38)<>0 Then Begin
  If H4CbDec(39)<>0 Then Begin H4CbSubB:=11+H4CbDec(39); Exit; End;
  Inc(T,4);
 End;
 Inc(T,2*H4CbDec(39));
 Inc(T,H4CbDec(39));
 H4CbSubB:=T;
End;

Function H4CbIpm(Pm: LongInt): LongInt;
Var M: LongInt;
Begin
 If H4CbDec(68)<>0 Then Begin H4CbIpm:=Pm; Exit; End;
 M:=H4CbDec(69);
 Inc(M,2*H4CbDec(69));
 Inc(M,4*H4CbDec(69));
 If M>=Pm Then Inc(M);
 H4CbIpm:=M;
End;

Function H4CbChromaMode: LongInt;
Var Ctx: LongInt;
Begin
 Ctx:=0;
 If H4AvA Then If H4CpmTab^[H4MbAddr-1]<>0 Then Inc(Ctx);
 If H4AvB Then If H4CpmTab^[H4MbAddr-H4MbW]<>0 Then Inc(Ctx);
 If H4CbDec(64+Ctx)=0 Then Begin H4CbChromaMode:=0; Exit; End;
 If H4CbDec(67)=0 Then Begin H4CbChromaMode:=1; Exit; End;
 If H4CbDec(67)=0 Then H4CbChromaMode:=2 Else H4CbChromaMode:=3;
End;

Function H4CbTx8: Boolean;
Var Ctx: LongInt;
Begin
 Ctx:=0;
 If H4AvA Then If H4Tx8Tab^[H4MbAddr-1]<>0 Then Inc(Ctx);
 If H4AvB Then If H4Tx8Tab^[H4MbAddr-H4MbW]<>0 Then Inc(Ctx);
 H4CbTx8:=H4CbDec(399+Ctx)<>0;
End;

Function H4CbCbp(Intra: Boolean): LongInt;
Var Lw,Tw,Cbp,Ctx,Ca,Cb: LongInt;
Begin
 If Intra Then Begin Lw:=$7CF; Tw:=$7CF; End Else Begin Lw:=$00F; Tw:=$00F; End;
 If H4AvA Then Lw:=H4CbpTab^[H4MbAddr-1];
 If H4AvB Then Tw:=H4CbpTab^[H4MbAddr-H4MbW];
 Ctx:=Ord((Lw And 2)=0)+2*Ord((Tw And 4)=0);
 Cbp:=H4CbDec(73+Ctx);
 Ctx:=Ord((Cbp And 1)=0)+2*Ord((Tw And 8)=0);
 Cbp:=Cbp+(H4CbDec(73+Ctx) Shl 1);
 Ctx:=Ord((Lw And 8)=0)+2*Ord((Cbp And 1)=0);
 Cbp:=Cbp+(H4CbDec(73+Ctx) Shl 2);
 Ctx:=Ord((Cbp And 4)=0)+2*Ord((Cbp And 2)=0);
 Cbp:=Cbp+(H4CbDec(73+Ctx) Shl 3);
 Ca:=(Lw Shr 4) And 3; Cb:=(Tw Shr 4) And 3;
 Ctx:=Ord(Ca>0)+2*Ord(Cb>0);
 If H4CbDec(77+Ctx)<>0 Then Begin
  Ctx:=4+Ord(Ca=2)+2*Ord(Cb=2);
  Cbp:=Cbp+((1+H4CbDec(77+Ctx)) Shl 4);
 End;
 H4CbCbp:=Cbp;
End;

Function H4CbDqp: LongInt;
Var Val,Ctx: LongInt;
Begin
 If H4CbDec(60+Ord(H4LastDqp<>0))=0 Then Begin H4CbDqp:=0; Exit; End;
 Val:=1; Ctx:=2;
 While H4CbDec(60+Ctx)<>0 Do Begin
  Ctx:=3; Inc(Val);
  If Val>104 Then Begin H4Err:=True; H4CbDqp:=0; Exit; End;
 End;
 If Odd(Val) Then H4CbDqp:=(Val+1) Div 2 Else H4CbDqp:=-((Val+1) Div 2);
End;

{ voisin pour l'indice de reference : R=-2 indisponible, -1 intra/liste
 inutilisee ; Dir : predit en mode direct }
Procedure H4NbRef(L,Bx,By: LongInt; Var R: LongInt; Var Dir: Boolean);
Var Addr,Blk,B8: LongInt; Ok: Boolean;
Begin
 R:=-2; Dir:=False; Addr:=H4MbAddr; Ok:=False; Blk:=0;
 If By<0 Then Begin Ok:=H4AvB; Addr:=H4MbAddr-H4MbW; Blk:=12+Bx; End
 Else If Bx<0 Then Begin Ok:=H4AvA; Addr:=H4MbAddr-1; Blk:=By*4+3; End
 Else Begin Ok:=True; Blk:=By*4+Bx; End;
 If Not Ok Then Exit;
 B8:=(Blk Shr 3)*2+((Blk And 3) Shr 1);
 R:=-1;
 If Addr<>H4MbAddr Then Begin
  If (H4Pics[H4Cur].MbType^[Addr] And MT_INTRA)<>0 Then Exit;
  Dir:=H4Dir8Tab^[Addr*4+B8]<>0;
 End Else Dir:=H4CurDir8[B8]<>0;
 R:=ShortInt(PEABuffer(H4Pics[H4Cur].Ref[L])^[Addr*4+B8]);
End;

Function H4CbRef(L,Bx,By: LongInt): LongInt;
Var Ra,Rb,Ctx,Ref: LongInt; Da,Db: Boolean;
Begin
 H4NbRef(L,Bx-1,By,Ra,Da); H4NbRef(L,Bx,By-1,Rb,Db);
 Ctx:=0;
 If (Ra>0) And Not Da Then Inc(Ctx);
 If (Rb>0) And Not Db Then Inc(Ctx,2);
 Ref:=0;
 While H4CbDec(54+Ctx)<>0 Do Begin
  Inc(Ref); Ctx:=(Ctx Shr 2)+4;
  If Ref>=32 Then Begin H4Err:=True; H4CbRef:=0; Exit; End;
 End;
 H4CbRef:=Ref;
End;

{ valeur absolue de mvd du voisin }
Function H4NbMvd(L,Bx,By,Comp: LongInt): LongInt;
Var Addr,Blk: LongInt;
Begin
 H4NbMvd:=0; Addr:=H4MbAddr;
 If By<0 Then Begin If Not H4AvB Then Exit; Addr:=H4MbAddr-H4MbW; Blk:=12+Bx;
  End
 Else If Bx<0 Then Begin If Not H4AvA Then Exit; Addr:=H4MbAddr-1; Blk:=By*4+3;
  End
 Else Blk:=By*4+Bx;
 H4NbMvd:=H4MvdTab^[(((Addr*2+L)*16+Blk) Shl 1)+Comp];
End;

Function H4CbMvd(CtxBase,Amvd: LongInt; Var Mva: LongInt): LongInt;
Var Mvd,K: LongInt;
Begin
 If Amvd<3 Then K:=0 Else If Amvd>32 Then K:=2 Else K:=1;
 If H4CbDec(CtxBase+K)=0 Then Begin Mva:=0; H4CbMvd:=0; Exit; End;
 Mvd:=1; K:=CtxBase+3;
 While (Mvd<9) And (H4CbDec(K)<>0) Do Begin
  If Mvd<4 Then Inc(K);
  Inc(Mvd);
 End;
 If Mvd>=9 Then Begin
  K:=3;
  While H4CbByp<>0 Do Begin
   Inc(Mvd,1 Shl K); Inc(K);
   If K>24 Then Begin H4Err:=True; Mva:=0; H4CbMvd:=0; Exit; End;
  End;
  While K>0 Do Begin Dec(K); Inc(Mvd,H4CbByp Shl K); End;
  If Mvd<70 Then Mva:=Mvd Else Mva:=70;
 End Else Mva:=Mvd;
 If H4CbByp<>0 Then H4CbMvd:=-Mvd Else H4CbMvd:=Mvd;
End;

{ ---- residu ---- }
Function H4CbResidual(Cat,MaxCoeff,CbfCtx: LongInt; Var Lev: Array Of LongInt):
 LongInt;
Const SigOff: Array[0..5] Of Word=(105,120,134,149,152,402);
 LastOff: Array[0..5] Of Word=(166,181,195,210,213,417);
 AbsOff: Array[0..5] Of Word=(227,237,247,257,266,426);
Var I,Count,SigI,LastI,K,Eq1,Gt1,Abs_,Ab,Cx,Mx: LongInt; Idx: Array[0..63] Of
 LongInt; Last: Boolean;
Begin
 For I:=0 To MaxCoeff-1 Do Lev[I]:=0;
 H4CbResidual:=0;
 If CbfCtx>=0 Then If H4CbDec(CbfCtx)=0 Then Exit;
 Count:=0; Last:=False;
 For I:=0 To MaxCoeff-2 Do Begin
  If Cat=5 Then Begin SigI:=H4CabacSig8[I]; LastI:=H4CabacLast8[I]; End
  Else If Cat=3 Then Begin If I<2 Then SigI:=I Else SigI:=2; LastI:=SigI; End
  Else Begin SigI:=I; LastI:=I; End;
  If H4CbDec(SigOff[Cat]+SigI)<>0 Then Begin
   Idx[Count]:=I; Inc(Count);
   If H4CbDec(LastOff[Cat]+LastI)<>0 Then Begin Last:=True; Break; End;
  End;
 End;
 If Not Last Then Begin Idx[Count]:=MaxCoeff-1; Inc(Count); End;
 H4CbResidual:=Count;
 Eq1:=0; Gt1:=0;
 If Cat=3 Then Mx:=3 Else Mx:=4;
 For K:=Count-1 DownTo 0 Do Begin
  If Gt1<>0 Then Cx:=0 Else Begin Cx:=1+Eq1; If Cx>4 Then Cx:=4; End;
  If H4CbDec(AbsOff[Cat]+Cx)=0 Then Begin
   Abs_:=1; Inc(Eq1);
  End Else Begin
   Cx:=Gt1; If Cx>Mx Then Cx:=Mx;
   Cx:=AbsOff[Cat]+5+Cx;
   Abs_:=2;
   While (Abs_<15) And (H4CbDec(Cx)<>0) Do Inc(Abs_);
   If Abs_>=15 Then Begin
    Ab:=0;
    While (H4CbByp<>0) And (Ab<23) Do Inc(Ab);
    Abs_:=1;
    While Ab>0 Do Begin Dec(Ab); Abs_:=Abs_+Abs_+H4CbByp; End;
    Inc(Abs_,14);
   End;
   Inc(Gt1);
  End;
  If H4CbByp<>0 Then Lev[Idx[K]]:=-Abs_ Else Lev[Idx[K]]:=Abs_;
 End;
End;

{ condition de voisinage pour le drapeau de bloc code d'un bloc 4x4 : Plane 0
 luma, 1/2 chroma }
Function H4CbfInc(Plane,Bx,By: LongInt): LongInt;
Var Base,Gw,Na,Nb: LongInt; Intra: Boolean;
Begin
 If Plane=0 Then Begin Gw:=4; Base:=0; End Else Begin Gw:=2; Base:=16+(Plane-1)*
  4; End;
 Intra:=(H4CurType And MT_INTRA)<>0;
 If Bx>0 Then Na:=H4Nnz[Base+By*Gw+Bx-1]
 Else If H4AvA Then Na:=H4NnzTab^[(H4MbAddr-1)*48+Base+By*Gw+Gw-1]
 Else Na:=Ord(Intra);
 If By>0 Then Nb:=H4Nnz[Base+(By-1)*Gw+Bx]
 Else If H4AvB Then Nb:=H4NnzTab^[(H4MbAddr-H4MbW)*48+Base+(Gw-1)*Gw+Bx]
 Else Nb:=Ord(Intra);
 H4CbfInc:=Ord(Na>0)+2*Ord(Nb>0);
End;
Function H4CbfDcInc(Bit: LongInt): LongInt;
Var Na,Nb,Def: LongInt;
Begin
 If (H4CurType And MT_INTRA)<>0 Then Def:=1 Else Def:=0;
 If H4AvA Then Na:=(H4CbpTab^[H4MbAddr-1] Shr Bit) And 1 Else Na:=Def;
 If H4AvB Then Nb:=(H4CbpTab^[H4MbAddr-H4MbW] Shr Bit) And 1 Else Nb:=Def;
 H4CbfDcInc:=Na+2*Nb;
End;

Function H4LumaCabac(Tx8,I16: Boolean; CbpL: LongInt): Boolean;
Var B8,I4,Blk,Bx,By,N,K,Mx,Cat: LongInt; Lev: Array[0..63] Of LongInt;
Begin
 H4LumaCabac:=False;
 FillChar(H4Coef,SizeOf(H4Coef),0);
 FillChar(H4LumaDc,SizeOf(H4LumaDc),0);
 If I16 Then Begin
  N:=H4CbResidual(0,16,85+H4CbfDcInc(8),Lev);
  If H4Err Then Exit;
  If N>0 Then H4DcBits:=H4DcBits Or $100;
  For K:=0 To 15 Do H4LumaDc[H4Zigzag4[K]]:=Lev[K];
 End;
 For B8:=0 To 3 Do Begin
  If ((CbpL Shr B8) And 1)<>0 Then Begin
   If Tx8 Then Begin
    N:=H4CbResidual(5,64,-1,Lev);
    If H4Err Then Exit;
    For K:=0 To 63 Do If Lev[K]<>0 Then H4Coef[B8*64+H4Zigzag8[K]]:=Lev[K];
    For I4:=0 To 3 Do Begin Blk:=B8*4+I4; H4Nnz[H4BlkY[Blk]*4+H4BlkX[Blk]]:=N;
     End;
   End Else Begin
    For I4:=0 To 3 Do Begin
     Blk:=B8*4+I4; Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
     If I16 Then Begin Cat:=1; Mx:=15; End Else Begin Cat:=2; Mx:=16; End;
     N:=H4CbResidual(Cat,Mx,85+4*Cat+H4CbfInc(0,Bx,By),Lev);
     If H4Err Then Exit;
     H4Nnz[By*4+Bx]:=N;
     If I16 Then Begin For K:=0 To 14 Do If Lev[K]<>0 Then H4Coef[Blk*16+
      H4Zigzag4[K+1]]:=Lev[K]; End
     Else For K:=0 To 15 Do If Lev[K]<>0 Then H4Coef[Blk*16+H4Zigzag4[K]]:=Lev[
      K];
    End;
   End;
  End Else Begin
   For I4:=0 To 3 Do Begin Blk:=B8*4+I4; H4Nnz[H4BlkY[Blk]*4+H4BlkX[Blk]]:=0;
    End;
  End;
 End;
 H4LumaCabac:=True;
End;

Function H4ChromaCabac(CbpC: LongInt): Boolean;
Var C,Blk,N,K: LongInt; Lev: Array[0..15] Of LongInt;
Begin
 H4ChromaCabac:=False;
 FillChar(H4ChromaDc,SizeOf(H4ChromaDc),0);
 If CbpC<>0 Then Begin
  For C:=0 To 1 Do Begin
   N:=H4CbResidual(3,4,97+H4CbfDcInc(6+C),Lev);
   If H4Err Then Exit;
   If N>0 Then H4DcBits:=H4DcBits Or ($40 Shl C);
   For K:=0 To 3 Do H4ChromaDc[C,K]:=Lev[K];
  End;
 End;
 For C:=0 To 1 Do For Blk:=0 To 3 Do H4Nnz[16+C*4+Blk]:=0;
 If CbpC=2 Then Begin
  For C:=0 To 1 Do For Blk:=0 To 3 Do Begin
   N:=H4CbResidual(4,15,101+H4CbfInc(1+C,Blk And 1,Blk Shr 1),Lev);
   If H4Err Then Exit;
   H4Nnz[16+C*4+Blk]:=N;
   For K:=0 To 14 Do If Lev[K]<>0 Then H4Coef[256+C*64+Blk*16+H4Zigzag4[K+1]]:=
    Lev[K];
  End;
 End;
 H4ChromaCabac:=True;
End;


{ ---- couche macrobloc : intra / residu CAVLC ---- }
Const H4BlkOrder: Array[0..15] Of Byte=(0,1,4,5,2,3,6,7,8,9,12,13,10,11,14,15);

Function H4NbIpm(Avail: Boolean; Addr,Idx: LongInt): LongInt;  { -1 : mode DC
 force }
Begin
 If Not Avail Then Begin H4NbIpm:=-1; Exit; End;
 If (H4Pics[H4Cur].MbType^[Addr] And MT_INTRA)=0 Then Begin
  If H4Pp^.ConstrainedIntra<>0 Then H4NbIpm:=-1 Else H4NbIpm:=2;
  Exit;
 End;
 If (H4Pics[H4Cur].MbType^[Addr] And (MT_I4 Or MT_I8))=0 Then H4NbIpm:=2 Else
  H4NbIpm:=ShortInt(H4IpmTab^[Addr*16+Idx]);
End;
Function H4PredIpm(Bx,By: LongInt): LongInt;
Var A,B: LongInt;
Begin
 If Bx>0 Then A:=H4Ipm[By*4+Bx-1] Else A:=H4NbIpm(H4AvA,H4MbAddr-1,By*4+3);
 If By>0 Then B:=H4Ipm[(By-1)*4+Bx] Else B:=H4NbIpm(H4AvB,H4MbAddr-H4MbW,12+Bx);
 If (A<0) Or (B<0) Then H4PredIpm:=2 Else If A<B Then H4PredIpm:=A Else
  H4PredIpm:=B;
End;

{ lecture du residu luma CAVLC ; Cbp : bits 0..3 ; I16 : DC + AC a 15
 coefficients }
Function H4LumaCavlc(Tx8,I16: Boolean; CbpL: LongInt): Boolean;
Var B8,I4,Blk,Bx,By,N,K,Nc,Mx: LongInt; Lev: Array[0..15] Of LongInt;
Begin
 H4LumaCavlc:=False;
 FillChar(H4Coef,SizeOf(H4Coef),0);
 FillChar(H4LumaDc,SizeOf(H4LumaDc),0);
 If I16 Then Begin
  Nc:=H4NcAt(0,0,0);
  N:=H4CavlcBlock(Lev,16,Nc);
  If N<0 Then Exit;
  For K:=0 To 15 Do H4LumaDc[H4Zigzag4[K]]:=Lev[K];
 End;
 For B8:=0 To 3 Do Begin
  If ((CbpL Shr B8) And 1)<>0 Then Begin
   For I4:=0 To 3 Do Begin
    Blk:=B8*4+I4; Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
    Nc:=H4NcAt(0,Bx,By);
    If I16 Then Mx:=15 Else Mx:=16;
    N:=H4CavlcBlock(Lev,Mx,Nc);
    If N<0 Then Exit;
    H4Nnz[By*4+Bx]:=N;
    If Tx8 Then Begin
     For K:=0 To 15 Do If Lev[K]<>0 Then H4Coef[B8*64+H4Zigzag8[4*K+I4]]:=Lev[
      K];
    End Else If I16 Then Begin
     For K:=0 To 14 Do If Lev[K]<>0 Then H4Coef[Blk*16+H4Zigzag4[K+1]]:=Lev[K];
    End Else Begin
     For K:=0 To 15 Do If Lev[K]<>0 Then H4Coef[Blk*16+H4Zigzag4[K]]:=Lev[K];
    End;
   End;
  End Else Begin
   For I4:=0 To 3 Do Begin Blk:=B8*4+I4; H4Nnz[H4BlkY[Blk]*4+H4BlkX[Blk]]:=0;
    End;
  End;
 End;
 H4LumaCavlc:=True;
End;
Function H4ChromaCavlc(CbpC: LongInt): Boolean;
Var C,Blk,N,K,Nc: LongInt; Lev: Array[0..15] Of LongInt;
Begin
 H4ChromaCavlc:=False;
 FillChar(H4ChromaDc,SizeOf(H4ChromaDc),0);
 If CbpC<>0 Then Begin
  For C:=0 To 1 Do Begin
   N:=H4CavlcBlock(Lev,4,-1);
   If N<0 Then Exit;
   For K:=0 To 3 Do H4ChromaDc[C,K]:=Lev[K];
  End;
 End;
 For C:=0 To 1 Do For Blk:=0 To 3 Do H4Nnz[16+C*4+Blk]:=0;
 If CbpC=2 Then Begin
  For C:=0 To 1 Do For Blk:=0 To 3 Do Begin
   Nc:=H4NcAt(1+C,Blk And 1,Blk Shr 1);
   N:=H4CavlcBlock(Lev,15,Nc);
   If N<0 Then Exit;
   H4Nnz[16+C*4+Blk]:=N;
   For K:=0 To 14 Do If Lev[K]<>0 Then H4Coef[256+C*64+Blk*16+H4Zigzag4[K+1]]:=
    Lev[K];
  End;
 End;
 H4ChromaCavlc:=True;
End;

{ ajoute le residu luma d'un bloc 4x4 (ou 8x8) deja decode }
Procedure H4AddLuma4(Blk,Qp,List: LongInt; Sep: Boolean; Dc0: LongInt);
Var D: Array[0..15] Of LongInt; Pl: PEABuffer; X,Y: LongInt;
Begin
 H4Dequant4(H4Coef,Blk*16,D,List,Qp,Sep,Dc0);
 X:=H4MbX*16+H4BlkX[Blk]*4; Y:=H4MbY*16+H4BlkY[Blk]*4;
 H4Idct4(D,H4Pics[H4Cur].Y,H4StrideY,X,Y);
End;
Procedure H4AddLuma8(B8,Qp,List: LongInt);
Var D: Array[0..63] Of LongInt; X,Y: LongInt;
Begin
 H4Dequant8(H4Coef,B8*64,D,List,Qp);
 X:=H4MbX*16+(B8 And 1)*8; Y:=H4MbY*16+(B8 Shr 1)*8;
 H4Idct8(D,H4Pics[H4Cur].Y,H4StrideY,X,Y);
End;
{ residu chroma (DC + AC) apres prediction }
Procedure H4AddChroma(Intra: Boolean);
Var C,Blk,Qp,List,Qd,Qm,A,B,Cc,Dd: LongInt; Dc: Array[0..3] Of LongInt; D:
 Array[0..15] Of LongInt; Pl: PEABuffer; HasAc: Boolean; F: Array[0..3] Of
 LongInt;
Begin
 For C:=0 To 1 Do Begin
  If (H4CurCbp Shr 4)=0 Then Break;
  Qp:=H4QpC[C];
  If Intra Then List:=1+C Else List:=4+C;
  Qd:=Qp Div 6; Qm:=Qp Mod 6;
  A:=H4ChromaDc[C,0]; B:=H4ChromaDc[C,1]; Cc:=H4ChromaDc[C,2]; Dd:=H4ChromaDc[C,
   3];
  F[0]:=A+B+Cc+Dd; F[1]:=A-B+Cc-Dd; F[2]:=A+B-Cc-Dd; F[3]:=A-B-Cc+Dd;
  For Blk:=0 To 3 Do Dc[Blk]:=H4Sar((F[Blk]*H4Ls4[List,Qm,0]) Shl Qd,5);
  If C=0 Then Pl:=H4Pics[H4Cur].U Else Pl:=H4Pics[H4Cur].V;
  For Blk:=0 To 3 Do Begin
   H4Dequant4(H4Coef,256+C*64+Blk*16,D,List,Qp,True,Dc[Blk]);
   H4Idct4(D,Pl,H4StrideC,H4MbX*8+(Blk And 1)*4,H4MbY*8+(Blk Shr 1)*4);
  End;
 End;
End;


{ ---- macrobloc intra (CAVLC) ---- }
Procedure H4StoreMb(Skip: Boolean);
Var A,I: LongInt;
Begin
 A:=H4MbAddr;
 H4SliceTab^[A]:=H4SliceNum;
 H4Pics[H4Cur].MbType^[A]:=H4CurType;
 If (H4CurType And MT_PCM)<>0 Then H4QpTab^[A]:=0 Else H4QpTab^[A]:=H4Qp;
 For I:=0 To 23 Do H4NnzTab^[A*48+I]:=H4Nnz[I];
 H4CbpTab^[A]:=(H4CurCbp And $3F) Or H4DcBits;
 For I:=0 To 3 Do H4Dir8Tab^[A*4+I]:=H4CurDir8[I];
 H4Tx8Tab^[A]:=H4CurTx8;
 H4CpmTab^[A]:=H4ChromaMode;
 If (H4CurType And (MT_I4 Or MT_I8))<>0 Then For I:=0 To 15 Do H4IpmTab^[A*16+
  I]:=H4Ipm[I]
 Else For I:=0 To 15 Do H4IpmTab^[A*16+I]:=2;
End;

Procedure H4DecodeIntraMb(T: LongInt);
Var I,J,Blk,Bx,By,B8,Prev,Rem,Pm,CbpL,CbpC,Dq,X0,Y0,Mode,Cm: LongInt; AvL,AvT,
 AvTR,AvTL: Boolean;
 Dc: Array[0..15] Of LongInt; Tx8: Boolean; Ok: Boolean; Pl: PEABuffer;
Begin
 X0:=H4MbX*16; Y0:=H4MbY*16;
 FillChar(H4Nnz,SizeOf(H4Nnz),0);
 H4CurTx8:=0; H4ChromaMode:=0; H4CurCbp:=0;
 If T=25 Then Begin
  { I_PCM }
  H4CurType:=MT_PCM;
  H4Pos:=(H4Pos+7) And -8;
  H4DcBits:=$1C0;
  Pl:=H4Pics[H4Cur].Y;
  For J:=0 To 15 Do For I:=0 To 15 Do Pl^[(Y0+J)*H4StrideY+X0+I]:=H4Bits(8);
  Pl:=H4Pics[H4Cur].U;
  For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(H4MbY*8+J)*H4StrideC+H4MbX*8+I]:=
   H4Bits(8);
  Pl:=H4Pics[H4Cur].V;
  For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(H4MbY*8+J)*H4StrideC+H4MbX*8+I]:=
   H4Bits(8);
  For I:=0 To 23 Do H4Nnz[I]:=16;
  If H4CabacOn Then Begin H4CbRange:=510; H4CbOffset:=H4Bits(9); End;
  H4CurCbp:=$2F; H4LastDqp:=0;
  H4StoreMb(False);
  Exit;
 End;
 Tx8:=False;
 If T=0 Then Begin
  If H4Pp^.Transform8x8<>0 Then Begin If H4CabacOn Then Tx8:=H4CbTx8 Else Tx8:=
   H4Bit<>0; End;
  If Tx8 Then H4CurType:=MT_I8 Else H4CurType:=MT_I4;
  If Tx8 Then H4CurTx8:=1;
  If Tx8 Then Begin
   For B8:=0 To 3 Do Begin
    Bx:=(B8 And 1)*2; By:=(B8 Shr 1)*2;
    Pm:=H4PredIpm(Bx,By);
    If H4CabacOn Then Mode:=H4CbIpm(Pm) Else Begin
     Prev:=H4Bit;
     If Prev<>0 Then Mode:=Pm Else Begin Rem:=H4Bits(3); If Rem<Pm Then Mode:=
      Rem Else Mode:=Rem+1; End;
    End;
    H4Ipm[By*4+Bx]:=Mode; H4Ipm[By*4+Bx+1]:=Mode; H4Ipm[(By+1)*4+Bx]:=Mode;
     H4Ipm[(By+1)*4+Bx+1]:=Mode;
   End;
  End Else Begin
   For Blk:=0 To 15 Do Begin
    Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
    Pm:=H4PredIpm(Bx,By);
    If H4CabacOn Then Mode:=H4CbIpm(Pm) Else Begin
     Prev:=H4Bit;
     If Prev<>0 Then Mode:=Pm Else Begin Rem:=H4Bits(3); If Rem<Pm Then Mode:=
      Rem Else Mode:=Rem+1; End;
    End;
    H4Ipm[By*4+Bx]:=Mode;
   End;
  End;
  If H4CabacOn Then H4ChromaMode:=H4CbChromaMode Else H4ChromaMode:=H4Ue;
  If H4ChromaMode>3 Then Begin H4Err:=True; Exit; End;
  If H4CabacOn Then H4CurCbp:=H4CbCbp(True) Else Begin
   I:=H4Ue;
   If I>47 Then Begin H4Err:=True; Exit; End;
   H4CurCbp:=H4GolombToIntra4X4Cbp[I];
  End;
 End Else Begin
  H4CurType:=MT_I16;
  Pm:=(T-1) And 3; CbpC:=((T-1) Shr 2) Mod 3; If T>=13 Then CbpL:=15 Else CbpL:=
   0;
  H4I16Mode:=Pm;
  H4CurCbp:=CbpL Or (CbpC Shl 4);
  If H4CabacOn Then H4ChromaMode:=H4CbChromaMode Else H4ChromaMode:=H4Ue;
  If H4ChromaMode>3 Then Begin H4Err:=True; Exit; End;
 End;
 CbpL:=H4CurCbp And 15; CbpC:=H4CurCbp Shr 4;
 If (H4CurCbp>0) Or (H4CurType=MT_I16) Then Begin
  If H4CabacOn Then Dq:=H4CbDqp Else Dq:=H4Se;
  If (Dq<-26) Or (Dq>25) Then Begin H4Err:=True; Exit; End;
  H4Qp:=(H4Qp+Dq+52) Mod 52;
  If Dq<>0 Then H4LastDqp:=1 Else H4LastDqp:=0;
 End Else H4LastDqp:=0;
 H4QpC[0]:=H4ChromaQp(H4Qp,H4Pp^.ChromaQpOffset); H4QpC[1]:=H4ChromaQp(H4Qp,
  H4Pp^.ChromaQpOffset2);
 If H4CabacOn Then Begin
  Ok:=H4LumaCabac(Tx8,H4CurType=MT_I16,CbpL);
  If Ok Then Ok:=H4ChromaCabac(CbpC);
 End Else Begin
  Ok:=H4LumaCavlc(Tx8,H4CurType=MT_I16,CbpL);
  If Ok Then Ok:=H4ChromaCavlc(CbpC);
 End;
 If Not Ok Then Begin H4Err:=True; Exit; End;
 { reconstruction luma }
 Pl:=H4Pics[H4Cur].Y;
 If H4CurType=MT_I4 Then Begin
  For Blk:=0 To 15 Do Begin
   Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
   AvL:=(Bx>0) Or H4IiA; AvT:=(By>0) Or H4IiB;
   If (Bx>0) And (By>0) Then AvTL:=True Else If Bx>0 Then AvTL:=H4IiB Else If
    By>0 Then AvTL:=H4IiA Else AvTL:=H4IiD;
   If By=0 Then Begin If Bx<3 Then AvTR:=H4IiB Else AvTR:=H4IiC; End
   Else If Bx=3 Then AvTR:=False
   Else AvTR:=H4BlkOrder[(By-1)*4+Bx+1]<H4BlkOrder[By*4+Bx];
   If Not H4OkMode(H4Ipm[By*4+Bx],AvL,AvT,AvTL) Then Begin H4Err:=True; Exit;
    End;
   H4Pred4x4(Pl,H4StrideY,X0+Bx*4,Y0+By*4,H4Ipm[By*4+Bx],AvL,AvT,AvTR,AvTL);
   If ((CbpL Shr (Blk Shr 2)) And 1)<>0 Then H4AddLuma4(Blk,H4Qp,0,False,0);
  End;
 End Else If H4CurType=MT_I8 Then Begin
  For B8:=0 To 3 Do Begin
   Bx:=(B8 And 1)*2; By:=(B8 Shr 1)*2;
   AvL:=(Bx>0) Or H4IiA; AvT:=(By>0) Or H4IiB;
   If (Bx>0) And (By>0) Then AvTL:=True Else If Bx>0 Then AvTL:=H4IiB Else If
    By>0 Then AvTL:=H4IiA Else AvTL:=H4IiD;
   Case B8 Of 0: AvTR:=H4IiB; 1: AvTR:=H4IiC; 2: AvTR:=True; Else AvTR:=False;
    End;
   If Not H4OkMode(H4Ipm[By*4+Bx],AvL,AvT,AvTL) Then Begin H4Err:=True; Exit;
    End;
   H4Pred8x8(Pl,H4StrideY,X0+Bx*4,Y0+By*4,H4Ipm[By*4+Bx],AvL,AvT,AvTR,AvTL);
   If ((CbpL Shr B8) And 1)<>0 Then H4AddLuma8(B8,H4Qp,0);
  End;
 End Else Begin
  If Not H4OkMode16(H4I16Mode,H4IiA,H4IiB,H4IiD) Then Begin H4Err:=True; Exit;
   End;
  H4Pred16x16(Pl,H4StrideY,X0,Y0,H4I16Mode,H4IiA,H4IiB);
  H4LumaDcTransform(H4LumaDc,Dc,H4Qp);
  For Blk:=0 To 15 Do Begin
   Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
   H4AddLuma4(Blk,H4Qp,0,True,Dc[By*4+Bx]);
  End;
 End;
 { chroma }
 If Not H4OkModeC(H4ChromaMode,H4IiA,H4IiB,H4IiD) Then Begin H4Err:=True; Exit;
  End;
 H4PredChroma(H4Pics[H4Cur].U,H4StrideC,H4MbX*8,H4MbY*8,H4ChromaMode,H4IiA,
  H4IiB);
 H4PredChroma(H4Pics[H4Cur].V,H4StrideC,H4MbX*8,H4MbY*8,H4ChromaMode,H4IiA,
  H4IiB);
 H4AddChroma(True);
 H4StoreMb(False);
End;


{ ---- filtre de deblocage ---- }
Var H4SlDis,H4SlAlpha,H4SlBeta,H4SlCb,H4SlCr: PEABuffer;   { par numero de
 tranche }

Procedure H4FiltLuma(Pl: PEABuffer; Pos,Step,Bs,Alpha,Beta,Tc0: LongInt);
Var P0,P1,P2,P3,Q0,Q1,Q2,Q3,Ap,Aq,Tc,D,V: LongInt;
Begin
 P0:=Pl^[Pos-Step]; P1:=Pl^[Pos-2*Step]; Q0:=Pl^[Pos]; Q1:=Pl^[Pos+Step];
 If (Abs(P0-Q0)>=Alpha) Or (Abs(P1-P0)>=Beta) Or (Abs(Q1-Q0)>=Beta) Then Exit;
 P2:=Pl^[Pos-3*Step]; Q2:=Pl^[Pos+2*Step];
 Ap:=Abs(P2-P0); Aq:=Abs(Q2-Q0);
 If Bs<4 Then Begin
  Tc:=Tc0;
  If Ap<Beta Then Inc(Tc);
  If Aq<Beta Then Inc(Tc);
  D:=H4Clip3(-Tc,Tc,H4Sar(((Q0-P0) Shl 2)+(P1-Q1)+4,3));
  Pl^[Pos-Step]:=H4Clip(P0+D); Pl^[Pos]:=H4Clip(Q0-D);
  If Ap<Beta Then Pl^[Pos-2*Step]:=P1+H4Clip3(-Tc0,Tc0,H4Sar(P2+((P0+Q0+1) Shr
   1)-(P1 Shl 1),1));
  If Aq<Beta Then Pl^[Pos+Step]:=Q1+H4Clip3(-Tc0,Tc0,H4Sar(Q2+((P0+Q0+1) Shr 1)-
   (Q1 Shl 1),1));
 End Else Begin
  P3:=Pl^[Pos-4*Step]; Q3:=Pl^[Pos+3*Step];
  If (Ap<Beta) And (Abs(P0-Q0)<((Alpha Shr 2)+2)) Then Begin
   Pl^[Pos-Step]:=(P2+2*P1+2*P0+2*Q0+Q1+4) Shr 3;
   Pl^[Pos-2*Step]:=(P2+P1+P0+Q0+2) Shr 2;
   Pl^[Pos-3*Step]:=(2*P3+3*P2+P1+P0+Q0+4) Shr 3;
  End Else Pl^[Pos-Step]:=(2*P1+P0+Q1+2) Shr 2;
  If (Aq<Beta) And (Abs(P0-Q0)<((Alpha Shr 2)+2)) Then Begin
   Pl^[Pos]:=(P1+2*P0+2*Q0+2*Q1+Q2+4) Shr 3;
   Pl^[Pos+Step]:=(P0+Q0+Q1+Q2+2) Shr 2;
   Pl^[Pos+2*Step]:=(2*Q3+3*Q2+Q1+Q0+P0+4) Shr 3;
  End Else Pl^[Pos]:=(2*Q1+Q0+P1+2) Shr 2;
 End;
End;
Procedure H4FiltChroma(Pl: PEABuffer; Pos,Step,Bs,Alpha,Beta,Tc0: LongInt);
Var P0,P1,Q0,Q1,Tc,D: LongInt;
Begin
 P0:=Pl^[Pos-Step]; P1:=Pl^[Pos-2*Step]; Q0:=Pl^[Pos]; Q1:=Pl^[Pos+Step];
 If (Abs(P0-Q0)>=Alpha) Or (Abs(P1-P0)>=Beta) Or (Abs(Q1-Q0)>=Beta) Then Exit;
 If Bs<4 Then Begin
  Tc:=Tc0+1;
  D:=H4Clip3(-Tc,Tc,H4Sar(((Q0-P0) Shl 2)+(P1-Q1)+4,3));
  Pl^[Pos-Step]:=H4Clip(P0+D); Pl^[Pos]:=H4Clip(Q0-D);
 End Else Begin
  Pl^[Pos-Step]:=(2*P1+P0+Q1+2) Shr 2;
  Pl^[Pos]:=(2*Q1+Q0+P1+2) Shr 2;
 End;
End;

{ coefficients non nuls du bloc 4x4 (en tenant compte de la transformee 8x8) }
Function H4HasCoef(Addr,Blk: LongInt): Boolean;
Var Bx,By,B0: LongInt;
Begin
 If H4Tx8Tab^[Addr]<>0 Then Begin
  Bx:=Blk And 3; By:=Blk Shr 2; B0:=(By And 2)*4+(Bx And 2);
  H4HasCoef:=(H4NnzTab^[Addr*48+B0]+H4NnzTab^[Addr*48+B0+1]+H4NnzTab^[Addr*48+
   B0+4]+H4NnzTab^[Addr*48+B0+5])>0;
 End Else H4HasCoef:=H4NnzTab^[Addr*48+Blk]>0;
End;

Function H4BsInter(Addr,Blk,AddrP,BlkP: LongInt): LongInt; Forward;

Function H4Bs(AddrQ,BlkQ,AddrP,BlkP: LongInt; MbEdge: Boolean): LongInt;
Begin
 If ((H4Pics[H4Cur].MbType^[AddrQ] Or H4Pics[H4Cur].MbType^[AddrP]) And
  MT_INTRA)<>0 Then Begin
  If MbEdge Then H4Bs:=4 Else H4Bs:=3; Exit;
 End;
 If H4HasCoef(AddrQ,BlkQ) Or H4HasCoef(AddrP,BlkP) Then Begin H4Bs:=2; Exit;
  End;
 H4Bs:=H4BsInter(AddrQ,BlkQ,AddrP,BlkP);
End;

Procedure H4DeblockMb(Mx,My: LongInt);
Var Addr,Sn,AOff,BOff,E,Seg,Ln,Dir,X0,Y0,AddrP,BlkQ,BlkP,Bs: LongInt;
 Tx8,Edge0Ok: Boolean; Bsv: Array[0..3] Of LongInt; QpQ,QpP,QpAv,IdxA,IdxB,
  Alpha,Beta,Tc0,Pos,Step,Cq,Cp: LongInt; Pl: PEABuffer; Cb,Cr: LongInt;
 Qc: LongInt;
Begin
 Addr:=My*H4MbW+Mx; Sn:=H4SliceTab^[Addr];
 If Sn<0 Then Exit;
 If H4SlDis^[Sn]=1 Then Exit;
 AOff:=ShortInt(H4SlAlpha^[Sn]); BOff:=ShortInt(H4SlBeta^[Sn]);
 Tx8:=H4Tx8Tab^[Addr]<>0;
 X0:=Mx*16; Y0:=My*16;
 For Dir:=0 To 1 Do Begin
  { Dir 0 : bords verticaux ; 1 : bords horizontaux }
  For E:=0 To 3 Do Begin
   If Tx8 And Odd(E) Then Continue;
   If E=0 Then Begin
    If Dir=0 Then Begin
     If Mx=0 Then Continue;
     AddrP:=Addr-1;
    End Else Begin
     If My=0 Then Continue;
     AddrP:=Addr-H4MbW;
    End;
    If (H4SlDis^[Sn]=2) And (H4SliceTab^[AddrP]<>Sn) Then Continue;
   End Else AddrP:=Addr;
   For Seg:=0 To 3 Do Begin
    If Dir=0 Then Begin
     BlkQ:=Seg*4+E; If E=0 Then BlkP:=Seg*4+3 Else BlkP:=Seg*4+E-1;
    End Else Begin
     BlkQ:=E*4+Seg; If E=0 Then BlkP:=12+Seg Else BlkP:=(E-1)*4+Seg;
    End;
    Bsv[Seg]:=H4Bs(Addr,BlkQ,AddrP,BlkP,E=0);
   End;
   QpQ:=H4QpTab^[Addr]; QpP:=H4QpTab^[AddrP];
   { luma }
   QpAv:=(QpQ+QpP+1) Shr 1;
   IdxA:=H4Clip3(0,51,QpAv+AOff); IdxB:=H4Clip3(0,51,QpAv+BOff);
   Alpha:=H4Alpha[52+IdxA]; Beta:=H4Beta[52+IdxB];
   If (Alpha<>0) And (Beta<>0) Then
    For Seg:=0 To 3 Do If Bsv[Seg]>0 Then Begin
     If Bsv[Seg]<4 Then Tc0:=H4Tc0[(52+IdxA)*4+Bsv[Seg]] Else Tc0:=0;
     For Ln:=0 To 3 Do Begin
      If Dir=0 Then Begin Pos:=(Y0+Seg*4+Ln)*H4StrideY+X0+E*4; Step:=1; End
      Else Begin Pos:=(Y0+E*4)*H4StrideY+X0+Seg*4+Ln; Step:=H4StrideY; End;
      H4FiltLuma(H4Pics[H4Cur].Y,Pos,Step,Bsv[Seg],Alpha,Beta,Tc0);
     End;
    End;
   { chroma : aretes 0 et 2 }
   If (E=0) Or (E=2) Then
    For Cb:=0 To 1 Do Begin
     If Cb=0 Then Begin Pl:=H4Pics[H4Cur].U; Cq:=H4SlCb^[Sn]; End Else Begin
      Pl:=H4Pics[H4Cur].V; Cq:=H4SlCr^[Sn]; End;
     Qc:=H4ChromaQp(QpQ,ShortInt(Cq)); Cp:=H4ChromaQp(QpP,ShortInt(Cq));
     QpAv:=(Qc+Cp+1) Shr 1;
     IdxA:=H4Clip3(0,51,QpAv+AOff); IdxB:=H4Clip3(0,51,QpAv+BOff);
     Alpha:=H4Alpha[52+IdxA]; Beta:=H4Beta[52+IdxB];
     If (Alpha=0) Or (Beta=0) Then Continue;
     For Seg:=0 To 3 Do If Bsv[Seg]>0 Then Begin
      If Bsv[Seg]<4 Then Tc0:=H4Tc0[(52+IdxA)*4+Bsv[Seg]] Else Tc0:=0;
      For Ln:=0 To 1 Do Begin
       If Dir=0 Then Begin Pos:=(My*8+Seg*2+Ln)*H4StrideC+Mx*8+E*2; Step:=1; End
       Else Begin Pos:=(My*8+E*2)*H4StrideC+Mx*8+Seg*2+Ln; Step:=H4StrideC; End;
       H4FiltChroma(Pl,Pos,Step,Bsv[Seg],Alpha,Beta,Tc0);
      End;
     End;
    End;
  End;
 End;
End;




{ ---- gestion d'une image ---- }
Var
 H4NalBuf: PEABuffer; H4NalCap: LongInt;
 H4Mode: LongInt; H4Target: String; H4OutBuf: PEABuffer; H4OutW,H4OutH,
  H4OutSize: LongInt;
 H4Began: Boolean; H4FpsN,H4FpsD: LongInt;
 H4Timing,H4RateSet,H4PtsAuto: Boolean; H4Start,H4CurDur,H4Floor,H4AutoOff:
  Int64;
 H4FramesOut: LongInt;
 H4PicOpen: Boolean;            { une image est en cours de decodage }
 H4PicSeqW,H4PicSeqH: LongInt;
 H4ErrCount: LongInt;

Procedure H4FreeTabs;
Begin
 If H4SliceTab<>Nil Then Begin
  FreeMem(H4SliceTab); FreeMem(H4QpTab); FreeMem(H4NnzTab); FreeMem(H4IpmTab);
   FreeMem(H4CpmTab); FreeMem(H4Tx8Tab);
  FreeMem(H4MvdTab); FreeMem(H4Dir8Tab); FreeMem(H4CbfTab); FreeMem(H4CbpTab);
  FreeMem(H4SlDis); FreeMem(H4SlAlpha); FreeMem(H4SlBeta); FreeMem(H4SlCb);
   FreeMem(H4SlCr);
  H4SliceTab:=Nil;
 End;
End;
Procedure H4AllocTabs;
Begin
 H4FreeTabs;
 GetMem(H4SliceTab,H4MbNum*4+16); GetMem(H4QpTab,H4MbNum+16); GetMem(H4NnzTab,
  H4MbNum*48+16); GetMem(H4IpmTab,H4MbNum*16+16);
 GetMem(H4CpmTab,H4MbNum+16); GetMem(H4Tx8Tab,H4MbNum+16); GetMem(H4MvdTab,
  H4MbNum*64+16); GetMem(H4Dir8Tab,H4MbNum*4+16);
 GetMem(H4CbfTab,H4MbNum*48+16); GetMem(H4CbpTab,H4MbNum*2+16);
 GetMem(H4SlDis,H4MbNum+16); GetMem(H4SlAlpha,H4MbNum+16); GetMem(H4SlBeta,
  H4MbNum+16); GetMem(H4SlCb,H4MbNum+16); GetMem(H4SlCr,H4MbNum+16);
End;

{ active un SPS (nouvelle sequence) }
Function H4Activate(Id: LongInt): Boolean;
Var S: ^TH4Sps;
Begin
 H4Activate:=False;
 S:=@H4Sps[Id];
 If (S^.ChromaFormat<>1) Or (S^.BitDepthY<>8) Or (S^.BitDepthC<>8) Or (
  S^.FrameMbsOnly=0) Then Exit;
 If (Not H4Started) Or (H4ActSps<>Id) Or (H4MbW<>S^.MbW) Or (H4MbH<>S^.MbH) Then
  Begin
  H4FreeAll;
  H4MbW:=S^.MbW; H4MbH:=S^.MbH; H4MbNum:=H4MbW*H4MbH; H4StrideY:=H4MbW*16;
   H4StrideC:=H4MbW*8;
  H4AllocTabs;
  H4ActSps:=Id; H4Started:=True; H4Cur:=-1; H4Seq:=H4Seq+1;
  If S^.BitstreamRestriction<>0 Then H4ReorderDepth:=S^.NumReorderFrames Else
   H4ReorderDepth:=15;
  If H4ReorderDepth>15 Then H4ReorderDepth:=15;
 End;
 H4Activate:=True;
End;

Procedure H4EmitPic(I: LongInt);
Var S: ^TH4Sps; CL,CR,CT,CB,W,H,Y,CW,CH: LongInt; P: ^TH4Pic;
Begin
 S:=@H4Sps[H4ActSps]; P:=@H4Pics[I];
 CL:=S^.CropL*2; CR:=S^.CropR*2; CT:=S^.CropT*2; CB:=S^.CropB*2;
 W:=H4MbW*16-CL-CR; H:=H4MbH*16-CT-CB;
 If (W<=0) Or (H<=0) Then Begin CL:=0; CR:=0; CT:=0; CB:=0; W:=H4MbW*16; H:=H4MbH*16; End;
 CW:=(W+1) Div 2; CH:=(H+1) Div 2;
 If Not H4Began Then Begin
  H4Began:=True; H4OutW:=W; H4OutH:=H; H4OutSize:=W*H*3 Div 2+64; GetMem(H4OutBuf,H4OutSize);
 End;
 If (W<>H4OutW) Or (H<>H4OutH) Then Exit;
 For Y:=0 To H-1 Do Move(P^.Y^[(CT+Y)*H4StrideY+CL],H4OutBuf^[Y*W],W);
 For Y:=0 To CH-1 Do Move(P^.U^[(CT Div 2+Y)*H4StrideC+CL Div 2],H4OutBuf^[W*H+Y*CW],CW);
 For Y:=0 To CH-1 Do Move(P^.V^[(CT Div 2+Y)*H4StrideC+CL Div 2],H4OutBuf^[W*H+CW*CH+Y*CW],CW);
 Inc(H4FramesOut);
 If @H4VidHook<>Nil Then H4VidHook(H4OutBuf,W,H);
End;

Procedure H4FinishPicture;
Var Mx,My,I,Mn: LongInt; S: ^TH4Sps; P: ^TH4Pic; Top,Bot: LongInt;
Begin
 If Not H4PicOpen Then Exit;
 H4PicOpen:=False;
 S:=@H4Sps[H4ActSps];
 For My:=0 To H4MbH-1 Do For Mx:=0 To H4MbW-1 Do H4DeblockMb(Mx,My);
 P:=@H4Pics[H4Cur];
 H4Marking(H4FirstSh,S^,H4Cur);
 If P^.Mmco5 Then Begin
  { effet de mmco5 sur la numerotation et le POC }
  Mn:=P^.PocTop; If P^.PocBot<Mn Then Mn:=P^.PocBot;
  P^.PocTop:=P^.PocTop-Mn; P^.PocBot:=P^.PocBot-Mn; P^.Poc:=P^.PocTop; If
   P^.PocBot<P^.Poc Then P^.Poc:=P^.PocBot;
  P^.FrameNum:=0;
  H4PrevPocMsb:=0; H4PrevPocLsb:=P^.PocTop; H4PrevHadMmco5:=True;
  H4PrevFrameNum:=0; H4PrevFrameNumOffset:=0; H4PrevRefFrameNum:=0;
 End Else Begin
  H4PrevHadMmco5:=False;
  H4PrevFrameNum:=H4FirstSh.FrameNum;
  H4PrevFrameNumOffset:=H4FrameNumOffset;
  If H4FirstSh.NalRefIdc<>0 Then H4PrevRefFrameNum:=H4FirstSh.FrameNum;
 End;
 If (H4FirstSh.Idr<>0) Or P^.Mmco5 Then H4Bump(True);
 P^.Output:=True;
 H4OutQueue[H4OutCount]:=H4Cur; Inc(H4OutCount);
 H4Bump(False);
End;

Procedure H4StartPicture(Var Sh: TH4Slice);
Var S: ^TH4Sps; Top,Bot,I: LongInt;
Begin
 S:=@H4Sps[H4ActSps];
 If Sh.Idr<>0 Then Begin
  H4PrevRefFrameNum:=0;
 End;
 H4Cur:=H4NewPic;
 If H4Cur<0 Then Begin
  { DPB plein : sortie forcee }
  H4Bump(True);
  H4Cur:=H4NewPic;
  If H4Cur<0 Then Begin H4Err:=True; Exit; End;
 End;
 H4ComputePoc(Sh,S^,Top,Bot);
 With H4Pics[H4Cur] Do Begin
  PocTop:=Top; PocBot:=Bot; If Bot<Top Then Poc:=Bot Else Poc:=Top;
  FrameNum:=Sh.FrameNum; FrameNumWrap:=Sh.FrameNum; Idr:=Sh.Idr<>0;
  RefState:=0;
 End;
 FillChar(H4SliceTab^,H4MbNum*4,255);
 H4SliceNum:=-1;
 H4FirstSh:=Sh;
 H4PicOpen:=True;
End;


{ ---- donnees de tranche et unites NAL ---- }
Procedure H4InterMb(T: LongInt); Forward;   { macrobloc inter (P/B) : ajoute
 plus loin }
Procedure H4SkipMb; Forward;

Procedure H4SliceDataCabac(Var Sh: TH4Slice);
Var T: LongInt; Skip,Fin: Boolean;
Begin
 H4MbAddr:=Sh.FirstMb;
 If H4MbAddr>=H4MbNum Then Begin H4Err:=True; Exit; End;
 H4Qp:=Sh.Qp; H4LastDqp:=0; H4SliceType:=Sh.SliceType;
 H4CabacInit(Sh.Qp,Sh.CabacInitIdc,(Sh.SliceType=2) Or (Sh.SliceType=4));
 Repeat
  If H4MbAddr>=H4MbNum Then Break;
  H4MbX:=H4MbAddr Mod H4MbW; H4MbY:=H4MbAddr Div H4MbW;
  H4SetupNeighbors;
  Skip:=False;
  If (H4SliceType<>2) And (H4SliceType<>4) Then Skip:=H4CbSkip;
  If Skip Then H4SkipMb Else Begin
   Case H4SliceType Of
    2,4: T:=H4CbIntraType(3,True);
    1: T:=H4CbMbTypeB;
   Else T:=H4CbMbTypeP;
   End;
   If H4Err Then Exit;
   Case H4SliceType Of
    2,4: H4DecodeIntraMb(T);
    0,3: If T<5 Then H4InterMb(T) Else H4DecodeIntraMb(T-5);
    1: If T<23 Then H4InterMb(T) Else H4DecodeIntraMb(T-23);
   End;
  End;
  If H4Err Then Exit;
  Fin:=H4CbTerm<>0;
  Inc(H4MbAddr);
 Until Fin;
End;

Procedure H4SliceData(Var Sh: TH4Slice);
Var T,Run,I: LongInt; More,PrevSkipped: Boolean;
Begin
 H4CabacOn:=H4Pp^.Cabac<>0;
 If H4CabacOn Then Begin H4SliceDataCabac(Sh); Exit; End;
 H4MbAddr:=Sh.FirstMb;
 If H4MbAddr>=H4MbNum Then Begin H4Err:=True; Exit; End;
 H4Qp:=Sh.Qp; H4LastDqp:=0; H4SliceType:=Sh.SliceType;
 More:=True; PrevSkipped:=False;
 While More Do Begin
  If H4MbAddr>=H4MbNum Then Break;
  H4MbX:=H4MbAddr Mod H4MbW; H4MbY:=H4MbAddr Div H4MbW;
  If (H4SliceType<>2) And (H4SliceType<>4) Then Begin
   { mb_skip_run }
   Run:=H4Ue;
   If H4Err Then Exit;
   While Run>0 Do Begin
    If H4MbAddr>=H4MbNum Then Begin H4Err:=True; Exit; End;
    H4MbX:=H4MbAddr Mod H4MbW; H4MbY:=H4MbAddr Div H4MbW;
    H4SetupNeighbors;
    H4SkipMb;
    Inc(H4MbAddr); Dec(Run);
   End;
   More:=H4MoreData;
   If Not More Then Break;
   If H4MbAddr>=H4MbNum Then Break;
   H4MbX:=H4MbAddr Mod H4MbW; H4MbY:=H4MbAddr Div H4MbW;
  End;
  H4SetupNeighbors;
  T:=H4Ue;
  If H4Err Then Exit;
  Case H4SliceType Of
   2,4: Begin If T>25 Then Begin H4Err:=True; Exit; End; H4DecodeIntraMb(T);
    End;
   0,3: Begin
    If T<5 Then H4InterMb(T) Else Begin If T>30 Then Begin H4Err:=True; Exit;
     End; H4DecodeIntraMb(T-5); End;
   End;
   1: Begin
    If T<23 Then H4InterMb(T) Else Begin If T>48 Then Begin H4Err:=True; Exit;
     End; H4DecodeIntraMb(T-23); End;
   End;
  End;
  If H4Err Then Exit;
  Inc(H4MbAddr);
  More:=H4MoreData;
 End;
End;

{ detection d'un nouveau point d'acces (7.4.1.2.4) }
Function H4NewAu(Var Sh: TH4Slice): Boolean;
Var A: ^TH4Slice;
Begin
 A:=@H4FirstSh;
 H4NewAu:=(Sh.FrameNum<>A^.FrameNum) Or (Sh.PpsId<>A^.PpsId) Or (
  Sh.FieldPic<>A^.FieldPic) Or (Sh.BottomField<>A^.BottomField)
  Or ((Sh.NalRefIdc=0)<>(A^.NalRefIdc=0)) Or (Sh.Idr<>A^.Idr) Or ((Sh.Idr<>0)
   And (Sh.IdrPicId<>A^.IdrPicId))
  Or (Sh.PocLsb<>A^.PocLsb) Or (Sh.DeltaPocBottom<>A^.DeltaPocBottom) Or (
   Sh.DeltaPoc[0]<>A^.DeltaPoc[0]) Or (Sh.DeltaPoc[1]<>A^.DeltaPoc[1]);
End;

{ une unite NAL (sans code de debut) }
Procedure H4HandleNal(P: PEABuffer; Len: LongInt; Pts: Int64);
Var NalType,NalRef,I,J,Zeros,R: LongInt; Sh: TH4Slice; NewPic: Boolean; S:
 ^TH4Sps;
Begin
 If Len<2 Then Exit;
 NalType:=P^[0] And 31; NalRef:=(P^[0] Shr 5) And 3;
 If (NalType<>1) And (NalType<>5) And (NalType<>7) And (NalType<>8) And (
  NalType<>9) And (NalType<>11) And (NalType<>10) And (NalType<>6) Then Exit;
 { retrait des octets d'emulation }
 If H4NalCap<Len+64 Then Begin If H4NalBuf<>Nil Then FreeMem(H4NalBuf);
  H4NalCap:=Len+4096; GetMem(H4NalBuf,H4NalCap); End;
 J:=0; Zeros:=0;
 For I:=1 To Len-1 Do Begin
  If (Zeros>=2) And (P^[I]=3) Then Begin Zeros:=0; Continue; End;
  H4NalBuf^[J]:=P^[I]; Inc(J);
  If P^[I]=0 Then Inc(Zeros) Else Zeros:=0;
 End;
 FillChar(H4NalBuf^[J],16,0);
 H4Rb:=H4NalBuf; H4RbSize:=J; H4Pos:=0; H4Err:=False;
 Case NalType Of
  7: Begin H4FinishPicture; H4ParseSps; End;
  8: Begin H4FinishPicture; H4ParsePps; End;
  6,9,10,11: H4FinishPicture;
  1,5: Begin
   If H4ParseSlice(Sh,NalType,NalRef)<>0 Then Begin Inc(H4ErrCount); Exit; End;
   If Sh.RedundantPicCnt<>0 Then Exit;
   H4Pp:=@H4Pps[Sh.PpsId]; H4Sp:=@H4Sps[H4Pp^.SpsId];
   If Sh.FieldPic<>0 Then Begin Inc(H4ErrCount); Exit; End;
   NewPic:=(Not H4PicOpen) Or H4NewAu(Sh);
   If NewPic Then Begin
    H4FinishPicture;
    If Not H4Activate(H4Pp^.SpsId) Then Begin Inc(H4ErrCount); Exit; End;
    H4StartPicture(Sh);
    If H4Err Then Exit;
    H4Pics[H4Cur].Pts:=Pts; H4Pics[H4Cur].Dur:=H4CurDur;
   End;
   If Not H4PicOpen Then Exit;
   Inc(H4SliceNum);
   Sh.SliceNum:=H4SliceNum;
   H4SetupQuant;
   H4SlDis^[H4SliceNum]:=Sh.DisableDeblock; H4SlAlpha^[H4SliceNum]:=Sh.AlphaOff
    And 255; H4SlBeta^[H4SliceNum]:=Sh.BetaOff And 255;
   H4SlCb^[H4SliceNum]:=H4Pp^.ChromaQpOffset And 255; H4SlCr^[H4SliceNum]:=
    H4Pp^.ChromaQpOffset2 And 255;
   H4BuildRefLists(Sh,H4Sp^,H4Cur);
   H4CurSh:=Sh;
   H4SliceData(Sh);
   If H4Err Then Inc(H4ErrCount);
  End;
 End;
End;

{ ---- couche inter : vecteurs, direct, compensation de mouvement, ponderation
 ---- }
Const
 H4BPair: Array[0..8,0..1] Of Byte=((1,1),(2,2),(1,2),(2,1),(1,3),(2,3),(3,1),(
  3,2),(3,3));
 H4SubBPred: Array[0..12] Of Byte=(0,1,2,3,1,1,2,2,3,3,1,2,3);
 H4SubBShape: Array[0..12] Of Byte=(0,0,0,0,1,2,1,2,1,2,3,3,3);
Var
 H4Done: LongInt;                         { blocs 4x4 du macrobloc deja decodes
  (bit = ligne*4+colonne) }
 H4McT: Array[0..1,0..255] Of LongInt;    { predictions luma par liste (pas 16)
  }
 H4McC: Array[0..1,0..1,0..63] Of LongInt; { predictions chroma par liste et
  composante (pas 8) }

Function H4Ref8(L,Addr,B8: LongInt): LongInt;
Begin
 H4Ref8:=ShortInt(PEABuffer(H4Pics[H4Cur].Ref[L])^[Addr*4+B8]);
End;
Function H4MvX(L,Addr,Blk: LongInt): LongInt;
Begin H4MvX:=PSmallArr(H4Pics[H4Cur].Mv[L])^[(Addr*16+Blk)*2]; End;
Function H4MvY(L,Addr,Blk: LongInt): LongInt;
Begin H4MvY:=PSmallArr(H4Pics[H4Cur].Mv[L])^[(Addr*16+Blk)*2+1]; End;

{ voisin en coordonnees de blocs 4x4 relatives au macrobloc ; R=-2 :
 indisponible, -1 : intra ou liste non utilisee }
Procedure H4Nb(L,Bx,By: LongInt; Var R,Mx,My: LongInt);
Var Addr,Blk: LongInt; Ok: Boolean;
Begin
 R:=-2; Mx:=0; My:=0; Addr:=H4MbAddr; Blk:=0; Ok:=False;
 If By<0 Then Begin
  If Bx<0 Then Begin Ok:=H4AvD; Addr:=H4MbAddr-H4MbW-1; Blk:=15; End
  Else If Bx>3 Then Begin Ok:=H4AvC; Addr:=H4MbAddr-H4MbW+1; Blk:=12; End
  Else Begin Ok:=H4AvB; Addr:=H4MbAddr-H4MbW; Blk:=12+Bx; End;
 End Else If Bx<0 Then Begin Ok:=H4AvA; Addr:=H4MbAddr-1; Blk:=By*4+3; End
 Else If Bx>3 Then Ok:=False
 Else Begin Ok:=((H4Done Shr (By*4+Bx)) And 1)<>0; Blk:=By*4+Bx; End;
 If Not Ok Then Exit;
 R:=-1;
 If Addr<>H4MbAddr Then If (H4Pics[H4Cur].MbType^[Addr] And MT_INTRA)<>0 Then
  Exit;
 R:=H4Ref8(L,Addr,(Blk Shr 3)*2+((Blk And 3) Shr 1));
 If R>=0 Then Begin Mx:=H4MvX(L,Addr,Blk); My:=H4MvY(L,Addr,Blk); End;
End;

Function H4Median(A,B,C: LongInt): LongInt;
Var Lo,Hi: LongInt;
Begin
 If A<B Then Begin Lo:=A; Hi:=B; End Else Begin Lo:=B; Hi:=A; End;
 If C<Lo Then H4Median:=Lo Else If C>Hi Then H4Median:=Hi Else H4Median:=C;
End;

{ Shape : 0 normal, 1 16x8 haut, 2 16x8 bas, 3 8x16 gauche, 4 8x16 droite }
Procedure H4PredMv(L,Bx,By,W4,Ref,Shape: LongInt; Var Mx,My: LongInt);
Var Ra,Rb,Rc,Ax,Ay,Bx2,By2,Cx,Cy,Cnt: LongInt;
Begin
 H4Nb(L,Bx-1,By,Ra,Ax,Ay);
 H4Nb(L,Bx,By-1,Rb,Bx2,By2);
 H4Nb(L,Bx+W4,By-1,Rc,Cx,Cy);
 If Rc=-2 Then H4Nb(L,Bx-1,By-1,Rc,Cx,Cy);
 If (Shape=1) And (Rb=Ref) Then Begin Mx:=Bx2; My:=By2; Exit; End;
 If (Shape=2) And (Ra=Ref) Then Begin Mx:=Ax; My:=Ay; Exit; End;
 If (Shape=3) And (Ra=Ref) Then Begin Mx:=Ax; My:=Ay; Exit; End;
 If (Shape=4) And (Rc=Ref) Then Begin Mx:=Cx; My:=Cy; Exit; End;
 If (Rb=-2) And (Rc=-2) And (Ra<>-2) Then Begin Mx:=Ax; My:=Ay; Exit; End;
 Cnt:=Ord(Ra=Ref)+Ord(Rb=Ref)+Ord(Rc=Ref);
 If Cnt=1 Then Begin
  If Ra=Ref Then Begin Mx:=Ax; My:=Ay; End
  Else If Rb=Ref Then Begin Mx:=Bx2; My:=By2; End
  Else Begin Mx:=Cx; My:=Cy; End;
 End Else Begin
  Mx:=H4Median(Ax,Bx2,Cx); My:=H4Median(Ay,By2,Cy);
 End;
End;

Procedure H4SetPart(L,Bx,By,W4,Hp,Ref,Mx,My: LongInt);
Var I,J,Addr: LongInt;
Begin
 Addr:=H4MbAddr;
 If (Mx<-32768) Or (Mx>32767) Or (My<-32768) Or (My>32767) Then Begin H4Err:=
  True; Mx:=0; My:=0; End;
 For J:=By To By+Hp-1 Do For I:=Bx To Bx+W4-1 Do Begin
  PSmallArr(H4Pics[H4Cur].Mv[L])^[(Addr*16+J*4+I)*2]:=Mx;
  PSmallArr(H4Pics[H4Cur].Mv[L])^[(Addr*16+J*4+I)*2+1]:=My;
  PEABuffer(H4Pics[H4Cur].Ref[L])^[Addr*4+(J Shr 1)*2+(I Shr 1)]:=Ref And 255;
  H4Done:=H4Done Or (1 Shl (J*4+I));
 End;
End;

Procedure H4PutRef(L,Bx,By,W4,Hp,Ref: LongInt);
Var I,J: LongInt;
Begin
 For J:=By Shr 1 To (By+Hp-1) Shr 1 Do For I:=Bx Shr 1 To (Bx+W4-1) Shr 1 Do
  PEABuffer(H4Pics[H4Cur].Ref[L])^[H4MbAddr*4+J*2+I]:=Ref And 255;
End;

{ lecture d'une difference de vecteur (CAVLC : deux se(v) ; CABAC : contextes
 mvd) }
Procedure H4ReadMvd(L,Bx,By,W4,Hp: LongInt; Var Dx,Dy: LongInt);
Var Ax,Ay,Mx,My,I,J: LongInt;
Begin
 If Not H4CabacOn Then Begin Dx:=H4Se; Dy:=H4Se; Exit; End;
 Ax:=H4NbMvd(L,Bx-1,By,0)+H4NbMvd(L,Bx,By-1,0);
 Ay:=H4NbMvd(L,Bx-1,By,1)+H4NbMvd(L,Bx,By-1,1);
 Dx:=H4CbMvd(40,Ax,Mx);
 Dy:=H4CbMvd(47,Ay,My);
 For J:=By To By+Hp-1 Do For I:=Bx To Bx+W4-1 Do Begin
  H4MvdTab^[(((H4MbAddr*2+L)*16+J*4+I) Shl 1)]:=Mx;
  H4MvdTab^[(((H4MbAddr*2+L)*16+J*4+I) Shl 1)+1]:=My;
 End;
End;

{ ---- mode direct ---- }
Function H4MinPos(A,B: LongInt): LongInt;
Begin
 If (A>=0) And (B>=0) Then Begin If A<B Then H4MinPos:=A Else H4MinPos:=B; End
 Else Begin If A>B Then H4MinPos:=A Else H4MinPos:=B; End;
End;

{ informations du bloc colocalise (image RefList1[0], meme macrobloc) }
Procedure H4ColBlk(Blk: LongInt; Var Intra: Boolean; Var RefC,Mx,My,PicId:
 LongInt);
Var CP: ^TH4Pic; Addr,L,B8: LongInt;
Begin
 CP:=@H4Pics[H4RefList[1,0]]; Addr:=H4MbAddr; B8:=(Blk Shr 3)*2+((Blk And 3) Shr
  1);
 Intra:=(CP^.MbType^[Addr] And MT_INTRA)<>0;
 RefC:=-1; Mx:=0; My:=0; PicId:=-1;
 If Intra Then Exit;
 L:=0; RefC:=ShortInt(PEABuffer(CP^.Ref[0])^[Addr*4+B8]);
 If RefC<0 Then Begin L:=1; RefC:=ShortInt(PEABuffer(CP^.Ref[1])^[Addr*4+B8]);
  End;
 If RefC>=0 Then Begin
  Mx:=PSmallArr(CP^.Mv[L])^[(Addr*16+Blk)*2]; My:=PSmallArr(CP^.Mv[L])^[(Addr*
   16+Blk)*2+1];
  PicId:=PLongArr(CP^.RefId[L])^[Addr*4+B8];
 End;
End;

Procedure H4Direct(Mask8: LongInt);
Var B8,K,I,J,L,Blk,Bx0,By0,Cblk,Ra,Rb,Rc,Ax,Ay,Mx,My,RefC,CMx,CMy,PicId,R0,Tb,
 Td,Tx,Dsf,M0x,M0y,Poc0,Poc1,PocC: LongInt;
 Rr: Array[0..1] Of LongInt; Pm: Array[0..1,0..1] Of LongInt; Intra,Lt,ColZero,
  Zero: Boolean; P1: ^TH4Pic; Pic0: LongInt;
Begin
 If (H4RefList[1,0]<0) Or (H4RefList[0,0]<0) Then Begin H4Err:=True; Exit; End;
 P1:=@H4Pics[H4RefList[1,0]];
 Lt:=P1^.RefState=2;
 If H4CurSh.DirectSpatial<>0 Then Begin
  For L:=0 To 1 Do Begin
   H4Nb(L,-1,0,Ra,Ax,Ay); H4Nb(L,0,-1,Rb,Ax,Ay); H4Nb(L,4,-1,Rc,Ax,Ay);
   If Rc=-2 Then H4Nb(L,-1,-1,Rc,Ax,Ay);
   If Ra<0 Then Ra:=-1; If Rb<0 Then Rb:=-1; If Rc<0 Then Rc:=-1;
   Rr[L]:=H4MinPos(Ra,H4MinPos(Rb,Rc));
  End;
  Zero:=False;
  If (Rr[0]<0) And (Rr[1]<0) Then Begin Rr[0]:=0; Rr[1]:=0; Zero:=True; End;
  For L:=0 To 1 Do Begin
   Pm[L,0]:=0; Pm[L,1]:=0;
   If (Rr[L]>=0) And Not Zero Then Begin H4PredMv(L,0,0,4,Rr[L],0,Mx,My); Pm[L,
    0]:=Mx; Pm[L,1]:=My; End;
  End;
  For B8:=0 To 3 Do If ((Mask8 Shr B8) And 1)<>0 Then Begin
   Bx0:=(B8 And 1)*2; By0:=(B8 Shr 1)*2;
   For L:=0 To 1 Do PEABuffer(H4Pics[H4Cur].Ref[L])^[H4MbAddr*4+B8]:=Rr[L] And
    255;
   ColZero:=False;
   If H4Sp^.Direct8x8Inference<>0 Then Begin
    H4ColBlk((By0+(B8 Shr 1))*4+Bx0+(B8 And 1),Intra,RefC,CMx,CMy,PicId);
    ColZero:=(Not Intra) And (Not Lt) And (RefC=0) And (Abs(CMx)<=1) And (Abs(
     CMy)<=1);
   End;
   For J:=By0 To By0+1 Do For I:=Bx0 To Bx0+1 Do Begin
    Blk:=J*4+I;
    If H4Sp^.Direct8x8Inference=0 Then Begin
     H4ColBlk(Blk,Intra,RefC,CMx,CMy,PicId);
     ColZero:=(Not Intra) And (Not Lt) And (RefC=0) And (Abs(CMx)<=1) And (Abs(
      CMy)<=1);
    End;
    For L:=0 To 1 Do Begin
     If (Rr[L]=0) And ColZero Then Begin Mx:=0; My:=0; End Else Begin Mx:=Pm[L,
      0]; My:=Pm[L,1]; End;
     PSmallArr(H4Pics[H4Cur].Mv[L])^[(H4MbAddr*16+Blk)*2]:=Mx; PSmallArr(H4Pics[
      H4Cur].Mv[L])^[(H4MbAddr*16+Blk)*2+1]:=My;
    End;
   End;
  End;
 End Else Begin
  { direct temporel }
  Poc1:=P1^.Poc; PocC:=H4Pics[H4Cur].Poc;
  For B8:=0 To 3 Do If ((Mask8 Shr B8) And 1)<>0 Then Begin
   Bx0:=(B8 And 1)*2; By0:=(B8 Shr 1)*2;
   For J:=By0 To By0+1 Do For I:=Bx0 To Bx0+1 Do Begin
    Blk:=J*4+I;
    If H4Sp^.Direct8x8Inference<>0 Then Cblk:=(By0+(B8 Shr 1))*4+Bx0+(B8 And 1)
     Else Cblk:=Blk;
    H4ColBlk(Cblk,Intra,RefC,CMx,CMy,PicId);
    R0:=0;
    If (Not Intra) And (PicId>=0) Then
     For K:=H4CurSh.NumRef[0]-1 DownTo 0 Do If H4RefList[0,K]>=0 Then If H4Pics[
      H4RefList[0,K]].Id=PicId Then R0:=K;
    Pic0:=H4RefList[0,R0];
    If Pic0<0 Then Begin H4Err:=True; Exit; End;
    Poc0:=H4Pics[Pic0].Poc;
    Td:=H4Clip3(-128,127,Poc1-Poc0);
    If (Td=0) Or (H4Pics[Pic0].RefState=2) Then Begin M0x:=CMx; M0y:=CMy; Mx:=0;
     My:=0; End
    Else Begin
     Tb:=H4Clip3(-128,127,PocC-Poc0);
     Tx:=(16384+(Abs(Td) Shr 1)) Div Td;
     Dsf:=H4Clip3(-1024,1023,H4Sar(Tb*Tx+32,6));
     M0x:=H4Sar(Dsf*CMx+128,8); M0y:=H4Sar(Dsf*CMy+128,8);
     Mx:=M0x-CMx; My:=M0y-CMy;
    End;
    PEABuffer(H4Pics[H4Cur].Ref[0])^[H4MbAddr*4+B8]:=R0;
    PEABuffer(H4Pics[H4Cur].Ref[1])^[H4MbAddr*4+B8]:=0;
    PSmallArr(H4Pics[H4Cur].Mv[0])^[(H4MbAddr*16+Blk)*2]:=M0x; PSmallArr(H4Pics[
     H4Cur].Mv[0])^[(H4MbAddr*16+Blk)*2+1]:=M0y;
    PSmallArr(H4Pics[H4Cur].Mv[1])^[(H4MbAddr*16+Blk)*2]:=Mx; PSmallArr(H4Pics[
     H4Cur].Mv[1])^[(H4MbAddr*16+Blk)*2+1]:=My;
   End;
  End;
 End;
End;

{ ---- compensation de mouvement ---- }
Procedure H4McLuma(Src: PEABuffer; X,Y,Fx,Fy,Bw,Bh: LongInt; Dst: PLongArr);
Const PS=21;
Var P,Hb,Vh: Array[0..440] Of LongInt; Cx,Cy: Array[0..20] Of LongInt; R,C,I,J,
 PW,PH,G,V: LongInt;
Function Tap(A,B,Cc,D,E,F: LongInt): LongInt;
Begin Tap:=A-5*B+20*Cc+20*D-5*E+F; End;
Function Bq(Ii,Jj: LongInt): LongInt;
Begin Bq:=H4Clip(H4Sar(Hb[(Jj+2)*PS+Ii]+16,5)); End;
Function Sq(Ii,Jj: LongInt): LongInt;
Begin Sq:=H4Clip(H4Sar(Hb[(Jj+3)*PS+Ii]+16,5)); End;
Function Hq(Ii,Jj: LongInt): LongInt;
Begin Hq:=H4Clip(H4Sar(Vh[Jj*PS+Ii+2]+16,5)); End;
Function Mq(Ii,Jj: LongInt): LongInt;
Begin Mq:=H4Clip(H4Sar(Vh[Jj*PS+Ii+3]+16,5)); End;
Function Jq(Ii,Jj: LongInt): LongInt;
Begin Jq:=H4Clip(H4Sar(Tap(Hb[Jj*PS+Ii],Hb[(Jj+1)*PS+Ii],Hb[(Jj+2)*PS+Ii],Hb[(
 Jj+3)*PS+Ii],Hb[(Jj+4)*PS+Ii],Hb[(Jj+5)*PS+Ii])+512,10)); End;
Begin
 PW:=H4MbW*16; PH:=H4MbH*16;
 For C:=0 To Bw+4 Do Begin V:=X-2+C; If V<0 Then V:=0 Else If V>PW-1 Then V:=PW-
  1; Cx[C]:=V; End;
 For R:=0 To Bh+4 Do Begin V:=Y-2+R; If V<0 Then V:=0 Else If V>PH-1 Then V:=PH-
  1; Cy[R]:=V*PW; End;
 For R:=0 To Bh+4 Do For C:=0 To Bw+4 Do P[R*PS+C]:=Src^[Cy[R]+Cx[C]];
 If (Fx=0) And (Fy=0) Then Begin
  For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do Dst^[J*16+I]:=P[(J+2)*PS+I+2];
  Exit;
 End;
 If Fx<>0 Then
  For R:=0 To Bh+4 Do For C:=0 To Bw-1 Do
   Hb[R*PS+C]:=Tap(P[R*PS+C],P[R*PS+C+1],P[R*PS+C+2],P[R*PS+C+3],P[R*PS+C+4],P[
    R*PS+C+5]);
 If Fy<>0 Then
  For R:=0 To Bh-1 Do For C:=0 To Bw+4 Do
   Vh[R*PS+C]:=Tap(P[R*PS+C],P[(R+1)*PS+C],P[(R+2)*PS+C],P[(R+3)*PS+C],P[(R+4)*
    PS+C],P[(R+5)*PS+C]);
 For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do Begin
  G:=P[(J+2)*PS+I+2];
  Case Fy*4+Fx Of
   1: V:=(G+Bq(I,J)+1) Shr 1;
   2: V:=Bq(I,J);
   3: V:=(P[(J+2)*PS+I+3]+Bq(I,J)+1) Shr 1;
   4: V:=(G+Hq(I,J)+1) Shr 1;
   5: V:=(Bq(I,J)+Hq(I,J)+1) Shr 1;
   6: V:=(Bq(I,J)+Jq(I,J)+1) Shr 1;
   7: V:=(Bq(I,J)+Mq(I,J)+1) Shr 1;
   8: V:=Hq(I,J);
   9: V:=(Hq(I,J)+Jq(I,J)+1) Shr 1;
   10: V:=Jq(I,J);
   11: V:=(Jq(I,J)+Mq(I,J)+1) Shr 1;
   12: V:=(P[(J+3)*PS+I+2]+Hq(I,J)+1) Shr 1;
   13: V:=(Hq(I,J)+Sq(I,J)+1) Shr 1;
   14: V:=(Jq(I,J)+Sq(I,J)+1) Shr 1;
  Else V:=(Mq(I,J)+Sq(I,J)+1) Shr 1;
  End;
  Dst^[J*16+I]:=V;
 End;
End;

Procedure H4McChroma(Src: PEABuffer; X,Y,Fx,Fy,Bw,Bh: LongInt; Dst: PLongArr);
Var I,J,PW,PH,X0,X1,Y0,Y1: LongInt;
Begin
 PW:=H4MbW*8; PH:=H4MbH*8;
 For J:=0 To Bh-1 Do Begin
  Y0:=Y+J; If Y0<0 Then Y0:=0 Else If Y0>PH-1 Then Y0:=PH-1;
  Y1:=Y+J+1; If Y1<0 Then Y1:=0 Else If Y1>PH-1 Then Y1:=PH-1;
  For I:=0 To Bw-1 Do Begin
   X0:=X+I; If X0<0 Then X0:=0 Else If X0>PW-1 Then X0:=PW-1;
   X1:=X+I+1; If X1<0 Then X1:=0 Else If X1>PW-1 Then X1:=PW-1;
   Dst^[J*8+I]:=((8-Fx)*(8-Fy)*Src^[Y0*PW+X0]+Fx*(8-Fy)*Src^[Y0*PW+X1]+(8-Fx)*
    Fy*Src^[Y1*PW+X0]+Fx*Fy*Src^[Y1*PW+X1]+32) Shr 6;
  End;
 End;
End;

{ Mode 0 copie, 1 pondere (une liste), 2 moyenne, 3 pondere bi-predit }
Procedure H4PutBlock(Dst: PEABuffer; DStr,Bw,Bh: LongInt; A0,A1: PLongArr; PStr,
 Mode,W0,W1,O,Lg: LongInt);
Var I,J,V,P0,P1: LongInt;
Begin
 For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do Begin
  P0:=A0^[J*PStr+I]; P1:=0;
  If A1<>Nil Then P1:=A1^[J*PStr+I];
  Case Mode Of
   0: V:=P0;
   1: Begin
    If Lg>=1 Then V:=H4Sar(P0*W0+(1 Shl (Lg-1)),Lg)+O Else V:=P0*W0+O;
    V:=H4Clip(V);
   End;
   2: V:=(P0+P1+1) Shr 1;
  Else V:=H4Clip(H4Sar(P0*W0+P1*W1+(1 Shl Lg),Lg+1)+O);
  End;
  Dst^[J*DStr+I]:=V;
 End;
End;

{ mouvement identique sur tout le bloc (Bx,By,W4,Hp en blocs 4x4) : lit les
 tables de l'image courante }
Procedure H4McBlock(Bx,By,W4,Hp: LongInt);
Var L,B8,Blk,Bw,Bh,X0,Y0,PicIdx,Mode,W0,W1,O,Lg,C,Cnt,Lu,Poc0,Poc1,PocC,Tb,Td,
 Tx,Dsf,Wt: LongInt;
 R,Mx,My: Array[0..1] Of LongInt; Pc: Array[0..1] Of ^TH4Pic; Explicit,Implicit,
  Bipred: Boolean; Dst: PEABuffer;
Begin
 B8:=(By Shr 1)*2+(Bx Shr 1); Blk:=By*4+Bx; Bw:=W4*4; Bh:=Hp*4;
 X0:=H4MbX*16+Bx*4; Y0:=H4MbY*16+By*4;
 Cnt:=0; Lu:=0;
 For L:=0 To 1 Do Begin
  R[L]:=H4Ref8(L,H4MbAddr,B8); Pc[L]:=Nil; Mx[L]:=0; My[L]:=0;
  If R[L]>=0 Then Begin
   If R[L]>32 Then Begin H4Err:=True; Exit; End;
   PicIdx:=H4RefList[L,R[L]];
   If PicIdx<0 Then Begin H4Err:=True; Exit; End;
   Pc[L]:=@H4Pics[PicIdx]; Mx[L]:=H4MvX(L,H4MbAddr,Blk); My[L]:=H4MvY(L,
    H4MbAddr,Blk);
   H4McLuma(Pc[L]^.Y,X0+H4Sar(Mx[L],2),Y0+H4Sar(My[L],2),Mx[L] And 3,My[L] And
    3,Bw,Bh,@H4McT[L]);
   H4McChroma(Pc[L]^.U,(X0 Shr 1)+H4Sar(Mx[L],3),(Y0 Shr 1)+H4Sar(My[L],3),Mx[L]
    And 7,My[L] And 7,Bw Shr 1,Bh Shr 1,@H4McC[L,0]);
   H4McChroma(Pc[L]^.V,(X0 Shr 1)+H4Sar(Mx[L],3),(Y0 Shr 1)+H4Sar(My[L],3),Mx[L]
    And 7,My[L] And 7,Bw Shr 1,Bh Shr 1,@H4McC[L,1]);
   Inc(Cnt); Lu:=L;
  End;
 End;
 If Cnt=0 Then Begin H4Err:=True; Exit; End;
 Bipred:=Cnt=2;
 Explicit:=((H4SliceType<>1) And (H4Pp^.WeightedPred<>0)) Or ((H4SliceType=1)
  And (H4Pp^.WeightedBipred=1));
 Implicit:=(H4SliceType=1) And (H4Pp^.WeightedBipred=2);
 For C:=0 To 2 Do Begin
  If C=0 Then Begin Dst:=@H4Pics[H4Cur].Y^[Y0*H4StrideY+X0]; End
  Else If C=1 Then Dst:=@H4Pics[H4Cur].U^[(Y0 Shr 1)*H4StrideC+(X0 Shr 1)]
  Else Dst:=@H4Pics[H4Cur].V^[(Y0 Shr 1)*H4StrideC+(X0 Shr 1)];
  Mode:=0; W0:=0; W1:=0; O:=0; Lg:=0;
  If Not Bipred Then Begin
   If Explicit Then Begin
    Mode:=1;
    If C=0 Then Begin W0:=H4CurSh.LumaW[Lu,R[Lu]]; O:=H4CurSh.LumaO[Lu,R[Lu]];
     Lg:=H4CurSh.LumaLog2Wd; End
    Else Begin W0:=H4CurSh.ChromaW[Lu,R[Lu],C-1]; O:=H4CurSh.ChromaO[Lu,R[Lu],C-
     1]; Lg:=H4CurSh.ChromaLog2Wd; End;
   End;
  End Else Begin
   If Explicit Then Begin
    Mode:=3;
    If C=0 Then Begin
     W0:=H4CurSh.LumaW[0,R[0]]; W1:=H4CurSh.LumaW[1,R[1]]; O:=H4Sar(
      H4CurSh.LumaO[0,R[0]]+H4CurSh.LumaO[1,R[1]]+1,1); Lg:=H4CurSh.LumaLog2Wd;
    End Else Begin
     W0:=H4CurSh.ChromaW[0,R[0],C-1]; W1:=H4CurSh.ChromaW[1,R[1],C-1];
     O:=H4Sar(H4CurSh.ChromaO[0,R[0],C-1]+H4CurSh.ChromaO[1,R[1],C-1]+1,1); Lg:=
      H4CurSh.ChromaLog2Wd;
    End;
   End Else If Implicit Then Begin
    Poc0:=Pc[0]^.Poc; Poc1:=Pc[1]^.Poc; PocC:=H4Pics[H4Cur].Poc;
    Td:=H4Clip3(-128,127,Poc1-Poc0); W1:=32; W0:=32;
    If (Td<>0) And (Pc[0]^.RefState<>2) And (Pc[1]^.RefState<>2) Then Begin
     Tb:=H4Clip3(-128,127,PocC-Poc0); Tx:=(16384+(Abs(Td) Shr 1)) Div Td;
     Dsf:=H4Clip3(-1024,1023,H4Sar(Tb*Tx+32,6));
     Wt:=H4Sar(Dsf,2);
     If (Wt>=-64) And (Wt<=128) Then Begin W1:=Wt; W0:=64-Wt; End;
    End;
    Mode:=3; O:=0; Lg:=5;
   End Else Mode:=2;
  End;
  If C=0 Then Begin
   If Bipred Then H4PutBlock(Dst,H4StrideY,Bw,Bh,@H4McT[0],@H4McT[1],16,Mode,W0,
    W1,O,Lg)
   Else H4PutBlock(Dst,H4StrideY,Bw,Bh,@H4McT[Lu],Nil,16,Mode,W0,W1,O,Lg);
  End Else Begin
   If Bipred Then H4PutBlock(Dst,H4StrideC,Bw Shr 1,Bh Shr 1,@H4McC[0,C-1],
    @H4McC[1,C-1],8,Mode,W0,W1,O,Lg)
   Else H4PutBlock(Dst,H4StrideC,Bw Shr 1,Bh Shr 1,@H4McC[Lu,C-1],Nil,8,Mode,W0,
    W1,O,Lg);
  End;
 End;
End;

Function H4SameBlk(A,B: LongInt): Boolean;
Var L,Ra,Rb: LongInt;
Begin
 H4SameBlk:=False;
 For L:=0 To 1 Do Begin
  Ra:=H4Ref8(L,H4MbAddr,(A Shr 3)*2+((A And 3) Shr 1)); Rb:=H4Ref8(L,H4MbAddr,(B
   Shr 3)*2+((B And 3) Shr 1));
  If Ra<>Rb Then Exit;
  If Ra>=0 Then If (H4MvX(L,H4MbAddr,A)<>H4MvX(L,H4MbAddr,B)) Or (H4MvY(L,
   H4MbAddr,A)<>H4MvY(L,H4MbAddr,B)) Then Exit;
 End;
 H4SameBlk:=True;
End;

Procedure H4McMb;
Var B8,K,I,J,Bx,By: LongInt; All: Boolean;
Begin
 All:=True;
 For K:=1 To 15 Do If Not H4SameBlk(0,K) Then Begin All:=False; Break; End;
 If All Then Begin H4McBlock(0,0,4,4); Exit; End;
 For B8:=0 To 3 Do Begin
  Bx:=(B8 And 1)*2; By:=(B8 Shr 1)*2;
  If H4SameBlk(By*4+Bx,By*4+Bx+1) And H4SameBlk(By*4+Bx,(By+1)*4+Bx) And
   H4SameBlk(By*4+Bx,(By+1)*4+Bx+1) Then H4McBlock(Bx,By,2,2)
  Else For J:=0 To 1 Do For I:=0 To 1 Do H4McBlock(Bx+I,By+J,1,1);
  If H4Err Then Exit;
 End;
End;

Procedure H4SetRefIds;
Var L,B8,R,P: LongInt;
Begin
 For L:=0 To 1 Do For B8:=0 To 3 Do Begin
  R:=H4Ref8(L,H4MbAddr,B8); P:=-1;
  If (R>=0) And (R<=32) Then If H4RefList[L,R]>=0 Then P:=H4Pics[H4RefList[L,
   R]].Id;
  PLongArr(H4Pics[H4Cur].RefId[L])^[H4MbAddr*4+B8]:=P;
 End;
End;

{ ---- intensite de filtrage entre blocs inter ---- }
Function H4BsInter(Addr,Blk,AddrP,BlkP: LongInt): LongInt;
Var Cur: ^TH4Pic; Iq,Ip: Array[0..1] Of LongInt; Qx,Qy,Px,Py: Array[0..1] Of
 LongInt; L,Nq,Np,B8Q,B8P: LongInt;
Function Diff(Xa,Ya,Xb,Yb: LongInt): Boolean;
Begin Diff:=(Abs(Xa-Xb)>=4) Or (Abs(Ya-Yb)>=4); End;
Begin
 Cur:=@H4Pics[H4Cur]; H4BsInter:=1;
 B8Q:=(Blk Shr 3)*2+((Blk And 3) Shr 1); B8P:=(BlkP Shr 3)*2+((BlkP And 3) Shr
  1);
 Nq:=0; Np:=0;
 For L:=0 To 1 Do Begin
  Iq[L]:=-1; Ip[L]:=-1; Qx[L]:=0; Qy[L]:=0; Px[L]:=0; Py[L]:=0;
  If ShortInt(PEABuffer(Cur^.Ref[L])^[Addr*4+B8Q])>=0 Then Begin
   Iq[L]:=PLongArr(Cur^.RefId[L])^[Addr*4+B8Q]; Qx[L]:=H4MvX(L,Addr,Blk); Qy[
    L]:=H4MvY(L,Addr,Blk); Inc(Nq);
  End;
  If ShortInt(PEABuffer(Cur^.Ref[L])^[AddrP*4+B8P])>=0 Then Begin
   Ip[L]:=PLongArr(Cur^.RefId[L])^[AddrP*4+B8P]; Px[L]:=H4MvX(L,AddrP,BlkP); Py[
    L]:=H4MvY(L,AddrP,BlkP); Inc(Np);
  End;
 End;
 If Nq<>Np Then Exit;
 If Nq=1 Then Begin
  If Iq[0]>=0 Then L:=0 Else L:=1;
  If Ip[0]>=0 Then Begin
   If Iq[L]<>Ip[0] Then Exit;
   H4BsInter:=Ord(Diff(Qx[L],Qy[L],Px[0],Py[0]));
  End Else Begin
   If Iq[L]<>Ip[1] Then Exit;
   H4BsInter:=Ord(Diff(Qx[L],Qy[L],Px[1],Py[1]));
  End;
  Exit;
 End;
 If Not (((Iq[0]=Ip[0]) And (Iq[1]=Ip[1])) Or ((Iq[0]=Ip[1]) And (Iq[1]=Ip[0])))
  Then Exit;
 If Iq[0]<>Iq[1] Then Begin
  If Iq[0]=Ip[0] Then H4BsInter:=Ord(Diff(Qx[0],Qy[0],Px[0],Py[0]) Or Diff(Qx[
   1],Qy[1],Px[1],Py[1]))
  Else H4BsInter:=Ord(Diff(Qx[0],Qy[0],Px[1],Py[1]) Or Diff(Qx[1],Qy[1],Px[0],
   Py[0]));
 End Else
  H4BsInter:=Ord((Diff(Qx[0],Qy[0],Px[0],Py[0]) Or Diff(Qx[1],Qy[1],Px[1],Py[
   1])) And (Diff(Qx[0],Qy[0],Px[1],Py[1]) Or Diff(Qx[1],Qy[1],Px[0],Py[0])));
End;

{ ---- macroblocs inter ---- }
Procedure H4SkipMb;
Var Ra,Rb,Ax,Ay,Bx,By,Mx,My: LongInt;
Begin
 H4Done:=0; FillChar(H4Nnz,SizeOf(H4Nnz),0); H4CurTx8:=0; H4ChromaMode:=0;
  H4CurCbp:=0; H4LastDqp:=0;
 H4CurType:=MT_INTER Or MT_SKIP;
 If H4SliceType=1 Then Begin
  H4CurType:=H4CurType Or MT_DIRECT;
  FillChar(H4CurDir8,4,1);
  H4Direct(15);
  If H4Err Then Exit;
 End Else Begin
  H4Nb(0,-1,0,Ra,Ax,Ay); H4Nb(0,0,-1,Rb,Bx,By);
  If (Ra=-2) Or (Rb=-2) Or ((Ra=0) And (Ax=0) And (Ay=0)) Or ((Rb=0) And (Bx=0)
   And (By=0)) Then Begin Mx:=0; My:=0; End
  Else H4PredMv(0,0,0,4,0,0,Mx,My);
  H4SetPart(0,0,0,4,4,0,Mx,My);
  H4SetPart(1,0,0,4,4,-1,0,0);
 End;
 H4SetRefIds;
 H4McMb;
 H4StoreMb(True);
End;

Procedure H4InterMb(T: LongInt);
Var Shape,NP,I,J,K,L,B8,Lmax,Cbp,CbpL,CbpC,Dq,Mx,My,Dx,Dy,Bx,By,W4,Hp,Sh,
 DirMask,Blk: LongInt;
 PBx,PBy,PW4,PHp,PPred,PShape: Array[0..3] Of LongInt; SubShape,SubPred: Array[
  0..3] Of LongInt; SubDir: Array[0..3] Of Boolean;
 Rf: Array[0..1,0..3] Of LongInt; NRef: Array[0..1] Of LongInt; Ref0Mode,
  DirectAll,Small,Tx8,Ok: Boolean; Pr: LongInt;
Procedure Part(P,X,Y,W,H,Pred,Shp: LongInt);
Begin PBx[P]:=X; PBy[P]:=Y; PW4[P]:=W; PHp[P]:=H; PPred[P]:=Pred; PShape[P]:=
 Shp; End;
Begin
 H4Done:=0; FillChar(H4Nnz,SizeOf(H4Nnz),0); H4CurTx8:=0; H4ChromaMode:=0;
 H4CurType:=MT_INTER; DirectAll:=False; Small:=False; Ref0Mode:=False; DirMask:=
  0;
 NRef[0]:=H4CurSh.NumRef[0]; NRef[1]:=H4CurSh.NumRef[1];
 FillChar(Rf,SizeOf(Rf),0);
 For I:=0 To 3 Do Begin SubDir[I]:=False; SubShape[I]:=0; SubPred[I]:=0; End;
 Shape:=0; NP:=1;
 If H4SliceType=1 Then Begin
  Lmax:=1;
  If T=0 Then Begin DirectAll:=True; H4CurType:=H4CurType Or MT_DIRECT; End
  Else If T<=3 Then Begin Shape:=0; Part(0,0,0,4,4,T,0); End
  Else If T<22 Then Begin
   K:=(T-4) Div 2;
   If (T And 1)=0 Then Begin Shape:=1; Part(0,0,0,4,2,H4BPair[K,0],1); Part(1,0,
    2,4,2,H4BPair[K,1],2); End
   Else Begin Shape:=2; Part(0,0,0,2,4,H4BPair[K,0],3); Part(1,2,0,2,4,H4BPair[
    K,1],4); End;
   NP:=2;
  End Else Shape:=3;
 End Else Begin
  Lmax:=0;
  Case T Of
   0: Part(0,0,0,4,4,1,0);
   1: Begin Shape:=1; NP:=2; Part(0,0,0,4,2,1,1); Part(1,0,2,4,2,1,2); End;
   2: Begin Shape:=2; NP:=2; Part(0,0,0,2,4,1,3); Part(1,2,0,2,4,1,4); End;
  Else Begin Shape:=3; Ref0Mode:=T=4; End;
  End;
 End;
 If Shape=3 Then Begin
  For B8:=0 To 3 Do Begin
   If H4CabacOn Then Begin
    If H4SliceType=1 Then I:=H4CbSubB Else I:=H4CbSubP;
   End Else I:=H4Ue;
   If H4SliceType=1 Then Begin
    If I>12 Then Begin H4Err:=True; Exit; End;
    SubPred[B8]:=H4SubBPred[I]; SubShape[B8]:=H4SubBShape[I]; SubDir[B8]:=I=0;
    If I=0 Then Begin DirMask:=DirMask Or (1 Shl B8); H4CurDir8[B8]:=1; If
     H4Sp^.Direct8x8Inference=0 Then Small:=True; End;
   End Else Begin
    If I>3 Then Begin H4Err:=True; Exit; End;
    SubPred[B8]:=1; SubShape[B8]:=I;
   End;
   If (Not SubDir[B8]) And (SubShape[B8]<>0) Then Small:=True;
  End;
 End;
 If H4Err Then Exit;
 If DirectAll Then Begin
  FillChar(H4CurDir8,4,1);
  H4Direct(15);
  If H4Sp^.Direct8x8Inference=0 Then Small:=True;
  H4SetRefIds;
 End Else Begin
  If DirMask<>0 Then Begin H4Direct(DirMask); If H4Err Then Exit; End;
  { indices de reference }
  For L:=0 To 1 Do For B8:=0 To 3 Do If Not SubDir[B8] Then PEABuffer(H4Pics[
   H4Cur].Ref[L])^[H4MbAddr*4+B8]:=255;
  For L:=0 To Lmax Do Begin
   If Shape=3 Then Begin
    For B8:=0 To 3 Do If (Not SubDir[B8]) And ((SubPred[B8] And (1 Shl L))<>0)
     Then Begin
     If Ref0Mode Or (NRef[L]<=1) Then Rf[L,B8]:=0
     Else If H4CabacOn Then Rf[L,B8]:=H4CbRef(L,(B8 And 1)*2,(B8 Shr 1)*2)
     Else Rf[L,B8]:=H4Te(NRef[L]-1);
     If (Rf[L,B8]<0) Or (Rf[L,B8]>=NRef[L]) Or H4Err Then Begin H4Err:=True;
      Exit; End;
     H4PutRef(L,(B8 And 1)*2,(B8 Shr 1)*2,2,2,Rf[L,B8]);
    End;
   End Else
    For I:=0 To NP-1 Do If (PPred[I] And (1 Shl L))<>0 Then Begin
     If NRef[L]<=1 Then Rf[L,I]:=0
     Else If H4CabacOn Then Rf[L,I]:=H4CbRef(L,PBx[I],PBy[I])
     Else Rf[L,I]:=H4Te(NRef[L]-1);
     If (Rf[L,I]<0) Or (Rf[L,I]>=NRef[L]) Or H4Err Then Begin H4Err:=True; Exit;
      End;
     H4PutRef(L,PBx[I],PBy[I],PW4[I],PHp[I],Rf[L,I]);
    End;
  End;
  If H4Err Then Exit;
  { vecteurs }
  For L:=0 To Lmax Do Begin
   H4Done:=0;
   If Shape=3 Then Begin
    For B8:=0 To 3 Do Begin
     Bx:=(B8 And 1)*2; By:=(B8 Shr 1)*2;
     If SubDir[B8] Then Begin
      H4Done:=H4Done Or (51 Shl (By*4+Bx));
     End Else If (SubPred[B8] And (1 Shl L))=0 Then H4SetPart(L,Bx,By,2,2,-1,0,
      0)
     Else Begin
      Case SubShape[B8] Of
       0: Begin NP:=1; W4:=2; Hp:=2; End;
       1: Begin NP:=2; W4:=2; Hp:=1; End;
       2: Begin NP:=2; W4:=1; Hp:=2; End;
      Else Begin NP:=4; W4:=1; Hp:=1; End;
      End;
      For K:=0 To NP-1 Do Begin
       Case SubShape[B8] Of
        0: Begin I:=0; J:=0; End;
        1: Begin I:=0; J:=K; End;
        2: Begin I:=K; J:=0; End;
       Else Begin I:=K And 1; J:=K Shr 1; End;
       End;
       H4PredMv(L,Bx+I,By+J,W4,Rf[L,B8],0,Mx,My);
       H4ReadMvd(L,Bx+I,By+J,W4,Hp,Dx,Dy);
       H4SetPart(L,Bx+I,By+J,W4,Hp,Rf[L,B8],Mx+Dx,My+Dy);
      End;
     End;
    End;
   End Else
    For I:=0 To NP-1 Do Begin
     If (PPred[I] And (1 Shl L))=0 Then H4SetPart(L,PBx[I],PBy[I],PW4[I],PHp[I],
      -1,0,0)
     Else Begin
      H4PredMv(L,PBx[I],PBy[I],PW4[I],Rf[L,I],PShape[I],Mx,My);
      H4ReadMvd(L,PBx[I],PBy[I],PW4[I],PHp[I],Dx,Dy);
      H4SetPart(L,PBx[I],PBy[I],PW4[I],PHp[I],Rf[L,I],Mx+Dx,My+Dy);
     End;
    End;
  End;
  If H4SliceType<>1 Then H4SetPart(1,0,0,4,4,-1,0,0);
  H4SetRefIds;
 End;
 If H4Err Then Exit;
 H4McMb;
 If H4Err Then Exit;
 { residu }
 If H4CabacOn Then Cbp:=H4CbCbp(False) Else Begin
  I:=H4Ue;
  If I>47 Then Begin H4Err:=True; Exit; End;
  Cbp:=H4GolombToInterCbp[I];
 End;
 H4CurCbp:=Cbp; CbpL:=Cbp And 15; CbpC:=Cbp Shr 4;
 Tx8:=False;
 If (CbpL<>0) And (H4Pp^.Transform8x8<>0) And (Not Small) Then Begin If
  H4CabacOn Then Tx8:=H4CbTx8 Else Tx8:=H4Bit<>0; End;
 If Tx8 Then H4CurTx8:=1;
 If Cbp<>0 Then Begin
  If H4CabacOn Then Dq:=H4CbDqp Else Dq:=H4Se;
  If (Dq<-26) Or (Dq>25) Then Begin H4Err:=True; Exit; End;
  H4Qp:=(H4Qp+Dq+52) Mod 52;
  If Dq<>0 Then H4LastDqp:=1 Else H4LastDqp:=0;
 End Else H4LastDqp:=0;
 H4QpC[0]:=H4ChromaQp(H4Qp,H4Pp^.ChromaQpOffset); H4QpC[1]:=H4ChromaQp(H4Qp,
  H4Pp^.ChromaQpOffset2);
 If H4CabacOn Then Begin
  Ok:=H4LumaCabac(Tx8,False,CbpL);
  If Ok Then Ok:=H4ChromaCabac(CbpC);
 End Else Begin
  Ok:=H4LumaCavlc(Tx8,False,CbpL);
  If Ok Then Ok:=H4ChromaCavlc(CbpC);
 End;
 If Not Ok Then Begin H4Err:=True; Exit; End;
 If Tx8 Then Begin
  For B8:=0 To 3 Do If ((CbpL Shr B8) And 1)<>0 Then H4AddLuma8(B8,H4Qp,1);
 End Else
  For Blk:=0 To 15 Do If ((CbpL Shr (Blk Shr 2)) And 1)<>0 Then
   If H4Nnz[H4BlkY[Blk]*4+H4BlkX[Blk]]<>0 Then H4AddLuma4(Blk,H4Qp,3,False,0);
 H4AddChroma(False);
 H4StoreMb(False);
End;


{ flux brut Annex B : decoupe aux codes de debut 00 00 01 }
Procedure H4InitState;
Var I: LongInt;
Begin
 FillChar(H4Sps,SizeOf(H4Sps),0); FillChar(H4Pps,SizeOf(H4Pps),0);
 For I:=0 To H4MaxPics-1 Do H4Pics[I].Used:=False;
 H4Started:=False; H4PicOpen:=False; H4Began:=False; H4Cur:=-1; H4OutCount:=0;
  H4FramesOut:=0; H4ErrCount:=0;
 H4PrevPocMsb:=0; H4PrevPocLsb:=0; H4PrevFrameNumOffset:=0; H4FrameNumOffset:=0;
  H4PrevFrameNum:=0; H4PrevRefFrameNum:=0;
 H4AutoOff:=0; H4Floor:=-4000000000000; H4Timing:=False; H4RateSet:=False;
  H4PtsAuto:=False; H4Start:=0; H4CurDur:=0;
 H4PrevHadMmco5:=False; H4NextId:=1; H4Seq:=0; H4NalBuf:=Nil; H4NalCap:=0;
  H4SliceTab:=Nil; H4ActSps:=-1; H4MbW:=0; H4MbH:=0;
 H4InitTabs;
End;

Procedure H4FeedNalPacket(P: PEABuffer; Len: LongInt; NalSz: LongInt; Pts:
 Int64);
{ NalSz=0 : flux Annex B (codes de debut) ; sinon unites precedees d'une
 longueur sur NalSz octets }
Var I,Start,E,N,K: LongInt;
Begin
 If NalSz=0 Then Begin
  I:=0; Start:=-1;
  While I+2<Len Do Begin
   If (P^[I]=0) And (P^[I+1]=0) And (P^[I+2]=1) Then Begin
    If Start>=0 Then Begin
     E:=I; While (E>Start) And (P^[E-1]=0) Do Dec(E);
     H4HandleNal(PEABuffer(@P^[Start]),E-Start,Pts);
    End;
    Start:=I+3; Inc(I,3);
   End Else Inc(I);
  End;
  If Start>=0 Then Begin
   E:=Len; While (E>Start) And (P^[E-1]=0) Do Dec(E);
   H4HandleNal(PEABuffer(@P^[Start]),E-Start,Pts);
  End;
 End Else Begin
  I:=0;
  While I+NalSz<=Len Do Begin
   N:=0; For K:=0 To NalSz-1 Do N:=N*256+P^[I+K];
   Inc(I,NalSz);
   If (N<=0) Or (I+N>Len) Then Break;
   H4HandleNal(PEABuffer(@P^[I]),N,Pts);
   Inc(I,N);
  End;
 End;
End;

{ lit un enregistrement avcC et alimente les SPS/PPS ; renvoie la taille du
 champ longueur }
Function H4FeedAvcc(Mp: PEABuffer; Len: LongInt): LongInt;
Var Pos,N,I,L: LongInt;
Begin
 H4FeedAvcc:=4;
 If (Len<7) Or (Mp^[0]<>1) Then Exit;
 H4FeedAvcc:=(Mp^[4] And 3)+1;
 Pos:=6; N:=Mp^[5] And 31;
 For I:=1 To N Do Begin
  If Pos+2>Len Then Exit;
  L:=Mp^[Pos]*256+Mp^[Pos+1]; Inc(Pos,2);
  If Pos+L>Len Then Exit;
  H4HandleNal(PEABuffer(@Mp^[Pos]),L,0); Inc(Pos,L);
 End;
 If Pos<Len Then Begin
  N:=Mp^[Pos]; Inc(Pos);
  For I:=1 To N Do Begin
   If Pos+2>Len Then Exit;
   L:=Mp^[Pos]*256+Mp^[Pos+1]; Inc(Pos,2);
   If Pos+L>Len Then Exit;
   H4HandleNal(PEABuffer(@Mp^[Pos]),L,0); Inc(Pos,L);
  End;
 End;
End;

{ ---- libx264 : encodeur H.264 natif (profil Baseline contraint, CAVLC, I/P,
 sans filtre de deblocage) vers flux brut Annex B ou MP4 ---- }
Const
 X4MF: Array[0..5,0..2] Of LongInt=((13107,5243,8066),(11916,4660,7490),(10082,
  4194,6554),(9362,3647,5825),(8192,3355,5243),(7282,2893,4559));
 X4V: Array[0..5,0..2] Of LongInt=((10,16,13),(11,18,14),(13,20,16),(14,23,18),(
  16,25,20),(18,29,23));
 X4Zig: Array[0..15] Of LongInt=(0,1,4,8,5,2,3,6,9,12,13,10,7,11,14,15);
 X4BlkX: Array[0..15] Of LongInt=(0,1,0,1,2,3,2,3,0,1,0,1,2,3,2,3);
 X4BlkY: Array[0..15] Of LongInt=(0,0,1,1,0,0,1,1,2,2,3,3,2,2,3,3);
Type
 X4Arr=Array[0..15] Of LongInt;
Var
 X4Rb: PEABuffer; X4RbBits: LongInt;           { RBSP en cours d'ecriture }
 X4Mbw,X4Mbh,X4Wp,X4Hp,X4Cw,X4Ch: LongInt;
 X4Src,X4Rec,X4Ref: PEABuffer;                  { Y puis U puis V, planes
  alignes sur les macroblocs }
 X4NnzY,X4NnzU,X4NnzV: PEABuffer; X4Kind: PEABuffer; X4Mvx,X4Mvy: PLongArr;
 X4Qp,X4SkipRun,X4Lam: LongInt; X4Inter: Boolean;
 X4CbpInv: Array[0..47] Of Byte;
 X4Ready: Boolean;
 X4Crf,X4QpFix,X4Gop,X4BitsTarget: LongInt; X4Preset: String;

Procedure X4Put(V: Int64; N: LongInt);
Var K: LongInt;
Begin
 For K:=N-1 Downto 0 Do Begin
  If ((V Shr K) And 1)<>0 Then X4Rb^[X4RbBits Shr 3]:=X4Rb^[X4RbBits Shr 3] Or (
   1 Shl (7-(X4RbBits And 7)));
  Inc(X4RbBits);
 End;
End;
Procedure X4Ue(V: LongInt);
Var N,T: LongInt;
Begin
 Inc(V); N:=0; T:=V; While T>1 Do Begin T:=T Shr 1; Inc(N); End;
 X4Put(0,N); X4Put(V,N+1);
End;
Procedure X4Se(V: LongInt);
Begin If V>0 Then X4Ue(2*V-1) Else X4Ue(-2*V); End;
Procedure X4Trail; Begin X4Put(1,1); While (X4RbBits And 7)<>0 Do X4Put(0,1);
 End;

{ ---- CAVLC ---- }
Procedure X4Level(Lc,Sl: LongInt);
Var Pre,Suf,Sz: LongInt;
Begin
 If Sl=0 Then Begin
  If Lc<14 Then Begin Pre:=Lc; Sz:=0; Suf:=0; End
  Else If Lc<30 Then Begin Pre:=14; Sz:=4; Suf:=Lc-14; End
  Else Begin Pre:=15; Sz:=12; Suf:=Lc-30; End;
 End Else Begin
  If Lc<(15 Shl Sl) Then Begin Pre:=Lc Shr Sl; Sz:=Sl; Suf:=Lc And ((1 Shl Sl)-
   1); End
  Else Begin Pre:=15; Sz:=12; Suf:=Lc-(15 Shl Sl); End;
 End;
 If Suf>4095 Then Suf:=4095;
 X4Put(0,Pre); X4Put(1,1);
 If Sz>0 Then X4Put(Suf,Sz);
End;
{ ecrit un bloc ; Lev en ordre de balayage ; NC=-1 DC chroma ; renvoie
 TotalCoeff }
Function X4Block(Const Lev: Array Of LongInt; MaxC,NC: LongInt): LongInt;
Var Total,T1,I,Sl,Lv,Lc,Zeros,Zl,Run,Idx: LongInt; Vals,Pos: X4Arr;
Begin
 Total:=0;
 For I:=MaxC-1 Downto 0 Do If Lev[I]<>0 Then Begin Vals[Total]:=Lev[I]; Pos[
  Total]:=I; Inc(Total); End;
 T1:=0; While (T1<Total) And (T1<3) And (Abs(Vals[T1])=1) Do Inc(T1);
 If NC=-1 Then Begin Idx:=Total*4+T1; X4Put(H4ChromaDcCoeffTokenBits[Idx],
  H4ChromaDcCoeffTokenLen[Idx]); End
 Else If NC>=8 Then Begin
  If Total=0 Then X4Put(3,6) Else X4Put(((Total-1) Shl 2) Or T1,6);
 End Else Begin
  If NC<2 Then Idx:=0 Else If NC<4 Then Idx:=1 Else Idx:=2;
  Idx:=Idx*68+Total*4+T1; X4Put(H4CoeffTokenBits[Idx],H4CoeffTokenLen[Idx]);
 End;
 X4Block:=Total;
 If Total=0 Then Exit;
 For I:=0 To T1-1 Do If Vals[I]<0 Then X4Put(1,1) Else X4Put(0,1);
 If (Total>10) And (T1<3) Then Sl:=1 Else Sl:=0;
 For I:=T1 To Total-1 Do Begin
  Lv:=Vals[I];
  If Lv>0 Then Lc:=2*Lv-2 Else Lc:=-2*Lv-1;
  If (I=T1) And (T1<3) Then Dec(Lc,2);
  X4Level(Lc,Sl);
  If Sl=0 Then Sl:=1;
  If (Abs(Lv)>(3 Shl (Sl-1))) And (Sl<6) Then Inc(Sl);
 End;
 Zeros:=Pos[0]+1-Total;
 If Total<MaxC Then Begin
  If NC=-1 Then Idx:=(Total-1)*4+Zeros Else Idx:=(Total-1)*16+Zeros;
  If NC=-1 Then X4Put(H4ChromaDcTotalZerosBits[Idx],H4ChromaDcTotalZerosLen[
   Idx])
  Else X4Put(H4TotalZerosBits[Idx],H4TotalZerosLen[Idx]);
 End;
 Zl:=Zeros;
 For I:=0 To Total-2 Do Begin
  If Zl<=0 Then Break;
  Run:=Pos[I]-Pos[I+1]-1;
  Idx:=Zl; If Idx>7 Then Idx:=7;
  Idx:=(Idx-1)*16+Run;
  X4Put(H4RunBits[Idx],H4RunLen[Idx]);
  Dec(Zl,Run);
 End;
End;

{ ---- transformees ---- }
Procedure X4Fdct(Var B: X4Arr);
Var I,A,Bb,C,D: LongInt; T: X4Arr;
Begin
 For I:=0 To 3 Do Begin
  A:=B[I*4]+B[I*4+3]; Bb:=B[I*4+1]+B[I*4+2]; C:=B[I*4+1]-B[I*4+2]; D:=B[I*4]-B[
   I*4+3];
  T[I*4]:=A+Bb; T[I*4+2]:=A-Bb; T[I*4+1]:=2*D+C; T[I*4+3]:=D-2*C;
 End;
 For I:=0 To 3 Do Begin
  A:=T[I]+T[12+I]; Bb:=T[4+I]+T[8+I]; C:=T[4+I]-T[8+I]; D:=T[I]-T[12+I];
  B[I]:=A+Bb; B[8+I]:=A-Bb; B[4+I]:=2*D+C; B[12+I]:=D-2*C;
 End;
End;
Function X4Cls(I: LongInt): LongInt;
Var R,C: LongInt;
Begin R:=I Shr 2; C:=I And 3; If ((R And 1)=0) And ((C And 1)=0) Then X4Cls:=0
 Else If ((R And 1)=1) And ((C And 1)=1) Then X4Cls:=1 Else X4Cls:=2; End;
Function X4Q(V,Mf,Qb,F: LongInt): LongInt;
Var A: Int64;
Begin
 A:=(Int64(Abs(V))*Mf+F) Shr Qb;
 If A>2047 Then A:=2047;
 If V<0 Then X4Q:=-A Else X4Q:=A;
End;
{ dequantification d'un coefficient AC (flat) }
Function X4Dq(C,Qp,Cls: LongInt): LongInt;
Var Ls: LongInt;
Begin
 Ls:=16*X4V[Qp Mod 6,Cls];
 If Qp>=24 Then X4Dq:=(C*Ls) Shl (Qp Div 6-4) Else X4Dq:=H4Sar(C*Ls+(1 Shl (3-Qp
  Div 6)),4-Qp Div 6);
End;

Function X4Sad(Pa,Pb: PEABuffer; Sa,Sb,W,H: LongInt): LongInt;
Var I,J,S: LongInt;
Begin
 S:=0;
 For J:=0 To H-1 Do For I:=0 To W-1 Do Inc(S,Abs(Pa^[J*Sa+I]-Pb^[J*Sb+I]));
 X4Sad:=S;
End;

{ quantifie et reconstruit un bloc 4x4 (residu deja calcule dans Res) ; Lev
 recoit les niveaux en balayage ; renvoie nb de coefs non nuls ;
  Start : 0 ou 1 (le DC est traite a part) ; DcOut : coefficient DC transforme
   (non quantifie) }
Function X4QuantBlock(Var Res: X4Arr; Qp: LongInt; Intra: Boolean; Start:
 LongInt; Var Lev: Array Of LongInt; Var Dq: X4Arr; Var Dc: LongInt): LongInt;
Var I,K,Qb,F,N: LongInt; W: X4Arr;
Begin
 W:=Res; X4Fdct(W);
 Dc:=W[0];
 Qb:=15+Qp Div 6;
 If Intra Then F:=(1 Shl Qb) Div 3 Else F:=(1 Shl Qb) Div 6;
 N:=0; FillChar(Dq,SizeOf(Dq),0);
 For K:=Start To 15 Do Begin
  I:=X4Zig[K];
  Lev[K-Start]:=X4Q(W[I],X4MF[Qp Mod 6,X4Cls(I)],Qb,F);
  If Lev[K-Start]<>0 Then Begin Inc(N); Dq[I]:=X4Dq(Lev[K-Start],Qp,X4Cls(I));
   End;
 End;
 X4QuantBlock:=N;
End;

{ prediction de vecteur 16x16 (quarts de pixel) }
Procedure X4Mvp(Mx,My: LongInt; Var Px,Py: LongInt; Var AvA,AvB: Boolean; Var
 RefA,RefB: LongInt; Var MvAx,MvAy,MvBx,MvBy: LongInt);
Var Ia,Ib,Ic,RefC,MvCx,MvCy,Cnt: LongInt; AvC: Boolean;
 Function Med(A,B,C: LongInt): LongInt;
 Begin If A>B Then Begin If B>C Then Med:=B Else If A>C Then Med:=C Else Med:=A;
  End Else Begin If A>C Then Med:=A Else If B>C Then Med:=C Else Med:=B; End;
  End;
Begin
 AvA:=Mx>0; AvB:=My>0; AvC:=False; RefA:=-1; RefB:=-1; RefC:=-1; MvAx:=0; MvAy:=
  0; MvBx:=0; MvBy:=0; MvCx:=0; MvCy:=0;
 If AvA Then Begin Ia:=My*X4Mbw+Mx-1; If X4Kind^[Ia]>=1 Then Begin RefA:=0;
  MvAx:=X4Mvx^[Ia]; MvAy:=X4Mvy^[Ia]; End; End;
 If AvB Then Begin Ib:=(My-1)*X4Mbw+Mx; If X4Kind^[Ib]>=1 Then Begin RefB:=0;
  MvBx:=X4Mvx^[Ib]; MvBy:=X4Mvy^[Ib]; End; End;
 If My>0 Then Begin
  If Mx<X4Mbw-1 Then Begin Ic:=(My-1)*X4Mbw+Mx+1; AvC:=True; End
  Else If Mx>0 Then Begin Ic:=(My-1)*X4Mbw+Mx-1; AvC:=True; End;
  If AvC And (X4Kind^[Ic]>=1) Then Begin RefC:=0; MvCx:=X4Mvx^[Ic]; MvCy:=
   X4Mvy^[Ic]; End;
 End;
 If (Not AvB) And (Not AvC) And AvA Then Begin Px:=MvAx; Py:=MvAy; Exit; End;
 Cnt:=Ord(RefA=0)+Ord(RefB=0)+Ord(RefC=0);
 If Cnt=1 Then Begin
  If RefA=0 Then Begin Px:=MvAx; Py:=MvAy; End Else If RefB=0 Then Begin Px:=
   MvBx; Py:=MvBy; End Else Begin Px:=MvCx; Py:=MvCy; End;
 End Else Begin Px:=Med(MvAx,MvBx,MvCx); Py:=Med(MvAy,MvBy,MvCy); End;
End;

Function X4NcLuma(Gx,Gy: LongInt): LongInt;
Var A,B,Aa,Bb: LongInt;
Begin
 Aa:=Ord(Gx>0); Bb:=Ord(Gy>0);
 If Aa<>0 Then A:=X4NnzY^[Gy*X4Mbw*4+Gx-1] Else A:=0;
 If Bb<>0 Then B:=X4NnzY^[(Gy-1)*X4Mbw*4+Gx] Else B:=0;
 If (Aa<>0) And (Bb<>0) Then X4NcLuma:=(A+B+1) Shr 1 Else X4NcLuma:=A+B;
End;
Function X4NcChroma(Pl: PEABuffer; Gx,Gy: LongInt): LongInt;
Var A,B,Aa,Bb: LongInt;
Begin
 Aa:=Ord(Gx>0); Bb:=Ord(Gy>0);
 If Aa<>0 Then A:=Pl^[Gy*X4Mbw*2+Gx-1] Else A:=0;
 If Bb<>0 Then B:=Pl^[(Gy-1)*X4Mbw*2+Gx] Else B:=0;
 If (Aa<>0) And (Bb<>0) Then X4NcChroma:=(A+B+1) Shr 1 Else X4NcChroma:=A+B;
End;

Type X4Lum=Array[0..15] Of X4Arr;
Var
 X4LL: X4Lum; X4LNz: X4Arr; X4DcL: X4Arr; X4DcNz: LongInt;   { niveaux luma (AC
  par bloc), DC Intra16 }
 X4CL: Array[0..1,0..3] Of X4Arr; X4CNz: Array[0..1,0..3] Of LongInt; X4CDc:
  Array[0..1] Of X4Arr; X4CDcNz: Array[0..1] Of LongInt;
 X4DqL: X4Lum; X4DqC: Array[0..1,0..3] Of X4Arr;           { coefficients
  dequantifies }
 X4DcDq: X4Arr; X4CDcDq: Array[0..1] Of X4Arr;
 X4Mc: Array[0..255] Of LongInt; X4McC: Array[0..63] Of LongInt;
 X4Lamb: LongInt;

Function X4Plane(Base: PEABuffer; P: LongInt): PEABuffer;
Begin
 If P=0 Then X4Plane:=Base Else If P=1 Then X4Plane:=PEABuffer(@Base^[X4Wp*
  X4Hp]) Else X4Plane:=PEABuffer(@Base^[X4Wp*X4Hp+X4Cw*X4Ch]);
End;

{ Intra 16x16 : prediction dans Rec (mode), SAD vs source }
Function X4SadMb(Mx,My: LongInt): LongInt;
Begin
 X4SadMb:=X4Sad(PEABuffer(@X4Plane(X4Rec,0)^[My*16*X4Wp+Mx*16]),PEABuffer(
  @X4Plane(X4Src,0)^[My*16*X4Wp+Mx*16]),X4Wp,X4Wp,16,16);
End;
Procedure X4BestIntra(Mx,My: LongInt; Var BestMode,BestSad,BestCm,BestCsad:
 LongInt);
Var Mode,S,Sc: LongInt; AvL,AvT: Boolean;
Begin
 AvL:=Mx>0; AvT:=My>0;
 BestSad:=MaxLongInt; BestMode:=2;
 For Mode:=0 To 3 Do Begin
  If (Mode=0) And Not AvT Then Continue;
  If (Mode=1) And Not AvL Then Continue;
  If (Mode=3) And Not (AvL And AvT) Then Continue;
  H4Pred16x16(X4Plane(X4Rec,0),X4Wp,Mx*16,My*16,Mode,AvL,AvT);
  S:=X4SadMb(Mx,My);
  If S<BestSad Then Begin BestSad:=S; BestMode:=Mode; End;
 End;
 BestCsad:=MaxLongInt; BestCm:=0;
 For Mode:=0 To 3 Do Begin
  If (Mode=1) And Not AvL Then Continue;
  If (Mode=2) And Not AvT Then Continue;
  If (Mode=3) And Not (AvL And AvT) Then Continue;
  H4PredChroma(X4Plane(X4Rec,1),X4Cw,Mx*8,My*8,Mode,AvL,AvT);
  H4PredChroma(X4Plane(X4Rec,2),X4Cw,Mx*8,My*8,Mode,AvL,AvT);
  Sc:=X4Sad(PEABuffer(@X4Plane(X4Rec,1)^[My*8*X4Cw+Mx*8]),PEABuffer(@X4Plane(
   X4Src,1)^[My*8*X4Cw+Mx*8]),X4Cw,X4Cw,8,8)
     +X4Sad(PEABuffer(@X4Plane(X4Rec,2)^[My*8*X4Cw+Mx*8]),PEABuffer(@X4Plane(
      X4Src,2)^[My*8*X4Cw+Mx*8]),X4Cw,X4Cw,8,8);
  If Sc<BestCsad Then Begin BestCsad:=Sc; BestCm:=Mode; End;
 End;
End;

{ residu 4x4 en (Bx,By) d'un plan : source - Rec (qui contient la prediction) }
Procedure X4Resid(P: LongInt; Bw,X,Y: LongInt; Var R: X4Arr);
Var I,J,Stride: LongInt; S,D: PEABuffer;
Begin
 If P=0 Then Stride:=X4Wp Else Stride:=X4Cw;
 S:=X4Plane(X4Src,P); D:=X4Plane(X4Rec,P);
 For J:=0 To 3 Do For I:=0 To 3 Do R[J*4+I]:=S^[(Y+J)*Stride+X+I]-D^[(Y+J)*
  Stride+X+I];
End;

{ ---- luma Intra16x16 : niveaux ---- }
Procedure X4LumaI16(Mx,My: LongInt);
Var B,K,I,Gx,Gy,Qb,F,Dc: LongInt; R: X4Arr; M,H,T: X4Arr; Lev15: Array[0..14] Of
 LongInt; Tmp: Array[0..15] Of LongInt; Z: LongInt;
Begin
 Qb:=15+X4Qp Div 6; F:=(1 Shl Qb) Div 3;
 For B:=0 To 15 Do Begin
  Gx:=X4BlkX[B]; Gy:=X4BlkY[B];
  X4Resid(0,0,Mx*16+Gx*4,My*16+Gy*4,R);
  X4LNz[B]:=X4QuantBlock(R,X4Qp,True,1,Tmp,X4DqL[B],Dc);
  For K:=0 To 14 Do X4LL[B][K]:=Tmp[K];
  M[Gy*4+Gx]:=Dc;
 End;
 { Hadamard 4x4 des DC }
 For I:=0 To 3 Do Begin
  T[I*4]:=M[I*4]+M[I*4+1]+M[I*4+2]+M[I*4+3];
  T[I*4+1]:=M[I*4]+M[I*4+1]-M[I*4+2]-M[I*4+3];
  T[I*4+2]:=M[I*4]-M[I*4+1]-M[I*4+2]+M[I*4+3];
  T[I*4+3]:=M[I*4]-M[I*4+1]+M[I*4+2]-M[I*4+3];
 End;
 For I:=0 To 3 Do Begin
  H[I]:=T[I]+T[4+I]+T[8+I]+T[12+I];
  H[4+I]:=T[I]+T[4+I]-T[8+I]-T[12+I];
  H[8+I]:=T[I]-T[4+I]-T[8+I]+T[12+I];
  H[12+I]:=T[I]-T[4+I]+T[8+I]-T[12+I];
 End;
 X4DcNz:=0;
 For K:=0 To 15 Do Begin
  X4DcL[K]:=X4Q(H[X4Zig[K]],X4MF[X4Qp Mod 6,0],Qb+2,4*F);
  If X4DcL[K]<>0 Then Inc(X4DcNz);
 End;
End;

{ reconstruction luma Intra16x16 selon Ac (blocs AC codes ou non) }
Procedure X4ReconI16(Mx,My: LongInt; Ac: Boolean);
Var B,I,Gx,Gy,K: LongInt; C,T,G: X4Arr; Ls: LongInt;
Begin
 FillChar(C,SizeOf(C),0);
 For K:=0 To 15 Do C[X4Zig[K]]:=X4DcL[K];
 For I:=0 To 3 Do Begin
  T[I*4]:=C[I*4]+C[I*4+1]+C[I*4+2]+C[I*4+3];
  T[I*4+1]:=C[I*4]+C[I*4+1]-C[I*4+2]-C[I*4+3];
  T[I*4+2]:=C[I*4]-C[I*4+1]-C[I*4+2]+C[I*4+3];
  T[I*4+3]:=C[I*4]-C[I*4+1]+C[I*4+2]-C[I*4+3];
 End;
 For I:=0 To 3 Do Begin
  G[I]:=T[I]+T[4+I]+T[8+I]+T[12+I];
  G[4+I]:=T[I]+T[4+I]-T[8+I]-T[12+I];
  G[8+I]:=T[I]-T[4+I]-T[8+I]+T[12+I];
  G[12+I]:=T[I]-T[4+I]+T[8+I]-T[12+I];
 End;
 Ls:=16*X4V[X4Qp Mod 6,0];
 For I:=0 To 15 Do
  If X4Qp>=36 Then G[I]:=(G[I]*Ls) Shl (X4Qp Div 6-6) Else G[I]:=H4Sar(G[I]*Ls+(
   1 Shl (5-X4Qp Div 6)),6-X4Qp Div 6);
 For B:=0 To 15 Do Begin
  Gx:=X4BlkX[B]; Gy:=X4BlkY[B];
  If Not Ac Then FillChar(X4DqL[B],SizeOf(X4Arr),0);
  X4DqL[B][0]:=G[Gy*4+Gx];
  H4Idct4(X4DqL[B],X4Plane(X4Rec,0),X4Wp,Mx*16+Gx*4,My*16+Gy*4);
 End;
End;

{ ---- luma inter : niveaux (16 coefficients par bloc) ---- }
Procedure X4LumaInter(Mx,My: LongInt);
Var B,K,Gx,Gy,Dc: LongInt; R: X4Arr; Tmp: Array[0..15] Of LongInt;
Begin
 For B:=0 To 15 Do Begin
  Gx:=X4BlkX[B]; Gy:=X4BlkY[B];
  X4Resid(0,0,Mx*16+Gx*4,My*16+Gy*4,R);
  X4LNz[B]:=X4QuantBlock(R,X4Qp,False,0,Tmp,X4DqL[B],Dc);
  For K:=0 To 15 Do X4LL[B][K]:=Tmp[K];
 End;
End;

{ ---- chroma : niveaux ; Intra selon prediction deja dans Rec ---- }
Procedure X4Chroma(Mx,My: LongInt; Intra: Boolean);
Var P,B,K,Bx,By,Qpc,Qb,F: LongInt; R: X4Arr; Tmp: Array[0..15] Of LongInt; Dc:
 LongInt; D: Array[0..3] Of LongInt; Fq: Array[0..3] Of LongInt;
Begin
 Qpc:=H4ChromaQp(X4Qp,0); Qb:=15+Qpc Div 6;
 If Intra Then F:=(1 Shl Qb) Div 3 Else F:=(1 Shl Qb) Div 6;
 For P:=0 To 1 Do Begin
  For B:=0 To 3 Do Begin
   Bx:=B And 1; By:=B Shr 1;
   X4Resid(P+1,0,Mx*8+Bx*4,My*8+By*4,R);
   X4CNz[P,B]:=X4QuantBlock(R,Qpc,Intra,1,Tmp,X4DqC[P,B],Dc);
   For K:=0 To 14 Do X4CL[P,B][K]:=Tmp[K];
   D[B]:=Dc;
  End;
  Fq[0]:=D[0]+D[1]+D[2]+D[3]; Fq[1]:=D[0]-D[1]+D[2]-D[3]; Fq[2]:=D[0]+D[1]-D[2]-
   D[3]; Fq[3]:=D[0]-D[1]-D[2]+D[3];
  X4CDcNz[P]:=0;
  For K:=0 To 3 Do Begin
   X4CDc[P][K]:=X4Q(Fq[K],X4MF[Qpc Mod 6,0],Qb+1,2*F);
   If X4CDc[P][K]<>0 Then Inc(X4CDcNz[P]);
  End;
 End;
End;
{ reconstruction chroma : Mode 0 rien, 1 DC seulement, 2 DC + AC }
Procedure X4ReconChroma(Mx,My,Cbp: LongInt);
Var P,B,Bx,By,Qpc,Ls: LongInt; G: Array[0..3] Of LongInt; C: Array[0..3] Of
 LongInt;
Begin
 If Cbp=0 Then Exit;
 Qpc:=H4ChromaQp(X4Qp,0); Ls:=16*X4V[Qpc Mod 6,0];
 For P:=0 To 1 Do Begin
  C[0]:=X4CDc[P][0]; C[1]:=X4CDc[P][1]; C[2]:=X4CDc[P][2]; C[3]:=X4CDc[P][3];
  G[0]:=C[0]+C[1]+C[2]+C[3]; G[1]:=C[0]-C[1]+C[2]-C[3]; G[2]:=C[0]+C[1]-C[2]-C[
   3]; G[3]:=C[0]-C[1]-C[2]+C[3];
  For B:=0 To 3 Do Begin
   Bx:=B And 1; By:=B Shr 1;
   If Cbp<2 Then FillChar(X4DqC[P,B],SizeOf(X4Arr),0);
   X4DqC[P,B][0]:=H4Sar((G[B]*Ls) Shl (Qpc Div 6),5);
   H4Idct4(X4DqC[P,B],X4Plane(X4Rec,P+1),X4Cw,Mx*8+Bx*4,My*8+By*4);
  End;
 End;
End;

{ ---- ecriture des residus ---- }
Procedure X4Lz(Var A: Array Of LongInt; N: LongInt); Var I: LongInt; Begin For
 I:=0 To N-1 Do A[I]:=0; End;
Procedure X4WriteChroma(Mx,My,Cbp: LongInt);
Var P,B,Bx,By,Nc,Tot: LongInt; Lv: X4Arr; Dc: Array[0..3] Of LongInt; Pl:
 PEABuffer;
Begin
 If Cbp=0 Then Exit;
 For P:=0 To 1 Do Begin
  For B:=0 To 3 Do Dc[B]:=X4CDc[P][B];
  X4Block(Dc,4,-1);
 End;
 If Cbp<2 Then Exit;
 For P:=0 To 1 Do Begin
  If P=0 Then Pl:=X4NnzU Else Pl:=X4NnzV;
  For B:=0 To 3 Do Begin
   Bx:=B And 1; By:=B Shr 1;
   Nc:=X4NcChroma(Pl,Mx*2+Bx,My*2+By);
   Tot:=X4Block(X4CL[P,B],15,Nc);
   Pl^[(My*2+By)*X4Mbw*2+Mx*2+Bx]:=Tot;
  End;
 End;
End;


{ ---- sortie : tampon croissant, NAL, MP4 ---- }
Const
 X4CbpTab: Array[0..47] Of Byte=(0,16,1,2,4,8,32,3,5,10,12,15,47,7,11,13,14,6,9,
  31,35,37,42,44,33,34,36,40,39,43,45,46,17,18,20,24,19,21,26,28,23,27,29,30,22,
  25,38,41);
Var
 X4O: PEABuffer; X4OLen,X4OCap: LongInt;
 X4Nb: PEABuffer; X4NbLen: LongInt;
 X4SpsB,X4PpsB: Array[0..255] Of Byte; X4SpsLen,X4PpsLen: LongInt;
 X4Mp4: Boolean;
 X4Fn,X4Fd: LongInt;

Procedure X4OB(V: LongInt);
Begin
 If X4OLen>=X4OCap Then Begin X4OCap:=X4OCap*2; ReallocMem(Pointer(X4O),X4OCap);
  End;
 X4O^[X4OLen]:=V And 255; Inc(X4OLen);
End;
Procedure X4O32(V: LongInt); Begin X4OB(V Shr 24); X4OB(V Shr 16); X4OB(V Shr
 8); X4OB(V); End;
Procedure X4O16(V: LongInt); Begin X4OB(V Shr 8); X4OB(V); End;
Procedure X4OTag(Const S: String); Var I: LongInt; Begin For I:=1 To 4 Do X4OB(
 Ord(S[I])); End;
Procedure X4OPatch32(At,V: LongInt);
Begin X4O^[At]:=V Shr 24; X4O^[At+1]:=V Shr 16; X4O^[At+2]:=V Shr 8; X4O^[At+
 3]:=V; End;
{ ouvre une boite : renvoie la position de sa taille }
Function X4BoxB(Const Tag: String): LongInt;
Begin X4BoxB:=X4OLen; X4O32(0); X4OTag(Tag); End;
Procedure X4BoxE(At: LongInt); Begin X4OPatch32(At,X4OLen-At); End;

{ construit le NAL (en-tete + RBSP echappe) dans X4Nb a partir de X4Rb (arret
 deja ecrit) }
Procedure X4NalBuild(RefIdc,Typ: LongInt);
Var I,N,Z: LongInt;
Begin
 N:=X4RbBits Shr 3; X4NbLen:=0;
 X4Nb^[0]:=(RefIdc Shl 5) Or Typ; X4NbLen:=1; Z:=0;
 For I:=0 To N-1 Do Begin
  If (Z>=2) And (X4Rb^[I]<=3) Then Begin X4Nb^[X4NbLen]:=3; Inc(X4NbLen); Z:=0;
   End;
  X4Nb^[X4NbLen]:=X4Rb^[I]; Inc(X4NbLen);
  If X4Rb^[I]=0 Then Inc(Z) Else Z:=0;
 End;
End;
Procedure X4EmitNal;
Var I: LongInt;
Begin
 If X4Mp4 Then X4O32(X4NbLen) Else Begin X4OB(0); X4OB(0); X4OB(0); X4OB(1);
  End;
 For I:=0 To X4NbLen-1 Do X4OB(X4Nb^[I]);
End;

Procedure X4WriteSps(W,H,Crop: LongInt; Lvl: LongInt);
Var CropX,CropY: LongInt;
Begin
 FillChar(X4Rb^,512,0); X4RbBits:=0;
 X4Put(66,8); X4Put($C0,8); X4Put(Lvl,8);
 X4Ue(0);                         { sps_id }
 X4Ue(4);                         { log2_max_frame_num-4 : 8 bits }
 X4Ue(2);                         { pic_order_cnt_type }
 X4Ue(1);                         { num_ref_frames }
 X4Put(0,1);                      { gaps }
 X4Ue(X4Mbw-1); X4Ue(X4Mbh-1);
 X4Put(1,1);                      { frame_mbs_only }
 X4Put(1,1);                      { direct_8x8_inference }
 CropX:=(X4Wp-W) Div 2; CropY:=(X4Hp-H) Div 2;
 If (CropX>0) Or (CropY>0) Then Begin
  X4Put(1,1); X4Ue(0); X4Ue(CropX); X4Ue(0); X4Ue(CropY);
 End Else X4Put(0,1);
 X4Put(1,1);                      { vui_parameters_present }
 X4Put(0,1);                      { aspect_ratio_info_present }
 X4Put(0,1); X4Put(0,1);          { overscan, video_signal_type }
 X4Put(0,1);                      { chroma_loc }
 X4Put(1,1);                      { timing_info_present }
 X4Put(X4Fd,32); X4Put(Int64(X4Fn)*2,32); X4Put(1,1);
 X4Put(0,1); X4Put(0,1);          { nal_hrd, vcl_hrd }
 X4Put(0,1);                      { pic_struct_present }
 X4Put(1,1);                      { bitstream_restriction }
 X4Put(1,1);                      { motion_vectors_over_pic_boundaries }
 X4Ue(0); X4Ue(0);                { max_bytes_per_pic_denom,
  max_bits_per_mb_denom }
 X4Ue(16); X4Ue(16);              { log2_max_mv_length }
 X4Ue(0); X4Ue(1);                { num_reorder_frames, max_dec_frame_buffering
  }
 X4Trail;
 X4NalBuild(3,7);
 X4SpsLen:=X4NbLen; Move(X4Nb^[0],X4SpsB[0],X4NbLen);
End;
Procedure X4WritePps;
Begin
 FillChar(X4Rb^,64,0); X4RbBits:=0;
 X4Ue(0); X4Ue(0); X4Put(0,1); X4Put(0,1);
 X4Ue(0);                         { num_slice_groups-1 }
 X4Ue(0); X4Ue(0);                { num_ref_idx_default-1 }
 X4Put(0,1); X4Put(0,2);          { weighted_pred, weighted_bipred }
 X4Se(0); X4Se(0); X4Se(0);       { pic_init_qp-26, qs, chroma_qp_index_offset }
 X4Put(1,1);                      { deblocking_filter_control_present }
 X4Put(0,1); X4Put(0,1);          { constrained_intra_pred,
  redundant_pic_cnt_present }
 X4Trail;
 X4NalBuild(3,8);
 X4PpsLen:=X4NbLen; Move(X4Nb^[0],X4PpsB[0],X4NbLen);
End;

{ ---- macroblocs ---- }
Procedure X4ClearNnz(Mx,My: LongInt);
Var I,J: LongInt;
Begin
 For J:=0 To 3 Do For I:=0 To 3 Do X4NnzY^[(My*4+J)*X4Mbw*4+Mx*4+I]:=0;
 For J:=0 To 1 Do For I:=0 To 1 Do Begin
  X4NnzU^[(My*2+J)*X4Mbw*2+Mx*2+I]:=0; X4NnzV^[(My*2+J)*X4Mbw*2+Mx*2+I]:=0;
 End;
End;
Procedure X4SetInfo(Mx,My,Kind,Vx,Vy: LongInt);
Begin X4Kind^[My*X4Mbw+Mx]:=Kind; X4Mvx^[My*X4Mbw+Mx]:=Vx; X4Mvy^[My*X4Mbw+Mx]:=
 Vy; End;

Procedure X4MbIntra(Mx,My,Mode,Cm: LongInt);
Var Ac,CAc,CDc,AvL,AvT: Boolean; CbpC,B,P,Gx,Gy,Nc,Tot: LongInt;
Begin
 AvL:=Mx>0; AvT:=My>0;
 H4Pred16x16(X4Plane(X4Rec,0),X4Wp,Mx*16,My*16,Mode,AvL,AvT);
 H4PredChroma(X4Plane(X4Rec,1),X4Cw,Mx*8,My*8,Cm,AvL,AvT);
 H4PredChroma(X4Plane(X4Rec,2),X4Cw,Mx*8,My*8,Cm,AvL,AvT);
 X4LumaI16(Mx,My);
 Ac:=False; For B:=0 To 15 Do If X4LNz[B]>0 Then Ac:=True;
 X4Chroma(Mx,My,True);
 CAc:=False; CDc:=False;
 For P:=0 To 1 Do Begin
  If X4CDcNz[P]>0 Then CDc:=True;
  For B:=0 To 3 Do If X4CNz[P,B]>0 Then CAc:=True;
 End;
 If CAc Then CbpC:=2 Else If CDc Then CbpC:=1 Else CbpC:=0;
 X4ReconI16(Mx,My,Ac);
 X4ReconChroma(Mx,My,CbpC);
 If X4Inter Then Begin X4Ue(X4SkipRun); X4SkipRun:=0; End;
 X4ClearNnz(Mx,My);
 X4Ue(Ord(X4Inter)*5+1+Mode+4*CbpC+12*Ord(Ac));
 X4Ue(Cm); X4Se(0);
 X4Block(X4DcL,16,X4NcLuma(Mx*4,My*4));
 If Ac Then For B:=0 To 15 Do Begin
  Gx:=Mx*4+X4BlkX[B]; Gy:=My*4+X4BlkY[B];
  Nc:=X4NcLuma(Gx,Gy); Tot:=X4Block(X4LL[B],15,Nc);
  X4NnzY^[Gy*X4Mbw*4+Gx]:=Tot;
 End;
 X4WriteChroma(Mx,My,CbpC);
 X4SetInfo(Mx,My,0,0,0);
End;

Function X4Bits(V: LongInt): LongInt;
Var N: LongInt;
Begin
 If V<0 Then V:=-V;
 V:=2*V+1; N:=0; While V>1 Do Begin V:=V Shr 1; Inc(N); End;
 X4Bits:=2*N+1;
End;

{ SAD luma 16x16 a un vecteur au quart de pixel }
Function X4SadMv(Mx,My,Vx,Vy: LongInt): LongInt;
Var X,Y,Fx,Fy,I,J,S: LongInt; Sp,Rp: PEABuffer;
Begin
 X:=Mx*16+H4Sar(Vx,2); Y:=My*16+H4Sar(Vy,2); Fx:=Vx And 3; Fy:=Vy And 3;
 Sp:=X4Plane(X4Src,0); Rp:=X4Plane(X4Ref,0); S:=0;
 If (Fx=0) And (Fy=0) And (X>=0) And (Y>=0) And (X<=X4Wp-16) And (Y<=X4Hp-16)
  Then Begin
  For J:=0 To 15 Do For I:=0 To 15 Do Inc(S,Abs(Sp^[(My*16+J)*X4Wp+Mx*16+I]-Rp^[
   (Y+J)*X4Wp+X+I]));
 End Else Begin
  H4McLuma(Rp,X,Y,Fx,Fy,16,16,PLongArr(@X4Mc));
  For J:=0 To 15 Do For I:=0 To 15 Do Inc(S,Abs(Sp^[(My*16+J)*X4Wp+Mx*16+I]-
   X4Mc[J*16+I]));
 End;
 X4SadMv:=S;
End;

Procedure X4MbInter(Mx,My: LongInt; Const Mvp: Array Of LongInt; SkipOk:
 Boolean; Vx,Vy,SkX,SkY: LongInt);
Var X,Y,Fx,Fy,I,J,B,B8,P,Cbp,CbpL,CbpC,Gx,Gy,Nc,Tot,Sum,K: LongInt; CAc,CDc:
 Boolean; Rp,Dp: PEABuffer;
Begin
 X:=Mx*16+H4Sar(Vx,2); Y:=My*16+H4Sar(Vy,2); Fx:=Vx And 3; Fy:=Vy And 3;
 Dp:=X4Plane(X4Rec,0);
 H4McLuma(X4Plane(X4Ref,0),X,Y,Fx,Fy,16,16,PLongArr(@X4Mc));
 For J:=0 To 15 Do For I:=0 To 15 Do Dp^[(My*16+J)*X4Wp+Mx*16+I]:=X4Mc[J*16+I];
 X:=Mx*8+H4Sar(Vx,3); Y:=My*8+H4Sar(Vy,3); Fx:=Vx And 7; Fy:=Vy And 7;
 For P:=1 To 2 Do Begin
  H4McChroma(X4Plane(X4Ref,P),X,Y,Fx,Fy,8,8,PLongArr(@X4McC));
  Dp:=X4Plane(X4Rec,P);
  For J:=0 To 7 Do For I:=0 To 7 Do Dp^[(My*8+J)*X4Cw+Mx*8+I]:=X4McC[J*8+I];
 End;
 X4LumaInter(Mx,My);
 CbpL:=0;
 For B8:=0 To 3 Do Begin
  Sum:=0;
  For B:=B8*4 To B8*4+3 Do For K:=0 To 15 Do Sum:=Sum+Abs(X4LL[B][K]);
  { elimination des groupes dont le residu est negligeable }
  If Sum<=2 Then Begin
   For B:=B8*4 To B8*4+3 Do Begin X4LNz[B]:=0; FillChar(X4DqL[B],SizeOf(X4Arr),
    0); FillChar(X4LL[B],SizeOf(X4Arr),0); End;
  End Else
   CbpL:=CbpL Or (1 Shl B8);
 End;
 For B:=0 To 15 Do H4Idct4(X4DqL[B],X4Plane(X4Rec,0),X4Wp,Mx*16+X4BlkX[B]*4,My*
  16+X4BlkY[B]*4);
 X4Chroma(Mx,My,False);
 CAc:=False; CDc:=False;
 For P:=0 To 1 Do Begin
  If X4CDcNz[P]>0 Then CDc:=True;
  For B:=0 To 3 Do If X4CNz[P,B]>0 Then CAc:=True;
 End;
 { chroma negligeable : un seul coefficient +-1 }
 If CAc Then CbpC:=2 Else If CDc Then CbpC:=1 Else CbpC:=0;
 X4ReconChroma(Mx,My,CbpC);
 Cbp:=CbpL Or (CbpC Shl 4);
 X4ClearNnz(Mx,My);
 If SkipOk And (Cbp=0) And (Vx=SkX) And (Vy=SkY) Then Begin
  Inc(X4SkipRun); X4SetInfo(Mx,My,2,Vx,Vy); Exit;
 End;
 X4Ue(X4SkipRun); X4SkipRun:=0;
 X4Ue(0);
 X4Se(Vx-Mvp[0]); X4Se(Vy-Mvp[1]);
 X4Ue(X4CbpInv[Cbp]);
 If Cbp<>0 Then Begin
  X4Se(0);
  For B8:=0 To 3 Do If (CbpL And (1 Shl B8))<>0 Then
   For B:=B8*4 To B8*4+3 Do Begin
    Gx:=Mx*4+X4BlkX[B]; Gy:=My*4+X4BlkY[B];
    Nc:=X4NcLuma(Gx,Gy); Tot:=X4Block(X4LL[B],16,Nc);
    X4NnzY^[Gy*X4Mbw*4+Gx]:=Tot;
   End;
  X4WriteChroma(Mx,My,CbpC);
 End;
 X4SetInfo(Mx,My,1,Vx,Vy);
End;

{ ---- image ---- }
Function X4EncodeFrame(Idr: Boolean; FrameNum,Qp: LongInt): LongInt;
Var
 Mx,My,Mode,Cm,IS1,IS2,Cs,Best,Bx,By,Px,Py,Vx,Vy,Sx,Sy,It,Dx,Dy,C0,Bc,Si,Pmx,
  Pmy: LongInt;
 AvA,AvB: Boolean; RA,RB,Ax,Ay,Bx2,By2: LongInt; Mvp: Array[0..1] Of LongInt;
  Improved: Boolean; BestSad,IntraCost,InterCost,SkipCost: LongInt;
 Cand: Array[0..4,0..1] Of LongInt; Ci: LongInt;
 Function Cost(Ex,Ey: LongInt): LongInt;
 Begin Cost:=X4SadMv(Mx,My,Ex,Ey)+X4Lam*(X4Bits(Ex-Mvp[0])+X4Bits(Ey-Mvp[1]));
  End;
 Function Inside(Ex,Ey: LongInt): Boolean;
 Var Xp,Yp: LongInt;
 Begin
  Xp:=Mx*16+H4Sar(Ex,2); Yp:=My*16+H4Sar(Ey,2);
  Inside:=(Xp>=-8) And (Yp>=-8) And (Xp<=X4Wp-8) And (Yp<=X4Hp-8) And (Abs(
   Ex)<=128) And (Abs(Ey)<=128);
 End;
Begin
 X4Qp:=Qp; X4Inter:=Not Idr;
 X4Lam:=Round(Exp(Ln(2)*(Qp-12)/6)); If X4Lam<1 Then X4Lam:=1;
 FillChar(X4Rb^,X4Wp*X4Hp*3 Div 2*4+4096,0); X4RbBits:=0;
 H4MbW:=X4Mbw; H4MbH:=X4Mbh;
 { en-tete de tranche }
 X4Ue(0); If Idr Then X4Ue(7) Else X4Ue(5); X4Ue(0); X4Put(FrameNum And 255,8);
 If Idr Then X4Ue(0) Else Begin X4Put(0,1); X4Put(0,1); End;
 If Idr Then Begin X4Put(0,1); X4Put(0,1); End Else X4Put(0,1);
 X4Se(Qp-26); X4Ue(1);
 X4SkipRun:=0;
 FillChar(X4NnzY^,X4Mbw*X4Mbh*16,0); FillChar(X4NnzU^,X4Mbw*X4Mbh*4,0);
  FillChar(X4NnzV^,X4Mbw*X4Mbh*4,0);
 For My:=0 To X4Mbh-1 Do For Mx:=0 To X4Mbw-1 Do Begin
  X4BestIntra(Mx,My,Mode,IS1,Cm,IS2);
  IntraCost:=IS1+IS2 Div 2;
  If Idr Then Begin X4MbIntra(Mx,My,Mode,Cm); Continue; End;
  X4Mvp(Mx,My,Px,Py,AvA,AvB,RA,RB,Ax,Ay,Bx2,By2);
  Mvp[0]:=Px; Mvp[1]:=Py;
  { vecteur du saut }
  If (Not AvA) Or (Not AvB) Or ((RA=0) And (Ax=0) And (Ay=0)) Or ((RB=0) And (
   Bx2=0) And (By2=0)) Then Begin Sx:=0; Sy:=0; End Else Begin Sx:=Px; Sy:=Py;
   End;
  { recherche entiere }
  Cand[0,0]:=0; Cand[0,1]:=0;
  Cand[1,0]:=(Px+2) And Not 3; Cand[1,1]:=(Py+2) And Not 3;
  Cand[2,0]:=(Sx+2) And Not 3; Cand[2,1]:=(Sy+2) And Not 3;
  If Mx>0 Then Begin Cand[3,0]:=(X4Mvx^[My*X4Mbw+Mx-1]+2) And Not 3; Cand[3,1]:=
   (X4Mvy^[My*X4Mbw+Mx-1]+2) And Not 3; End Else Begin Cand[3,0]:=0; Cand[3,1]:=
   0; End;
  If My>0 Then Begin Cand[4,0]:=(X4Mvx^[(My-1)*X4Mbw+Mx]+2) And Not 3; Cand[4,
   1]:=(X4Mvy^[(My-1)*X4Mbw+Mx]+2) And Not 3; End Else Begin Cand[4,0]:=0; Cand[
   4,1]:=0; End;
  Vx:=0; Vy:=0; Bc:=MaxLongInt;
  For Ci:=0 To 4 Do If Inside(Cand[Ci,0],Cand[Ci,1]) Then Begin
   C0:=Cost(Cand[Ci,0],Cand[Ci,1]);
   If C0<Bc Then Begin Bc:=C0; Vx:=Cand[Ci,0]; Vy:=Cand[Ci,1]; End;
  End;
  For It:=1 To 48 Do Begin
   Improved:=False; Bx:=Vx; By:=Vy;
   For Si:=0 To 3 Do Begin
    Case Si Of 0: Begin Dx:=4; Dy:=0; End; 1: Begin Dx:=-4; Dy:=0; End; 2: Begin
     Dx:=0; Dy:=4; End; Else Begin Dx:=0; Dy:=-4; End; End;
    If Inside(Vx+Dx,Vy+Dy) Then Begin
     C0:=Cost(Vx+Dx,Vy+Dy);
     If C0<Bc Then Begin Bc:=C0; Bx:=Vx+Dx; By:=Vy+Dy; Improved:=True; End;
    End;
   End;
   Vx:=Bx; Vy:=By;
   If Not Improved Then Break;
  End;
  { demi puis quart de pixel }
  For It:=0 To 1 Do Begin
   Bx:=Vx; By:=Vy; Dx:=2 Shr It;
   For Si:=0 To 7 Do Begin
    Case Si Of 0: Begin Sx:=Dx; Sy:=0; End; 1: Begin Sx:=-Dx; Sy:=0; End; 2:
     Begin Sx:=0; Sy:=Dx; End; 3: Begin Sx:=0; Sy:=-Dx; End;
     4: Begin Sx:=Dx; Sy:=Dx; End; 5: Begin Sx:=-Dx; Sy:=Dx; End; 6: Begin Sx:=
      Dx; Sy:=-Dx; End; Else Begin Sx:=-Dx; Sy:=-Dx; End; End;
    If Inside(Vx+Sx,Vy+Sy) Then Begin
     C0:=Cost(Vx+Sx,Vy+Sy);
     If C0<Bc Then Begin Bc:=C0; Bx:=Vx+Sx; By:=Vy+Sy; End;
    End;
   End;
   Vx:=Bx; Vy:=By;
  End;
  { vecteur du saut recalcule (Sx,Sy ont ete reutilises) }
  If (Not AvA) Or (Not AvB) Or ((RA=0) And (Ax=0) And (Ay=0)) Or ((RB=0) And (
   Bx2=0) And (By2=0)) Then Begin Sx:=0; Sy:=0; End Else Begin Sx:=Px; Sy:=Py;
   End;
  InterCost:=Bc;
  If Inside(Sx,Sy) Then Begin
   SkipCost:=X4SadMv(Mx,My,Sx,Sy);
   If SkipCost<=Bc Then Begin Vx:=Sx; Vy:=Sy; InterCost:=SkipCost; End;
  End;
  If IntraCost+4*X4Lam*6<InterCost Then X4MbIntra(Mx,My,Mode,Cm)
  Else X4MbInter(Mx,My,Mvp,True,Vx,Vy,Sx,Sy);
 End;
 If X4SkipRun>0 Then Begin X4Ue(X4SkipRun); X4SkipRun:=0; End;
 X4Trail;
 X4EncodeFrame:=X4RbBits;
End;

{ ---- MP4 ---- }
Var X4SampSz,X4SampOff: PLongArr; X4SampKey: PEABuffer;
Procedure X4WriteMoov(W,H,N,Lvl: LongInt);
Const Hn: String='VideoHandler';
Var Moov,Trak,Mdia,Minf,Stbl,Stsd,Avc1,AvcC,B,I,Dur,KeyCount: LongInt;
Begin
 Dur:=N*X4Fd;
 Moov:=X4BoxB('moov');
 B:=X4BoxB('mvhd'); X4O32(0); X4O32(0); X4O32(0); X4O32(X4Fn); X4O32(Dur);
  X4O32($10000); X4O16($100); X4O16(0); X4O32(0); X4O32(0);
 X4O32($10000); X4O32(0); X4O32(0); X4O32(0); X4O32($10000); X4O32(0); X4O32(0);
  X4O32(0); X4O32($40000000);
 For I:=1 To 6 Do X4O32(0);
 X4O32(2); X4BoxE(B);
 Trak:=X4BoxB('trak');
 B:=X4BoxB('tkhd'); X4O32(3); X4O32(0); X4O32(0); X4O32(1); X4O32(0); X4O32(
  Dur); X4O32(0); X4O32(0); X4O16(0); X4O16(0); X4O16(0); X4O16(0);
 X4O32($10000); X4O32(0); X4O32(0); X4O32(0); X4O32($10000); X4O32(0); X4O32(0);
  X4O32(0); X4O32($40000000);
 X4O32(W Shl 16); X4O32(H Shl 16); X4BoxE(B);
 Mdia:=X4BoxB('mdia');
 B:=X4BoxB('mdhd'); X4O32(0); X4O32(0); X4O32(0); X4O32(X4Fn); X4O32(Dur);
  X4O16($55C4); X4O16(0); X4BoxE(B);
 B:=X4BoxB('hdlr'); X4O32(0); X4O32(0); X4OTag('vide'); X4O32(0); X4O32(0);
  X4O32(0);
 For I:=1 To 12 Do X4OB(Ord(Hn[I])); X4OB(0); X4BoxE(B);
 Minf:=X4BoxB('minf');
 B:=X4BoxB('vmhd'); X4O32(1); X4O32(0); X4O32(0); X4BoxE(B);
 B:=X4BoxB('dinf'); I:=X4BoxB('dref'); X4O32(0); X4O32(1); Stbl:=X4BoxB('url ');
  X4O32(1); X4BoxE(Stbl); X4BoxE(I); X4BoxE(B);
 Stbl:=X4BoxB('stbl');
 Stsd:=X4BoxB('stsd'); X4O32(0); X4O32(1);
 Avc1:=X4BoxB('avc1'); X4O32(0); X4O16(0); X4O16(1); X4O32(0); X4O32(0); X4O32(
  0); X4O32(0);
 X4O16(W); X4O16(H); X4O32($480000); X4O32($480000); X4O32(0); X4O16(1);
 For I:=1 To 32 Do X4OB(0);
 X4O16($18); X4O16($FFFF);
 AvcC:=X4BoxB('avcC'); X4OB(1); X4OB(66); X4OB($C0); X4OB(Lvl); X4OB($FF); X4OB(
  $E1);
 X4O16(X4SpsLen); For I:=0 To X4SpsLen-1 Do X4OB(X4SpsB[I]);
 X4OB(1); X4O16(X4PpsLen); For I:=0 To X4PpsLen-1 Do X4OB(X4PpsB[I]);
 X4BoxE(AvcC); X4BoxE(Avc1); X4BoxE(Stsd);
 B:=X4BoxB('stts'); X4O32(0); X4O32(1); X4O32(N); X4O32(X4Fd); X4BoxE(B);
 KeyCount:=0; For I:=0 To N-1 Do If X4SampKey^[I]<>0 Then Inc(KeyCount);
 B:=X4BoxB('stss'); X4O32(0); X4O32(KeyCount); For I:=0 To N-1 Do If X4SampKey^[
  I]<>0 Then X4O32(I+1); X4BoxE(B);
 B:=X4BoxB('stsc'); X4O32(0); X4O32(1); X4O32(1); X4O32(1); X4O32(1); X4BoxE(B);
 B:=X4BoxB('stsz'); X4O32(0); X4O32(0); X4O32(N); For I:=0 To N-1 Do X4O32(
  X4SampSz^[I]); X4BoxE(B);
 B:=X4BoxB('stco'); X4O32(0); X4O32(N); For I:=0 To N-1 Do X4O32(X4SampOff^[I]);
  X4BoxE(B);
 X4BoxE(Stbl); X4BoxE(Minf); X4BoxE(Mdia); X4BoxE(Trak); X4BoxE(Moov);
End;

{ ---- programme principal de l'encodeur ---- }
{ ---- Encodeur AAC-LC (libfaac) : tables Huffman et bandes issues de aactab.c
 de FFmpeg (LGPL-2.1-or-later) ---- }
Const
 AERoots:Array[0..11] Of Integer=(
 0,120,200,280,360,440,520,600,663,726,894,1062);

 AEHuffLeft:Array[0..1349] Of Integer=(
 -61,92,90,87,83,79,74,72,67,62,56,52,44,14,18,16,17,-1,42,21,
 -2,-20,29,24,27,26,-120,28,-11,110,113,32,-119,-8,-9,39,37,-12,-15,40,
 -17,-21,-24,-91,49,48,-89,-26,-29,51,-27,-87,55,97,-31,-85,60,58,-86,-37,
 -84,-38,66,65,-83,-82,-81,70,71,-43,-46,-45,73,-75,78,77,-74,-73,-50,82,
 -52,-71,-53,86,-68,-54,-67,89,-56,-57,-63,-58,-60,-62,95,-77,-78,-88,99,100,
 -98,-93,103,-95,-97,-99,107,-101,-103,-104,116,119,-111,114,-107,-109,117,-112,
  -114,-116,
 -41,158,139,153,148,131,136,145,129,130,-1,132,133,-22,135,-19,143,138,-12,172,
 141,142,-5,144,-6,170,152,-73,167,162,151,-8,-81,154,194,-11,157,-13,159,160,
 -68,-15,192,-26,165,-17,-18,168,169,-74,171,-61,173,174,-59,199,-24,-25,-63,-
  28,
 189,-44,-71,187,-34,186,-35,-48,-77,-42,-39,-40,-66,-65,-53,-62,-55,-60,-76,-
  70,
 238,220,209,216,229,206,207,-21,-57,246,257,261,-16,227,215,-55,235,218,226,-6,
 221,222,237,-65,256,-81,-8,245,-9,230,255,-10,242,234,-31,236,-12,-13,239,-41,
 -68,-14,244,-29,-17,-63,273,275,-20,-74,-60,262,253,-50,-35,-54,-25,278,-72,
  260,
 -28,-30,269,-32,268,-69,267,-58,-37,-38,272,-49,-47,-45,-64,-48,-77,-78,-62,-
  75,
 -1,282,283,-28,291,286,332,335,-38,-55,-10,292,-37,294,295,296,-6,298,312,-67,
 -49,-8,314,304,305,336,-9,308,-13,313,-19,-31,-46,-22,324,337,317,-35,328,326,
 330,322,-54,-21,347,-23,327,-25,329,-26,331,-27,-29,349,-30,-41,-65,-44,-47,
  340,
 -36,342,-39,-68,-45,346,-48,-58,-71,-76,-73,357,354,-57,-72,-62,-75,-66,-70,-
  81,
 361,392,414,-37,365,376,391,-2,374,377,371,382,415,-3,375,-4,-5,394,416,390,
 -22,-19,397,-30,408,398,405,388,389,-9,-56,-29,393,-41,395,-17,-15,-16,399,400,
 -18,-21,403,-23,-24,435,439,-25,426,432,433,-70,413,-81,-32,-34,417,-35,419,-
  36,
 -38,-47,423,425,-50,-68,434,-71,-58,-48,438,-49,-51,-52,-53,-66,-79,-75,-67,-
  72,
 -41,508,506,493,478,474,459,456,453,468,471,470,-81,467,490,-64,472,458,-3,463,
 461,462,-4,464,-37,513,-6,-71,469,-8,-73,-74,473,-65,491,476,477,-12,482,480,
 481,-13,483,-14,485,-15,518,-16,-17,-18,-19,501,-21,497,495,496,-22,498,-23,
  500,
 -24,-25,-26,-76,-69,-30,510,-31,509,-32,-49,-34,-47,-54,-38,-59,-42,-55,-70,-
  78,
 580,567,552,548,535,532,542,597,531,541,-1,-8,533,534,-7,545,537,576,-6,540,
 -5,-81,594,-45,-10,560,547,-65,556,550,-70,-12,565,558,555,-13,557,-68,559,-15,
 -16,-17,-63,596,-56,574,-21,568,-31,595,-24,572,573,-23,-57,-75,-28,-47,588,-
  30,
 589,582,-32,-33,-67,593,-36,-38,-52,591,-40,-41,-59,-54,-77,-58,-62,598,-64,-
  72,
 -1,602,-9,604,-10,628,-17,608,629,610,-4,612,613,639,-5,616,640,-43,619,641,
 636,622,-31,643,625,650,-32,-57,-18,630,-26,632,-13,-14,654,-15,-51,-19,-20,-
  28,
 -35,646,-44,648,645,-52,-30,-49,649,-58,-46,652,656,-61,-50,-59,-54,658,-48,-
  60,
 661,-63,-56,664,692,668,-19,-1,-11,670,671,672,-3,674,675,676,-4,698,714,-45,
 700,682,683,684,-53,703,687,720,-7,725,722,-8,-10,-18,-12,705,697,-13,707,-14,
 708,702,-50,704,-16,-20,-21,-42,718,-23,711,-59,-28,-29,-30,716,-31,-32,-38,-
  39,
 -49,-46,-48,-54,-55,-63,-1,728,-14,730,-15,779,-27,734,735,800,-17,-40,780,782,
 816,-5,743,744,783,838,-56,-6,785,750,751,-93,753,754,789,756,757,-8,759,-47,
 761,762,809,764,765,-10,797,820,769,-148,812,772,773,836,775,-12,847,778,-13,-
  28,
 801,-18,-31,802,-20,786,787,-66,-45,790,-23,806,793,794,-24,832,-111,843,799,-
  38,
 -41,-30,-67,804,-46,-107,807,808,-36,845,-110,-134,813,833,815,-39,-55,-48,831,
  -49,
 821,-50,823,853,-51,826,867,-162,829,-106,-58,-61,-158,881,-63,-125,837,-137,-
  68,-69,
 841,-79,-84,878,-73,-74,-101,848,-138,-82,-132,-122,-86,-144,-89,856,857,869,-
  164,876,
 -104,-105,863,-95,-98,866,-149,-113,-102,-139,-121,-114,873,874,875,-115,-116,-
  117,-123,880,
 -129,-131,883,884,-141,-142,893,888,-143,-159,-161,-165,-156,-167,900,896,897,
  898,953,-1,
 949,902,903,-2,980,906,-27,996,-4,954,983,1005,-80,914,957,916,917,1015,-93,
  920,
 921,1018,1029,999,-36,926,969,928,929,930,-8,1023,-149,934,1002,1037,937,-158,
  976,940,
 941,942,-11,1060,-12,1048,1053,948,-168,952,-28,-29,-15,-18,982,956,-19,958,
  959,-20,
 961,-106,988,964,-22,966,1009,968,-23,1011,1043,972,-137,993,1013,-25,977,995,-
  115,-128,
 -30,-31,-32,1006,-81,1007,987,-47,989,-60,1021,992,-37,994,-148,-163,-44,-42,-
  69,-49,
 -50,-136,1024,1058,-162,-82,-70,-59,-109,1045,-62,1035,-63,-138,-65,-95,-71,-
  72,1019,-73,
 -74,1042,-75,-76,1051,-150,1027,1059,-103,1030,-120,-84,-85,-98,-87,-88,-102,
  1038,-90,1040,
 -91,-108,-100,-146,-101,-111,-112,-116,1052,-157,-145,-126,-129,1057,-130,-139,
  -144,-166,-161,-152,
 -153,-167,1063,1064,1065,-1,1133,-2,1134,1070,1071,-38,1178,1074,-52,1076,1077,
  1140,1143,1231,
 1081,-5,1083,1084,1085,1237,1264,-6,1089,1090,1253,1155,-174,1094,1095,1129,
  1097,1098,1099,-8,
 1101,1102,1103,1104,1163,-9,1226,1298,1283,-154,1172,1112,1113,1315,1314,-11,
  1117,1118,1331,-222,
 1333,1122,-254,-15,1322,1126,-14,1346,-16,1197,1307,1279,-17,-289,1135,-20,
  1137,-21,-55,-70,
 1141,1180,-23,1144,1212,-24,1147,1184,1274,1285,-34,1152,1153,1154,-221,-128,
  1157,1292,1159,-191,
 1266,1336,-29,-30,1165,1166,1167,1223,-31,1208,1171,-260,1271,1174,1284,1329,-
  33,-54,1179,-71,
 -40,1211,1233,-41,1185,1348,-281,1234,1189,1190,-43,1192,1193,-127,1241,1196,-
  45,1198,-225,1200,
 1201,1202,-196,1335,-48,1258,1328,-49,1270,-50,-72,-57,-106,1214,-122,1289,-60,
  1252,-61,-62,
 1221,1222,-129,-189,1225,-131,1295,1228,-101,1230,-68,1261,-69,-74,1235,1236,-
  76,1332,-125,1305,
 -78,1304,-159,1244,-80,1246,1247,-243,-165,-87,-91,-108,-94,1260,-95,-96,-273,-
  98,1310,-180,
 -103,-107,1303,-109,-110,-224,1267,-147,1269,-116,-206,1311,1319,-215,1275,-
  119,-120,-123,-124,-130,
 1281,-132,-133,-257,-135,-282,1337,-211,-138,-140,-141,-143,1293,-175,-258,
  1297,-231,-246,1338,-263,
 1320,1302,-200,-153,-173,-157,-176,-193,-192,-163,-164,1312,-167,-168,-216,
  1340,-249,-179,-182,-184,
 1321,-185,1325,-186,-187,-188,-194,-195,-197,-199,-232,-203,-287,1345,-237,-
  226,-241,-210,-213,-214,
 -218,1344,-269,-250,-236,-239,-270,-266,-280,-276);

 AEHuffRight:Array[0..1349] Of Integer=(
 1,2,3,4,5,6,7,8,9,10,11,12,13,22,15,98,106,105,19,20,
 -3,-4,23,35,25,33,-5,109,-6,30,31,34,-7,-16,-10,36,38,-13,-14,41,
 -19,-18,43,-22,45,46,47,-23,-25,50,-28,-30,53,54,-32,-33,57,59,-34,-35,
 61,-36,63,64,-39,-40,-41,68,69,-42,-44,-80,94,-47,75,76,-48,-49,-72,80,
 81,-51,-70,84,85,-69,-55,88,-66,-65,91,-64,93,-59,96,-76,-79,-90,102,101,
 -92,-94,104,-96,-105,-100,108,-102,-118,-121,111,112,-106,115,-108,-110,118,-
  113,-115,-117,
 121,122,123,124,125,126,127,128,134,178,-75,175,179,-2,196,-3,137,166,-4,140,
 164,193,-29,198,-10,146,147,-7,149,150,197,-30,-9,156,155,-69,161,-67,180,191,
 -14,-31,163,-16,182,-45,-72,183,195,-20,177,-21,185,190,-23,176,-80,-57,-27,-
  54,
 181,-32,-33,184,-56,188,-43,-36,-37,-38,-47,-50,-46,-49,-51,-52,-79,-58,-64,-
  78,
 201,202,203,204,205,213,224,208,-1,210,211,212,-2,214,279,-3,217,259,219,-4,
 232,264,223,-5,225,-7,-18,228,-73,266,231,-52,233,276,-11,249,-56,-59,251,240,
 241,-42,243,-15,-51,-19,247,248,-34,250,-22,252,270,254,-23,-24,-27,258,-26,
  274,
 -70,-80,263,-44,265,-33,277,-36,-71,-40,271,-39,-43,-67,-46,-66,-53,-61,-76,-
  79,
 281,284,290,-2,285,293,287,288,289,-3,-4,307,-5,302,297,300,-64,309,299,-7,
 301,-17,303,318,333,306,-18,311,-11,310,-12,-14,-15,-16,315,316,343,-20,319,
  320,
 321,345,323,-61,325,-43,339,-24,341,350,348,-80,-40,334,-56,-32,-33,338,-34,
  358,
 -74,344,-59,-42,-77,351,355,-50,-51,-52,-53,352,353,356,-60,-69,-63,359,-79,-
  78,
 364,362,363,-1,368,366,367,-11,369,370,384,372,373,381,422,-10,-31,378,379,380,
 -6,-7,383,-8,385,386,387,412,401,-61,-12,-13,420,-14,402,396,-43,-20,418,404,
 -74,-57,421,-33,-62,406,407,-73,409,410,411,-26,436,-27,-28,-55,428,-64,429,-
  80,
 -40,-39,430,424,-42,-44,427,-45,-46,-60,431,-59,-69,-76,-77,-54,437,-63,-65,-
  78,
 441,442,443,444,445,446,447,448,449,450,451,452,-1,454,455,-2,457,517,-79,460,
 465,503,-45,519,-5,466,-46,-7,489,-72,-9,-10,488,-11,475,486,502,-66,479,484,
 504,-53,514,-68,512,-67,487,-20,-27,-80,-75,492,-57,494,499,505,-60,515,-43,
  511,
 -58,-61,-56,-28,-29,-52,507,-51,516,-50,-33,-48,-35,-36,-44,-39,-40,-63,-62,-
  77,
 521,522,523,524,525,526,527,528,529,530,-73,-2,539,562,-3,536,585,538,-4,575,
 -79,-9,543,544,-18,546,561,-11,549,563,551,-26,553,554,577,-53,587,-14,584,-69,
 -71,-46,-19,564,-20,566,-61,571,569,570,-22,578,592,-34,-25,-27,-78,-29,579,-
  43,
 581,583,-51,-49,-35,586,-37,-44,-39,590,-42,-50,-48,-76,-55,-60,-66,599,-74,-
  80,
 601,603,-2,607,605,606,-3,611,609,631,638,618,615,614,-33,634,617,-6,623,620,
 621,647,-7,624,651,626,627,-8,-11,637,-12,633,-34,-42,635,-36,-16,-25,-27,-21,
 -22,642,-23,644,659,-24,-29,-37,655,-38,-39,657,653,-40,-41,-45,-47,660,-62,-
  53,
 662,-55,-64,669,665,666,667,-17,-2,673,695,694,-26,680,677,713,-36,678,679,-5,
 681,685,710,719,-6,686,689,688,-62,690,691,-64,693,-9,-27,696,706,-35,699,-44,
 701,715,-15,717,-47,712,-25,-22,709,-51,723,-24,-34,-43,-37,721,-52,724,-33,-
  58,
 -40,-41,-57,-60,-61,-56,727,729,-2,733,731,732,-3,742,738,736,737,-4,739,740,
 741,-53,752,748,745,746,747,-33,749,803,805,-7,760,791,755,758,817,-120,850,-9,
 770,766,763,795,851,-146,767,768,864,-11,771,855,776,774,854,-163,777,871,-151,
  -16,
 781,-54,-19,784,-44,828,788,-21,-22,840,-94,792,818,842,-96,796,-25,798,889,-
  26,
 -29,-42,-32,830,-34,-35,862,861,-71,810,811,-37,822,814,835,-124,-43,-59,819,-
  145,
 852,-75,825,824,-76,865,827,-52,839,-57,-119,-60,-62,834,-87,-64,846,-65,-80,-
  81,
 849,-70,-72,844,-97,-118,-77,868,-78,-108,-83,-85,-112,-88,-157,872,859,858,-
  90,860,
 -91,-92,870,-133,-160,890,-99,-100,-126,-103,-109,-127,882,879,877,-140,-152,-
  128,-135,885,
 -130,-136,886,891,-153,-166,887,892,-155,-147,-150,-154,-169,-168,895,913,909,
  907,899,-56,
 901,904,997,-17,905,981,-3,908,-57,910,911,912,-5,919,915,962,960,918,-6,925,
 965,922,923,924,-7,933,927,973,931,1001,-113,932,-9,938,935,936,1014,-10,939,
  945,
 943,1056,-104,944,-155,946,947,1061,-13,950,951,-14,-16,-54,955,998,-67,985,
  1016,-46,
 1041,-21,963,1008,-48,990,967,1046,-99,970,971,1050,-24,974,975,-159,1026,978,
  979,-26,
 -43,-55,-68,984,-33,986,1017,-34,1032,-35,991,1000,-132,1036,-38,-39,-40,-41,-
  45,-119,
 -124,-51,1003,1004,-52,-53,-58,1031,-61,1010,-133,1012,-92,-64,-127,-66,-83,-
  107,1020,-110,
 1033,1022,-135,-114,1025,-77,1039,1028,-78,1034,-79,-94,-97,-86,-121,-105,-89,
  1055,-118,1047,
 -140,-96,-134,1044,-147,-122,-123,-165,1049,-117,-125,-160,-142,1054,-156,-131,
  -141,-143,-151,-164,
 -154,-169,1075,1068,1066,-19,1067,-36,1069,1072,1138,-3,1073,1249,-4,1082,1146,
  1078,1079,1080,
 1250,-51,1093,1088,1151,1086,1087,1290,1156,1194,1091,1092,-7,1100,1164,1096,
  1160,1203,1326,-65,
 1110,1106,1169,1280,1105,-229,1107,1108,1109,-10,1111,1116,1124,1114,1115,-217,
  1120,1341,1119,-12,
 1121,1127,1123,-13,1125,1347,-251,1128,-271,1130,1131,1132,-82,-18,1136,-37,
  1177,-53,1139,-22,
 1181,1142,-89,1229,1145,-85,1187,1148,1149,1150,-25,1191,1217,1288,-26,-27,
  1220,1158,1276,-28,
 1161,1162,-81,-230,1199,1245,1224,1168,-207,1170,1248,-32,1173,1300,1175,1176,-
  183,-35,1210,-39,
 -73,1182,1183,-104,1213,1186,-42,1188,1215,1324,-93,1239,1291,-44,1195,1219,-
  160,1256,-46,1205,
 1268,1309,-47,1204,-227,1206,1207,-115,1209,-261,-56,-90,-58,1251,-59,1216,-86,
  1218,-142,-112,
 1243,1255,-63,-64,1257,-66,1227,1318,-67,1349,-278,1232,-75,-105,1262,1278,-
  284,1238,-77,1240,
 -111,1242,-79,1265,-190,1286,1327,-83,-84,-88,-102,-92,-238,1254,-144,-172,-97,
  -99,1259,-100,
 -158,-279,1263,-170,-126,-113,1317,-114,1294,-181,-117,1272,1273,-118,1277,-
  283,-177,-121,-285,-146,
 1282,-212,-259,-134,1313,-136,1287,-137,-255,-139,-288,-156,1306,-145,-148,
  1296,-149,-150,1299,-151,
 1301,1343,-152,-274,-155,-272,-161,1308,-162,-244,-245,1339,-166,-264,-169,
  1316,-171,-178,-198,-248,
 1330,-233,1323,-235,-286,-219,-223,-242,-240,-202,-201,-252,-204,1334,-205,-
  208,-209,-228,-262,-247,
 -265,1342,-220,-234,-268,-253,-256,-267,-275,-277);

 AELongBands:Array[0..12] Of Integer=(
 41,41,47,49,49,51,47,47,43,43,43,40,40);

 AELongOffsets:Array[0..12,0..51] Of Integer=(
 (0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,64,72,80,88,96,108,120,132,144,156,
  172,188,212,240,276,320,384,448,512,576,640,704,768,832,896,960,1024,1024,
  1024,1024,1024,1024,1024,1024,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,64,72,80,88,96,108,120,132,144,156,
  172,188,212,240,276,320,384,448,512,576,640,704,768,832,896,960,1024,1024,
  1024,1024,1024,1024,1024,1024,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,64,72,80,88,100,112,124,140,156,172,
  192,216,240,268,304,344,384,424,464,504,544,584,624,664,704,744,784,824,864,
  904,944,984,1024,1024,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,48,56,64,72,80,88,96,108,120,132,144,160,176,
  196,216,240,264,292,320,352,384,416,448,480,512,544,576,608,640,672,704,736,
  768,800,832,864,896,928,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,48,56,64,72,80,88,96,108,120,132,144,160,176,
  196,216,240,264,292,320,352,384,416,448,480,512,544,576,608,640,672,704,736,
  768,800,832,864,896,928,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,48,56,64,72,80,88,96,108,120,132,144,160,176,
  196,216,240,264,292,320,352,384,416,448,480,512,544,576,608,640,672,704,736,
  768,800,832,864,896,928,960,992,1024),
 (0,4,8,12,16,20,24,28,32,36,40,44,52,60,68,76,84,92,100,108,116,124,136,148,
  160,172,188,204,220,240,260,284,308,336,364,396,432,468,508,552,600,652,704,
  768,832,896,960,1024,1024,1024,1024,1024),
 (0,4,8,12,16,20,24,28,32,36,40,44,52,60,68,76,84,92,100,108,116,124,136,148,
  160,172,188,204,220,240,260,284,308,336,364,396,432,468,508,552,600,652,704,
  768,832,896,960,1024,1024,1024,1024,1024),
 (0,8,16,24,32,40,48,56,64,72,80,88,100,112,124,136,148,160,172,184,196,212,228,
  244,260,280,300,320,344,368,396,424,456,492,532,572,616,664,716,772,832,896,
  960,1024,1024,1024,1024,1024,1024,1024,1024,1024),
 (0,8,16,24,32,40,48,56,64,72,80,88,100,112,124,136,148,160,172,184,196,212,228,
  244,260,280,300,320,344,368,396,424,456,492,532,572,616,664,716,772,832,896,
  960,1024,1024,1024,1024,1024,1024,1024,1024,1024),
 (0,8,16,24,32,40,48,56,64,72,80,88,100,112,124,136,148,160,172,184,196,212,228,
  244,260,280,300,320,344,368,396,424,456,492,532,572,616,664,716,772,832,896,
  960,1024,1024,1024,1024,1024,1024,1024,1024,1024),
 (0,12,24,36,48,60,72,84,96,108,120,132,144,156,172,188,204,220,236,252,268,288,
  308,328,348,372,396,420,448,476,508,544,580,620,664,712,764,820,880,944,1024,
  1024,1024,1024,1024,1024,1024,1024,1024,1024,1024,1024),
 (0,12,24,36,48,60,72,84,96,108,120,132,144,156,172,188,204,220,236,252,268,288,
  308,328,348,372,396,420,448,476,508,544,580,620,664,712,764,820,880,944,1024,
  1024,1024,1024,1024,1024,1024,1024,1024,1024,1024,1024));


Type
 TAEDArr=Array[0..4095] Of Double;
 TAEPcm=Array[0..200000000] Of SmallInt; PAEPcm=^TAEPcm;
Var
 AEWr,AEWi,AETwr,AETwi,AEPwr,AEPwi: Array[0..511] Of Double;
 AEBitRev: Array[0..511] Of LongInt;
 AEWin: Array[0..2047] Of Double;
 AECode: Array[0..11,0..288] Of LongWord; AELen: Array[0..11,0..288] Of Byte;
 AEInv: Array[0..255] Of Double;
 AEQ: Array[0..1,0..1023] Of LongInt; AEBook,AESf: Array[0..1,0..63] Of LongInt;
  AEMs: Array[0..63] Of LongInt;
 AEMaxSfb,AEChans,AERateIdx,AEBands: LongInt; AEGlobal: Array[0..1] Of LongInt;
  AEOff: Array[0..52] Of LongInt;
 AEBuf: Array[0..16383] Of Byte; AEPos: LongInt; AECounting: Boolean;
 AEX: Array[0..1,0..1023] Of Double;
Const
 AELimit: Array[0..11] Of LongInt=(0,1,1,2,2,4,4,7,7,12,12,8191);
 AERates: Array[0..12] Of LongInt=(96000,88200,64000,48000,44100,32000,24000,
  22050,16000,12000,11025,8000,7350);

Procedure AEMdctInit;
Var I,J,B: LongInt; A: Double;
Begin
 For I:=0 To 511 Do Begin
  A:=-2*Pi*I/512; AEWr[I]:=Cos(A); AEWi[I]:=Sin(A);
  A:=-Pi*(4*I+1)/(4*1024); AETwr[I]:=Cos(A); AETwi[I]:=Sin(A);
  A:=-Pi*I/1024; AEPwr[I]:=Cos(A); AEPwi[I]:=Sin(A);
  J:=0; For B:=0 To 8 Do If (I And (1 Shl B))<>0 Then J:=J Or (1 Shl (8-B));
  AEBitRev[I]:=J;
 End;
 For I:=0 To 2047 Do AEWin[I]:=Sin(Pi*(I+0.5)/2048);
 For I:=0 To 255 Do AEInv[I]:=Exp(-(I-100)/4.0*0.69314718055994530942);
End;

{ MDCT AAC : X[k] = 2 * somme z[n] cos(pi/N (n+1/2+N/2)(k+1/2)), N=1024 }
Procedure AEMdct(Const Z: TAEDArr; Var X: TAEDArr);
Var U: Array[0..1023] Of Double; Tr,Ti: Array[0..511] Of Double; N,H,I,J,K,Len,
 Half,Step: LongInt; Ar,Ai,Br,Bi,Wr,Wi,Xr,Xi: Double;
Begin
 N:=1024; H:=512;
 For I:=0 To H-1 Do U[I]:=-Z[3*H-1-I]-Z[3*H+I];
 For I:=H To N-1 Do U[I]:=Z[I-H]-Z[3*H-1-I];
 For I:=0 To H-1 Do Begin
  Ar:=U[2*I]; Ai:=U[N-1-2*I];
  J:=AEBitRev[I];
  Tr[J]:=Ar*AETwr[I]-Ai*AETwi[I]; Ti[J]:=Ar*AETwi[I]+Ai*AETwr[I];
 End;
 Len:=2;
 While Len<=H Do Begin
  Half:=Len Div 2; Step:=H Div Len;
  I:=0;
  While I<H Do Begin
   For K:=0 To Half-1 Do Begin
    Wr:=AEWr[K*Step]; Wi:=AEWi[K*Step];
    Br:=Tr[I+K+Half]*Wr-Ti[I+K+Half]*Wi; Bi:=Tr[I+K+Half]*Wi+Ti[I+K+Half]*Wr;
    Tr[I+K+Half]:=Tr[I+K]-Br; Ti[I+K+Half]:=Ti[I+K]-Bi;
    Tr[I+K]:=Tr[I+K]+Br; Ti[I+K]:=Ti[I+K]+Bi;
   End;
   Inc(I,Len);
  End;
  Len:=Len*2;
 End;
 For K:=0 To H-1 Do Begin
  Xr:=Tr[K]*AEPwr[K]-Ti[K]*AEPwi[K]; Xi:=Tr[K]*AEPwi[K]+Ti[K]*AEPwr[K];
  X[2*K]:=2*Xr; X[N-1-2*K]:=-2*Xi;
 End;
End;

{ codes Huffman a partir des arbres du decodeur : AECode/AELen[livre,symbole] ;
 livre 0 = facteurs d'echelle }
Procedure AEWalk(Book,Node: LongInt; Code: LongWord; Depth: LongInt);
Var C: LongInt;
Begin
 C:=AEHuffLeft[Node];
 If C<0 Then Begin AECode[Book,-C-1]:=Code Shl 1; AELen[Book,-C-1]:=Depth+1; End
 Else If C>0 Then AEWalk(Book,C,Code Shl 1,Depth+1);
 C:=AEHuffRight[Node];
 If C<0 Then Begin AECode[Book,-C-1]:=(Code Shl 1) Or 1; AELen[Book,-C-1]:=
  Depth+1; End
 Else If C>0 Then AEWalk(Book,C,(Code Shl 1) Or 1,Depth+1);
End;

Procedure AEPut(V: LongWord; N: LongInt);
Var K: LongInt;
Begin
 If N<=0 Then Exit;
 If AECounting Then Begin Inc(AEPos,N); Exit; End;
 For K:=N-1 Downto 0 Do Begin
  If ((V Shr K) And 1)<>0 Then AEBuf[AEPos Shr 3]:=AEBuf[AEPos Shr 3] Or (1 Shl
   (7-(AEPos And 7)));
  Inc(AEPos);
 End;
End;

{ ecrit (Emit) ou compte les bits des valeurs Q[C, Off..Off+W-1] avec le livre
 Cb }
Function AEBand(Cb,C,Off,W: LongInt; Emit: Boolean): LongInt;
Var Dim,Radix,K,D,Sym,Bits,A,E2: LongInt; V: Array[0..3] Of LongInt; Signed:
 Boolean;
Begin
 Bits:=0;
 If Cb<=4 Then Begin Dim:=4; Radix:=3; End Else Begin Dim:=2; If Cb<=6 Then
  Radix:=9 Else If Cb<=8 Then Radix:=8 Else If Cb<=10 Then Radix:=13 Else
  Radix:=17; End;
 Signed:=(Cb<=2) Or ((Cb>=5) And (Cb<=6));
 K:=0;
 While K<W Do Begin
  Sym:=0;
  For D:=0 To Dim-1 Do Begin
   V[D]:=AEQ[C,Off+K+D];
   If Signed Then Begin
    If Cb<=2 Then A:=V[D]+1 Else A:=V[D]+4;
   End Else Begin
    A:=Abs(V[D]); If (Cb=11) And (A>16) Then A:=16;
   End;
   Sym:=Sym*Radix+A;
  End;
  Inc(Bits,AELen[Cb,Sym]);
  If Emit Then AEPut(AECode[Cb,Sym],AELen[Cb,Sym]);
  If Not Signed Then
   For D:=0 To Dim-1 Do If V[D]<>0 Then Begin
    Inc(Bits);
    If Emit Then If V[D]<0 Then AEPut(1,1) Else AEPut(0,1);
   End;
  If Cb=11 Then
   For D:=0 To Dim-1 Do If Abs(V[D])>=16 Then Begin
    A:=Abs(V[D]);
    { N = floor(log2(A)) ; (N-4) uns, un zero, puis N bits }
    Sym:=0; While (A Shr (Sym+1))>0 Do Inc(Sym);
    Inc(Bits,(Sym-4)+1+Sym);
    If Emit Then Begin
     For E2:=1 To Sym-4 Do AEPut(1,1);
     AEPut(0,1);
     AEPut(A-(1 Shl Sym),Sym);
    End;
   End;
  Inc(K,Dim);
 End;
 AEBand:=Bits;
End;

{ choisit le livre de code d'une bande ; renvoie 0 si nulle }
Function AEBestBook(C,Off,W: LongInt): LongInt;
Var K,Mx,F,Cb,Best,BestBits,B: LongInt;
Begin
 Mx:=0; For K:=Off To Off+W-1 Do If Abs(AEQ[C,K])>Mx Then Mx:=Abs(AEQ[C,K]);
 If Mx=0 Then Begin AEBestBook:=0; Exit; End;
 F:=1; While AELimit[F]<Mx Do Inc(F);
 Best:=F; BestBits:=AEBand(F,C,Off,W,False);
 For Cb:=F+1 To 11 Do If (Cb<=F+3) And (AELimit[Cb]>=Mx) Then Begin
  B:=AEBand(Cb,C,Off,W,False);
  If B<BestBits Then Begin BestBits:=B; Best:=Cb; End;
 End;
 AEBestBook:=Best;
End;

Function AEQuant(X,Inv: Double): LongInt;
Var A,Y: Double; Q: LongInt;
Begin
 A:=Abs(X)*Inv;
 If A<=0 Then Begin AEQuant:=0; Exit; End;
 Y:=Sqrt(A*Sqrt(A)); { A^0.75 }
 If Y>8191 Then Y:=8191.9;
 Q:=Trunc(Y+0.4054);
 If Q>8191 Then Q:=8191;
 If X<0 Then Q:=-Q;
 AEQuant:=Q;
End;

{ quantifie toutes les bandes pour le gain G (MS = bandes M/S) ; renvoie False
 si une valeur depasse 8191 }
Procedure AEPrepare(G: LongInt);
Var B,C,K,Off,W,Cb,Cb2,BitsLR,BitsMS: LongInt; InvLR,InvMS,M,S: Double; QL,QR:
 Array[0..255] Of LongInt; Mx: LongInt;
Begin
 InvLR:=AEInv[G]; If G>=2 Then InvMS:=AEInv[G-2] Else InvMS:=InvLR;
 For B:=0 To AEBands-1 Do Begin
  Off:=AEOff[B]; W:=AEOff[B+1]-Off;
  AEMs[B]:=0;
  If B>=AEMaxSfb Then Begin
   For K:=Off To Off+W-1 Do Begin AEQ[0,K]:=0; AEQ[1,K]:=0; End;
   Continue;
  End;
  For C:=0 To AEChans-1 Do For K:=Off To Off+W-1 Do AEQ[C,K]:=AEQuant(AEX[C,K],
   InvLR);
  AESf[0,B]:=G; AESf[1,B]:=G;
  If AEChans=2 Then Begin
   { variante M/S }
   BitsLR:=0;
   Cb:=AEBestBook(0,Off,W); If Cb<>0 Then Inc(BitsLR,AEBand(Cb,0,Off,W,False));
   Cb:=AEBestBook(1,Off,W); If Cb<>0 Then Inc(BitsLR,AEBand(Cb,1,Off,W,False));
   For K:=0 To W-1 Do Begin QL[K]:=AEQ[0,Off+K]; QR[K]:=AEQ[1,Off+K]; End;
   For K:=Off To Off+W-1 Do Begin
    M:=(AEX[0,K]+AEX[1,K])*0.5; S:=(AEX[0,K]-AEX[1,K])*0.5;
    AEQ[0,K]:=AEQuant(M,InvMS); AEQ[1,K]:=AEQuant(S,InvMS);
   End;
   BitsMS:=0;
   Cb:=AEBestBook(0,Off,W); If Cb<>0 Then Inc(BitsMS,AEBand(Cb,0,Off,W,False));
   Cb:=AEBestBook(1,Off,W); If Cb<>0 Then Inc(BitsMS,AEBand(Cb,1,Off,W,False));
   If BitsMS<BitsLR Then Begin
    AEMs[B]:=1; AESf[0,B]:=G-2; AESf[1,B]:=G-2;
   End Else Begin
    For K:=0 To W-1 Do Begin AEQ[0,Off+K]:=QL[K]; AEQ[1,Off+K]:=QR[K]; End;
   End;
  End;
 End;
 For C:=0 To AEChans-1 Do
  For B:=0 To AEMaxSfb-1 Do AEBook[C,B]:=AEBestBook(C,AEOff[B],AEOff[B+1]-AEOff[
   B]);
End;

{ ecrit (ou compte) une trame sans en-tete ADTS ; Gain = gain de reference }
Procedure AEWriteFrame(G: LongInt);
Var C,B,E,Cb,Len,Prev,D,Last,AnyMs,Gg: LongInt;
Procedure Ics(Ch: LongInt; Info: Boolean);
Var Bb,Ee,Cb2,L2,Pv,Dd: LongInt;
Begin
 Gg:=G; For Bb:=0 To AEMaxSfb-1 Do If AEBook[Ch,Bb]<>0 Then Begin Gg:=AESf[Ch,
  Bb]; Break; End;
 AEGlobal[Ch]:=Gg;
 AEPut(Gg,8);
 If Info Then Begin AEPut(0,1); AEPut(0,2); AEPut(0,1); AEPut(AEMaxSfb,6);
  AEPut(0,1); End;
 Bb:=0;
 While Bb<AEMaxSfb Do Begin
  Cb2:=AEBook[Ch,Bb]; Ee:=Bb; While (Ee<AEMaxSfb) And (AEBook[Ch,Ee]=Cb2) Do
   Inc(Ee);
  AEPut(Cb2,4); L2:=Ee-Bb;
  While L2>=31 Do Begin AEPut(31,5); Dec(L2,31); End;
  AEPut(L2,5); Bb:=Ee;
 End;
 Pv:=Gg;
 For Bb:=0 To AEMaxSfb-1 Do If AEBook[Ch,Bb]<>0 Then Begin
  Dd:=AESf[Ch,Bb]-Pv;
  AEPut(AECode[0,Dd+60],AELen[0,Dd+60]); Pv:=AESf[Ch,Bb];
 End;
 AEPut(0,1); AEPut(0,1); AEPut(0,1);
 For Bb:=0 To AEMaxSfb-1 Do If AEBook[Ch,Bb]<>0 Then AEBand(AEBook[Ch,Bb],Ch,
  AEOff[Bb],AEOff[Bb+1]-AEOff[Bb],True);
End;
Begin
 If AEChans=1 Then Begin
  AEPut(0,3); AEPut(0,4); Ics(0,True);
 End Else Begin
  AEPut(1,3); AEPut(0,4); AEPut(1,1);
  AEPut(0,1); AEPut(0,2); AEPut(0,1); AEPut(AEMaxSfb,6); AEPut(0,1);
  AnyMs:=0; For B:=0 To AEMaxSfb-1 Do If AEMs[B]<>0 Then AnyMs:=1;
  If AnyMs<>0 Then Begin AEPut(1,2); For B:=0 To AEMaxSfb-1 Do AEPut(AEMs[B],1);
   End Else AEPut(0,2);
  Ics(0,False); Ics(1,False);
 End;
 AEPut(7,3);
End;

Procedure AEEncodeAAC(Const Source,Target: String; BitRateK: LongInt);
Var
 Hd: Array[0..63] Of Byte; Limit,At,N,Sz,DataStart,DataSize,Rate,Frames,F,I,K,C,
  B,G,Lo,Hi,Best,Fill,Bits,AvgBits,Target2,Reservoir,Cut,CutBin,Used,Total,
  FrameBytes: LongInt;
 Fmt,Ch,BitsPer,Al: LongInt; Pcm: PAEPcm; Z,X: TAEDArr; Tag: String[4]; Out:
  Array[0..8191] Of Byte; Rd: Array[0..4095] Of Byte; BitsPerCh: LongInt;
 Nz: LongInt;
Function U32(P: LongInt): LongInt; Begin U32:=LongInt(Hd[P])+LongInt(Hd[P+1])*
 256+LongInt(Hd[P+2])*65536+LongInt(Hd[P+3])*16777216; End;
Function Sample(S,Cn: LongInt): Double;
Begin
 If (S<0) Or (S>=N) Then Sample:=0 Else Sample:=Pcm^[S*AEChans+Cn];
End;
Begin
 AEMdctInit;
 FillChar(AECode,SizeOf(AECode),0); FillChar(AELen,SizeOf(AELen),0);
 For I:=0 To 11 Do AEWalk(I,AERoots[I],0,0);
 OpenRead(Source); Limit:=InputSize;
 If Limit<12 Then Fail('aac: WAV tronque.');
 ReadAt(0,Hd,12);
 If (Hd[0]<>82) Or (Hd[1]<>73) Or (Hd[2]<>70) Or (Hd[3]<>70) Then Fail(
  'aac: WAV RIFF requis.');
 At:=12; Ch:=0; Rate:=0; DataStart:=0; DataSize:=-1; BitsPer:=0; Fmt:=0;
 While At+8<=Limit Do Begin
  ReadAt(At,Hd,8); Sz:=U32(4); Tag:=Chr(Hd[0])+Chr(Hd[1])+Chr(Hd[2])+Chr(Hd[3]);
   Inc(At,8);
  If Sz>Limit-At Then Sz:=Limit-At;
  If Tag='fmt ' Then Begin
   ReadAt(At,Hd,16); Fmt:=Hd[0]+Hd[1]*256; Ch:=Hd[2]+Hd[3]*256; Rate:=U32(4);
    BitsPer:=Hd[14]+Hd[15]*256;
  End Else If Tag='data' Then Begin DataStart:=At; DataSize:=Sz; Break; End;
  Inc(At,Sz+(Sz And 1));
 End;
 If (Fmt<>1) Or (BitsPer<>16) Or (Ch<1) Or (Ch>2) Or (DataSize<=0) Then Fail(
  'aac: PCM 16 bits mono ou stereo requis.');
 AEChans:=Ch; AERateIdx:=-1;
 If BitRateK<=0 Then BitRateK:=64*Ch;
 If (BitRateK<8) Or (BitRateK>576) Then Fail('aac: debit 8..576 kb/s requis.');
 For I:=0 To 12 Do If AERates[I]=Rate Then AERateIdx:=I;
 If AERateIdx<0 Then Fail(
  'aac: frequence non AAC (96000..7350 Hz); utiliser -ar.');
 N:=DataSize Div (2*Ch);
 If N<1 Then Fail('aac: aucun echantillon.');
 GetMem(Pcm,Int64(N)*Ch*2+16);
 At:=0;
 While At<N*Ch*2 Do Begin
  If N*Ch*2-At>4096 Then Sz:=4096 Else Sz:=N*Ch*2-At;
  ReadAt(DataStart+At,Rd,Sz);
  For I:=0 To Sz Div 2-1 Do Begin
   K:=Rd[2*I]+Rd[2*I+1]*256; If K>=32768 Then Dec(K,65536);
   Pcm^[(At Div 2)+I]:=K;
  End;
  Inc(At,Sz);
 End;
 CloseRead;
 AEBands:=AELongBands[AERateIdx];
 For I:=0 To AEBands Do AEOff[I]:=AELongOffsets[AERateIdx,I];
 { bande passante (table de libfaac) }
 BitsPerCh:=BitRateK*1000 Div Ch;
 If BitsPerCh<=29500 Then Cut:=5000 Else If BitsPerCh<=36000 Then Cut:=9000 Else
  If BitsPerCh<=43000 Then Cut:=12000
 Else If BitsPerCh<=50000 Then Cut:=14260 Else If BitsPerCh<=58000 Then Cut:=
  15500 Else If BitsPerCh<=68000 Then Cut:=16000
 Else If BitsPerCh<=96000 Then Cut:=18000 Else Cut:=Rate Div 2;
 If Cut>Rate Div 2 Then Cut:=Rate Div 2;
 CutBin:=Round(Cut*2048.0/Rate); If CutBin>1024 Then CutBin:=1024;
 Frames:=(N+1023) Div 1024+1;
 AvgBits:=Round(BitRateK*1000.0*1024/Rate); Reservoir:=0;
 OpenWrite(Target);
 For F:=0 To Frames-1 Do Begin
  For C:=0 To Ch-1 Do Begin
   For I:=0 To 2047 Do Z[I]:=AEWin[I]*Sample((F-1)*1024+I,C);
   AEMdct(Z,X);
   For K:=0 To 1023 Do If K<CutBin Then AEX[C,K]:=X[K] Else AEX[C,K]:=0;
  End;
  { bandes utiles }
  AEMaxSfb:=0; For B:=0 To AEBands-1 Do If AEOff[B]<CutBin Then AEMaxSfb:=B+1;
  { derniere bande non nulle (energie) }
  Nz:=0;
  For B:=0 To AEMaxSfb-1 Do For C:=0 To Ch-1 Do For K:=AEOff[B] To AEOff[B+1]-1
   Do If Abs(AEX[C,K])>=0.5 Then Nz:=B+1;
  AEMaxSfb:=Nz;
  Target2:=AvgBits+Reservoir Div 2; If Target2>6000*Ch Then Target2:=6000*Ch;
  Target2:=Target2-56-8;
  Lo:=2; Hi:=255; Best:=255;
  While Lo<=Hi Do Begin
   G:=(Lo+Hi) Div 2;
   AEPrepare(G);
   AECounting:=True; AEPos:=0; AEWriteFrame(G);
   If AEPos<=Target2 Then Begin Best:=G; Hi:=G-1; End Else Lo:=G+1;
  End;
  G:=Best; AEPrepare(G);
  { recalcul du nombre maximal de bandes apres quantification }
  Nz:=0;
  For C:=0 To Ch-1 Do For B:=0 To AEMaxSfb-1 Do If AEBook[C,B]<>0 Then If B+1>Nz
   Then Nz:=B+1;
  AEMaxSfb:=Nz;
  AECounting:=False; AEPos:=0; FillChar(AEBuf,SizeOf(AEBuf),0);
  AEWriteFrame(G);
  Used:=AEPos; FrameBytes:=(Used+7) Div 8+7;
  If FrameBytes>8191 Then Fail('aac: trame trop grande.');
  Out[0]:=$FF; Out[1]:=$F1; Out[2]:=(1 Shl 6) Or (AERateIdx Shl 2) Or (Ch Shr
   2);
  Out[3]:=((Ch And 3) Shl 6) Or (FrameBytes Shr 11);
  Out[4]:=(FrameBytes Shr 3) And 255;
  Out[5]:=((FrameBytes And 7) Shl 5) Or $1F;
  Out[6]:=$FC;
  Move(AEBuf,Out[7],(Used+7) Div 8);
  WriteBytes(Out,FrameBytes);
  Inc(Reservoir,AvgBits-(FrameBytes*8)); If Reservoir>3000*Ch Then Reservoir:=
   3000*Ch; If Reservoir<0 Then Reservoir:=0;
 End;
 CloseWrite;
 FreeMem(Pcm,Int64(N)*Ch*2+16);
End;

{ MPEG-1/2 video: I/B encoders and MPEG-1 I/P/B decoder. Tables and syntax
 adapted
  from FFmpeg mpeg12data.c/mpeg12.c/mpeg12dec.c (LGPL-2.1-or-later). }
{ VORBE-BEGIN }

{$ENDIF}
{$IFDEF FPC}
{ ---- MPEG-4 Part 2 (XviD/DivX) : decodeur de FFMPEG.PAS / libavcodec (LGPL-2.1+) ---- }
Var
 M4VidHook: Procedure(B: Pointer; W,H: LongInt);
Function AVSar(V: Int64; N: Integer): Int64;Begin
 If V>=0 Then AVSar:=V Shr N Else AVSar:=-1-((-1-V) Shr N);
End;
Type TGFArr=Array[0..100000000] Of LongInt; PGFArr=^TGFArr;
{ ---- H.263 / H.261 / Sorenson Spark (FLV1): tables de libavcodec/h263data.c,
 h261data.c, mpegvideodata.c, LGPL-2.1-or-later ---- }
Const
 H3IntraMcbpcCode: Array[0..8] Of Byte=(
  1,1,2,3,1,1,2,3,1);
 H3IntraMcbpcBits: Array[0..8] Of Byte=(
  1,3,3,3,4,6,6,6,9);
 H3InterMcbpcCode: Array[0..27] Of Byte=(
  1,3,2,5,3,4,3,3,3,7,6,5,4,4,3,2,
  2,5,4,5,1,0,0,0,2,12,14,15);
 H3InterMcbpcBits: Array[0..27] Of Byte=(
  1,4,4,6,5,8,8,7,3,7,7,9,6,9,9,9,
  3,7,7,8,9,0,0,0,11,13,13,13);
 H3CbpyTab: Array[0..31] Of Byte=(
  3,4,5,5,4,5,9,4,3,5,7,4,2,6,11,4,
  2,5,3,6,5,4,10,4,4,4,8,4,6,4,3,2);
 H3MvTab: Array[0..65] Of Byte=(
  1,1,1,2,1,3,1,4,3,6,5,7,4,7,3,7,
  11,9,10,9,9,9,17,10,16,10,15,10,14,10,13,10,
  12,10,11,10,10,10,9,10,8,10,7,10,6,10,5,10,
  4,10,7,11,6,11,5,11,4,11,3,11,2,11,3,12,
  2,12);
 H3InterVlc: Array[0..205] Of Word=(
  2,2,15,4,21,6,23,7,31,8,37,9,36,9,33,10,
  32,10,7,11,6,11,32,11,6,3,20,6,30,8,15,10,
  33,11,80,12,14,4,29,8,14,10,81,12,13,5,35,9,
  13,10,12,5,34,9,82,12,11,5,12,10,83,12,19,6,
  11,10,84,12,18,6,10,10,17,6,9,10,16,6,8,10,
  22,7,85,12,21,7,20,7,28,8,27,8,33,9,32,9,
  31,9,30,9,29,9,28,9,27,9,26,9,34,11,35,11,
  86,12,87,12,7,4,25,9,5,11,15,6,4,11,14,6,
  13,6,12,6,19,7,18,7,17,7,16,7,26,8,25,8,
  24,8,23,8,22,8,21,8,20,8,19,8,24,9,23,9,
  22,9,21,9,20,9,19,9,18,9,17,9,7,10,6,10,
  5,10,4,10,36,11,37,11,38,11,39,11,88,12,89,12,
  90,12,91,12,92,12,93,12,94,12,95,12,3,7);
 H3InterLevel: Array[0..101] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,1,2,3,4,
  5,6,1,2,3,4,1,2,3,1,2,3,1,2,3,1,
  2,3,1,2,1,2,1,2,1,2,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,2,3,1,2,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1);
 H3InterRun: Array[0..101] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,
  1,1,2,2,2,2,3,3,3,4,4,4,5,5,5,6,
  6,6,7,7,8,8,9,9,10,10,11,12,13,14,15,16,
  17,18,19,20,21,22,23,24,25,26,0,0,0,1,1,2,
  3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,
  19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,
  35,36,37,38,39,40);
 H3IntraVlcAic: Array[0..205] Of Word=(
  2,2,6,3,14,4,12,5,13,5,16,6,17,6,18,6,
  22,7,27,8,32,9,33,9,26,9,27,9,28,9,29,9,
  30,9,31,9,35,11,34,11,87,12,86,12,85,12,84,12,
  83,12,15,4,20,6,20,7,30,8,15,10,33,11,80,12,
  11,5,21,7,14,10,9,10,21,6,29,8,13,10,81,12,
  19,6,35,9,7,11,23,7,34,9,82,12,28,8,12,10,
  31,8,11,10,37,9,10,10,36,9,6,11,33,10,32,10,
  8,10,32,11,7,4,12,6,16,7,19,8,17,9,18,9,
  4,10,39,11,38,11,95,12,15,6,19,9,5,10,37,11,
  14,6,20,9,36,11,13,6,6,10,94,12,17,7,7,10,
  19,7,93,12,18,7,92,12,20,8,91,12,21,8,26,8,
  25,8,24,8,23,8,22,8,25,9,21,9,22,9,24,9,
  23,9,4,11,5,11,88,12,89,12,90,12,3,7);
 H3IntraRunAic: Array[0..101] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,
  2,2,2,2,3,3,3,3,4,4,4,5,5,5,6,6,
  7,7,8,8,9,9,10,11,12,13,0,0,0,0,0,0,
  0,0,0,0,1,1,1,1,2,2,2,3,3,3,4,4,
  5,5,6,6,7,7,8,9,10,11,12,13,14,15,16,17,
  18,19,20,21,22,23);
 H3IntraLevelAic: Array[0..101] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  17,18,19,20,21,22,23,24,25,1,2,3,4,5,6,7,
  1,2,3,4,1,2,3,4,1,2,3,1,2,3,1,2,
  1,2,1,2,1,2,1,1,1,1,1,2,3,4,5,6,
  7,8,9,10,1,2,3,4,1,2,3,1,2,3,1,2,
  1,2,1,2,1,2,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1);
 H3Format: Array[0..15] Of Word=(
  0,0,128,96,176,144,352,288,704,576,1408,1152,0,0,0,0);
 H3AicDcScale: Array[0..31] Of Byte=(
  0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,
  32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62);
 H3ModQuant: Array[0..63] Of Byte=(
  0,3,1,2,3,4,5,6,7,8,9,9,10,11,12,13,
  14,15,16,17,18,18,19,20,21,22,23,24,25,26,27,28,
  0,2,3,4,5,6,7,8,9,10,11,13,14,15,16,17,
  18,19,20,21,22,24,25,26,27,28,29,30,31,31,31,26);
 H3ChromaQ: Array[0..31] Of Byte=(
  0,1,2,3,4,5,6,6,7,8,9,9,10,10,11,11,
  12,12,12,13,13,13,14,14,14,14,14,15,15,15,15,15);
 H3MbaMax: Array[0..5] Of Word=(
  47,98,395,1583,6335,9215);
 H3MbaLength: Array[0..6] Of Byte=(
  6,7,9,11,13,14,14);
 H3MbtypeB: Array[0..29] Of Byte=(
  1,1,3,3,1,5,4,4,5,4,6,6,2,4,3,4,
  7,6,4,6,5,6,1,6,1,10,1,7,1,8);
 H3CbpcB: Array[0..7] Of Byte=(
  0,1,2,2,7,3,6,3);

Type
 TH3I16=Array[0..200000000] Of SmallInt; PH3I16=^TH3I16;
 TH3Blk=Array[0..63] Of SmallInt;
 TH3Vlc=Record Sym: Array[0..65535] Of SmallInt; Len: Array[0..65535] Of Byte;
  Bits: LongInt; End;
 TH3Pic=Record
  Y,U,V: PEABuffer;
  Mt: PGFArr;       { mb_type, decale de 2*mb_stride+1 }
  Mv: PH3I16;       { vecteurs (x,y) par bloc 8x8, decale de 4 blocs }
  Mv1: PH3I16;      { liste 1 (images B) }
  Qs: PEABuffer;    { qscale par macrobloc, decale de 2*mb_stride+1 }
 End;
Const
 H3_INTRA=1; H3_16X16=8; H3_8X8=64; H3_SKIP=2048; H3_ACPRED=512; H3_L0=12288;
  H3_DIRECT2=256; H3_QUANT=65536; H3_CBP=131072;
 H3Zigzag: Array[0..63] Of Byte=(0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,
  26,33,40,48,41,34,27,20,13,6,7,14,21,28,
  35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,
   61,54,47,55,62,63);
 H3AltH: Array[0..63] Of Byte=(0,1,2,3,8,9,16,17,10,11,4,5,6,7,15,14,13,12,19,
  18,24,25,32,33,26,27,20,21,22,23,28,29,
  30,31,34,35,40,41,48,49,42,43,36,37,38,39,44,45,46,47,50,51,56,57,58,59,52,53,
   54,55,60,61,62,63);
 H3AltV: Array[0..63] Of Byte=(0,8,16,24,1,9,2,10,17,25,32,40,48,56,57,49,41,33,
  26,18,3,11,4,12,19,27,34,42,50,58,35,43,
  51,59,20,28,5,13,6,14,21,29,36,44,52,60,37,45,53,61,22,30,7,15,23,31,38,46,54,
   62,39,47,55,63);
 H3LoopStrength: Array[0..31] Of Byte=(0,1,1,2,2,3,3,4,4,4,5,5,6,6,7,7,7,8,8,8,
  9,9,9,10,10,10,11,11,11,12,12,12);
 H3RoundTab: Array[0..15] Of Byte=(0,0,0,1,1,1,1,1,0,0,0,0,0,0,1,1);
Var
 { lecteur de bits }
 H3Buf: PEABuffer; H3Size,H3Pos: LongInt;
 { tables VLC }
 H3VIntra,H3VInter,H3VCbpy,H3VMv: TH3Vlc;
 H3VRlInter,H3VRlAic: TH3Vlc;   { sym: indice de table (0..102), 102 =
  echappement }
 H3VMbB,H3VCbpcB: TH3Vlc;
 H3RunInter,H3RunAic: Array[0..102] Of SmallInt;  { run+1 (+192 si dernier) }
 H3LevInter,H3LevAic: Array[0..102] Of SmallInt;
 H3Init: Boolean;
 H3RasterEnd: Array[0..63] Of Byte;
 H3AltHRE,H3AltVRE: Array[0..63] Of Byte;

Function H3Left: LongInt;Begin H3Left:=H3Size*8-H3Pos; End;
Function H3Show(N: LongInt): LongInt;
Var P: LongInt; V: Int64;
Begin
 If N=0 Then Begin H3Show:=0; Exit; End;
 P:=H3Pos Shr 3;
 V:=(Int64(H3Buf^[P]) Shl 32) Or (Int64(H3Buf^[P+1]) Shl 24) Or (Int64(H3Buf^[P+
  2]) Shl 16) Or (Int64(H3Buf^[P+3]) Shl 8) Or Int64(H3Buf^[P+4]);
 H3Show:=(V Shr (40-(H3Pos And 7)-N)) And ((Int64(1) Shl N)-1);
End;
Function H3Bits(N: LongInt): LongInt;Begin H3Bits:=H3Show(N); Inc(H3Pos,N); End;
Function H3Bit: LongInt;Begin H3Bit:=(H3Buf^[H3Pos Shr 3] Shr (7-(H3Pos And 7)))
 And 1; Inc(H3Pos); End;
Procedure H3Skip(N: LongInt);Begin Inc(H3Pos,N); End;
Function H3SBits(N: LongInt): LongInt;
Var V: LongInt;
Begin V:=H3Show(N); If V>=(LongInt(1) Shl (N-1)) Then V:=V-(LongInt(1) Shl N);
 H3SBits:=V; End;
Procedure H3Align;Begin H3Pos:=(H3Pos+7) And -8; End;
Function H3Sar(V: LongInt; N: LongInt): LongInt;
Begin If V>=0 Then H3Sar:=V Shr N Else H3Sar:=-1-((-1-V) Shr N); End;
Function H3Mid(A,B,C: LongInt): LongInt;
Var Lo,Hi: LongInt;
Begin
 If A<B Then Begin Lo:=A; Hi:=B; End Else Begin Lo:=B; Hi:=A; End;
 If C<Hi Then Hi:=C;
 If Lo>Hi Then H3Mid:=Lo Else H3Mid:=Hi;
End;
Function H3Clip(V,Lo,Hi: LongInt): LongInt;Begin If V<Lo Then V:=Lo; If V>Hi
 Then V:=Hi; H3Clip:=V; End;

{ construit une table VLC directe a partir de (code,longueur); Pas = 1 (tables
 separees) ou 2 (paires) }
Procedure H3BuildVlc(Var T: TH3Vlc; N: LongInt; Codes,Lens: PEABuffer;
 WideCodes: Boolean; Step: LongInt);
Var I,J,Len,Code,Span: LongInt;
Begin
 T.Bits:=0;
 For I:=0 To N-1 Do Begin
  Len:=Lens^[I*Step]; If Len>T.Bits Then T.Bits:=Len;
 End;
 For I:=0 To (LongInt(1) Shl T.Bits)-1 Do Begin T.Sym[I]:=-1; T.Len[I]:=0; End;
 For I:=0 To N-1 Do Begin
  Len:=Lens^[I*Step]; If Len=0 Then Continue;
  Code:=Codes^[I*Step];
  Span:=LongInt(1) Shl (T.Bits-Len);
  For J:=0 To Span-1 Do Begin
   T.Sym[(Code Shl (T.Bits-Len))+J]:=I; T.Len[(Code Shl (T.Bits-Len))+J]:=Len;
  End;
 End;
End;

Function H3GetVlc(Var T: TH3Vlc): LongInt;
Var Ix: LongInt;
Begin
 Ix:=H3Show(T.Bits);
 H3GetVlc:=T.Sym[Ix]; Inc(H3Pos,T.Len[Ix]);
End;

Procedure H3InitTables;
Var
 I,J: LongInt; Cd,Bt: Array[0..255] Of Byte; Cw: Array[0..255] Of Word;
 Tmp: Array[0..3] Of Byte;
Procedure BuildRl(Var T: TH3Vlc; Const Vl: Array Of Word; Const Run,Lev: Array
 Of ShortInt; Var RunO,LevO: Array Of SmallInt);
Var K,Len,J: LongInt;
Begin
 T.Bits:=0;
 For K:=0 To 102 Do Begin Len:=Vl[K*2+1]; If Len>T.Bits Then T.Bits:=Len; End;
 For K:=0 To (LongInt(1) Shl T.Bits)-1 Do Begin T.Sym[K]:=-1; T.Len[K]:=0; End;
 For K:=0 To 102 Do Begin
  Len:=Vl[K*2+1];
  For J:=0 To (LongInt(1) Shl (T.Bits-Len))-1 Do Begin
   T.Sym[(Vl[K*2] Shl (T.Bits-Len))+J]:=K; T.Len[(Vl[K*2] Shl (T.Bits-Len))+J]:=
    Len;
  End;
  If K<102 Then Begin
   RunO[K]:=Run[K]+1; If K>=58 Then Inc(RunO[K],192);
   LevO[K]:=Lev[K];
  End;
 End;
End;
Begin
 If H3Init Then Exit;
 H3Init:=True;
 H3BuildVlc(H3VIntra,9,@H3IntraMcbpcCode,@H3IntraMcbpcBits,False,1);
 H3BuildVlc(H3VInter,28,@H3InterMcbpcCode,@H3InterMcbpcBits,False,1);
 H3BuildVlc(H3VCbpy,16,@H3CbpyTab,@H3CbpyTab[1],False,2);
 H3BuildVlc(H3VMv,33,@H3MvTab,@H3MvTab[1],False,2);
 H3BuildVlc(H3VMbB,15,@H3MbtypeB,@H3MbtypeB[1],False,2);
 H3BuildVlc(H3VCbpcB,4,@H3CbpcB,@H3CbpcB[1],False,2);
 BuildRl(H3VRlInter,H3InterVlc,H3InterRun,H3InterLevel,H3RunInter,H3LevInter);
 BuildRl(H3VRlAic,H3IntraVlcAic,H3IntraRunAic,H3IntraLevelAic,H3RunAic,
  H3LevAic);
 J:=-1;
 For I:=0 To 63 Do Begin If H3Zigzag[I]>J Then J:=H3Zigzag[I]; H3RasterEnd[I]:=
  J; End;
 J:=-1;
 For I:=0 To 63 Do Begin If H3AltH[I]>J Then J:=H3AltH[I]; H3AltHRE[I]:=J; End;
 J:=-1;
 For I:=0 To 63 Do Begin If H3AltV[I]>J Then J:=H3AltV[I]; H3AltVRE[I]:=J; End;
End;

Var
 { parametres de l'image / du flux }
 H3Wd,H3Ht,H3MbW,H3MbH,H3MbStride,H3B8Stride,H3MbNum,H3LY,H3LC,H3HEdge,H3VEdge:
  LongInt;
 H3PictType: LongInt;  { 0 I, 1 P, 2 B }
 H3Qscale,H3ChromaQscale,H3YDcScale,H3CDcScale: LongInt;
 H3Obmc,H3Umvplus,H3LongVec,H3Aic,H3Loop,H3SliceStruct,H3AltInter,H3ModQ,
  H3PbFrame,H3NoRounding,H3Plus,H3CustomPcf,H3Flv,H3Droppable: LongInt;
 H3PicNum,H3LastNonB,H3Time,H3PpTime,H3PbTime: LongInt;
 H3Aspect: Array[0..1] Of LongInt;  { sample_aspect_ratio num,den }
 H3FpsN,H3FpsD: LongInt;
 H3ChromaTab: Boolean;  { True: table de qscale chroma modifiee }
 H3Inited: Boolean;
 { etat macrobloc }
 H3MbX,H3MbY,H3MbIntra,H3AcPred,H3AicDir,H3MvType,H3MbSkipped,H3FirstLine,
  H3ResyncX,H3ResyncY: LongInt;
 H3Mv: Array[0..3,0..1] Of LongInt;
 H3Blk: Array[0..5] Of TH3Blk;
 H3BlkLast: Array[0..5] Of LongInt;
 H3LastGb: LongInt;
 { images }
 H3P: Array[0..2] Of TH3Pic;
 H3CurI,H3RefI: LongInt;  { indices dans H3P; -1 = aucune }
 H3Dc: Array[0..2] Of PH3I16;   { dc_val: base ; acces par decalage }
 H3Ac: PH3I16;
 H3DcOff: Array[0..2] Of LongInt;
 H3Intra: PEABuffer;  { mbintra_table }
 H3DcBase: PH3I16; H3DcN,H3AcN: LongInt;
 H3Err: Boolean;
 { RealVideo 1.0/2.0 }
 H3RvMode,H3Rv10Ver,H3MbNumLeft: LongInt; H3MvList,H3MvDir,H3BwdI,H3Avg:
  LongInt; H3Mv1: Array[0..3,0..1] Of LongInt; H3DirScale: Array[0..1,0..63] Of
  LongInt; H3RvLastDc,H3RvFirst: Array[0..2] Of LongInt;
 H3RvLumSym,H3RvChrSym: Array[0..1023] Of Byte; H3RvLumCnt,H3RvChrCnt,
  H3RvLumFirst,H3RvChrFirst,H3RvLumOff,H3RvChrOff: Array[0..17] Of LongInt;
  H3RvInit: Boolean;

Function H3Mt(Xy: LongInt): LongInt;Begin H3Mt:=H3P[H3CurI].Mt^[Xy+2*H3MbStride+
 1]; End;
Procedure H3SetMt(Xy,V: LongInt);Begin H3P[H3CurI].Mt^[Xy+2*H3MbStride+1]:=V;
 End;
Function H3MvAt(M,C: LongInt): LongInt;Begin If H3MvList=0 Then H3MvAt:=H3P[
 H3CurI].Mv^[(M+4)*2+C] Else H3MvAt:=H3P[H3CurI].Mv1^[(M+4)*2+C]; End;
Procedure H3SetMv(M,C,V: LongInt);Begin If H3MvList=0 Then H3P[H3CurI].Mv^[(M+
 4)*2+C]:=V Else H3P[H3CurI].Mv1^[(M+4)*2+C]:=V; End;

Procedure H3SetQscale(Q: LongInt);
Begin
 If Q<1 Then Q:=1 Else If Q>31 Then Q:=31;
 H3Qscale:=Q;
 If H3ChromaTab Then H3ChromaQscale:=H3ChromaQ[Q] Else H3ChromaQscale:=Q;
 If H3Aic<>0 Then Begin H3YDcScale:=H3AicDcScale[Q]; H3CDcScale:=H3AicDcScale[
  H3ChromaQscale]; End
 Else Begin H3YDcScale:=8; H3CDcScale:=8; End;
End;

Function H3Sext(V,Bits: LongInt): LongInt;
Begin
 V:=V And ((LongInt(1) Shl Bits)-1);
 If V>=(LongInt(1) Shl (Bits-1)) Then V:=V-(LongInt(1) Shl Bits);
 H3Sext:=V;
End;

{ ff_h263_decode_mba }
Function H3DecodeMba: LongInt;
Var I,P: LongInt;
Begin
 I:=0;
 While I<6 Do Begin If H3MbNum-1<=H3MbaMax[I] Then Break; Inc(I); End;
 P:=H3Bits(H3MbaLength[I]);
 H3MbX:=P Mod H3MbW; H3MbY:=P Div H3MbW;
 H3DecodeMba:=P;
End;

{ h263_decode_gob_header: faux = erreur }
Function H3GobHeader: Boolean;
Var Left,Gob,I: LongInt;
Begin
 H3GobHeader:=False;
 If H3Show(16)<>0 Then Exit;
 H3Skip(16);
 Left:=H3Left; If Left>32 Then Left:=32;
 While Left>13 Do Begin
  If H3Bit<>0 Then Break;
  Dec(Left);
 End;
 If Left<=13 Then Exit;
 If H3SliceStruct<>0 Then Begin
  If H3Bit=0 Then Exit;
  H3DecodeMba;
  If H3MbNum>1583 Then If H3Bit=0 Then Exit;
  H3Qscale:=H3Bits(5);
  If H3Bit=0 Then Exit;
  H3Skip(2);
 End Else Begin
  Gob:=H3Bits(5);
  H3MbX:=0;
  If H3Ht<=400 Then I:=1 Else If H3Ht<=800 Then I:=2 Else I:=4;
  H3MbY:=I*Gob;
  H3Skip(2);
  H3Qscale:=H3Bits(5);
 End;
 If H3MbY>=H3MbH Then Exit;
 If H3Qscale=0 Then Exit;
 H3GobHeader:=True;
End;

{ ff_h263_resync: renvoie la position ou -1 }
Function H3Resync: LongInt;
Var Left,Pos,Bak: LongInt;
Begin
 H3Resync:=-1;
 If H3Show(16)=0 Then Begin
  Pos:=H3Pos;
  If H3GobHeader Then Begin H3Resync:=Pos; Exit; End;
 End;
 H3Pos:=H3LastGb;
 H3Align;
 Left:=H3Left;
 While Left>16+1+5+5 Do Begin
  If H3Show(16)=0 Then Begin
   Bak:=H3Pos; Pos:=H3Pos;
   If H3GobHeader Then Begin H3Resync:=Pos; Exit; End;
   H3Pos:=Bak;
  End;
  H3Skip(8);
  Dec(Left,8);
 End;
End;

{ ff_h263_pred_motion: renvoie l'indice du bloc ; Px,Py predicteur }
Function H3PredMotion(Block,Dir: LongInt; Var Px,Py: LongInt): LongInt;
Var Wrap,M,A0,A1,B0,B1,C0,C1,Off: LongInt;
Begin
 Wrap:=H3B8Stride;
 M:=H3B8Stride*2*H3MbY+2*H3MbX+(Block And 1)+(Block Shr 1)*H3B8Stride;
 Case Block Of 0: Off:=2; 1,2: Off:=1; Else Off:=-1; End;
 A0:=H3MvAt(M-1,0); A1:=H3MvAt(M-1,1);
 If (H3FirstLine<>0) And (Block<3) Then Begin
  If Block=0 Then Begin
   If H3MbX=H3ResyncX Then Begin Px:=0; Py:=0; End
   Else Begin Px:=A0; Py:=A1; End;
  End Else If Block=1 Then Begin
   Px:=A0; Py:=A1;
  End Else Begin
   B0:=H3MvAt(M-Wrap,0); B1:=H3MvAt(M-Wrap,1);
   C0:=H3MvAt(M+Off-Wrap,0); C1:=H3MvAt(M+Off-Wrap,1);
   If H3MbX=H3ResyncX Then Begin A0:=0; A1:=0; H3SetMv(M-1,0,0); H3SetMv(M-1,1,
    0); End;
   Px:=H3Mid(A0,B0,C0); Py:=H3Mid(A1,B1,C1);
  End;
 End Else Begin
  B0:=H3MvAt(M-Wrap,0); B1:=H3MvAt(M-Wrap,1);
  C0:=H3MvAt(M+Off-Wrap,0); C1:=H3MvAt(M+Off-Wrap,1);
  Px:=H3Mid(A0,B0,C0); Py:=H3Mid(A1,B1,C1);
 End;
 H3PredMotion:=M;
End;

{ ff_h263_decode_motion }
Function H3DecMotion(Pred,FCode: LongInt): LongInt;
Var Code,Val,Sign,Shift: LongInt;
Begin
 Code:=H3GetVlc(H3VMv);
 If Code=0 Then Begin H3DecMotion:=Pred; Exit; End;
 If Code<0 Then Begin H3DecMotion:=$FFFF; Exit; End;
 Sign:=H3Bit;
 Shift:=FCode-1;
 Val:=Code;
 If Shift<>0 Then Begin
  Val:=(Val-1) Shl Shift;
  Val:=Val Or H3Bits(Shift);
  Inc(Val);
 End;
 If Sign<>0 Then Val:=-Val;
 Inc(Val,Pred);
 If H3LongVec=0 Then Val:=H3Sext(Val,5+FCode)
 Else Begin
  If (Pred<-31) And (Val<-63) Then Inc(Val,64);
  If (Pred>32) And (Val>63) Then Dec(Val,64);
 End;
 H3DecMotion:=Val;
End;

{ h263p_decode_umotion }
Function H3UMotion(Pred: LongInt): LongInt;
Var Code,Sign: LongInt;
Begin
 If H3Bit<>0 Then Begin H3UMotion:=Pred; Exit; End;
 Code:=2+H3Bit;
 While H3Bit<>0 Do Begin
  Code:=Code Shl 1;
  Inc(Code,H3Bit);
  If Code>=32768 Then Begin H3UMotion:=$FFFF; Exit; End;
 End;
 Sign:=Code And 1;
 Code:=Code Shr 1;
 If Sign<>0 Then H3UMotion:=Pred-Code Else H3UMotion:=Pred+Code;
End;

Function H3MotionComp(Pred: LongInt): LongInt;
Begin If H3Umvplus<>0 Then H3MotionComp:=H3UMotion(Pred) Else H3MotionComp:=
 H3DecMotion(Pred,1); End;

Procedure H3Dquant;
Const QT: Array[0..3] Of ShortInt=(-1,-2,1,2);
Var Q: LongInt;
Begin
 If H3ModQ<>0 Then Begin
  If H3Bit<>0 Then Begin
   Q:=H3Bit;
   H3Qscale:=H3ModQuant[Q*32+H3Qscale];
  End Else H3Qscale:=H3Bits(5);
 End Else Inc(H3Qscale,QT[H3Bits(2)]);
 H3SetQscale(H3Qscale);
End;

{ ---- decodage des blocs et des macroblocs (ituh263dec.c) ---- }
Procedure H3PredAcDc(Var Block: TH3Blk; N: LongInt);
Var X,Y,Wrap,A,C,PredDc,Scale,I,AcBase,AcBase1,Comp: LongInt; Dc: PH3I16;
Begin
 If N<4 Then Begin
  X:=2*H3MbX+(N And 1); Y:=2*H3MbY+(N Shr 1); Wrap:=H3B8Stride; Comp:=0; Scale:=
   H3YDcScale;
 End Else Begin
  X:=H3MbX; Y:=H3MbY; Wrap:=H3MbStride; Comp:=N-4+1; Scale:=H3CDcScale;
 End;
 Dc:=H3Dc[Comp];
 AcBase:=(H3DcOff[Comp]+Y*Wrap+X)*16; AcBase1:=AcBase;
 A:=Dc^[H3DcOff[Comp]+(X-1)+Y*Wrap];
 C:=Dc^[H3DcOff[Comp]+X+(Y-1)*Wrap];
 If (H3FirstLine<>0) And (N<>3) Then Begin
  If N<>2 Then C:=1024;
  If (N<>1) And (H3MbX=H3ResyncX) Then A:=1024;
 End;
 If H3AcPred<>0 Then Begin
  PredDc:=1024;
  If H3AicDir<>0 Then Begin
   If A<>1024 Then Begin
    Dec(AcBase,16);
    For I:=1 To 7 Do Block[I Shl 3]:=SmallInt(Block[I Shl 3]+H3Ac^[AcBase+I]);
    PredDc:=A;
   End;
  End Else Begin
   If C<>1024 Then Begin
    Dec(AcBase,16*Wrap);
    For I:=1 To 7 Do Block[I]:=SmallInt(Block[I]+H3Ac^[AcBase+I+8]);
    PredDc:=C;
   End;
  End;
 End Else Begin
  If (A<>1024) And (C<>1024) Then PredDc:=(A+C) Shr 1
  Else If A<>1024 Then PredDc:=A
  Else PredDc:=C;
 End;
 Block[0]:=SmallInt(Block[0]*Scale+PredDc);
 If Block[0]<0 Then Block[0]:=0 Else Block[0]:=Block[0] Or 1;
 Dc^[H3DcOff[Comp]+X+Y*Wrap]:=Block[0];
 For I:=1 To 7 Do H3Ac^[AcBase1+I]:=Block[I Shl 3];
 For I:=1 To 7 Do H3Ac^[AcBase1+8+I]:=Block[I];
End;

{ h263_decode_block ; 0 = ok, -1 = erreur }
Procedure H3RvInitTab;
Const
 RunLen: Array[0..18,0..1] Of Integer=((0,0),(1,0),(255,0),(3,1),(254,1),(7,3),(
  252,3),(15,7),(248,7),(31,15),(240,15),(63,31),(224,31),(127,63),(192,63),(
  255,127),(128,127),(127,255),(128,255));
 LumLen: Array[0..14] Of Integer=(1,0,2,4,8,16,32,0,64,0,128,0,256,0,512);
 ChrLen: Array[0..14] Of Integer=(1,2,4,0,8,0,16,0,32,0,64,0,128,0,256);
Var I,T,N,L,Idx: LongInt; Cur: LongInt; Code: Int64;
Begin
 If H3RvInit Then Exit; H3RvInit:=True;
 N:=0;
 For I:=0 To 18 Do Begin Cur:=RunLen[I,0]; For T:=0 To RunLen[I,1] Do Begin
  H3RvLumSym[N]:=Cur And 255; Dec(Cur); Inc(N); End; End;
 N:=0;
 For I:=0 To 16 Do Begin Cur:=RunLen[I,0]; For T:=0 To RunLen[I,1] Do Begin
  H3RvChrSym[N]:=Cur And 255; Dec(Cur); Inc(N); End; End;
 Code:=0; Idx:=0;
 For L:=2 To 16 Do Begin
  H3RvLumCnt[L]:=LumLen[L-2]; H3RvLumFirst[L]:=Code Shr (32-L); H3RvLumOff[L]:=
   Idx;
  Code:=Code+(Int64(LumLen[L-2]) Shl (32-L)); Inc(Idx,LumLen[L-2]);
 End;
 Code:=0; Idx:=0;
 For L:=2 To 16 Do Begin
  H3RvChrCnt[L]:=ChrLen[L-2]; H3RvChrFirst[L]:=Code Shr (32-L); H3RvChrOff[L]:=
   Idx;
  Code:=Code+(Int64(ChrLen[L-2]) Shl (32-L)); Inc(Idx,ChrLen[L-2]);
 End;
End;
{ ff_rv_decode_dc ; < 0 = erreur }
Function H3RvDecodeDc(N: LongInt): LongInt;
Var V,L,Start: LongInt;
Begin
 H3RvInitTab;
 Start:=H3Pos; V:=0;
 If N<4 Then Begin
  If H3Show(7)=$7F Then Begin H3Skip(18); H3RvDecodeDc:=255; Exit; End;
  For L:=1 To 16 Do Begin
   V:=V*2+H3Bit;
   If (L>=2) And (H3RvLumCnt[L]>0) And (V>=H3RvLumFirst[L]) And (V-H3RvLumFirst[
    L]<H3RvLumCnt[L]) Then Begin
    H3RvDecodeDc:=H3RvLumSym[H3RvLumOff[L]+V-H3RvLumFirst[L]]; Exit;
   End;
  End;
 End Else Begin
  If H3Show(9)=$1FE Then Begin H3Skip(18); H3RvDecodeDc:=255; Exit; End;
  For L:=1 To 16 Do Begin
   V:=V*2+H3Bit;
   If (L>=2) And (H3RvChrCnt[L]>0) And (V>=H3RvChrFirst[L]) And (V-H3RvChrFirst[
    L]<H3RvChrCnt[L]) Then Begin
    H3RvDecodeDc:=H3RvChrSym[H3RvChrOff[L]+V-H3RvChrFirst[L]]; Exit;
   End;
  End;
 End;
 H3Pos:=Start; H3RvDecodeDc:=-1;
End;

Function H3Block(Var Block: TH3Blk; N,Coded: LongInt): LongInt;
Var
 Level,I,J,Run,Sym,SavedPos,Rl,Is11,Comp,Diff: LongInt; Scan: PEABuffer; Acp:
  Boolean; Retry: Boolean;
 Done: Boolean;
Begin
 H3Block:=-1;
 SavedPos:=H3Pos;
 Scan:=@H3Zigzag; Rl:=0;
 If (H3Aic<>0) And (H3MbIntra<>0) Then Begin
  Rl:=1; I:=0;
  If H3AcPred<>0 Then Begin If H3AicDir<>0 Then Scan:=@H3AltV Else Scan:=
   @H3AltH; End;
 End Else If H3MbIntra<>0 Then Begin
  If H3RvMode=1 Then Begin
   If (H3Rv10Ver=3) And (H3PictType=0) Then Begin
    If N<=3 Then Comp:=0 Else Comp:=N-3;
    Level:=H3RvLastDc[Comp];
    If H3RvFirst[Comp]<>0 Then Begin
     Diff:=H3RvDecodeDc(N);
     If Diff<0 Then Exit;
     Level:=(Level+Diff) And 255;
     H3RvLastDc[Comp]:=Level;
    End Else H3RvFirst[Comp]:=1;
   End Else Begin
    Level:=H3Bits(8);
    If Level=255 Then Level:=128;
   End;
  End Else Begin
   Level:=H3Bits(8);
   If Level=255 Then Level:=128;
  End;
  Block[0]:=Level; I:=1;
 End Else I:=0;
 If Coded=0 Then Begin
  If (H3MbIntra<>0) And (H3Aic<>0) Then Begin
   H3PredAcDc(Block,N); H3BlkLast[N]:=63; H3Block:=0; Exit;
  End;
  H3BlkLast[N]:=I-1; H3Block:=0; Exit;
 End;
 Repeat
  Retry:=False;
  Dec(I);
  Repeat
   If Rl=0 Then Sym:=H3GetVlc(H3VRlInter) Else Sym:=H3GetVlc(H3VRlAic);
   If Sym<0 Then Exit;
   If Sym=102 Then Begin
    If H3Flv>1 Then Begin
     Is11:=H3Bit;
     Run:=H3Bits(7)+1;
     If Is11<>0 Then Level:=H3SBits(11) Else Level:=H3SBits(7);
     If Is11<>0 Then H3Skip(11) Else H3Skip(7);
    End Else Begin
     Run:=H3Bits(7)+1;
     Level:=H3Bits(8); If Level>=128 Then Dec(Level,256);
     If Level=-128 Then Begin
      If H3RvMode=1 Then Begin
       Level:=H3SBits(12); H3Skip(12);
      End Else Begin
       Level:=H3Bits(5);
       Level:=Level Or (H3SBits(6)*32);
       H3Skip(6);
      End;
     End;
    End;
   End Else Begin
    If Rl=0 Then Begin Run:=H3RunInter[Sym]; Level:=H3LevInter[Sym]; End
    Else Begin Run:=H3RunAic[Sym]; Level:=H3LevAic[Sym]; End;
    If H3Bit<>0 Then Level:=-Level;
   End;
   Inc(I,Run);
   If I>=64 Then Begin
    I:=I-Run+((Run-1) And 63)+1;
    If I<64 Then Begin
     Block[Scan^[I]]:=SmallInt(Level);
     Break;
    End;
    If (H3AltInter<>0) And (Rl=0) And (H3MbIntra=0) Then Begin
     Rl:=1; I:=0; H3Pos:=SavedPos; FillChar(Block,SizeOf(Block),0); Retry:=True;
      Break;
    End;
    Exit;
   End;
   J:=Scan^[I];
   Block[J]:=SmallInt(Level);
  Until False;
 Until Not Retry;
 If (H3MbIntra<>0) And (H3Aic<>0) Then Begin
  H3PredAcDc(Block,N); I:=63;
 End;
 H3BlkLast[N]:=I;
 H3Block:=0;
End;

Procedure H3FillMv(M,Mx,My: LongInt);
Begin
 H3SetMv(M,0,Mx); H3SetMv(M,1,My); H3SetMv(M+1,0,Mx); H3SetMv(M+1,1,My);
 H3SetMv(M+H3B8Stride,0,Mx); H3SetMv(M+H3B8Stride,1,My); H3SetMv(M+H3B8Stride+1,
  0,Mx); H3SetMv(M+H3B8Stride+1,1,My);
End;

{ preview_obmc: lit les vecteurs du macrobloc suivant sans consommer le flux }
Procedure H3PreviewObmc;
Var
 Saved,Cbpc,I,Px,Py,Mx,My,M,Xy: LongInt; Ok: Boolean;
Begin
 Saved:=H3Pos;
 Xy:=H3MbX+1+H3MbY*H3MbStride;
 Inc(H3MbX);
 Repeat
  If H3Bit<>0 Then Begin
   M:=H3B8Stride*2*H3MbY+2*H3MbX;
   H3FillMv(M,0,0);
   H3SetMt(Xy,H3_SKIP Or H3_16X16 Or H3_L0);
   Dec(H3MbX); H3Pos:=Saved; Exit;
  End;
  Cbpc:=H3GetVlc(H3VInter);
 Until Cbpc<>20;
 If (Cbpc And 4)<>0 Then H3SetMt(Xy,H3_INTRA)
 Else Begin
  H3GetVlc(H3VCbpy);
  If (Cbpc And 8)<>0 Then Begin
   If H3ModQ<>0 Then Begin
    If H3Bit<>0 Then H3Skip(1) Else H3Skip(5);
   End Else H3Skip(2);
  End;
  If (Cbpc And 16)=0 Then Begin
   H3SetMt(Xy,H3_16X16 Or H3_L0);
   M:=H3PredMotion(0,0,Px,Py);
   Mx:=H3MotionComp(Px);
   My:=H3MotionComp(Py);
   H3FillMv(M,Mx,My);
  End Else Begin
   H3SetMt(Xy,H3_8X8 Or H3_L0);
   For I:=0 To 3 Do Begin
    M:=H3PredMotion(I,0,Px,Py);
    Mx:=H3MotionComp(Px);
    My:=H3MotionComp(Py);
    If (H3Umvplus<>0) And (Mx-Px=1) And (My-Py=1) Then H3Skip(1);
    H3SetMv(M,0,Mx); H3SetMv(M,1,My);
   End;
  End;
 End;
 Dec(H3MbX); H3Pos:=Saved;
End;

Function H3SkipBPart(Cbp: LongInt): LongInt;
Var Db: TH3Blk; I,Mbi: LongInt; Bli: Array[0..5] Of LongInt;
Begin
 H3SkipBPart:=-1;
 Mbi:=H3MbIntra;
 Move(H3BlkLast,Bli,SizeOf(Bli));
 H3MbIntra:=0;
 For I:=0 To 5 Do Begin
  FillChar(Db,SizeOf(Db),0);
  If H3Block(Db,I,Cbp And 32)<0 Then Exit;
  Cbp:=Cbp+Cbp;
 End;
 H3MbIntra:=Mbi;
 Move(Bli,H3BlkLast,SizeOf(Bli));
 H3SkipBPart:=0;
End;

Function H3GetModb(PbFrame: LongInt; Var Cbpb: LongInt): LongInt;
Var C,Mv,I: LongInt;
Begin
 Mv:=1;
 If PbFrame<3 Then Begin
  C:=H3Bit;
  If (PbFrame=2) And (C<>0) Then If H3Bit=0 Then Mv:=1 Else Mv:=0;
 End Else Begin
  I:=0; While (I<4) And (H3Bit<>0) Do Inc(I);
  Mv:=I+1;
  C:=Mv And 1;
  If (Mv And 2)<>0 Then Mv:=1 Else Mv:=0;
 End;
 If C<>0 Then Cbpb:=H3Bits(6);
 H3GetModb:=Mv;
End;

Const H3SliceOk=0; H3SliceErr=-1; H3SliceEnd=-2; H3SliceNoEnd=-3;
 H3InvalidData=-100;

{ ff_h263_decode_mb (images I et P ; les images B ne sont pas prises en charge)
 }
{ set_direct_mv (images B H.263/RV20) }
Procedure H3SetDirectMv;
Var Xy,I,M,Pmx,Pmy,Tpp,Tpb: LongInt; Nx: ^TH3Pic; Col: LongInt;
Procedure One(K: LongInt);
Begin
 M:=H3B8Stride*2*H3MbY+2*H3MbX+(K And 1)+(K Shr 1)*H3B8Stride;
 Pmx:=Nx^.Mv^[(M+4)*2]; Pmy:=Nx^.Mv^[(M+4)*2+1];
 If (Pmx+32>=0) And (Pmx+32<64) Then Begin H3Mv[K,0]:=H3DirScale[0,Pmx+32];
  H3Mv1[K,0]:=H3DirScale[1,Pmx+32]; End
 Else Begin H3Mv[K,0]:=Pmx*Tpb Div Tpp; H3Mv1[K,0]:=Pmx*(Tpb-Tpp) Div Tpp; End;
 If (Pmy+32>=0) And (Pmy+32<64) Then Begin H3Mv[K,1]:=H3DirScale[0,Pmy+32];
  H3Mv1[K,1]:=H3DirScale[1,Pmy+32]; End
 Else Begin H3Mv[K,1]:=Pmy*Tpb Div Tpp; H3Mv1[K,1]:=Pmy*(Tpb-Tpp) Div Tpp; End;
End;
Begin
 Xy:=H3MbX+H3MbY*H3MbStride;
 Nx:=@H3P[H3BwdI];
 Col:=Nx^.Mt^[Xy+2*H3MbStride+1];
 Tpp:=Word(H3PpTime); Tpb:=Word(H3PbTime);
 If (Col And H3_8X8)<>0 Then Begin
  For I:=0 To 3 Do One(I);
 End Else Begin
  One(0);
  For I:=1 To 3 Do Begin H3Mv[I,0]:=H3Mv[0,0]; H3Mv[I,1]:=H3Mv[0,1]; H3Mv1[I,
   0]:=H3Mv1[0,0]; H3Mv1[I,1]:=H3Mv1[0,1]; End;
 End;
 H3MvType:=1;
End;

Function H3DecodeMb: LongInt;
Var
 Cbpc,Cbpy,I,Cbp,Px,Py,Mx,My,Dquant,Xy,PbMvCount,Cbpb,M,V,Left,Bt: LongInt;
Label Done;
Begin
 Xy:=H3MbX+H3MbY*H3MbStride;
 Cbpb:=0; PbMvCount:=0; Cbp:=0; Dquant:=0;
 If H3PictType=2 Then Begin
  M:=H3B8Stride*2*H3MbY+2*H3MbX;
  For I:=0 To 1 Do Begin
   H3MvList:=I;
   H3FillMv(M,0,0);
  End;
  H3MvList:=0;
  Repeat
   Bt:=H3GetVlc(H3VMbB);
   If Bt<0 Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
  Until Bt<>12;
  FillChar(H3Blk,SizeOf(H3Blk),0);
  H3MbSkipped:=0; H3MvDir:=0; H3MvType:=0;
  If Bt>=13 Then Begin
   H3MbIntra:=1;
   Cbpc:=H3GetVlc(H3VCbpcB);
   If Bt=14 Then Dquant:=4 Else Dquant:=0;
  End Else Begin
   H3MbIntra:=0;
   If Bt In [1,2,4,5,7,8,10,11] Then Begin
    Cbpc:=H3GetVlc(H3VCbpcB);
    Cbpy:=H3GetVlc(H3VCbpy);
    If Cbpy<0 Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
    If (H3AltInter=0) Or ((Cbpc And 3)<>3) Then Cbpy:=Cbpy Xor $F;
    Cbp:=(Cbpc And 3) Or (Cbpy Shl 2);
   End Else Cbp:=0;
   If Bt In [2,5,8,11] Then H3Dquant;
   H3SetMt(Xy,H3_16X16);
   If Bt<=2 Then Begin
    H3MvDir:=3; H3SetDirectMv;
   End Else Begin
    If Bt In [3,4,5,9,10,11] Then Begin
     H3MvList:=0;
     H3PredMotion(0,0,Px,Py);
     Mx:=H3MotionComp(Px);
     If Mx>=$FFFF Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
     My:=H3MotionComp(Py);
     If My>=$FFFF Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
     If (H3Umvplus<>0) And (Mx-Px=1) And (My-Py=1) Then H3Skip(1);
     H3Mv[0,0]:=Mx; H3Mv[0,1]:=My;
     H3FillMv(M,Mx,My);
     H3MvDir:=1;
    End;
    If Bt In [6,7,8,9,10,11] Then Begin
     H3MvList:=1;
     H3PredMotion(0,1,Px,Py);
     Mx:=H3MotionComp(Px);
     If Mx>=$FFFF Then Begin H3MvList:=0; H3DecodeMb:=H3SliceErr; Exit; End;
     My:=H3MotionComp(Py);
     If My>=$FFFF Then Begin H3MvList:=0; H3DecodeMb:=H3SliceErr; Exit; End;
     If (H3Umvplus<>0) And (Mx-Px=1) And (My-Py=1) Then H3Skip(1);
     H3Mv1[0,0]:=Mx; H3Mv1[0,1]:=My;
     H3FillMv(M,Mx,My);
     H3MvList:=0;
     H3MvDir:=H3MvDir Or 2;
    End;
   End;
  End;
 End Else
 If H3PictType=1 Then Begin
  Repeat
   If H3Bit<>0 Then Begin
    H3MbIntra:=0;
    For I:=0 To 5 Do H3BlkLast[I]:=-1;
    H3MvType:=0;
    H3SetMt(Xy,H3_SKIP Or H3_16X16 Or H3_L0);
    H3Mv[0,0]:=0; H3Mv[0,1]:=0;
    If (H3Obmc Or H3Loop)=0 Then H3MbSkipped:=1 Else H3MbSkipped:=0;
    Goto Done;
   End;
   Cbpc:=H3GetVlc(H3VInter);
   If Cbpc<0 Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
  Until Cbpc<>20;
  FillChar(H3Blk,SizeOf(H3Blk),0);
  Dquant:=Cbpc And 8;
  If (Cbpc And 4)<>0 Then H3MbIntra:=1 Else H3MbIntra:=0;
  If H3MbIntra=0 Then Begin
   If (H3PbFrame<>0) And (H3Bit<>0) Then PbMvCount:=H3GetModb(H3PbFrame,Cbpb);
   Cbpy:=H3GetVlc(H3VCbpy);
   If Cbpy<0 Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
   If (H3AltInter=0) Or ((Cbpc And 3)<>3) Then Cbpy:=Cbpy Xor $F;
   Cbp:=(Cbpc And 3) Or (Cbpy Shl 2);
   If Dquant<>0 Then H3Dquant;
   If (Cbpc And 16)=0 Then Begin
    H3SetMt(Xy,H3_16X16 Or H3_L0);
    H3MvType:=0;
    H3PredMotion(0,0,Px,Py);
    Mx:=H3MotionComp(Px);
    If Mx>=$FFFF Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
    My:=H3MotionComp(Py);
    If My>=$FFFF Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
    H3Mv[0,0]:=Mx; H3Mv[0,1]:=My;
    If (H3Umvplus<>0) And (Mx-Px=1) And (My-Py=1) Then H3Skip(1);
   End Else Begin
    H3SetMt(Xy,H3_8X8 Or H3_L0);
    H3MvType:=1;
    For I:=0 To 3 Do Begin
     M:=H3PredMotion(I,0,Px,Py);
     Mx:=H3MotionComp(Px);
     If Mx>=$FFFF Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
     My:=H3MotionComp(Py);
     If My>=$FFFF Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
     H3Mv[I,0]:=Mx; H3Mv[I,1]:=My;
     If (H3Umvplus<>0) And (Mx-Px=1) And (My-Py=1) Then H3Skip(1);
     H3SetMv(M,0,Mx); H3SetMv(M,1,My);
    End;
   End;
  End;
 End Else Begin
  Repeat
   Cbpc:=H3GetVlc(H3VIntra);
   If Cbpc<0 Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
  Until Cbpc<>8;
  FillChar(H3Blk,SizeOf(H3Blk),0);
  Dquant:=Cbpc And 4;
  H3MbIntra:=1;
 End;
 If H3MbIntra<>0 Then Begin
  H3MvType:=0;
  H3SetMt(Xy,H3_INTRA);
  If H3Aic<>0 Then Begin
   H3AcPred:=H3Bit;
   If H3AcPred<>0 Then Begin
    H3SetMt(Xy,H3_INTRA Or H3_ACPRED);
    H3AicDir:=H3Bit;
   End;
  End Else H3AcPred:=0;
  If (H3PbFrame<>0) And (H3Bit<>0) Then PbMvCount:=H3GetModb(H3PbFrame,Cbpb);
  Cbpy:=H3GetVlc(H3VCbpy);
  If Cbpy<0 Then Begin H3DecodeMb:=H3SliceErr; Exit; End;
  Cbp:=(Cbpc And 3) Or (Cbpy Shl 2);
  If Dquant<>0 Then H3Dquant;
  If H3PbFrame<>0 Then Inc(PbMvCount);
 End;
 While PbMvCount>0 Do Begin
  Dec(PbMvCount);
  H3DecMotion(0,1); H3DecMotion(0,1);
 End;
 For I:=0 To 5 Do Begin
  If H3Block(H3Blk[I],I,Cbp And 32)<0 Then Begin H3DecodeMb:=-1; Exit; End;
  Cbp:=Cbp+Cbp;
 End;
 If (H3PbFrame<>0) And (H3SkipBPart(Cbpb)<0) Then Begin H3DecodeMb:=-1; Exit;
  End;
 If (H3Obmc<>0) And (H3MbIntra=0) Then
  If (H3PictType=1) And (H3MbX+1<H3MbW) And (H3MbNumLeft<>1) Then H3PreviewObmc;
Done:
 If H3Left<0 Then Begin H3DecodeMb:=H3InvalidData; Exit; End;
 V:=H3Show(16);
 Left:=H3Left;
 If Left<16 Then V:=V Shr (16-Left);
 If V=0 Then H3DecodeMb:=H3SliceEnd Else H3DecodeMb:=H3SliceOk;
End;

{ en-tete d'image H.263 (ff_h263_decode_picture_header) ; < 0 = erreur }
Function H3PicHeader: LongInt;
Var Format,Width,Height,I,Ufep,Aspect,StartCode,Gcd,A,B,T: LongInt;
Begin
 H3PicHeader:=-1;
 H3Align;
 StartCode:=H3Bits(14);
 I:=H3Left;
 While I>24 Do Begin
  StartCode:=((StartCode Shl 8) Or H3Bits(8)) And $003FFFFF;
  If StartCode=$20 Then Break;
  Dec(I,8);
 End;
 If StartCode<>$20 Then Exit;
 I:=H3Bits(8);
 Dec(I,(I-(H3PicNum And 255)+128) And -256);
 H3PicNum:=(H3PicNum And -256)+I;
 If H3Bit<>1 Then Exit;
 If H3Bit<>0 Then Exit;
 H3Skip(3);
 Format:=H3Bits(3);
 If (Format<>7) And (Format<>6) Then Begin
  H3Plus:=0;
  Width:=H3Format[Format*2]; Height:=H3Format[Format*2+1];
  If Width=0 Then Exit;
  H3PictType:=H3Bit;
  H3LongVec:=H3Bit;
  If H3Bit<>0 Then Exit;
  H3Obmc:=H3Bit;
  H3PbFrame:=H3Bit;
  H3Qscale:=H3Bits(5); H3ChromaQscale:=H3Qscale;
  H3Skip(1);
  H3Wd:=Width; H3Ht:=Height;
  H3Aspect[0]:=12; H3Aspect[1]:=11;
  H3FpsN:=30000; H3FpsD:=1001;
 End Else Begin
  H3Plus:=1;
  Ufep:=H3Bits(3);
  If Ufep=1 Then Begin
   Format:=H3Bits(3);
   H3CustomPcf:=H3Bit;
   H3Umvplus:=H3Bit;
   H3Skip(1);
   H3Obmc:=H3Bit;
   H3Aic:=H3Bit;
   H3Loop:=H3Bit;
   H3SliceStruct:=H3Bit;
   H3Skip(1);
   H3Skip(1);
   H3AltInter:=H3Bit;
   H3ModQ:=H3Bit;
   If H3ModQ<>0 Then H3ChromaTab:=True;
   H3Skip(1);
   H3Skip(3);
  End Else If Ufep<>0 Then Exit;
  T:=H3Bits(3);
  Case T Of
   0: H3PictType:=0;
   1: H3PictType:=1;
   2: Begin H3PictType:=1; H3PbFrame:=3; End;
   3: H3PictType:=2;
   7: H3PictType:=0;
  Else Exit;
  End;
  H3Skip(2);
  H3NoRounding:=H3Bit;
  H3Skip(4);
  If Ufep<>0 Then Begin
   If Format=6 Then Begin
    Aspect:=H3Bits(4);
    Width:=(H3Bits(9)+1)*4;
    H3Bit;
    Height:=H3Bits(9)*4;
    If Aspect=15 Then Begin H3Aspect[0]:=H3Bits(8); H3Aspect[1]:=H3Bits(8); End
    Else Case Aspect Of
     1: Begin H3Aspect[0]:=1; H3Aspect[1]:=1; End;
     2: Begin H3Aspect[0]:=12; H3Aspect[1]:=11; End;
     3: Begin H3Aspect[0]:=10; H3Aspect[1]:=11; End;
     4: Begin H3Aspect[0]:=16; H3Aspect[1]:=11; End;
     5: Begin H3Aspect[0]:=40; H3Aspect[1]:=33; End;
    Else Begin H3Aspect[0]:=0; H3Aspect[1]:=1; End;
    End;
   End Else Begin
    Width:=H3Format[Format*2]; Height:=H3Format[Format*2+1];
    H3Aspect[0]:=12; H3Aspect[1]:=11;
   End;
   If (Width=0) Or (Height=0) Then Exit;
   H3Wd:=Width; H3Ht:=Height;
   If H3CustomPcf<>0 Then Begin
    H3FpsN:=1800000; H3FpsD:=1000+H3Bit;
    H3FpsD:=H3FpsD*H3Bits(7);
    If H3FpsD=0 Then Exit;
    A:=H3FpsD; B:=H3FpsN;
    While B<>0 Do Begin Gcd:=A Mod B; A:=B; B:=Gcd; End;
    H3FpsD:=H3FpsD Div A; H3FpsN:=H3FpsN Div A;
   End Else Begin H3FpsN:=30000; H3FpsD:=1001; End;
  End;
  If H3CustomPcf<>0 Then H3Skip(2);
  If Ufep<>0 Then Begin
   If H3Umvplus<>0 Then If H3Bit=0 Then H3Skip(1);
   If H3SliceStruct<>0 Then Begin H3Bit; H3Bit; End;
   If H3PictType=2 Then Begin
    H3Skip(4);
    If Ufep=1 Then H3Skip(4);
   End;
  End;
  H3Qscale:=H3Bits(5);
 End;
 If (H3Wd<=0) Or (H3Ht<=0) Or (H3Wd>32768) Or (H3Ht>32768) Or (Int64(H3Wd)*
  H3Ht>268435456) Then Exit;
 If (H3Wd*H3Ht Div 256 Div 8)>H3Left Then Begin H3PicHeader:=H3InvalidData;
  Exit; End;
 H3MbW:=(H3Wd+15) Div 16; H3MbH:=(H3Ht+15) Div 16; H3MbNum:=H3MbW*H3MbH;
 If H3PbFrame<>0 Then Begin
  H3Skip(3);
  If H3CustomPcf<>0 Then H3Skip(2);
  H3Skip(2);
 End;
 If H3PictType<>2 Then Begin
  H3Time:=H3PicNum;
  H3PpTime:=H3Time-H3LastNonB;
  H3LastNonB:=H3Time;
 End Else Begin
  H3Time:=H3PicNum;
  H3PbTime:=H3PpTime-(H3LastNonB-H3Time);
  If (H3PpTime<=H3PbTime) Or (H3PpTime<=H3PpTime-H3PbTime) Or (H3PpTime<=0) Then
   Begin H3PpTime:=2; H3PbTime:=1; End;
 End;
 { PEI }
 If H3Left<=0 Then Begin H3PicHeader:=H3InvalidData; Exit; End;
 While H3Bit<>0 Do Begin
  H3Skip(8);
  If H3Left<=0 Then Begin H3PicHeader:=H3InvalidData; Exit; End;
 End;
 If H3SliceStruct<>0 Then Begin
  If H3Bit<>1 Then Exit;
  H3DecodeMba;
  If H3Bit<>1 Then Exit;
 End;
 H3PicHeader:=0;
End;

{ en-tete Sorenson Spark (ff_flv_decode_picture_header) }
Function H3FlvHeader: LongInt;
Var Format,Width,Height,T: LongInt;
Begin
 H3FlvHeader:=-1;
 If H3Bits(17)<>1 Then Exit;
 Format:=H3Bits(5);
 If (Format<>0) And (Format<>1) Then Exit;
 H3Flv:=Format+1;
 H3PicNum:=H3Bits(8);
 Format:=H3Bits(3);
 Case Format Of
  0: Begin Width:=H3Bits(8); Height:=H3Bits(8); End;
  1: Begin Width:=H3Bits(16); Height:=H3Bits(16); End;
  2: Begin Width:=352; Height:=288; End;
  3: Begin Width:=176; Height:=144; End;
  4: Begin Width:=128; Height:=96; End;
  5: Begin Width:=320; Height:=240; End;
  6: Begin Width:=160; Height:=120; End;
 Else Begin Width:=0; Height:=0; End;
 End;
 If (Width<=0) Or (Height<=0) Then Exit;
 H3Wd:=Width; H3Ht:=Height;
 T:=H3Bits(2);
 H3PictType:=T; If H3PictType>2 Then H3PictType:=3;
 If T>1 Then H3Droppable:=1 Else H3Droppable:=0;
 If H3Droppable<>0 Then H3PictType:=1;
 H3Skip(1);
 H3Qscale:=H3Bits(5); H3ChromaQscale:=H3Qscale;
 H3Plus:=0; H3LongVec:=0;
 If H3Left<=0 Then Begin H3FlvHeader:=H3InvalidData; Exit; End;
 While H3Bit<>0 Do Begin
  H3Skip(8);
  If H3Left<=0 Then Begin H3FlvHeader:=H3InvalidData; Exit; End;
 End;
 H3MbW:=(H3Wd+15) Div 16; H3MbH:=(H3Ht+15) Div 16; H3MbNum:=H3MbW*H3MbH;
 H3FlvHeader:=0;
End;

{ en-tete Intel H.263 (ff_intel_h263_decode_picture_header) }
Function H3IntelHeader: LongInt;
Var Fmt,Ar,Width,Height: LongInt;
Begin
 H3IntelHeader:=-1;
 If H3Left=64 Then Exit; { trame factice }
 If H3Bits(22)<>$20 Then Exit;
 H3PicNum:=H3Bits(8);
 If H3Bit<>1 Then Exit;
 If H3Bit<>0 Then Exit;
 H3Skip(3);
 Fmt:=H3Bits(3);
 If (Fmt=0) Or (Fmt=6) Then Exit;
 H3Plus:=0;
 H3PictType:=H3Bit;
 H3LongVec:=H3Bit;
 If H3Bit<>0 Then Exit;
 H3Obmc:=H3Bit;
 H3PbFrame:=H3Bit;
 If Fmt<6 Then Begin
  Width:=H3Format[Fmt*2]; Height:=H3Format[Fmt*2+1];
  If Width=0 Then Exit;
  H3Wd:=Width; H3Ht:=Height;
  H3Aspect[0]:=12; H3Aspect[1]:=11;
 End Else Begin
  Fmt:=H3Bits(3);
  If (Fmt=0) Or (Fmt=7) Then Exit;
  H3Skip(2);
  H3Loop:=H3Bit;
  H3Skip(1);
  If H3Bit<>0 Then H3PbFrame:=2;
  H3Skip(5); H3Skip(5);
 End;
 If Fmt=6 Then Begin
  Ar:=H3Bits(4);
  H3Skip(9); H3Bit; H3Skip(9);
  If Ar=15 Then Begin H3Aspect[0]:=H3Bits(8); H3Aspect[1]:=H3Bits(8); End
  Else Case Ar Of
   1: Begin H3Aspect[0]:=1; H3Aspect[1]:=1; End;
   2: Begin H3Aspect[0]:=12; H3Aspect[1]:=11; End;
   3: Begin H3Aspect[0]:=10; H3Aspect[1]:=11; End;
   4: Begin H3Aspect[0]:=16; H3Aspect[1]:=11; End;
   5: Begin H3Aspect[0]:=40; H3Aspect[1]:=33; End;
  Else Begin H3Aspect[0]:=0; H3Aspect[1]:=1; End;
  End;
 End;
 H3Qscale:=H3Bits(5); H3ChromaQscale:=H3Qscale;
 H3Skip(1);
 If H3PbFrame<>0 Then Begin H3Skip(3); H3Skip(2); End;
 If (H3Wd<=0) Or (H3Ht<=0) Then Exit;
 H3MbW:=(H3Wd+15) Div 16; H3MbH:=(H3Ht+15) Div 16; H3MbNum:=H3MbW*H3MbH;
 If H3PictType<>2 Then Begin
  H3Time:=H3PicNum; H3PpTime:=H3Time-H3LastNonB; H3LastNonB:=H3Time;
 End;
 If H3Left<=0 Then Begin H3IntelHeader:=H3InvalidData; Exit; End;
 While H3Bit<>0 Do Begin
  H3Skip(8);
  If H3Left<=0 Then Begin H3IntelHeader:=H3InvalidData; Exit; End;
 End;
 H3IntelHeader:=0;
End;

{ ---- reconstruction (mpegvideo_motion.c, mpv_reconstruct_mb_template.c,
 h263dsp.c, simple_idct) ---- }
Var H3Emu: Array[0..24*24-1] Of Byte;
 H3ObmcBuf: Array[0..4,0..63] Of Byte;

{ bloc BW x BH copie avec recopie des bords (emulated_edge_mc) ; Dst de pas 24 }
Procedure H3Fetch(Plane: PEABuffer; PW,PH,PStride,X,Y,BW,BH: LongInt);
Var I,J,XX,YY: LongInt;
Begin
 If (X>=0) And (Y>=0) And (X+BW<=PW) And (Y+BH<=PH) Then Begin
  For J:=0 To BH-1 Do Move(Plane^[(Y+J)*PStride+X],H3Emu[J*24],BW);
  Exit;
 End;
 For J:=0 To BH-1 Do Begin
  YY:=Y+J; If YY<0 Then YY:=0 Else If YY>=PH Then YY:=PH-1;
  For I:=0 To BW-1 Do Begin
   XX:=X+I; If XX<0 Then XX:=0 Else If XX>=PW Then XX:=PW-1;
   H3Emu[J*24+I]:=Plane^[YY*PStride+XX];
  End;
 End;
End;

{ interpolation demi-pel de H3Emu vers Dst (W x H) }
Procedure H3Pel(Dst: PEABuffer; DOff,DStr,Dxy,W,H,NoRnd: LongInt);
Var X,Y,A,B,C,D,R1,R2,V: LongInt;
Begin
 R1:=1-NoRnd; R2:=2-NoRnd;
 For Y:=0 To H-1 Do
  For X:=0 To W-1 Do Begin
   A:=H3Emu[Y*24+X];
   Case Dxy Of
    0: V:=A;
    1: Begin B:=H3Emu[Y*24+X+1]; V:=(A+B+R1) Shr 1; End;
    2: Begin C:=H3Emu[(Y+1)*24+X]; V:=(A+C+R1) Shr 1; End;
   Else Begin
    B:=H3Emu[Y*24+X+1]; C:=H3Emu[(Y+1)*24+X]; D:=H3Emu[(Y+1)*24+X+1];
    V:=(A+B+C+D+R2) Shr 2;
   End;
   End;
   If H3Avg<>0 Then V:=(Dst^[DOff+Y*DStr+X]+V+1) Shr 1;
   Dst^[DOff+Y*DStr+X]:=V;
  End;
End;

{ hpel_motion: bloc 8x8 ; Dst/DOff/DStr destination }
Procedure H3HpelMotion(Dst: PEABuffer; DOff,DStr: LongInt; Ref: PEABuffer; SrcX,
 SrcY,Mx,My,NoRnd: LongInt);
Var Dxy: LongInt;
Begin
 Dxy:=0;
 Inc(SrcX,H3Sar(Mx,1)); Inc(SrcY,H3Sar(My,1));
 SrcX:=H3Clip(SrcX,-16,H3Wd);
 If SrcX<>H3Wd Then Dxy:=Dxy Or (Mx And 1);
 SrcY:=H3Clip(SrcY,-16,H3Ht);
 If SrcY<>H3Ht Then Dxy:=Dxy Or ((My And 1) Shl 1);
 H3Fetch(Ref,H3HEdge,H3VEdge,H3LY,SrcX,SrcY,9,9);
 H3Pel(Dst,DOff,DStr,Dxy,8,8,NoRnd);
End;

{ chroma_4mv_motion }
Procedure H3Chroma4Mv(RefU,RefV: PEABuffer; DstU,DstV: PEABuffer; DOff: LongInt;
 Mx,My,NoRnd: LongInt);
Var SrcX,SrcY,Dxy: LongInt;
Begin
 Mx:=H3RoundTab[Mx And 15]+H3Sar(Mx,3);
 My:=H3RoundTab[My And 15]+H3Sar(My,3);
 Dxy:=((My And 1) Shl 1) Or (Mx And 1);
 Mx:=H3Sar(Mx,1); My:=H3Sar(My,1);
 SrcX:=H3MbX*8+Mx; SrcY:=H3MbY*8+My;
 SrcX:=H3Clip(SrcX,-8,H3Wd Shr 1);
 If SrcX=(H3Wd Shr 1) Then Dxy:=Dxy And Not 1;
 SrcY:=H3Clip(SrcY,-8,H3Ht Shr 1);
 If SrcY=(H3Ht Shr 1) Then Dxy:=Dxy And Not 2;
 H3Fetch(RefU,H3HEdge Shr 1,H3VEdge Shr 1,H3LC,SrcX,SrcY,9,9);
 H3Pel(DstU,DOff,H3LC,Dxy,8,8,NoRnd);
 H3Fetch(RefV,H3HEdge Shr 1,H3VEdge Shr 1,H3LC,SrcX,SrcY,9,9);
 H3Pel(DstV,DOff,H3LC,Dxy,8,8,NoRnd);
End;

{ vecteur 16x16 sur les trois composantes (mpeg_motion_internal, sortie H.263) }
Procedure H3MpegMotion(Ref: Integer; Mx,My,NoRnd: LongInt);
Var Dxy,UvDxy,SrcX,SrcY,UvX,UvY,DOff,COff: LongInt; P: ^TH3Pic;
Begin
 P:=@H3P[Ref];
 Dxy:=((My And 1) Shl 1) Or (Mx And 1);
 SrcX:=H3MbX*16+H3Sar(Mx,1); SrcY:=H3MbY*16+H3Sar(My,1);
 UvDxy:=Dxy Or (My And 2) Or ((Mx And 2) Shr 1);
 UvX:=H3Sar(SrcX,1); UvY:=H3Sar(SrcY,1);
 DOff:=H3MbY*16*H3LY+H3MbX*16; COff:=H3MbY*8*H3LC+H3MbX*8;
 H3Fetch(P^.Y,H3HEdge,H3VEdge,H3LY,SrcX,SrcY,17,17);
 H3Pel(H3P[H3CurI].Y,DOff,H3LY,Dxy,16,16,NoRnd);
 H3Fetch(P^.U,H3HEdge Shr 1,H3VEdge Shr 1,H3LC,UvX,UvY,9,9);
 H3Pel(H3P[H3CurI].U,COff,H3LC,UvDxy,8,8,NoRnd);
 H3Fetch(P^.V,H3HEdge Shr 1,H3VEdge Shr 1,H3LC,UvX,UvY,9,9);
 H3Pel(H3P[H3CurI].V,COff,H3LC,UvDxy,8,8,NoRnd);
End;

Procedure H3PutObmc(Dst: PEABuffer; DOff,DStr: LongInt);
Procedure F(X,Y,T,L,M,R,B: LongInt);
Var I: LongInt;
Begin
 I:=Y*8+X;
 Dst^[DOff+Y*DStr+X]:=(T*H3ObmcBuf[1,I]+L*H3ObmcBuf[2,I]+M*H3ObmcBuf[0,I]+R*
  H3ObmcBuf[3,I]+B*H3ObmcBuf[4,I]+4) Shr 3;
End;
Procedure F4(X,Y,T,L,M,R,B: LongInt);
Begin F(X,Y,T,L,M,R,B); F(X+1,Y,T,L,M,R,B); F(X,Y+1,T,L,M,R,B); F(X+1,Y+1,T,L,M,
 R,B); End;
Begin
 F(0,0,2,2,4,0,0); F(1,0,2,1,5,0,0); F4(2,0,2,1,5,0,0); F4(4,0,2,0,5,1,0); F(6,
  0,2,0,5,1,0); F(7,0,2,0,4,2,0);
 F(0,1,1,2,5,0,0); F(1,1,1,2,5,0,0); F(6,1,1,0,5,2,0); F(7,1,1,0,5,2,0);
 F4(0,2,1,2,5,0,0); F4(2,2,1,1,6,0,0); F4(4,2,1,0,6,1,0); F4(6,2,1,0,5,2,0);
 F4(0,4,0,2,5,0,1); F4(2,4,0,1,6,0,1); F4(4,4,0,0,6,1,1); F4(6,4,0,0,5,2,1);
 F(0,6,0,2,5,0,1); F(1,6,0,2,5,0,1); F4(2,6,0,1,5,0,2); F4(4,6,0,0,5,1,2); F(6,
  6,0,0,5,2,1); F(7,6,0,0,5,2,1);
 F(0,7,0,2,4,0,2); F(1,7,0,1,5,0,2); F(6,7,0,0,5,1,2); F(7,7,0,0,4,2,2);
End;

{ apply_obmc }
Procedure H3ApplyObmc(Ref: Integer; NoRnd: LongInt);
Var
 MvC: Array[0..3,0..3,0..1] Of LongInt; MotXy,Mot,Xy,I,J,X,Y,Mx,My: LongInt;
  Mvs: Array[0..4,0..1] Of LongInt;
 P: ^TH3Pic; Cur: ^TH3Pic; Tmp: Array[0..63] Of Byte;
Begin
 P:=@H3P[Ref]; Cur:=@H3P[H3CurI];
 Xy:=H3MbX+H3MbY*H3MbStride;
 Mot:=H3B8Stride; MotXy:=H3MbX*2+H3MbY*2*Mot;
 For J:=0 To 1 Do Begin MvC[1,1,J]:=H3MvAt(MotXy,J); MvC[1,2,J]:=H3MvAt(MotXy+1,
  J);
  MvC[2,1,J]:=H3MvAt(MotXy+Mot,J); MvC[2,2,J]:=H3MvAt(MotXy+Mot+1,J);
  MvC[3,1,J]:=H3MvAt(MotXy+Mot,J); MvC[3,2,J]:=H3MvAt(MotXy+Mot+1,J); End;
 If (H3MbY=0) Or ((H3Mt(Xy-H3MbStride) And 7)<>0) Then
  For J:=0 To 1 Do Begin MvC[0,1,J]:=MvC[1,1,J]; MvC[0,2,J]:=MvC[1,2,J]; End
 Else
  For J:=0 To 1 Do Begin MvC[0,1,J]:=H3MvAt(MotXy-Mot,J); MvC[0,2,J]:=H3MvAt(
   MotXy-Mot+1,J); End;
 If (H3MbX=0) Or ((H3Mt(Xy-1) And 7)<>0) Then
  For J:=0 To 1 Do Begin MvC[1,0,J]:=MvC[1,1,J]; MvC[2,0,J]:=MvC[2,1,J]; End
 Else
  For J:=0 To 1 Do Begin MvC[1,0,J]:=H3MvAt(MotXy-1,J); MvC[2,0,J]:=H3MvAt(
   MotXy-1+Mot,J); End;
 If (H3MbX+1>=H3MbW) Or ((H3Mt(Xy+1) And 7)<>0) Then
  For J:=0 To 1 Do Begin MvC[1,3,J]:=MvC[1,2,J]; MvC[2,3,J]:=MvC[2,2,J]; End
 Else
  For J:=0 To 1 Do Begin MvC[1,3,J]:=H3MvAt(MotXy+2,J); MvC[2,3,J]:=H3MvAt(
   MotXy+2+Mot,J); End;
 Mx:=0; My:=0;
 For I:=0 To 3 Do Begin
  X:=(I And 1)+1; Y:=(I Shr 1)+1;
  For J:=0 To 1 Do Begin
   Mvs[0,J]:=SmallInt(MvC[Y,X,J]); Mvs[1,J]:=SmallInt(MvC[Y-1,X,J]); Mvs[2,J]:=
    SmallInt(MvC[Y,X-1,J]);
   Mvs[3,J]:=SmallInt(MvC[Y,X+1,J]); Mvs[4,J]:=SmallInt(MvC[Y+1,X,J]);
  End;
  For J:=0 To 4 Do Begin
   H3HpelMotion(@H3ObmcBuf[J],0,8,P^.Y,H3MbX*16+(I And 1)*8,H3MbY*16+(I Shr 1)*
    8,Mvs[J,0],Mvs[J,1],NoRnd);
  End;
  H3PutObmc(Cur^.Y,H3MbY*16*H3LY+H3MbX*16+(I And 1)*8+(I Shr 1)*8*H3LY,H3LY);
  Inc(Mx,Mvs[0,0]); Inc(My,Mvs[0,1]);
 End;
 H3Chroma4Mv(P^.U,P^.V,Cur^.U,Cur^.V,H3MbY*8*H3LC+H3MbX*8,Mx,My,NoRnd);
End;

{ apply_8x8 (sans OBMC) }
Procedure H3Apply8x8(Ref: Integer; NoRnd: LongInt);
Var I,Mx,My: LongInt; P,Cur: ^TH3Pic;
Begin
 P:=@H3P[Ref]; Cur:=@H3P[H3CurI];
 Mx:=0; My:=0;
 For I:=0 To 3 Do Begin
  H3HpelMotion(Cur^.Y,H3MbY*16*H3LY+H3MbX*16+(I And 1)*8+(I Shr 1)*8*H3LY,H3LY,
   P^.Y,
   H3MbX*16+(I And 1)*8,H3MbY*16+(I Shr 1)*8,H3Mv[I,0],H3Mv[I,1],NoRnd);
  Inc(Mx,H3Mv[I,0]); Inc(My,H3Mv[I,1]);
 End;
 H3Chroma4Mv(P^.U,P^.V,Cur^.U,Cur^.V,H3MbY*8*H3LC+H3MbX*8,Mx,My,NoRnd);
End;

{ IDCT simple 8 bits : Add=0 ecrit, Add=1 ajoute ; Dest = plan, Off decalage }
Procedure H3Idct(Var Blk: TH3Blk; Dest: PEABuffer; Off,Stride: LongInt; Add:
 Boolean);
Const W1=22725; W2=21407; W3=19266; W4=16383; W5=12873; W6=8867; W7=4520;
Var
 I,K: Integer; A0,A1,A2,A3,B0,B1,B2,B3: Int64; R: Array[0..7] Of Int64; V:
  Int64;
Procedure Put(Col,Row: Integer; X: Int64);
Var D: Int64;
Begin
 X:=AVSar(X,20);
 If Add Then X:=X+Dest^[Off+Row*Stride+Col];
 If X<0 Then X:=0; If X>255 Then X:=255;
 Dest^[Off+Row*Stride+Col]:=X;
End;
Begin
 For I:=0 To 7 Do Begin
  For K:=0 To 7 Do R[K]:=Blk[I*8+K];
  If (R[1] Or R[2] Or R[3] Or R[4] Or R[5] Or R[6] Or R[7])=0 Then Begin
   V:=SmallInt(R[0]*8); For K:=0 To 7 Do Blk[I*8+K]:=V;
  End Else Begin
   A0:=W4*R[0]+(1 Shl 10); A1:=A0; A2:=A0; A3:=A0;
   Inc(A0,W2*R[2]); Inc(A1,W6*R[2]); Dec(A2,W6*R[2]); Dec(A3,W2*R[2]);
   B0:=W1*R[1]+W3*R[3]; B1:=W3*R[1]-W7*R[3]; B2:=W5*R[1]-W1*R[3]; B3:=W7*R[1]-
    W5*R[3];
   If (R[4] Or R[5] Or R[6] Or R[7])<>0 Then Begin
    Inc(A0,W4*R[4]+W6*R[6]); Inc(A1,-W4*R[4]-W2*R[6]); Inc(A2,-W4*R[4]+W2*R[6]);
     Inc(A3,W4*R[4]-W6*R[6]);
    Inc(B0,W5*R[5]+W7*R[7]); Inc(B1,-W1*R[5]-W5*R[7]); Inc(B2,W7*R[5]+W3*R[7]);
     Inc(B3,W3*R[5]-W1*R[7]);
   End;
   Blk[I*8+0]:=SmallInt(AVSar(A0+B0,11)); Blk[I*8+7]:=SmallInt(AVSar(A0-B0,11));
   Blk[I*8+1]:=SmallInt(AVSar(A1+B1,11)); Blk[I*8+6]:=SmallInt(AVSar(A1-B1,11));
   Blk[I*8+2]:=SmallInt(AVSar(A2+B2,11)); Blk[I*8+5]:=SmallInt(AVSar(A2-B2,11));
   Blk[I*8+3]:=SmallInt(AVSar(A3+B3,11)); Blk[I*8+4]:=SmallInt(AVSar(A3-B3,11));
  End;
 End;
 For I:=0 To 7 Do Begin
  For K:=0 To 7 Do R[K]:=Blk[K*8+I];
  A0:=W4*(R[0]+32); A1:=A0; A2:=A0; A3:=A0;
  Inc(A0,W2*R[2]); Inc(A1,W6*R[2]); Dec(A2,W6*R[2]); Dec(A3,W2*R[2]);
  B0:=W1*R[1]+W3*R[3]; B1:=W3*R[1]-W7*R[3]; B2:=W5*R[1]-W1*R[3]; B3:=W7*R[1]-W5*
   R[3];
  If R[4]<>0 Then Begin Inc(A0,W4*R[4]); Dec(A1,W4*R[4]); Dec(A2,W4*R[4]); Inc(
   A3,W4*R[4]); End;
  If R[5]<>0 Then Begin Inc(B0,W5*R[5]); Dec(B1,W1*R[5]); Inc(B2,W7*R[5]); Inc(
   B3,W3*R[5]); End;
  If R[6]<>0 Then Begin Inc(A0,W6*R[6]); Dec(A1,W2*R[6]); Inc(A2,W2*R[6]); Dec(
   A3,W6*R[6]); End;
  If R[7]<>0 Then Begin Inc(B0,W7*R[7]); Dec(B1,W5*R[7]); Inc(B2,W3*R[7]); Dec(
   B3,W1*R[7]); End;
  Put(I,0,A0+B0); Put(I,1,A1+B1); Put(I,2,A2+B2); Put(I,3,A3+B3);
  Put(I,4,A3-B3); Put(I,5,A2-B2); Put(I,6,A1-B1); Put(I,7,A0-B0);
 End;
End;

Procedure H3DequantIntra(Var Blk: TH3Blk; N,Q: LongInt);
Var I,Level,Qmul,Qadd,NC: LongInt;
Begin
 Qmul:=Q Shl 1;
 If H3Aic=0 Then Begin
  If N<4 Then Blk[0]:=SmallInt(Blk[0]*H3YDcScale) Else Blk[0]:=SmallInt(Blk[0]*
   H3CDcScale);
  Qadd:=(Q-1) Or 1;
 End Else Qadd:=0;
 If H3AcPred<>0 Then NC:=63 Else NC:=H3RasterEnd[H3BlkLast[N]];
 For I:=1 To NC Do Begin
  Level:=Blk[I];
  If Level<>0 Then Begin
   If Level<0 Then Level:=Level*Qmul-Qadd Else Level:=Level*Qmul+Qadd;
   Blk[I]:=SmallInt(Level);
  End;
 End;
End;

Procedure H3DequantInter(Var Blk: TH3Blk; N,Q: LongInt);
Var I,Level,Qmul,Qadd,NC: LongInt;
Begin
 Qadd:=(Q-1) Or 1; Qmul:=Q Shl 1;
 NC:=H3RasterEnd[H3BlkLast[N]];
 For I:=0 To NC Do Begin
  Level:=Blk[I];
  If Level<>0 Then Begin
   If Level<0 Then Level:=Level*Qmul-Qadd Else Level:=Level*Qmul+Qadd;
   Blk[I]:=SmallInt(Level);
  End;
 End;
End;

{ ff_clean_intra_table_entries }
Procedure H3CleanIntra;
Var Xy,Wrap,I: LongInt;
Begin
 Wrap:=H3B8Stride;
 Xy:=H3DcOff[0]+H3B8Stride*2*H3MbY+2*H3MbX;
 H3Dc[0]^[Xy]:=1024; H3Dc[0]^[Xy+1]:=1024; H3Dc[0]^[Xy+Wrap]:=1024; H3Dc[0]^[Xy+
  1+Wrap]:=1024;
 For I:=0 To 31 Do Begin H3Ac^[Xy*16+I]:=0; H3Ac^[(Xy+Wrap)*16+I]:=0; End;
 Xy:=H3MbX+H3MbY*H3MbStride;
 H3Dc[1]^[H3DcOff[1]+Xy]:=1024; H3Dc[2]^[H3DcOff[2]+Xy]:=1024;
 For I:=0 To 15 Do Begin H3Ac^[(H3DcOff[1]+Xy)*16+I]:=0; H3Ac^[(H3DcOff[2]+Xy)*
  16+I]:=0; End;
 H3Intra^[Xy]:=0;
End;

{ prediction des images B (mpv_motion, sens avant puis arriere en moyenne) }
Procedure H3BPredict;
Var Sv: Array[0..3,0..1] Of LongInt; I: LongInt;
Begin
 H3Avg:=0;
 If (H3MvDir And 1)<>0 Then Begin
  If H3MvType=0 Then H3MpegMotion(H3RefI,H3Mv[0,0],H3Mv[0,1],0) Else H3Apply8x8(
   H3RefI,0);
  H3Avg:=1;
 End;
 If (H3MvDir And 2)<>0 Then Begin
  If H3MvType=0 Then H3MpegMotion(H3BwdI,H3Mv1[0,0],H3Mv1[0,1],0)
  Else Begin
   Move(H3Mv,Sv,SizeOf(Sv)); Move(H3Mv1,H3Mv,SizeOf(H3Mv));
   H3Apply8x8(H3BwdI,0);
   Move(Sv,H3Mv,SizeOf(Sv));
  End;
 End;
 H3Avg:=0;
End;

{ ff_mpv_reconstruct_mb (H.263, images I/P) }
Procedure H3Recon;
Var
 Xy,NoRnd,I,DOff,COff: LongInt; Cur,P: ^TH3Pic;
Begin
 Xy:=H3MbX+H3MbY*H3MbStride;
 Cur:=@H3P[H3CurI];
 Cur^.Qs^[Xy+2*H3MbStride+1]:=H3Qscale;
 If H3MbIntra=0 Then Begin
  If H3Aic<>0 Then If H3Intra^[Xy]<>0 Then H3CleanIntra;
 End Else If H3Aic<>0 Then H3Intra^[Xy]:=1;
 H3MbSkipped:=0;
 DOff:=H3MbY*16*H3LY+H3MbX*16; COff:=H3MbY*8*H3LC+H3MbX*8;
 If H3MbIntra=0 Then Begin
  If (H3NoRounding<>0) And (H3PictType<>2) Then NoRnd:=1 Else NoRnd:=0;
  P:=@H3P[H3RefI];
  If H3PictType=2 Then H3BPredict
  Else If (H3Obmc<>0) And (H3PictType<>2) Then H3ApplyObmc(H3RefI,NoRnd)
  Else If H3MvType=0 Then H3MpegMotion(H3RefI,H3Mv[0,0],H3Mv[0,1],NoRnd)
  Else H3Apply8x8(H3RefI,NoRnd);
  For I:=0 To 3 Do
   If H3BlkLast[I]>=0 Then Begin
    H3DequantInter(H3Blk[I],I,H3Qscale);
    H3Idct(H3Blk[I],Cur^.Y,DOff+(I And 1)*8+(I Shr 1)*8*H3LY,H3LY,True);
   End;
  For I:=4 To 5 Do
   If H3BlkLast[I]>=0 Then Begin
    H3DequantInter(H3Blk[I],I,H3ChromaQscale);
    If I=4 Then H3Idct(H3Blk[I],Cur^.U,COff,H3LC,True) Else H3Idct(H3Blk[I],
     Cur^.V,COff,H3LC,True);
   End;
 End Else Begin
  For I:=0 To 3 Do Begin
   H3DequantIntra(H3Blk[I],I,H3Qscale);
   H3Idct(H3Blk[I],Cur^.Y,DOff+(I And 1)*8+(I Shr 1)*8*H3LY,H3LY,False);
  End;
  H3DequantIntra(H3Blk[4],4,H3ChromaQscale); H3Idct(H3Blk[4],Cur^.U,COff,H3LC,
   False);
  H3DequantIntra(H3Blk[5],5,H3ChromaQscale); H3Idct(H3Blk[5],Cur^.V,COff,H3LC,
   False);
 End;
End;

{ h263_h_loop_filter / h263_v_loop_filter }
Procedure H3LoopH(Pl: PEABuffer; Src,Stride,Q: LongInt);
Var Y,D1,D2,Ad1,P0,P1,P2,P3,D,St: LongInt;
Begin
 St:=H3LoopStrength[Q];
 For Y:=0 To 7 Do Begin
  P0:=Pl^[Src+Y*Stride-2]; P1:=Pl^[Src+Y*Stride-1]; P2:=Pl^[Src+Y*Stride]; P3:=
   Pl^[Src+Y*Stride+1];
  D:=(P0-P3+4*(P2-P1)) Div 8;
  If D<-2*St Then D1:=0
  Else If D<-St Then D1:=-2*St-D
  Else If D<St Then D1:=D
  Else If D<2*St Then D1:=2*St-D
  Else D1:=0;
  Inc(P1,D1); Dec(P2,D1);
  If (P1 And 256)<>0 Then Begin If P1<0 Then P1:=0 Else P1:=255; End;
  If (P2 And 256)<>0 Then Begin If P2<0 Then P2:=0 Else P2:=255; End;
  Pl^[Src+Y*Stride-1]:=P1; Pl^[Src+Y*Stride]:=P2;
  Ad1:=Abs(D1) Shr 1;
  D2:=H3Clip((P0-P3) Div 4,-Ad1,Ad1);
  Pl^[Src+Y*Stride-2]:=P0-D2; Pl^[Src+Y*Stride+1]:=P3+D2;
 End;
End;

Procedure H3LoopV(Pl: PEABuffer; Src,Stride,Q: LongInt);
Var X,D1,D2,Ad1,P0,P1,P2,P3,D,St: LongInt;
Begin
 St:=H3LoopStrength[Q];
 For X:=0 To 7 Do Begin
  P0:=Pl^[Src+X-2*Stride]; P1:=Pl^[Src+X-Stride]; P2:=Pl^[Src+X]; P3:=Pl^[Src+X+
   Stride];
  D:=(P0-P3+4*(P2-P1)) Div 8;
  If D<-2*St Then D1:=0
  Else If D<-St Then D1:=-2*St-D
  Else If D<St Then D1:=D
  Else If D<2*St Then D1:=2*St-D
  Else D1:=0;
  Inc(P1,D1); Dec(P2,D1);
  If (P1 And 256)<>0 Then Begin If P1<0 Then P1:=0 Else P1:=255; End;
  If (P2 And 256)<>0 Then Begin If P2<0 Then P2:=0 Else P2:=255; End;
  Pl^[Src+X-Stride]:=P1; Pl^[Src+X]:=P2;
  Ad1:=Abs(D1) Shr 1;
  D2:=H3Clip((P0-P3) Div 4,-Ad1,Ad1);
  Pl^[Src+X-2*Stride]:=P0-D2; Pl^[Src+X+Stride]:=P3+D2;
 End;
End;

{ ff_h263_loop_filter }
Procedure H3LoopFilter;
Var
 QpC,Xy,QpDt,QpTt,QpTc,ChromaQp,QpLc,DY,DC: LongInt; Cur: ^TH3Pic;
 Function QS(I: LongInt): LongInt;Begin QS:=Cur^.Qs^[I+2*H3MbStride+1]; End;
 Function IsSkip(I: LongInt): Boolean;Begin IsSkip:=(Cur^.Mt^[I+2*H3MbStride+1]
  And H3_SKIP)<>0; End;
Begin
 Cur:=@H3P[H3CurI];
 Xy:=H3MbY*H3MbStride+H3MbX;
 DY:=H3MbY*16*H3LY+H3MbX*16; DC:=H3MbY*8*H3LC+H3MbX*8;
 If Not IsSkip(Xy) Then Begin
  QpC:=H3Qscale;
  H3LoopV(Cur^.Y,DY+8*H3LY,H3LY,QpC);
  H3LoopV(Cur^.Y,DY+8*H3LY+8,H3LY,QpC);
 End Else QpC:=0;
 If H3MbY<>0 Then Begin
  If IsSkip(Xy-H3MbStride) Then QpTt:=0 Else QpTt:=QS(Xy-H3MbStride);
  If QpC<>0 Then QpTc:=QpC Else QpTc:=QpTt;
  If QpTc<>0 Then Begin
   If H3ChromaTab Then ChromaQp:=H3ChromaQ[QpTc] Else ChromaQp:=QpTc;
   H3LoopV(Cur^.Y,DY,H3LY,QpTc);
   H3LoopV(Cur^.Y,DY+8,H3LY,QpTc);
   H3LoopV(Cur^.U,DC,H3LC,ChromaQp);
   H3LoopV(Cur^.V,DC,H3LC,ChromaQp);
  End;
  If QpTt<>0 Then H3LoopH(Cur^.Y,DY-8*H3LY+8,H3LY,QpTt);
  If H3MbX<>0 Then Begin
   If (QpTt<>0) Or IsSkip(Xy-1-H3MbStride) Then QpDt:=QpTt Else QpDt:=QS(Xy-1-
    H3MbStride);
   If QpDt<>0 Then Begin
    If H3ChromaTab Then ChromaQp:=H3ChromaQ[QpDt] Else ChromaQp:=QpDt;
    H3LoopH(Cur^.Y,DY-8*H3LY,H3LY,QpDt);
    H3LoopH(Cur^.U,DC-8*H3LC,H3LC,ChromaQp);
    H3LoopH(Cur^.V,DC-8*H3LC,H3LC,ChromaQp);
   End;
  End;
 End;
 If QpC<>0 Then Begin
  H3LoopH(Cur^.Y,DY+8,H3LY,QpC);
  If H3MbY+1=H3MbH Then H3LoopH(Cur^.Y,DY+8*H3LY+8,H3LY,QpC);
 End;
 If H3MbX<>0 Then Begin
  If (QpC<>0) Or IsSkip(Xy-1) Then QpLc:=QpC Else QpLc:=QS(Xy-1);
  If QpLc<>0 Then Begin
   H3LoopH(Cur^.Y,DY,H3LY,QpLc);
   If H3MbY+1=H3MbH Then Begin
    If H3ChromaTab Then ChromaQp:=H3ChromaQ[QpLc] Else ChromaQp:=QpLc;
    H3LoopH(Cur^.Y,DY+8*H3LY,H3LY,QpLc);
    H3LoopH(Cur^.U,DC,H3LC,ChromaQp);
    H3LoopH(Cur^.V,DC,H3LC,ChromaQp);
   End;
  End;
 End;
End;

{ ---- images et boucle de decodage (h263dec.c, mpegvideo.c, mpegvideo_dec.c)
 ---- }
Var
 H3CtxW,H3CtxH: LongInt; H3HaveCtx: Boolean; H3Codec: LongInt; { 0 h263, 1 flv }
 H3Out: LongInt;
 H3PkBuf: PEABuffer; H3PkCap: LongInt;

Procedure H3FreeCtx;
Var I: LongInt;
Begin
 If Not H3HaveCtx Then Exit;
 For I:=0 To 2 Do Begin
  FreeMem(H3P[I].Y); FreeMem(H3P[I].U); FreeMem(H3P[I].V); FreeMem(H3P[I].Mt);
   FreeMem(H3P[I].Mv); FreeMem(H3P[I].Mv1); FreeMem(H3P[I].Qs);
 End;
 FreeMem(H3DcBase); FreeMem(H3Ac); FreeMem(H3Intra);
 H3HaveCtx:=False;
End;

Procedure H3AllocCtx;
Var I,YSize,CSize,YcSize,MtN,MvN: LongInt;
Begin
 H3FreeCtx;
 H3MbStride:=H3MbW+1; H3B8Stride:=H3MbW*2+1;
 H3LY:=H3MbW*16; H3LC:=H3MbW*8;
 H3HEdge:=H3MbW*16; H3VEdge:=H3MbH*16;
 For I:=0 To 2 Do Begin
  GetMem(H3P[I].Y,H3LY*H3MbH*16+64); FillChar(H3P[I].Y^,H3LY*H3MbH*16+64,0);
  GetMem(H3P[I].U,H3LC*H3MbH*8+64); FillChar(H3P[I].U^,H3LC*H3MbH*8+64,0);
  GetMem(H3P[I].V,H3LC*H3MbH*8+64); FillChar(H3P[I].V^,H3LC*H3MbH*8+64,0);
  MtN:=H3MbStride*(H3MbH+1)+1+H3MbStride+8;
  GetMem(H3P[I].Mt,MtN*4); FillChar(H3P[I].Mt^,MtN*4,0);
  GetMem(H3P[I].Qs,MtN); FillChar(H3P[I].Qs^,MtN,0);
  MvN:=2*(H3B8Stride*H3MbH*2+16);
  GetMem(H3P[I].Mv,MvN*2); FillChar(H3P[I].Mv^,MvN*2,0);
  GetMem(H3P[I].Mv1,MvN*2); FillChar(H3P[I].Mv1^,MvN*2,0);
 End;
 YSize:=H3B8Stride*(2*H3MbH+1); CSize:=H3MbStride*(H3MbH+1); YcSize:=YSize+2*
  CSize;
 If (H3MbH And 1)<>0 Then Inc(YcSize,2*H3B8Stride+2*H3MbStride);
 H3DcN:=YcSize;
 GetMem(H3DcBase,YcSize*2); For I:=0 To YcSize-1 Do H3DcBase^[I]:=1024;
 GetMem(H3Ac,YcSize*16*2); FillChar(H3Ac^,YcSize*16*2,0);
 GetMem(H3Intra,H3MbStride*H3MbH+2); FillChar(H3Intra^,H3MbStride*H3MbH+2,1);
 H3Dc[0]:=H3DcBase; H3Dc[1]:=H3DcBase; H3Dc[2]:=H3DcBase;
 H3DcOff[0]:=H3B8Stride+1; H3DcOff[1]:=YSize+H3MbStride+1; H3DcOff[2]:=H3DcOff[
  1]+CSize;
 H3CtxW:=H3Wd; H3CtxH:=H3Ht; H3HaveCtx:=True;
 H3CurI:=-1; H3RefI:=-1;
End;

Procedure H3ClearPic(I: LongInt);
Var MtN,MvN: LongInt;
Begin
 MtN:=H3MbStride*(H3MbH+1)+1+H3MbStride+8;
 FillChar(H3P[I].Mt^,MtN*4,0); FillChar(H3P[I].Qs^,MtN,0);
 MvN:=2*(H3B8Stride*H3MbH*2+16);
 FillChar(H3P[I].Mv^,MvN*2,0); FillChar(H3P[I].Mv1^,MvN*2,0);
End;

{ ff_h263_update_motion_val (images non B) }
Procedure H3UpdateMotion;
Var M,Mx,My: LongInt;
Begin
 If H3MvType<>1 Then Begin
  M:=H3B8Stride*2*H3MbY+2*H3MbX;
  If H3MbIntra<>0 Then Begin Mx:=0; My:=0; End Else Begin Mx:=H3Mv[0,0]; My:=
   H3Mv[0,1]; End;
  H3FillMv(M,Mx,My);
 End;
End;

{ boucle sur une tranche (decode_slice) ; 0 = ok, <0 = erreur }
Function H3DecodeSlice: LongInt;
Var Ret: LongInt;
Begin
 H3DecodeSlice:=H3InvalidData;
 H3LastGb:=H3Pos;
 H3FirstLine:=1;
 H3ResyncX:=H3MbX; H3ResyncY:=H3MbY;
 H3SetQscale(H3Qscale);
 While H3MbY<H3MbH Do Begin
  While H3MbX<H3MbW Do Begin
   If (H3ResyncX=H3MbX) And (H3ResyncY+1=H3MbY) Then H3FirstLine:=0;
   H3MvType:=0;
   Ret:=H3DecodeMb;
   H3UpdateMotion;
   If Ret<0 Then Begin
    If Ret=H3SliceEnd Then Begin
     H3Recon;
     If H3Loop<>0 Then H3LoopFilter;
     Inc(H3MbX);
     If H3MbX>=H3MbW Then Begin H3MbX:=0; Inc(H3MbY); End;
     H3DecodeSlice:=0; Exit;
    End Else If Ret=H3SliceNoEnd Then Begin H3DecodeSlice:=H3InvalidData; Exit;
     End;
    H3Err:=True;
    H3DecodeSlice:=H3InvalidData; Exit;
   End;
   H3Recon;
   If H3Loop<>0 Then H3LoopFilter;
   Inc(H3MbX);
  End;
  H3MbX:=0;
  Inc(H3MbY);
 End;
 { fin de l'image sans marqueur de fin : accepte (pas de contournement de
  bourrage a signaler) }
 H3DecodeSlice:=0;
End;

{ decode un paquet ; renvoie 1 si une image est disponible dans H3P[H3Out] }
Function H3Frame(Pk: PEABuffer; Len: LongInt): LongInt;
Var Ret,PrevX,PrevY,I,Slot: LongInt; NewCtx: Boolean;
Begin
 H3Frame:=0;
 If Len=0 Then Exit;
 If H3PkCap<Len+128 Then Begin
  If H3PkBuf<>Nil Then FreeMem(H3PkBuf);
  H3PkCap:=Len+128; GetMem(H3PkBuf,H3PkCap);
 End;
 Move(Pk^,H3PkBuf^,Len); FillChar(H3PkBuf^[Len],128,0);
 H3Buf:=H3PkBuf; H3Size:=Len; H3Pos:=0;
 If H3Codec=1 Then Ret:=H3FlvHeader Else If H3Codec=3 Then Ret:=H3IntelHeader
  Else Ret:=H3PicHeader;
 If Ret<0 Then Begin
  If H3HaveCtx Then Begin H3Wd:=H3CtxW; H3Ht:=H3CtxH; End;
  Exit;
 End;
 NewCtx:=Not H3HaveCtx Or (H3Wd<>H3CtxW) Or (H3Ht<>H3CtxH);
 If NewCtx Then H3AllocCtx;
 If H3PictType=2 Then Exit;   { images B non prises en charge }
 If (H3RefI<0) And (H3Droppable<>0) Then Exit;
 { image courante : un emplacement different de la reference }
 Slot:=0; While Slot=H3RefI Do Inc(Slot);
 H3CurI:=Slot;
 H3ClearPic(H3CurI);
 If (H3PictType<>0) And (H3RefI<0) Then Begin
  { image de reference factice }
  Slot:=0; While Slot=H3CurI Do Inc(Slot);
  H3RefI:=Slot;
  FillChar(H3P[H3RefI].Y^,H3LY*H3MbH*16,16);
  FillChar(H3P[H3RefI].U^,H3LC*H3MbH*8,128); FillChar(H3P[H3RefI].V^,H3LC*H3MbH*
   8,128);
 End;
 H3MbX:=0; H3MbY:=0; H3Err:=False;
 Ret:=H3DecodeSlice;
 While H3MbY<H3MbH Do Begin
  PrevX:=H3MbX; PrevY:=H3MbY;
  If H3Resync<0 Then Break;
  If H3DecodeSlice<0 Then Ret:=H3InvalidData;
 End;
 H3Out:=H3CurI;
 If H3Droppable=0 Then H3RefI:=H3CurI;
 H3Frame:=1;
End;

Var H3OutBuf: PEABuffer; H3OutW,H3OutH,H3OutBegun: LongInt;

{ copie l'image decodee (recadree) dans le tampon de sortie planaire 4:2:0 ;
 faux si les dimensions changent }
{ ---- MPEG-4 Part 2 : decodeur (libavcodec/mpeg4videodec.c, mpeg4video.c,
 h263.c, mpegvideo_motion.c, qpeldsp.c,
       mpegvideodsp.c, LGPL-2.1-or-later) ---- }
Const
 M4DcLum: Array[0..25] Of Byte=(
  3,3,3,2,2,2,2,3,1,3,1,4,1,5,1,6,
  1,7,1,8,1,9,1,10,1,11);
 M4DcChr: Array[0..25] Of Byte=(
  3,2,2,2,1,2,1,3,1,4,1,5,1,6,1,7,
  1,8,1,9,1,10,1,11,1,12);
 M4IntraVlc: Array[0..205] Of Word=(
  2,2,6,3,15,4,13,5,12,5,21,6,19,6,18,6,
  23,7,31,8,30,8,29,8,37,9,36,9,35,9,33,9,
  33,10,32,10,15,10,14,10,7,11,6,11,32,11,33,11,
  80,12,81,12,82,12,14,4,20,6,22,7,28,8,32,9,
  31,9,13,10,34,11,83,12,85,12,11,5,21,7,30,9,
  12,10,86,12,17,6,27,8,29,9,11,10,16,6,34,9,
  10,10,13,6,28,9,8,10,18,7,27,9,84,12,20,7,
  26,9,87,12,25,8,9,10,24,8,35,11,23,8,25,9,
  24,9,7,10,88,12,7,4,12,6,22,8,23,9,6,10,
  5,11,4,11,89,12,15,6,22,9,5,10,14,6,4,10,
  17,7,36,11,16,7,37,11,19,7,90,12,21,8,91,12,
  20,8,19,8,26,8,21,9,20,9,19,9,18,9,17,9,
  38,11,39,11,92,12,93,12,94,12,95,12,3,7);
 M4IntraLev: Array[0..101] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  17,18,19,20,21,22,23,24,25,26,27,1,2,3,4,5,
  6,7,8,9,10,1,2,3,4,5,1,2,3,4,1,2,
  3,1,2,3,1,2,3,1,2,3,1,2,1,2,1,1,
  1,1,1,1,2,3,4,5,6,7,8,1,2,3,1,2,
  1,2,1,2,1,2,1,2,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1);
 M4IntraRun: Array[0..101] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,
  1,1,1,1,1,2,2,2,2,2,3,3,3,3,4,4,
  4,5,5,5,6,6,6,7,7,7,8,8,9,9,10,11,
  12,13,14,0,0,0,0,0,0,0,0,1,1,1,2,2,
  3,3,4,4,5,5,6,6,7,8,9,10,11,12,13,14,
  15,16,17,18,19,20);
 M4InterRvlc: Array[0..339] Of Word=(
  6,3,1,4,4,5,28,7,60,8,61,8,124,9,252,10,
  253,10,508,11,509,11,1020,12,2044,13,2045,13,3068,13,3069,13,
  4092,14,4093,14,8188,15,7,3,12,6,92,8,125,9,380,10,
  764,11,1021,12,3580,13,6140,14,6141,14,10,4,29,7,188,9,
  765,11,1532,12,7164,14,7165,14,5,5,93,8,381,10,1533,12,
  3581,13,7676,14,8189,15,8,5,108,8,892,11,3836,13,12284,15,
  9,5,189,9,893,11,3837,13,13,6,444,10,1788,12,7677,14,
  20,6,445,10,1789,12,12285,15,21,6,476,10,3964,13,44,7,
  477,10,7932,14,45,7,956,11,52,7,1916,12,109,8,3965,13,
  116,8,7933,14,117,8,8060,14,220,9,8061,14,221,9,8124,14,
  236,9,14332,15,492,10,493,10,500,10,957,11,988,11,989,11,
  1004,11,1005,11,1012,11,1917,12,1980,12,1981,12,4028,13,4029,13,
  4060,13,4061,13,8125,14,8156,14,8157,14,14333,15,15356,15,11,4,
  120,8,1013,11,4076,13,8172,14,18,5,237,9,2012,12,8173,14,
  15357,15,19,5,1016,11,15868,15,24,6,2013,12,25,6,2028,12,
  34,6,4077,13,35,6,4084,13,53,7,4085,13,56,7,4088,13,
  57,7,4089,13,66,7,8180,14,67,7,8181,14,121,8,8184,14,
  130,8,15869,15,131,8,244,9,245,9,248,9,249,9,258,9,
  259,9,501,10,504,10,505,10,514,10,515,10,1017,11,1026,11,
  1027,11,2029,12,2036,12,2037,12,2040,12,2041,12,2050,12,2051,12,
  4098,13,4099,13,8185,14,8194,14,8195,14,16124,15,16125,15,16252,15,
  16253,15,0,4);
 M4InterRvlcRun: Array[0..168] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,1,1,1,1,1,1,1,1,1,1,2,2,2,
  2,2,2,2,3,3,3,3,3,3,3,4,4,4,4,4,
  5,5,5,5,6,6,6,6,7,7,7,7,8,8,8,9,
  9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,
  17,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,
  32,33,34,35,36,37,38,0,0,0,0,0,1,1,1,1,
  1,2,2,2,3,3,4,4,5,5,6,6,7,7,8,8,
  9,9,10,10,11,11,12,12,13,13,14,15,16,17,18,19,
  20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,
  36,37,38,39,40,41,42,43,44);
 M4InterRvlcLev: Array[0..168] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  17,18,19,1,2,3,4,5,6,7,8,9,10,1,2,3,
  4,5,6,7,1,2,3,4,5,6,7,1,2,3,4,5,
  1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,1,
  2,3,1,2,1,2,1,2,1,2,1,2,1,2,1,2,
  1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,2,3,4,5,1,2,3,4,
  5,1,2,3,1,2,1,2,1,2,1,2,1,2,1,2,
  1,2,1,2,1,2,1,2,1,2,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1);
 M4IntraRvlc: Array[0..339] Of Word=(
  6,3,7,3,10,4,9,5,20,6,21,6,52,7,116,8,
  117,8,221,9,236,9,492,10,493,10,500,10,1004,11,1005,11,
  1012,11,1917,12,1980,12,4029,13,4060,13,1981,12,4061,13,8125,14,
  8156,14,8157,14,8188,15,1,4,8,5,45,7,108,8,109,8,
  220,9,477,10,988,11,989,11,1916,12,4028,13,8061,14,8124,14,
  4,5,44,7,188,9,476,10,956,11,957,11,3837,13,3964,13,
  3965,13,7933,14,8060,14,5,5,92,8,189,9,893,11,1788,12,
  3836,13,7677,14,7932,14,8189,15,12,6,93,8,445,10,1021,12,
  1789,12,7165,14,13,6,125,9,764,11,1532,12,7164,14,7676,14,
  28,7,380,10,765,11,1533,12,12284,15,29,7,381,10,892,11,
  3581,13,12285,15,60,8,444,10,3069,13,6141,14,61,8,509,11,
  3580,13,14332,15,124,9,1020,12,252,10,3068,13,253,10,14333,15,
  508,11,2044,13,2045,13,4092,14,4093,14,6140,14,15356,15,11,4,
  120,8,1013,11,4076,13,8172,14,18,5,237,9,2012,12,8173,14,
  15357,15,19,5,1016,11,15868,15,24,6,2013,12,25,6,2028,12,
  34,6,4077,13,35,6,4084,13,53,7,4085,13,56,7,4088,13,
  57,7,4089,13,66,7,8180,14,67,7,8181,14,121,8,8184,14,
  130,8,15869,15,131,8,244,9,245,9,248,9,249,9,258,9,
  259,9,501,10,504,10,505,10,514,10,515,10,1017,11,1026,11,
  1027,11,2029,12,2036,12,2037,12,2040,12,2041,12,2050,12,2051,12,
  4098,13,4099,13,8185,14,8194,14,8195,14,16124,15,16125,15,16252,15,
  16253,15,0,4);
 M4IntraRvlcRun: Array[0..168] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,
  1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,
  2,2,2,3,3,3,3,3,3,3,3,3,4,4,4,4,
  4,4,5,5,5,5,5,5,6,6,6,6,6,7,7,7,
  7,7,8,8,8,8,9,9,9,9,10,10,11,11,12,12,
  13,14,15,16,17,18,19,0,0,0,0,0,1,1,1,1,
  1,2,2,2,3,3,4,4,5,5,6,6,7,7,8,8,
  9,9,10,10,11,11,12,12,13,13,14,15,16,17,18,19,
  20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,
  36,37,38,39,40,41,42,43,44);
 M4IntraRvlcLev: Array[0..168] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  17,18,19,20,21,22,23,24,25,26,27,1,2,3,4,5,
  6,7,8,9,10,11,12,13,1,2,3,4,5,6,7,8,
  9,10,11,1,2,3,4,5,6,7,8,9,1,2,3,4,
  5,6,1,2,3,4,5,6,1,2,3,4,5,1,2,3,
  4,5,1,2,3,4,1,2,3,4,1,2,1,2,1,2,
  1,1,1,1,1,1,1,1,2,3,4,5,1,2,3,4,
  5,1,2,3,1,2,1,2,1,2,1,2,1,2,1,2,
  1,2,1,2,1,2,1,2,1,2,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1);
 M4DefIntra: Array[0..63] Of Byte=(
  8,17,18,19,21,23,25,27,
  17,18,19,21,23,25,27,28,
  20,21,22,23,24,26,28,30,
  21,22,23,24,26,28,30,32,
  22,23,24,26,28,30,32,35,
  23,24,26,28,30,32,35,38,
  25,26,28,30,32,35,38,41,
  27,28,30,32,35,38,41,45);
 M4DefInter: Array[0..63] Of Byte=(
  16,17,18,19,20,21,22,23,
  17,18,19,20,21,22,23,24,
  18,19,20,21,22,23,24,25,
  19,20,21,22,23,24,26,27,
  20,21,22,23,25,26,27,28,
  21,22,23,24,26,27,28,30,
  22,23,24,26,27,28,30,31,
  23,24,25,27,28,30,31,33);
 M4YDcScale: Array[0..31] Of Byte=(
  0,8,8,8,8,10,12,14,16,17,18,19,20,21,22,23,
  24,25,26,27,28,29,30,31,32,34,36,38,40,42,44,46);
 M4CDcScale: Array[0..31] Of Byte=(
  0,8,8,8,8,9,9,10,10,11,11,12,12,13,13,14,
  14,15,15,16,16,17,17,18,18,19,20,21,22,23,24,25);
Type
 TM4Rl=Record Vlc: TH3Vlc; N,Last: LongInt; Run,Lev: Array[0..199] Of SmallInt;
  MaxLev,MaxRun: Array[0..1,0..63] Of SmallInt; End;
 PM4Rl=^TM4Rl;
 TM4L32=Array[0..40000000] Of LongInt; PM4L32=^TM4L32;
 TM4Pic=Record Y,U,V,Ref,Qs,Sk: PEABuffer; Mt: PM4L32; Mv: PH3I16; IsRef,Used:
  Boolean; PType: LongInt; Time: Int64; End;
Const
 M4_INTRA=1; M4_16X16=2; M4_8X8=4; M4_16X8=8; M4_INTERLACED=16; M4_SKIP=32;
  M4_ACPRED=64; M4_DIRECT=128; M4_GMC=256;
 M4_L0=512; M4_L1=1024;
 M4_BUG_NOPAD=16; M4_BUG_XVIDILACE=4; M4_BUG_UMP4=8; M4_BUG_QPELCH=64;
  M4_BUG_QPELCH2=256; M4_BUG_DIRBLK=512; M4_BUG_EDGE=1024;
 M4_BUG_HPELCH=2048; M4_BUG_DCCLIP=4096; M4_BUG_STDQPEL=128; M4_BUG_AMV=32;
 M4_SLICE_OK=0; M4_SLICE_ERR=-1; M4_SLICE_END=-2; M4_SLICE_NOEND=-3;
 M4_SKIPPED=-100;
 M4DcThr: Array[0..7] Of Byte=(99,13,15,17,19,21,23,0);
 M4SprLen: Array[0..14] Of Byte=(2,3,3,3,3,3,4,5,6,7,8,9,10,11,12);
 M4Aspect: Array[0..15,0..1] Of Byte=((0,1),(1,1),(12,11),(10,11),(16,11),(40,
  33),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1));
Var
 M4Init: Boolean;
 M4RlIntra,M4RlRvIntra,M4RlRvInter,M4RlInter: TM4Rl;
 M4VDcL,M4VDcC,M4VSpr: TH3Vlc;
 { flux / VOL }
 M4W,M4H,M4MbW,M4MbH,M4MbS,M4B8S,M4MbNum,M4HEdge,M4VEdge,M4LY,M4LC: LongInt;
 M4AllocW,M4AllocH: LongInt; M4Have: Boolean;
 M4VoType,M4Shape,M4TIncBits,M4Res,M4FixedRate,M4Prog,M4SprUsage,M4NumWarp,
  M4WarpAcc,M4BrightChg,M4QuantPrec,M4MpegQuant,M4QuarterS,
 M4DataPart,M4Rvlc,M4ResyncMarker,M4NewPred,M4Scal,M4EnhType,M4LowDelay,
  M4VolCtl: LongInt;
 M4CplxI,M4CplxP,M4CplxB: LongInt;
 M4SarN,M4SarD: LongInt;
 M4IntraM,M4InterM: Array[0..63] Of LongInt;
 M4DivxVer,M4DivxBuild,M4XvidBuild,M4LavcBuild,M4Bugs,M4PadScore: LongInt;
  M4DivxPacked: Boolean; M4CTag: String[4];
 { image courante }
 M4PType,M4Part,M4NoRnd,M4IntraDcThr,M4Tff,M4AltScan,M4Qscale,M4FCode,M4BCode:
  LongInt;
 M4Time,M4TimeBase,M4LastTimeBase,M4LastNonBTime,M4PPTime,M4PBTime,M4TFrame,
  M4PPField,M4PBField: Int64;
 M4PicNum: LongInt;
 M4SpOff: Array[0..1,0..1] Of Int64; M4SpDelta: Array[0..1,0..1] Of Int64;
  M4SpShift: Array[0..1] Of LongInt; M4RealWarp: LongInt;
 M4DirScale: Array[0..1,0..63] Of LongInt;
 { macrobloc }
 M4MbX,M4MbY,M4MbIntra,M4AcPred,M4IDct,M4MvDir,M4MvType,M4McSel,M4Skip,
  M4ResyncX,M4ResyncY,M4FirstLine,M4MbLeft,
 M4YDc,M4CDc,M4ChromaQ: LongInt;
 M4Mv: Array[0..1,0..3,0..1] Of LongInt; M4LastMv: Array[0..1,0..1,0..1] Of
  LongInt; M4FieldSel: Array[0..1,0..1] Of LongInt;
 M4Blk: Array[0..5] Of TH3Blk; M4BlkLast: Array[0..5] Of LongInt;
 M4ResyncPos: LongInt;
 { images et tables de contexte }
 M4P: Array[0..4] Of TM4Pic; M4CurI,M4LastI,M4NextI: LongInt;
 M4Dc,M4Ac: Array[0..2] Of PH3I16; M4DcN,M4AcN: Array[0..2] Of LongInt;
 M4IntraTab,M4CbpTab,M4DirTab: PEABuffer; M4PField: PH3I16; M4TabN: LongInt;
 M4SkippedLast: Boolean; M4PicHave: Boolean;
 M4OutBuf: PEABuffer; M4OutBegun,M4OutCount: LongInt; M4Mode: LongInt; M4Target:
  String;
 M4Err: Boolean;
 M4Ms: LongInt; M4CodedBlk: PEABuffer; M4YDcT,M4CDcT: Array[0..31] Of Byte;

Function M4Sar(V,N: LongInt): LongInt;
Begin If V>=0 Then M4Sar:=V Shr N Else M4Sar:=-1-((-1-V) Shr N); End;
Function M4Sar64(V: Int64; N: LongInt): Int64;
Begin If V>=0 Then M4Sar64:=V Shr N Else M4Sar64:=-1-((-1-V) Shr N); End;

Procedure M4BuildRl(Var R: TM4Rl; N,Last: LongInt; Const Vl: Array Of Word;
 Const Run,Lev: Array Of ShortInt);
Var K,Len,J,L,St,En,Rn,Lv,Code: LongInt;
Begin
 R.N:=N; R.Last:=Last; R.Vlc.Bits:=0;
 For K:=0 To N Do Begin Len:=Vl[K*2+1]; If Len>R.Vlc.Bits Then R.Vlc.Bits:=Len;
  End;
 For K:=0 To (LongInt(1) Shl R.Vlc.Bits)-1 Do Begin R.Vlc.Sym[K]:=-1; R.Vlc.Len[
  K]:=0; End;
 For K:=0 To N Do Begin
  Len:=Vl[K*2+1]; Code:=Vl[K*2];
  For J:=0 To (LongInt(1) Shl (R.Vlc.Bits-Len))-1 Do Begin
   R.Vlc.Sym[(Code Shl (R.Vlc.Bits-Len))+J]:=K; R.Vlc.Len[(Code Shl (R.Vlc.Bits-
    Len))+J]:=Len;
  End;
 End;
 FillChar(R.MaxLev,SizeOf(R.MaxLev),0); FillChar(R.MaxRun,SizeOf(R.MaxRun),0);
 For K:=0 To N-1 Do Begin R.Run[K]:=Run[K]; R.Lev[K]:=Lev[K]; End;
 For L:=0 To 1 Do Begin
  If L=0 Then Begin St:=0; En:=Last; End Else Begin St:=Last; En:=N; End;
  For K:=St To En-1 Do Begin
   Rn:=Run[K]; Lv:=Lev[K];
   If Lv>R.MaxLev[L,Rn] Then R.MaxLev[L,Rn]:=Lv;
   If Rn>R.MaxRun[L,Lv] Then R.MaxRun[L,Lv]:=Rn;
  End;
 End;
End;

Procedure M4InitTables;
Var K,Len,J,Code: LongInt;
Procedure Dc(Var T: TH3Vlc; Const Tab: Array Of Byte);
Var Q,Ln,Cd,Sp: LongInt;
Begin
 T.Bits:=0;
 For Q:=0 To 9 Do If Tab[Q*2+1]>T.Bits Then T.Bits:=Tab[Q*2+1];
 For Q:=0 To (LongInt(1) Shl T.Bits)-1 Do Begin T.Sym[Q]:=-1; T.Len[Q]:=0; End;
 For Q:=0 To 9 Do Begin
  Ln:=Tab[Q*2+1]; Cd:=Tab[Q*2];
  For Sp:=0 To (LongInt(1) Shl (T.Bits-Ln))-1 Do Begin T.Sym[(Cd Shl (T.Bits-
   Ln))+Sp]:=Q; T.Len[(Cd Shl (T.Bits-Ln))+Sp]:=Ln; End;
 End;
End;
Begin
 If M4Init Then Exit;
 M4Init:=True;
 H3InitTables;
 M4BuildRl(M4RlIntra,102,67,M4IntraVlc,M4IntraRun,M4IntraLev);
 M4BuildRl(M4RlRvInter,169,103,M4InterRvlc,M4InterRvlcRun,M4InterRvlcLev);
 M4BuildRl(M4RlRvIntra,169,103,M4IntraRvlc,M4IntraRvlcRun,M4IntraRvlcLev);
 M4BuildRl(M4RlInter,102,58,H3InterVlc,H3InterRun,H3InterLevel);
 Dc(M4VDcL,M4DcLum); Dc(M4VDcC,M4DcChr);
 M4VSpr.Bits:=12;
 For K:=0 To 4095 Do Begin M4VSpr.Sym[K]:=-1; M4VSpr.Len[K]:=0; End;
 Code:=0;
 For Len:=1 To 12 Do Begin
  For K:=0 To 14 Do If M4SprLen[K]=Len Then Begin
   For J:=0 To (LongInt(1) Shl (12-Len))-1 Do Begin M4VSpr.Sym[(Code Shl (12-
    Len))+J]:=K; M4VSpr.Len[(Code Shl (12-Len))+J]:=Len; End;
   Inc(Code);
  End;
  Code:=Code Shl 1;
 End;
End;

{ ---- petits utilitaires de lecture ---- }
Function M4GetXbits(N: LongInt): LongInt;
Var V: LongInt;
Begin
 V:=H3Bits(N);
 If V<(LongInt(1) Shl (N-1)) Then V:=V-(LongInt(1) Shl N)+1;
 M4GetXbits:=V;
End;

Function M4Marker: LongInt;
Begin M4Marker:=H3Bit; End;

Function M4Log2(V: LongInt): LongInt;
Var R: LongInt;
Begin R:=0; While V>1 Do Begin V:=V Shr 1; Inc(R); End; M4Log2:=R; End;

Procedure M4SetQscale(Q: LongInt);
Begin
 If Q<1 Then Q:=1 Else If Q>31 Then Q:=31;
 M4Qscale:=Q; M4ChromaQ:=Q;
 M4YDc:=M4YDcT[Q]; M4CDc:=M4CDcT[Q];
End;

Function M4Div(A,B: LongInt): LongInt;   { division C : arrondi vers zero }
Begin M4Div:=A Div B; End;
Function M4RDiv(A,B: LongInt): LongInt;  { ROUNDED_DIV }
Begin If A>=0 Then M4RDiv:=(A+(B Shr 1)) Div B Else M4RDiv:=(A-(B Shr 1)) Div B;
 End;
Function M4RDiv64(A,B: Int64): Int64;
Begin If A>=0 Then M4RDiv64:=(A+(B Shr 1)) Div B Else M4RDiv64:=(A-(B Shr 1))
 Div B; End;

{ ---- en-tetes (mpeg4videodec.c) ---- }
Var M4Range: LongInt;

Procedure M4DefaultMatrices;
Var I: LongInt;
Begin
 For I:=0 To 63 Do Begin M4IntraM[I]:=M4DefIntra[I]; M4InterM[I]:=M4DefInter[I];
  End;
End;

Procedure M4UserData;
Var Buf: String; I,Ver,Build,Ver2,Ver3,E: LongInt; Last: Char;
Function Num(Var P: LongInt; Var V: LongInt): Boolean;
Var Q: LongInt;
Begin
 Q:=P; V:=0;
 While (Q<=Length(Buf)) And (Buf[Q]>='0') And (Buf[Q]<='9') Do Begin If
  V<100000000 Then V:=V*10+Ord(Buf[Q])-48; Inc(Q); End;
 Num:=Q>P; P:=Q;
End;
Function StartsWith(Const S: String; Var P: LongInt): Boolean;
Var Ok: Boolean;
Begin
 Ok:=(Length(Buf)>=Length(S)) And (Copy(Buf,1,Length(S))=S);
 If Ok Then P:=Length(S)+1;
 StartsWith:=Ok;
End;
Var P: LongInt; Ok: Boolean; Hdr: Boolean;
Begin
 Buf:=''; I:=0;
 While (I<255) And (H3Pos<H3Size*8) Do Begin
  If H3Show(23)=0 Then Break;
  Buf:=Buf+Chr(H3Bits(8)); Inc(I);
 End;
 { detection DivX }
 Ver:=0; Build:=0; E:=0; Last:=#0; Hdr:=False;
 If StartsWith('DivX',P) Then Begin
  If Num(P,Ver) Then Begin
   If (P<=Length(Buf)) And (Copy(Buf,P,5)='Build') Then Begin
    Inc(P,5); If Num(P,Build) Then Begin E:=2; If P<=Length(Buf) Then Begin E:=
     3; Last:=Buf[P]; End; End;
   End Else If (P<=Length(Buf)) And (Buf[P]='b') Then Begin
    Inc(P); If Num(P,Build) Then Begin E:=2; If P<=Length(Buf) Then Begin E:=3;
     Last:=Buf[P]; End; End;
   End;
  End;
  If E>=2 Then Begin M4DivxVer:=Ver; M4DivxBuild:=Build; M4DivxPacked:=(E=3) And
   (Last='p'); End;
 End;
 { detection libavcodec }
 E:=0; Ver:=0; Ver2:=0; Ver3:=0; Build:=0;
 If StartsWith('FFmpe',P) Then Begin
  { FFmpe%*[^b]b%d }
  While (P<=Length(Buf)) And (Buf[P]<>'b') Do Inc(P);
  If (P<=Length(Buf)) And (Buf[P]='b') Then Begin Inc(P); If Num(P,Build) Then
   E:=4; End;
 End;
 If (E<>4) And StartsWith('FFmpeg v',P) Then Begin
  If Num(P,Ver) And (P<=Length(Buf)) And (Buf[P]='.') Then Begin
   Inc(P);
   If Num(P,Ver2) And (P<=Length(Buf)) And (Buf[P]='.') Then Begin
    Inc(P);
    If Num(P,Ver3) Then Begin
     If Copy(Buf,P,Length(' / libavcodec build: '))=' / libavcodec build: ' Then
      Begin
      Inc(P,Length(' / libavcodec build: ')); If Num(P,Build) Then E:=4;
     End;
    End;
   End;
  End;
 End;
 If E<>4 Then Begin
  If StartsWith('Lavc',P) Then Begin
   If Num(P,Ver) Then Begin
    E:=2;
    If (P<=Length(Buf)) And (Buf[P]='.') Then Begin
     Inc(P);
     If Num(P,Ver2) Then Begin
      E:=3;
      If (P<=Length(Buf)) And (Buf[P]='.') Then Begin Inc(P); If Num(P,Ver3)
       Then E:=4; End;
     End;
    End;
    If E=4 Then Begin Build:=((Ver And $FF) Shl 16)+((Ver2 And $FF) Shl 8)+(Ver3
     And $FF); End
    Else E:=2;
   End;
  End;
  If (E<>4) And (Buf='ffmpeg') Then M4LavcBuild:=4600;
 End;
 If E=4 Then M4LavcBuild:=Build;
 { detection Xvid }
 If StartsWith('XviD',P) Then Begin
  If Num(P,Build) Then M4XvidBuild:=Build;
 End;
End;

Procedure M4GopHeader;
Var Hrs,Mn,Sec: LongInt;
Begin
 If H3Show(23)=0 Then Exit;
 Hrs:=H3Bits(5); Mn:=H3Bits(6); M4Marker; Sec:=H3Bits(6);
 M4TimeBase:=Sec+60*(Mn+60*Hrs);
 H3Skip(2);
End;

Procedure M4VisualObject;
Var Id,Typ,Sig,Rng,Cd: LongInt;
Begin
 Id:=H3Bit;
 If Id<>0 Then H3Skip(7);
 Typ:=H3Bits(4);
 If (Typ=1) Or (Typ=2) Then Begin
  Sig:=H3Bit;
  If Sig<>0 Then Begin
   H3Skip(3); Rng:=H3Bit; Cd:=H3Bit;
   If Rng<>0 Then M4Range:=2 Else M4Range:=1;
   If Cd<>0 Then H3Skip(24);
  End;
 End;
End;

Function M4VolHeader: LongInt;
Var
 VerId,AspectInfo,ChromaFmt,I,V,Last,J,Pos0,Est,Wd,Ht: LongInt; GoNo: Boolean;
  Bak: LongInt;
 H1,H2,H3b,H4: LongInt; NoCplx: Boolean;
Begin
 M4VolHeader:=-1;
 H3Skip(1);
 M4VoType:=H3Bits(8);
 If (M4VoType=15) Or (M4VoType=14) Then Fail(
  'mpeg4: profil Simple Studio non pris en charge.');
 If H3Bit<>0 Then Begin VerId:=H3Bits(4); H3Skip(3); End Else VerId:=1;
 AspectInfo:=H3Bits(4);
 If AspectInfo=15 Then Begin M4SarN:=H3Bits(8); M4SarD:=H3Bits(8); End
 Else Begin M4SarN:=M4Aspect[AspectInfo,0]; M4SarD:=M4Aspect[AspectInfo,1]; End;
 M4VolCtl:=H3Bit;
 If M4VolCtl<>0 Then Begin
  ChromaFmt:=H3Bits(2);
  M4LowDelay:=H3Bit;
  If H3Bit<>0 Then Begin
   H3Skip(15); M4Marker; H3Skip(15); M4Marker; H3Skip(15); M4Marker; H3Skip(3);
    H3Skip(11); M4Marker; H3Skip(15); M4Marker;
  End;
 End Else Begin
  If M4PicNum=0 Then Begin
   Case M4VoType Of 1,17: M4LowDelay:=1; Else M4LowDelay:=0; End;
  End;
 End;
 M4Shape:=H3Bits(2);
 If M4Shape<>0 Then Fail(
  'mpeg4: seules les couches video rectangulaires sont prises en charge.');
 M4Marker;
 M4Res:=H3Bits(16);
 If M4Res=0 Then Exit;
 M4TIncBits:=M4Log2(M4Res-1)+1;
 If M4TIncBits<1 Then M4TIncBits:=1;
 M4Marker;
 If H3Bit<>0 Then M4FixedRate:=H3Bits(M4TIncBits) Else M4FixedRate:=1;
 M4TFrame:=0;
 M4Marker;
 Wd:=H3Bits(13); M4Marker; Ht:=H3Bits(13); M4Marker;
 If (Wd<>0) And (Ht<>0) And Not ((M4W<>0) And (M4CTag='MP4S')) Then Begin M4W:=
  Wd; M4H:=Ht; End;
 M4Prog:=H3Bit Xor 1;
 M4IDct:=0;
 H3Bit;  { OBMC disable }
 If VerId=1 Then M4SprUsage:=H3Bit Else M4SprUsage:=H3Bits(2);
 If (M4SprUsage=1) Or (M4SprUsage=2) Then Begin
  If M4SprUsage=1 Then Begin H3Skip(13); M4Marker; H3Skip(13); M4Marker; H3Skip(
   13); M4Marker; H3Skip(13); M4Marker; End;
  M4NumWarp:=H3Bits(6);
  If M4NumWarp>3 Then Begin M4NumWarp:=0; Exit; End;
  M4WarpAcc:=H3Bits(2);
  M4BrightChg:=H3Bit;
  If M4SprUsage=1 Then H3Bit;
 End;
 If H3Bit=1 Then Begin
  M4QuantPrec:=H3Bits(4);
  H3Bits(4);
  If (M4QuantPrec<3) Or (M4QuantPrec>9) Then M4QuantPrec:=5;
 End Else M4QuantPrec:=5;
 M4MpegQuant:=H3Bit;
 If M4MpegQuant<>0 Then Begin
  M4DefaultMatrices;
  If H3Bit<>0 Then Begin
   Last:=0; I:=0;
   While I<64 Do Begin
    If H3Left<8 Then Exit;
    V:=H3Bits(8);
    If V=0 Then Break;
    Last:=V; M4IntraM[H3Zigzag[I]]:=Last; Inc(I);
   End;
   While I<64 Do Begin M4IntraM[H3Zigzag[I]]:=Last; Inc(I); End;
  End;
  If H3Bit<>0 Then Begin
   Last:=0; I:=0;
   While I<64 Do Begin
    If H3Left<8 Then Exit;
    V:=H3Bits(8);
    If V=0 Then Break;
    Last:=V; M4InterM[H3Zigzag[I]]:=V; Inc(I);
   End;
   While I<64 Do Begin M4InterM[H3Zigzag[I]]:=Last; Inc(I); End;
  End;
 End;
 If VerId<>1 Then M4QuarterS:=H3Bit Else M4QuarterS:=0;
 If H3Left<4 Then Exit;
 NoCplx:=False;
 If H3Bit=0 Then Begin
  Pos0:=H3Pos;
  Est:=H3Bits(2);
  If Est<2 Then Begin
   If H3Bit=0 Then Begin
    Inc(M4CplxI,8*H3Bit); Inc(M4CplxI,8*H3Bit); Inc(M4CplxI,8*H3Bit); Inc(
     M4CplxI,8*H3Bit); Inc(M4CplxI,8*H3Bit); Inc(M4CplxI,8*H3Bit);
   End;
   If H3Bit=0 Then Begin
    Inc(M4CplxI,8*H3Bit); Inc(M4CplxP,8*H3Bit); Inc(M4CplxP,8*H3Bit); Inc(
     M4CplxI,8*H3Bit);
   End;
   If M4Marker=0 Then Begin H3Pos:=Pos0; NoCplx:=True; End
   Else Begin
    If H3Bit=0 Then Begin
     Inc(M4CplxI,8*H3Bit); Inc(M4CplxI,8*H3Bit); Inc(M4CplxI,8*H3Bit); Inc(
      M4CplxI,4*H3Bit);
    End;
    If H3Bit=0 Then Begin
     Inc(M4CplxP,8*H3Bit); Inc(M4CplxP,8*H3Bit); Inc(M4CplxB,8*H3Bit); Inc(
      M4CplxP,8*H3Bit); Inc(M4CplxP,8*H3Bit); Inc(M4CplxP,8*H3Bit);
    End;
    If M4Marker=0 Then Begin H3Pos:=Pos0; NoCplx:=True; End
    Else If Est=1 Then Begin Inc(M4CplxI,8*H3Bit); Inc(M4CplxP,8*H3Bit); End;
   End;
  End;
 End Else NoCplx:=True;
 If NoCplx Then Begin M4CplxI:=0; M4CplxP:=0; M4CplxB:=0; End;
 M4ResyncMarker:=H3Bit Xor 1;
 M4DataPart:=H3Bit;
 If M4DataPart<>0 Then M4Rvlc:=H3Bit Else M4Rvlc:=0;
 If VerId<>1 Then Begin
  M4NewPred:=H3Bit;
  If M4NewPred<>0 Then Begin H3Skip(2); H3Skip(1); End;
  H3Bit;  { reduced_res_vop }
 End Else M4NewPred:=0;
 M4Scal:=H3Bit;
 If M4Scal<>0 Then Begin
  Bak:=H3Pos;
  H3Skip(1); H3Skip(4); H3Skip(1);
  H1:=H3Bits(5); H2:=H3Bits(5); H3b:=H3Bits(5); H4:=H3Bits(5);
  M4EnhType:=H3Bit;
  If (H1=0) Or (H2=0) Or (H3b=0) Or (H4=0) Then Begin M4Scal:=0; H3Pos:=Bak;
   End;
 End;
 M4VolHeader:=0;
 M4Have:=True;
End;

Procedure M4InitDirectMv;
Var I: LongInt;
Begin
 For I:=0 To 63 Do Begin
  M4DirScale[0,I]:=SmallInt((I-32)*LongInt(M4PBTime) Div LongInt(M4PPTime));
  M4DirScale[1,I]:=SmallInt((I-32)*(LongInt(M4PBTime)-LongInt(M4PPTime)) Div
   LongInt(M4PPTime));
 End;
End;

Function M4SpriteTrajectory: LongInt;
Var
 A,Rho,R,Alpha,Beta,W,H,MinAB,I,W2,H2,W3,H3,Len,X,Y,ShiftY,ShiftC,J: LongInt;
 SpriteRef: Array[0..3,0..1] Of Int64; VirtualRef: Array[0..1,0..1] Of Int64;
 SOff,SDel: Array[0..1,0..1] Of Int64; VopRef: Array[0..3,0..1] Of LongInt; D:
  Array[0..3,0..1] Of LongInt;
 Sd0,Sd1: Int64; Lim: Int64;
 Div500: Boolean;
Function Traj: LongInt;
Begin Traj:=H3GetVlc(M4VSpr); End;
Begin
 M4SpriteTrajectory:=-1;
 A:=2 Shl M4WarpAcc; Rho:=3-M4WarpAcc; R:=16 Div A; Alpha:=1; Beta:=0; W:=M4W;
  H:=M4H;
 Div500:=(M4DivxVer=500) And (M4DivxBuild=413);
 If (W<=0) Or (H<=0) Then Exit;
 VopRef[0,0]:=0; VopRef[0,1]:=0; VopRef[1,0]:=W; VopRef[1,1]:=0; VopRef[2,0]:=0;
  VopRef[2,1]:=H; VopRef[3,0]:=W; VopRef[3,1]:=H;
 FillChar(D,SizeOf(D),0);
 For I:=0 To M4NumWarp-1 Do Begin
  X:=0; Y:=0;
  Len:=Traj; If Len>0 Then X:=M4GetXbits(Len);
  If Not Div500 Then M4Marker;
  Len:=Traj; If Len>0 Then Y:=M4GetXbits(Len);
  M4Marker;
  D[I,0]:=X; D[I,1]:=Y;
 End;
 While (LongInt(1) Shl Alpha)<W Do Inc(Alpha);
 While (LongInt(1) Shl Beta)<H Do Inc(Beta);
 W2:=LongInt(1) Shl Alpha; H2:=LongInt(1) Shl Beta;
 If Div500 Then Begin
  SpriteRef[0,0]:=A*VopRef[0,0]+D[0,0]; SpriteRef[0,1]:=A*VopRef[0,1]+D[0,1];
  SpriteRef[1,0]:=A*VopRef[1,0]+D[0,0]+D[1,0]; SpriteRef[1,1]:=A*VopRef[1,1]+D[
   0,1]+D[1,1];
  SpriteRef[2,0]:=A*VopRef[2,0]+D[0,0]+D[2,0]; SpriteRef[2,1]:=A*VopRef[2,1]+D[
   0,1]+D[2,1];
 End Else Begin
  SpriteRef[0,0]:=(A Shr 1)*(2*VopRef[0,0]+D[0,0]); SpriteRef[0,1]:=(A Shr 1)*(
   2*VopRef[0,1]+D[0,1]);
  SpriteRef[1,0]:=(A Shr 1)*(2*VopRef[1,0]+D[0,0]+D[1,0]); SpriteRef[1,1]:=(A
   Shr 1)*(2*VopRef[1,1]+D[0,1]+D[1,1]);
  SpriteRef[2,0]:=(A Shr 1)*(2*VopRef[2,0]+D[0,0]+D[2,0]); SpriteRef[2,1]:=(A
   Shr 1)*(2*VopRef[2,1]+D[0,1]+D[2,1]);
 End;
 VirtualRef[0,0]:=16*(VopRef[0,0]+W2)+M4RDiv64((W-W2)*(R*SpriteRef[0,0]-16*
  Int64(VopRef[0,0]))+W2*(R*SpriteRef[1,0]-16*Int64(VopRef[1,0])),W);
 VirtualRef[0,1]:=16*VopRef[0,1]+M4RDiv64((W-W2)*(R*SpriteRef[0,1]-16*Int64(
  VopRef[0,1]))+W2*(R*SpriteRef[1,1]-16*Int64(VopRef[1,1])),W);
 VirtualRef[1,0]:=16*VopRef[0,0]+M4RDiv64((H-H2)*(R*SpriteRef[0,0]-16*Int64(
  VopRef[0,0]))+H2*(R*SpriteRef[2,0]-16*Int64(VopRef[2,0])),H);
 VirtualRef[1,1]:=16*(VopRef[0,1]+H2)+M4RDiv64((H-H2)*(R*SpriteRef[0,1]-16*
  Int64(VopRef[0,1]))+H2*(R*SpriteRef[2,1]-16*Int64(VopRef[2,1])),H);
 Case M4NumWarp Of
  0: Begin
   SOff[0,0]:=0; SOff[0,1]:=0; SOff[1,0]:=0; SOff[1,1]:=0;
   SDel[0,0]:=A; SDel[0,1]:=0; SDel[1,0]:=0; SDel[1,1]:=A;
   M4SpShift[0]:=0; M4SpShift[1]:=0;
  End;
  1: Begin
   SOff[0,0]:=SpriteRef[0,0]-A*VopRef[0,0];
   SOff[0,1]:=SpriteRef[0,1]-A*VopRef[0,1];
   SOff[1,0]:=((SpriteRef[0,0] Shr 1) Or (SpriteRef[0,0] And 1))-A*(VopRef[0,0]
    Div 2);
   SOff[1,1]:=((SpriteRef[0,1] Shr 1) Or (SpriteRef[0,1] And 1))-A*(VopRef[0,1]
    Div 2);
   SDel[0,0]:=A; SDel[0,1]:=0; SDel[1,0]:=0; SDel[1,1]:=A;
   M4SpShift[0]:=0; M4SpShift[1]:=0;
  End;
  2: Begin
   SOff[0,0]:=SpriteRef[0,0]*(Int64(1) Shl (Alpha+Rho))+(-R*SpriteRef[0,0]+
    VirtualRef[0,0])*(-Int64(VopRef[0,0]))+
     (R*SpriteRef[0,1]-VirtualRef[0,1])*(-Int64(VopRef[0,1]))+(Int64(1) Shl (
      Alpha+Rho-1));
   SOff[0,1]:=SpriteRef[0,1]*(Int64(1) Shl (Alpha+Rho))+(-R*SpriteRef[0,1]+
    VirtualRef[0,1])*(-Int64(VopRef[0,0]))+
     (-R*SpriteRef[0,0]+VirtualRef[0,0])*(-Int64(VopRef[0,1]))+(Int64(1) Shl (
      Alpha+Rho-1));
   SOff[1,0]:=(-R*SpriteRef[0,0]+VirtualRef[0,0])*(-2*Int64(VopRef[0,0])+1)+(R*
    SpriteRef[0,1]-VirtualRef[0,1])*(-2*Int64(VopRef[0,1])+1)+
     2*W2*R*SpriteRef[0,0]-16*W2+(Int64(1) Shl (Alpha+Rho+1));
   SOff[1,1]:=(-R*SpriteRef[0,1]+VirtualRef[0,1])*(-2*Int64(VopRef[0,0])+1)+(-R*
    SpriteRef[0,0]+VirtualRef[0,0])*(-2*Int64(VopRef[0,1])+1)+
     2*W2*R*SpriteRef[0,1]-16*W2+(Int64(1) Shl (Alpha+Rho+1));
   SDel[0,0]:=(-R*SpriteRef[0,0]+VirtualRef[0,0]);
   SDel[0,1]:=(R*SpriteRef[0,1]-VirtualRef[0,1]);
   SDel[1,0]:=(-R*SpriteRef[0,1]+VirtualRef[0,1]);
   SDel[1,1]:=(-R*SpriteRef[0,0]+VirtualRef[0,0]);
   M4SpShift[0]:=Alpha+Rho; M4SpShift[1]:=Alpha+Rho+2;
  End;
  3: Begin
   If Alpha<Beta Then MinAB:=Alpha Else MinAB:=Beta;
   W3:=W2 Shr MinAB; H3:=H2 Shr MinAB;
   SOff[0,0]:=SpriteRef[0,0]*(Int64(1) Shl (Alpha+Beta+Rho-MinAB))+(-R*
    SpriteRef[0,0]+VirtualRef[0,0])*H3*(-Int64(VopRef[0,0]))+
     (-R*SpriteRef[0,0]+VirtualRef[1,0])*W3*(-Int64(VopRef[0,1]))+(Int64(1) Shl
      (Alpha+Beta+Rho-MinAB-1));
   SOff[0,1]:=SpriteRef[0,1]*(Int64(1) Shl (Alpha+Beta+Rho-MinAB))+(-R*
    SpriteRef[0,1]+VirtualRef[0,1])*H3*(-Int64(VopRef[0,0]))+
     (-R*SpriteRef[0,1]+VirtualRef[1,1])*W3*(-Int64(VopRef[0,1]))+(Int64(1) Shl
      (Alpha+Beta+Rho-MinAB-1));
   SOff[1,0]:=(-R*SpriteRef[0,0]+VirtualRef[0,0])*H3*(-2*Int64(VopRef[0,0])+1)+(
    -R*SpriteRef[0,0]+VirtualRef[1,0])*W3*(-2*Int64(VopRef[0,1])+1)+
     2*W2*H3*R*SpriteRef[0,0]-16*W2*H3+(Int64(1) Shl (Alpha+Beta+Rho-MinAB+1));
   SOff[1,1]:=(-R*SpriteRef[0,1]+VirtualRef[0,1])*H3*(-2*Int64(VopRef[0,0])+1)+(
    -R*SpriteRef[0,1]+VirtualRef[1,1])*W3*(-2*Int64(VopRef[0,1])+1)+
     2*W2*H3*R*SpriteRef[0,1]-16*W2*H3+(Int64(1) Shl (Alpha+Beta+Rho-MinAB+1));
   SDel[0,0]:=(-R*SpriteRef[0,0]+VirtualRef[0,0])*H3;
   SDel[0,1]:=(-R*SpriteRef[0,0]+VirtualRef[1,0])*W3;
   SDel[1,0]:=(-R*SpriteRef[0,1]+VirtualRef[0,1])*H3;
   SDel[1,1]:=(-R*SpriteRef[0,1]+VirtualRef[1,1])*W3;
   M4SpShift[0]:=Alpha+Beta+Rho-MinAB; M4SpShift[1]:=Alpha+Beta+Rho-MinAB+2;
  End;
 End;
 If (SDel[0,0]=Int64(A) Shl M4SpShift[0]) And (SDel[0,1]=0) And (SDel[1,0]=0)
  And (SDel[1,1]=Int64(A) Shl M4SpShift[0]) Then Begin
  SOff[0,0]:=M4Sar64(SOff[0,0],M4SpShift[0]); SOff[0,1]:=M4Sar64(SOff[0,1],
   M4SpShift[0]);
  SOff[1,0]:=M4Sar64(SOff[1,0],M4SpShift[1]); SOff[1,1]:=M4Sar64(SOff[1,1],
   M4SpShift[1]);
  SDel[0,0]:=A; SDel[0,1]:=0; SDel[1,0]:=0; SDel[1,1]:=A;
  M4SpShift[0]:=0; M4SpShift[1]:=0;
  M4RealWarp:=1;
 End Else Begin
  ShiftY:=16-M4SpShift[0]; ShiftC:=16-M4SpShift[1];
  Lim:=2147483647;
  For I:=0 To 1 Do Begin
   If (ShiftC<0) Or (ShiftY<0) Or (Abs(SOff[0,I])>=(Lim Shr ShiftY)) Or (Abs(
    SOff[1,I])>=(Lim Shr ShiftC)) Or
    (Abs(SDel[0,I])>=(Lim Shr ShiftY)) Or (Abs(SDel[1,I])>=(Lim Shr ShiftY))
     Then Begin
    FillChar(M4SpOff,SizeOf(M4SpOff),0); FillChar(M4SpDelta,SizeOf(M4SpDelta),
     0); Exit;
   End;
  End;
  For I:=0 To 1 Do Begin
   SOff[0,I]:=SOff[0,I]*(Int64(1) Shl ShiftY); SOff[1,I]:=SOff[1,I]*(Int64(1)
    Shl ShiftC);
   SDel[0,I]:=SDel[0,I]*(Int64(1) Shl ShiftY); SDel[1,I]:=SDel[1,I]*(Int64(1)
    Shl ShiftY);
   M4SpShift[I]:=16;
  End;
  For I:=0 To 1 Do Begin
   Sd0:=SDel[I,0]-Int64(A)*65536; Sd1:=SDel[I,1]-Int64(A)*65536;
   If (Abs(SOff[0,I]+SDel[I,0]*(W+16))>=Lim) Or (Abs(SOff[0,I]+SDel[I,1]*(H+
    16))>=Lim) Or
    (Abs(SOff[0,I]+SDel[I,0]*(W+16)+SDel[I,1]*(H+16))>=Lim) Or (Abs(SDel[I,0]*(
     W+16))>=Lim) Or (Abs(SDel[I,1]*(H+16))>=Lim) Or
    (Abs(Sd0)>=Lim) Or (Abs(Sd1)>=Lim) Or (Abs(SOff[0,I]+Sd0*(W+16))>=Lim) Or (
     Abs(SOff[0,I]+Sd1*(H+16))>=Lim) Or
    (Abs(SOff[0,I]+Sd0*(W+16)+Sd1*(H+16))>=Lim) Then Begin
    FillChar(M4SpOff,SizeOf(M4SpOff),0); FillChar(M4SpDelta,SizeOf(M4SpDelta),
     0); Exit;
   End;
  End;
  M4RealWarp:=M4NumWarp;
 End;
 For I:=0 To 3 Do Begin
  M4SpOff[I And 1,I Shr 1]:=SOff[I And 1,I Shr 1];
  M4SpDelta[I And 1,I Shr 1]:=SDel[I And 1,I Shr 1];
 End;
 M4SpriteTrajectory:=0;
End;

Procedure M4NewPredSkip;
Var Ln: LongInt;
Begin
 Ln:=M4TIncBits+3; If Ln>15 Then Ln:=15;
 H3Bits(Ln);
 If H3Bit<>0 Then H3Bits(Ln);
 M4Marker;
End;

Function M4VopHeader: LongInt;
Var TimeIncr,TimeInc,I: LongInt;
Begin
 M4VopHeader:=0;
 M4McSel:=0;
 M4PType:=H3Bits(2);
 If (M4PType=2) And (M4LowDelay<>0) And (M4VolCtl=0) Then M4LowDelay:=0;
 If (M4DataPart<>0) And (M4PType<>2) Then M4Part:=1 Else M4Part:=0;
 TimeIncr:=0;
 While (H3Bit<>0) And (H3Pos<H3Size*8) Do Inc(TimeIncr);
 M4Marker;
 If (M4TIncBits=0) Or ((H3Show(M4TIncBits+1) And 1)=0) Then Begin
  M4TIncBits:=1;
  While M4TIncBits<16 Do Begin
   If (M4PType=1) Or ((M4PType=3) And (M4SprUsage=2)) Then Begin
    If (H3Show(M4TIncBits+6) And $37)=$30 Then Break;
   End Else If (H3Show(M4TIncBits+5) And $1F)=$18 Then Break;
   Inc(M4TIncBits);
  End;
 End;
 TimeInc:=H3Bits(M4TIncBits);
 If M4PType<>2 Then Begin
  M4LastTimeBase:=M4TimeBase;
  M4TimeBase:=M4TimeBase+TimeIncr;
  M4Time:=M4TimeBase*M4Res+TimeInc;
  If (M4Bugs And M4_BUG_UMP4)<>0 Then Begin
   If M4Time<M4LastNonBTime Then Begin Inc(M4TimeBase); Inc(M4Time,M4Res); End;
  End;
  M4PPTime:=(M4Time-M4LastNonBTime) And $FFFF;
  M4LastNonBTime:=M4Time;
 End Else Begin
  M4Time:=(M4LastTimeBase+TimeIncr)*M4Res+TimeInc;
  M4PBTime:=(M4PPTime-(M4LastNonBTime-M4Time)) And $FFFF;
  If (M4PPTime<=M4PBTime) Or (M4PPTime<=M4PPTime-M4PBTime) Or (M4PPTime<=0) Then
   Begin M4VopHeader:=M4_SKIPPED; Exit; End;
  M4InitDirectMv;
  If M4TFrame=0 Then M4TFrame:=M4PBTime;
  If M4TFrame=0 Then M4TFrame:=1;
  M4PPField:=((M4RDiv64(M4LastNonBTime,M4TFrame)-M4RDiv64(M4LastNonBTime-
   M4PPTime,M4TFrame))*2) And $FFFF;
  M4PBField:=((M4RDiv64(M4Time,M4TFrame)-M4RDiv64(M4LastNonBTime-M4PPTime,
   M4TFrame))*2) And $FFFF;
  If (M4PPField<=M4PBField) Or (M4PBField<=1) Then Begin
   M4PBField:=2; M4PPField:=4;
   If M4Prog=0 Then Begin M4VopHeader:=M4_SKIPPED; Exit; End;
  End;
 End;
 M4Marker;
 If H3Bit<>1 Then Begin M4VopHeader:=M4_SKIPPED; Exit; End;
 If M4NewPred<>0 Then M4NewPredSkip;
 If (M4PType=1) Or ((M4PType=3) And (M4SprUsage=2)) Then M4NoRnd:=H3Bit Else
  M4NoRnd:=0;
 I:=M4CplxI; If I>0 Then H3Skip(I);
 If M4PType<>0 Then Begin I:=M4CplxP; If I>0 Then H3Skip(I); End;
 If M4PType=2 Then Begin I:=M4CplxB; If I>0 Then H3Skip(I); End;
 If H3Left<3 Then Begin M4VopHeader:=-1; Exit; End;
 M4IntraDcThr:=M4DcThr[H3Bits(3)];
 If M4Prog=0 Then Begin M4Tff:=H3Bit; M4AltScan:=H3Bit; End Else M4AltScan:=0;
 If M4PType=3 Then Begin
  If M4SprUsage=2 Then Begin
   If M4SpriteTrajectory<0 Then Begin M4VopHeader:=-1; Exit; End;
  End Else If M4SprUsage=1 Then Fail(
   'mpeg4: sprites statiques non pris en charge.')
  Else Begin FillChar(M4SpOff,SizeOf(M4SpOff),0); FillChar(M4SpDelta,SizeOf(
   M4SpDelta),0); End;
 End;
 M4Qscale:=H3Bits(M4QuantPrec); M4ChromaQ:=M4Qscale;
 If M4Qscale=0 Then Begin M4VopHeader:=-1; Exit; End;
 If M4PType<>0 Then Begin
  M4FCode:=H3Bits(3);
  If M4FCode=0 Then Begin M4FCode:=1; M4VopHeader:=-1; Exit; End;
 End Else M4FCode:=1;
 If M4PType=2 Then Begin
  M4BCode:=H3Bits(3);
  If M4BCode=0 Then Begin M4BCode:=1; M4VopHeader:=-1; Exit; End;
 End Else M4BCode:=1;
 If M4Scal<>0 Then Begin
  If M4EnhType<>0 Then H3Bit;
  H3Skip(2);
 End;
 If (M4VoType=0) And (M4VolCtl=0) And (M4DivxVer=-1) And (M4PicNum=0) Then
  M4LowDelay:=1;
 Inc(M4PicNum);
End;

{ ff_mpeg4_workaround_bugs : pas de variantes STD_QPEL (encodeurs anciens) }
Function M4Workaround: Boolean;
Begin
 M4Workaround:=False;
 If (M4XvidBuild=-1) And (M4DivxVer=-1) And (M4LavcBuild=-1) Then Begin
  If (M4CTag='XVID') Or (M4CTag='XVIX') Or (M4CTag='RMP4') Or (M4CTag='ZMP4') Or
   (M4CTag='SIPP') Then M4XvidBuild:=0;
 End;
 If (M4XvidBuild=-1) And (M4DivxVer=-1) And (M4LavcBuild=-1) Then
  If (M4CTag='DIVX') And (M4VoType=0) And (M4VolCtl=0) Then M4DivxVer:=400;
 If (M4XvidBuild>=0) And (M4DivxVer>=0) Then Begin M4DivxVer:=-1; M4DivxBuild:=-
  1; End;
 If (M4CTag='XVIX') Then M4Bugs:=M4Bugs Or M4_BUG_XVIDILACE;
 If (M4CTag='UMP4') Then M4Bugs:=M4Bugs Or M4_BUG_UMP4;
 If (M4DivxVer>=500) And (M4DivxBuild<1814) Then M4Bugs:=M4Bugs Or
  M4_BUG_QPELCH;
 If (M4DivxVer>502) And (M4DivxBuild<1814) Then M4Bugs:=M4Bugs Or
  M4_BUG_QPELCH2;
 If (M4XvidBuild>=0) And (M4XvidBuild<=3) Then M4PadScore:=256*256*256*64;
 If (M4XvidBuild>=0) And (M4XvidBuild<=1) Then M4Bugs:=M4Bugs Or M4_BUG_QPELCH;
 If (M4XvidBuild>=0) And (M4XvidBuild<=12) Then M4Bugs:=M4Bugs Or M4_BUG_EDGE;
 If (M4XvidBuild>=0) And (M4XvidBuild<=32) Then M4Bugs:=M4Bugs Or M4_BUG_DCCLIP;
 { les comparaisons C sont non signees : -1 devient grand }
 If (M4LavcBuild>=0) And (M4LavcBuild<4653) Then M4Bugs:=M4Bugs Or
  M4_BUG_STDQPEL;
 If (M4LavcBuild>=0) And (M4LavcBuild<4655) Then M4Bugs:=M4Bugs Or
  M4_BUG_DIRBLK;
 If (M4LavcBuild>=0) And (M4LavcBuild<4670) Then M4Bugs:=M4Bugs Or M4_BUG_EDGE;
 If (M4LavcBuild>=0) And (M4LavcBuild<=4712) Then M4Bugs:=M4Bugs Or
  M4_BUG_DCCLIP;
 If M4DivxVer>=0 Then M4Bugs:=M4Bugs Or M4_BUG_DIRBLK;
 If (M4DivxVer=501) And (M4DivxBuild=20020416) Then M4PadScore:=256*256*256*64;
 If (M4DivxVer>=0) And (M4DivxVer<500) Then M4Bugs:=M4Bugs Or M4_BUG_EDGE;
 If M4DivxVer>=0 Then M4Bugs:=M4Bugs Or M4_BUG_HPELCH;
 If (M4Bugs And M4_BUG_STDQPEL)<>0 Then Fail(
  'mpeg4: flux d''un ancien encodeur libavcodec (qpel non standard) non pris e'+
  'n charge.');
End;

{ ---- tables de contexte, DC/AC (mpeg4video.h, mpeg4videodec.c) ---- }
Function M4Off: LongInt;
Begin M4Off:=M4MbS+1; End;

Function M4AcIx(N: LongInt): LongInt;   { indice (blocs de 16 valeurs) dans
 M4Dc/M4Ac }
Begin
 If N<4 Then M4AcIx:=M4B8S*(2*M4MbY+(N Shr 1))+2*M4MbX+(N And 1)+M4B8S+1
 Else M4AcIx:=M4MbS*M4MbY+M4MbX+M4MbS+1;
End;

Function M4PredDc(N,Level: LongInt; Var Dir: LongInt): LongInt;
Var A,B,C,Wrap,Pred,Scale,Ret,Ix,Pl: LongInt; D: PH3I16;
Begin
 If N<4 Then Scale:=M4YDc Else Scale:=M4CDc;
 If N<4 Then Begin Pl:=0; Wrap:=M4B8S; End Else Begin Pl:=N-3; Wrap:=M4MbS; End;
 Ix:=M4AcIx(N);
 D:=M4Dc[Pl];
 A:=D^[Ix-1]; B:=D^[Ix-1-Wrap]; C:=D^[Ix-Wrap];
 If (M4FirstLine<>0) And (N<>3) Then Begin
  If N<>2 Then Begin B:=1024; C:=1024; End;
  If (N<>1) And (M4MbX=M4ResyncX) Then Begin B:=1024; A:=1024; End;
 End;
 If (M4MbX=M4ResyncX) And (M4MbY=M4ResyncY+1) Then Begin
  If (N=0) Or (N=4) Or (N=5) Then B:=1024;
 End;
 If Abs(A-B)<Abs(B-C) Then Begin Pred:=C; Dir:=1; End Else Begin Pred:=A; Dir:=
  0; End;
 Pred:=(Pred+(Scale Shr 1)) Div Scale;
 Level:=Level+Pred; Ret:=Level;
 Level:=Level*Scale;
 If (Level And Not 2047)<>0 Then Begin
  If Level<0 Then Level:=0
  Else If (M4Bugs And M4_BUG_DCCLIP)=0 Then Level:=2047;
 End;
 D^[Ix]:=SmallInt(Level);
 M4PredDc:=Ret;
End;

Procedure M4PredAc(N,Dir: LongInt);
Var Pl,Ix,Wrap,Xy,I,Base,Qo: LongInt; A: PH3I16; Qs: PEABuffer;
Begin
 If N<4 Then Pl:=0 Else Pl:=N-3;
 If N<4 Then Wrap:=M4B8S Else Wrap:=M4MbS;
 Ix:=M4AcIx(N);
 A:=M4Ac[Pl];
 Qs:=M4P[M4CurI].Qs;
 If M4AcPred<>0 Then Begin
  If Dir=0 Then Begin
   Xy:=M4MbX-1+M4MbY*M4MbS+M4Off;
   Base:=(Ix-1)*16;
   If (M4MbX=0) Or (M4Qscale=Qs^[Xy]) Or (N=1) Or (N=3) Then Begin
    For I:=1 To 7 Do M4Blk[N][I*8]:=SmallInt(M4Blk[N][I*8]+A^[Base+I]);
   End Else Begin
    For I:=1 To 7 Do M4Blk[N][I*8]:=SmallInt(M4Blk[N][I*8]+M4RDiv(A^[Base+I]*
     Qs^[Xy],M4Qscale));
   End;
  End Else Begin
   Xy:=M4MbX+M4MbY*M4MbS-M4MbS+M4Off;
   Base:=(Ix-Wrap)*16;
   If (M4MbY=0) Or (M4Qscale=Qs^[Xy]) Or (N=2) Or (N=3) Then Begin
    For I:=1 To 7 Do M4Blk[N][I]:=SmallInt(M4Blk[N][I]+A^[Base+I+8]);
   End Else Begin
    For I:=1 To 7 Do M4Blk[N][I]:=SmallInt(M4Blk[N][I]+M4RDiv(A^[Base+I+8]*Qs^[
     Xy],M4Qscale));
   End;
  End;
 End;
 Base:=Ix*16;
 For I:=1 To 7 Do A^[Base+I]:=M4Blk[N][I*8];
 For I:=1 To 7 Do A^[Base+8+I]:=M4Blk[N][I];
End;

Procedure M4CleanIntraEntries;   { ff_clean_intra_table_entries }
Var Ix,I,Cx: LongInt;
Begin
 Ix:=M4AcIx(0);
 M4Dc[0]^[Ix]:=1024; M4Dc[0]^[Ix+1]:=1024; M4Dc[0]^[Ix+M4B8S]:=1024; M4Dc[0]^[
  Ix+1+M4B8S]:=1024;
 FillChar(M4Ac[0]^[Ix*16],64,0);
 FillChar(M4Ac[0]^[(Ix+M4B8S)*16],64,0);
 Cx:=M4AcIx(4);
 M4Dc[1]^[Cx]:=1024; M4Dc[2]^[Cx]:=1024;
 FillChar(M4Ac[1]^[Cx*16],32,0); FillChar(M4Ac[2]^[Cx*16],32,0);
 M4IntraTab^[M4MbX+M4MbY*M4MbS+M4Off]:=0;
 If (M4Ms>=3) And (M4CodedBlk<>Nil) Then Begin
  M4CodedBlk^[Ix]:=0; M4CodedBlk^[Ix+1]:=0; M4CodedBlk^[Ix+M4B8S]:=0;
   M4CodedBlk^[Ix+1+M4B8S]:=0;
 End;
End;

Procedure M4CleanBuffers;   { ff_mpeg4_clean_buffers }
Var LXy,CXy: LongInt;
Begin
 LXy:=(2*M4MbY-1)*M4B8S+M4MbX*2-1+M4B8S+1;
 CXy:=(M4MbY-1)*M4MbS+M4MbX-1+M4MbS+1;
 FillChar(M4Ac[0]^[LXy*16],(M4B8S*2+1)*32,0);
 FillChar(M4Ac[1]^[CXy*16],(M4MbS+1)*32,0);
 FillChar(M4Ac[2]^[CXy*16],(M4MbS+1)*32,0);
 M4LastMv[0,0,0]:=0; M4LastMv[0,0,1]:=0; M4LastMv[1,0,0]:=0; M4LastMv[1,0,1]:=0;
End;

Function M4DecodeDc(N: LongInt; Var Dir: LongInt): LongInt;
Var Code,Level: LongInt;
Begin
 If N<4 Then Code:=H3GetVlc(M4VDcL) Else Code:=H3GetVlc(M4VDcC);
 If (Code<0) Or (Code>9) Then Begin M4DecodeDc:=-1; Exit; End;
 If Code=0 Then Level:=0
 Else Begin
  Level:=M4GetXbits(Code);
  If Code>8 Then H3Bit;
 End;
 M4DecodeDc:=M4PredDc(N,Level,Dir);
End;

{ ---- blocs ---- }
Function M4Block(N,Coded,Intra,UseDcVlc,Rvlc: LongInt): LongInt;
Var
 Level,I,Last,Run,Qmul,Qadd,Dir,Sym,Lev0,LastF,Sg,B1,B2: LongInt; Rl: PM4Rl;
  Scan: PEABuffer; Blk: ^TH3Blk;
Label NotCoded;
Begin
 M4Block:=-1;
 Blk:=@M4Blk[N];
 Dir:=0; Qmul:=1; Qadd:=0; Rl:=@M4RlIntra; Scan:=@H3Zigzag;
 If Intra<>0 Then Begin
  If UseDcVlc<>0 Then Begin
   If M4Part<>0 Then Begin
    If N<4 Then Level:=M4Dc[0]^[M4AcIx(N)] Else Level:=M4Dc[N-3]^[M4AcIx(N)];
    If N<4 Then Level:=(Level+(M4YDc Shr 1)) Div M4YDc Else Level:=(Level+(M4CDc
     Shr 1)) Div M4CDc;
    Dir:=(M4DirTab^[M4MbX+M4MbY*M4MbS+M4Off] Shl N) And 32;
   End Else Begin
    Level:=M4DecodeDc(N,Dir);
    If Level<0 Then Exit;
   End;
   Blk^[0]:=SmallInt(Level);
   I:=0;
  End Else Begin
   I:=-1;
   M4PredDc(N,0,Dir);
  End;
  If Coded=0 Then Goto NotCoded;
  If Rvlc<>0 Then Rl:=@M4RlRvIntra Else Rl:=@M4RlIntra;
  If M4AcPred<>0 Then Begin
   If Dir=0 Then Begin If M4AltScan<>0 Then Scan:=@H3AltV Else Scan:=@H3AltV;
    End   { gauche }
   Else Begin If M4AltScan<>0 Then Scan:=@H3AltV Else Scan:=@H3AltH; End;
    { haut }
  End Else Begin
   If M4AltScan<>0 Then Scan:=@H3AltV Else Scan:=@H3Zigzag;
  End;
 End Else Begin
  I:=-1;
  If Coded=0 Then Begin M4BlkLast[N]:=I; M4Block:=0; Exit; End;
  If Rvlc<>0 Then Rl:=@M4RlRvInter Else Rl:=@M4RlInter;
  If M4AltScan<>0 Then Scan:=@H3AltV Else Scan:=@H3Zigzag;
  If M4MpegQuant=0 Then Begin Qmul:=M4Qscale Shl 1; Qadd:=(M4Qscale-1) Or 1;
   End;
 End;
 Repeat
  Sym:=H3GetVlc(Rl^.Vlc);
  If Sym<0 Then Exit;
  If Sym=Rl^.N Then Begin
   If Rvlc<>0 Then Begin
    If H3Bit=0 Then Exit;
    Last:=H3Bit; Run:=H3Bits(6);
    If H3Bit=0 Then Exit;
    Level:=H3Bits(11);
    If H3Bits(5)<>$10 Then Exit;
    Level:=Level*Qmul+Qadd;
    If H3Bit<>0 Then Level:=-Level;
    Inc(I,Run+1);
    If Last<>0 Then Inc(I,192);
   End Else Begin
    B1:=H3Bit;
    If B1<>0 Then Begin
     B2:=H3Bit;
     If B2<>0 Then Begin
      { troisieme echappement }
      Last:=H3Bit; Run:=H3Bits(6);
      If H3Bit=0 Then Exit;
      Level:=H3SBits(12); H3Skip(12);
      If H3Bit=0 Then Exit;
      If Level>0 Then Level:=Level*Qmul+Qadd Else Level:=Level*Qmul-Qadd;
      If (Level+2048>4095) Or (Level+2048<0) Then Begin If Level<0 Then Level:=-
       2048 Else Level:=2047; End;
      Inc(I,Run+1);
      If Last<>0 Then Inc(I,192);
     End Else Begin
      { deuxieme echappement }
      Sym:=H3GetVlc(Rl^.Vlc);
      If (Sym<0) Or (Sym=Rl^.N) Then Exit;
      Lev0:=Rl^.Lev[Sym]; LastF:=Ord(Sym>=Rl^.Last);
      Run:=Rl^.Run[Sym];
      Inc(I,Run+1+Rl^.MaxRun[LastF,Lev0]+1);
      If LastF<>0 Then Inc(I,192);
      Level:=Lev0*Qmul+Qadd;
      If H3Bit<>0 Then Level:=-Level;
     End;
    End Else Begin
     { premier echappement }
     Sym:=H3GetVlc(Rl^.Vlc);
     If (Sym<0) Or (Sym=Rl^.N) Then Exit;
     Lev0:=Rl^.Lev[Sym]; LastF:=Ord(Sym>=Rl^.Last);
     Run:=Rl^.Run[Sym];
     Inc(I,Run+1);
     If LastF<>0 Then Inc(I,192);
     Level:=(Lev0+Rl^.MaxLev[LastF,Run])*Qmul+Qadd;
     If H3Bit<>0 Then Level:=-Level;
    End;
   End;
  End Else Begin
   Lev0:=Rl^.Lev[Sym]; LastF:=Ord(Sym>=Rl^.Last);
   Inc(I,Rl^.Run[Sym]+1);
   If LastF<>0 Then Inc(I,192);
   Level:=Lev0*Qmul+Qadd;
   If H3Bit<>0 Then Level:=-Level;
  End;
  If I>62 Then Begin
   Dec(I,192);
   If (I And Not 63)<>0 Then Exit;
   Blk^[Scan^[I]]:=SmallInt(Level);
   Break;
  End;
  Blk^[Scan^[I]]:=SmallInt(Level);
 Until False;
NotCoded:
 If Intra<>0 Then Begin
  If UseDcVlc=0 Then Begin
   Blk^[0]:=SmallInt(M4PredDc(N,Blk^[0],Dir));
   If I=-1 Then I:=0;
  End;
  M4PredAc(N,Dir);
  If M4AcPred<>0 Then I:=63;
 End;
 M4BlkLast[N]:=I;
 M4Block:=0;
End;

{ ---- vecteurs de mouvement ---- }
Function M4MvOff: LongInt;
Begin M4MvOff:=M4B8S+8; End;

Function M4MvGet(Pic,M,C: LongInt): LongInt;
Begin M4MvGet:=M4P[Pic].Mv^[(M+M4B8S+8)*2+C]; End;
Procedure M4MvSet(Pic,M,C,V: LongInt);
Begin M4P[Pic].Mv^[(M+M4B8S+8)*2+C]:=SmallInt(V); End;

Function M4PredMotion(Block: LongInt; Var Px,Py: LongInt): LongInt;
Var Wrap,M,A0,A1,B0,B1,C0,C1,Off: LongInt;
Begin
 Wrap:=M4B8S;
 M:=M4B8S*2*M4MbY+2*M4MbX+(Block And 1)+(Block Shr 1)*M4B8S;
 Case Block Of 0: Off:=2; 1,2: Off:=1; Else Off:=-1; End;
 A0:=M4MvGet(M4CurI,M-1,0); A1:=M4MvGet(M4CurI,M-1,1);
 If (M4FirstLine<>0) And (Block<3) Then Begin
  If Block=0 Then Begin
   If M4MbX=M4ResyncX Then Begin Px:=0; Py:=0; End
   Else If M4MbX+1=M4ResyncX Then Begin
    C0:=M4MvGet(M4CurI,M+Off-Wrap,0); C1:=M4MvGet(M4CurI,M+Off-Wrap,1);
    If M4MbX=0 Then Begin Px:=C0; Py:=C1; End Else Begin Px:=H3Mid(A0,0,C0);
     Py:=H3Mid(A1,0,C1); End;
   End Else Begin Px:=A0; Py:=A1; End;
  End Else If Block=1 Then Begin
   If M4MbX+1=M4ResyncX Then Begin
    C0:=M4MvGet(M4CurI,M+Off-Wrap,0); C1:=M4MvGet(M4CurI,M+Off-Wrap,1);
    Px:=H3Mid(A0,0,C0); Py:=H3Mid(A1,0,C1);
   End Else Begin Px:=A0; Py:=A1; End;
  End Else Begin
   B0:=M4MvGet(M4CurI,M-Wrap,0); B1:=M4MvGet(M4CurI,M-Wrap,1);
   C0:=M4MvGet(M4CurI,M+Off-Wrap,0); C1:=M4MvGet(M4CurI,M+Off-Wrap,1);
   If M4MbX=M4ResyncX Then Begin A0:=0; A1:=0; M4MvSet(M4CurI,M-1,0,0); M4MvSet(
    M4CurI,M-1,1,0); End;
   Px:=H3Mid(A0,B0,C0); Py:=H3Mid(A1,B1,C1);
  End;
 End Else Begin
  B0:=M4MvGet(M4CurI,M-Wrap,0); B1:=M4MvGet(M4CurI,M-Wrap,1);
  C0:=M4MvGet(M4CurI,M+Off-Wrap,0); C1:=M4MvGet(M4CurI,M+Off-Wrap,1);
  Px:=H3Mid(A0,B0,C0); Py:=H3Mid(A1,B1,C1);
 End;
 M4PredMotion:=M;
End;

Procedure M4FillMv4(Mx,My: LongInt);   { quatre blocs du macrobloc courant }
Var M: LongInt;
Begin
 M:=M4B8S*2*M4MbY+2*M4MbX;
 M4MvSet(M4CurI,M,0,Mx); M4MvSet(M4CurI,M,1,My);
 M4MvSet(M4CurI,M+1,0,Mx); M4MvSet(M4CurI,M+1,1,My);
 M4MvSet(M4CurI,M+M4B8S,0,Mx); M4MvSet(M4CurI,M+M4B8S,1,My);
 M4MvSet(M4CurI,M+1+M4B8S,0,Mx); M4MvSet(M4CurI,M+1+M4B8S,1,My);
End;

Function M4Rshift(A,B: LongInt): LongInt;
Begin
 If A>0 Then M4Rshift:=M4Sar(A+((LongInt(1) Shl B) Shr 1),B)
 Else M4Rshift:=M4Sar(A+((LongInt(1) Shl B) Shr 1)-1,B);
End;

Function M4GetAmv(N: LongInt): LongInt;
Var X,Y,MbV,Sum,Dx,Dy,Shift,Len,A,V: LongInt;
Begin
 Len:=LongInt(1) Shl (M4FCode+4);
 A:=M4WarpAcc;
 If (M4Bugs And M4_BUG_AMV)<>0 Then Len:=Len Shr M4QuarterS;
 If M4RealWarp=1 Then Begin
  If (M4DivxVer=500) And (M4DivxBuild=413) And (A>=M4QuarterS) Then Sum:=
   LongInt(M4SpOff[0,N]) Div (LongInt(1) Shl (A-M4QuarterS))
  Else Sum:=M4Rshift(LongInt(M4SpOff[0,N])*(LongInt(1) Shl M4QuarterS),A);
 End Else Begin
  Dx:=LongInt(M4SpDelta[N,0]); Dy:=LongInt(M4SpDelta[N,1]); Shift:=M4SpShift[0];
  If N<>0 Then Dy:=Dy-(LongInt(1) Shl (Shift+A+1)) Else Dx:=Dx-(LongInt(1) Shl (
   Shift+A+1));
  MbV:=LongInt(M4SpOff[0,N])+Dx*M4MbX*16+Dy*M4MbY*16;
  Sum:=0;
  For Y:=0 To 15 Do Begin
   V:=MbV+Dy*Y;
   For X:=0 To 15 Do Begin Sum:=Sum+M4Sar(V,Shift); V:=V+Dx; End;
  End;
  Sum:=M4Rshift(Sum,A+8-M4QuarterS);
 End;
 If Sum<-Len Then Sum:=-Len Else If Sum>=Len Then Sum:=Len-1;
 M4GetAmv:=Sum;
End;

Procedure M4UpdateMotion;
Var MbXy,Mx,My,I: LongInt;
Begin
 MbXy:=M4MbY*M4MbS+M4MbX+M4Off;
 M4P[M4CurI].Sk^[MbXy]:=M4Skip;
 If M4MvType<>1 Then Begin
  If M4MbIntra<>0 Then Begin Mx:=0; My:=0; End
  Else If M4MvType=0 Then Begin Mx:=M4Mv[0,0,0]; My:=M4Mv[0,0,1]; End
  Else Begin
   Mx:=M4Mv[0,0,0]+M4Mv[0,1,0]; My:=M4Mv[0,0,1]+M4Mv[0,1,1];
   Mx:=M4Sar(Mx,1) Or (Mx And 1);
   For I:=0 To 1 Do Begin
    M4PField^[(I*M4TabN+MbXy)*2]:=SmallInt(M4Mv[0,I,0]); M4PField^[(I*M4TabN+
     MbXy)*2+1]:=SmallInt(M4Mv[0,I,1]);
   End;
   M4P[M4CurI].Ref^[4*MbXy]:=M4FieldSel[0,0]; M4P[M4CurI].Ref^[4*MbXy+1]:=
    M4FieldSel[0,0];
   M4P[M4CurI].Ref^[4*MbXy+2]:=M4FieldSel[0,1]; M4P[M4CurI].Ref^[4*MbXy+3]:=
    M4FieldSel[0,1];
  End;
  M4FillMv4(Mx,My);
 End;
End;

{ ---- mode direct (mpeg4video.c) ---- }
Procedure M4SetOneDirectMv(Mx,My,I: LongInt);
Var M,PMx,PMy,TimePP,TimePB,V0: LongInt;
Begin
 M:=M4B8S*(2*M4MbY+(I Shr 1))+2*M4MbX+(I And 1);
 TimePP:=M4PPTime And $FFFF; TimePB:=M4PBTime And $FFFF;
 PMx:=M4MvGet(M4NextI,M,0);
 If (PMx+32>=0) And (PMx+32<64) Then Begin
  M4Mv[0,I,0]:=M4DirScale[0,PMx+32]+Mx;
  If Mx<>0 Then M4Mv[1,I,0]:=M4Mv[0,I,0]-PMx Else M4Mv[1,I,0]:=M4DirScale[1,PMx+
   32];
 End Else Begin
  M4Mv[0,I,0]:=PMx*TimePB Div TimePP+Mx;
  If Mx<>0 Then M4Mv[1,I,0]:=M4Mv[0,I,0]-PMx Else M4Mv[1,I,0]:=PMx*(TimePB-
   TimePP) Div TimePP;
 End;
 PMy:=M4MvGet(M4NextI,M,1);
 If (PMy+32>=0) And (PMy+32<64) Then Begin
  M4Mv[0,I,1]:=M4DirScale[0,PMy+32]+My;
  If My<>0 Then M4Mv[1,I,1]:=M4Mv[0,I,1]-PMy Else M4Mv[1,I,1]:=M4DirScale[1,PMy+
   32];
 End Else Begin
  M4Mv[0,I,1]:=PMy*TimePB Div TimePP+My;
  If My<>0 Then M4Mv[1,I,1]:=M4Mv[0,I,1]-PMy Else M4Mv[1,I,1]:=PMy*(TimePB-
   TimePP) Div TimePP;
 End;
End;

Function M4SetDirectMv(Mx,My: LongInt): LongInt;
Var MbIndex,Col,I,FS,TimePP,TimePB,Xy: LongInt;
Begin
 MbIndex:=M4MbX+M4MbY*M4MbS;
 Col:=M4P[M4NextI].Mt^[MbIndex+M4Off];
 If (Col And M4_8X8)<>0 Then Begin
  M4MvType:=1;
  For I:=0 To 3 Do M4SetOneDirectMv(Mx,My,I);
  M4SetDirectMv:=M4_DIRECT Or M4_8X8 Or M4_L0 Or M4_L1;
 End Else If (Col And M4_INTERLACED)<>0 Then Begin
  M4MvType:=2;
  Xy:=MbIndex+M4Off;
  For I:=0 To 1 Do Begin
   FS:=M4P[M4NextI].Ref^[4*Xy+2*I];
   M4FieldSel[0,I]:=FS; M4FieldSel[1,I]:=I;
   If M4Tff<>0 Then Begin TimePP:=(M4PPField-FS+I) And $FFFF; TimePB:=(
    M4PBField-FS+I) And $FFFF; End
   Else Begin TimePP:=(M4PPField+FS-I) And $FFFF; TimePB:=(M4PBField+FS-I) And
    $FFFF; End;
   M4Mv[0,I,0]:=M4PField^[(I*M4TabN+Xy)*2]*TimePB Div TimePP+Mx;
   M4Mv[0,I,1]:=M4PField^[(I*M4TabN+Xy)*2+1]*TimePB Div TimePP+My;
   If Mx<>0 Then M4Mv[1,I,0]:=M4Mv[0,I,0]-M4PField^[(I*M4TabN+Xy)*2]
   Else M4Mv[1,I,0]:=M4PField^[(I*M4TabN+Xy)*2]*(TimePB-TimePP) Div TimePP;
   If My<>0 Then M4Mv[1,I,1]:=M4Mv[0,I,1]-M4PField^[(I*M4TabN+Xy)*2+1]
   Else M4Mv[1,I,1]:=M4PField^[(I*M4TabN+Xy)*2+1]*(TimePB-TimePP) Div TimePP;
  End;
  M4SetDirectMv:=M4_DIRECT Or M4_16X8 Or M4_L0 Or M4_L1 Or M4_INTERLACED;
 End Else Begin
  M4SetOneDirectMv(Mx,My,0);
  For I:=1 To 3 Do Begin
   M4Mv[0,I,0]:=M4Mv[0,0,0]; M4Mv[0,I,1]:=M4Mv[0,0,1];
   M4Mv[1,I,0]:=M4Mv[1,0,0]; M4Mv[1,I,1]:=M4Mv[1,0,1];
  End;
  If ((M4Bugs And M4_BUG_DIRBLK)<>0) Or (M4QuarterS=0) Then M4MvType:=0 Else
   M4MvType:=1;
  M4SetDirectMv:=M4_DIRECT Or M4_16X16 Or M4_L0 Or M4_L1;
 End;
End;

{ ---- fin de tranche / paquets video ---- }
Function M4PrefixLength: LongInt;
Var M: LongInt;
Begin
 Case M4PType Of
  0: M4PrefixLength:=16;
  1,3: M4PrefixLength:=M4FCode+15;
  2: Begin M:=M4FCode; If M4BCode>M Then M:=M4BCode; If M<2 Then M:=2;
   M4PrefixLength:=M+15; End;
  Else M4PrefixLength:=-1;
 End;
End;

Function M4IsResync: LongInt;
Var BitsCount,V,Len,MbNumBits,MbNum,Save: LongInt;
Const Prefix: Array[0..7] Of Word=($7F00,$7E00,$7C00,$7800,$7000,$6000,$4000,
 $0000);
Begin
 M4IsResync:=0;
 BitsCount:=H3Pos;
 V:=H3Show(16);
 If ((M4Bugs And M4_BUG_NOPAD)<>0) And (M4ResyncMarker=0) Then Exit;
 While V<=$FF Do Begin
  If (M4PType=2) Or ((V Shr (8-M4PType))<>1) Or (M4Part<>0) Then Break;
  H3Skip(8+M4PType);
  Inc(BitsCount,8+M4PType);
  V:=H3Show(16);
 End;
 If BitsCount+8>=H3Size*8 Then Begin
  V:=V Shr 8;
  V:=V Or (($7F) Shr (7-(BitsCount And 7)));
  If V=$7F Then M4IsResync:=M4MbNum;
 End Else Begin
  If V=Prefix[BitsCount And 7] Then Begin
   MbNumBits:=M4Log2(M4MbNum-1)+1;
   Save:=H3Pos;
   H3Skip(1);
   H3Align;
   Len:=0;
   While Len<32 Do Begin If H3Bit<>0 Then Break; Inc(Len); End;
   MbNum:=H3Bits(MbNumBits);
   If (MbNum=0) Or (MbNum>M4MbNum) Or (H3Pos+6>H3Size*8) Then MbNum:=-1;
   H3Pos:=Save;
   If Len>=M4PrefixLength Then M4IsResync:=MbNum;
  End;
 End;
End;

Function M4VideoPacketHeader: LongInt;
Var MbNumBits,Len,MbNum,Q,HeaderExt,TimeIncr: LongInt;
Begin
 M4VideoPacketHeader:=-1;
 MbNumBits:=M4Log2(M4MbNum-1)+1;
 HeaderExt:=0;
 If H3Pos>H3Size*8-20 Then Exit;
 Len:=0;
 While Len<32 Do Begin If H3Bit<>0 Then Break; Inc(Len); End;
 If Len<>M4PrefixLength Then Exit;
 MbNum:=H3Bits(MbNumBits);
 If (MbNum>=M4MbNum) Or (MbNum=0) Then Exit;
 M4MbX:=MbNum Mod M4MbW; M4MbY:=MbNum Div M4MbW;
 Q:=H3Bits(M4QuantPrec);
 If Q<>0 Then Begin M4Qscale:=Q; M4ChromaQ:=Q; End;
 HeaderExt:=H3Bit;
 If HeaderExt<>0 Then Begin
  TimeIncr:=0;
  While (H3Bit<>0) And (H3Pos<H3Size*8) Do Inc(TimeIncr);
  M4Marker;
  H3Skip(M4TIncBits);
  M4Marker;
  H3Skip(2);
  H3Skip(3);
  If (M4PType=3) And (M4SprUsage=2) Then Begin
   If M4SpriteTrajectory<0 Then Exit;
  End;
  If M4PType<>0 Then H3Bits(3);
  If M4PType=2 Then H3Bits(3);
 End;
 If M4NewPred<>0 Then M4NewPredSkip;
 M4VideoPacketHeader:=0;
End;

{ ---- macroblocs ---- }
Const M4QuantTab: Array[0..3] Of ShortInt=(-1,-2,1,2);

Procedure M4ClearBlocks;
Var I: LongInt;
Begin
 FillChar(M4Blk,SizeOf(M4Blk),0);
 For I:=0 To 5 Do M4BlkLast[I]:=-1;
End;

Function M4TypeIndex: LongInt;
Begin M4TypeIndex:=M4MbX+M4MbY*M4MbS+M4Off; End;

Function M4DecodeMb: LongInt;
Label Fin;
Var
 Cbpc,Cbpy,I,Cbp,Px,Py,Mx,My,Dquant,Xy,Modb1,Modb2,MbType,Next,Delta,M,UseDc,
  SelFlag: LongInt;
 IsIntra: Boolean; Mt: PM4L32;
Begin
 M4DecodeMb:=M4_SLICE_ERR;
 Mt:=M4P[M4CurI].Mt;
 Xy:=M4TypeIndex;
 M4ClearBlocks;
 IsIntra:=False; Dquant:=0; Cbp:=0;
 If (M4PType=1) Or (M4PType=3) Then Begin
  Repeat
   If H3Bit<>0 Then Begin
    M4MbIntra:=0;
    For I:=0 To 5 Do M4BlkLast[I]:=-1;
    M4MvDir:=1; M4MvType:=0;
    If (M4PType=3) And (M4SprUsage=2) Then Begin
     Mt^[Xy]:=M4_SKIP Or M4_GMC Or M4_16X16 Or M4_L0;
     M4McSel:=1;
     M4Mv[0,0,0]:=M4GetAmv(0); M4Mv[0,0,1]:=M4GetAmv(1);
     M4Skip:=0;
    End Else Begin
     Mt^[Xy]:=M4_SKIP Or M4_16X16 Or M4_L0;
     M4McSel:=0;
     M4Mv[0,0,0]:=0; M4Mv[0,0,1]:=0;
     M4Skip:=1;
    End;
    Goto Fin;
   End;
   Cbpc:=H3GetVlc(H3VInter);
   If Cbpc<0 Then Exit;
  Until Cbpc<>20;
  Dquant:=Cbpc And 8;
  M4MbIntra:=Ord((Cbpc And 4)<>0);
  If M4MbIntra<>0 Then IsIntra:=True
  Else Begin
   If (M4PType=3) And (M4SprUsage=2) And ((Cbpc And 16)=0) Then M4McSel:=H3Bit
    Else M4McSel:=0;
   Cbpy:=H3GetVlc(H3VCbpy);
   If Cbpy<0 Then Exit;
   Cbpy:=Cbpy Xor $F;
   Cbp:=(Cbpc And 3) Or (Cbpy Shl 2);
   If Dquant<>0 Then M4SetQscale(M4Qscale+M4QuantTab[H3Bits(2)]);
   If (M4Prog=0) And ((Cbp<>0) Or ((M4Bugs And M4_BUG_XVIDILACE)<>0)) Then
    M4IDct:=H3Bit;
   M4MvDir:=1;
   If (Cbpc And 16)=0 Then Begin
    If M4McSel<>0 Then Begin
     Mt^[Xy]:=M4_GMC Or M4_16X16 Or M4_L0;
     M4MvType:=0;
     Mx:=M4GetAmv(0); My:=M4GetAmv(1);
     M4Mv[0,0,0]:=Mx; M4Mv[0,0,1]:=My;
    End Else If (M4Prog=0) And (H3Bit<>0) Then Begin
     Mt^[Xy]:=M4_16X8 Or M4_L0 Or M4_INTERLACED;
     M4MvType:=2;
     M4FieldSel[0,0]:=H3Bit; M4FieldSel[0,1]:=H3Bit;
     M4PredMotion(0,Px,Py);
     For I:=0 To 1 Do Begin
      Mx:=H3DecMotion(Px,M4FCode);
      If Mx>=$FFFF Then Exit;
      My:=H3DecMotion(Py Div 2,M4FCode);
      If My>=$FFFF Then Exit;
      M4Mv[0,I,0]:=Mx; M4Mv[0,I,1]:=My;
     End;
    End Else Begin
     Mt^[Xy]:=M4_16X16 Or M4_L0;
     M4MvType:=0;
     M4PredMotion(0,Px,Py);
     Mx:=H3DecMotion(Px,M4FCode);
     If Mx>=$FFFF Then Exit;
     My:=H3DecMotion(Py,M4FCode);
     If My>=$FFFF Then Exit;
     M4Mv[0,0,0]:=Mx; M4Mv[0,0,1]:=My;
    End;
   End Else Begin
    Mt^[Xy]:=M4_8X8 Or M4_L0;
    M4MvType:=1;
    For I:=0 To 3 Do Begin
     M:=M4PredMotion(I,Px,Py);
     Mx:=H3DecMotion(Px,M4FCode);
     If Mx>=$FFFF Then Exit;
     My:=H3DecMotion(Py,M4FCode);
     If My>=$FFFF Then Exit;
     M4Mv[0,I,0]:=Mx; M4Mv[0,I,1]:=My;
     M4MvSet(M4CurI,M,0,Mx); M4MvSet(M4CurI,M,1,My);
    End;
   End;
  End;
 End Else If M4PType=2 Then Begin
  M4MbIntra:=0; M4McSel:=0;
  If M4MbX=0 Then Begin
   For I:=0 To 1 Do Begin M4LastMv[I,0,0]:=0; M4LastMv[I,0,1]:=0; M4LastMv[I,1,
    0]:=0; M4LastMv[I,1,1]:=0; End;
  End;
  M4Skip:=M4P[M4NextI].Sk^[M4MbY*M4MbS+M4MbX+M4Off];
  If M4Skip<>0 Then Begin
   For I:=0 To 5 Do M4BlkLast[I]:=-1;
   M4MvDir:=1; M4MvType:=0;
   M4Mv[0,0,0]:=0; M4Mv[0,0,1]:=0; M4Mv[1,0,0]:=0; M4Mv[1,0,1]:=0;
   Mt^[Xy]:=M4_SKIP Or M4_16X16 Or M4_L0;
   Goto Fin;
  End;
  Modb1:=H3Bit;
  If Modb1<>0 Then Begin
   MbType:=M4_DIRECT Or M4_SKIP Or M4_L0 Or M4_L1;
   Cbp:=0;
  End Else Begin
   Modb2:=H3Bit;
   I:=0;
   While H3Bit=0 Do Begin
    Inc(I);
    If I>=3 Then Begin H3Bit; Break; End;
   End;
   Case I Of
    0: MbType:=M4_DIRECT Or M4_L0 Or M4_L1;
    1: MbType:=M4_L0 Or M4_L1 Or M4_16X16;
    2: MbType:=M4_L1 Or M4_16X16;
    Else MbType:=M4_L0 Or M4_16X16;
   End;
   If Modb2<>0 Then Cbp:=0 Else Cbp:=H3Bits(6);
   If ((MbType And M4_DIRECT)=0) And (Cbp<>0) Then Begin
    If H3Bit<>0 Then M4SetQscale(M4Qscale+H3Bit*4-2);
   End;
   If M4Prog=0 Then Begin
    If Cbp<>0 Then M4IDct:=H3Bit;
    If ((MbType And M4_DIRECT)=0) And (H3Bit<>0) Then Begin
     MbType:=(MbType Or M4_16X8 Or M4_INTERLACED) And Not M4_16X16;
     If (MbType And M4_L0)<>0 Then Begin M4FieldSel[0,0]:=H3Bit; M4FieldSel[0,
      1]:=H3Bit; End;
     If (MbType And M4_L1)<>0 Then Begin M4FieldSel[1,0]:=H3Bit; M4FieldSel[1,
      1]:=H3Bit; End;
    End;
   End;
   M4MvDir:=0;
   If (MbType And (M4_DIRECT Or M4_INTERLACED))=0 Then Begin
    M4MvType:=0;
    If (MbType And M4_L0)<>0 Then Begin
     M4MvDir:=1;
     Mx:=H3DecMotion(M4LastMv[0,0,0],M4FCode);
     My:=H3DecMotion(M4LastMv[0,0,1],M4FCode);
     M4LastMv[0,1,0]:=Mx; M4LastMv[0,0,0]:=Mx; M4Mv[0,0,0]:=Mx;
     M4LastMv[0,1,1]:=My; M4LastMv[0,0,1]:=My; M4Mv[0,0,1]:=My;
    End;
    If (MbType And M4_L1)<>0 Then Begin
     M4MvDir:=M4MvDir Or 2;
     Mx:=H3DecMotion(M4LastMv[1,0,0],M4BCode);
     My:=H3DecMotion(M4LastMv[1,0,1],M4BCode);
     M4LastMv[1,1,0]:=Mx; M4LastMv[1,0,0]:=Mx; M4Mv[1,0,0]:=Mx;
     M4LastMv[1,1,1]:=My; M4LastMv[1,0,1]:=My; M4Mv[1,0,1]:=My;
    End;
   End Else If (MbType And M4_DIRECT)=0 Then Begin
    M4MvType:=2;
    If (MbType And M4_L0)<>0 Then Begin
     M4MvDir:=1;
     For I:=0 To 1 Do Begin
      Mx:=H3DecMotion(M4LastMv[0,I,0],M4FCode);
      My:=H3DecMotion(M4LastMv[0,I,1] Div 2,M4FCode);
      M4LastMv[0,I,0]:=Mx; M4Mv[0,I,0]:=Mx;
      M4Mv[0,I,1]:=My; M4LastMv[0,I,1]:=My*2;
     End;
    End;
    If (MbType And M4_L1)<>0 Then Begin
     M4MvDir:=M4MvDir Or 2;
     For I:=0 To 1 Do Begin
      Mx:=H3DecMotion(M4LastMv[1,I,0],M4BCode);
      My:=H3DecMotion(M4LastMv[1,I,1] Div 2,M4BCode);
      M4LastMv[1,I,0]:=Mx; M4Mv[1,I,0]:=Mx;
      M4Mv[1,I,1]:=My; M4LastMv[1,I,1]:=My*2;
     End;
    End;
   End;
  End;
  If (MbType And M4_DIRECT)<>0 Then Begin
   If (MbType And M4_SKIP)<>0 Then Begin Mx:=0; My:=0; End
   Else Begin Mx:=H3DecMotion(0,1); My:=H3DecMotion(0,1); End;
   M4MvDir:=7;
   MbType:=MbType Or M4SetDirectMv(Mx,My);
  End;
  Mt^[Xy]:=MbType;
 End Else Begin
  Repeat
   Cbpc:=H3GetVlc(H3VIntra);
   If Cbpc<0 Then Exit;
  Until Cbpc<>8;
  Dquant:=Cbpc And 4;
  M4MbIntra:=1;
  IsIntra:=True;
 End;
 If IsIntra Then Begin
  M4AcPred:=H3Bit;
  If M4AcPred<>0 Then Mt^[Xy]:=M4_INTRA Or M4_ACPRED Else Mt^[Xy]:=M4_INTRA;
  Cbpy:=H3GetVlc(H3VCbpy);
  If Cbpy<0 Then Exit;
  Cbp:=(Cbpc And 3) Or (Cbpy Shl 2);
  If M4Qscale<M4IntraDcThr Then UseDc:=1 Else UseDc:=0;
  If Dquant<>0 Then M4SetQscale(M4Qscale+M4QuantTab[H3Bits(2)]);
  If M4Prog=0 Then M4IDct:=H3Bit;
  For I:=0 To 5 Do Begin
   If M4Block(I,Cbp And 32,1,UseDc,0)<0 Then Exit;
   Cbp:=Cbp+Cbp;
  End;
  Goto Fin;
 End;
 For I:=0 To 5 Do Begin
  If M4Block(I,Cbp And 32,0,0,0)<0 Then Exit;
  Cbp:=Cbp+Cbp;
 End;
Fin:
 Next:=M4IsResync;
 If Next<>0 Then Begin
  If M4MbX+M4MbY*M4MbW+1>=Next Then Begin M4DecodeMb:=M4_SLICE_END; Exit; End;
  If M4PType=2 Then Begin
   If M4MbX+1=M4MbW Then Delta:=2 Else Delta:=1;
   If M4P[M4NextI].Sk^[Xy+Delta]<>0 Then Begin M4DecodeMb:=M4_SLICE_OK; Exit;
    End;
  End;
  M4DecodeMb:=M4_SLICE_END; Exit;
 End;
 M4DecodeMb:=M4_SLICE_OK;
End;

{ ---- partitions de donnees (mpeg4_decode_partition_a/b, partitioned_mb) ---- }
Function M4PartitionA: LongInt;
Var
 MbCount,Cbpc,I,Dir,Dc,Bits,Px,Py,Mx,My,M,Xy: LongInt; Mt: PM4L32; Done:
  Boolean;
Begin
 MbCount:=0;
 Mt:=M4P[M4CurI].Mt;
 M4FirstLine:=1;
 While M4MbY<M4MbH Do Begin
  While M4MbX<M4MbW Do Begin
   Xy:=M4TypeIndex;
   Inc(MbCount);
   If (M4MbX=M4ResyncX) And (M4MbY=M4ResyncY+1) Then M4FirstLine:=0;
   If M4PType=0 Then Begin
    Repeat
     If H3Show(19)=$6B001 Then Begin M4PartitionA:=MbCount-1; Exit; End;
     Cbpc:=H3GetVlc(H3VIntra);
     If Cbpc<0 Then Begin M4PartitionA:=-1; Exit; End;
    Until Cbpc<>8;
    M4CbpTab^[Xy]:=Cbpc And 3;
    Mt^[Xy]:=M4_INTRA;
    M4MbIntra:=1;
    If (Cbpc And 4)<>0 Then M4SetQscale(M4Qscale+M4QuantTab[H3Bits(2)]);
    M4P[M4CurI].Qs^[Xy]:=M4Qscale;
    M4IntraTab^[Xy]:=1;
    Dir:=0;
    For I:=0 To 5 Do Begin
     Dc:=M4DecodeDc(I,M);
     If Dc<0 Then Begin M4PartitionA:=-1; Exit; End;
     Dir:=Dir Shl 1;
     If M<>0 Then Dir:=Dir Or 1;
    End;
    M4DirTab^[Xy]:=Dir;
   End Else Begin
    Done:=False;
    Repeat
     Bits:=H3Show(17);
     If Bits=$1F001 Then Begin M4PartitionA:=MbCount-1; Exit; End;
     H3Skip(1);
     If (Bits And $10000)<>0 Then Begin
      If (M4PType=3) And (M4SprUsage=2) Then Begin
       Mt^[Xy]:=M4_SKIP Or M4_16X16 Or M4_GMC Or M4_L0;
       Mx:=M4GetAmv(0); My:=M4GetAmv(1);
      End Else Begin
       Mt^[Xy]:=M4_SKIP Or M4_16X16 Or M4_L0;
       Mx:=0; My:=0;
      End;
      M4FillMv4(Mx,My);
      If M4IntraTab^[Xy]<>0 Then M4CleanIntraEntries;
      Done:=True; Cbpc:=-2;
     End Else Begin
      Cbpc:=H3GetVlc(H3VInter);
      If Cbpc<0 Then Begin M4PartitionA:=-1; Exit; End;
     End;
    Until Done Or (Cbpc<>20);
    If Not Done Then Begin
     M4CbpTab^[Xy]:=Cbpc And (8+3);
     M4MbIntra:=Ord((Cbpc And 4)<>0);
     If M4MbIntra<>0 Then Begin
      Mt^[Xy]:=M4_INTRA;
      M4IntraTab^[Xy]:=1;
      M4FillMv4(0,0);
     End Else Begin
      If M4IntraTab^[Xy]<>0 Then M4CleanIntraEntries;
      If (M4PType=3) And (M4SprUsage=2) And ((Cbpc And 16)=0) Then M4McSel:=
       H3Bit Else M4McSel:=0;
      If (Cbpc And 16)=0 Then Begin
       M4PredMotion(0,Px,Py);
       If M4McSel=0 Then Begin
        Mx:=H3DecMotion(Px,M4FCode);
        If Mx>=$FFFF Then Begin M4PartitionA:=-1; Exit; End;
        My:=H3DecMotion(Py,M4FCode);
        If My>=$FFFF Then Begin M4PartitionA:=-1; Exit; End;
        Mt^[Xy]:=M4_16X16 Or M4_L0;
       End Else Begin
        Mx:=M4GetAmv(0); My:=M4GetAmv(1);
        Mt^[Xy]:=M4_16X16 Or M4_GMC Or M4_L0;
       End;
       M4FillMv4(Mx,My);
      End Else Begin
       Mt^[Xy]:=M4_8X8 Or M4_L0;
       For I:=0 To 3 Do Begin
        M:=M4PredMotion(I,Px,Py);
        Mx:=H3DecMotion(Px,M4FCode);
        If Mx>=$FFFF Then Begin M4PartitionA:=-1; Exit; End;
        My:=H3DecMotion(Py,M4FCode);
        If My>=$FFFF Then Begin M4PartitionA:=-1; Exit; End;
        M4MvSet(M4CurI,M,0,Mx); M4MvSet(M4CurI,M,1,My);
       End;
      End;
     End;
    End;
   End;
   Inc(M4MbX);
  End;
  M4MbX:=0;
  Inc(M4MbY);
 End;
 M4PartitionA:=MbCount;
End;

Function M4PartitionB(MbCount: LongInt): LongInt;
Var MbNum,Xy,AcPred,Cbpy,I,Dir,Dc,M: LongInt; Mt: PM4L32;
Begin
 M4PartitionB:=-1;
 MbNum:=0;
 Mt:=M4P[M4CurI].Mt;
 M4MbX:=M4ResyncX;
 M4FirstLine:=1;
 M4MbY:=M4ResyncY;
 While MbNum<MbCount Do Begin
  While (MbNum<MbCount) And (M4MbX<M4MbW) Do Begin
   Xy:=M4TypeIndex;
   Inc(MbNum);
   If (M4MbX=M4ResyncX) And (M4MbY=M4ResyncY+1) Then M4FirstLine:=0;
   If M4PType=0 Then Begin
    AcPred:=H3Bit;
    Cbpy:=H3GetVlc(H3VCbpy);
    If Cbpy<0 Then Exit;
    M4CbpTab^[Xy]:=M4CbpTab^[Xy] Or (Cbpy Shl 2);
    If AcPred<>0 Then Mt^[Xy]:=Mt^[Xy] Or M4_ACPRED;
   End Else Begin
    If (Mt^[Xy] And M4_INTRA)<>0 Then Begin
     Dir:=0;
     AcPred:=H3Bit;
     Cbpy:=H3GetVlc(H3VCbpy);
     If Cbpy<0 Then Exit;
     If (M4CbpTab^[Xy] And 8)<>0 Then M4SetQscale(M4Qscale+M4QuantTab[H3Bits(
      2)]);
     M4P[M4CurI].Qs^[Xy]:=M4Qscale;
     M4MbIntra:=1;
     For I:=0 To 5 Do Begin
      Dc:=M4DecodeDc(I,M);
      If Dc<0 Then Exit;
      Dir:=Dir Shl 1;
      If M<>0 Then Dir:=Dir Or 1;
     End;
     M4CbpTab^[Xy]:=M4CbpTab^[Xy] And 3;
     M4CbpTab^[Xy]:=M4CbpTab^[Xy] Or (Cbpy Shl 2);
     If AcPred<>0 Then Mt^[Xy]:=Mt^[Xy] Or M4_ACPRED;
     M4DirTab^[Xy]:=Dir;
    End Else If (Mt^[Xy] And M4_SKIP)<>0 Then Begin
     M4P[M4CurI].Qs^[Xy]:=M4Qscale;
     M4CbpTab^[Xy]:=0;
    End Else Begin
     Cbpy:=H3GetVlc(H3VCbpy);
     If Cbpy<0 Then Exit;
     If (M4CbpTab^[Xy] And 8)<>0 Then M4SetQscale(M4Qscale+M4QuantTab[H3Bits(
      2)]);
     M4P[M4CurI].Qs^[Xy]:=M4Qscale;
     M4CbpTab^[Xy]:=M4CbpTab^[Xy] And 3;
     M4CbpTab^[Xy]:=M4CbpTab^[Xy] Or ((Cbpy Xor $F) Shl 2);
    End;
   End;
   Inc(M4MbX);
  End;
  If MbNum>=MbCount Then Begin M4PartitionB:=0; Exit; End;
  M4MbX:=0;
  Inc(M4MbY);
 End;
 M4PartitionB:=0;
End;

Function M4Partitions: LongInt;
Var MbNum,Ret: LongInt;
Begin
 M4Partitions:=-1;
 MbNum:=M4PartitionA;
 If MbNum<=0 Then Exit;
 If M4ResyncX+M4ResyncY*M4MbW+MbNum>M4MbNum Then Exit;
 M4MbLeft:=MbNum;
 If M4PType=0 Then Begin
  While H3Show(9)=1 Do H3Skip(9);
  If H3Bits(19)<>$6B001 Then Exit;
 End Else Begin
  While H3Show(10)=1 Do H3Skip(10);
  If H3Bits(17)<>$1F001 Then Exit;
 End;
 Ret:=M4PartitionB(MbNum);
 If Ret<0 Then Exit;
 M4Partitions:=0;
End;

Function M4PartitionedMb: LongInt;
Var Cbp,MbType,UseDc,I,Xy,Delta: LongInt; Mt: PM4L32;
Begin
 M4PartitionedMb:=M4_SLICE_ERR;
 Mt:=M4P[M4CurI].Mt;
 Xy:=M4TypeIndex;
 MbType:=Mt^[Xy];
 Cbp:=M4CbpTab^[Xy];
 If M4Qscale<M4IntraDcThr Then UseDc:=1 Else UseDc:=0;
 If M4P[M4CurI].Qs^[Xy]<>M4Qscale Then M4SetQscale(M4P[M4CurI].Qs^[Xy]);
 M4ClearBlocks;
 If (M4PType=1) Or (M4PType=3) Then Begin
  For I:=0 To 3 Do Begin
   M4Mv[0,I,0]:=M4MvGet(M4CurI,M4B8S*(2*M4MbY+(I Shr 1))+2*M4MbX+(I And 1),0);
   M4Mv[0,I,1]:=M4MvGet(M4CurI,M4B8S*(2*M4MbY+(I Shr 1))+2*M4MbX+(I And 1),1);
  End;
  M4MbIntra:=Ord((MbType And M4_INTRA)<>0);
  If (MbType And M4_SKIP)<>0 Then Begin
   For I:=0 To 5 Do M4BlkLast[I]:=-1;
   M4MvDir:=1; M4MvType:=0;
   If (M4PType=3) And (M4SprUsage=2) Then Begin M4McSel:=1; M4Skip:=0; End
   Else Begin M4McSel:=0; M4Skip:=1; End;
  End Else If M4MbIntra<>0 Then Begin
   M4AcPred:=Ord((MbType And M4_ACPRED)<>0);
  End Else Begin
   M4MvDir:=1;
   If (MbType And M4_8X8)<>0 Then M4MvType:=1 Else M4MvType:=0;
  End;
 End Else Begin
  M4MbIntra:=1;
  M4AcPred:=Ord((MbType And M4_ACPRED)<>0);
 End;
 If (MbType And M4_SKIP)=0 Then Begin
  For I:=0 To 5 Do Begin
   If M4Block(I,Cbp And 32,M4MbIntra,UseDc,M4Rvlc)<0 Then Exit;
   Cbp:=Cbp+Cbp;
  End;
 End;
 Dec(M4MbLeft);
 If M4MbLeft<=0 Then Begin
  If M4IsResync<>0 Then M4PartitionedMb:=M4_SLICE_END Else M4PartitionedMb:=
   M4_SLICE_NOEND;
 End Else Begin
  M4PartitionedMb:=M4_SLICE_OK;
  If M4IsResync<>0 Then Begin
   If M4MbX+1=M4MbW Then Delta:=2 Else Delta:=1;
   If M4CbpTab^[Xy+Delta]<>0 Then M4PartitionedMb:=M4_SLICE_END;
  End;
 End;
End;

{ ---- compensation de mouvement (mpegvideo_motion.c, hpeldsp, qpeldsp,
 mpegvideodsp) ---- }
Type TM4Q=Array[0..24*24-1] Of LongInt;
Var
 M4Win: Array[0..24*24-1] Of Byte;
 QF,QH,QH2,QV,QHV: TM4Q;

Procedure M4Fetch(Pl: PEABuffer; PStr: LongInt; X0,RowBase,RowStep,NW,NH,EW,EH:
 LongInt);
Var I,J,X,Y: LongInt;
Begin
 For J:=0 To NH-1 Do Begin
  Y:=RowBase+J*RowStep;
  If Y<0 Then Y:=0 Else If Y>=EH Then Y:=EH-1;
  For I:=0 To NW-1 Do Begin
   X:=X0+I;
   If X<0 Then X:=0 Else If X>=EW Then X:=EW-1;
   M4Win[J*24+I]:=Pl^[Y*PStr+X];
  End;
 End;
End;

Procedure M4Hpel(Dst: PEABuffer; DOff,DStr,Dxy,W,H: LongInt; NoRnd,Avg:
 Boolean);
Var X,Y,A,B,C,D,V,P: LongInt;
Begin
 For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
  P:=Y*24+X;
  A:=M4Win[P];
  Case Dxy Of
   0: V:=A;
   1: Begin B:=M4Win[P+1]; If NoRnd Then V:=(A+B) Shr 1 Else V:=(A+B+1) Shr 1;
    End;
   2: Begin C:=M4Win[P+24]; If NoRnd Then V:=(A+C) Shr 1 Else V:=(A+C+1) Shr 1;
    End;
   Else Begin
    B:=M4Win[P+1]; C:=M4Win[P+24]; D:=M4Win[P+25];
    If NoRnd Then V:=(A+B+C+D+1) Shr 2 Else V:=(A+B+C+D+2) Shr 2;
   End;
  End;
  If Avg Then V:=(Dst^[DOff+Y*DStr+X]+V+1) Shr 1;
  Dst^[DOff+Y*DStr+X]:=V;
 End;
End;

Function M4Qcm(B,Rc: LongInt): LongInt;
Var V: LongInt;
Begin
 V:=M4Sar(B+Rc,5);
 If V<0 Then V:=0 Else If V>255 Then V:=255;
 M4Qcm:=V;
End;

Function M4Mir(J,W: LongInt): LongInt;
Begin
 If J<0 Then M4Mir:=-1-J Else If J>W Then M4Mir:=2*W+1-J Else M4Mir:=J;
End;

{ filtre passe-bas horizontal sur Rows lignes, W colonnes ; source de pas 24 }
Procedure M4HLow(Var Src,Dst: TM4Q; SOff,Rows,W,Rc: LongInt);
Var I,J,K: LongInt; S: Array[0..16] Of LongInt;
Begin
 For J:=0 To Rows-1 Do Begin
  For K:=0 To W Do S[K]:=Src[SOff+J*24+K];
  For I:=0 To W-1 Do
   Dst[J*24+I]:=M4Qcm((S[I]+S[I+1])*20-(S[M4Mir(I-1,W)]+S[M4Mir(I+2,W)])*6+(S[
    M4Mir(I-2,W)]+S[M4Mir(I+3,W)])*3-(S[M4Mir(I-3,W)]+S[M4Mir(I+4,W)]),Rc);
 End;
End;

Procedure M4VLow(Var Src,Dst: TM4Q; SOff,W,Rc: LongInt);
Var I,J,K: LongInt; S: Array[0..16] Of LongInt;
Begin
 For I:=0 To W-1 Do Begin
  For K:=0 To W Do S[K]:=Src[SOff+K*24+I];
  For J:=0 To W-1 Do
   Dst[J*24+I]:=M4Qcm((S[J]+S[J+1])*20-(S[M4Mir(J-1,W)]+S[M4Mir(J+2,W)])*6+(S[
    M4Mir(J-2,W)]+S[M4Mir(J+3,W)])*3-(S[M4Mir(J-3,W)]+S[M4Mir(J+4,W)]),Rc);
 End;
End;

{ Mode : 0 put, 1 put_no_rnd, 2 avg ; fenetre M4Win de (W+1)x(W+1) pixels }
Procedure M4Qpel(Dst: PEABuffer; DOff,DStr,Dxy,W,Mode: LongInt);
Var X,Y,I,J,Rc,Mx,My,V: LongInt;
Function L2(A,B: LongInt): LongInt;
Begin If Mode=1 Then L2:=(A+B) Shr 1 Else L2:=(A+B+1) Shr 1; End;
Function L2p(A,B: LongInt): LongInt;
Begin If Mode=1 Then L2p:=(A+B) Shr 1 Else L2p:=(A+B+1) Shr 1; End;
Procedure Outp(PX,PY,Vv: LongInt);
Begin
 If Mode=2 Then Vv:=(Dst^[DOff+PY*DStr+PX]+Vv+1) Shr 1;
 Dst^[DOff+PY*DStr+PX]:=Vv;
End;
Begin
 If Mode=1 Then Rc:=15 Else Rc:=16;
 Mx:=Dxy And 3; My:=Dxy Shr 2;
 For J:=0 To W Do For I:=0 To W Do QF[J*24+I]:=M4Win[J*24+I];
 Case My*4+Mx Of
  0: For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QF[Y*24+X]);
  1,3: Begin
   M4HLow(QF,QH,0,W,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,L2(QF[Y*24+X+(Mx Shr 1)],QH[Y*
    24+X]));
  End;
  2: Begin
   M4HLow(QF,QH,0,W,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QH[Y*24+X]);
  End;
  4,12: Begin
   M4VLow(QF,QV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,L2(QF[(Y+(My Shr 1))*24+X],QV[
    Y*24+X]));
  End;
  8: Begin
   M4VLow(QF,QV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QV[Y*24+X]);
  End;
  5,7,13,15: Begin
   M4HLow(QF,QH,0,W+1,W,Rc);
   For J:=0 To W Do For I:=0 To W-1 Do QH[J*24+I]:=L2p(QH[J*24+I],QF[J*24+I+(Mx
    Shr 1)]);
   M4VLow(QH,QHV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,L2(QH[(Y+(My Shr 1))*24+X],
    QHV[Y*24+X]));
  End;
  6,14: Begin
   M4HLow(QF,QH,0,W+1,W,Rc);
   M4VLow(QH,QHV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,L2(QH[(Y+(My Shr 1))*24+X],
    QHV[Y*24+X]));
  End;
  9,11: Begin
   M4HLow(QF,QH,0,W+1,W,Rc);
   For J:=0 To W Do For I:=0 To W-1 Do QH[J*24+I]:=L2p(QH[J*24+I],QF[J*24+I+(Mx
    Shr 1)]);
   M4VLow(QH,QHV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QHV[Y*24+X]);
  End;
  10: Begin
   M4HLow(QF,QH,0,W+1,W,Rc);
   M4VLow(QH,QHV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QHV[Y*24+X]);
  End;
 End;
End;

Procedure M4Gmc1(Dst: PEABuffer; DOff,DStr,H,X16,Y16,Rnd,WOff: LongInt);   {
 fenetre M4Win ; 8 colonnes }
Var A,B,C,D,X,Y,P: LongInt;
Begin
 A:=(16-X16)*(16-Y16); B:=X16*(16-Y16); C:=(16-X16)*Y16; D:=X16*Y16;
 For Y:=0 To H-1 Do For X:=0 To 7 Do Begin
  P:=Y*24+X+WOff;
  Dst^[DOff+Y*DStr+X]:=(A*M4Win[P]+B*M4Win[P+1]+C*M4Win[P+24]+D*M4Win[P+25]+Rnd)
   Shr 8;
 End;
End;

Procedure M4GmcPlane(Pl: PEABuffer; PStr: LongInt; Dst: PEABuffer; DOff,DStr,H:
 LongInt; Ox,Oy,Dxx,Dxy,Dyx,Dyy,Shift,R,Width,Height: LongInt);
Var Y,X,Vx,Vy,SrcX,SrcY,FracX,FracY,Index,S: LongInt;
Function Clip(V,Lo,Hi: LongInt): LongInt;
Begin If V<Lo Then V:=Lo Else If V>Hi Then V:=Hi; Clip:=V; End;
Begin
 S:=LongInt(1) Shl Shift;
 Dec(Width); Dec(Height);
 For Y:=0 To H-1 Do Begin
  Vx:=Ox; Vy:=Oy;
  For X:=0 To 7 Do Begin
   SrcX:=M4Sar(Vx,16); SrcY:=M4Sar(Vy,16);
   FracX:=SrcX And (S-1); FracY:=SrcY And (S-1);
   SrcX:=M4Sar(SrcX,Shift); SrcY:=M4Sar(SrcY,Shift);
   If (SrcX>=0) And (SrcX<Width) Then Begin
    If (SrcY>=0) And (SrcY<Height) Then Begin
     Index:=SrcX+SrcY*PStr;
     Dst^[DOff+Y*DStr+X]:=((Pl^[Index]*(S-FracX)+Pl^[Index+1]*FracX)*(S-FracY)+(
      Pl^[Index+PStr]*(S-FracX)+Pl^[Index+PStr+1]*FracX)*FracY+R) Shr (Shift*2);
    End Else Begin
     Index:=SrcX+Clip(SrcY,0,Height)*PStr;
     Dst^[DOff+Y*DStr+X]:=((Pl^[Index]*(S-FracX)+Pl^[Index+1]*FracX)*S+R) Shr (
      Shift*2);
    End;
   End Else Begin
    If (SrcY>=0) And (SrcY<Height) Then Begin
     Index:=Clip(SrcX,0,Width)+SrcY*PStr;
     Dst^[DOff+Y*DStr+X]:=((Pl^[Index]*(S-FracY)+Pl^[Index+PStr]*FracY)*S+R) Shr
      (Shift*2);
    End Else Begin
     Index:=Clip(SrcX,0,Width)+Clip(SrcY,0,Height)*PStr;
     Dst^[DOff+Y*DStr+X]:=Pl^[Index];
    End;
   End;
   Vx:=Vx+Dxx; Vy:=Vy+Dyx;
  End;
  Ox:=Ox+Dxy; Oy:=Oy+Dyy;
 End;
End;

Procedure M4McselMotion(Ref,DY,DC: LongInt);
Var Pc: ^TM4Pic; Mx,My,SrcX,SrcY,A,Ox,Oy,Dxy: LongInt; Cur: ^TM4Pic;
Begin
 Pc:=@M4P[Ref]; Cur:=@M4P[M4CurI];
 A:=M4WarpAcc;
 If M4RealWarp=1 Then Begin
  Mx:=LongInt(M4SpOff[0,0]); My:=LongInt(M4SpOff[0,1]);
  SrcX:=M4MbX*16+M4Sar(Mx,A+1); SrcY:=M4MbY*16+M4Sar(My,A+1);
  Mx:=Mx*(LongInt(1) Shl (3-A)); My:=My*(LongInt(1) Shl (3-A));
  If SrcX<-16 Then SrcX:=-16 Else If SrcX>M4W Then SrcX:=M4W;
  If SrcX=M4W Then Mx:=0;
  If SrcY<-16 Then SrcY:=-16 Else If SrcY>M4H Then SrcY:=M4H;
  If SrcY=M4H Then My:=0;
  M4Fetch(Pc^.Y,M4LY,SrcX,SrcY,1,17,17,M4HEdge,M4VEdge);
  If ((Mx Or My) And 7)<>0 Then Begin
   M4Gmc1(Cur^.Y,DY,M4LY,16,Mx And 15,My And 15,128-M4NoRnd,0);
   M4Gmc1(Cur^.Y,DY+8,M4LY,16,Mx And 15,My And 15,128-M4NoRnd,8);
  End Else Begin
   Dxy:=((M4Sar(Mx,3)) And 1) Or ((M4Sar(My,2)) And 2);
   M4Hpel(Cur^.Y,DY,M4LY,Dxy,16,16,M4NoRnd<>0,False);
  End;
  Mx:=LongInt(M4SpOff[1,0]); My:=LongInt(M4SpOff[1,1]);
  SrcX:=M4MbX*8+M4Sar(Mx,A+1); SrcY:=M4MbY*8+M4Sar(My,A+1);
  Mx:=Mx*(LongInt(1) Shl (3-A)); My:=My*(LongInt(1) Shl (3-A));
  If SrcX<-8 Then SrcX:=-8 Else If SrcX>(M4W Shr 1) Then SrcX:=M4W Shr 1;
  If SrcX=(M4W Shr 1) Then Mx:=0;
  If SrcY<-8 Then SrcY:=-8 Else If SrcY>(M4H Shr 1) Then SrcY:=M4H Shr 1;
  If SrcY=(M4H Shr 1) Then My:=0;
  M4Fetch(Pc^.U,M4LC,SrcX,SrcY,1,9,9,M4HEdge Shr 1,M4VEdge Shr 1);
  M4Gmc1(Cur^.U,DC,M4LC,8,Mx And 15,My And 15,128-M4NoRnd,0);
  M4Fetch(Pc^.V,M4LC,SrcX,SrcY,1,9,9,M4HEdge Shr 1,M4VEdge Shr 1);
  M4Gmc1(Cur^.V,DC,M4LC,8,Mx And 15,My And 15,128-M4NoRnd,0);
 End Else Begin
  Ox:=LongInt(M4SpOff[0,0])+LongInt(M4SpDelta[0,0])*M4MbX*16+LongInt(M4SpDelta[
   0,1])*M4MbY*16;
  Oy:=LongInt(M4SpOff[0,1])+LongInt(M4SpDelta[1,0])*M4MbX*16+LongInt(M4SpDelta[
   1,1])*M4MbY*16;
  M4GmcPlane(Pc^.Y,M4LY,Cur^.Y,DY,M4LY,16,Ox,Oy,LongInt(M4SpDelta[0,0]),LongInt(
   M4SpDelta[0,1]),LongInt(M4SpDelta[1,0]),LongInt(M4SpDelta[1,1]),A+1,(LongInt(
   1) Shl (2*A+1))-M4NoRnd,M4HEdge,M4VEdge);
  M4GmcPlane(Pc^.Y,M4LY,Cur^.Y,DY+8,M4LY,16,Ox+LongInt(M4SpDelta[0,0])*8,Oy+
   LongInt(M4SpDelta[1,0])*8,LongInt(M4SpDelta[0,0]),LongInt(M4SpDelta[0,1]),
   LongInt(M4SpDelta[1,0]),LongInt(M4SpDelta[1,1]),A+1,(LongInt(1) Shl (2*A+1))-
   M4NoRnd,M4HEdge,M4VEdge);
  Ox:=LongInt(M4SpOff[1,0])+LongInt(M4SpDelta[0,0])*M4MbX*8+LongInt(M4SpDelta[0,
   1])*M4MbY*8;
  Oy:=LongInt(M4SpOff[1,1])+LongInt(M4SpDelta[1,0])*M4MbX*8+LongInt(M4SpDelta[1,
   1])*M4MbY*8;
  M4GmcPlane(Pc^.U,M4LC,Cur^.U,DC,M4LC,8,Ox,Oy,LongInt(M4SpDelta[0,0]),LongInt(
   M4SpDelta[0,1]),LongInt(M4SpDelta[1,0]),LongInt(M4SpDelta[1,1]),A+1,(LongInt(
   1) Shl (2*A+1))-M4NoRnd,(M4HEdge+1) Shr 1,(M4VEdge+1) Shr 1);
  M4GmcPlane(Pc^.V,M4LC,Cur^.V,DC,M4LC,8,Ox,Oy,LongInt(M4SpDelta[0,0]),LongInt(
   M4SpDelta[0,1]),LongInt(M4SpDelta[1,0]),LongInt(M4SpDelta[1,1]),A+1,(LongInt(
   1) Shl (2*A+1))-M4NoRnd,(M4HEdge+1) Shr 1,(M4VEdge+1) Shr 1);
 End;
End;

{ mpeg_motion_internal (sortie H.263) : un vecteur demi-pel sur les trois
 composantes }
Procedure M4MpegMotion(Ref,DOffY,DOffC,FB,Bottom,FSel,Mx,My,H: LongInt; NoRnd,
 Avg: Boolean);
Var
 Dxy,UvDxy,SrcX,SrcY,UvX,UvY,Mx2,My2,YStrD,CStrD,RowY,RowC,StepR,I: LongInt; Pc,
  Cur: ^TM4Pic;
Begin
 Pc:=@M4P[Ref]; Cur:=@M4P[M4CurI];
 Dxy:=((My And 1) Shl 1) Or (Mx And 1);
 SrcX:=M4MbX*16+M4Sar(Mx,1);
 SrcY:=(M4MbY Shl (4-FB))+M4Sar(My,1);
 If ((M4Bugs And M4_BUG_HPELCH)<>0) And (FB<>0) Then Begin
  Mx2:=M4Sar(Mx,1) Or (Mx And 1); My2:=M4Sar(My,1);
  UvDxy:=((My2 And 1) Shl 1) Or (Mx2 And 1);
  UvX:=M4MbX*8+M4Sar(Mx2,1);
  UvY:=(M4MbY Shl (3-FB))+M4Sar(My2,1);
 End Else Begin
  UvDxy:=Dxy Or (My And 2) Or ((Mx And 2) Shr 1);
  UvX:=M4Sar(SrcX,1); UvY:=M4Sar(SrcY,1);
 End;
 YStrD:=M4LY Shl FB; CStrD:=M4LC Shl FB;
 If FB<>0 Then Begin
  RowY:=2*SrcY+FSel; RowC:=2*UvY+FSel; StepR:=2;
 End Else Begin
  RowY:=SrcY; RowC:=UvY; StepR:=1;
 End;
 If Bottom<>0 Then Begin Inc(DOffY,M4LY); Inc(DOffC,M4LC); End;
 M4Fetch(Pc^.Y,M4LY,SrcX,RowY,StepR,17,H+1,M4HEdge,M4VEdge);
 M4Hpel(Cur^.Y,DOffY,YStrD,Dxy,16,H,NoRnd,Avg);
 M4Fetch(Pc^.U,M4LC,UvX,RowC,StepR,9,(H Shr 1)+1,M4HEdge Shr 1,M4VEdge Shr 1);
 M4Hpel(Cur^.U,DOffC,CStrD,UvDxy,8,H Shr 1,NoRnd,Avg);
 M4Fetch(Pc^.V,M4LC,UvX,RowC,StepR,9,(H Shr 1)+1,M4HEdge Shr 1,M4VEdge Shr 1);
 M4Hpel(Cur^.V,DOffC,CStrD,UvDxy,8,H Shr 1,NoRnd,Avg);
End;

{ qpel_motion }
Procedure M4QpelMotion(Ref,DOffY,DOffC,FB,Bottom,FSel,Mx,My,H: LongInt; NoRnd,
 Avg: Boolean);
Var
 Dxy,UvDxy,SrcX,SrcY,UvX,UvY,Cx,Cy,RowY,RowC,StepR,YStrD,CStrD,Mode: LongInt;
  Pc,Cur: ^TM4Pic;
Const RTab: Array[0..7] Of ShortInt=(0,0,1,1,0,0,0,1);
Begin
 Pc:=@M4P[Ref]; Cur:=@M4P[M4CurI];
 If Avg Then Mode:=2 Else If NoRnd Then Mode:=1 Else Mode:=0;
 Dxy:=((My And 3) Shl 2) Or (Mx And 3);
 SrcX:=M4MbX*16+M4Sar(Mx,2);
 SrcY:=M4MbY*(16 Shr FB)+M4Sar(My,2);
 YStrD:=M4LY Shl FB; CStrD:=M4LC Shl FB;
 If FB<>0 Then Begin
  Cx:=Mx Div 2; Cy:=M4Sar(My,1);
 End Else If (M4Bugs And M4_BUG_QPELCH2)<>0 Then Begin
  Cx:=M4Sar(Mx,1)+RTab[Mx And 7]; Cy:=M4Sar(My,1)+RTab[My And 7];
 End Else If (M4Bugs And M4_BUG_QPELCH)<>0 Then Begin
  Cx:=M4Sar(Mx,1) Or (Mx And 1); Cy:=M4Sar(My,1) Or (My And 1);
 End Else Begin
  Cx:=Mx Div 2; Cy:=My Div 2;
 End;
 Cx:=M4Sar(Cx,1) Or (Cx And 1); Cy:=M4Sar(Cy,1) Or (Cy And 1);
 UvDxy:=(Cx And 1) Or ((Cy And 1) Shl 1);
 Cx:=M4Sar(Cx,1); Cy:=M4Sar(Cy,1);
 UvX:=M4MbX*8+Cx;
 UvY:=M4MbY*(8 Shr FB)+Cy;
 If FB<>0 Then Begin RowY:=2*SrcY+FSel; RowC:=2*UvY+FSel; StepR:=2; End
 Else Begin RowY:=SrcY; RowC:=UvY; StepR:=1; End;
 If FB=0 Then Begin
  M4Fetch(Pc^.Y,M4LY,SrcX,RowY,StepR,17,17,M4HEdge,M4VEdge);
  M4Qpel(Cur^.Y,DOffY,YStrD,Dxy,16,Mode);
 End Else Begin
  If Bottom<>0 Then Begin Inc(DOffY,M4LY); Inc(DOffC,M4LC); End;
  M4Fetch(Pc^.Y,M4LY,SrcX,RowY,StepR,17,9,M4HEdge,M4VEdge);
  M4Qpel(Cur^.Y,DOffY,YStrD,Dxy,8,Mode);
  { second bloc 8x8 : fenetre decalee de 8 colonnes }
  M4Fetch(Pc^.Y,M4LY,SrcX+8,RowY,StepR,9,9,M4HEdge,M4VEdge);
  M4Qpel(Cur^.Y,DOffY+8,YStrD,Dxy,8,Mode);
 End;
 M4Fetch(Pc^.U,M4LC,UvX,RowC,StepR,9,(H Shr 1)+1,M4HEdge Shr 1,M4VEdge Shr 1);
 M4Hpel(Cur^.U,DOffC,CStrD,UvDxy,8,H Shr 1,NoRnd,Avg);
 M4Fetch(Pc^.V,M4LC,UvX,RowC,StepR,9,(H Shr 1)+1,M4HEdge Shr 1,M4VEdge Shr 1);
 M4Hpel(Cur^.V,DOffC,CStrD,UvDxy,8,H Shr 1,NoRnd,Avg);
End;

Function M4RoundChroma(X: LongInt): LongInt;
Begin M4RoundChroma:=H3RoundTab[X And 15]+M4Sar(X,3); End;

{ apply_8x8 + chroma_4mv_motion }
Procedure M4Apply8x8(Dir,Ref,DOffY,DOffC: LongInt; NoRnd,Avg: Boolean);
Var
 I,Mx,My,Mvx,Mvy,Dxy,SrcX,SrcY,Mode,Off: LongInt; Pc,Cur: ^TM4Pic;
Begin
 Pc:=@M4P[Ref]; Cur:=@M4P[M4CurI];
 If Avg Then Mode:=2 Else If NoRnd Then Mode:=1 Else Mode:=0;
 Mx:=0; My:=0;
 For I:=0 To 3 Do Begin
  Mvx:=M4Mv[Dir,I,0]; Mvy:=M4Mv[Dir,I,1];
  Off:=DOffY+(I And 1)*8+(I Shr 1)*8*M4LY;
  If M4QuarterS<>0 Then Begin
   Dxy:=((Mvy And 3) Shl 2) Or (Mvx And 3);
   SrcX:=M4MbX*16+M4Sar(Mvx,2)+(I And 1)*8;
   SrcY:=M4MbY*16+M4Sar(Mvy,2)+(I Shr 1)*8;
   If SrcX<-16 Then SrcX:=-16 Else If SrcX>M4W Then SrcX:=M4W;
   If SrcX=M4W Then Dxy:=Dxy And Not 3;
   If SrcY<-16 Then SrcY:=-16 Else If SrcY>M4H Then SrcY:=M4H;
   If SrcY=M4H Then Dxy:=Dxy And Not 12;
   M4Fetch(Pc^.Y,M4LY,SrcX,SrcY,1,9,9,M4HEdge,M4VEdge);
   M4Qpel(Cur^.Y,Off,M4LY,Dxy,8,Mode);
   Mx:=Mx+Mvx Div 2; My:=My+Mvy Div 2;
  End Else Begin
   SrcX:=M4MbX*16+(I And 1)*8+M4Sar(Mvx,1);
   SrcY:=M4MbY*16+(I Shr 1)*8+M4Sar(Mvy,1);
   Dxy:=0;
   If SrcX<-16 Then SrcX:=-16 Else If SrcX>M4W Then SrcX:=M4W;
   If SrcX<>M4W Then Dxy:=Dxy Or (Mvx And 1);
   If SrcY<-16 Then SrcY:=-16 Else If SrcY>M4H Then SrcY:=M4H;
   If SrcY<>M4H Then Dxy:=Dxy Or ((Mvy And 1) Shl 1);
   M4Fetch(Pc^.Y,M4LY,SrcX,SrcY,1,9,9,M4HEdge,M4VEdge);
   M4Hpel(Cur^.Y,Off,M4LY,Dxy,8,8,NoRnd,Avg);
   Mx:=Mx+Mvx; My:=My+Mvy;
  End;
 End;
 { chroma_4mv_motion }
 Mx:=M4RoundChroma(Mx); My:=M4RoundChroma(My);
 Dxy:=((My And 1) Shl 1) Or (Mx And 1);
 Mx:=M4Sar(Mx,1); My:=M4Sar(My,1);
 SrcX:=M4MbX*8+Mx; SrcY:=M4MbY*8+My;
 If SrcX<-8 Then SrcX:=-8 Else If SrcX>(M4W Shr 1) Then SrcX:=M4W Shr 1;
 If SrcX=(M4W Shr 1) Then Dxy:=Dxy And Not 1;
 If SrcY<-8 Then SrcY:=-8 Else If SrcY>(M4H Shr 1) Then SrcY:=M4H Shr 1;
 If SrcY=(M4H Shr 1) Then Dxy:=Dxy And Not 2;
 M4Fetch(Pc^.U,M4LC,SrcX,SrcY,1,9,9,M4HEdge Shr 1,M4VEdge Shr 1);
 M4Hpel(Cur^.U,DOffC,M4LC,Dxy,8,8,NoRnd,Avg);
 M4Fetch(Pc^.V,M4LC,SrcX,SrcY,1,9,9,M4HEdge Shr 1,M4VEdge Shr 1);
 M4Hpel(Cur^.V,DOffC,M4LC,Dxy,8,8,NoRnd,Avg);
End;

{ ff_mpv_motion pour une direction }
Procedure M4Motion(Dir,Ref,DOffY,DOffC: LongInt; NoRnd,Avg: Boolean);
Var I: LongInt;
Begin
 Case M4MvType Of
  0: Begin
   If M4McSel<>0 Then M4McselMotion(Ref,DOffY,DOffC)
   Else If M4QuarterS<>0 Then M4QpelMotion(Ref,DOffY,DOffC,0,0,0,M4Mv[Dir,0,0],
    M4Mv[Dir,0,1],16,NoRnd,Avg)
   Else M4MpegMotion(Ref,DOffY,DOffC,0,0,0,M4Mv[Dir,0,0],M4Mv[Dir,0,1],16,NoRnd,
    Avg);
  End;
  1: M4Apply8x8(Dir,Ref,DOffY,DOffC,NoRnd,Avg);
  2: For I:=0 To 1 Do Begin
   If M4QuarterS<>0 Then M4QpelMotion(Ref,DOffY,DOffC,1,I,M4FieldSel[Dir,I],
    M4Mv[Dir,I,0],M4Mv[Dir,I,1],8,NoRnd,Avg)
   Else M4MpegMotion(Ref,DOffY,DOffC,1,I,M4FieldSel[Dir,I],M4Mv[Dir,I,0],M4Mv[
    Dir,I,1],8,NoRnd,Avg);
  End;
 End;
End;

{ ---- dequantification ---- }
Procedure M4DequantIntra(N: LongInt);
Var I,J,Level,Qmul,Qadd,NC,Q,Dcs: LongInt; Blk: ^TH3Blk; Scan: PEABuffer;
Begin
 Blk:=@M4Blk[N];
 If N<4 Then Dcs:=M4YDc Else Dcs:=M4CDc;
 If N<4 Then Q:=M4Qscale Else Q:=M4ChromaQ;
 If M4MpegQuant<>0 Then Begin
  Q:=Q Shl 1;
  If M4AltScan<>0 Then Scan:=@H3AltV Else Scan:=@H3Zigzag;
  If M4AltScan<>0 Then NC:=63 Else NC:=M4BlkLast[N];
  Blk^[0]:=SmallInt(Blk^[0]*Dcs);
  For I:=1 To NC Do Begin
   J:=Scan^[I];
   Level:=Blk^[J];
   If Level<>0 Then Begin
    If Level<0 Then Level:=-((-Level*Q*M4IntraM[J]) Shr 4) Else Level:=(Level*Q*
     M4IntraM[J]) Shr 4;
    Blk^[J]:=SmallInt(Level);
   End;
  End;
 End Else Begin
  Qmul:=Q Shl 1;
  Blk^[0]:=SmallInt(Blk^[0]*Dcs);
  Qadd:=(Q-1) Or 1;
  If M4AcPred<>0 Then NC:=63
  Else If M4AltScan<>0 Then NC:=H3AltVRE[M4BlkLast[N]] Else NC:=H3RasterEnd[
   M4BlkLast[N]];
  For I:=1 To NC Do Begin
   Level:=Blk^[I];
   If Level<>0 Then Begin
    If Level<0 Then Level:=Level*Qmul-Qadd Else Level:=Level*Qmul+Qadd;
    Blk^[I]:=SmallInt(Level);
   End;
  End;
 End;
End;

Procedure M4DequantInterMpeg(N: LongInt);
Var I,J,Level,NC,Q,Sum: LongInt; Blk: ^TH3Blk; Scan: PEABuffer;
Begin
 Blk:=@M4Blk[N];
 If N<4 Then Q:=M4Qscale Else Q:=M4ChromaQ;
 Q:=Q Shl 1;
 If M4AltScan<>0 Then Scan:=@H3AltV Else Scan:=@H3Zigzag;
 If M4AltScan<>0 Then NC:=63 Else NC:=M4BlkLast[N];
 Sum:=-1;
 For I:=0 To NC Do Begin
  J:=Scan^[I];
  Level:=Blk^[J];
  If Level<>0 Then Begin
   If Level<0 Then Level:=-((((-Level) Shl 1)+1)*Q*M4InterM[J] Shr 5) Else
    Level:=((Level Shl 1)+1)*Q*M4InterM[J] Shr 5;
   Blk^[J]:=SmallInt(Level);
   Sum:=Sum+Level;
  End;
 End;
 Blk^[63]:=SmallInt(Blk^[63] Xor (Sum And 1));
End;


{ ---- IDCT "xvid" (xvididct.c), utilisee quand le flux est identifie comme Xvid
 ---- }
Function M4W32(X: Int64): LongInt;
Begin M4W32:=LongInt(X And $FFFFFFFF); End;

Function M4XvRow(Var R: Array Of SmallInt; Base: LongInt; Const Tab: Array Of
 LongInt; Rnd: LongInt): Boolean;
Var C1,C2,C3,C4,C5,C6,C7,K,A0,A1,A2,A3,B0,B1,B2,B3: LongInt; Left,Right:
 LongInt;
Begin
 C1:=Tab[0]; C2:=Tab[1]; C3:=Tab[2]; C4:=Tab[3]; C5:=Tab[4]; C6:=Tab[5]; C7:=
  Tab[6];
 Right:=R[Base+5] Or R[Base+6] Or R[Base+7];
 Left:=R[Base+1] Or R[Base+2] Or R[Base+3];
 M4XvRow:=True;
 If (Right Or R[Base+4])=0 Then Begin
  K:=M4W32(Int64(C4)*R[Base]+Rnd);
  If Left<>0 Then Begin
   A0:=M4W32(Int64(K)+Int64(C2)*R[Base+2]); A1:=M4W32(Int64(K)+Int64(C6)*R[Base+
    2]);
   A2:=M4W32(Int64(K)-Int64(C6)*R[Base+2]); A3:=M4W32(Int64(K)-Int64(C2)*R[Base+
    2]);
   B0:=M4W32(Int64(C1)*R[Base+1]+Int64(C3)*R[Base+3]); B1:=M4W32(Int64(C3)*R[
    Base+1]-Int64(C7)*R[Base+3]);
   B2:=M4W32(Int64(C5)*R[Base+1]-Int64(C1)*R[Base+3]); B3:=M4W32(Int64(C7)*R[
    Base+1]-Int64(C5)*R[Base+3]);
   R[Base]:=SmallInt(M4Sar(M4W32(Int64(A0)+B0),11)); R[Base+1]:=SmallInt(M4Sar(
    M4W32(Int64(A1)+B1),11));
   R[Base+2]:=SmallInt(M4Sar(M4W32(Int64(A2)+B2),11)); R[Base+3]:=SmallInt(
    M4Sar(M4W32(Int64(A3)+B3),11));
   R[Base+4]:=SmallInt(M4Sar(M4W32(Int64(A3)-B3),11)); R[Base+5]:=SmallInt(
    M4Sar(M4W32(Int64(A2)-B2),11));
   R[Base+6]:=SmallInt(M4Sar(M4W32(Int64(A1)-B1),11)); R[Base+7]:=SmallInt(
    M4Sar(M4W32(Int64(A0)-B0),11));
  End Else Begin
   A0:=M4Sar(K,11);
   If A0<>0 Then Begin
    For K:=0 To 7 Do R[Base+K]:=SmallInt(A0);
   End Else M4XvRow:=False;
  End;
 End Else If (Left Or Right)=0 Then Begin
  A0:=M4Sar(M4W32(Int64(Rnd)+Int64(C4)*(R[Base]+R[Base+4])),11);
  A1:=M4Sar(M4W32(Int64(Rnd)+Int64(C4)*(R[Base]-R[Base+4])),11);
  R[Base]:=SmallInt(A0); R[Base+3]:=SmallInt(A0); R[Base+4]:=SmallInt(A0); R[
   Base+7]:=SmallInt(A0);
  R[Base+1]:=SmallInt(A1); R[Base+2]:=SmallInt(A1); R[Base+5]:=SmallInt(A1); R[
   Base+6]:=SmallInt(A1);
 End Else Begin
  K:=M4W32(Int64(C4)*R[Base]+Rnd);
  A0:=M4W32(Int64(K)+Int64(C2)*R[Base+2]+Int64(C4)*R[Base+4]+Int64(C6)*R[Base+
   6]);
  A1:=M4W32(Int64(K)+Int64(C6)*R[Base+2]-Int64(C4)*R[Base+4]-Int64(C2)*R[Base+
   6]);
  A2:=M4W32(Int64(K)-Int64(C6)*R[Base+2]-Int64(C4)*R[Base+4]+Int64(C2)*R[Base+
   6]);
  A3:=M4W32(Int64(K)-Int64(C2)*R[Base+2]+Int64(C4)*R[Base+4]-Int64(C6)*R[Base+
   6]);
  B0:=M4W32(Int64(C1)*R[Base+1]+Int64(C3)*R[Base+3]+Int64(C5)*R[Base+5]+Int64(
   C7)*R[Base+7]);
  B1:=M4W32(Int64(C3)*R[Base+1]-Int64(C7)*R[Base+3]-Int64(C1)*R[Base+5]-Int64(
   C5)*R[Base+7]);
  B2:=M4W32(Int64(C5)*R[Base+1]-Int64(C1)*R[Base+3]+Int64(C7)*R[Base+5]+Int64(
   C3)*R[Base+7]);
  B3:=M4W32(Int64(C7)*R[Base+1]-Int64(C5)*R[Base+3]+Int64(C3)*R[Base+5]-Int64(
   C1)*R[Base+7]);
  R[Base]:=SmallInt(M4Sar(M4W32(Int64(A0)+B0),11)); R[Base+1]:=SmallInt(M4Sar(
   M4W32(Int64(A1)+B1),11));
  R[Base+2]:=SmallInt(M4Sar(M4W32(Int64(A2)+B2),11)); R[Base+3]:=SmallInt(M4Sar(
   M4W32(Int64(A3)+B3),11));
  R[Base+4]:=SmallInt(M4Sar(M4W32(Int64(A3)-B3),11)); R[Base+5]:=SmallInt(M4Sar(
   M4W32(Int64(A2)-B2),11));
  R[Base+6]:=SmallInt(M4Sar(M4W32(Int64(A1)-B1),11)); R[Base+7]:=SmallInt(M4Sar(
   M4W32(Int64(A0)-B0),11));
 End;
End;

Function M4XvMult(C,X: LongInt; N: LongInt): LongInt;
Begin M4XvMult:=M4Sar(M4W32(Int64(C)*(X And $FFFFFFFF)),N); End;

Procedure M4XvCol(Var R: Array Of SmallInt; Base,Kind: LongInt);
Var Mm0,Mm1,Mm2,Mm3,Mm4,Mm5,Mm6,Mm7,Sp: LongInt;
Const TAN1=$32EC; TAN2=$6A0A; TAN3=$AB0E; SQRT2=$5A82;
Procedure Bf(Var A,B: LongInt; Var Tmp: LongInt);
Begin Tmp:=M4W32(Int64(A)+B); B:=M4W32(Int64(A)-B); A:=Tmp; End;
Begin
 Case Kind Of
  8: Begin
   Mm4:=R[Base+56]; Mm5:=R[Base+40]; Mm6:=R[Base+24]; Mm7:=R[Base+8];
   Mm0:=M4W32(Int64(M4XvMult(TAN1,Mm4,16))+Mm7);
   Mm1:=M4W32(Int64(M4XvMult(TAN1,Mm7,16))-Mm4);
   Mm2:=M4W32(Int64(M4XvMult(TAN3,Mm5,16))+Mm6);
   Mm3:=M4W32(Int64(M4XvMult(TAN3,Mm6,16))-Mm5);
   Mm7:=M4W32(Int64(Mm0)+Mm2); Mm4:=M4W32(Int64(Mm1)-Mm3); Mm0:=M4W32(Int64(
    Mm0)-Mm2); Mm1:=M4W32(Int64(Mm1)+Mm3);
   Mm6:=M4W32(Int64(Mm0)+Mm1); Mm5:=M4W32(Int64(Mm0)-Mm1);
   Mm5:=M4W32(2*Int64(M4XvMult(SQRT2,Mm5,16)));
   Mm6:=M4W32(2*Int64(M4XvMult(SQRT2,Mm6,16)));
   Mm1:=R[Base+16]; Mm2:=R[Base+48];
   Mm3:=M4W32(Int64(M4XvMult(TAN2,Mm2,16))+Mm1);
   Mm2:=M4W32(Int64(M4XvMult(TAN2,Mm1,16))-Mm2);
   Mm0:=R[Base]+R[Base+32]; Mm1:=R[Base]-R[Base+32];
  End;
  4: Begin
   Mm0:=R[Base+8]; Mm2:=R[Base+24];
   Mm1:=M4XvMult(TAN1,Mm0,16); Mm3:=M4XvMult(TAN3,Mm2,16);
   Mm7:=M4W32(Int64(Mm0)+Mm2); Mm4:=M4W32(Int64(Mm1)-Mm3); Mm0:=M4W32(Int64(
    Mm0)-Mm2); Mm1:=M4W32(Int64(Mm1)+Mm3);
   Mm6:=M4W32(Int64(Mm0)+Mm1); Mm5:=M4W32(Int64(Mm0)-Mm1);
   Mm6:=M4W32(2*Int64(M4XvMult(SQRT2,Mm6,16)));
   Mm5:=M4W32(2*Int64(M4XvMult(SQRT2,Mm5,16)));
   Mm0:=R[Base]; Mm1:=Mm0; Mm3:=R[Base+16];
   Mm2:=M4XvMult(TAN2,Mm3,16);
  End;
  Else Begin
   Mm7:=R[Base+8];
   Mm4:=M4XvMult(TAN1,Mm7,16);
   Mm6:=M4W32(Int64(Mm7)+Mm4); Mm5:=M4W32(Int64(Mm7)-Mm4);
   Mm6:=M4W32(2*Int64(M4XvMult(SQRT2,Mm6,16)));
   Mm5:=M4W32(2*Int64(M4XvMult(SQRT2,Mm5,16)));
   Mm0:=R[Base]; Mm1:=Mm0; Mm3:=R[Base+16];
   Mm2:=M4XvMult(TAN2,Mm3,16);
  End;
 End;
 Bf(Mm0,Mm3,Sp);
 Bf(Mm0,Mm7,Sp);
 R[Base]:=SmallInt(M4Sar(Mm0,6)); R[Base+56]:=SmallInt(M4Sar(Mm7,6));
 Bf(Mm3,Mm4,Mm0);
 R[Base+24]:=SmallInt(M4Sar(Mm3,6)); R[Base+32]:=SmallInt(M4Sar(Mm4,6));
 Bf(Mm1,Mm2,Mm0);
 Bf(Mm1,Mm6,Mm0);
 R[Base+8]:=SmallInt(M4Sar(Mm1,6)); R[Base+48]:=SmallInt(M4Sar(Mm6,6));
 Bf(Mm2,Mm5,Mm0);
 R[Base+16]:=SmallInt(M4Sar(Mm2,6)); R[Base+40]:=SmallInt(M4Sar(Mm5,6));
End;

Procedure M4XvidIdct(Var Blk: TH3Blk);
Const
 T04: Array[0..6] Of LongInt=(22725,21407,19266,16384,12873,8867,4520);
 T17: Array[0..6] Of LongInt=(31521,29692,26722,22725,17855,12299,6270);
 T26: Array[0..6] Of LongInt=(29692,27969,25172,21407,16819,11585,5906);
 T35: Array[0..6] Of LongInt=(26722,25172,22654,19266,15137,10426,5315);
Var I,Rows: LongInt;
Begin
 Rows:=7;
 M4XvRow(Blk,0,T04,65536);
 M4XvRow(Blk,8,T17,3597);
 M4XvRow(Blk,16,T26,2260);
 If M4XvRow(Blk,24,T35,1203) Then Rows:=Rows Or 8;
 If M4XvRow(Blk,32,T04,0) Then Rows:=Rows Or $10;
 If M4XvRow(Blk,40,T35,120) Then Rows:=Rows Or $20;
 If M4XvRow(Blk,48,T26,512) Then Rows:=Rows Or $40;
 If M4XvRow(Blk,56,T17,512) Then Rows:=Rows Or $80;
 If (Rows And $F0)<>0 Then Begin For I:=0 To 7 Do M4XvCol(Blk,I,8); End
 Else If (Rows And 8)<>0 Then Begin For I:=0 To 7 Do M4XvCol(Blk,I,4); End
 Else Begin For I:=0 To 7 Do M4XvCol(Blk,I,3); End;
End;

Procedure M4IdctPut(Var Blk: TH3Blk; Dest: PEABuffer; Off,Stride: LongInt; Add:
 Boolean);
Var X,Y,V: LongInt;
Begin
 If M4XvidBuild<0 Then Begin H3Idct(Blk,Dest,Off,Stride,Add); Exit; End;
 M4XvidIdct(Blk);
 For Y:=0 To 7 Do For X:=0 To 7 Do Begin
  V:=Blk[Y*8+X];
  If Add Then V:=V+Dest^[Off+Y*Stride+X];
  If V<0 Then V:=0 Else If V>255 Then V:=255;
  Dest^[Off+Y*Stride+X]:=V;
 End;
End;

{ ---- reconstruction d'un macrobloc (mpv_reconstruct_mb_internal) ---- }
Procedure M4Recon;
Var
 Xy,I,DY,DC,DctStr,DctOff,Ref: LongInt; Cur: ^TM4Pic; NoRnd: Boolean;
Begin
 Cur:=@M4P[M4CurI];
 Xy:=M4MbY*M4MbS+M4MbX+M4Off;
 Cur^.Qs^[Xy]:=M4Qscale;
 If M4MbIntra=0 Then Begin
  If M4IntraTab^[Xy]<>0 Then M4CleanIntraEntries;
 End Else M4IntraTab^[Xy]:=1;
 If M4Skip<>0 Then Begin M4Skip:=0; Cur^.Sk^[Xy]:=1; End
 Else If Not Cur^.IsRef Then Cur^.Sk^[Xy]:=1 Else Cur^.Sk^[Xy]:=0;
 DY:=M4MbY*16*M4LY+M4MbX*16;
 DC:=M4MbY*8*M4LC+M4MbX*8;
 DctStr:=M4LY Shl M4IDct;
 If M4IDct<>0 Then DctOff:=M4LY Else DctOff:=M4LY*8;
 If M4MbIntra=0 Then Begin
  NoRnd:=(M4NoRnd<>0) And (M4PType<>2);
  If (M4MvDir And 1)<>0 Then Begin
   M4Motion(0,M4LastI,DY,DC,NoRnd,False);
   If (M4MvDir And 2)<>0 Then M4Motion(1,M4NextI,DY,DC,NoRnd,True);
  End Else If (M4MvDir And 2)<>0 Then M4Motion(1,M4NextI,DY,DC,NoRnd,False);
  For I:=0 To 5 Do If M4BlkLast[I]>=0 Then Begin
   If M4MpegQuant<>0 Then M4DequantInterMpeg(I);
   Case I Of
    0: M4IdctPut(M4Blk[0],Cur^.Y,DY,DctStr,True);
    1: M4IdctPut(M4Blk[1],Cur^.Y,DY+8,DctStr,True);
    2: M4IdctPut(M4Blk[2],Cur^.Y,DY+DctOff,DctStr,True);
    3: M4IdctPut(M4Blk[3],Cur^.Y,DY+DctOff+8,DctStr,True);
    4: M4IdctPut(M4Blk[4],Cur^.U,DC,M4LC,True);
    5: M4IdctPut(M4Blk[5],Cur^.V,DC,M4LC,True);
   End;
  End;
 End Else Begin
  For I:=0 To 5 Do Begin
   M4DequantIntra(I);
   Case I Of
    0: M4IdctPut(M4Blk[0],Cur^.Y,DY,DctStr,False);
    1: M4IdctPut(M4Blk[1],Cur^.Y,DY+8,DctStr,False);
    2: M4IdctPut(M4Blk[2],Cur^.Y,DY+DctOff,DctStr,False);
    3: M4IdctPut(M4Blk[3],Cur^.Y,DY+DctOff+8,DctStr,False);
    4: M4IdctPut(M4Blk[4],Cur^.U,DC,M4LC,False);
    5: M4IdctPut(M4Blk[5],Cur^.V,DC,M4LC,False);
   End;
  End;
 End;
End;

{ ---- allocation et gestion des images ---- }
Type TM4I64=Array[0..100000000] Of Int64;
Procedure M4FreeAll;
Var I: LongInt;
Begin
 For I:=0 To 4 Do With M4P[I] Do Begin
  If Y<>Nil Then Begin FreeMem(Y); Y:=Nil; End;
  If U<>Nil Then Begin FreeMem(U); U:=Nil; End;
  If V<>Nil Then Begin FreeMem(V); V:=Nil; End;
  If Ref<>Nil Then Begin FreeMem(Ref); Ref:=Nil; End;
  If Qs<>Nil Then Begin FreeMem(Qs); Qs:=Nil; End;
  If Sk<>Nil Then Begin FreeMem(Sk); Sk:=Nil; End;
  If Mt<>Nil Then Begin FreeMem(Mt); Mt:=Nil; End;
  If Mv<>Nil Then Begin FreeMem(Mv); Mv:=Nil; End;
  Used:=False; IsRef:=False;
 End;
 For I:=0 To 2 Do Begin
  If M4Dc[I]<>Nil Then Begin FreeMem(M4Dc[I]); M4Dc[I]:=Nil; End;
  If M4Ac[I]<>Nil Then Begin FreeMem(M4Ac[I]); M4Ac[I]:=Nil; End;
 End;
 If M4IntraTab<>Nil Then Begin FreeMem(M4IntraTab); M4IntraTab:=Nil; End;
 If M4CbpTab<>Nil Then Begin FreeMem(M4CbpTab); M4CbpTab:=Nil; End;
 If M4DirTab<>Nil Then Begin FreeMem(M4DirTab); M4DirTab:=Nil; End;
 If M4PField<>Nil Then Begin FreeMem(M4PField); M4PField:=Nil; End;
 M4CurI:=-1; M4LastI:=-1; M4NextI:=-1;
End;

Procedure M4Alloc;
Var I,YSize,CSize,MbN,MvN,DcN0,DcN1,K: LongInt;
Begin
 M4FreeAll;
 M4MbW:=(M4W+15) Div 16; M4MbH:=(M4H+15) Div 16;
 M4MbS:=M4MbW+1; M4B8S:=2*M4MbW+1; M4MbNum:=M4MbW*M4MbH;
 M4HEdge:=M4MbW*16; M4VEdge:=M4MbH*16;
 M4LY:=M4MbW*16; M4LC:=M4MbW*8;
 YSize:=M4LY*M4MbH*16; CSize:=M4LC*M4MbH*8;
 MbN:=(M4MbH+3)*M4MbS+16; M4TabN:=MbN;
 MvN:=2*(M4B8S*(2*M4MbH+3)+2*(M4B8S+8)+16);
 For I:=0 To 4 Do With M4P[I] Do Begin
  GetMem(Y,YSize+64); GetMem(U,CSize+64); GetMem(V,CSize+64);
  FillChar(Y^,YSize+64,128); FillChar(U^,CSize+64,128); FillChar(V^,CSize+64,
   128);
  GetMem(Ref,MbN*4); FillChar(Ref^,MbN*4,0);
  GetMem(Qs,MbN); FillChar(Qs^,MbN,0);
  GetMem(Sk,MbN); FillChar(Sk^,MbN,0);
  GetMem(Mt,MbN*4); FillChar(Mt^,MbN*4,0);
  GetMem(Mv,MvN*2); FillChar(Mv^,MvN*2,0);
  Used:=False; IsRef:=False; PType:=0;
 End;
 DcN0:=M4B8S*(2*M4MbH+4)+64; DcN1:=M4MbS*(M4MbH+4)+64;
 M4DcN[0]:=DcN0; M4DcN[1]:=DcN1; M4DcN[2]:=DcN1;
 For I:=0 To 2 Do Begin
  GetMem(M4Dc[I],M4DcN[I]*2); GetMem(M4Ac[I],M4DcN[I]*32);
  For K:=0 To M4DcN[I]-1 Do M4Dc[I]^[K]:=1024;
  FillChar(M4Ac[I]^,M4DcN[I]*32,0);
 End;
 GetMem(M4IntraTab,MbN); FillChar(M4IntraTab^,MbN,1);
 GetMem(M4CbpTab,MbN); FillChar(M4CbpTab^,MbN,0);
 GetMem(M4DirTab,MbN); FillChar(M4DirTab^,MbN,0);
 GetMem(M4PField,MbN*8); FillChar(M4PField^,MbN*8,0);
 M4AllocW:=M4W; M4AllocH:=M4H;
End;

Function M4FindFree: LongInt;
Var I: LongInt;
Begin
 M4FindFree:=-1;
 For I:=0 To 4 Do If Not M4P[I].Used Then Begin M4FindFree:=I; Exit; End;
End;

Procedure M4Gray(I: LongInt);
Begin
 FillChar(M4P[I].Y^,M4LY*M4MbH*16,128);
 FillChar(M4P[I].U^,M4LC*M4MbH*8,128);
 FillChar(M4P[I].V^,M4LC*M4MbH*8,128);
End;

Function M4FrameStart: Boolean;
Var I,Pic: LongInt;
Begin
 M4FrameStart:=False;
 M4Skip:=0;
 If (M4PType<>2) And (M4LastI>=0) And (M4LastI<>M4NextI) Then M4P[
  M4LastI].Used:=False;
 For I:=0 To 4 Do
  If (Not M4P[I].IsRef) Or ((I<>M4LastI) And (I<>M4NextI)) Then M4P[I].Used:=
   False;
 Pic:=M4FindFree;
 If Pic<0 Then Exit;
 M4P[Pic].Used:=True;
 M4P[Pic].IsRef:=(M4PType<>2);
 M4P[Pic].PType:=M4PType;
 M4CurI:=Pic;
 If M4PType<>2 Then Begin
  M4LastI:=M4NextI;
  M4NextI:=Pic;
 End;
 If ((M4LastI<0) Or Not M4P[M4LastI].Used) And (M4PType<>0) Then Begin
  I:=M4FindFree; If I<0 Then Exit;
  M4LastI:=I; M4P[I].Used:=True; M4P[I].IsRef:=True; M4P[I].PType:=1; M4Gray(I);
 End;
 If ((M4NextI<0) Or Not M4P[M4NextI].Used) And (M4PType=2) Then Begin
  I:=M4FindFree; If I<0 Then Exit;
  M4NextI:=I; M4P[I].Used:=True; M4P[I].IsRef:=True; M4P[I].PType:=1;
 End;
 If (M4Bugs And M4_BUG_EDGE)<>0 Then Begin M4HEdge:=M4W; M4VEdge:=M4H; End
 Else Begin M4HEdge:=M4MbW*16; M4VEdge:=M4MbH*16; End;
 M4FrameStart:=True;
End;

{ ---- boucle de decodage d'une tranche (decode_slice) ---- }
Function M4DecodeSlice: LongInt;
Var Ret,Qsave,BitsLeft,BitsCount,V: LongInt; Cur: ^TM4Pic;
Begin
 M4DecodeSlice:=-1;
 Cur:=@M4P[M4CurI];
 M4ResyncPos:=H3Pos;
 M4FirstLine:=1;
 M4ResyncX:=M4MbX; M4ResyncY:=M4MbY;
 M4SetQscale(M4Qscale);
 If M4Part<>0 Then Begin
  Qsave:=M4Qscale;
  If M4Partitions<0 Then Exit;
  M4FirstLine:=1; M4MbX:=M4ResyncX; M4MbY:=M4ResyncY;
  M4SetQscale(Qsave);
 End;
 While M4MbY<M4MbH Do Begin
  While M4MbX<M4MbW Do Begin
   If (M4ResyncX=M4MbX) And (M4ResyncY+1=M4MbY) Then M4FirstLine:=0;
   M4MvDir:=1; M4MvType:=0;
   If M4Part<>0 Then Ret:=M4PartitionedMb Else Ret:=M4DecodeMb;
   If M4PType<>2 Then M4UpdateMotion;
   If Ret<0 Then Begin
    If Ret=M4_SLICE_END Then Begin
     M4Recon;
     Dec(M4PadScore);
     Inc(M4MbX);
     If M4MbX>=M4MbW Then Begin M4MbX:=0; Inc(M4MbY); End;
     M4DecodeSlice:=0; Exit;
    End Else Begin
     M4Err:=True;
     Exit;
    End;
   End;
   M4Recon;
   Inc(M4MbX);
  End;
  M4MbX:=0;
  Inc(M4MbY);
 End;
 { detection du bug de remplissage }
 If (H3Left>=48) And (H3Show(24)=$4010) And (M4DataPart=0) Then Inc(M4PadScore,
  32);
 BitsLeft:=H3Left;
 If (BitsLeft>=0) And (BitsLeft<137) And (M4DataPart=0) Then Begin
  BitsCount:=H3Pos;
  If BitsLeft=0 Then Inc(M4PadScore,16)
  Else If BitsLeft<>1 Then Begin
   V:=H3Show(8);
   V:=V Or ($7F Shr (7-(BitsCount And 7)));
   If (V=$7F) And (BitsLeft<=8) Then Dec(M4PadScore)
   Else If (V=$7F) And (((H3Pos+8) And 8)<>0) And (BitsLeft<=16) Then Inc(
    M4PadScore,4)
   Else Inc(M4PadScore);
  End;
 End;
 If (M4PadScore>-2) And (M4DataPart=0) Then M4Bugs:=M4Bugs Or M4_BUG_NOPAD Else
  M4Bugs:=M4Bugs And Not M4_BUG_NOPAD;
 If (M4Bugs And M4_BUG_NOPAD)<>0 Then M4DecodeSlice:=0;
End;

Function M4Resync: LongInt;
Var Left,Pos,Bak,Ret: LongInt;
Begin
 M4Resync:=-1;
 H3Skip(1); H3Align;
 If H3Show(16)=0 Then Begin
  Pos:=H3Pos;
  Ret:=M4VideoPacketHeader;
  If Ret>=0 Then Begin M4Resync:=Pos; Exit; End;
 End;
 H3Pos:=M4ResyncPos; H3Align;
 Left:=H3Left;
 While Left>16+1+5+5 Do Begin
  If H3Show(16)=0 Then Begin
   Bak:=H3Pos; Pos:=H3Pos;
   Ret:=M4VideoPacketHeader;
   If Ret>=0 Then Begin M4Resync:=Pos; Exit; End;
   H3Pos:=Bak;
  End;
  H3Skip(8);
  Dec(Left,8);
 End;
End;

{ ---- en-tete d'image : recherche des codes de debut
 (ff_mpeg4_decode_picture_header) ---- }
Function M4PictureHeader: LongInt;
Var Start: Int64; V,Prof,Lev,Vol: LongInt;
Begin
 M4PictureHeader:=-1;
 H3Align;
 Start:=$FF; Vol:=0;
 Repeat
  If H3Pos>=H3Size*8 Then Begin
   If ((H3Size*8=8) And ((M4DivxVer>=0) Or (M4XvidBuild>=0))) Or (M4CTag='QMP4')
    Then M4PictureHeader:=M4_SKIPPED;
   Exit;
  End;
  V:=H3Bits(8);
  Start:=((Start Shl 8) Or V) And $FFFFFFFF;
  If (Start And $FFFFFF00)<>$100 Then Continue;
  If (Start>=$120) And (Start<=$12F) Then Begin
   If Vol<>0 Then Continue;
   Inc(Vol);
   If M4VolHeader<0 Then Exit;
  End Else If Start=$1B2 Then M4UserData
  Else If Start=$1B3 Then M4GopHeader
  Else If Start=$1B0 Then Begin
   Prof:=H3Bits(4); Lev:=H3Bits(4);
   If (Prof=14) And (Lev>0) And (Lev<9) Then Fail(
    'mpeg4: profil Simple Studio non pris en charge.');
  End Else If Start=$1B5 Then M4VisualObject
  Else If Start=$1B6 Then Break;
  H3Align;
  Start:=$FF;
 Until False;
 If M4LowDelay<>0 Then ;
 If Not M4Have Then Exit;
 M4PictureHeader:=M4VopHeader;
End;

{ ---- sortie ---- }
Var M4RateN,M4RateD: LongInt; M4Delta,M4T0,M4LastSlot: Int64;
Procedure M4Emit(P: LongInt);
Var Y,CW,CH,Size: LongInt;
Begin
 If M4OutBegun=0 Then Begin M4OutBegun:=1; M4T0:=M4P[P].Time; M4LastSlot:=-1; End;
 CW:=(M4W+1) Div 2; CH:=(M4H+1) Div 2;
 Size:=M4W*M4H+2*CW*CH;
 If M4OutBuf=Nil Then GetMem(M4OutBuf,Size+64);
 For Y:=0 To M4H-1 Do Move(M4P[P].Y^[Y*M4LY],M4OutBuf^[Y*M4W],M4W);
 For Y:=0 To CH-1 Do Move(M4P[P].U^[Y*M4LC],M4OutBuf^[M4W*M4H+Y*CW],CW);
 For Y:=0 To CH-1 Do Move(M4P[P].V^[Y*M4LC],M4OutBuf^[M4W*M4H+CW*CH+Y*CW],CW);
 Inc(M4OutCount);
 If @M4VidHook<>Nil Then M4VidHook(M4OutBuf,M4W,M4H);
End;

Var M4InTag: String[4]; M4Scan: Boolean; M4Times: ^TM4I64; M4TimeN,M4TimeCap:
 LongInt;
Procedure M4Packet(Pk: PEABuffer; Len: LongInt);
Var Ret,Slice,PrevX,PrevY: LongInt;
Begin
 H3Buf:=Pk; H3Size:=Len; H3Pos:=0;
 FillChar(Pk^[Len],32,0);
 M4SkippedLast:=False;
 Ret:=M4PictureHeader;
 If Ret=M4_SKIPPED Then Begin M4SkippedLast:=True; Exit; End;
 If Ret<0 Then Exit;
 If M4Scan Then Begin
  If M4TimeN>=M4TimeCap Then Begin
   ReallocMem(M4Times,(M4TimeCap*2+1024)*8); M4TimeCap:=M4TimeCap*2+1024;
  End;
  M4Times^[M4TimeN]:=M4Time; Inc(M4TimeN); Exit;
 End;
 If (M4W<=0) Or (M4H<=0) Then Exit;
 If (M4W<>M4AllocW) Or (M4H<>M4AllocH) Then Begin M4Alloc; M4PicHave:=False;
  End;
 If (M4PType<>2) And (M4MbNum Div 2>H3Left) Then Exit;
 M4Workaround;
 If (M4LastI<0) And (M4PType=2) Then Exit;
 If Not M4FrameStart Then Exit;
 M4PicHave:=True; M4P[M4CurI].Time:=M4Time;
 M4MbX:=0; M4MbY:=0; M4Err:=False;
 Slice:=M4DecodeSlice;
 While M4MbY<M4MbH Do Begin
  PrevX:=M4MbX; PrevY:=M4MbY;
  If M4Resync<0 Then Break;
  M4CleanBuffers;
  If M4DecodeSlice<0 Then Slice:=-1;
 End;
 If (M4PType=2) Or (M4LowDelay<>0) Then M4Emit(M4CurI)
 Else If M4LastI>=0 Then M4Emit(M4LastI);
 M4P[M4CurI].PType:=M4PType;
End;

Procedure M4Reset;
Var Ix: LongInt;
Begin
 M4Init:=False; M4InitTables;
 M4Have:=False; M4W:=0; M4H:=0; M4AllocW:=-1; M4AllocH:=-1;
 M4CurI:=-1; M4LastI:=-1; M4NextI:=-1;
 M4DivxVer:=-1; M4DivxBuild:=-1; M4XvidBuild:=-1; M4LavcBuild:=-1; M4Bugs:=1;
  M4PadScore:=0; M4DivxPacked:=False; M4CTag:=M4InTag;
 M4VoType:=0; M4Shape:=0; M4TIncBits:=4; M4Res:=25; M4FixedRate:=1; M4Prog:=1;
  M4SprUsage:=0; M4NumWarp:=0; M4WarpAcc:=0;
 M4BrightChg:=0; M4QuantPrec:=5; M4MpegQuant:=0; M4QuarterS:=0; M4DataPart:=0;
  M4Rvlc:=0; M4ResyncMarker:=1; M4NewPred:=0; M4Scal:=0;
 M4EnhType:=0; M4LowDelay:=0; M4VolCtl:=0; M4CplxI:=0; M4CplxP:=0; M4CplxB:=0;
  M4SarN:=0; M4SarD:=1; M4Range:=0;
 M4Time:=0; M4TimeBase:=0; M4LastTimeBase:=0; M4LastNonBTime:=0; M4PPTime:=0;
  M4PBTime:=0; M4TFrame:=0; M4PPField:=0; M4PBField:=0;
 M4PicNum:=0; M4PType:=0; M4Part:=0; M4NoRnd:=0; M4Tff:=0; M4AltScan:=0;
  M4IDct:=0;
 FillChar(M4SpOff,SizeOf(M4SpOff),0); FillChar(M4SpDelta,SizeOf(M4SpDelta),0);
  M4RealWarp:=0;
 M4DefaultMatrices;
 M4OutBuf:=Nil; M4OutBegun:=0; M4OutCount:=0; M4SkippedLast:=False; M4PicHave:=
  False;
 FillChar(M4Dc,SizeOf(M4Dc),0); FillChar(M4Ac,SizeOf(M4Ac),0);
 M4IntraTab:=Nil; M4CbpTab:=Nil; M4DirTab:=Nil; M4PField:=Nil;
 FillChar(M4P,SizeOf(M4P),0);
  H3LongVec:=0;
 For Ix:=0 To 31 Do Begin M4YDcT[Ix]:=M4YDcScale[Ix]; M4CDcT[Ix]:=M4CDcScale[
  Ix]; End;
 M4Ms:=0; M4CodedBlk:=Nil;
End;
{$ENDIF}

{ ====================================================================== }
{ Colle entre l'interface et les moteurs audio                             }
{ ====================================================================== }
Const
 ekMP3 = 1; ekAIFF = 2; ekVOC = 3; ekMOD = 4; ekEncMP3 = 5; ekAAC = 6; ekEncAAC = 7;

Type
 TByteArr = Array[0..32767] Of Byte;
 PByteArr = ^TByteArr;
 TIntArr = Array[0..16383] Of Integer;
 PIntArr = ^TIntArr;
 THdr = Array[0..63] Of Byte;
 TWavInfo = Record
  Tag,Ch,Bits,Align: Integer;
  Rate: LongInt;
  DataOfs,DataLen: LongInt;
 End;
 TAP = Record
  StartMs,EndMs,DelayMs: LongInt;
  Vol,Speed: Integer;
  OutRate: LongInt;
  OutCh: Integer;
  Rev: Boolean;
  FadeIn,FadeOut: LongInt;
 End;

Var
 EngFirst: LongInt;
 JobIdx: Integer;
 TmpCount: Integer;
 LastDraw: LongInt;
 EngUsed: Boolean;

Procedure UiTick(Pos,Total: LongInt); Forward;

{$IFDEF FPC}
Procedure EngTickUi(Pos,Total: LongInt);
Begin
 UiTick(Pos,Total);
 If Stopped Then Begin EngMsg:='Conversion annul'#233'e.'; EngAbort; End;
End;
{$ENDIF}

Procedure InitEngines;
Begin
 {$IFDEF FPC}
 {$IFDEF UNIX}
 Assign(EngOut,'/dev/null');
 {$ELSE}
 Assign(EngOut,'NUL');
 {$ENDIF}
 {$I-}Rewrite(EngOut);{$I+}
 If IOResult<>0 Then ;
 EngTickProc:=EngTickUi;
 {$ENDIF}
End;

Function TmpName(Const Ext: String): String;
Begin
 Inc(TmpCount);
 TmpName:=TmpDir+'AMP4'+IStr(Ticks Mod 10000)+'_'+IStr(TmpCount)+'.'+Ext;
End;

Function RunEng(Kind: Integer; Const Src,Dst: String; Arg: Integer; Var Err: String): Boolean;
Begin
 {$IFDEF FPC}
 EngMsg:=''; EngFirst:=0; AacInOpen:=False; AacOutOpen:=False; EngUsed:=True;
 DelFile(Dst);
 If SetJmp(EngJmp)=0 Then Begin
  Case Kind Of
   ekMP3: DecodeMP3(Src,Dst);
   ekAIFF: DecodeAIFF(Src,Dst);
   ekVOC: DecodeVOC(Src,Dst);
   ekMOD: DecodeMOD(Src,Dst);
   ekEncMP3: EncodeMP3(Src,Dst,Arg);
   ekAAC: DecodeAAC(Src,Dst);
   ekEncAAC: AEEncodeAAC(Src,Dst,Arg);
  End;
  RunEng:=True;
 End Else Begin
  If (Kind=ekAAC) Or (Kind=ekEncAAC) Then AacCleanup(True);
  If EngMsg='' Then EngMsg:='Erreur de conversion.';
  Err:=EngMsg; RunEng:=False;
 End;
 {$ELSE}
 Err:='Moteur audio indisponible dans la version Turbo Pascal.'; RunEng:=False;
 {$ENDIF}
End;

{ ---------------------------------------------------------------------- }
{ Fichiers WAV                                                              }
{ ---------------------------------------------------------------------- }
Procedure P32(Var B: THdr; At: Integer; V: LongInt);
Begin
 B[At]:=V And 255; B[At+1]:=(V Shr 8) And 255; B[At+2]:=(V Shr 16) And 255; B[At+3]:=(V Shr 24) And 255;
End;

Procedure P16(Var B: THdr; At: Integer; V: LongInt);
Begin
 B[At]:=V And 255; B[At+1]:=(V Shr 8) And 255;
End;

Procedure T4(Var B: THdr; At: Integer; Const S: String);
Begin
 B[At]:=Ord(S[1]); B[At+1]:=Ord(S[2]); B[At+2]:=Ord(S[3]); B[At+3]:=Ord(S[4]);
End;

Procedure PcmHeader(Var B: THdr; Rate: LongInt; Ch,Bits: Integer; DataLen: LongInt);
Begin
 FillChar(B,SizeOf(B),0);
 T4(B,0,'RIFF'); P32(B,4,DataLen+36); T4(B,8,'WAVE'); T4(B,12,'fmt '); P32(B,16,16);
 P16(B,20,1); P16(B,22,Ch); P32(B,24,Rate); P32(B,28,Rate*Ch*(Bits Div 8));
 P16(B,32,Ch*(Bits Div 8)); P16(B,34,Bits); T4(B,36,'data'); P32(B,40,DataLen);
End;

Function ReadWavInfo(Const Path: String; Var W: TWavInfo): Boolean;
Var P,Sz: LongInt; Id: String; Got: Boolean;
Begin
 ReadWavInfo:=False; FillChar(W,SizeOf(W),0);
 If Not COpen(Path) Then Exit;
 If (C4(0)<>'RIFF') Or (C4(8)<>'WAVE') Then Begin CClose; Exit; End;
 P:=12; Got:=False;
 While P+8<=CSize Do Begin
  Id:=C4(P); Sz:=L32(P+4);
  If Id='fmt ' Then Begin
   W.Tag:=L16(P+8); W.Ch:=L16(P+10); W.Rate:=L32(P+12); W.Align:=L16(P+20); W.Bits:=L16(P+22);
   If (W.Tag=$FFFE) And (Sz>=26) Then W.Tag:=L16(P+8+24);
   Got:=True;
  End Else If Id='data' Then Begin
   W.DataOfs:=P+8; W.DataLen:=Sz;
   If (Sz<=0) Or (Sz>CSize-W.DataOfs) Then W.DataLen:=CSize-W.DataOfs;
   If Got Then ReadWavInfo:=True;
   Break;
  End;
  If Sz<0 Then Break;
  P:=P+8+Sz+(Sz And 1);
 End;
 CClose;
End;

Function OpenWavIn(Const Path: String; Var F: File; Var W: TWavInfo; Var Err: String): Boolean;
Var Old: Byte;
Begin
 OpenWavIn:=False;
 If Not ReadWavInfo(Path,W) Then Begin Err:='Fichier WAV invalide.'; Exit; End;
 Assign(F,Path); Old:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Begin Err:='Ouverture impossible: '+Path; Exit; End;
 {$I-}Seek(F,W.DataOfs);{$I+}
 OpenWavIn:=True;
End;

Function CreateOut(Const Path: String; Var F: File; Var Err: String): Boolean;
Begin
 Assign(F,Path);
 {$I-}Rewrite(F,1);{$I+}
 If IOResult<>0 Then Begin Err:='Cr'#233'ation impossible: '+Path; CreateOut:=False; End
 Else CreateOut:=True;
End;

Procedure PutHeaderFix(Var F: File; Rate: LongInt; Ch,Bits: Integer; DataLen: LongInt);
Var H: THdr;
Begin
 PcmHeader(H,Rate,Ch,Bits,DataLen);
 Seek(F,0); BlockWrite(F,H,44);
End;

Function IsCanon(Const Path: String): Boolean;
Var W: TWavInfo;
Begin
 IsCanon:=False;
 If Not ReadWavInfo(Path,W) Then Exit;
 IsCanon:=(W.Tag=1) And (W.Bits=16) And (W.Ch>=1) And (W.Ch<=2) And (W.DataOfs=44);
End;

Function Sar8(V: LongInt): LongInt;
Begin
 If V>=0 Then Sar8:=V Shr 8 Else Sar8:=-((-V+255) Shr 8);
End;

Function ImaDecode(Var Pred,Idx: LongInt; N: Integer): Integer;
Var Step,Diff: LongInt;
Begin
 Step:=ADPCMStepTable[Idx];
 Diff:=Step Shr 3;
 If (N And 4)<>0 Then Inc(Diff,Step);
 If (N And 2)<>0 Then Inc(Diff,Step Shr 1);
 If (N And 1)<>0 Then Inc(Diff,Step Shr 2);
 If (N And 8)<>0 Then Dec(Pred,Diff) Else Inc(Pred,Diff);
 If Pred>32767 Then Pred:=32767; If Pred<-32768 Then Pred:=-32768;
 Inc(Idx,ADPCMIndexTable[N]);
 If Idx<0 Then Idx:=0; If Idx>88 Then Idx:=88;
 ImaDecode:=Pred;
End;

Function ALawDec(B: Byte): LongInt;
Var A,T,Seg: LongInt;
Begin
 A:=B Xor $55; T:=(A And $0F) Shl 4; Seg:=(A And $70) Shr 4;
 If Seg=0 Then Inc(T,8) Else Begin Inc(T,$108); T:=T Shl (Seg-1); End;
 If (A And $80)<>0 Then ALawDec:=T Else ALawDec:=-T;
End;

Function ULawDec(B: Byte): LongInt;
Var U,T: LongInt;
Begin
 U:=(Not B) And 255; T:=((U And $0F) Shl 3)+$84; T:=T Shl ((U And $70) Shr 4); Dec(T,$84);
 If (U And $80)<>0 Then ULawDec:=-T Else ULawDec:=T;
End;

{ Convertit tout WAV pris en charge en PCM 16 bits mono/stereo (en-tete de 44 octets) }
Function NormalizeWav(Const Src,Dst: String; Var Err: String): Boolean;
Var
 W: TWavInfo; FI,FO: File; IB: PByteArr; OB: PIntArr;
 Remain,Total,Take,Got: LongInt; BPF,OC,Frames,I,C,K,Spb,G,B0: Integer; V: LongInt;
 Ok: Boolean; Sg: Single; Pred,Idx: Array[0..1] Of LongInt; Tmp: Array[0..1,0..4095] Of Integer;
 Sub: Integer; Nib: Integer; Code: Integer; Hd0: THdr;
Begin
 NormalizeWav:=False;
 If Not OpenWavIn(Src,FI,W,Err) Then Exit;
 If (W.Ch<1) Or (W.Rate<1) Then Begin Close(FI); Err:='En-t'#234'te WAV invalide.'; Exit; End;
 If Not (W.Tag In [1,3,6,7,$11]) Then Begin
  Close(FI); Err:='Codec audio WAV non pris en charge ('+WavTagName(W.Tag)+').'; Exit;
 End;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); Exit; End;
 New(IB); New(OB);
 OC:=W.Ch; If OC>2 Then OC:=2;
 Remain:=W.DataLen; Total:=0; Ok:=True;
 PcmHeader(Hd0,W.Rate,OC,16,0); BlockWrite(FO,Hd0,44);
 If W.Tag=$11 Then Begin
  { IMA ADPCM par blocs }
  BPF:=W.Align; If (BPF<4*W.Ch+4) Or (BPF>16000) Then BPF:=1024;
  Spb:=((BPF-4*W.Ch) Div (4*W.Ch))*8+1;
  If Spb>4095 Then Begin Ok:=False; Err:='Bloc ADPCM trop grand.'; End;
  While Ok And (Remain>=BPF) Do Begin
   BlockRead(FI,IB^,BPF,Got); Dec(Remain,BPF);
   For C:=0 To W.Ch-1 Do If C<2 Then Begin
    Pred[C]:=IB^[C*4]+IB^[C*4+1]*256; If Pred[C]>32767 Then Dec(Pred[C],65536);
    Idx[C]:=IB^[C*4+2]; If Idx[C]>88 Then Idx[C]:=88;
    Tmp[C,0]:=Pred[C];
   End;
   B0:=4*W.Ch;
   G:=0;
   While B0+4*W.Ch<=BPF Do Begin
    For C:=0 To W.Ch-1 Do Begin
     For K:=0 To 3 Do Begin
      Nib:=IB^[B0+K];
      If C<2 Then Begin
       Tmp[C,1+G*8+K*2]:=ImaDecode(Pred[C],Idx[C],Nib And 15);
       Tmp[C,2+G*8+K*2]:=ImaDecode(Pred[C],Idx[C],Nib Shr 4);
      End;
     End;
     Inc(B0,4);
    End;
    Inc(G);
   End;
   For I:=0 To Spb-1 Do Begin
    For C:=0 To OC-1 Do OB^[I*OC+C]:=Tmp[C,I];
   End;
   BlockWrite(FO,OB^,Spb*OC*2); Inc(Total,Spb*OC*2);
   If (Total And $3FFFF)=0 Then UiTick(W.DataLen-Remain,W.DataLen);
   If Stopped Then Ok:=False;
  End;
 End Else Begin
  BPF:=W.Align; If BPF<1 Then BPF:=(W.Bits Div 8)*W.Ch;
  If BPF<1 Then BPF:=1;
  While Ok And (Remain>=BPF) Do Begin
   Take:=Min(Remain,16384); Take:=Take-(Take Mod BPF);
   BlockRead(FI,IB^,Take,Got); Got:=Got-(Got Mod BPF);
   If Got<=0 Then Break;
   Dec(Remain,Got); Frames:=Got Div BPF;
   For I:=0 To Frames-1 Do Begin
    For C:=0 To OC-1 Do Begin
     K:=I*BPF+C*(W.Bits Div 8);
     Case W.Tag Of
      6: V:=ALawDec(IB^[K]);
      7: V:=ULawDec(IB^[K]);
      3: Begin Move(IB^[K],Sg,4); V:=Round(Sg*32767.0); End;
      Else Case W.Bits Of
       8: V:=(LongInt(IB^[K])-128) Shl 8;
       16: Begin V:=IB^[K]+IB^[K+1]*256; End;
       24: Begin V:=IB^[K+1]+IB^[K+2]*256; End;
       32: Begin V:=IB^[K+2]+IB^[K+3]*256; End;
       Else V:=0;
      End;
     End;
     If (W.Tag=1) And (W.Bits In [16,24,32]) And (V>32767) Then Dec(V,65536);
     If V>32767 Then V:=32767; If V<-32768 Then V:=-32768;
     OB^[I*OC+C]:=V;
    End;
   End;
   BlockWrite(FO,OB^,Frames*OC*2); Inc(Total,Frames*OC*2);
   UiTick(W.DataLen-Remain,W.DataLen);
   If Stopped Then Ok:=False;
  End;
 End;
 Dispose(IB); Dispose(OB);
 If Ok Then PutHeaderFix(FO,W.Rate,OC,16,Total);
 Close(FI); Close(FO);
 If Not Ok Then Begin DelFile(Dst); If Err='' Then Err:='Conversion annul'#233'e.'; Exit; End;
 NormalizeWav:=True;
End;

{ Amene un fichier temporaire (sortie d'un decodeur) a la forme canonique }
Function MakeCanon(Const Tmp,Dst: String; Var Err: String): Boolean;
Var F: File;
Begin
 MakeCanon:=False;
 If IsCanon(Tmp) Then Begin
  DelFile(Dst);
  Assign(F,Tmp);
  {$I-}Rename(F,Dst);{$I+}
  If IOResult<>0 Then Begin Err:='Renommage impossible.'; Exit; End;
  MakeCanon:=True;
 End Else Begin
  MakeCanon:=NormalizeWav(Tmp,Dst,Err);
  DelFile(Tmp);
 End;
End;

{ ---------------------------------------------------------------------- }
{ Extraction audio des conteneurs                                           }
{ ---------------------------------------------------------------------- }
Procedure CopyRange(Var FI,FO: File; Pos,Len: LongInt; Swap: Boolean);
Var Buf: PByteArr; N,Got,I: Word; T: Byte;
Begin
 If Len<=0 Then Exit;
 New(Buf);
 {$I-}Seek(FI,Pos);{$I+}
 While Len>0 Do Begin
  If Len>32768 Then N:=32768 Else N:=Len;
  BlockRead(FI,Buf^,N,Got);
  If Got=0 Then Break;
  If Swap Then Begin
   I:=0;
   While I+1<Got Do Begin T:=Buf^[I]; Buf^[I]:=Buf^[I+1]; Buf^[I+1]:=T; Inc(I,2); End;
  End;
  BlockWrite(FO,Buf^,Got);
  Dec(Len,Got);
 End;
 Dispose(Buf);
End;

Procedure PutAdts(Var FO: File; Prof,Sfi,Ch,Size: Integer);
Var H: Array[0..6] Of Byte; L: LongInt;
Begin
 L:=Size+7;
 H[0]:=$FF; H[1]:=$F1; H[2]:=(Prof Shl 6) Or (Sfi Shl 2) Or ((Ch Shr 2) And 1);
 H[3]:=((Ch And 3) Shl 6) Or ((L Shr 11) And 3); H[4]:=(L Shr 3) And $FF;
 H[5]:=((L And 7) Shl 5) Or $1F; H[6]:=$FC;
 BlockWrite(FO,H,7);
End;

{ AVI : extrait la premiere piste audio. Kind: 1 WAV, 2 MP3 brut }
Function ExtractAvi(Const Src,Dst: String; Var Kind: Integer; Var Err: String): Boolean;
Var
 P,Sz,Q,Z,Mv,MvEnd,FmtOfs,FmtLen,DataLen,Pos2: LongInt; Id,Want: String; Idx,Cur,Tag: Integer;
 FI,FO: File; H: THdr; Buf: Array[0..511] Of Byte; I: Integer; HaveAud: Boolean; Strh: String;
 Old: Byte;
 Procedure Hdrl(S,En: LongInt);
 Var Q2,Z2: LongInt; I2: String;
 Begin
  Q2:=S;
  While Q2+8<=En Do Begin
   I2:=C4(Q2); Z2:=L32(Q2+4);
   If Z2<0 Then Break;
   If I2='LIST' Then Begin
    If C4(Q2+8)='strl' Then Begin Strh:=''; Hdrl(Q2+12,Q2+8+Z2); Inc(Cur); End
    Else Hdrl(Q2+12,Q2+8+Z2);
   End Else If I2='strh' Then Strh:=C4(Q2+8)
   Else If (I2='strf') And (Strh='auds') And Not HaveAud Then Begin
    HaveAud:=True; Idx:=Cur; FmtOfs:=Q2+8; FmtLen:=Z2; Tag:=L16(Q2+8);
   End;
   Q2:=Q2+8+Z2+(Z2 And 1);
  End;
 End;
Begin
 ExtractAvi:=False; HaveAud:=False; Cur:=0; Idx:=-1; Tag:=0; Strh:=''; Mv:=0; MvEnd:=0;
 If Not COpen(Src) Then Begin Err:='Ouverture impossible.'; Exit; End;
 P:=12;
 While P+12<=CSize Do Begin
  Id:=C4(P); Sz:=L32(P+4);
  If Sz<0 Then Break;
  If (Id='LIST') And (C4(P+8)='hdrl') Then Hdrl(P+12,P+8+Sz);
  If (Id='LIST') And (C4(P+8)='movi') Then Begin Mv:=P+12; MvEnd:=P+8+Sz; If MvEnd>CSize Then MvEnd:=CSize; Break; End;
  P:=P+8+Sz+(Sz And 1);
 End;
 If Not HaveAud Then Begin CClose; Err:='Aucune piste audio dans ce fichier AVI.'; Exit; End;
 If Not (Tag In [1,$11,$55,$FFFE,6,7,3]) Then Begin
  CClose; Err:='Audio AVI non pris en charge ('+WavTagName(Tag)+').'; Exit;
 End;
 Want:=Pad2(Idx)+'wb';
 If Tag=$55 Then Kind:=2 Else Kind:=1;
 Assign(FI,Src); Old:=FileMode; FileMode:=0;
 {$I-}Reset(FI,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Begin CClose; Err:='Ouverture impossible.'; Exit; End;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); CClose; Exit; End;
 DataLen:=0;
 If Kind=1 Then Begin
  FillChar(H,SizeOf(H),0);
  { en-tete RIFF + fmt copie de la source }
  T4(H,0,'RIFF'); T4(H,8,'WAVE'); T4(H,12,'fmt ');
  If FmtLen>40 Then FmtLen:=40;
  P32(H,16,FmtLen);
  For I:=0 To FmtLen-1 Do H[20+I]:=CB(FmtOfs+I);
  T4(H,20+FmtLen,'data');
  BlockWrite(FO,H,28+FmtLen);
 End;
 { parcours de movi }
 P:=Mv;
 While P+8<=MvEnd Do Begin
  Id:=C4(P); Sz:=L32(P+4);
  If Sz<0 Then Break;
  If Id='LIST' Then Begin P:=P+12; Continue; End;
  If Id=Want Then Begin
   If P+8+Sz>CSize Then Sz:=CSize-P-8;
   CopyRange(FI,FO,P+8,Sz,False); Inc(DataLen,Sz);
  End;
  P:=P+8+Sz+(Sz And 1);
  If (P And $FFFF)<16 Then UiTick(P,CSize);
 End;
 If Kind=1 Then Begin
  Seek(FO,4); Z:=DataLen+20+FmtLen; BlockWrite(FO,Z,4);
  Seek(FO,24+FmtLen); BlockWrite(FO,DataLen,4);
 End;
 Close(FI); Close(FO); CClose;
 If DataLen=0 Then Begin DelFile(Dst); Err:='Aucune donn'#233'e audio trouv'#233'e.'; Exit; End;
 ExtractAvi:=True;
End;

{ FLV : Kind 1 WAV, 2 MP3, 3 AAC (ADTS) }
Function ExtractFlv(Const Src,Dst: String; Var Kind: Integer; Var Err: String): Boolean;
Var
 P,Sz,DataLen: LongInt; FI,FO: File; Typ,Fl,Fmt: Byte; Old: Byte; H: THdr; Rate: LongInt; Ch,Bits: Integer;
 Prof,Sfi,Cfg,Cnt: Integer; GotAsc: Boolean; B1,B2: Byte;
Begin
 ExtractFlv:=False; Kind:=0; DataLen:=0; GotAsc:=False; Prof:=1; Sfi:=4; Cfg:=2; Cnt:=0;
 If Not COpen(Src) Then Begin Err:='Ouverture impossible.'; Exit; End;
 P:=B32(5)+4;
 While P+12<CSize Do Begin
  If CB(P)=8 Then Begin Fl:=CB(P+11); Break; End;
  Sz:=LongInt(CB(P+1))*65536+B16(P+2);
  P:=P+11+Sz+4;
 End;
 If P+12>=CSize Then Begin CClose; Err:='Aucune piste audio dans ce fichier FLV.'; Exit; End;
 Fmt:=Fl Shr 4;
 Case Fmt Of
  2: Kind:=2;
  0,3: Kind:=1;
  10: Kind:=3;
  Else Begin CClose; Err:='Audio FLV non pris en charge (format '+IStr(Fmt)+').'; Exit; End;
 End;
 Case (Fl Shr 2) And 3 Of 0: Rate:=5512; 1: Rate:=11025; 2: Rate:=22050; Else Rate:=44100 End;
 Ch:=1+(Fl And 1); If (Fl And 2)<>0 Then Bits:=16 Else Bits:=8;
 Assign(FI,Src); Old:=FileMode; FileMode:=0;
 {$I-}Reset(FI,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Begin CClose; Err:='Ouverture impossible.'; Exit; End;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); CClose; Exit; End;
 If Kind=1 Then Begin PcmHeader(H,Rate,Ch,Bits,0); BlockWrite(FO,H,44); End;
 While P+12<CSize Do Begin
  Typ:=CB(P); Sz:=LongInt(CB(P+1))*65536+B16(P+2);
  If (Typ=8) And (Sz>1) Then Begin
   Case Kind Of
    1,2: Begin CopyRange(FI,FO,P+12,Sz-1,False); Inc(DataLen,Sz-1); End;
    3: Begin
     If CB(P+12)=0 Then Begin
      B1:=CB(P+13); B2:=CB(P+14);
      Prof:=(B1 Shr 3)-1; Sfi:=((B1 And 7) Shl 1) Or (B2 Shr 7); Cfg:=(B2 Shr 3) And 15; GotAsc:=True;
     End Else If GotAsc Then Begin
      PutAdts(FO,Prof,Sfi,Cfg,Sz-2); CopyRange(FI,FO,P+13,Sz-2,False); Inc(DataLen,Sz-2);
     End;
    End;
   End;
  End;
  P:=P+11+Sz+4; Inc(Cnt);
  If (Cnt And 63)=0 Then UiTick(P,CSize);
 End;
 If Kind=1 Then PutHeaderFix(FO,Rate,Ch,Bits,DataLen);
 Close(FI); Close(FO); CClose;
 If DataLen=0 Then Begin DelFile(Dst); Err:='Aucune donn'#233'e audio trouv'#233'e.'; Exit; End;
 ExtractFlv:=True;
End;

{ MP4 / MOV / M4A / 3GP : Kind 1 WAV (PCM), 2 MP3, 3 AAC (ADTS) }
Function ExtractMp4(Const Src,Dst: String; Var Kind: Integer; Var Err: String): Boolean;
Var
 Stsd,Stsz,Stsc,Stco,Co64: LongInt; HaveAud: Boolean; Fc: String; Chs: Integer; Rt: LongInt;
 Oti,Asc0,Asc1: Integer; BigEnd: Boolean; Bits: Integer;

 Function Child(S,En: LongInt; Const Nm: String; Var Pl: LongInt): Boolean;
 Var Q,Z,H: LongInt;
 Begin
  Child:=False; Q:=S;
  While Q+8<=En Do Begin
   Z:=B32(Q); H:=8;
   If Z=1 Then Begin Z:=B32(Q+12); H:=16; End;
   If (Z<8) Then Break;
   If C4(Q+4)=Nm Then Begin Pl:=Q+H; Child:=True; Exit; End;
   Q:=Q+Z;
  End;
 End;
 Function BoxEnd(Pl: LongInt): LongInt;
 Begin
  If B32(Pl-8)=1 Then BoxEnd:=Pl-16+B32(Pl-4) Else BoxEnd:=Pl-8+B32(Pl-8);
 End;
 Function FindAud: Boolean;
 Var Mo,Tr,Md,Hd,Mi,Sb,Q,Z,H: LongInt;
 Begin
  FindAud:=False;
  If Not Child(0,CSize,'moov',Mo) Then Exit;
  Q:=Mo;
  While Q+8<=BoxEnd(Mo) Do Begin
   Z:=B32(Q); H:=8; If Z=1 Then Begin Z:=B32(Q+12); H:=16; End;
   If Z<8 Then Break;
   If C4(Q+4)='trak' Then Begin
    Tr:=Q+H;
    If Child(Tr,Q+Z,'mdia',Md) Then
     If Child(Md,BoxEnd(Md),'hdlr',Hd) Then
      If C4(Hd+8)='soun' Then
       If Child(Md,BoxEnd(Md),'minf',Mi) Then
        If Child(Mi,BoxEnd(Mi),'stbl',Sb) Then Begin
         If Child(Sb,BoxEnd(Sb),'stsd',Stsd) And Child(Sb,BoxEnd(Sb),'stsz',Stsz) And Child(Sb,BoxEnd(Sb),'stsc',Stsc) Then Begin
          If Not Child(Sb,BoxEnd(Sb),'stco',Stco) Then Stco:=0;
          If Not Child(Sb,BoxEnd(Sb),'co64',Co64) Then Co64:=0;
          If (Stco<>0) Or (Co64<>0) Then Begin FindAud:=True; Exit; End;
         End;
        End;
   End;
   Q:=Q+Z;
  End;
 End;
 Procedure Esds(S,En: LongInt);
 Var Q,Z,H: LongInt; P: LongInt; Tg: Byte; L: LongInt; K: Integer;
 Begin
  Q:=S;
  While Q+8<=En Do Begin
   Z:=B32(Q); If Z<8 Then Break;
   If C4(Q+4)='esds' Then Begin
    P:=Q+12; { apres version/flags }
    While P<Q+Z Do Begin
     Tg:=CB(P); Inc(P); L:=0;
     For K:=1 To 4 Do Begin L:=L*128+(CB(P) And $7F); Inc(P); If (CB(P-1) And $80)=0 Then Break; End;
     Case Tg Of
      3: Inc(P,3);
      4: Begin Oti:=CB(P); Inc(P,13); End;
      5: Begin Asc0:=CB(P); Asc1:=CB(P+1); Break; End;
      Else Inc(P,L);
     End;
    End;
    Exit;
   End;
   Q:=Q+Z;
  End;
 End;
Var
 FI,FO: File; Old: Byte; H: THdr; DataLen,Ent,NCh,NSc,Samples,Fixed,Off,Len,Sz,Si,C: LongInt;
 ScI,ScFirst,ScSpc,ScNext,ScNextFirst,I,K: LongInt; Prof,Sfi,Cfg,Cnt: Integer; Swap: Boolean; Tmp: LongInt;
 B1,B2: Byte;
Begin
 ExtractMp4:=False; Kind:=0; Oti:=0; Asc0:=0; Asc1:=0; Stsd:=0; Stsz:=0; Stsc:=0; Stco:=0; Co64:=0;
 If Not COpen(Src) Then Begin Err:='Ouverture impossible.'; Exit; End;
 If Not FindAud Then Begin CClose; Err:='Aucune piste audio dans ce fichier.'; Exit; End;
 Fc:=C4(Stsd+12); Chs:=B16(Stsd+8+24); Rt:=B16(Stsd+8+32); Bits:=B16(Stsd+8+26);
 Esds(Stsd+8+36,BoxEnd(Stsd));
 Swap:=False;
 If (Fc='.mp3') Or ((Fc='mp4a') And ((Oti=$6B) Or (Oti=$69))) Then Kind:=2
 Else If (Fc='mp4a') And (Oti=$40) Then Kind:=3
 Else If (Fc='sowt') Then Kind:=1
 Else If (Fc='twos') Then Begin Kind:=1; Swap:=True; End
 Else If (Fc='raw ') Then Begin Kind:=1; Bits:=8; End
 Else Begin CClose; Err:='Audio MP4 non pris en charge ('+Fc+').'; Exit; End;
 If (Kind=1) And (Bits<>8) And (Bits<>16) Then Begin CClose; Err:='PCM MP4 non pris en charge.'; Exit; End;
 If Chs<1 Then Chs:=2;
 Prof:=((Asc0 Shr 3)-1); Sfi:=((Asc0 And 7) Shl 1) Or (Asc1 Shr 7); Cfg:=(Asc1 Shr 3) And 15;
 Assign(FI,Src); Old:=FileMode; FileMode:=0;
 {$I-}Reset(FI,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Begin CClose; Err:='Ouverture impossible.'; Exit; End;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); CClose; Exit; End;
 If Kind=1 Then Begin PcmHeader(H,Rt,Chs,Bits,0); BlockWrite(FO,H,44); End;
 Fixed:=B32(Stsz+4); Samples:=B32(Stsz+8);
 If Stco<>0 Then NCh:=B32(Stco+4) Else NCh:=B32(Co64+4);
 NSc:=B32(Stsc+4);
 DataLen:=0; Si:=0; ScI:=0;
 ScFirst:=B32(Stsc+8); ScSpc:=B32(Stsc+12);
 If NSc>1 Then ScNextFirst:=B32(Stsc+8+12) Else ScNextFirst:=2147483647;
 For C:=1 To NCh Do Begin
  While (C>=ScNextFirst) And (ScI+1<NSc) Do Begin
   Inc(ScI); ScFirst:=B32(Stsc+8+ScI*12); ScSpc:=B32(Stsc+12+ScI*12);
   If ScI+1<NSc Then ScNextFirst:=B32(Stsc+8+(ScI+1)*12) Else ScNextFirst:=2147483647;
  End;
  If Stco<>0 Then Off:=B32(Stco+8+(C-1)*4) Else Off:=B32(Co64+8+(C-1)*8+4);
  If Kind=1 Then Begin
   If Fixed<>0 Then Len:=ScSpc*Fixed Else Len:=ScSpc*Chs*(Bits Div 8);
   If (Fixed<>0) And (Fixed<Chs*(Bits Div 8)) Then Len:=ScSpc*Chs*(Bits Div 8);
   If Off+Len>CSize Then Len:=CSize-Off;
   CopyRange(FI,FO,Off,Len,Swap And (Bits=16)); Inc(DataLen,Len);
  End Else Begin
   For K:=0 To ScSpc-1 Do Begin
    If Fixed<>0 Then Sz:=Fixed Else Sz:=B32(Stsz+12+(Si+K)*4);
    If (Sz<=0) Or (Off+Sz>CSize) Then Break;
    If Kind=3 Then PutAdts(FO,Prof,Sfi,Cfg,Sz);
    CopyRange(FI,FO,Off,Sz,False); Inc(DataLen,Sz); Off:=Off+Sz;
   End;
  End;
  Inc(Si,ScSpc);
  If (C And 31)=0 Then UiTick(C,NCh);
 End;
 If Kind=1 Then Begin
  If Bits=8 Then Begin
   { MOV 'raw ' = 8 bits non signes, comme WAV }
  End;
  PutHeaderFix(FO,Rt,Chs,Bits,DataLen);
 End;
 Close(FI); Close(FO); CClose;
 If DataLen=0 Then Begin DelFile(Dst); Err:='Aucune donn'#233'e audio trouv'#233'e.'; Exit; End;
 ExtractMp4:=True;
End;

{ ---------------------------------------------------------------------- }
{ Source quelconque -> WAV PCM16 canonique                                   }
{ ---------------------------------------------------------------------- }
Function DecodeKind(Kind: Integer; Const Tmp,Dst: String; Var Err: String): Boolean;
Var T2: String;
Begin
 DecodeKind:=False;
 Case Kind Of
  1: DecodeKind:=MakeCanon(Tmp,Dst,Err);
  2: Begin
   T2:=TmpName('WAV');
   If RunEng(ekMP3,Tmp,T2,0,Err) Then DecodeKind:=MakeCanon(T2,Dst,Err);
   DelFile(Tmp);
  End;
  3: Begin
   T2:=TmpName('WAV');
   If RunEng(ekAAC,Tmp,T2,0,Err) Then DecodeKind:=MakeCanon(T2,Dst,Err);
   DelFile(Tmp);
  End;
 End;
 If Not (Kind In [1,2,3]) Then Err:='Type audio inconnu.';
End;

{$IFDEF FPC}
Function ExtractMkv(Const Src,Dst: String; Var Kind: Integer; Var Err: String): Boolean; Forward;
Function DecodeFlac(Const Src,Dst: String; Var Err: String): Boolean; Forward;
{$ENDIF}

Function GetPcm(Const M: TMedia; Const Dst: String; Var Err: String): Boolean;
Var F: String; T1,T2: String; Kind: Integer; W: TWavInfo; FI,FO: File; Old: Byte;
Begin
 GetPcm:=False; Err:=''; F:=M.Fmt;
 If (F='WAV') Then Begin
  If Not ReadWavInfo(M.Path,W) Then Begin Err:='Fichier WAV invalide.'; Exit; End;
  If W.Tag=$55 Then Begin
   T1:=TmpName('MP3');
   Assign(FI,M.Path); Old:=FileMode; FileMode:=0; {$I-}Reset(FI,1);{$I+} FileMode:=Old;
   If IOResult<>0 Then Begin Err:='Ouverture impossible.'; Exit; End;
   If Not CreateOut(T1,FO,Err) Then Begin Close(FI); Exit; End;
   CopyRange(FI,FO,W.DataOfs,W.DataLen,False); Close(FI); Close(FO);
   GetPcm:=DecodeKind(2,T1,Dst,Err); Exit;
  End;
  GetPcm:=NormalizeWav(M.Path,Dst,Err);
 End
 Else If F='MP3' Then Begin
  T1:=TmpName('WAV');
  If RunEng(ekMP3,M.Path,T1,0,Err) Then GetPcm:=MakeCanon(T1,Dst,Err);
 End
 Else If (F='AIFF') Or (F='AIF') Or (F='AIFC') Then Begin
  T1:=TmpName('WAV');
  If RunEng(ekAIFF,M.Path,T1,0,Err) Then GetPcm:=MakeCanon(T1,Dst,Err);
 End
 Else If F='VOC' Then Begin
  T1:=TmpName('WAV');
  If RunEng(ekVOC,M.Path,T1,0,Err) Then GetPcm:=MakeCanon(T1,Dst,Err);
 End
 Else If F='MOD' Then Begin
  T1:=TmpName('WAV');
  If RunEng(ekMOD,M.Path,T1,0,Err) Then GetPcm:=MakeCanon(T1,Dst,Err);
 End
 {$IFDEF FPC}
 Else If F='FLAC' Then Begin
  T1:=TmpName('WAV');
  If DecodeFlac(M.Path,T1,Err) Then GetPcm:=MakeCanon(T1,Dst,Err) Else DelFile(T1);
 End
 {$ENDIF}
 Else If ExtOf(M.Path)='AAC' Then Begin
  T1:=TmpName('WAV');
  If RunEng(ekAAC,M.Path,T1,0,Err) Then GetPcm:=MakeCanon(T1,Dst,Err);
 End
 {$IFDEF FPC}
 Else If (F='MKV') Or (F='WEBM') Then Begin
  T1:=TmpName('TMP');
  If ExtractMkv(M.Path,T1,Kind,Err) Then GetPcm:=DecodeKind(Kind,T1,Dst,Err) Else DelFile(T1);
 End
 {$ENDIF}
 Else If F='AVI' Then Begin
  T1:=TmpName('TMP');
  If ExtractAvi(M.Path,T1,Kind,Err) Then GetPcm:=DecodeKind(Kind,T1,Dst,Err) Else DelFile(T1);
 End
 Else If F='FLV' Then Begin
  T1:=TmpName('TMP');
  If ExtractFlv(M.Path,T1,Kind,Err) Then GetPcm:=DecodeKind(Kind,T1,Dst,Err) Else DelFile(T1);
 End
 Else If (F='MP4') Or (F='MOV') Or (F='M4A') Or (F='3GP') Then Begin
  T1:=TmpName('TMP');
  If ExtractMp4(M.Path,T1,Kind,Err) Then GetPcm:=DecodeKind(Kind,T1,Dst,Err) Else DelFile(T1);
 End
 Else Err:='Le moteur int'#233'gr'#233' ne d'#233'code pas l''audio de ce format ('+F+').';
End;

{ ---------------------------------------------------------------------- }
{ Traitement : decoupe, volume, vitesse, retard, rythme, canaux              }
{ ---------------------------------------------------------------------- }
Function ProcessWav(Const Src,Dst: String; Var P: TAP; Var Err: String): Boolean;
Const CacheFr = 4096;
Var
 W: TWavInfo; FI,FO: File; Cache: PIntArr; CBase,CCount: LongInt; SrcFr: LongInt;
 SF,EF,Step,Pos: Double; OutRate: LongInt; OutCh,I2: Integer; Content,Dly,Total,N,Skip: LongInt;
 Out: PIntArr; OC,Wr: Integer; Gain: LongInt; FIn,FOut: LongInt; Ok: Boolean; A,B,Fr: LongInt;
 L0,R0,L1,R1,Lv,Rv: LongInt; Idx: LongInt; Wt: LongInt; Written: LongInt; Spd: Integer;
 Got: Word; Hd0: THdr;

 Procedure Fetch(Fn: LongInt; Var L,R: LongInt);
 Var Ofs: LongInt;
 Begin
  If Fn<0 Then Fn:=0; If Fn>=SrcFr Then Fn:=SrcFr-1;
  If (Fn<CBase) Or (Fn>=CBase+CCount) Then Begin
   CBase:=Fn-(Fn Mod CacheFr);
   {$I-}Seek(FI,W.DataOfs+CBase*W.Ch*2); BlockRead(FI,Cache^,CacheFr*W.Ch*2,Got);{$I+}
   If IOResult<>0 Then Got:=0;
   CCount:=Got Div (W.Ch*2);
   If CCount<=0 Then Begin L:=0; R:=0; Exit; End;
  End;
  Ofs:=(Fn-CBase)*W.Ch;
  L:=Cache^[Ofs];
  If W.Ch=2 Then R:=Cache^[Ofs+1] Else R:=L;
 End;
Begin
 ProcessWav:=False;
 If Not OpenWavIn(Src,FI,W,Err) Then Exit;
 If (W.Tag<>1) Or (W.Bits<>16) Or (W.Ch<1) Or (W.Ch>2) Then Begin Close(FI); Err:='WAV canonique requis.'; Exit; End;
 SrcFr:=W.DataLen Div (W.Ch*2);
 If SrcFr<1 Then Begin Close(FI); Err:='Aucune donn'#233'e audio.'; Exit; End;
 OutRate:=P.OutRate; If OutRate<=0 Then OutRate:=W.Rate;
 OutCh:=P.OutCh; If (OutCh<1) Or (OutCh>2) Then OutCh:=W.Ch;
 Spd:=P.Speed; If Spd<=0 Then Spd:=100;
 SF:=(P.StartMs/1000.0)*W.Rate; EF:=SrcFr;
 If (P.EndMs>0) And ((P.EndMs/1000.0)*W.Rate<EF) Then EF:=(P.EndMs/1000.0)*W.Rate;
 If SF>=EF-1 Then SF:=0;
 Step:=(W.Rate/OutRate)*(Spd/100.0);
 Content:=Trunc((EF-SF)/Step);
 If Content<1 Then Content:=1;
 Dly:=Round((P.DelayMs/1000.0)*OutRate);
 Skip:=0; If Dly<0 Then Begin Skip:=-Dly; Dly:=0; If Skip>=Content Then Skip:=Content-1; End;
 Total:=Content-Skip+Dly;
 Gain:=(P.Vol*256) Div 100;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); Exit; End;
 New(Cache); New(Out);
 CBase:=-1; CCount:=0;
 PcmHeader(Hd0,OutRate,OutCh,16,0); BlockWrite(FO,Hd0,44);
 N:=0; Wr:=0; Written:=0; Ok:=True; OC:=OutCh;
 While (N<Total) And Ok Do Begin
  If N<Dly Then Begin Lv:=0; Rv:=0; End Else Begin
   Fr:=N-Dly+Skip;
   If P.Rev Then Pos:=EF-1-Fr*Step Else Pos:=SF+Fr*Step;
   If Pos<0 Then Pos:=0;
   Idx:=Trunc(Pos); Wt:=Trunc((Pos-Idx)*256);
   Fetch(Idx,L0,R0);
   If Wt>0 Then Begin
    If P.Rev Then Fetch(Idx-1,L1,R1) Else Fetch(Idx+1,L1,R1);
    Lv:=L0+(((L1-L0)*Wt) Div 256); Rv:=R0+(((R1-R0)*Wt) Div 256);
   End Else Begin Lv:=L0; Rv:=R0; End;
   If (OutCh=1) And (W.Ch=2) Then Begin Lv:=(Lv+Rv) Div 2; Rv:=Lv; End;
   Lv:=Sar8(Lv*Gain); Rv:=Sar8(Rv*Gain);
   { fondus }
   Fr:=N-Dly;
   If (P.FadeIn>0) Then Begin
    A:=(P.FadeIn*OutRate) Div 1000;
    If (A>0) And (Fr<A) Then Begin Lv:=(Lv*Fr) Div A; Rv:=(Rv*Fr) Div A; End;
   End;
   If (P.FadeOut>0) Then Begin
    A:=(P.FadeOut*OutRate) Div 1000;
    B:=Total-N;
    If (A>0) And (B<A) Then Begin Lv:=(Lv*B) Div A; Rv:=(Rv*B) Div A; End;
   End;
   If Lv>32767 Then Lv:=32767; If Lv<-32768 Then Lv:=-32768;
   If Rv>32767 Then Rv:=32767; If Rv<-32768 Then Rv:=-32768;
  End;
  Out^[Wr]:=Lv; Inc(Wr);
  If OC=2 Then Begin Out^[Wr]:=Rv; Inc(Wr); End;
  If Wr>=16380 Then Begin
   BlockWrite(FO,Out^,Wr*2); Inc(Written,Wr*2); Wr:=0;
   UiTick(N,Total);
   If Stopped Then Ok:=False;
  End;
  Inc(N);
 End;
 If Wr>0 Then Begin BlockWrite(FO,Out^,Wr*2); Inc(Written,Wr*2); End;
 Dispose(Cache); Dispose(Out);
 If Ok Then PutHeaderFix(FO,OutRate,OutCh,16,Written);
 Close(FI); Close(FO);
 If Not Ok Then Begin DelFile(Dst); Err:='Conversion annul'#233'e.'; Exit; End;
 ProcessWav:=True;
End;

{ ---------------------------------------------------------------------- }
{ Ecriture des formats de sortie a partir du WAV canonique                  }
{ ---------------------------------------------------------------------- }
Procedure BE32P(Var B: THdr; At: Integer; V: LongInt);
Begin
 B[At]:=(V Shr 24) And 255; B[At+1]:=(V Shr 16) And 255; B[At+2]:=(V Shr 8) And 255; B[At+3]:=V And 255;
End;

Function OutPcm8(Const Src,Dst: String; Var Err: String): Boolean;
Var W: TWavInfo; FI,FO: File; Buf: PIntArr; O: PByteArr; Got: Word; I: Integer; Tot,Rem: LongInt; Hd0: THdr;
Begin
 OutPcm8:=False;
 If Not OpenWavIn(Src,FI,W,Err) Then Exit;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); Exit; End;
 New(Buf); New(O); Tot:=0; Rem:=W.DataLen;
 PcmHeader(Hd0,W.Rate,W.Ch,8,0); BlockWrite(FO,Hd0,44);
 While Rem>0 Do Begin
  BlockRead(FI,Buf^,32768,Got); If Got=0 Then Break;
  If Got>Rem Then Got:=Rem;
  For I:=0 To (Got Div 2)-1 Do O^[I]:=(Buf^[I] Div 256)+128;
  BlockWrite(FO,O^,Got Div 2); Inc(Tot,Got Div 2); Dec(Rem,Got);
 End;
 PutHeaderFix(FO,W.Rate,W.Ch,8,Tot);
 Dispose(Buf); Dispose(O); Close(FI); Close(FO);
 OutPcm8:=True;
End;

Function OutIma(Const Src,Dst: String; Var Err: String): Boolean;
Const Align = 1024;
Var
 W: TWavInfo; FI,FO: File; H: THdr; Spb,Fr,I,C,K,Blocks: Integer; Smp: Array[0..1,0..2047] Of Integer;
 Pred,Idx: Array[0..1] Of LongInt; Buf: PIntArr; Blk: Array[0..Align-1] Of Byte; Got: Word; Total,Frames,Read: LongInt;
 B0,G,Code: Integer; Nib: Array[0..7] Of Integer; Pr,Ix,Step,Diff,T,S,Sign: LongInt; Tot: LongInt;
Begin
 OutIma:=False;
 If Not OpenWavIn(Src,FI,W,Err) Then Exit;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); Exit; End;
 Spb:=((Align-4*W.Ch) Div (4*W.Ch))*8+1;
 Frames:=W.DataLen Div (W.Ch*2); Blocks:=(Frames+Spb-1) Div Spb;
 FillChar(H,SizeOf(H),0);
 T4(H,0,'RIFF'); P32(H,4,0); T4(H,8,'WAVE'); T4(H,12,'fmt '); P32(H,16,20);
 P16(H,20,$11); P16(H,22,W.Ch); P32(H,24,W.Rate); P32(H,28,(W.Rate*Align) Div Spb);
 P16(H,32,Align*1); P16(H,34,4); P16(H,36,2); P16(H,38,Spb);
 T4(H,40,'fact'); P32(H,44,4); P32(H,48,Frames); T4(H,52,'data'); P32(H,56,Blocks*Align);
 BlockWrite(FO,H,60);
 New(Buf); Pred[0]:=0; Pred[1]:=0; Idx[0]:=0; Idx[1]:=0; Tot:=0;
 For K:=0 To Blocks-1 Do Begin
  FillChar(Smp,SizeOf(Smp),0);
  BlockRead(FI,Buf^,Spb*W.Ch*2,Got); Fr:=Got Div (W.Ch*2);
  For I:=0 To Fr-1 Do For C:=0 To W.Ch-1 Do Smp[C,I]:=Buf^[I*W.Ch+C];
  FillChar(Blk,SizeOf(Blk),0);
  For C:=0 To W.Ch-1 Do Begin
   Pred[C]:=Smp[C,0];
   Blk[C*4]:=Pred[C] And 255; Blk[C*4+1]:=(Pred[C] Shr 8) And 255; Blk[C*4+2]:=Idx[C];
  End;
  For I:=1 To Spb-1 Do For C:=0 To W.Ch-1 Do Begin
   Pr:=Pred[C]; Ix:=Idx[C]; Step:=ADPCMStepTable[Ix];
   Diff:=Smp[C,I]-Pr; Sign:=0; If Diff<0 Then Begin Sign:=8; Diff:=-Diff; End;
   Code:=0; T:=Step;
   If Diff>=T Then Begin Code:=4; Dec(Diff,T); End; T:=T Shr 1;
   If Diff>=T Then Begin Code:=Code Or 2; Dec(Diff,T); End; T:=T Shr 1;
   If Diff>=T Then Code:=Code Or 1;
   Code:=Code Or Sign;
   Pred[C]:=Pr; Idx[C]:=Ix;
   S:=ImaDecode(Pred[C],Idx[C],Code);
   { position : groupe de 8 echantillons par canal }
   G:=(I-1) Div 8; B0:=W.Ch*4+(G*W.Ch+C)*4+((I-1) Mod 8) Div 2;
   If ((I-1) And 1)=0 Then Blk[B0]:=Blk[B0] Or Code Else Blk[B0]:=Blk[B0] Or (Code Shl 4);
  End;
  BlockWrite(FO,Blk,Align); Inc(Tot,Align);
  If (K And 15)=0 Then UiTick(K,Blocks);
 End;
 Seek(FO,4); Total:=Tot+52; BlockWrite(FO,Total,4);
 Dispose(Buf); Close(FI); Close(FO);
 OutIma:=True;
End;

Function OutAiff(Const Src,Dst: String; Var Err: String): Boolean;
Var W: TWavInfo; FI,FO: File; H: THdr; Buf: PIntArr; O: PByteArr; Got: Word; I: Integer; Rem,Tot,E2: LongInt; R: LongInt;
Begin
 OutAiff:=False;
 If Not OpenWavIn(Src,FI,W,Err) Then Exit;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); Exit; End;
 FillChar(H,SizeOf(H),0);
 T4(H,0,'FORM'); BE32P(H,4,0); T4(H,8,'AIFF'); T4(H,12,'COMM'); BE32P(H,16,18);
 H[20]:=0; H[21]:=W.Ch; BE32P(H,22,W.DataLen Div (2*W.Ch)); H[26]:=0; H[27]:=16;
 R:=W.Rate; E2:=0; While (R Shr (E2+1))>0 Do Inc(E2);
 H[28]:=((16383+E2) Shr 8) And $7F; H[29]:=(16383+E2) And 255;
 BE32P(H,30,W.Rate Shl (31-E2));
 T4(H,38,'SSND'); BE32P(H,42,W.DataLen+8); BE32P(H,46,0); BE32P(H,50,0);
 BlockWrite(FO,H,54);
 New(Buf); New(O); Rem:=W.DataLen; Tot:=0;
 While Rem>0 Do Begin
  BlockRead(FI,Buf^,32768,Got); If Got=0 Then Break;
  If Got>Rem Then Got:=Rem;
  For I:=0 To (Got Div 2)-1 Do Begin O^[I*2]:=(Buf^[I] Shr 8) And 255; O^[I*2+1]:=Buf^[I] And 255; End;
  BlockWrite(FO,O^,Got); Inc(Tot,Got); Dec(Rem,Got);
 End;
 If Odd(Tot) Then Begin I:=0; BlockWrite(FO,I,1); End;
 Seek(FO,4); BE32P(H,0,Tot+46);
 BlockWrite(FO,H,4);
 Dispose(Buf); Dispose(O); Close(FI); Close(FO);
 OutAiff:=True;
End;

Function OutAu(Const Src,Dst: String; Var Err: String): Boolean;
Var W: TWavInfo; FI,FO: File; H: THdr; Buf: PIntArr; O: PByteArr; Got: Word; I: Integer; Rem: LongInt;
Begin
 OutAu:=False;
 If Not OpenWavIn(Src,FI,W,Err) Then Exit;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); Exit; End;
 FillChar(H,SizeOf(H),0);
 T4(H,0,'.snd'); BE32P(H,4,24); BE32P(H,8,W.DataLen); BE32P(H,12,3); BE32P(H,16,W.Rate); BE32P(H,20,W.Ch);
 BlockWrite(FO,H,24);
 New(Buf); New(O); Rem:=W.DataLen;
 While Rem>0 Do Begin
  BlockRead(FI,Buf^,32768,Got); If Got=0 Then Break;
  If Got>Rem Then Got:=Rem;
  For I:=0 To (Got Div 2)-1 Do Begin O^[I*2]:=(Buf^[I] Shr 8) And 255; O^[I*2+1]:=Buf^[I] And 255; End;
  BlockWrite(FO,O^,Got); Dec(Rem,Got);
 End;
 Dispose(Buf); Dispose(O); Close(FI); Close(FO);
 OutAu:=True;
End;

Function CopyFileTo(Const Src,Dst: String; Var Err: String): Boolean;
Var FI,FO: File; Old: Byte;
Begin
 CopyFileTo:=False;
 Assign(FI,Src); Old:=FileMode; FileMode:=0;
 {$I-}Reset(FI,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Begin Err:='Ouverture impossible: '+Src; Exit; End;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); Exit; End;
 CopyRange(FI,FO,0,FileSize(FI),False);
 Close(FI); Close(FO);
 CopyFileTo:=True;
End;

Function NearBitrate(K: Integer): Integer;
Const T: Array[0..13] Of Integer = (32,40,48,56,64,80,96,112,128,160,192,224,256,320);
Var I,B: Integer;
Begin
 B:=T[0];
 For I:=0 To 13 Do If Abs(T[I]-K)<Abs(B-K) Then B:=T[I];
 NearBitrate:=B;
End;

{$IFDEF FPC}
Function WriteAacOut(Const Canon,Dst: String; Const Pr: TProf; Var Err: String): Boolean; Forward;
{$ENDIF}

{ Ecrit le fichier final selon l'extension du profil }
Function WriteFinal(Const Canon,Dst: String; Const Pr: TProf; Var Err: String): Boolean;
Var Ext: String; T: String;
Begin
 WriteFinal:=False; Ext:=Pr.Ext; Err:='';
 If Ext='WAV' Then Begin
  If Pr.AC='PCM8' Then WriteFinal:=OutPcm8(Canon,Dst,Err)
  Else If Pr.AC='ADPCM' Then WriteFinal:=OutIma(Canon,Dst,Err)
  Else WriteFinal:=CopyFileTo(Canon,Dst,Err);
 End
 Else If Ext='AIF' Then WriteFinal:=OutAiff(Canon,Dst,Err)
 Else If Ext='AU' Then WriteFinal:=OutAu(Canon,Dst,Err)
 Else If Ext='MP3' Then Begin
  WriteFinal:=RunEng(ekEncMP3,Canon,Dst,NearBitrate(Pr.AKb),Err);
 End
 {$IFDEF FPC}
 Else If (Ext='M4A') Or (Ext='AAC') Then WriteFinal:=WriteAacOut(Canon,Dst,Pr,Err)
 {$ENDIF}
 Else Err:='Format audio de sortie non pris en charge: '+Ext;
End;

{ ====================================================================== }
{ Images : BMP, GIF (anime), transformations, ecriture GIF/BMP             }
{ ====================================================================== }
Const
 MaxAnim = 48;

Type
 TPixArr = Array[0..0] Of Byte;
 PPixArr = ^TPixArr;
 TImg = Record
  W,H: LongInt;
  P: PPixArr;
 End;
 PImg = ^TImg;
 TAnim = Record
  N: Integer;
  F: Array[1..MaxAnim] Of PImg;
  Dly: Array[1..MaxAnim] Of Integer;
 End;
 PAnim = ^TAnim;

Function ImgNew(W,H: LongInt): PImg;
Var I: PImg;
Begin
 ImgNew:=Nil;
 If (W<1) Or (H<1) Or (W*H>16000000) Then Exit;
 New(I); I^.W:=W; I^.H:=H;
 GetMem(I^.P,W*H*3);
 FillChar(I^.P^,W*H*3,255);
 ImgNew:=I;
End;

Procedure ImgFree(Var I: PImg);
Begin
 If I=Nil Then Exit;
 FreeMem(I^.P,I^.W*I^.H*3); Dispose(I); I:=Nil;
End;

Procedure AnimFree(Var A: PAnim);
Var K: Integer;
Begin
 If A=Nil Then Exit;
 For K:=1 To A^.N Do ImgFree(A^.F[K]);
 Dispose(A); A:=Nil;
End;

Function ImgCopy(S: PImg): PImg;
Var D: PImg;
Begin
 D:=ImgNew(S^.W,S^.H);
 If D<>Nil Then Move(S^.P^,D^.P^,S^.W*S^.H*3);
 ImgCopy:=D;
End;

Procedure PutPx(I: PImg; X,Y: LongInt; R,G,B: Byte);
Var O: LongInt;
Begin
 If (X<0) Or (Y<0) Or (X>=I^.W) Or (Y>=I^.H) Then Exit;
 O:=(Y*I^.W+X)*3; I^.P^[O]:=R; I^.P^[O+1]:=G; I^.P^[O+2]:=B;
End;

{ Lecture complete d'un fichier en memoire }
Function ReadAll(Const Path: String; Var Buf: PPixArr; Var Size: LongInt): Boolean;
Var F: File; Old: Byte; N: LongInt; Got: Word; P: LongInt;
Begin
 ReadAll:=False; Buf:=Nil; Size:=0;
 Assign(F,Path); Old:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Exit;
 N:=FileSize(F);
 If (N<1) Or (N>48000000) Then Begin Close(F); Exit; End;
 GetMem(Buf,N+8); P:=0;
 While P<N Do Begin
  BlockRead(F,Buf^[P],Min(32768,N-P),Got);
  If Got=0 Then Break;
  Inc(P,Got);
 End;
 Close(F); Size:=N; ReadAll:=True;
End;

Function RdL(B: PPixArr; O: LongInt; N: Integer): LongInt;
Var V: LongInt; K: Integer;
Begin
 V:=0;
 For K:=N-1 DownTo 0 Do V:=V*256+B^[O+K];
 RdL:=V;
End;

{ ---- BMP ---- }
Function LoadBmp(Const Path: String): PImg;
Var B: PPixArr; Sz,Off,Dib,W,H,Bpp,Comp,Ncol,Stride,Y,X,RowO,Pal,O: LongInt; Img: PImg; TopDown: Boolean;
 Pr,Pg,Pb: Array[0..255] Of Byte; K,V,Idx: LongInt; Rr,Gg,Bb: Byte;
Begin
 LoadBmp:=Nil;
 If Not ReadAll(Path,B,Sz) Then Exit;
 If (Sz<54) Or (B^[0]<>66) Or (B^[1]<>77) Then Begin FreeMem(B,Sz+8); Exit; End;
 Off:=RdL(B,10,4); Dib:=RdL(B,14,4); W:=RdL(B,18,4); H:=RdL(B,22,4);
 TopDown:=H<0; If H<0 Then H:=-H;
 Bpp:=RdL(B,28,2); Comp:=RdL(B,30,4); Ncol:=RdL(B,46,4);
 If (Comp<>0) And (Comp<>3) Then Begin FreeMem(B,Sz+8); Exit; End;
 If (Bpp<=8) And (Ncol=0) Then Ncol:=1 Shl Bpp;
 Pal:=14+Dib;
 For K:=0 To Ncol-1 Do If (K<256) And (Pal+K*4+3<Sz) Then Begin Pb[K]:=B^[Pal+K*4]; Pg[K]:=B^[Pal+K*4+1]; Pr[K]:=B^[Pal+K*4+2]; End;
 Img:=ImgNew(W,H);
 If Img=Nil Then Begin FreeMem(B,Sz+8); Exit; End;
 Stride:=((W*Bpp+31) Div 32)*4;
 For Y:=0 To H-1 Do Begin
  If TopDown Then RowO:=Off+Y*Stride Else RowO:=Off+(H-1-Y)*Stride;
  If RowO+Stride>Sz Then Break;
  For X:=0 To W-1 Do Begin
   Case Bpp Of
    1: Begin Idx:=(B^[RowO+X Shr 3] Shr (7-(X And 7))) And 1; Rr:=Pr[Idx]; Gg:=Pg[Idx]; Bb:=Pb[Idx]; End;
    4: Begin If (X And 1)=0 Then Idx:=B^[RowO+X Shr 1] Shr 4 Else Idx:=B^[RowO+X Shr 1] And 15; Rr:=Pr[Idx]; Gg:=Pg[Idx]; Bb:=Pb[Idx]; End;
    8: Begin Idx:=B^[RowO+X]; Rr:=Pr[Idx]; Gg:=Pg[Idx]; Bb:=Pb[Idx]; End;
    16: Begin V:=B^[RowO+X*2]+B^[RowO+X*2+1]*256; Rr:=((V Shr 10) And 31)*255 Div 31; Gg:=((V Shr 5) And 31)*255 Div 31; Bb:=(V And 31)*255 Div 31; End;
    24,32: Begin O:=RowO+X*(Bpp Div 8); Bb:=B^[O]; Gg:=B^[O+1]; Rr:=B^[O+2]; End;
    Else Begin Rr:=0; Gg:=0; Bb:=0; End;
   End;
   PutPx(Img,X,Y,Rr,Gg,Bb);
  End;
 End;
 FreeMem(B,Sz+8);
 LoadBmp:=Img;
End;

Function SaveBmp(Const Path: String; I: PImg): Boolean;
Var F: File; H: THdr; Stride,Y,X,Pad,Sz: LongInt; Row: PByteArr; Err: String;
Begin
 SaveBmp:=False;
 Stride:=((I^.W*24+31) Div 32)*4; Sz:=Stride*I^.H;
 If Stride>32768 Then Exit;
 If Not CreateOut(Path,F,Err) Then Exit;
 FillChar(H,SizeOf(H),0);
 H[0]:=66; H[1]:=77; P32(H,2,54+Sz); P32(H,10,54); P32(H,14,40); P32(H,18,I^.W); P32(H,22,I^.H);
 P16(H,26,1); P16(H,28,24); P32(H,34,Sz);
 BlockWrite(F,H,54);
 New(Row);
 For Y:=I^.H-1 DownTo 0 Do Begin
  FillChar(Row^,Stride,0);
  For X:=0 To I^.W-1 Do Begin
   Row^[X*3]:=I^.P^[(Y*I^.W+X)*3+2]; Row^[X*3+1]:=I^.P^[(Y*I^.W+X)*3+1]; Row^[X*3+2]:=I^.P^[(Y*I^.W+X)*3];
  End;
  BlockWrite(F,Row^,Stride);
 End;
 Dispose(Row); Close(F);
 SaveBmp:=True;
End;

{ ---- GIF : decodage ---- }
Function LoadGif(Const Path: String; Var A: PAnim; MaxFr: Integer): Boolean;
Var
 B: PPixArr; Sz,P,GW,GH,Ci: LongInt; Fl: Byte; Gct: Array[0..767] Of Byte; Lct: Array[0..767] Of Byte;
 Pal: Array[0..767] Of Byte; NG: Integer; Cv,Prev: PImg; Tr,Disp,Bg: Integer; Dl: Integer;
 FX,FY,FW,FH,LFl,Mn: LongInt; Il: Boolean; Data: PPixArr; DLen,Q: LongInt; Idx: PPixArr;
 Pref: Array[0..4095] Of Word; Suf: Array[0..4095] Of Byte; Stk: Array[0..4096] Of Byte;
 Sp,CSz,Clear,Eoi,Nxt,Old,Cur,InCode,First,BitsN,Acc,Code,Mask: LongInt; Pix,Tot,Y,X,Row,Pass: LongInt;
 Done: Boolean; K,N2,L: Integer; HavePrev: Boolean; Lt: Boolean; R,G,Bl: Byte;
 PrevDisp: Integer; PrevX,PrevY,PrevW,PrevH: LongInt;
Begin
 LoadGif:=False; A:=Nil;
 If Not ReadAll(Path,B,Sz) Then Exit;
 If (Sz<14) Or (B^[0]<>71) Or (B^[1]<>73) Then Begin FreeMem(B,Sz+8); Exit; End;
 GW:=RdL(B,6,2); GH:=RdL(B,8,2); Fl:=B^[10]; Bg:=B^[11]; P:=13; NG:=0;
 If (Fl And $80)<>0 Then Begin NG:=1 Shl ((Fl And 7)+1); Move(B^[P],Gct,NG*3); Inc(P,NG*3); End;
 Cv:=ImgNew(GW,GH); Prev:=Nil;
 If Cv=Nil Then Begin FreeMem(B,Sz+8); Exit; End;
 New(A); A^.N:=0; Tr:=-1; Disp:=0; Dl:=10; PrevDisp:=0; PrevX:=0; PrevY:=0; PrevW:=0; PrevH:=0;
 GetMem(Data,Sz+8); GetMem(Idx,GW*GH+8);
 Done:=False;
 While (P<Sz) And Not Done And (A^.N<MaxFr) Do Begin
  Case B^[P] Of
   $3B: Done:=True;
   $21: Begin
    If (B^[P+1]=$F9) And (B^[P+2]>=4) Then Begin
     Disp:=(B^[P+3] Shr 2) And 7; If (B^[P+3] And 1)<>0 Then Tr:=B^[P+6] Else Tr:=-1;
     Dl:=RdL(B,P+4,2); If Dl<2 Then Dl:=10;
    End;
    Inc(P,2);
    While (P<Sz) And (B^[P]<>0) Do P:=P+B^[P]+1;
    Inc(P);
   End;
   $2C: Begin
    FX:=RdL(B,P+1,2); FY:=RdL(B,P+3,2); FW:=RdL(B,P+5,2); FH:=RdL(B,P+7,2); LFl:=B^[P+9]; Inc(P,10);
    Il:=(LFl And $40)<>0;
    If (LFl And $80)<>0 Then Begin L:=1 Shl ((LFl And 7)+1); Move(B^[P],Lct,L*3); Inc(P,L*3); Move(Lct,Pal,L*3); End
    Else Move(Gct,Pal,768);
    Mn:=B^[P]; Inc(P);
    DLen:=0;
    While (P<Sz) And (B^[P]<>0) Do Begin L:=B^[P]; Move(B^[P+1],Data^[DLen],L); Inc(DLen,L); P:=P+L+1; End;
    Inc(P);
    { efface la zone du bloc precedent selon son mode de disposition }
    If (PrevDisp=2) Then Begin
     For Y:=PrevY To PrevY+PrevH-1 Do For X:=PrevX To PrevX+PrevW-1 Do PutPx(Cv,X,Y,255,255,255);
    End Else If (PrevDisp=3) And (Prev<>Nil) Then Move(Prev^.P^,Cv^.P^,GW*GH*3);
    If Disp=3 Then Begin ImgFree(Prev); Prev:=ImgCopy(Cv); End;
    { LZW }
    CSz:=Mn+1; Clear:=1 Shl Mn; Eoi:=Clear+1; Nxt:=Eoi+1; Old:=-1; BitsN:=0; Acc:=0; Q:=0; Pix:=0; Tot:=FW*FH; Sp:=0;
    Mask:=(1 Shl CSz)-1; FillChar(Idx^,GW*GH,0);
    For K:=0 To Clear-1 Do Begin Pref[K]:=0; Suf[K]:=K; End;
    While Pix<Tot Do Begin
     While (BitsN<CSz) And (Q<DLen) Do Begin Acc:=Acc Or (LongInt(Data^[Q]) Shl BitsN); Inc(BitsN,8); Inc(Q); End;
     If BitsN<CSz Then Break;
     Code:=Acc And Mask; Acc:=Acc Shr CSz; Dec(BitsN,CSz);
     If Code=Clear Then Begin CSz:=Mn+1; Mask:=(1 Shl CSz)-1; Nxt:=Eoi+1; Old:=-1; Continue; End;
     If Code=Eoi Then Break;
     If Old=-1 Then Begin
      If Code<Clear Then Begin Stk[0]:=Suf[Code]; Sp:=1; First:=Suf[Code]; End Else Break;
      Old:=Code;
     End Else Begin
      InCode:=Code; Sp:=0;
      If Code>=Nxt Then Begin Stk[Sp]:=First; Inc(Sp); Code:=Old; End;
      While Code>=Clear Do Begin Stk[Sp]:=Suf[Code]; Inc(Sp); Code:=Pref[Code]; If Sp>4090 Then Break; End;
      First:=Suf[Code]; Stk[Sp]:=First; Inc(Sp);
      If Nxt<4096 Then Begin Pref[Nxt]:=Old; Suf[Nxt]:=First; Inc(Nxt); If (Nxt>Mask) And (CSz<12) Then Begin Inc(CSz); Mask:=(1 Shl CSz)-1; End; End;
      Old:=InCode;
     End;
     While Sp>0 Do Begin
      Dec(Sp);
      If Pix<Tot Then Begin
       Y:=Pix Div FW; X:=Pix Mod FW;
       If Il Then Begin
        { entrelacement : passes 0..3 }
        If Y<(FH+7) Div 8 Then Row:=Y*8
        Else If Y<(FH+7) Div 8+(FH+3) Div 8 Then Row:=(Y-(FH+7) Div 8)*8+4
        Else If Y<(FH+7) Div 8+(FH+3) Div 8+(FH+1) Div 4 Then Row:=(Y-(FH+7) Div 8-(FH+3) Div 8)*4+2
        Else Row:=(Y-(FH+7) Div 8-(FH+3) Div 8-(FH+1) Div 4)*2+1;
       End Else Row:=Y;
       If (Row<FH) And (FX+X<GW) And (FY+Row<GH) Then Begin
        Ci:=Stk[Sp];
        If Ci<>Tr Then PutPx(Cv,FX+X,FY+Row,Pal[Ci*3],Pal[Ci*3+1],Pal[Ci*3+2]);
       End;
      End;
      Inc(Pix);
     End;
    End;
    Inc(A^.N); A^.F[A^.N]:=ImgCopy(Cv); A^.Dly[A^.N]:=Dl;
    PrevDisp:=Disp; PrevX:=FX; PrevY:=FY; PrevW:=FW; PrevH:=FH; Disp:=0; Tr:=-1;
   End;
   Else Done:=True;
  End;
 End;
 FreeMem(Data,Sz+8); FreeMem(Idx,GW*GH+8); FreeMem(B,Sz+8); ImgFree(Cv); ImgFree(Prev);
 If A^.N=0 Then Begin Dispose(A); A:=Nil; Exit; End;
 LoadGif:=True;
End;

{ ---- GIF : ecriture ---- }
Type
 TColsArr = Array[0..32767] Of LongInt;
 PColsArr = ^TColsArr;
 THist = Array[0..32767] Of LongInt;
 PHist = ^THist;
 TLut = Array[0..32767] Of Byte;
 PLut = ^TLut;
 TBox = Record Lo,Hi: LongInt; Axis: Integer; End;

Var
 GifPal: Array[0..255,0..2] Of Byte;
 GifLut: PLut;

Procedure BuildPalette(A: PAnim);
Var H: PHist; K,Y,X,N,Cn,I,J,Best,Ax,Mid,Cnt,Tot,Acc,Rm,Gm,Bm,T,W: LongInt; Cols,Tmp2: PColsArr; Cnt32,Pos32: Array[0..31] Of LongInt;
 Boxes: Array[0..255] Of TBox; NB: Integer; Mn,Mx: Array[0..2] Of Integer; Rg,Gg,Bg: LongInt; C: Integer; Sorted: Boolean;
 Dist,Bd: LongInt; Rr,Gr,Br: LongInt;
Begin
 New(H); FillChar(H^,SizeOf(H^),0);
 For K:=1 To A^.N Do Begin
  N:=A^.F[K]^.W*A^.F[K]^.H;
  I:=0; T:=1+N Div 20000;
  While I<N Do Begin
   Rr:=A^.F[K]^.P^[I*3] Shr 3; Gr:=A^.F[K]^.P^[I*3+1] Shr 3; Br:=A^.F[K]^.P^[I*3+2] Shr 3;
   Inc(H^[(Rr Shl 10) Or (Gr Shl 5) Or Br]);
   Inc(I,T);
  End;
 End;
 { liste des couleurs presentes, triees par blocs (median cut) }
 GetMem(Cols,32768*4); GetMem(Tmp2,32768*4); Cn:=0;
 For I:=0 To 32767 Do If H^[I]>0 Then Begin Cols^[Cn]:=I; Inc(Cn); End;
 NB:=1; Boxes[0].Lo:=0; Boxes[0].Hi:=Cn-1;
 If Cn=0 Then Begin Boxes[0].Hi:=-1; End;
 While (NB<256) Do Begin
  { choisit la boite la plus peuplee a plusieurs couleurs }
  Best:=-1; Bd:=0;
  For I:=0 To NB-1 Do If (Boxes[I].Hi>Boxes[I].Lo) Then Begin
   Tot:=0; For J:=Boxes[I].Lo To Boxes[I].Hi Do Inc(Tot,H^[Cols^[J]]);
   If Tot>Bd Then Begin Bd:=Tot; Best:=I; End;
  End;
  If Best<0 Then Break;
  { axe de plus grande amplitude }
  For C:=0 To 2 Do Begin Mn[C]:=31; Mx[C]:=0; End;
  For J:=Boxes[Best].Lo To Boxes[Best].Hi Do Begin
   T:=Cols^[J];
   For C:=0 To 2 Do Begin
    W:=(T Shr ((2-C)*5)) And 31;
    If W<Mn[C] Then Mn[C]:=W; If W>Mx[C] Then Mx[C]:=W;
   End;
  End;
  Ax:=0;
  For C:=1 To 2 Do If (Mx[C]-Mn[C])*(1+Ord(C=1)) > (Mx[Ax]-Mn[Ax])*(1+Ord(Ax=1)) Then Ax:=C;
  { tri par comptage selon l'axe choisi }
  FillChar(Cnt32,SizeOf(Cnt32),0);
  For J:=Boxes[Best].Lo To Boxes[Best].Hi Do Inc(Cnt32[(Cols^[J] Shr ((2-Ax)*5)) And 31]);
  T:=0; For I:=0 To 31 Do Begin Pos32[I]:=T; Inc(T,Cnt32[I]); End;
  For J:=Boxes[Best].Lo To Boxes[Best].Hi Do Begin
   C:=(Cols^[J] Shr ((2-Ax)*5)) And 31;
   Tmp2^[Boxes[Best].Lo+Pos32[C]]:=Cols^[J]; Inc(Pos32[C]);
  End;
  For J:=Boxes[Best].Lo To Boxes[Best].Hi Do Cols^[J]:=Tmp2^[J];
  Tot:=0; For J:=Boxes[Best].Lo To Boxes[Best].Hi Do Inc(Tot,H^[Cols^[J]]);
  Acc:=0; Mid:=Boxes[Best].Lo;
  For J:=Boxes[Best].Lo To Boxes[Best].Hi-1 Do Begin Inc(Acc,H^[Cols^[J]]); Mid:=J; If Acc*2>=Tot Then Break; End;
  Boxes[NB].Lo:=Mid+1; Boxes[NB].Hi:=Boxes[Best].Hi; Boxes[Best].Hi:=Mid; Inc(NB);
 End;
 FillChar(GifPal,SizeOf(GifPal),0);
 For I:=0 To NB-1 Do Begin
  Rm:=0; Gm:=0; Bm:=0; Tot:=0;
  For J:=Boxes[I].Lo To Boxes[I].Hi Do Begin
   T:=Cols^[J]; W:=H^[T];
   Rm:=Rm+((T Shr 10) And 31)*W; Gm:=Gm+((T Shr 5) And 31)*W; Bm:=Bm+(T And 31)*W; Inc(Tot,W);
  End;
  If Tot>0 Then Begin
   GifPal[I,0]:=Min(255,(Rm*8 Div Tot)+4); GifPal[I,1]:=Min(255,(Gm*8 Div Tot)+4); GifPal[I,2]:=Min(255,(Bm*8 Div Tot)+4);
  End;
 End;
 FreeMem(Cols,32768*4); FreeMem(Tmp2,32768*4);
 { table de correspondance 5-5-5 }
 If GifLut=Nil Then New(GifLut);
 For I:=0 To 32767 Do Begin
  Rr:=((I Shr 10) And 31)*8+4; Gr:=((I Shr 5) And 31)*8+4; Br:=(I And 31)*8+4;
  Bd:=2000000000; Best:=0;
  For J:=0 To 255 Do Begin
   Dist:=Sqr(Rr-GifPal[J,0])*3+Sqr(Gr-GifPal[J,1])*4+Sqr(Br-GifPal[J,2])*2;
   If Dist<Bd Then Begin Bd:=Dist; Best:=J; If Dist=0 Then Break; End;
  End;
  GifLut^[I]:=Best;
 End;
 Dispose(H);
End;

Function SaveGif(Const Path: String; A: PAnim; Loop: Boolean): Boolean;
Var
 F: File; H: THdr; W,Hh,K,I,N,X,Y: LongInt; Err: String; Idx: PPixArr; Buf: Array[0..259] Of Byte;
 Out: PByteArr; OutN: LongInt;
 HKey: Array[0..8191] Of LongInt; HVal: Array[0..8191] Of Word; Nxt,CSz,Pre,Ch,Code,Hs,BitsN,Acc,Clr,Eoi: LongInt;
 Pk: PByteArr; PkN: Integer;
 Procedure Flush;
 Begin
  If PkN>0 Then Begin Buf[0]:=PkN; Move(Pk^,Buf[1],PkN); BlockWrite(F,Buf,PkN+1); PkN:=0; End;
 End;
 Procedure PutCode(C: LongInt);
 Begin
  Acc:=Acc Or (C Shl BitsN); Inc(BitsN,CSz);
  While BitsN>=8 Do Begin
   Pk^[PkN]:=Acc And 255; Inc(PkN); Acc:=Acc Shr 8; Dec(BitsN,8);
   If PkN=255 Then Flush;
  End;
 End;
 Procedure ResetDict;
 Begin
  FillChar(HKey,SizeOf(HKey),$FF); Nxt:=Eoi+1; CSz:=9;
 End;
Begin
 SaveGif:=False;
 If (A=Nil) Or (A^.N<1) Then Exit;
 W:=A^.F[1]^.W; Hh:=A^.F[1]^.H;
 BuildPalette(A);
 If Not CreateOut(Path,F,Err) Then Exit;
 FillChar(H,SizeOf(H),0);
 T4(H,0,'GIF8'); H[4]:=Ord('9'); H[5]:=Ord('a'); P16(H,6,W); P16(H,8,Hh); H[10]:=$F7; H[11]:=0; H[12]:=0;
 BlockWrite(F,H,13);
 BlockWrite(F,GifPal,768);
 If Loop And (A^.N>1) Then Begin
  Buf[0]:=$21; Buf[1]:=$FF; Buf[2]:=11; Move('NETSCAPE2.0',Buf[3],11); Buf[14]:=3; Buf[15]:=1; Buf[16]:=0; Buf[17]:=0; Buf[18]:=0;
  BlockWrite(F,Buf,19);
 End;
 GetMem(Idx,W*Hh+8); New(Pk);
 For K:=1 To A^.N Do Begin
  For I:=0 To W*Hh-1 Do Begin
   X:=A^.F[K]^.P^[I*3] Shr 3; Y:=A^.F[K]^.P^[I*3+1] Shr 3; N:=A^.F[K]^.P^[I*3+2] Shr 3;
   Idx^[I]:=GifLut^[(X Shl 10) Or (Y Shl 5) Or N];
  End;
  Buf[0]:=$21; Buf[1]:=$F9; Buf[2]:=4; Buf[3]:=0; Buf[4]:=A^.Dly[K] And 255; Buf[5]:=A^.Dly[K] Shr 8; Buf[6]:=0; Buf[7]:=0;
  BlockWrite(F,Buf,8);
  Buf[0]:=$2C; Buf[1]:=0; Buf[2]:=0; Buf[3]:=0; Buf[4]:=0; Buf[5]:=W And 255; Buf[6]:=W Shr 8; Buf[7]:=Hh And 255; Buf[8]:=Hh Shr 8; Buf[9]:=0; Buf[10]:=8;
  BlockWrite(F,Buf,11);
  Clr:=256; Eoi:=257; PkN:=0; Acc:=0; BitsN:=0; ResetDict; PutCode(Clr);
  Pre:=Idx^[0];
  For I:=1 To W*Hh-1 Do Begin
   Ch:=Idx^[I];
   Hs:=((Pre Shl 8) Xor Ch) Mod 8191; Code:=-1;
   While HKey[Hs]<>-1 Do Begin
    If HKey[Hs]=(Pre Shl 8) Or Ch Then Begin Code:=HVal[Hs]; Break; End;
    Hs:=(Hs+1) Mod 8191;
   End;
   If Code>=0 Then Pre:=Code
   Else Begin
    PutCode(Pre);
    If Nxt<4096 Then Begin
     HKey[Hs]:=(Pre Shl 8) Or Ch; HVal[Hs]:=Nxt; Inc(Nxt);
     If (Nxt>(1 Shl CSz)) And (CSz<12) Then Inc(CSz);
    End Else Begin PutCode(Clr); ResetDict; End;
    Pre:=Ch;
   End;
  End;
  PutCode(Pre); PutCode(Eoi);
  If BitsN>0 Then Begin Pk^[PkN]:=Acc And 255; Inc(PkN); End;
  Flush; Buf[0]:=0; BlockWrite(F,Buf,1);
  If (K And 3)=0 Then UiTick(K,A^.N);
 End;
 Buf[0]:=$3B; BlockWrite(F,Buf,1);
 FreeMem(Idx,W*Hh+8); Dispose(Pk); Close(F);
 SaveGif:=True;
End;

{ ---------------------------------------------------------------------- }
{ Transformations d'image                                                    }
{ ---------------------------------------------------------------------- }
Function ImgRot90(S: PImg): PImg;
Var D: PImg; X,Y,O,P: LongInt;
Begin
 D:=ImgNew(S^.H,S^.W);
 If D<>Nil Then
  For Y:=0 To S^.H-1 Do For X:=0 To S^.W-1 Do Begin
   O:=(Y*S^.W+X)*3; P:=((X*S^.H)+(S^.H-1-Y))*3;
   D^.P^[P]:=S^.P^[O]; D^.P^[P+1]:=S^.P^[O+1]; D^.P^[P+2]:=S^.P^[O+2];
  End;
 ImgRot90:=D;
End;

Procedure ImgFlip(S: PImg; Hz,Vt: Boolean);
Var X,Y,A,B,K: LongInt; T: Byte;
Begin
 If Hz Then
  For Y:=0 To S^.H-1 Do For X:=0 To S^.W Div 2-1 Do
   For K:=0 To 2 Do Begin
    A:=(Y*S^.W+X)*3+K; B:=(Y*S^.W+(S^.W-1-X))*3+K;
    T:=S^.P^[A]; S^.P^[A]:=S^.P^[B]; S^.P^[B]:=T;
   End;
 If Vt Then
  For Y:=0 To S^.H Div 2-1 Do For X:=0 To S^.W-1 Do
   For K:=0 To 2 Do Begin
    A:=(Y*S^.W+X)*3+K; B:=((S^.H-1-Y)*S^.W+X)*3+K;
    T:=S^.P^[A]; S^.P^[A]:=S^.P^[B]; S^.P^[B]:=T;
   End;
End;

Function ImgCropTo(S: PImg; X0,Y0,W,H: LongInt): PImg;
Var D: PImg; Y: LongInt;
Begin
 If X0<0 Then X0:=0; If Y0<0 Then Y0:=0;
 If X0+W>S^.W Then W:=S^.W-X0; If Y0+H>S^.H Then H:=S^.H-Y0;
 ImgCropTo:=Nil;
 If (W<1) Or (H<1) Then Exit;
 D:=ImgNew(W,H);
 If D=Nil Then Exit;
 For Y:=0 To H-1 Do Move(S^.P^[((Y0+Y)*S^.W+X0)*3],D^.P^[Y*W*3],W*3);
 ImgCropTo:=D;
End;

Function ImgScale(S: PImg; NW,NH: LongInt): PImg;
Var D: PImg; X,Y,X0,Y0,X1,Y1,FX,FY,K: LongInt; V: LongInt;
Begin
 ImgScale:=Nil;
 D:=ImgNew(NW,NH);
 If D=Nil Then Exit;
 For Y:=0 To NH-1 Do Begin
  FY:=(Y*(S^.H-1)*256) Div Max(NH-1,1); Y0:=FY Shr 8; FY:=FY And 255; Y1:=Min(Y0+1,S^.H-1);
  For X:=0 To NW-1 Do Begin
   FX:=(X*(S^.W-1)*256) Div Max(NW-1,1); X0:=FX Shr 8; X1:=Min(X0+1,S^.W-1);
   For K:=0 To 2 Do Begin
    V:=(S^.P^[(Y0*S^.W+X0)*3+K]*(256-(FX And 255))+S^.P^[(Y0*S^.W+X1)*3+K]*(FX And 255)) Div 256;
    V:=V*(256-FY) + ((S^.P^[(Y1*S^.W+X0)*3+K]*(256-(FX And 255))+S^.P^[(Y1*S^.W+X1)*3+K]*(FX And 255)) Div 256)*FY;
    D^.P^[(Y*NW+X)*3+K]:=V Div 256;
   End;
  End;
 End;
 ImgScale:=D;
End;

Procedure ImgAdjust(S: PImg; Br,Ct,Sa,Hu: Integer);
Var I,N,R,G,B,Gy,V: LongInt; F,C,Sn,Cs: Double; Ma: Array[0..2,0..2] Of Double; An: Double;
Begin
 N:=S^.W*S^.H;
 F:=(100+Ct)/100.0; If Ct>0 Then F:=1+Ct/40.0;
 An:=Hu*Pi/180.0*1.8; C:=Cos(An); Sn:=Sin(An);
 Ma[0,0]:=0.213+C*0.787-Sn*0.213; Ma[0,1]:=0.715-C*0.715-Sn*0.715; Ma[0,2]:=0.072-C*0.072+Sn*0.928;
 Ma[1,0]:=0.213-C*0.213+Sn*0.143; Ma[1,1]:=0.715+C*0.285+Sn*0.140; Ma[1,2]:=0.072-C*0.072-Sn*0.283;
 Ma[2,0]:=0.213-C*0.213-Sn*0.787; Ma[2,1]:=0.715-C*0.715+Sn*0.715; Ma[2,2]:=0.072+C*0.928+Sn*0.072;
 For I:=0 To N-1 Do Begin
  R:=S^.P^[I*3]; G:=S^.P^[I*3+1]; B:=S^.P^[I*3+2];
  If Hu<>0 Then Begin
   V:=Round(R*Ma[0,0]+G*Ma[0,1]+B*Ma[0,2]); Gy:=Round(R*Ma[1,0]+G*Ma[1,1]+B*Ma[1,2]); B:=Round(R*Ma[2,0]+G*Ma[2,1]+B*Ma[2,2]);
   R:=V; G:=Gy;
  End;
  If Sa<>0 Then Begin
   Gy:=(R*30+G*59+B*11) Div 100;
   R:=Gy+((R-Gy)*(100+Sa)) Div 100; G:=Gy+((G-Gy)*(100+Sa)) Div 100; B:=Gy+((B-Gy)*(100+Sa)) Div 100;
  End;
  R:=Round((R-128)*F+128)+Br*2; G:=Round((G-128)*F+128)+Br*2; B:=Round((B-128)*F+128)+Br*2;
  S^.P^[I*3]:=Clip(R,0,255); S^.P^[I*3+1]:=Clip(G,0,255); S^.P^[I*3+2]:=Clip(B,0,255);
 End;
End;

Procedure ImgText(S: PImg; X,Y: LongInt; Const T: String; Sc: Integer; R,G,B: Byte; Alpha: Integer);
Var A: String; K,Rw,Cl,Dx,Dy,Px,Py,O: LongInt; Ch: Byte; Bits: Byte;
Begin
 A:=U2A(T);
 For K:=1 To Length(A) Do Begin
  Ch:=Ord(A[K]); If Ch<32 Then Ch:=63;
  For Rw:=0 To 7 Do Begin
   Bits:=Font8[Ch,Rw];
   For Cl:=0 To 7 Do If (Bits And (128 Shr Cl))<>0 Then
    For Dy:=0 To Sc-1 Do For Dx:=0 To Sc-1 Do Begin
     Px:=X+(K-1)*8*Sc+Cl*Sc+Dx; Py:=Y+Rw*Sc+Dy;
     If (Px>=0) And (Py>=0) And (Px<S^.W) And (Py<S^.H) Then Begin
      O:=(Py*S^.W+Px)*3;
      S^.P^[O]:=(S^.P^[O]*(100-Alpha)+R*Alpha) Div 100;
      S^.P^[O+1]:=(S^.P^[O+1]*(100-Alpha)+G*Alpha) Div 100;
      S^.P^[O+2]:=(S^.P^[O+2]*(100-Alpha)+B*Alpha) Div 100;
     End;
    End;
  End;
 End;
End;

Procedure ApplyEdit(Const M: TMedia; Var I: PImg);
Var T: PImg; K,Sc,TW,X,Y: LongInt;
Begin
 If M.CropW>0 Then Begin
  T:=ImgCropTo(I,M.CropX,M.CropY,M.CropW,M.CropH);
  If T<>Nil Then Begin ImgFree(I); I:=T; End;
 End;
 For K:=1 To M.Rot Mod 4 Do Begin
  T:=ImgRot90(I); If T<>Nil Then Begin ImgFree(I); I:=T; End;
 End;
 If M.FlipH Or M.FlipV Then ImgFlip(I,M.FlipH,M.FlipV);
 If (M.Bright<>0) Or (M.Contr<>0) Or (M.Satur<>0) Or (M.Hue<>0) Then ImgAdjust(I,M.Bright,M.Contr,M.Satur,M.Hue);
 If M.WmOn And (M.WmText<>'') Then Begin
  Sc:=M.WmSize*Max(1,I^.H Div 200); TW:=Length(U2A(M.WmText))*8*Sc;
  Case M.WmPos Mod 3 Of 0: X:=8; 1: X:=(I^.W-TW) Div 2; Else X:=I^.W-TW-8 End;
  Case M.WmPos Div 3 Of 0: Y:=8; 1: Y:=(I^.H-8*Sc) Div 2; Else Y:=I^.H-8*Sc-8 End;
  ImgText(I,X+Sc,Y+Sc,M.WmText,Sc,0,0,0,M.WmAlpha);
  ImgText(I,X,Y,M.WmText,Sc,255,255,255,M.WmAlpha);
 End;
End;

{ Redimensionne dans (W,H) en conservant le ratio, fond uni }
Function ImgFit(S: PImg; W,H: LongInt; R,G,B: Byte; Cover: Boolean): PImg;
Var D,T: PImg; NW,NH,X,Y,I: LongInt;
Begin
 ImgFit:=Nil;
 D:=ImgNew(W,H);
 If D=Nil Then Exit;
 For I:=0 To W*H-1 Do Begin D^.P^[I*3]:=R; D^.P^[I*3+1]:=G; D^.P^[I*3+2]:=B; End;
 If Cover Then Begin
  If S^.W*H>S^.H*W Then Begin NH:=H; NW:=(S^.W*H) Div S^.H; End Else Begin NW:=W; NH:=(S^.H*W) Div S^.W; End;
 End Else Begin
  If S^.W*H>S^.H*W Then Begin NW:=W; NH:=(S^.H*W) Div S^.W; End Else Begin NH:=H; NW:=(S^.W*H) Div S^.H; End;
 End;
 If NW<1 Then NW:=1; If NH<1 Then NH:=1;
 T:=ImgScale(S,NW,NH);
 If T=Nil Then Begin ImgFree(D); Exit; End;
 X:=(W-NW) Div 2; Y:=(H-NH) Div 2;
 For I:=0 To NH-1 Do
  If (Y+I>=0) And (Y+I<H) Then
   If X>=0 Then Move(T^.P^[I*NW*3],D^.P^[((Y+I)*W+X)*3],Min(NW,W-X)*3)
   Else Move(T^.P^[(I*NW-X)*3],D^.P^[(Y+I)*W*3],W*3);
 ImgFree(T);
 ImgFit:=D;
End;

Function LoadAnim(Const Path: String; Var A: PAnim; MaxFr: Integer): Boolean;
Var E: String; I: PImg;
Begin
 LoadAnim:=False; A:=Nil; E:=ExtOf(Path);
 If E='GIF' Then Begin LoadAnim:=LoadGif(Path,A,MaxFr); Exit; End;
 If E='BMP' Then Begin
  I:=LoadBmp(Path);
  If I=Nil Then Exit;
  New(A); A^.N:=1; A^.F[1]:=I; A^.Dly[1]:=100; LoadAnim:=True;
 End;
End;

Function LoadFirst(Const Path: String): PImg;
Var A: PAnim; I: PImg;
Begin
 LoadFirst:=Nil;
 If Not LoadAnim(Path,A,1) Then Exit;
 I:=A^.F[1]; A^.F[1]:=Nil; A^.N:=0; AnimFree(A);
 LoadFirst:=I;
End;

{ ---------------------------------------------------------------------- }
{ Apercu a l'ecran (16 couleurs, tramage ordonne)                           }
{ ---------------------------------------------------------------------- }
Const Bayer: Array[0..3,0..3] Of ShortInt = ((0,8,2,10),(12,4,14,6),(3,11,1,9),(15,7,13,5));

Function NearPal(R,G,B: Integer): Byte;
Var K,Best: Integer; D,Bd: LongInt;
Begin
 Bd:=2000000000; Best:=0;
 For K:=0 To 15 Do Begin
  D:=Sqr(R-PalRGB[K,0])*3+Sqr(G-PalRGB[K,1])*4+Sqr(B-PalRGB[K,2])*2;
  If D<Bd Then Begin Bd:=D; Best:=K; End;
 End;
 NearPal:=Best;
End;

Procedure DrawImg(I: PImg; X,Y,W,H: Integer);
Var NW,NH,DX,DY,SX,SY,O,T: LongInt; Dt: Integer;
Begin
 If I=Nil Then Exit;
 If I^.W*H>I^.H*W Then Begin NW:=W; NH:=(I^.H*W) Div I^.W; End Else Begin NH:=H; NW:=(I^.W*H) Div I^.H; End;
 If NW<1 Then NW:=1; If NH<1 Then NH:=1;
 X:=X+(W-NW) Div 2; Y:=Y+(H-NH) Div 2;
 For DY:=0 To NH-1 Do Begin
  SY:=(DY*I^.H) Div NH;
  For DX:=0 To NW-1 Do Begin
   SX:=(DX*I^.W) Div NW; O:=(SY*I^.W+SX)*3;
   Dt:=(Bayer[DY And 3,DX And 3]-8)*3;
   PutPixel(X+DX,Y+DY,NearPal(Clip(I^.P^[O]+Dt,0,255),Clip(I^.P^[O+1]+Dt,0,255),Clip(I^.P^[O+2]+Dt,0,255)));
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Collage                                                                     }
{ ---------------------------------------------------------------------- }
Type
 TCell = Record X,Y,W,H: Integer; End;
 TLayout = Array[1..9] Of TCell;

Const NLayouts = 12;

Procedure GetLayout(L: Integer; Var N: Integer; Var C: TLayout);
 Procedure S(K,X,Y,W,H: Integer);
 Begin
  C[K].X:=X; C[K].Y:=Y; C[K].W:=W; C[K].H:=H;
 End;
Var I,J: Integer;
Begin
 Case L Of
  1: Begin N:=2; S(1,0,0,50,100); S(2,50,0,50,100); End;
  2: Begin N:=2; S(1,0,0,100,50); S(2,0,50,100,50); End;
  3: Begin N:=3; S(1,0,0,60,100); S(2,60,0,40,50); S(3,60,50,40,50); End;
  4: Begin N:=3; S(1,0,0,100,60); S(2,0,60,50,40); S(3,50,60,50,40); End;
  5: Begin N:=3; S(1,0,0,34,100); S(2,34,0,33,100); S(3,67,0,33,100); End;
  6: Begin N:=3; S(1,0,0,100,34); S(2,0,34,100,33); S(3,0,67,100,33); End;
  7: Begin N:=4; S(1,0,0,50,50); S(2,50,0,50,50); S(3,0,50,50,50); S(4,50,50,50,50); End;
  8: Begin N:=4; S(1,0,0,60,100); S(2,60,0,40,34); S(3,60,34,40,33); S(4,60,67,40,33); End;
  9: Begin N:=5; S(1,0,0,100,60); S(2,0,60,25,40); S(3,25,60,25,40); S(4,50,60,25,40); S(5,75,60,25,40); End;
  10: Begin N:=6; For I:=0 To 2 Do For J:=0 To 1 Do S(J*3+I+1,I*34-Ord(I=2),J*50,34-Ord(I=2)+Ord(I=2),50); End;
  11: Begin N:=9; For I:=0 To 2 Do For J:=0 To 2 Do S(J*3+I+1,I*34-Ord(I=2),J*34-Ord(J=2),34,34); End;
  Else Begin N:=2; S(1,0,0,100,100); S(2,60,60,36,36); End;
 End;
End;

Type TPathList = Array[0..15] Of String[200];

Function RenderCollage(Lay: Integer; Var Paths: TPathList; W,H,Border,Br,Bg,Bb: LongInt; Var Err: String): PImg;
Var Out,Im,Sc: PImg; N,K: Integer; I,X,Y,CW,CH,Yy: LongInt; C: TLayout;
Begin
 RenderCollage:=Nil;
 Out:=ImgNew(W,H);
 If Out=Nil Then Begin Err:='M'#233'moire insuffisante.'; Exit; End;
 For I:=0 To W*H-1 Do Begin Out^.P^[I*3]:=Br; Out^.P^[I*3+1]:=Bg; Out^.P^[I*3+2]:=Bb; End;
 GetLayout(Lay,N,C);
 For K:=1 To N Do Begin
  X:=(C[K].X*W) Div 100+Border; Y:=(C[K].Y*H) Div 100+Border;
  CW:=(C[K].W*W) Div 100-2*Border; CH:=(C[K].H*H) Div 100-2*Border;
  If (CW<2) Or (CH<2) Then Continue;
  Im:=Nil;
  If Paths[K-1]<>'' Then Im:=LoadFirst(Paths[K-1]);
  If Im=Nil Then Begin
   For Yy:=Y To Y+CH-1 Do For I:=X To X+CW-1 Do If (I<W) And (Yy<H) Then Begin Out^.P^[(Yy*W+I)*3]:=225; Out^.P^[(Yy*W+I)*3+1]:=228; Out^.P^[(Yy*W+I)*3+2]:=235; End;
   Continue;
  End;
  Sc:=ImgFit(Im,CW,CH,0,0,0,True);
  ImgFree(Im);
  If Sc=Nil Then Continue;
  For I:=0 To CH-1 Do If (Y+I<H) Then Move(Sc^.P^[I*CW*3],Out^.P^[((Y+I)*W+X)*3],Min(CW,W-X)*3);
  ImgFree(Sc);
 End;
 RenderCollage:=Out;
End;

{ ---------------------------------------------------------------------- }
{ Diaporama / GIF a partir d'une liste d'images                              }
{ ---------------------------------------------------------------------- }
Procedure CenterText(I: PImg; Const T: String; Sc: Integer; R,G,B: Byte);
Var TW: Integer;
Begin
 TW:=Length(U2A(T))*8*Sc;
 ImgText(I,(I^.W-TW) Div 2,(I^.H-8*Sc) Div 2,T,Sc,R,G,B,100);
End;

Function BuildShow(Var Paths: TPathList; N: Integer; W,H: LongInt; DelayCs,Fade: Integer; Br,Bg,Bb,Tr,Tg,Tb: Byte;
 Const Title,EndText: String; Var A: PAnim; Var Err: String): Boolean;
Var K,J: Integer; Im,Fr,Prev,Mix: PImg; Src: PAnim; Steps: Integer; I,T: LongInt;
 Procedure Add(Img: PImg; D: Integer);
 Begin
  If A^.N>=MaxAnim Then Begin ImgFree(Img); Exit; End;
  Inc(A^.N); A^.F[A^.N]:=Img; A^.Dly[A^.N]:=D;
 End;
Begin
 BuildShow:=False; New(A); A^.N:=0; Prev:=Nil;
 Steps:=Fade;
 If (N+2)*(1+Steps)>MaxAnim Then Steps:=0;
 If Title<>'' Then Begin
  Fr:=ImgNew(W,H);
  If Fr<>Nil Then Begin
   For I:=0 To W*H-1 Do Begin Fr^.P^[I*3]:=Br; Fr^.P^[I*3+1]:=Bg; Fr^.P^[I*3+2]:=Bb; End;
   CenterText(Fr,Title,Max(1,W Div 160),Tr,Tg,Tb); Add(Fr,DelayCs); Prev:=ImgCopy(A^.F[A^.N]);
  End;
 End;
 For K:=0 To N-1 Do Begin
  Fr:=Nil;
  If LoadAnim(Paths[K],Src,1) Then Begin
   Fr:=ImgFit(Src^.F[1],W,H,Br,Bg,Bb,False); AnimFree(Src);
  End Else Begin
   Err:='Image non lisible (BMP/GIF seulement): '+NameOf(Paths[K]);
  End;
  If Fr=Nil Then Continue;
  If (Prev<>Nil) And (Steps>0) Then
   For J:=1 To Steps Do Begin
    Mix:=ImgNew(W,H);
    If Mix<>Nil Then Begin
     T:=(J*256) Div (Steps+1);
     For I:=0 To W*H*3-1 Do Mix^.P^[I]:=(Prev^.P^[I]*(256-T)+Fr^.P^[I]*T) Div 256;
     Add(Mix,8);
    End;
   End;
  ImgFree(Prev); Prev:=ImgCopy(Fr);
  Add(Fr,DelayCs);
 End;
 ImgFree(Prev);
 If EndText<>'' Then Begin
  Fr:=ImgNew(W,H);
  If Fr<>Nil Then Begin
   For I:=0 To W*H-1 Do Begin Fr^.P^[I*3]:=Br; Fr^.P^[I*3+1]:=Bg; Fr^.P^[I*3+2]:=Bb; End;
   CenterText(Fr,EndText,Max(1,W Div 160),Tr,Tg,Tb); Add(Fr,DelayCs);
  End;
 End;
 If A^.N=0 Then Begin AnimFree(A); If Err='' Then Err:='Aucune image utilisable.'; Exit; End;
 BuildShow:=True;
End;

{ ---------------------------------------------------------------------- }
{ Conversion d'une image / d'un GIF anime                                    }
{ ---------------------------------------------------------------------- }
Function RunImageJob(Const M: TMedia; Const Pr: TProf; Const Dst: String; Var Err: String): Boolean;
Var A: PAnim; K,S,E: Integer; Ok: Boolean; Acc: LongInt; T: PImg; Tmp: PAnim;
Begin
 RunImageJob:=False;
 If Not LoadAnim(M.Path,A,MaxAnim) Then Begin
  Err:='Format d''image non pris en charge par le moteur ('+M.Fmt+'). BMP et GIF seulement.'; Exit;
 End;
 { decoupe temporelle d'un GIF anime }
 S:=1; E:=A^.N;
 If (A^.N>1) And ((M.TrimS>0) Or (M.TrimE>0)) Then Begin
  Acc:=0; S:=A^.N+1; E:=0;
  For K:=1 To A^.N Do Begin
   If (Acc>=M.TrimS) And (S>A^.N) Then S:=K;
   Inc(Acc,A^.Dly[K]*10);
   If (M.TrimE=0) Or (Acc<=M.TrimE) Then E:=K;
  End;
  If S>E Then Begin S:=1; E:=A^.N; End;
 End;
 For K:=1 To A^.N Do Begin
  If (K>=S) And (K<=E) Then ApplyEdit(M,A^.F[K]);
  UiTick(K,A^.N);
 End;
 If (S>1) Or (E<A^.N) Then Begin
  New(Tmp); Tmp^.N:=0;
  For K:=S To E Do Begin Inc(Tmp^.N); Tmp^.F[Tmp^.N]:=A^.F[K]; Tmp^.Dly[Tmp^.N]:=A^.Dly[K]; A^.F[K]:=Nil; End;
  AnimFree(A); A:=Tmp;
 End;
 If Pr.Ext='GIF' Then Ok:=SaveGif(Dst,A,True)
 Else If Pr.Ext='BMP' Then Ok:=SaveBmp(Dst,A^.F[1])
 Else Begin Ok:=False; Err:='Sortie image non prise en charge: '+Pr.Ext; End;
 If (Not Ok) And (Err='') Then Err:='Ecriture impossible.';
 AnimFree(A);
 RunImageJob:=Ok;
End;

{ ---------------------------------------------------------------------- }
{ Decodeur FLAC natif (sous-trames CONSTANT, VERBATIM, FIXED, LPC)           }
{ ---------------------------------------------------------------------- }
{$IFDEF FPC}
Type
 TFlBuf = Array[0..0] Of Byte;
 PFlBuf = ^TFlBuf;
 TFlCh = Array[0..65535] Of LongInt;
 PFlCh = ^TFlCh;

Var
 FlB: PFlBuf;
 FlSize: LongInt;
 FlPos: LongInt;
 FlBad: Boolean;

Function SarL(V: LongInt; N: Integer): LongInt;
Begin
 If V>=0 Then SarL:=V Shr N Else SarL:=-((-V-1) Shr N)-1;
End;

Function SarQ(V: Int64; N: Integer): Int64;
Begin
 If V>=0 Then SarQ:=V Shr N Else SarQ:=-((-V-1) Shr N)-1;
End;

Function FlBits(N: Integer): LongInt;
Var V: LongInt; Idx,Off,Take: LongInt;
Begin
 V:=0;
 While N>0 Do Begin
  Idx:=FlPos Shr 3;
  If Idx>=FlSize Then Begin FlBad:=True; FlBits:=0; Exit; End;
  Off:=FlPos And 7; Take:=8-Off; If Take>N Then Take:=N;
  V:=(V Shl Take) Or ((FlB^[Idx] Shr (8-Off-Take)) And ((1 Shl Take)-1));
  Inc(FlPos,Take); Dec(N,Take);
 End;
 FlBits:=V;
End;

Function FlSBits(N: Integer): LongInt;
Var V: LongInt;
Begin
 If N=0 Then Begin FlSBits:=0; Exit; End;
 V:=FlBits(N);
 If (V And (LongInt(1) Shl (N-1)))<>0 Then V:=V-(LongInt(1) Shl N);
 FlSBits:=V;
End;

Function FlUnary: LongInt;
Var N: LongInt;
Begin
 N:=0;
 While (FlBits(1)=0) And Not FlBad And (N<100000) Do Inc(N);
 FlUnary:=N;
End;

Procedure FlResidual(Ch: PFlCh; Order,BlockSize: LongInt);
Var Method,PO,Parts,P,N,I,Start,Param,Bits,Q,V: LongInt;
Begin
 Method:=FlBits(2); PO:=FlBits(4);
 Parts:=LongInt(1) Shl PO; Start:=Order;
 For P:=0 To Parts-1 Do Begin
  If P=0 Then N:=(BlockSize Shr PO)-Order Else N:=BlockSize Shr PO;
  If Method=0 Then Param:=FlBits(4) Else Param:=FlBits(5);
  If ((Method=0) And (Param=15)) Or ((Method=1) And (Param=31)) Then Begin
   Bits:=FlBits(5);
   For I:=0 To N-1 Do Begin Ch^[Start+I]:=FlSBits(Bits); End;
  End Else Begin
   For I:=0 To N-1 Do Begin
    Q:=FlUnary; V:=(Q Shl Param) Or FlBits(Param);
    If (V And 1)<>0 Then V:=-((V+1) Shr 1) Else V:=V Shr 1;
    Ch^[Start+I]:=V;
    If FlBad Then Exit;
   End;
  End;
  Inc(Start,N);
 End;
End;

Procedure FlSubframe(Ch: PFlCh; BlockSize,Bps: LongInt);
Var Typ,Wasted,I,J,Order,Prec,Shift: LongInt; Coef: Array[0..31] Of LongInt; Sum: Int64; V: LongInt;
Begin
 FlBits(1);
 Typ:=FlBits(6); Wasted:=0;
 If FlBits(1)=1 Then Begin Wasted:=1; While (FlBits(1)=0) And Not FlBad Do Inc(Wasted); End;
 Dec(Bps,Wasted);
 If Typ=0 Then Begin
  V:=FlSBits(Bps); For I:=0 To BlockSize-1 Do Ch^[I]:=V;
 End Else If Typ=1 Then Begin
  For I:=0 To BlockSize-1 Do Ch^[I]:=FlSBits(Bps);
 End Else If (Typ>=8) And (Typ<=15) Then Begin
  Order:=Typ-8;
  For I:=0 To Order-1 Do Ch^[I]:=FlSBits(Bps);
  FlResidual(Ch,Order,BlockSize);
  For I:=Order To BlockSize-1 Do Begin
   Case Order Of
    0: ;
    1: Ch^[I]:=Ch^[I]+Ch^[I-1];
    2: Ch^[I]:=Ch^[I]+2*Ch^[I-1]-Ch^[I-2];
    3: Ch^[I]:=Ch^[I]+3*Ch^[I-1]-3*Ch^[I-2]+Ch^[I-3];
    Else Ch^[I]:=Ch^[I]+4*Ch^[I-1]-6*Ch^[I-2]+4*Ch^[I-3]-Ch^[I-4];
   End;
  End;
 End Else If Typ>=32 Then Begin
  Order:=Typ-31;
  For I:=0 To Order-1 Do Ch^[I]:=FlSBits(Bps);
  Prec:=FlBits(4)+1; Shift:=FlSBits(5);
  For I:=0 To Order-1 Do Coef[I]:=FlSBits(Prec);
  FlResidual(Ch,Order,BlockSize);
  For I:=Order To BlockSize-1 Do Begin
   Sum:=0;
   For J:=0 To Order-1 Do Sum:=Sum+Int64(Coef[J])*Ch^[I-J-1];
   If Shift>=0 Then Ch^[I]:=Ch^[I]+LongInt(SarQ(Sum,Shift)) Else Ch^[I]:=Ch^[I]+LongInt(Sum Shl (-Shift));
  End;
 End Else FlBad:=True;
 If Wasted>0 Then For I:=0 To BlockSize-1 Do Ch^[I]:=Ch^[I] Shl Wasted;
End;

Function DecodeFlac(Const Src,Dst: String; Var Err: String): Boolean;
Var
 FO: File; Hd: THdr; C: Array[0..7] Of PFlCh; Out: PIntArr; I,K,Nch,Rate,Bps,Typ,Last: LongInt; Len: LongInt;
 Blk,Bsz,Asg,SzCode,RateCode,Chn,SBps: LongInt; Total,Written: LongInt; Ok: Boolean; Mid,Side,L,R,V: LongInt; Sh: Integer;
 SyncPos: LongInt; B0,B1: Byte;
Begin
 DecodeFlac:=False; FlBad:=False;
 If Not ReadAll(Src,PPixArr(FlB),FlSize) Then Begin Err:='Fichier FLAC illisible ou trop volumineux (> 48 Mo).'; Exit; End;
 If (FlSize<42) Or (FlB^[0]<>102) Or (FlB^[1]<>76) Or (FlB^[2]<>97) Or (FlB^[3]<>67) Then Begin Err:='Signature FLAC absente.'; FreeMem(FlB,FlSize+8); Exit; End;
 FlPos:=32; Rate:=0; Nch:=0; Bps:=0; Total:=0;
 Repeat
  Last:=FlBits(1); Typ:=FlBits(7); Len:=FlBits(24);
  If Typ=0 Then Begin
   FlBits(16); FlBits(16); FlBits(24); FlBits(24);
   Rate:=FlBits(20); Nch:=FlBits(3)+1; Bps:=FlBits(5)+1; FlBits(4); Total:=FlBits(32);
   FlPos:=FlPos+128;
  End Else FlPos:=FlPos+Len*8;
 Until (Last=1) Or FlBad;
 If (Rate=0) Or (Nch<1) Or (Nch>2) Or (Bps<8) Or (Bps>24) Then Begin
  Err:='FLAC non pris en charge (mono/st'#233'r'#233'o 8 '#224' 24 bits seulement).'; FreeMem(FlB,FlSize+8); Exit;
 End;
 If Not CreateOut(Dst,FO,Err) Then Begin FreeMem(FlB,FlSize+8); Exit; End;
 PcmHeader(Hd,Rate,Nch,16,0); BlockWrite(FO,Hd,44);
 For I:=0 To 7 Do C[I]:=Nil;
 For I:=0 To Nch-1 Do GetMem(C[I],SizeOf(TFlCh));
 New(Out);
 Written:=0; Ok:=True;
 { frames : recherche de la synchronisation 0xFFF8 }
 FlPos:=(FlPos+7) And Not 7;
 While Ok And (Not FlBad) And ((FlPos Shr 3)+8<FlSize) Do Begin
  SyncPos:=FlPos Shr 3;
  B0:=FlB^[SyncPos]; B1:=FlB^[SyncPos+1];
  If (B0<>$FF) Or ((B1 And $FE)<>$F8) Then Begin Inc(FlPos,8); Continue; End;
  FlPos:=FlPos+16;
  Blk:=FlBits(4); RateCode:=FlBits(4); Asg:=FlBits(4); SzCode:=FlBits(3); FlBits(1);
  { numero de trame (UTF-8) }
  V:=FlBits(8);
  If V>=$C0 Then Begin K:=0; While (V And ($80 Shr (K+1)))<>0 Do Inc(K); For I:=1 To K Do FlBits(8); End;
  Case Blk Of
   1: Bsz:=192; 2..5: Bsz:=576 Shl (Blk-2); 6: Bsz:=FlBits(8)+1; 7: Bsz:=FlBits(16)+1;
   Else Bsz:=256 Shl (Blk-8);
  End;
  Case RateCode Of 12: FlBits(8); 13,14: FlBits(16); End;
  FlBits(8);
  Case SzCode Of 1: SBps:=8; 2: SBps:=12; 4: SBps:=16; 5: SBps:=20; 6: SBps:=24; Else SBps:=Bps; End;
  If (Bsz<1) Or (Bsz>65535) Or FlBad Then Begin Ok:=False; Err:='Trame FLAC invalide.'; Break; End;
  If Asg<=7 Then Chn:=Asg+1 Else Chn:=2;
  If Chn<>Nch Then Begin Ok:=False; Err:='Changement de canaux FLAC non pris en charge.'; Break; End;
  For I:=0 To Chn-1 Do Begin
   K:=SBps;
   If ((Asg=8) And (I=1)) Or ((Asg=9) And (I=0)) Or ((Asg=10) And (I=1)) Then Inc(K);
   FlSubframe(C[I],Bsz,K);
  End;
  If FlBad Then Begin Ok:=False; Err:='Donn'#233'es FLAC corrompues.'; Break; End;
  FlPos:=(FlPos+7) And Not 7; FlBits(16);
  Case Asg Of
   8: For I:=0 To Bsz-1 Do C[1]^[I]:=C[0]^[I]-C[1]^[I];
   9: For I:=0 To Bsz-1 Do C[0]^[I]:=C[0]^[I]+C[1]^[I];
   10: For I:=0 To Bsz-1 Do Begin
    Mid:=C[0]^[I]; Side:=C[1]^[I]; Mid:=(Mid Shl 1) Or (Side And 1);
    C[0]^[I]:=SarL(Mid+Side,1); C[1]^[I]:=SarL(Mid-Side,1);
   End;
  End;
  Sh:=SBps-16;
  K:=0;
  For I:=0 To Bsz-1 Do Begin
   For Chn:=0 To Nch-1 Do Begin
    V:=C[Chn]^[I];
    If Sh>0 Then V:=SarL(V,Sh) Else If Sh<0 Then V:=V Shl (-Sh);
    If V>32767 Then V:=32767; If V<-32768 Then V:=-32768;
    Out^[K]:=V; Inc(K);
    If K>=16384 Then Begin BlockWrite(FO,Out^,K*2); Inc(Written,K*2); K:=0; End;
   End;
  End;
  If K>0 Then Begin BlockWrite(FO,Out^,K*2); Inc(Written,K*2); End;
  UiTick(FlPos Shr 3,FlSize);
  If Stopped Then Begin Ok:=False; Err:='Conversion annul'#233'e.'; End;
 End;
 If Ok And (Written=0) Then Begin Ok:=False; Err:='Aucune trame FLAC d'#233'cod'#233'e.'; End;
 If Ok Then PutHeaderFix(FO,Rate,Nch,16,Written);
 Close(FO);
 For I:=0 To Nch-1 Do FreeMem(C[I],SizeOf(TFlCh));
 Dispose(Out); FreeMem(FlB,FlSize+8);
 If Not Ok Then DelFile(Dst);
 DecodeFlac:=Ok;
End;
{$ENDIF}

{ ====================================================================== }
{ Travaux de conversion                                                     }
{ ====================================================================== }
Const
 { identifiants des zones cliquables }
 hMenu = 10;        { 10..19 : titres de la barre de menus }
 hTab = 30;         { 30..34 : onglets principaux }
 hAdd = 40; hAddArrow = 41; hSubConv = 42; hSubDone = 43; hHw = 44;
 hFmt = 50; hFmtGear = 51; hFast = 52; hDir = 53; hDirBtn = 54; hMerge = 55; hConvAll = 56;
 hScrUp = 57; hScrDn = 58;
 { ligne de fichier : 100 + 10*i + k  (k : 0 edition, 1 couper, 2 effets, 3 format,
   4 supprimer, 5 piste audio, 6 sous-titre, 7 informations) }
 RowH = 63; RowsVis = 4; ListY = 99;

Var
 JobWarn: String;
 ProgMode: Boolean;
 StageLo,StageHi: Integer;
 CancelX1,CancelY1,CancelX2,CancelY2: Integer;
 Running: Boolean;

Procedure DrawRowProgress; Forward;
Procedure DrawConvertScreen; Forward;
Procedure DrawFooter; Forward;
Procedure DrawProgBox; Forward;
Procedure DrawAll; Forward;
{$IFDEF FPC}
Function VideoJob(Var M: TMedia; Const Pr: TProf; Const Dst: String; Var Err: String): Boolean; Forward;
Function ImageVideoJob(Var M: TMedia; Const Pr: TProf; Const Dst: String; Var Err: String): Boolean; Forward;
Function VideoFirstFrame(Const Path,Fmt: String): PImg; Forward;
{$ENDIF}

Procedure UiTick(Pos,Total: LongInt);
Var Pct: Integer; C: Char; X,Y: Integer; B: LongInt;
Begin
 If Total<0 Then Begin
  If EngFirst=0 Then EngFirst:=Pos;
  If EngFirst>0 Then Pct:=100-Integer((Pos*100) Div EngFirst) Else Pct:=0;
 End Else If Total>0 Then Begin
  If Total>20000000 Then Pct:=Integer(Pos Div (Total Div 100+1)) Else Pct:=Integer((Pos*100) Div Total);
 End Else Pct:=0;
 Pct:=Clip(Pct,0,100);
 If (JobIdx>=1) And (JobIdx<=MaxFiles+1) And (Files[JobIdx]<>Nil) Then
  Files[JobIdx]^.Pct:=StageLo+((StageHi-StageLo)*Pct) Div 100;
 If Ticks-LastDraw>=15 Then Begin
  LastDraw:=Ticks;
  If Running Then Begin If ProgMode Then DrawProgBox Else DrawRowProgress; End;
  If KeyPressed Then Begin C:=ReadKey; If C=#27 Then Stopped:=True; If C=#0 Then C:=ReadKey; End;
  ReadMouse(X,Y,B);
  If ((B And 1)<>0) And (X>=CancelX1) And (X<=CancelX2) And (Y>=CancelY1) And (Y<=CancelY2) Then Stopped:=True;
 End;
End;

Function LowExt(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:=S; For I:=1 To Length(R) Do If (R[I]>='A') And (R[I]<='Z') Then R[I]:=Chr(Ord(R[I])+32);
 LowExt:=R;
End;

Function UniqueOut(Const Dir,Base,Ext: String): String;
Var P: String; N: Integer;
Begin
 If (Dir<>'') And (Not DirExists(Dir)) Then Begin {$I-}MkDir(Dir);{$I+} If IOResult<>0 Then ; End;
 P:=AddSlash(Dir)+Base+'.'+LowExt(Ext); N:=0;
 If Not OverwriteAll Then
  While FileExists(P) Do Begin Inc(N); P:=AddSlash(Dir)+Base+'_'+IStr(N)+'.'+LowExt(Ext); End;
 UniqueOut:=P;
End;

{ Parametres de traitement audio derives du fichier, du profil et des reglages }
Procedure BuildAP(Const M: TMedia; Const Pr: TProf; Var P: TAP; Const SP: TAP);
Begin
 P:=SP;
 P.StartMs:=M.TrimS; P.EndMs:=M.TrimE; P.DelayMs:=M.ADelay+SP.DelayMs;
 If SP.Vol=0 Then P.Vol:=M.Vol Else P.Vol:=(M.Vol*SP.Vol) Div 100;
 If P.Speed<=0 Then P.Speed:=100;
 P.OutRate:=SP.OutRate;
 If P.OutRate=0 Then Begin
  If CustRate>0 Then P.OutRate:=CustRate
  Else If (Pr.Rate>0) And (Pr.Rate<44100) Then P.OutRate:=Pr.Rate
  Else If (M.Rate=32000) Or (M.Rate=44100) Or (M.Rate=48000) Then P.OutRate:=M.Rate
  Else P.OutRate:=44100;
  If (Pr.Ext='MP3') And (P.OutRate<32000) Then P.OutRate:=32000;
 End;
 P.OutCh:=SP.OutCh;
 If P.OutCh=0 Then Begin
  If CustCh>0 Then P.OutCh:=CustCh
  Else If Pr.Ch=1 Then P.OutCh:=1
  Else P.OutCh:=0;
 End;
End;

Function AppendWavData(Const Src: String; Var FO: File; Var Rate: LongInt; Var Ch: Integer; Var Total: LongInt; Var Err: String): Boolean;
Var W: TWavInfo; FI: File;
Begin
 AppendWavData:=False;
 If Not OpenWavIn(Src,FI,W,Err) Then Exit;
 If Total=0 Then Begin Rate:=W.Rate; Ch:=W.Ch; End
 Else If (W.Rate<>Rate) Or (W.Ch<>Ch) Then Begin Close(FI); Err:='Formats audio diff'#233'rents.'; Exit; End;
 CopyRange(FI,FO,W.DataOfs,W.DataLen,False);
 Inc(Total,W.DataLen);
 Close(FI);
 AppendWavData:=True;
End;

{ Convertit un fichier. Retourne True si reussi (Dst = sortie creee) }
Function DoConvert(Var M: TMedia; Const Pr: TProf; Const Dst: String; Const SP: TAP; Var Err: String): Boolean;
Var T1,T2: String; P: TAP; Audio: Boolean; Ok: Boolean;
Begin
 DoConvert:=False; Err:=''; JobWarn:='';
 Audio:=InList(Pr.Ext,'MP3,WAV,AIF,AU,M4A,AAC');
 If Audio Then Begin
  If (M.Kind=3) Or ((M.Kind=2) And (M.Fmt='GIF')) Then Begin Err:='Ce fichier ne contient pas de piste audio.'; Exit; End;
  StageLo:=0; StageHi:=45;
  T1:=TmpName('WAV');
  If Not GetPcm(M,T1,Err) Then Begin DelFile(T1); Exit; End;
  If Stopped Then Begin DelFile(T1); Err:='Conversion annul'#233'e.'; Exit; End;
  BuildAP(M,Pr,P,SP);
  StageLo:=45; StageHi:=60;
  T2:=TmpName('WAV');
  If Not ProcessWav(T1,T2,P,Err) Then Begin DelFile(T1); DelFile(T2); Exit; End;
  DelFile(T1);
  StageLo:=60; StageHi:=100;
  Ok:=WriteFinal(T2,Dst,Pr,Err);
  DelFile(T2);
  If (Not Ok) Then DelFile(Dst);
  DoConvert:=Ok;
 End Else If InList(Pr.Ext,'GIF,BMP') Then Begin
  If (M.Kind=3) Or ((M.Kind=2) And (M.Fmt='GIF')) Then Begin
   StageLo:=0; StageHi:=100;
   DoConvert:=RunImageJob(M,Pr,Dst,Err);
  End Else Err:='Le d'#233'codeur vid'#233'o n''est pas inclus : seules les images BMP/GIF peuvent '#234'tre converties en image.';
 End Else If InList(Pr.Ext,'MP4,MOV,M4V,3GP') Then Begin
  {$IFDEF FPC}
  If M.Kind=1 Then Err:='Un fichier audio ne peut pas devenir une vid'#233'o. Choisissez un profil Audio.'
  Else If (M.Kind=3) Or (M.Fmt='GIF') Then Begin StageLo:=0; StageHi:=90; DoConvert:=ImageVideoJob(M,Pr,Dst,Err); End
  Else Begin StageLo:=0; StageHi:=90; DoConvert:=VideoJob(M,Pr,Dst,Err); End;
  {$ELSE}
  Err:='Sortie MP4 indisponible dans la version Turbo Pascal.';
  {$ENDIF}
 End Else Begin
  If M.Kind=1 Then Err:='Un fichier audio ne peut pas devenir une vid'#233'o. Choisissez un profil Audio.'
  Else If M.Kind=3 Then Err:='Choisissez un profil Image (GIF/BMP) ou Audio pour ce fichier.'
  Else Err:='Le moteur int'#233'gr'#233' ne contient pas d''encodeur vid'#233'o '+Pr.VC+'. Utilisez un profil MP4/MOV/M4V/3GP (H.264), Audio ou Image.';
 End;
End;

Procedure SetStatus(I: Integer; St: Byte; Const Msg: String);
Begin
 Files[I]^.Status:=St; Files[I]^.Msg:=Copy(Msg,1,90);
End;

Procedure AddConverted(Const P: String);
Var K: Integer;
Begin
 If NConv>=64 Then Begin
  For K:=1 To 63 Do Converted[K]:=Converted[K+1];
  NConv:=63;
 End;
 Inc(NConv); Converted[NConv]:=P;
End;

Function MergeAudio(Const Pr: TProf; Var Dst,Err: String): Boolean;
Var I: Integer; FO: File; Tot,Rate: LongInt; Ch: Integer; Hd: THdr; Tmp,T1,T2: String; P,SP: TAP; Ok: Boolean;
Begin
 MergeAudio:=False; Tmp:=TmpName('WAV'); Tot:=0; Rate:=0; Ch:=2;
 If Not CreateOut(Tmp,FO,Err) Then Exit;
 PcmHeader(Hd,44100,2,16,0); BlockWrite(FO,Hd,44);
 Ok:=True;
 For I:=1 To NFiles Do Begin
  If Not Ok Then Break;
  JobIdx:=I; SetStatus(I,1,'Fusion...'); Files[I]^.Pct:=0;
  FillChar(SP,SizeOf(SP),0); SP.Vol:=100; SP.Speed:=100;
  StageLo:=0; StageHi:=50;
  T1:=TmpName('WAV');
  Ok:=GetPcm(Files[I]^,T1,Err);
  If Ok And Stopped Then Begin Ok:=False; Err:='Conversion annul'#233'e.'; End;
  If Ok Then Begin
   BuildAP(Files[I]^,Pr,P,SP);
   If I=1 Then Begin Rate:=P.OutRate; Ch:=P.OutCh; If Ch=0 Then Ch:=2; End;
   P.OutRate:=Rate; P.OutCh:=Ch;
   T2:=TmpName('WAV'); StageLo:=50; StageHi:=100;
   Ok:=ProcessWav(T1,T2,P,Err);
   If Ok Then Ok:=AppendWavData(T2,FO,Rate,Ch,Tot,Err);
   DelFile(T2);
  End;
  DelFile(T1);
  If Ok Then Begin SetStatus(I,2,'Fusionn'#233); Files[I]^.Pct:=100; End Else SetStatus(I,3,Err);
 End;
 If Ok Then PutHeaderFix(FO,Rate,Ch,16,Tot);
 Close(FO);
 If Ok Then Begin
  Dst:=UniqueOut(OutDir,BaseOf(Files[1]^.Path)+'_fusion',Pr.Ext);
  StageLo:=0; StageHi:=100; JobIdx:=1;
  Ok:=WriteFinal(Tmp,Dst,Pr,Err);
  If Not Ok Then DelFile(Dst);
 End;
 DelFile(Tmp);
 MergeAudio:=Ok;
End;

Procedure ConvertAll;
Var I,Done: Integer; Pr: TProf; Dst,Err: String; SP: TAP; Ok: Boolean;
Begin
 If NFiles=0 Then Begin Info('Ajoutez d''abord des fichiers '#224' convertir.'); Exit; End;
 Pr:=Profs[CurProf];
 If (OutDir<>'') And (Not DirExists(OutDir)) Then Begin
  {$I-}MkDir(OutDir);{$I+}
  If IOResult<>0 Then Begin Info('Dossier de sortie introuvable : '+OutDir); Exit; End;
 End;
 Stopped:=False; Running:=True; ProgMode:=False; Done:=0; Err:='';
 For I:=1 To NFiles Do Begin Files[I]^.Status:=0; Files[I]^.Pct:=0; Files[I]^.Msg:=''; End;
 SubTab:=0; Tab:=0; DrawAll;
 If MergeAll And InList(Pr.Ext,'MP3,WAV,AIF,AU,M4A,AAC') And (NFiles>1) Then Begin
  Ok:=MergeAudio(Pr,Dst,Err);
  If Ok Then Begin
   AddConverted(Dst); Inc(Done);
   For I:=1 To NFiles Do SetStatus(I,2,'-> '+NameOf(Dst));
  End Else For I:=1 To NFiles Do If Files[I]^.Status<>3 Then SetStatus(I,3,Err);
 End Else
 For I:=1 To NFiles Do Begin
  If Stopped Then Begin SetStatus(I,3,'Annul'#233); Continue; End;
  JobIdx:=I;
  SetStatus(I,1,'Conversion...'); Files[I]^.Pct:=0; DrawRowProgress;
  Dst:=UniqueOut(OutDir,BaseOf(Files[I]^.Path),Pr.Ext);
  FillChar(SP,SizeOf(SP),0); SP.Vol:=100; SP.Speed:=100;
  Err:='';
  Ok:=DoConvert(Files[I]^,Pr,Dst,SP,Err);
  If Ok Then Begin
   SetStatus(I,2,NameOf(Dst)+JobWarn); Files[I]^.OutFile:=Dst; Files[I]^.Pct:=100;
   AddConverted(Dst); Inc(Done);
  End Else Begin
   If Err='' Then Err:='Erreur.';
   SetStatus(I,3,Err); Files[I]^.Pct:=0; DelFile(Dst);
  End;
  DrawRowProgress;
 End;
 Running:=False; JobIdx:=0; Dirty:=True;
 If Stopped Then Info('Conversion arr'#234't'#233'e.|'+IStr(Done)+' fichier(s) converti(s).')
 Else If Done=0 Then Info('Aucun fichier converti. Le message d''erreur est affich'#233' sous chaque fichier.')
 Else Begin
  SubTab:=1;
  If AfterAct=2 Then Quit:=True
  Else Info(IStr(Done)+' fichier(s) converti(s) avec succ'#232's.|Dossier : '+OutDir);
 End;
End;

{ ====================================================================== }
{ Interface : barre de menus, onglets, ecran Convertisseur                  }
{ ====================================================================== }
Const
 MenuX: Array[1..5] Of Integer = (78,146,214,298,358);
 MenuW: Array[1..5] Of Integer = (56,56,72,48,32);
 TabNames: Array[0..4] Of String[16] = ('Convertisseur','Ripper','MV','Collage','Bo'#238'te '#224' outils');

Function BarHit(X: Integer): Integer;
Var I: Integer;
Begin
 BarHit:=0;
 For I:=1 To 5 Do
  If (X>=MenuX[I]-4) And (X<MenuX[I]+MenuW[I]+4) Then Begin BarHit:=I; Exit; End;
End;

Procedure DrawMenuBar(Active: Integer);
Const Names: Array[1..5] Of String[10] = ('Fichier',#201'dition','Affichage','Outils','Aide');
Var I: Integer;
Begin
 Rect(0,0,ScrW-1,17,cPanel); HLn(0,ScrW-1,17,cSteel);
 Disc(12,9,6,cBlue); Txt(9,6,'A',cWhite);
 Txt(24,5,'AnyMP4',cNavy);
 For I:=1 To 5 Do Begin
  If I=Active Then Begin Rect(MenuX[I]-4,1,MenuX[I]+MenuW[I]+3,16,cBlue); Txt(MenuX[I],5,Names[I],cWhite); End
  Else Txt(MenuX[I],5,Names[I],cBlack);
  HotAdd(MenuX[I]-4,0,MenuW[I]+8,17,hMenu+I);
 End;
 IcoKey(ScrW-130,3,cGrayD);
 Txt(ScrW-112,5,'Non enregistr'#233,cGrayD);
 HotAdd(ScrW-134,0,134,17,hMenu+9);
End;

Procedure DrawTabs;
Var I,X: Integer;
Begin
 Rect(0,18,ScrW-1,69,cBlue);
 For I:=0 To 4 Do Begin
  X:=44+I*108;
  If I=Tab Then Rect(X,18,X+103,69,cBlueL);
  Case I Of
   0: IcoFilm(X+36,20,cWhite);
   1: IcoDisc(X+36,20,cWhite);
   2: IcoMV(X+36,20,cWhite);
   3: IcoCollage(X+36,20,cWhite);
   4: IcoToolbox(X+36,20,cWhite);
  End;
  TxtC(X,X+103,56,TabNames[I],cWhite);
  HotAdd(X,18,104,52,hTab+I);
 End;
End;

Procedure DrawToolbar;
Begin
 Rect(0,70,ScrW-1,95,cWhite); HLn(0,ScrW-1,95,cLine);
 Case Tab Of
  0: Begin
   IcoPlus(18,83,7,cBlue);
   Txt(32,79,'Ajouter Fichier(s)',cNavy); Tri(186,83,0,cNavy);
   Frame(6,73,198,92,cLine);
   HotAdd(6,73,170,20,hAdd); HotAdd(176,73,28,20,hAddArrow);
   Panel(222,73,392,92,cWhite,cSteel);
   If SubTab=0 Then Rect(223,74,306,91,cSky) Else Rect(307,74,391,91,cSky);
   TxtC(223,306,79,'Conversion',cNavy); TxtC(307,391,79,'Converti',cNavy);
   HotAdd(223,74,84,18,hSubConv); HotAdd(307,74,84,18,hSubDone);
   TxtR(588,72,'NVIDIA | Intel | AMD',cGrayD);
   TxtR(588,83,'Acc'#233'l'#233'ration mat'#233'rielle',cBlack);
   Toggle(594,79,HwAccel,hHw);
   Txt(626,79,'?',cGrayD);
  End;
  1: Begin
   IcoPlus(18,83,7,cBlue); Txt(32,79,'Charger DVD',cNavy); Tri(130,83,0,cNavy);
   Frame(6,73,146,92,cLine);
   HotAdd(6,73,140,20,hAdd);
  End;
  2: Txt(12,79,'Cr'#233'ez un diaporama (MV) '#224' partir de vos images et ajoutez de la musique.',cGrayD);
  3: Txt(12,79,'Cr'#233'ez un collage d''images en choisissant un mod'#232'le.',cGrayD);
  4: Txt(12,79,'Outils pour l''audio (MP3, WAV, AAC...) et les images (BMP, GIF).',cGrayD);
 End;
End;

{ Cache de miniatures (images/GIF reduits) }
Type TTh = Record Path: String[200]; Img: PImg; End;
Var ThC: Array[0..15] Of TTh; ThN: Integer; ThFail: Array[0..15] Of String[200]; ThFN: Integer;

Function GetThumb(Const Path: String): PImg;
Var K: Integer; A: PAnim; T: PImg; V: PImg;
Begin
 GetThumb:=Nil;
 For K:=0 To 15 Do If (ThC[K].Img<>Nil) And (ThC[K].Path=Path) Then Begin GetThumb:=ThC[K].Img; Exit; End;
 For K:=0 To 15 Do If ThFail[K]=Path Then Exit;
 If Not LoadAnim(Path,A,1) Then Begin
  {$IFDEF FPC}
  V:=VideoFirstFrame(Path,ExtOf(Path));
  If V<>Nil Then Begin
   New(A); A^.N:=1; A^.F[1]:=V; A^.Dly[1]:=100;
  End Else
  {$ENDIF}
  Begin ThFail[ThFN Mod 16]:=Path; Inc(ThFN); Exit; End;
 End;
 T:=ImgFit(A^.F[1],Min(A^.F[1]^.W,160),Min(A^.F[1]^.H,100),0,0,0,False);
 If T<>Nil Then Begin
  { retire les bandes de fond : on garde le rapport via un redimensionnement exact }
  ImgFree(T);
  If A^.F[1]^.W*100>A^.F[1]^.H*160 Then T:=ImgScale(A^.F[1],160,Max(1,(A^.F[1]^.H*160) Div A^.F[1]^.W))
  Else T:=ImgScale(A^.F[1],Max(1,(A^.F[1]^.W*100) Div A^.F[1]^.H),100);
 End;
 AnimFree(A);
 If T=Nil Then Exit;
 K:=ThN Mod 16; Inc(ThN);
 ImgFree(ThC[K].Img); ThC[K].Img:=T; ThC[K].Path:=Path;
 GetThumb:=T;
End;

{ Miniature d'un media dans une zone 80x50 }
Procedure DrawThumb(Var M: TMedia; X,Y: Integer);
Var Im: PImg;
Begin
 Panel(X,Y,X+79,Y+49,cNavy,cSteel);
 Im:=Nil;
 If (M.Kind=3) Or (M.Kind=2) Then Im:=GetThumb(M.Path);
 If Im<>Nil Then DrawImg(Im,X+1,Y+1,78,48)
 Else Begin
  If M.Kind=1 Then Begin
   SetColor(cBlueL); Circle(X+40,Y+25,14);
   Line(X+28,Y+25,X+32,Y+18); Line(X+32,Y+18,X+36,Y+32); Line(X+36,Y+32,X+40,Y+14);
   Line(X+40,Y+14,X+44,Y+34); Line(X+44,Y+34,X+48,Y+20); Line(X+48,Y+20,X+52,Y+25);
  End Else Begin
   Rect(X+20,Y+12,X+60,Y+38,cBlue);
   Tri(X+41,Y+25,2,cWhite);
   SetColor(cSky); Rectangle(X+20,Y+12,X+60,Y+38);
  End;
 End;
 TxtR(X+78,Y+40,TimeStr(M.DurMs),cWhite);
End;

Function MediaShort(Var M: TMedia): String;
Var S: String;
Begin
 S:=M.Fmt;
 If M.W>0 Then S:=S+' '+IStr(M.W)+'x'+IStr(M.H);
 If (M.Kind=1) And (M.Rate>0) Then Begin
  S:=S+' '+IStr(M.Rate)+'Hz';
  If M.Chans=1 Then S:=S+' mono' Else If M.Chans=2 Then S:=S+' st'#233'r'#233'o';
 End;
 MediaShort:=S+' '+SizeStr(M.Size);
End;

Function OutInfo(Var M: TMedia): String;
Var Pr: TProf; S: String;
Begin
 Pr:=Profs[CurProf];
 S:=Pr.Ext;
 If InList(Pr.Ext,'MP3,WAV,AIF,AU,M4A,AAC') Then Begin
  If Pr.AKb>0 Then S:=S+'  '+IStr(Pr.AKb)+' kbps';
  S:=S+' '+TimeStr(M.DurMs);
 End Else Begin
  If M.W>0 Then S:=S+' '+IStr(M.W)+'x'+IStr(M.H) Else If Pr.Res<>'-' Then S:=S+' '+Pr.Res;
  S:=S+' '+TimeStr(M.DurMs);
 End;
 OutInfo:=S;
End;

Procedure DrawRow(I: Integer; Y: Integer);
Var M: PMedia; Pr: TProf; S: String;
Begin
 M:=Files[I]; Pr:=Profs[CurProf];
 Panel(8,Y,ScrW-22,Y+60,cWhite,cLine);
 Rect(9,Y+1,ScrW-23,Y+59,cPanel);
 DrawThumb(M^,14,Y+5);
 S:='Source: '+Fit(NameOf(M^.Path),210);
 Txt(104,Y+6,S,cBlack);
 IcoInfo(104+TextW(S)+6,Y+5,cBlue);
 HotAdd(100,Y+3,TextW(S)+24,12,107+I*10);
 Txt(104,Y+19,Fit(MediaShort(M^),220),cGrayD);
 IcoStar(104,Y+38,cBlue); HotAdd(102,Y+36,16,16,100+I*10);
 IcoScissors(128,Y+38,cBlue); HotAdd(126,Y+36,16,16,101+I*10);
 IcoPalette(152,Y+38,cBlue); HotAdd(150,Y+36,16,16,102+I*10);
 If (M^.Rot<>0) Or M^.FlipH Or M^.FlipV Or (M^.CropW>0) Or (M^.Bright<>0) Or (M^.Contr<>0) Or M^.WmOn Or (M^.TrimS>0) Or (M^.TrimE>0) Or (M^.Vol<>100) Or (M^.ADelay<>0) Then
  Disc(176,Y+44,3,cOrange);
 Tri(332,Y+30,2,cSteel); Tri(338,Y+30,2,cSteel);
 Txt(356,Y+6,'Sortie: '+Fit(BaseOf(M^.Path)+'.'+LowExt(Pr.Ext),170),cBlack);
 Txt(356,Y+19,Fit(OutInfo(M^),170),cGrayD);
 Combo(356,Y+34,82,16,'Piste 1',105+I*10);
 If M^.SubFile<>'' Then Combo(444,Y+34,86,16,Fit(NameOf(M^.SubFile),60),106+I*10)
 Else Combo(444,Y+34,86,16,'Sous-titre',106+I*10);
 Panel(538,Y+8,ScrW-52,Y+26,cBlue,cBlue);
 TxtC(538,ScrW-52,Y+13,Pr.Ext,cWhite);
 HotAdd(538,Y+8,ScrW-52-538+1,19,103+I*10);
 IcoClose(ScrW-44,Y+10,cGrayD); HotAdd(ScrW-48,Y+6,16,16,104+I*10);
 Case M^.Status Of
  1: ProgBar(104,Y+54,ScrW-22-104-6,5,M^.Pct);
  2: Begin Rect(104,Y+54,ScrW-28,Y+57,cGreen); Txt(538,Y+34,#251+' Termin'#233,cGreen); End;
  3: Txt(104,Y+53,Fit(M^.Msg,ScrW-140),cRed);
 End;
End;

Procedure DrawRowProgress;
Var Y,Save: Integer;
Begin
 If (Tab<>0) Or (SubTab<>0) Or (JobIdx<1) Or (JobIdx>NFiles) Then Exit;
 HideMouse;
 If (JobIdx<=ListTop) Or (JobIdx>ListTop+RowsVis) Then Begin
  ListTop:=Clip(JobIdx-1,0,Max(0,NFiles-RowsVis)); HotClear; DrawConvertScreen;
 End Else Begin
  Save:=HotN; Y:=ListY+(JobIdx-ListTop-1)*RowH;
  DrawRow(JobIdx,Y); HotN:=Save;
 End;
 ShowMouse;
End;

Procedure Para(X,Y,W: Integer; Const S: String; C: Byte);
Var T,L: String; N: Integer;
Begin
 T:=S; N:=W Div 8;
 While T<>'' Do Begin
  L:=WrapLine(T,N);
  Txt(X,Y,L,C); Inc(Y,12);
 End;
End;

Procedure DrawEmptyState;
Var X: Integer; S1,S2,S3: String;
Begin
 S1:=#201'tape 1 : Cliquez sur'; S2:=#201'tape 2 : Cliquez sur Format de sortie'; S3:=#201'tape 3 : Cliquez sur';
 SetLineStyle(DashedLn,0,1); SetColor(cSteel); Rectangle(70,106,570,290); SetLineStyle(SolidLn,0,1);
 SetColor(cBlue); Circle(320,150,22); Circle(320,150,21);
 Line(320,138,320,162); Line(308,150,332,150); Line(320,139,320,161);
 TxtC(70,570,186,'Commencer',cBlack);
 X:=110;
 Txt(X,214,S1,cBlack); IcoPlus(X+TextW(S1)+14,218,6,cBlue);
 Txt(X+TextW(S1)+26,214,'Ajouter Fichier(s)',cBlack);
 Txt(X,236,S2,cBlack);
 Combo(X+TextW(S2)+8,230,64,16,Profs[CurProf].Ext,hFmt);
 Txt(X,258,S3,cBlack);
 Button(X+TextW(S3)+8,252,100,16,'Convertir Tout',0,bsPrimary);
 Txt(X+TextW(S3)+116,258,'pour lancer',cBlack);
 HotAdd(70,106,500,184,hAdd);
 Para(12,302,616,'AnyMP4 Convertisseur Vid'#233'o Ultimate - Votre convertisseur, '#233'diteur et am'#233'lioreur tout-en-un aliment'#233' par 14 ans d''innovation. Lib'#233'rez la magie de l''IA sur plus de 500 formats pour la vid'#233'o, l''audio, DVD et les images.',cGrayD);
End;

Procedure DrawDoneList;
Var I,Y: Integer;
Begin
 If NConv=0 Then Begin
  TxtC(0,ScrW-1,200,'Aucun fichier converti pour le moment.',cGrayD);
  Exit;
 End;
 For I:=1 To Min(NConv,RowsVis+1) Do Begin
  Y:=ListY+(I-1)*40;
  Panel(8,Y,ScrW-22,Y+36,cWhite,cLine);
  IcoFilm(12,Y+2,cSteel);
  Txt(52,Y+8,Fit(NameOf(Converted[NConv-I+1]),400),cBlack);
  Txt(52,Y+20,Fit(DirOf(Converted[NConv-I+1]),340)+'  '+SizeStr(FileSizeOf(Converted[NConv-I+1])),cGrayD);
  Button(500,Y+8,52,20,'Infos',107+I*10,bsNormal);
  Button(558,Y+8,58,20,'Suppr.',104+I*10,bsNormal);
 End;
End;

Procedure DrawFooter;
Begin
 Rect(0,400,ScrW-1,ScrH-1,cPanel); HLn(0,ScrW-1,400,cSteel);
 Txt(10,413,'Format de sortie:',cBlack);
 Combo(150,408,172,22,Profs[CurProf].Name+' ('+Profs[CurProf].Ext+')',hFmt);
 Panel(328,408,350,429,cWhite,cSteel); IcoGear(333,413,cNavy); HotAdd(328,408,23,22,hFmtGear);
 Txt(366,413,'Conversion 120'#215' plus rapide',cBlack);
 Toggle(592,413,Fast120,hFast);
 Txt(10,447,'Enregistrer:',cBlack);
 Combo(150,442,210,22,OutDir,hDir);
 Panel(366,442,388,463,cWhite,cSteel); IcoFolder(370,446,cGold); HotAdd(366,442,23,22,hDirBtn);
 CheckBox(402,447,'Fusionner en un seul fichier',MergeAll,hMerge);
 If Running Then Begin
  Button(548,438,84,32,'Arr'#234'ter',0,bsBlue);
  CancelX1:=548; CancelY1:=438; CancelX2:=631; CancelY2:=469;
 End Else Begin
  Button(496,436,136,34,'Convertir Tout',hConvAll,bsPrimary);
 End;
End;

Procedure DrawConvertScreen;
Var I: Integer;
Begin
 Rect(0,96,ScrW-1,399,cWhite);
 If SubTab=1 Then Begin DrawDoneList; Exit; End;
 If NFiles=0 Then DrawEmptyState
 Else Begin
  For I:=1 To RowsVis Do Begin
   If ListTop+I>NFiles Then Break;
   DrawRow(ListTop+I,ListY+(I-1)*RowH);
  End;
  Panel(ScrW-18,ListY,ScrW-4,ListY+RowsVis*RowH-4,cLine,cSteel);
  Tri(ScrW-11,ListY+7,1,cNavy); Tri(ScrW-11,ListY+RowsVis*RowH-12,0,cNavy);
  HotAdd(ScrW-18,ListY,14,16,hScrUp); HotAdd(ScrW-18,ListY+RowsVis*RowH-20,14,16,hScrDn);
  Txt(12,ListY+RowsVis*RowH-2,IStr(NFiles)+' fichier(s)',cGrayD);
 End;
End;

{ ====================================================================== }
{ Video MP4 : demuxeurs MP4/MOV et FLV, decodage H.264, encodage H.264,     }
{ multiplexeur MP4 (video H.264 + audio AAC)                                 }
{ ====================================================================== }
{$IFDEF FPC}
Type
 TLArr = Array[0..0] Of LongInt;
 PLArr = ^TLArr;
 TBArr = Array[0..0] Of Byte;
 PBArr = ^TBArr;
 TTrkIn = Record
  Ok,IsVideo: Boolean;
  Codec: String[4];
  Ts: LongInt;
  W,H,Chans: Integer;
  Rate: LongInt;
  N: LongInt;
  Off,Sz,Dur,Cts: PLArr;
  Sync: PBArr;
  Cfg: Array[0..511] Of Byte;
  CfgLen: Integer;
  Oti: Integer;
 End;
 PTrkIn = ^TTrkIn;

 TMuxTrk = Record
  T: PTrkIn;
  First,Last: LongInt;       { fenetre d'echantillons [First..Last] }
  Mem: PBArr;                { source en memoire (sinon fichier Path) }
  Path: String[200];
  Annex: Boolean;            { echantillons Annex B a convertir en AVCC }
  F: File;
  Opened: Boolean;
  OutSz: PLArr;
  ChOff,ChCnt: PLArr;
  NCh: LongInt;
 End;

Var
 SBuf: PBArr;
 SBufCap: LongInt;
 Cnt32: Word;
 CvBuf: PBArr;
 CvCap: LongInt;
 VFrameCb: Procedure(B: PEABuffer; W,H: LongInt);
 VStopFlag: Boolean;
 VF: File;
 VFOpen: Boolean;
 VOk: Boolean;
 VErr: String;

Procedure TrkClear(Var T: TTrkIn);
Begin
 If T.N>0 Then Begin
  FreeMem(T.Off,T.N*4+16); FreeMem(T.Sz,T.N*4+16); FreeMem(T.Dur,T.N*4+16); FreeMem(T.Cts,T.N*4+16); FreeMem(T.Sync,T.N+16);
 End;
 FillChar(T,SizeOf(T),0);
End;

Procedure TrkAlloc(Var T: TTrkIn; N: LongInt);
Begin
 T.N:=N;
 GetMem(T.Off,N*4+16); GetMem(T.Sz,N*4+16); GetMem(T.Dur,N*4+16); GetMem(T.Cts,N*4+16); GetMem(T.Sync,N+16);
 FillChar(T.Off^,N*4+16,0); FillChar(T.Sz^,N*4+16,0); FillChar(T.Dur^,N*4+16,0); FillChar(T.Cts^,N*4+16,0);
 FillChar(T.Sync^,N+16,1);
End;

Procedure NeedBuf(Var B: PBArr; Var Cap: LongInt; N: LongInt);
Begin
 If N+64>Cap Then Begin
  If B<>Nil Then FreeMem(B,Cap);
  Cap:=N+65536; GetMem(B,Cap);
 End;
End;

{ ---------------------------------------------------------------------- }
{ Demuxeur MP4 / MOV                                                         }
{ ---------------------------------------------------------------------- }
Function BoxEndOf(Pl: LongInt): LongInt;
Begin
 If B32(Pl-8)=1 Then BoxEndOf:=Pl-16+B32(Pl-4) Else BoxEndOf:=Pl-8+B32(Pl-8);
End;

Function BoxChild(S,En: LongInt; Const Nm: String; Var Pl: LongInt): Boolean;
Var Q,Z,H: LongInt;
Begin
 BoxChild:=False; Q:=S;
 While Q+8<=En Do Begin
  Z:=B32(Q); H:=8;
  If Z=1 Then Begin Z:=B32(Q+12); H:=16; End;
  If Z<8 Then Break;
  If C4(Q+4)=Nm Then Begin Pl:=Q+H; BoxChild:=True; Exit; End;
  Q:=Q+Z;
 End;
End;

Procedure Mp4ParseTrak(Tr,TrEnd: LongInt; Var V,A: TTrkIn);
Var Md,Hd,Mh,Mi,Sb,Sd,Ss,Sc,Sz,Co,Tt,Ct,Se,Cc: LongInt; Co64: Boolean; Kind: String; T: PTrkIn;
 N,I,K,C,Nc,Nsc,Si,Spc,NextFirst,Sci,Off,Cnt,Del,E,P,L: LongInt; Fc: String; Fixed: LongInt; Tg: Byte;
Begin
 If Not BoxChild(Tr,TrEnd,'mdia',Md) Then Exit;
 If Not BoxChild(Md,BoxEndOf(Md),'hdlr',Hd) Then Exit;
 Kind:=C4(Hd+8);
 If Kind='vide' Then Begin If V.Ok Then Exit; T:=@V; End
 Else If Kind='soun' Then Begin If A.Ok Then Exit; T:=@A; End
 Else Exit;
 If Not BoxChild(Md,BoxEndOf(Md),'mdhd',Mh) Then Exit;
 If CB(Mh)=1 Then T^.Ts:=B32(Mh+20) Else T^.Ts:=B32(Mh+12);
 If T^.Ts<=0 Then Exit;
 If Not BoxChild(Md,BoxEndOf(Md),'minf',Mi) Then Exit;
 If Not BoxChild(Mi,BoxEndOf(Mi),'stbl',Sb) Then Exit;
 E:=BoxEndOf(Sb);
 If Not (BoxChild(Sb,E,'stsd',Sd) And BoxChild(Sb,E,'stsz',Sz) And BoxChild(Sb,E,'stsc',Sc) And BoxChild(Sb,E,'stts',Tt)) Then Exit;
 Co64:=False;
 If Not BoxChild(Sb,E,'stco',Co) Then Begin If BoxChild(Sb,E,'co64',Co) Then Co64:=True Else Exit; End;
 T^.IsVideo:=Kind='vide';
 Fc:=C4(Sd+12); T^.Codec:=Fc;
 If T^.IsVideo Then Begin
  T^.W:=B16(Sd+8+32); T^.H:=B16(Sd+8+34);
  { enregistrement avcC dans les sous-boites de l'entree }
  If BoxChild(Sd+8+86,BoxEndOf(Sd),'avcC',P) Then Begin
   L:=BoxEndOf(P)-P; If L>500 Then L:=500;
   For I:=0 To L-1 Do T^.Cfg[I]:=CB(P+I);
   T^.CfgLen:=L;
  End;
 End Else Begin
  T^.Chans:=B16(Sd+8+24); T^.Rate:=B16(Sd+8+32);
  If BoxChild(Sd+8+36,BoxEndOf(Sd),'esds',P) Then Begin
   P:=P+4;
   E:=BoxEndOf(Sd);
   Tg:=0; T^.Oti:=0;
   While P<E Do Begin
    Tg:=CB(P); Inc(P); Cnt:=0;
    For K:=1 To 4 Do Begin Cnt:=Cnt*128+(CB(P) And $7F); Inc(P); If (CB(P-1) And $80)=0 Then Break; End;
    Case Tg Of
     3: Inc(P,3);
     4: Begin T^.Oti:=CB(P); Inc(P,13); End;
     5: Begin
      If Cnt>20 Then Cnt:=20;
      For I:=0 To Cnt-1 Do T^.Cfg[I]:=CB(P+I);
      T^.CfgLen:=Cnt; Break;
     End;
     Else Inc(P,Cnt);
    End;
   End;
  End;
  If (Fc='mp4a') And (T^.Oti=$40) Then T^.Codec:='mp4a' Else If Fc='mp4a' Then T^.Codec:='mp4?';
 End;
 Fixed:=B32(Sz+4); N:=B32(Sz+8);
 If (N<1) Or (N>3000000) Then Exit;
 TrkAlloc(T^,N);
 For I:=0 To N-1 Do If Fixed<>0 Then T^.Sz^[I]:=Fixed Else T^.Sz^[I]:=B32(Sz+12+I*4);
 { echantillons -> chunks }
 If Co64 Then Nc:=B32(Co+4) Else Nc:=B32(Co+4);
 Nsc:=B32(Sc+4); Si:=0; Sci:=0;
 Spc:=B32(Sc+12);
 If Nsc>1 Then NextFirst:=B32(Sc+8+12) Else NextFirst:=2147483647;
 For C:=1 To Nc Do Begin
  While (C>=NextFirst) And (Sci+1<Nsc) Do Begin
   Inc(Sci); Spc:=B32(Sc+12+Sci*12);
   If Sci+1<Nsc Then NextFirst:=B32(Sc+8+(Sci+1)*12) Else NextFirst:=2147483647;
  End;
  If Co64 Then Off:=B32(Co+8+(C-1)*8+4) Else Off:=B32(Co+8+(C-1)*4);
  For K:=1 To Spc Do Begin
   If Si>=N Then Break;
   T^.Off^[Si]:=Off; Inc(Off,T^.Sz^[Si]); Inc(Si);
  End;
 End;
 { durees }
 Cnt:=B32(Tt+4); Si:=0;
 For I:=0 To Cnt-1 Do Begin
  K:=B32(Tt+8+I*8); Del:=B32(Tt+12+I*8);
  While (K>0) And (Si<N) Do Begin T^.Dur^[Si]:=Del; Inc(Si); Dec(K); End;
 End;
 { decalages de composition }
 If BoxChild(Sb,E,'ctts',Ct) Then Begin
  Cnt:=B32(Ct+4); Si:=0;
  For I:=0 To Cnt-1 Do Begin
   K:=B32(Ct+8+I*8); Del:=B32(Ct+12+I*8);
   While (K>0) And (Si<N) Do Begin T^.Cts^[Si]:=Del; Inc(Si); Dec(K); End;
  End;
 End;
 If BoxChild(Sb,E,'stss',Se) Then Begin
  FillChar(T^.Sync^,N,0);
  Cnt:=B32(Se+4);
  For I:=0 To Cnt-1 Do Begin K:=B32(Se+8+I*4)-1; If (K>=0) And (K<N) Then T^.Sync^[K]:=1; End;
 End;
 T^.Ok:=True;
End;

Function Mp4Tracks(Const Path: String; Var V,A: TTrkIn; Var Err: String): Boolean;
Var Mo,Q,Z,H,Tr: LongInt;
Begin
 Mp4Tracks:=False; FillChar(V,SizeOf(V),0); FillChar(A,SizeOf(A),0);
 If Not COpen(Path) Then Begin Err:='Ouverture impossible.'; Exit; End;
 If Not BoxChild(0,CSize,'moov',Mo) Then Begin CClose; Err:='Bo'#238'te moov introuvable (MP4 fragment'#233' non pris en charge).'; Exit; End;
 Q:=Mo;
 While Q+8<=BoxEndOf(Mo) Do Begin
  Z:=B32(Q); H:=8; If Z=1 Then Begin Z:=B32(Q+12); H:=16; End;
  If Z<8 Then Break;
  If C4(Q+4)='trak' Then Mp4ParseTrak(Q+H,Q+Z,V,A);
  Q:=Q+Z;
 End;
 CClose;
 Mp4Tracks:=V.Ok Or A.Ok;
 If Not (V.Ok Or A.Ok) Then Err:='Aucune piste lisible.';
End;

{ ---------------------------------------------------------------------- }
{ Demuxeur FLV (H.264 + AAC)                                                  }
{ ---------------------------------------------------------------------- }
Function FlvTracks(Const Path: String; Var V,A: TTrkIn; Var Err: String): Boolean;
Var P,Sz,Nv,Na,Pass,Iv,Ia,Ts,Tsv,Tsa: LongInt; Ty,Fl,Pk: Byte; I,L: Integer; LastV,LastA: LongInt;
Begin
 FlvTracks:=False; FillChar(V,SizeOf(V),0); FillChar(A,SizeOf(A),0);
 If Not COpen(Path) Then Begin Err:='Ouverture impossible.'; Exit; End;
 For Pass:=1 To 2 Do Begin
  P:=B32(5)+4; Nv:=0; Na:=0; LastV:=-1; LastA:=-1;
  While P+15<CSize Do Begin
   Ty:=CB(P); Sz:=LongInt(CB(P+1))*65536+B16(P+2);
   Ts:=LongInt(CB(P+4))*65536+B16(P+5)+LongInt(CB(P+7))*16777216;
   If (Ty=9) And (Sz>5) And ((CB(P+11) And 15)=7) Then Begin
    Pk:=CB(P+12);
    If Pk=0 Then Begin
     If Pass=2 Then Begin
      L:=Sz-5; If L>500 Then L:=500;
      For I:=0 To L-1 Do V.Cfg[I]:=CB(P+16+I); V.CfgLen:=L;
     End;
    End Else If Pk=1 Then Begin
     If Pass=2 Then Begin
      Iv:=Nv; V.Off^[Iv]:=P+16; V.Sz^[Iv]:=Sz-5; V.Sync^[Iv]:=Ord((CB(P+11) Shr 4)=1);
      V.Cts^[Iv]:=LongInt(CB(P+13))*65536+B16(P+14);
      If V.Cts^[Iv]>=8388608 Then V.Cts^[Iv]:=V.Cts^[Iv]-16777216;
      V.Dur^[Iv]:=Ts; { dts provisoire }
     End;
     Inc(Nv);
    End;
   End Else If (Ty=8) And (Sz>2) And ((CB(P+11) Shr 4)=10) Then Begin
    Pk:=CB(P+12);
    If Pk=0 Then Begin
     If Pass=2 Then Begin
      L:=Sz-2; If L>20 Then L:=20;
      For I:=0 To L-1 Do A.Cfg[I]:=CB(P+13+I); A.CfgLen:=L;
     End;
    End Else Begin
     If Pass=2 Then Begin
      Ia:=Na; A.Off^[Ia]:=P+13; A.Sz^[Ia]:=Sz-2; A.Dur^[Ia]:=1024;
     End;
     Inc(Na);
    End;
   End;
   P:=P+11+Sz+4;
  End;
  If Pass=1 Then Begin
   If Nv>0 Then Begin TrkAlloc(V,Nv); V.Ts:=1000; End;
   If Na>0 Then Begin TrkAlloc(A,Na); A.Ts:=44100; End;
  End;
 End;
 CClose;
 If V.N>0 Then Begin
  V.Ok:=True; V.IsVideo:=True; V.Codec:='avc1';
  { durees a partir des dts (stockes provisoirement dans Dur) }
  For I:=0 To V.N-2 Do V.Dur^[I]:=V.Dur^[I+1]-V.Dur^[I];
  If V.N>1 Then V.Dur^[V.N-1]:=V.Dur^[V.N-2] Else V.Dur^[0]:=40;
  For I:=0 To V.N-1 Do If V.Dur^[I]<=0 Then V.Dur^[I]:=1;
 End;
 If A.N>0 Then Begin
  A.Ok:=True; A.IsVideo:=False; A.Codec:='mp4a'; A.Oti:=$40;
  If A.CfgLen>=2 Then Begin
   Case ((A.Cfg[0] And 7) Shl 1) Or (A.Cfg[1] Shr 7) Of
    0: A.Rate:=96000; 1: A.Rate:=88200; 2: A.Rate:=64000; 3: A.Rate:=48000; 4: A.Rate:=44100; 5: A.Rate:=32000;
    6: A.Rate:=24000; 7: A.Rate:=22050; 8: A.Rate:=16000; 9: A.Rate:=12000; 10: A.Rate:=11025; Else A.Rate:=8000;
   End;
   A.Chans:=(A.Cfg[1] Shr 3) And 15; If A.Chans<1 Then A.Chans:=2;
   A.Ts:=A.Rate;
  End;
 End;
 FlvTracks:=V.Ok Or A.Ok;
 If Not (V.Ok Or A.Ok) Then Err:='Aucune piste H.264/AAC dans ce FLV.';
End;

{ ---------------------------------------------------------------------- }
{ Demuxeur AVI (piste video)                                                 }
{ ---------------------------------------------------------------------- }
Function AviTracks(Const Path: String; Var V: TTrkIn; Var Err: String): Boolean;
Var P,Sz,Mv,MvEnd,Pass,N,I: LongInt; Want,Id,Strh,Fcc: String; VidIdx,Cur: Integer; Scale,Rate,W,H: LongInt; Have: Boolean;
 Procedure Hdrl(S,En: LongInt);
 Var Q,Z: LongInt; K: String;
 Begin
  Q:=S;
  While Q+8<=En Do Begin
   K:=C4(Q); Z:=L32(Q+4);
   If Z<0 Then Break;
   If K='LIST' Then Begin
    If C4(Q+8)='strl' Then Begin Strh:=''; Hdrl(Q+12,Q+8+Z); Inc(Cur); End
    Else Hdrl(Q+12,Q+8+Z);
   End Else If K='strh' Then Begin
    Strh:=C4(Q+8);
    If (Strh='vids') And Not Have Then Begin Scale:=L32(Q+28); Rate:=L32(Q+32); Fcc:=C4(Q+12); End;
   End Else If (K='strf') And (Strh='vids') And Not Have Then Begin
    Have:=True; VidIdx:=Cur; W:=L32(Q+12); H:=Abs(L32(Q+16));
    If L32(Q+24)<>0 Then Fcc:=C4(Q+24);
   End;
   Q:=Q+8+Z+(Z And 1);
  End;
 End;
Begin
 AviTracks:=False; FillChar(V,SizeOf(V),0); Have:=False; Cur:=0; VidIdx:=0; Scale:=1; Rate:=25; Fcc:=''; Strh:='';
 If Not COpen(Path) Then Begin Err:='Ouverture impossible.'; Exit; End;
 If (C4(0)<>'RIFF') Or (C4(8)<>'AVI ') Then Begin CClose; Err:='Fichier AVI invalide.'; Exit; End;
 Mv:=0; MvEnd:=0; P:=12;
 While P+12<=CSize Do Begin
  Id:=C4(P); Sz:=L32(P+4);
  If Sz<0 Then Break;
  If (Id='LIST') And (C4(P+8)='hdrl') Then Hdrl(P+12,P+8+Sz);
  If (Id='LIST') And (C4(P+8)='movi') Then Begin Mv:=P+12; MvEnd:=Min(P+8+Sz,CSize); Break; End;
  P:=P+8+Sz+(Sz And 1);
 End;
 If (Not Have) Or (Mv=0) Then Begin CClose; Err:='Aucune piste vid'#233'o dans cet AVI.'; Exit; End;
 If (Scale<=0) Or (Rate<=0) Then Begin Scale:=1; Rate:=25; End;
 Want:=Pad2(VidIdx);
 For Pass:=1 To 2 Do Begin
  P:=Mv; N:=0;
  While P+8<=MvEnd Do Begin
   Id:=C4(P); Sz:=L32(P+4);
   If Sz<0 Then Break;
   If Id='LIST' Then Begin Inc(P,12); Continue; End;
   If (Copy(Id,1,2)=Want) And ((Copy(Id,3,2)='dc') Or (Copy(Id,3,2)='db')) Then Begin
    If Pass=2 Then Begin V.Off^[N]:=P+8; V.Sz^[N]:=Min(Sz,CSize-P-8); V.Dur^[N]:=Scale; End;
    Inc(N);
   End;
   P:=P+8+Sz+(Sz And 1);
  End;
  If Pass=1 Then Begin
   If N<1 Then Begin CClose; Err:='Aucune image vid'#233'o dans cet AVI.'; Exit; End;
   TrkAlloc(V,N);
  End;
 End;
 CClose;
 V.Ok:=True; V.IsVideo:=True; V.Codec:=Copy(UpStr(Fcc),1,4); V.Ts:=Rate; V.W:=W; V.H:=H;
 AviTracks:=True;
End;


{ ---------------------------------------------------------------------- }
{ Demuxeur Matroska / WebM (H.264, MPEG-4 ASP, AAC, MP3, PCM)                  }
{ ---------------------------------------------------------------------- }
{$IFDEF FPC}
Function EbVInt(Var P: LongInt; Keep: Boolean): Int64;
Var B,Mask: Byte; N,I: Integer; V: Int64;
Begin
 B:=CB(P); Mask:=$80; N:=1;
 While (N<=8) And ((B And Mask)=0) Do Begin Mask:=Mask Shr 1; Inc(N); End;
 If N>8 Then Begin EbVInt:=-1; Inc(P); Exit; End;
 If Keep Then V:=B Else V:=B And (Mask-1);
 For I:=1 To N-1 Do V:=V*256+CB(P+I);
 Inc(P,N); EbVInt:=V;
End;

Type
 TMkTrk = Record
  Num: LongInt; Typ: Integer; Codec: String[24];
  PrivPos,PrivLen: LongInt; W,H,Ch,Bits: LongInt; Rate: LongInt; Dd: LongInt; Used: Boolean;
 End;

Var
 MkT: Array[0..7] Of TMkTrk;
 MkN: Integer;
 MkScale: LongInt;
 MkCnt: Array[0..1] Of LongInt;
 MkFill: Boolean;
 MkTr: Array[0..1] Of PTrkIn;
 MkNum: Array[0..1] Of LongInt;
 MkIdx: Array[0..1] Of LongInt;
 MkPts: PLArr;

Function EbUInt(P: LongInt; N: Integer): Int64;
Var I: Integer; V: Int64;
Begin
 V:=0; For I:=0 To N-1 Do V:=V*256+CB(P+I);
 EbUInt:=V;
End;

Procedure MkTrackEntry(S,En: LongInt);
Var Q,Id,Sz,Dp,P2,E2,I2,Z2: Int64; T: TMkTrk; Qq: LongInt; Qid,Qsz,Qd: LongInt;
 Procedure Sub(S2,E3: LongInt);
 Var R,Ri,Rs,Rd: LongInt;
 Begin
  R:=S2;
  While R<E3 Do Begin
   Ri:=EbVInt(R,True); Rs:=EbVInt(R,False); Rd:=R;
   If Ri=$B0 Then T.W:=EbUInt(Rd,Rs) Else If Ri=$BA Then T.H:=EbUInt(Rd,Rs)
   Else If Ri=$9F Then T.Ch:=EbUInt(Rd,Rs) Else If Ri=$6264 Then T.Bits:=EbUInt(Rd,Rs)
   Else If Ri=$B5 Then T.Rate:=Round(BEDouble(Rd,Rs));
   R:=Rd+Rs;
  End;
 End;
Begin
 FillChar(T,SizeOf(T),0);
 Qq:=S;
 While Qq<En Do Begin
  Qid:=EbVInt(Qq,True); Qsz:=EbVInt(Qq,False); Qd:=Qq;
  If (Qid<0) Or (Qsz<0) Then Break;
  Case Qid Of
   $D7: T.Num:=EbUInt(Qd,Qsz);
   $83: T.Typ:=EbUInt(Qd,Qsz);
   $86: T.Codec:=CStr(Qd,Min(Qsz,24));
   $63A2: Begin T.PrivPos:=Qd; T.PrivLen:=Qsz; End;
   $23E383: T.Dd:=EbUInt(Qd,Qsz);
   $E0,$E1: Sub(Qd,Qd+Qsz);
  End;
  Qq:=Qd+Qsz;
 End;
 If MkN<8 Then Begin MkT[MkN]:=T; Inc(MkN); End;
End;

Procedure MkAddBlock(P,Sz: LongInt; Sync: Integer; Cluster: LongInt);
Var Q,Num,K,Hdr: LongInt; Tc: LongInt; Fl: Byte; Pts: LongInt;
Begin
 Q:=P; Num:=EbVInt(Q,False);
 Tc:=B16(Q); If Tc>=32768 Then Tc:=Tc-65536;
 Fl:=CB(Q+2); Hdr:=(Q+3)-P;
 If (Fl And 6)<>0 Then Exit;
 For K:=0 To 1 Do If (MkTr[K]<>Nil) Or Not MkFill Then
  If Num=MkNum[K] Then Begin
   Pts:=Round((Cluster+Tc)*(MkScale/1000000.0));
   If MkFill Then Begin
    If MkTr[K]^.N>MkIdx[K] Then Begin
     MkTr[K]^.Off^[MkIdx[K]]:=P+Hdr; MkTr[K]^.Sz^[MkIdx[K]]:=Sz-Hdr; If Sync=2 Then Sync:=Ord((Fl And $80)<>0);
     MkTr[K]^.Sync^[MkIdx[K]]:=Ord((Sync<>0) Or (K=1));
     If K=0 Then MkPts^[MkIdx[K]]:=Pts;
     Inc(MkIdx[K]);
    End;
   End Else Inc(MkCnt[K]);
  End;
End;

Procedure MkCluster(S,En: LongInt);
Var Q,Id,Sz,Dp,Tc,Z,Z2,Zd,Zi,Zs: LongInt; HasRef: Boolean; Bp,Bs: LongInt;
Begin
 Q:=S; Tc:=0;
 While Q<En Do Begin
  Id:=EbVInt(Q,True); Sz:=EbVInt(Q,False); Dp:=Q;
  If (Id<0) Or (Sz<0) Then Break;
  If Dp+Sz>En Then Sz:=En-Dp;
  Case Id Of
   $E7: Tc:=EbUInt(Dp,Sz);
   $A3: MkAddBlock(Dp,Sz,2,Tc);
   $A0: Begin
    Z:=Dp; HasRef:=False; Bp:=-1; Bs:=0;
    While Z<Dp+Sz Do Begin
     Zi:=EbVInt(Z,True); Zs:=EbVInt(Z,False); Zd:=Z;
     If (Zi<0) Or (Zs<0) Then Break;
     If Zi=$A1 Then Begin Bp:=Zd; Bs:=Zs; End Else If Zi=$FB Then HasRef:=True;
     Z:=Zd+Zs;
    End;
    If Bp>=0 Then MkAddBlock(Bp,Bs,Ord(Not HasRef),Tc);
   End;
  End;
  Q:=Dp+Sz;
 End;
End;

Procedure MkSegment(S,En: LongInt; Pass: Integer);
Var Q,Id,Sz,Dp: LongInt; Ent,Ee,Qid,Qsz,Qd: LongInt;
Begin
 Q:=S;
 While Q<En Do Begin
  Id:=EbVInt(Q,True); Sz:=EbVInt(Q,False); Dp:=Q;
  If (Id<0) Or (Sz<0) Then Break;
  If (Sz>En-Dp) Then Sz:=En-Dp;
  If Pass=0 Then Begin
   If Id=$1549A966 Then Begin
    Ee:=Dp; While Ee<Dp+Sz Do Begin
     Qid:=EbVInt(Ee,True); Qsz:=EbVInt(Ee,False); Qd:=Ee;
     If (Qid<0) Or (Qsz<0) Then Break;
     If Qid=$2AD7B1 Then MkScale:=EbUInt(Qd,Qsz);
     Ee:=Qd+Qsz;
    End;
   End Else If Id=$1654AE6B Then Begin
    Ee:=Dp; While Ee<Dp+Sz Do Begin
     Qid:=EbVInt(Ee,True); Qsz:=EbVInt(Ee,False); Qd:=Ee;
     If (Qid<0) Or (Qsz<0) Then Break;
     If Qid=$AE Then MkTrackEntry(Qd,Qd+Qsz);
     Ee:=Qd+Qsz;
    End;
   End;
  End Else If Id=$1F43B675 Then MkCluster(Dp,Dp+Sz);
  Q:=Dp+Sz;
 End;
End;

Procedure MkSnapFps(DdNs: LongInt; Var Ts,D: LongInt);
Var Fps: Double;
Begin
 Fps:=1000000000.0/DdNs; Ts:=1000; D:=Round(DdNs/1000000.0);
 If Abs(Fps-23.976)<0.02 Then Begin Ts:=24000; D:=1001; End
 Else If Abs(Fps-29.97)<0.02 Then Begin Ts:=30000; D:=1001; End
 Else If Abs(Fps-59.94)<0.03 Then Begin Ts:=60000; D:=1001; End
 Else If Abs(Fps-Round(Fps))<0.01 Then Begin Ts:=Round(Fps)*100; D:=100; End
 Else Begin Ts:=Round(Fps*1000); D:=1000; End;
End;

Function MkvTracks(Const Path: String; Var V,A: TTrkIn; Var Err: String): Boolean;
Var Pos0,Sz,Se,SeEnd,I,K,Vi,Ai,D,Ts,MinP,MaxP,J: LongInt; Id: LongInt; Cd: String; P: LongInt;
Begin
 MkvTracks:=False; FillChar(V,SizeOf(V),0); FillChar(A,SizeOf(A),0);
 If Not COpen(Path) Then Begin Err:='Ouverture impossible.'; Exit; End;
 If (CB(0)<>$1A) Or (CB(1)<>$45) Then Begin CClose; Err:='Fichier Matroska invalide.'; Exit; End;
 MkN:=0; MkScale:=1000000; Se:=0; SeEnd:=0;
 P:=0;
 While P<CSize Do Begin
  Id:=EbVInt(P,True); Sz:=EbVInt(P,False);
  If (Id<0) Or (Sz<0) Then Break;
  If Id=$18538067 Then Begin Se:=P; SeEnd:=P+Sz; If SeEnd>CSize Then SeEnd:=CSize; Break; End;
  P:=P+Sz;
 End;
 If Se=0 Then Begin CClose; Err:='Segment Matroska introuvable.'; Exit; End;
 MkSegment(Se,SeEnd,0);
 Vi:=-1; Ai:=-1;
 For I:=0 To MkN-1 Do Begin
  If (MkT[I].Typ=1) And (Vi<0) Then Vi:=I;
  If (MkT[I].Typ=2) And (Ai<0) Then Ai:=I;
 End;
 If Vi>=0 Then MkNum[0]:=MkT[Vi].Num Else MkNum[0]:=-1;
 If Ai>=0 Then MkNum[1]:=MkT[Ai].Num Else MkNum[1]:=-1;
 MkCnt[0]:=0; MkCnt[1]:=0; MkFill:=False; MkTr[0]:=Nil; MkTr[1]:=Nil;
 MkSegment(Se,SeEnd,1);
 If (Vi>=0) And (MkCnt[0]>0) Then Begin TrkAlloc(V,MkCnt[0]); MkTr[0]:=@V; GetMem(MkPts,MkCnt[0]*4+16); End;
 If (Ai>=0) And (MkCnt[1]>0) Then Begin TrkAlloc(A,MkCnt[1]); MkTr[1]:=@A; End;
 MkIdx[0]:=0; MkIdx[1]:=0; MkFill:=True;
 MkSegment(Se,SeEnd,1);
 { configuration de piste }
 If V.N>0 Then Begin
  V.Ok:=True; V.IsVideo:=True; V.W:=MkT[Vi].W; V.H:=MkT[Vi].H;
  Cd:=MkT[Vi].Codec;
  If Cd='V_MPEG4/ISO/AVC' Then V.Codec:='avc1'
  Else If Cd='V_MPEG4/ISO/ASP' Then V.Codec:='MP4V'
  Else If Cd='V_MS/VFW/FOURCC' Then V.Codec:=Copy(UpStr(C4(MkT[Vi].PrivPos+16)),1,4)
  Else V.Codec:=Copy(Cd,3,4);
  K:=MkT[Vi].PrivLen; If K>500 Then K:=500;
  If Cd<>'V_MS/VFW/FOURCC' Then Begin For I:=0 To K-1 Do V.Cfg[I]:=CB(MkT[Vi].PrivPos+I); V.CfgLen:=K; End;
  { cadence : DefaultDuration, sinon moyenne des instants }
  MinP:=MkPts^[0]; MaxP:=MkPts^[0];
  For I:=1 To V.N-1 Do Begin If MkPts^[I]<MinP Then MinP:=MkPts^[I]; If MkPts^[I]>MaxP Then MaxP:=MkPts^[I]; End;
  If MkT[Vi].Dd>0 Then MkSnapFps(MkT[Vi].Dd,Ts,D)
  Else If (V.N>1) And (MaxP>MinP) Then MkSnapFps(Round((MaxP-MinP)*1000000.0/(V.N-1)),Ts,D)
  Else Begin Ts:=25; D:=1; End;
  V.Ts:=Ts;
  For I:=0 To V.N-1 Do Begin
   V.Dur^[I]:=D;
   V.Cts^[I]:=Round((MkPts^[I]-MinP)*(Ts/1000.0))-I*D;
  End;
  FreeMem(MkPts,MkCnt[0]*4+16);
 End;
 If A.N>0 Then Begin
  A.Ok:=True; A.IsVideo:=False; Cd:=MkT[Ai].Codec; A.Chans:=MkT[Ai].Ch; A.Rate:=MkT[Ai].Rate; A.Ts:=A.Rate; A.Oti:=0;
  If A.Rate<=0 Then Begin A.Rate:=44100; A.Ts:=44100; End;
  If Copy(Cd,1,5)='A_AAC' Then Begin
   A.Codec:='mp4a'; A.Oti:=$40;
   K:=MkT[Ai].PrivLen; If K>20 Then K:=20;
   For I:=0 To K-1 Do A.Cfg[I]:=CB(MkT[Ai].PrivPos+I); A.CfgLen:=K;
  End Else If Cd='A_MPEG/L3' Then A.Codec:='mp3 '
  Else If Copy(Cd,1,10)='A_PCM/INT/' Then Begin A.Codec:='pcm '; A.Oti:=MkT[Ai].Bits; If A.Oti=0 Then A.Oti:=16; End
  Else A.Codec:=Copy(Cd,3,4);
  For I:=0 To A.N-1 Do A.Dur^[I]:=1024;
  If A.Codec='mp3 ' Then For I:=0 To A.N-1 Do A.Dur^[I]:=1152;
  If A.Codec='pcm ' Then For I:=0 To A.N-1 Do A.Dur^[I]:=A.Sz^[I] Div Max(1,A.Chans*(A.Oti Div 8));
 End;
 CClose;
 MkvTracks:=V.Ok Or A.Ok;
 If Not (V.Ok Or A.Ok) Then Err:='Aucune piste lisible dans ce fichier Matroska.';
End;

{$ENDIF}

{ ---------------------------------------------------------------------- }
{ Lecture d'echantillons et decodage H.264                                    }
{ ---------------------------------------------------------------------- }
Function OpenSrc(Const Path: String; Var F: File): Boolean;
Var Old: Byte;
Begin
 Assign(F,Path); Old:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}
 FileMode:=Old;
 OpenSrc:=IOResult=0;
End;

Procedure ReadSample(Var F: File; Off,Sz: LongInt);
Var Got: Word; P: LongInt;
Begin
 NeedBuf(SBuf,SBufCap,Sz);
 {$I-}Seek(F,Off);{$I+}
 P:=0;
 While P<Sz Do Begin
  {$I-}BlockRead(F,SBuf^[P],Min(32768,Sz-P),Got);{$I+}
  If (IOResult<>0) Or (Got=0) Then Break;
  Inc(P,Got);
 End;
 If P<Sz Then FillChar(SBuf^[P],Sz-P,0);
End;

Var VLastBuf: PEABuffer; VLastW,VLastH: LongInt;

Procedure H4Trampoline(B: Pointer; W,H: LongInt);
Begin
 VLastBuf:=PEABuffer(B); VLastW:=W; VLastH:=H;
 If @VFrameCb<>Nil Then VFrameCb(PEABuffer(B),W,H);
End;

{ Mode 0 : H.264 AVCC (avcC) ; 1 : H.264 Annex B ; 2 : MPEG-4 Part 2 (XviD/DivX) }
Function DecodeVideoTrack(Const Path: String; Var T: TTrkIn; First: LongInt; Mode: Integer; Var Err: String): Boolean;
Var I,NalSz,P,K,Np,Ps: LongInt; Starts: Array[0..15] Of LongInt;
Begin
 DecodeVideoTrack:=False; VStopFlag:=False; VErr:=''; VFOpen:=False; VLastBuf:=Nil;
 If Not OpenSrc(Path,VF) Then Begin Err:='Ouverture impossible.'; Exit; End;
 VFOpen:=True; EngMsg:=''; EngFirst:=0; NalSz:=0;
 If SetJmp(EngJmp)=0 Then Begin
  If Mode=2 Then Begin
   M4VidHook:=H4Trampoline; M4InTag:=Copy(T.Codec+'    ',1,4); M4Scan:=False; M4Reset; M4OutBuf:=Nil;
   If T.CfgLen>0 Then Begin
    NeedBuf(CvBuf,CvCap,T.CfgLen+64); Move(T.Cfg,CvBuf^,T.CfgLen); M4Packet(PEABuffer(CvBuf),T.CfgLen);
   End;
  End Else Begin
   H4VidHook:=H4Trampoline; H4InitState; H4OutBuf:=Nil;
   If Mode=0 Then NalSz:=H4FeedAvcc(PEABuffer(@T.Cfg),T.CfgLen);
  End;
  I:=First;
  While (I<T.N) And Not VStopFlag And Not Stopped Do Begin
   If T.Sz^[I]<=0 Then Begin
    { image perdue (chunk vide) : repete la derniere image }
    If (VLastBuf<>Nil) And (@VFrameCb<>Nil) Then VFrameCb(VLastBuf,VLastW,VLastH);
   End Else Begin
    ReadSample(VF,T.Off^[I],T.Sz^[I]);
    If Mode=2 Then Begin
     { decoupage des paquets multiples (B-images empaquetees) aux codes B6 }
     Starts[0]:=0; Np:=1; Ps:=0;
     K:=0;
     While (K+3<T.Sz^[I]) And (Np<15) Do Begin
      If (SBuf^[K]=0) And (SBuf^[K+1]=0) And (SBuf^[K+2]=1) And (SBuf^[K+3]=$B6) Then Begin
       If Ps>0 Then Begin Starts[Np]:=K; Inc(Np); End;
       Inc(Ps);
      End;
      Inc(K);
     End;
     Ps:=0;
     Starts[Np]:=T.Sz^[I];
     For K:=0 To Np-1 Do Begin
      P:=Starts[K+1]-Starts[K];
      NeedBuf(CvBuf,CvCap,P+64);
      Move(SBuf^[Starts[K]],CvBuf^,P);
      M4Packet(PEABuffer(CvBuf),P);
     End;
    End Else H4FeedNalPacket(PEABuffer(SBuf),T.Sz^[I],NalSz,0);
   End;
   If (I And 7)=0 Then UiTick(I,T.N);
   Inc(I);
  End;
  If Mode=2 Then Begin
   If Not VStopFlag Then Begin
    If (M4LowDelay=0) And (M4NextI>=0) And M4PicHave Then M4Emit(M4NextI)
    Else If M4SkippedLast And M4PicHave And (M4CurI>=0) Then M4Emit(M4CurI);
   End;
  End Else If Not VStopFlag Then Begin H4FinishPicture; H4Bump(True); End;
  VOk:=True;
 End Else Begin VOk:=False; VErr:=EngMsg; End;
 If VFOpen Then Begin Close(VF); VFOpen:=False; End;
 If Mode=2 Then Begin
  If M4OutBuf<>Nil Then Begin FreeMem(M4OutBuf); M4OutBuf:=Nil; End;
 End Else If H4Began And (H4OutBuf<>Nil) Then Begin FreeMem(H4OutBuf,H4OutSize); H4OutBuf:=Nil; End;
 If VOk Then Begin
  If Stopped Then Err:='Conversion annul'#233'e.' Else DecodeVideoTrack:=True;
 End Else Begin
  If VErr='' Then VErr:='Erreur de d'#233'codage vid'#233'o.';
  Err:=VErr;
 End;
End;

Function DecodeH264Track(Const Path: String; Var T: TTrkIn; First: LongInt; Var Err: String): Boolean;
Begin
 DecodeH264Track:=DecodeVideoTrack(Path,T,First,0,Err);
End;

{ Mode de decodage selon le codec de la piste (-1 : non pris en charge) }
Function VideoMode(Const Fmt: String; Const T: TTrkIn): Integer;
Var C: String;
Begin
 C:=T.Codec; VideoMode:=-1;
 If Fmt='AVI' Then Begin
  If InList(C,'H264,X264,AVC1,DAVC,H.26') Then VideoMode:=1
  Else If InList(C,'XVID,DIVX,DX50,FMP4,MP4V,3IV2,XVIX,BLZ0,DIV5,RMP4,MP4S,M4S2,SEDG,WV1F,UMP4,EM4A,DXGM,FVFW,DM4V') Then VideoMode:=2;
 End Else If InList(Fmt,'MKV,WEBM') Then Begin
  If (C='avc1') And (T.CfgLen>=7) Then VideoMode:=0
  Else If InList(C,'MP4V,XVID,DIVX,DX50,FMP4') Then VideoMode:=2;
 End Else If ((C='avc1') Or (C='avc3')) And (T.CfgLen>=7) Then VideoMode:=0;
End;

{ ---------------------------------------------------------------------- }
{ Conversion YUV 4:2:0 <-> RGB                                                }
{ ---------------------------------------------------------------------- }
Function YuvToImg(B: PEABuffer; W,H: LongInt): PImg;
Var Im: PImg; X,Y,CW,Yv,U,V,R,G,Bl,O: LongInt;
Begin
 Im:=ImgNew(W,H); YuvToImg:=Im;
 If Im=Nil Then Exit;
 CW:=(W+1) Div 2;
 For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
  Yv:=B^[Y*W+X]-16; U:=B^[W*H+(Y Div 2)*CW+(X Div 2)]-128; V:=B^[W*H+CW*((H+1) Div 2)+(Y Div 2)*CW+(X Div 2)]-128;
  R:=298*Yv+409*V+128; G:=298*Yv-100*U-208*V+128; Bl:=298*Yv+516*U+128;
  O:=(Y*W+X)*3;
  If R<0 Then R:=0; If G<0 Then G:=0; If Bl<0 Then Bl:=0;
  R:=R Div 256; G:=G Div 256; Bl:=Bl Div 256;
  If R>255 Then R:=255; If G>255 Then G:=255; If Bl>255 Then Bl:=255;
  Im^.P^[O]:=R; Im^.P^[O+1]:=G; Im^.P^[O+2]:=Bl;
 End;
End;

Procedure ImgToYuv(Im: PImg; Dst: PEABuffer);
Var X,Y,W,H,CW,CH,O,R,G,B,U,V,Cnt,Su,Sv,Xx,Yy: LongInt;
Begin
 W:=Im^.W; H:=Im^.H; CW:=W Div 2; CH:=H Div 2;
 For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
  O:=(Y*W+X)*3; R:=Im^.P^[O]; G:=Im^.P^[O+1]; B:=Im^.P^[O+2];
  Dst^[Y*W+X]:=((66*R+129*G+25*B+128) Div 256)+16;
 End;
 For Y:=0 To CH-1 Do For X:=0 To CW-1 Do Begin
  Su:=0; Sv:=0;
  For Yy:=0 To 1 Do For Xx:=0 To 1 Do Begin
   O:=((Y*2+Yy)*W+X*2+Xx)*3; R:=Im^.P^[O]; G:=Im^.P^[O+1]; B:=Im^.P^[O+2];
   Inc(Su,-38*R-74*G+112*B+128); Inc(Sv,112*R-94*G-18*B+128);
  End;
  U:=(Su Div 4+32768) Div 256; V:=(Sv Div 4+32768) Div 256;
  If U>255 Then U:=255; If V>255 Then V:=255;
  Dst^[W*H+Y*CW+X]:=U; Dst^[W*H+CW*CH+Y*CW+X]:=V;
 End;
End;

{ Premiere image d'une video H.264 (MP4/MOV/FLV) pour les miniatures }
Var FFImg: PImg;
Procedure FFCallback(B: PEABuffer; W,H: LongInt);
Begin
 If FFImg=Nil Then FFImg:=YuvToImg(B,W,H);
 VStopFlag:=True;
End;

Function VideoFirstFrame(Const Path,Fmt: String): PImg;
Var V,A: TTrkIn; Err: String; Ok: Boolean; SaveStop: Boolean; Md: Integer;
Begin
 VideoFirstFrame:=Nil; FFImg:=Nil;
 If InList(Fmt,'MP4,MOV,M4V,3GP') Then Ok:=Mp4Tracks(Path,V,A,Err)
 Else If Fmt='FLV' Then Ok:=FlvTracks(Path,V,A,Err)
 Else If Fmt='AVI' Then Begin Ok:=AviTracks(Path,V,Err); FillChar(A,SizeOf(A),0); End
 Else If InList(Fmt,'MKV,WEBM') Then Ok:=MkvTracks(Path,V,A,Err)
 Else Exit;
 If Not Ok Then Exit;
 Md:=VideoMode(Fmt,V);
 If V.Ok And (Md>=0) Then Begin
  VFrameCb:=FFCallback; SaveStop:=Stopped; Stopped:=False;
  Ok:=DecodeVideoTrack(Path,V,0,Md,Err);
  Stopped:=SaveStop;
  VFrameCb:=Nil;
 End;
 TrkClear(V); TrkClear(A);
 VideoFirstFrame:=FFImg;
End;

{ ---------------------------------------------------------------------- }
{ Encodeur H.264 : pilote autour des routines X4 de FFMPEG.PAS                }
{ ---------------------------------------------------------------------- }
Var
 VEW,VEH,VEFn,VEFd,VEFrame,VEQp,VEAcc,VETarget,VEGop,VENum,VECap: LongInt;
 VERaw: PEABuffer;
 VEUsed: LongInt;
 VEActive: Boolean;

Function VEncBegin(W,H,Fn,Fd,MaxFrames,Bitrate: LongInt; Var Err: String): Boolean;
Var Lvl,I: LongInt;
Begin
 VEncBegin:=False;
 If (W<16) Or (H<16) Or Odd(W) Or Odd(H) Or (W>8192) Or (H>8192) Then Begin Err:='Dimensions vid'#233'o invalides ('+IStr(W)+'x'+IStr(H)+').'; Exit; End;
 X4Mp4:=False; X4Fn:=Fn; X4Fd:=Fd;
 VEW:=W; VEH:=H; VEFn:=Fn; VEFd:=Fd;
 X4Mbw:=(W+15) Div 16; X4Mbh:=(H+15) Div 16; X4Wp:=X4Mbw*16; X4Hp:=X4Mbh*16; X4Cw:=X4Wp Div 2; X4Ch:=X4Hp Div 2;
 If X4Mbw*X4Mbh>36864 Then Begin Err:='Image trop grande.'; Exit; End;
 If X4Mbw*X4Mbh>8192 Then Lvl:=51 Else Lvl:=40;
 VEUsed:=X4Wp*X4Hp*3 Div 2;
 GetMem(X4Src,VEUsed+64); GetMem(X4Rec,VEUsed+64); GetMem(X4Ref,VEUsed+64);
 FillChar(X4Rec^,VEUsed,128); FillChar(X4Ref^,VEUsed,128);
 X4RbBits:=0; GetMem(X4Rb,VEUsed*4+8192); GetMem(X4Nb,VEUsed*8+8192);
 GetMem(X4NnzY,X4Mbw*X4Mbh*16); GetMem(X4NnzU,X4Mbw*X4Mbh*4); GetMem(X4NnzV,X4Mbw*X4Mbh*4); GetMem(X4Kind,X4Mbw*X4Mbh+4);
 GetMem(X4Mvx,X4Mbw*X4Mbh*4+16); GetMem(X4Mvy,X4Mbw*X4Mbh*4+16);
 X4OCap:=1 Shl 20; GetMem(X4O,X4OCap); X4OLen:=0;
 For I:=0 To 47 Do X4CbpInv[X4CbpTab[I]]:=I;
 VECap:=MaxFrames+4;
 GetMem(X4SampSz,VECap*4+8); GetMem(X4SampOff,VECap*4+8); GetMem(X4SampKey,VECap+8);
 GetMem(VERaw,W*H*3 Div 2+64);
 VEQp:=26; If Bitrate>0 Then VEQp:=28;
 If Bitrate>0 Then VETarget:=Round(Int64(Bitrate)*Fd/Fn) Else VETarget:=0;
 VEAcc:=0; VENum:=0; VEFrame:=0;
 VEGop:=Max(1,(Fn*10) Div Max(Fd,1));
 X4WriteSps(W,H,0,Lvl); X4WritePps;
 VEActive:=True; VEncBegin:=True;
End;

{ Encode l'image YUV 4:2:0 (W*H*3/2 octets) }
Procedure VEncFrame(Yuv: PEABuffer);
Var X,Y,I,J,K,CW,CH,Bits: LongInt; Idr: Boolean; Tmp: PEABuffer;
Begin
 CW:=VEW Div 2; CH:=VEH Div 2;
 For Y:=0 To X4Hp-1 Do Begin
  J:=Y; If J>VEH-1 Then J:=VEH-1;
  For X:=0 To X4Wp-1 Do Begin
   I:=X; If I>VEW-1 Then I:=VEW-1;
   X4Src^[Y*X4Wp+X]:=Yuv^[J*VEW+I];
  End;
 End;
 For K:=0 To 1 Do For Y:=0 To X4Ch-1 Do Begin
  J:=Y; If J>CH-1 Then J:=CH-1;
  For X:=0 To X4Cw-1 Do Begin
   I:=X; If I>CW-1 Then I:=CW-1;
   X4Src^[X4Wp*X4Hp+K*X4Cw*X4Ch+Y*X4Cw+X]:=Yuv^[VEW*VEH+K*CW*CH+J*CW+I];
  End;
 End;
 Idr:=(VEFrame=0) Or ((VEGop>0) And (VEFrame Mod VEGop=0));
 If Idr Then VENum:=0;
 Bits:=X4EncodeFrame(Idr,VENum,VEQp);
 If Idr Then X4NalBuild(3,5) Else X4NalBuild(2,1);
 X4SampOff^[VEFrame]:=X4OLen; If Idr Then X4SampKey^[VEFrame]:=1 Else X4SampKey^[VEFrame]:=0;
 X4EmitNal;
 X4SampSz^[VEFrame]:=X4OLen-X4SampOff^[VEFrame];
 Inc(VENum); Inc(VEFrame);
 Tmp:=X4Rec; X4Rec:=X4Ref; X4Ref:=Tmp;
 If VETarget>0 Then Begin
  Inc(VEAcc,Bits-VETarget);
  If VEAcc>2*VETarget Then Begin If VEQp<51 Then Inc(VEQp); VEAcc:=VEAcc Div 2; End
  Else If VEAcc<-2*VETarget Then Begin If VEQp>10 Then Dec(VEQp); VEAcc:=VEAcc Div 2; End;
 End;
End;

Procedure VEncFree;
Begin
 If Not VEActive Then Exit;
 FreeMem(VERaw,VEW*VEH*3 Div 2+64);
 FreeMem(X4Src,VEUsed+64); FreeMem(X4Rec,VEUsed+64); FreeMem(X4Ref,VEUsed+64);
 FreeMem(X4Rb,VEUsed*4+8192); FreeMem(X4Nb,VEUsed*8+8192);
 FreeMem(X4NnzY,X4Mbw*X4Mbh*16); FreeMem(X4NnzU,X4Mbw*X4Mbh*4); FreeMem(X4NnzV,X4Mbw*X4Mbh*4); FreeMem(X4Kind,X4Mbw*X4Mbh+4);
 FreeMem(X4Mvx,X4Mbw*X4Mbh*4+16); FreeMem(X4Mvy,X4Mbw*X4Mbh*4+16);
 FreeMem(X4O,X4OCap);
 FreeMem(X4SampSz,VECap*4+8); FreeMem(X4SampOff,VECap*4+8); FreeMem(X4SampKey,VECap+8);
 VEActive:=False;
End;

{ ---------------------------------------------------------------------- }
{ Multiplexeur MP4                                                            }
{ ---------------------------------------------------------------------- }
Var
 MB: PBArr;
 MBLen,MBCap: LongInt;

Procedure MEnsure(N: LongInt);
Var NB: PBArr;
Begin
 If MBLen+N+16>MBCap Then Begin
  GetMem(NB,MBCap*2+N+65536);
  Move(MB^,NB^,MBLen);
  FreeMem(MB,MBCap);
  MB:=NB; MBCap:=MBCap*2+N+65536;
 End;
End;

Procedure M8(V: LongInt);
Begin
 MEnsure(1); MB^[MBLen]:=V And 255; Inc(MBLen);
End;

Procedure M16(V: LongInt);
Begin
 M8(V Shr 8); M8(V);
End;

Procedure M32(V: LongInt);
Begin
 M8(V Shr 24); M8(V Shr 16); M8(V Shr 8); M8(V);
End;

Procedure MTag(Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do M8(Ord(S[I]));
End;

Procedure MZero(N: LongInt);
Var I: LongInt;
Begin
 For I:=1 To N Do M8(0);
End;

Function MBegin(Const Tag: String): LongInt;
Begin
 MBegin:=MBLen; M32(0); MTag(Tag);
End;

Procedure MEnd(P: LongInt);
Var Z: LongInt;
Begin
 Z:=MBLen-P;
 MB^[P]:=(Z Shr 24) And 255; MB^[P+1]:=(Z Shr 16) And 255; MB^[P+2]:=(Z Shr 8) And 255; MB^[P+3]:=Z And 255;
End;

Procedure MMatrix;
Begin
 M32($10000); M32(0); M32(0); M32(0); M32($10000); M32(0); M32(0); M32(0); M32($40000000);
End;

{ Octets d'un echantillon pret a ecrire (conversion Annex B -> AVCC si besoin) }
Function MuxFetch(Var MT: TMuxTrk; I: LongInt; Var Len: LongInt): PBArr;
Var Sz,Off,P,Q,Start,E,N: LongInt; Typ: Byte;
Begin
 Sz:=MT.T^.Sz^[I]; Off:=MT.T^.Off^[I];
 If MT.Mem<>Nil Then Begin
  NeedBuf(SBuf,SBufCap,Sz); Move(MT.Mem^[Off],SBuf^,Sz);
 End Else Begin
  NeedBuf(SBuf,SBufCap,Sz);
  {$I-}Seek(MT.F,Off);{$I+}
  P:=0;
  While P<Sz Do Begin
   {$I-}BlockRead(MT.F,SBuf^[P],Min(32768,Sz-P),Cnt32);{$I+}
   If (IOResult<>0) Or (Cnt32=0) Then Break;
   Inc(P,Cnt32);
  End;
 End;
 If Not MT.Annex Then Begin Len:=Sz; MuxFetch:=SBuf; Exit; End;
 NeedBuf(CvBuf,CvCap,Sz+64); N:=0;
 P:=0; Start:=-1;
 While P<=Sz Do Begin
  If (P+2<Sz) And (SBuf^[P]=0) And (SBuf^[P+1]=0) And (SBuf^[P+2]=1) Or (P=Sz) Then Begin
   If Start>=0 Then Begin
    E:=P; While (E>Start) And (SBuf^[E-1]=0) Do Dec(E);
    If E>Start Then Begin
     Typ:=SBuf^[Start] And 31;
     If (Typ<>7) And (Typ<>8) And (Typ<>9) Then Begin
      Q:=E-Start;
      CvBuf^[N]:=(Q Shr 24) And 255; CvBuf^[N+1]:=(Q Shr 16) And 255; CvBuf^[N+2]:=(Q Shr 8) And 255; CvBuf^[N+3]:=Q And 255;
      Move(SBuf^[Start],CvBuf^[N+4],Q); Inc(N,Q+4);
     End;
    End;
   End;
   Start:=P+3; Inc(P,3);
  End Else Inc(P);
 End;
 Len:=N; MuxFetch:=CvBuf;
End;

Procedure MuxStbl(Var MT: TMuxTrk; IsVideo: Boolean);
Var I,K,Run,Prev,P,Cnt,NSync,MinC: LongInt; AnyCts: Boolean; Sb,Sd,Ent,Cfg: LongInt; Pos: LongInt;
Begin
 Sb:=MBegin('stbl');
 Sd:=MBegin('stsd'); M32(0); M32(1);
 If IsVideo Then Begin
  Ent:=MBegin('avc1'); MZero(6); M16(1); MZero(16); M16(MT.T^.W); M16(MT.T^.H); M32($480000); M32($480000); M32(0); M16(1);
  MZero(32); M16($18); M16($FFFF);
  Cfg:=MBegin('avcC'); For I:=0 To MT.T^.CfgLen-1 Do M8(MT.T^.Cfg[I]); MEnd(Cfg);
  MEnd(Ent);
 End Else Begin
  Ent:=MBegin('mp4a'); MZero(6); M16(1); MZero(8); M16(MT.T^.Chans); M16(16); M16(0); M16(0); M16(MT.T^.Rate); M16(0);
  Cfg:=MBegin('esds'); M32(0);
  M8(3); M8(3+2+13+2+MT.T^.CfgLen+3); M16(1); M8(0);
  M8(4); M8(13+2+MT.T^.CfgLen); M8($40); M8($15); MZero(3); M32(0); M32(0);
  M8(5); M8(MT.T^.CfgLen); For I:=0 To MT.T^.CfgLen-1 Do M8(MT.T^.Cfg[I]);
  M8(6); M8(1); M8(2);
  MEnd(Cfg); MEnd(Ent);
 End;
 MEnd(Sd);
 { stts }
 P:=MBegin('stts'); M32(0); Cnt:=0; Pos:=MBLen; M32(0);
 I:=MT.First;
 While I<=MT.Last Do Begin
  Run:=1; Prev:=MT.T^.Dur^[I];
  While (I+Run<=MT.Last) And (MT.T^.Dur^[I+Run]=Prev) Do Inc(Run);
  M32(Run); M32(Prev); Inc(Cnt); Inc(I,Run);
 End;
 MB^[Pos]:=(Cnt Shr 24) And 255; MB^[Pos+1]:=(Cnt Shr 16) And 255; MB^[Pos+2]:=(Cnt Shr 8) And 255; MB^[Pos+3]:=Cnt And 255;
 MEnd(P);
 { ctts }
 AnyCts:=False;
 For I:=MT.First To MT.Last Do If MT.T^.Cts^[I]<>0 Then AnyCts:=True;
 If AnyCts Then Begin
  P:=MBegin('ctts'); M32(0); Cnt:=0; Pos:=MBLen; M32(0);
  I:=MT.First;
  MinC:=MT.T^.Cts^[I];
  For K:=MT.First To MT.Last Do If MT.T^.Cts^[K]<MinC Then MinC:=MT.T^.Cts^[K];
  While I<=MT.Last Do Begin
   Run:=1; Prev:=MT.T^.Cts^[I];
   While (I+Run<=MT.Last) And (MT.T^.Cts^[I+Run]=Prev) Do Inc(Run);
   M32(Run); M32(Prev-MinC); Inc(Cnt); Inc(I,Run);
  End;
  MB^[Pos]:=(Cnt Shr 24) And 255; MB^[Pos+1]:=(Cnt Shr 16) And 255; MB^[Pos+2]:=(Cnt Shr 8) And 255; MB^[Pos+3]:=Cnt And 255;
  MEnd(P);
 End;
 { stsc : un echantillon-groupe par bloc }
 P:=MBegin('stsc'); M32(0); Cnt:=0; Pos:=MBLen; M32(0);
 Prev:=-1;
 For I:=0 To MT.NCh-1 Do If MT.ChCnt^[I]<>Prev Then Begin M32(I+1); M32(MT.ChCnt^[I]); M32(1); Prev:=MT.ChCnt^[I]; Inc(Cnt); End;
 MB^[Pos]:=(Cnt Shr 24) And 255; MB^[Pos+1]:=(Cnt Shr 16) And 255; MB^[Pos+2]:=(Cnt Shr 8) And 255; MB^[Pos+3]:=Cnt And 255;
 MEnd(P);
 { stsz }
 P:=MBegin('stsz'); M32(0); M32(0); M32(MT.Last-MT.First+1);
 For I:=MT.First To MT.Last Do M32(MT.OutSz^[I]);
 MEnd(P);
 { stco }
 P:=MBegin('stco'); M32(0); M32(MT.NCh);
 For I:=0 To MT.NCh-1 Do M32(MT.ChOff^[I]);
 MEnd(P);
 { stss }
 If IsVideo Then Begin
  NSync:=0;
  For I:=MT.First To MT.Last Do If MT.T^.Sync^[I]<>0 Then Inc(NSync);
  If NSync<MT.Last-MT.First+1 Then Begin
   P:=MBegin('stss'); M32(0); M32(NSync);
   For I:=MT.First To MT.Last Do If MT.T^.Sync^[I]<>0 Then M32(I-MT.First+1);
   MEnd(P);
  End;
 End;
 MEnd(Sb);
End;

{ Ecrit le fichier MP4. Tr[0] = video (ou audio seul), Tr[1] = audio. }
Function MuxMp4(Const Dst,Brand: String; Var Tr: Array Of TMuxTrk; NT: Integer; Var Err: String): Boolean;
Var
 FO: File; H: THdr; I,K,S,Ch,MaxCh: LongInt; Mdat,Moov,Mv,Trak,Mdia,Minf,Tk,Dinf,Dref,Ud: LongInt; Ok: Boolean;
 Dp: Array[0..1] Of Int64; Idx: Array[0..1] Of LongInt; DurMs,MaxMs: LongInt; Len: LongInt; Buf: PBArr;
 TotalMs: Array[0..1] Of LongInt; Pos0,TrkMin: LongInt; Sec: LongInt; EndSample: LongInt; Acc: Int64; Written: LongInt;
 Hd: Array[0..11] Of Byte;
Begin
 MuxMp4:=False; Ok:=True;
 If MB=Nil Then Begin MBCap:=65536; GetMem(MB,MBCap); End;
 If Not CreateOut(Dst,FO,Err) Then Exit;
 MaxMs:=0;
 For K:=0 To NT-1 Do Begin
  Acc:=0; For I:=Tr[K].First To Tr[K].Last Do Inc(Acc,Tr[K].T^.Dur^[I]);
  TotalMs[K]:=Round(Acc*1000.0/Tr[K].T^.Ts);
  If TotalMs[K]>MaxMs Then MaxMs:=TotalMs[K];
  GetMem(Tr[K].OutSz,Tr[K].T^.N*4+16);
  Tr[K].NCh:=0;
  If Tr[K].Mem=Nil Then Begin
   If Not OpenSrc(Tr[K].Path,Tr[K].F) Then Begin Err:='Source illisible.'; Ok:=False; End Else Tr[K].Opened:=True;
  End;
 End;
 MaxCh:=MaxMs Div 1000+3;
 For K:=0 To NT-1 Do Begin GetMem(Tr[K].ChOff,MaxCh*4+16); GetMem(Tr[K].ChCnt,MaxCh*4+16); End;
 { ftyp }
 MBLen:=0;
 Mv:=MBegin('ftyp'); MTag(Brand); M32(512); MTag(Brand);
 If Brand='qt  ' Then MTag('qt  ') Else Begin MTag('isom'); MTag('iso2'); If Brand<>'M4A ' Then MTag('avc1'); MTag('mp41'); End;
 MEnd(Mv);
 BlockWrite(FO,MB^,MBLen);
 Written:=MBLen;
 Mdat:=Written; FillChar(Hd,SizeOf(Hd),0); Hd[4]:=Ord('m'); Hd[5]:=Ord('d'); Hd[6]:=Ord('a'); Hd[7]:=Ord('t');
 BlockWrite(FO,Hd,8); Inc(Written,8);
 For K:=0 To NT-1 Do Idx[K]:=Tr[K].First;
 { blocs d'une seconde, entrelaces }
 Dp[0]:=0; Dp[1]:=0; Sec:=0;
 While Ok And ((Idx[0]<=Tr[0].Last) Or ((NT>1) And (Idx[1]<=Tr[1].Last))) Do Begin
  For K:=0 To NT-1 Do Begin
   S:=0; Pos0:=Written;
   While (Idx[K]<=Tr[K].Last) And Ok Do Begin
    If Dp[K]*1000 Div Tr[K].T^.Ts>=(Sec+1)*1000 Then Break;
    Buf:=MuxFetch(Tr[K],Idx[K],Len);
    Tr[K].OutSz^[Idx[K]]:=Len;
    BlockWrite(FO,Buf^,Len); Inc(Written,Len);
    Inc(Dp[K],Tr[K].T^.Dur^[Idx[K]]); Inc(Idx[K]); Inc(S);
   End;
   If S>0 Then Begin
    Tr[K].ChOff^[Tr[K].NCh]:=Pos0; Tr[K].ChCnt^[Tr[K].NCh]:=S; Inc(Tr[K].NCh);
   End;
  End;
  Inc(Sec);
  If Sec>MaxCh-2 Then Break;
  UiTick(Sec,Max(1,MaxMs Div 1000+1));
  If Stopped Then Ok:=False;
 End;
 For K:=0 To NT-1 Do If Idx[K]<=Tr[K].Last Then Ok:=False;
 If Not Ok Then Begin
  If Err='' Then If Stopped Then Err:='Conversion annul'#233'e.' Else Err:='Erreur de multiplexage.';
 End Else Begin
  { taille de mdat }
  Seek(FO,Mdat); H[0]:=((Written-Mdat) Shr 24) And 255; H[1]:=((Written-Mdat) Shr 16) And 255; H[2]:=((Written-Mdat) Shr 8) And 255; H[3]:=(Written-Mdat) And 255;
  BlockWrite(FO,H,4);
  Seek(FO,Written);
  { moov }
  MBLen:=0;
  Moov:=MBegin('moov');
  Mv:=MBegin('mvhd'); M32(0); M32(0); M32(0); M32(1000); M32(MaxMs); M32($10000); M16($100); MZero(10); MMatrix; MZero(24); M32(NT+1); MEnd(Mv);
  For K:=0 To NT-1 Do Begin
   Trak:=MBegin('trak');
   Tk:=MBegin('tkhd'); M32(3); M32(0); M32(0); M32(K+1); M32(0); M32(TotalMs[K]); MZero(8); M16(0); M16(0);
   If Tr[K].T^.IsVideo Then M16(0) Else M16($100);
   M16(0); MMatrix;
   If Tr[K].T^.IsVideo Then Begin M32(Tr[K].T^.W Shl 16); M32(Tr[K].T^.H Shl 16); End Else Begin M32(0); M32(0); End;
   MEnd(Tk);
   Mdia:=MBegin('mdia');
   Mv:=MBegin('mdhd'); M32(0); M32(0); M32(0); M32(Tr[K].T^.Ts);
   Acc:=0; For I:=Tr[K].First To Tr[K].Last Do Inc(Acc,Tr[K].T^.Dur^[I]);
   M32(Acc); M16($55C4); M16(0); MEnd(Mv);
   Mv:=MBegin('hdlr'); M32(0); M32(0);
   If Tr[K].T^.IsVideo Then Begin MTag('vide'); MZero(12); MTag('VideoHandler'); End Else Begin MTag('soun'); MZero(12); MTag('SoundHandler'); End;
   M8(0); MEnd(Mv);
   Minf:=MBegin('minf');
   If Tr[K].T^.IsVideo Then Begin Mv:=MBegin('vmhd'); M32(1); MZero(8); MEnd(Mv); End
   Else Begin Mv:=MBegin('smhd'); M32(0); M32(0); MEnd(Mv); End;
   Dinf:=MBegin('dinf'); Dref:=MBegin('dref'); M32(0); M32(1); Mv:=MBegin('url '); M32(1); MEnd(Mv); MEnd(Dref); MEnd(Dinf);
   MuxStbl(Tr[K],Tr[K].T^.IsVideo);
   MEnd(Minf); MEnd(Mdia); MEnd(Trak);
  End;
  MEnd(Moov);
  BlockWrite(FO,MB^,MBLen);
  MuxMp4:=True;
 End;
 Close(FO);
 For K:=0 To NT-1 Do Begin
  If Tr[K].Opened Then Begin Close(Tr[K].F); Tr[K].Opened:=False; End;
  FreeMem(Tr[K].OutSz,Tr[K].T^.N*4+16); FreeMem(Tr[K].ChOff,MaxCh*4+16); FreeMem(Tr[K].ChCnt,MaxCh*4+16);
 End;
 If Not Ok Then DelFile(Dst);
End;
{$ENDIF}

{$IFDEF FPC}
{ Audio d'un fichier MKV : Kind 1 WAV (PCM), 2 MP3, 3 AAC (ADTS) }
Function ExtractMkv(Const Src,Dst: String; Var Kind: Integer; Var Err: String): Boolean;
Var V,A: TTrkIn; FI,FO: File; I,Tot: LongInt; H: THdr; Prof,Sfi,Cfg: Integer; Ok: Boolean;
Begin
 ExtractMkv:=False; Kind:=0;
 If Not MkvTracks(Src,V,A,Err) Then Exit;
 TrkClear(V);
 If Not A.Ok Then Begin Err:='Aucune piste audio dans ce fichier.'; TrkClear(A); Exit; End;
 If A.Codec='mp4a' Then Kind:=3 Else If A.Codec='mp3 ' Then Kind:=2 Else If A.Codec='pcm ' Then Kind:=1
 Else Begin Err:='Audio MKV non pris en charge ('+A.Codec+').'; TrkClear(A); Exit; End;
 If (Kind=3) And (A.CfgLen<2) Then Begin Err:='Configuration AAC absente.'; TrkClear(A); Exit; End;
 If Not OpenSrc(Src,FI) Then Begin Err:='Ouverture impossible.'; TrkClear(A); Exit; End;
 If Not CreateOut(Dst,FO,Err) Then Begin Close(FI); TrkClear(A); Exit; End;
 If Kind=1 Then Begin PcmHeader(H,A.Rate,A.Chans,A.Oti,0); BlockWrite(FO,H,44); End;
 Prof:=(A.Cfg[0] Shr 3)-1; Sfi:=((A.Cfg[0] And 7) Shl 1) Or (A.Cfg[1] Shr 7); Cfg:=(A.Cfg[1] Shr 3) And 15;
 Tot:=0;
 For I:=0 To A.N-1 Do Begin
  If Kind=3 Then PutAdts(FO,Prof,Sfi,Cfg,A.Sz^[I]);
  CopyRange(FI,FO,A.Off^[I],A.Sz^[I],False); Inc(Tot,A.Sz^[I]);
  If (I And 255)=0 Then UiTick(I,A.N);
 End;
 If Kind=1 Then PutHeaderFix(FO,A.Rate,A.Chans,A.Oti,Tot);
 Close(FI); Close(FO); TrkClear(A);
 If Tot=0 Then Begin DelFile(Dst); Err:='Aucune donn'#233'e audio.'; Exit; End;
 ExtractMkv:=True;
End;
{$ENDIF}

{ ====================================================================== }
{ Taches video : copie de flux, transcodage H.264, image -> video, AAC      }
{ ====================================================================== }
{$IFDEF FPC}
Var
 VJMed: ^TMedia;
 VJIdx,VJN,VJOutW,VJOutH,VJFn,VJFd,VJBitrate,VJResW,VJResH,VJTrimS,VJTrimE: LongInt;
 VJStarted,VJNeedEdit: Boolean;
 VJOut: PEABuffer;
 VJErr: String;
 VJTmp: File;
 VJTmpName: String;
 VJCnt: LongInt;

Procedure ParseRes(Const S: String; Var W,H: LongInt);
Var P: Integer;
Begin
 W:=0; H:=0; P:=Pos('x',S);
 If P>1 Then Begin W:=ValL(Copy(S,1,P-1)); H:=ValL(Copy(S,P+1,10)); End;
End;

Function Gcd(A,B: LongInt): LongInt;
Var T: LongInt;
Begin
 While B<>0 Do Begin T:=A Mod B; A:=B; B:=T; End;
 Gcd:=A;
End;

Function EditsPresent(Const M: TMedia): Boolean;
Begin
 EditsPresent:=(M.Rot Mod 4<>0) Or M.FlipH Or M.FlipV Or (M.CropW>0) Or (M.Bright<>0) Or (M.Contr<>0) Or (M.Satur<>0) Or (M.Hue<>0) Or (M.WmOn And (M.WmText<>''));
End;

Procedure CalcOutDims(Const M: TMedia; W,H: LongInt; Var OW,OH: LongInt);
Var EW,EH: LongInt;
Begin
 EW:=W; EH:=H;
 If (M.CropW>0) And (M.CropX+M.CropW<=W) And (M.CropY+M.CropH<=H) Then Begin EW:=M.CropW; EH:=M.CropH; End;
 If Odd(M.Rot) Then Begin OW:=EW; EW:=EH; EH:=OW; End;
 If (VJResW>0) And (VJResH>0) Then Begin OW:=VJResW; OH:=VJResH; End
 Else Begin OW:=EW; OH:=EH; End;
 OW:=OW And (Not 1); OH:=OH And (Not 1);
 If OW<16 Then OW:=16; If OH<16 Then OH:=16;
End;

Procedure ProcFrame(B: PEABuffer; W,H: LongInt);
Var Im,T: PImg;
Begin
 If (Not VJNeedEdit) And (W=VJOutW) And (H=VJOutH) And (Not Odd(W)) And (Not Odd(H)) Then Begin
  Move(B^,VJOut^,W*H*3 Div 2); Exit;
 End;
 Im:=YuvToImg(B,W,H);
 If Im=Nil Then Exit;
 If VJNeedEdit Then ApplyEdit(VJMed^,Im);
 If (Im^.W<>VJOutW) Or (Im^.H<>VJOutH) Then Begin
  T:=ImgFit(Im,VJOutW,VJOutH,0,0,0,False);
  If T<>Nil Then Begin ImgFree(Im); Im:=T; End;
 End;
 ImgToYuv(Im,VJOut);
 ImgFree(Im);
End;

{ Phase 1 : decodage + retouche, images ecrites dans un fichier temporaire }
Procedure TranscodeCb(B: PEABuffer; W,H: LongInt);
Var Ms: LongInt;
Begin
 Inc(VJIdx);
 Ms:=Round((VJIdx-1)*1000.0*VJFd/VJFn);
 If Ms<VJTrimS Then Exit;
 If (VJTrimE>0) And (Ms>=VJTrimE) Then Begin VStopFlag:=True; Exit; End;
 If Not VJStarted Then Begin
  CalcOutDims(VJMed^,W,H,VJOutW,VJOutH);
  GetMem(VJOut,VJOutW*VJOutH*3 Div 2+64);
  VJTmpName:=TmpName('YUV');
  Assign(VJTmp,VJTmpName);
  {$I-}Rewrite(VJTmp,1);{$I+}
  If IOResult<>0 Then Begin VJErr:='Fichier temporaire impossible : '+VJTmpName; VStopFlag:=True; Exit; End;
  VJStarted:=True; VJCnt:=0;
 End;
 ProcFrame(B,W,H);
 {$I-}BlockWrite(VJTmp,VJOut^,VJOutW*VJOutH*3 Div 2);{$I+}
 If IOResult<>0 Then Begin VJErr:='Disque plein (fichier temporaire).'; VStopFlag:=True; Exit; End;
 Inc(VJCnt);
 If (VJIdx And 3)=0 Then UiTick(VJIdx,VJN);
 If Stopped Then VStopFlag:=True;
End;

{ Phase 2 : encodage H.264 depuis le fichier temporaire }
Function EncodeTemp(Var Err: String): Boolean;
Var I,Fsz: LongInt; Got: Word; P: LongInt; Ok: Boolean;
Begin
 EncodeTemp:=False;
 Fsz:=VJOutW*VJOutH*3 Div 2;
 If Not VEncBegin(VJOutW,VJOutH,VJFn,VJFd,VJCnt,VJBitrate,Err) Then Exit;
 Seek(VJTmp,0); Ok:=True;
 For I:=1 To VJCnt Do Begin
  P:=0;
  While P<Fsz Do Begin
   {$I-}BlockRead(VJTmp,VJOut^[P],Min(32768,Fsz-P),Got);{$I+}
   If (IOResult<>0) Or (Got=0) Then Begin Ok:=False; Break; End;
   Inc(P,Got);
  End;
  If Not Ok Then Break;
  VEncFrame(VJOut);
  If (I And 3)=0 Then UiTick(I,VJCnt);
  If Stopped Then Begin Ok:=False; Err:='Conversion annul'#233'e.'; Break; End;
 End;
 If (Not Ok) And (Err='') Then Err:='Lecture du fichier temporaire impossible.';
 EncodeTemp:=Ok;
End;

{ ---- ADTS -> piste audio ---- }
Function ParseAdts(Const Path: String; Var T: TTrkIn): Boolean;
Var P,L,H,N,Pass,I: LongInt; Obj,Sfi,Ch: Integer;
Const Rates: Array[0..12] Of LongInt = (96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350);
Begin
 ParseAdts:=False; FillChar(T,SizeOf(T),0);
 If Not COpen(Path) Then Exit;
 P:=0; N:=0;
 For Pass:=1 To 2 Do Begin
  P:=0; I:=0;
  While P+7<CSize Do Begin
   If (CB(P)<>$FF) Or ((CB(P+1) And $F0)<>$F0) Then Begin Inc(P); Continue; End;
   If (CB(P+1) And 1)=1 Then H:=7 Else H:=9;
   L:=((LongInt(CB(P+3)) And 3) Shl 11) Or (LongInt(CB(P+4)) Shl 3) Or (CB(P+5) Shr 5);
   If (L<H) Or (P+L>CSize) Then Break;
   If (Pass=1) And (N=0) Then Begin
    Obj:=(CB(P+2) Shr 6)+1; Sfi:=(CB(P+2) Shr 2) And 15; Ch:=((CB(P+2) And 1) Shl 2) Or (CB(P+3) Shr 6);
   End;
   If Pass=2 Then Begin T.Off^[I]:=P+H; T.Sz^[I]:=L-H; T.Dur^[I]:=1024; End;
   Inc(I); Inc(P,L);
  End;
  If Pass=1 Then Begin
   N:=I; If N<1 Then Begin CClose; Exit; End;
   TrkAlloc(T,N);
  End;
 End;
 CClose;
 T.Ok:=True; T.IsVideo:=False; T.Codec:='mp4a'; T.Oti:=$40;
 If Sfi<=12 Then T.Rate:=Rates[Sfi] Else T.Rate:=44100;
 T.Ts:=T.Rate; T.Chans:=Ch; If T.Chans<1 Then T.Chans:=2;
 T.Cfg[0]:=(Obj Shl 3) Or (Sfi Shr 1); T.Cfg[1]:=((Sfi And 1) Shl 7) Or (Ch Shl 3); T.CfgLen:=2;
 ParseAdts:=True;
End;

Function BrandFor(Const Ext: String; Audio: Boolean): String;
Begin
 If Audio Then BrandFor:='M4A ' Else If Ext='MOV' Then BrandFor:='qt  ' Else If Ext='3GP' Then BrandFor:='3gp4' Else If Ext='M4V' Then BrandFor:='M4V ' Else BrandFor:='isom';
End;

{ Sortie audio AAC (ADTS) ou M4A : a partir du WAV canonique }
Function WriteAacOut(Const Canon,Dst: String; Const Pr: TProf; Var Err: String): Boolean;
Var Adts: String; A: TTrkIn; Tr: Array[0..0] Of TMuxTrk; K: Integer; Kb: LongInt; Ok: Boolean;
Begin
 WriteAacOut:=False;
 Kb:=Pr.AKb; If Kb<64 Then Kb:=128; If Kb>320 Then Kb:=256;
 If Pr.Ext='AAC' Then Begin WriteAacOut:=RunEng(ekEncAAC,Canon,Dst,Kb,Err); Exit; End;
 Adts:=TmpName('AAC');
 If Not RunEng(ekEncAAC,Canon,Adts,Kb,Err) Then Begin DelFile(Adts); Exit; End;
 If Not ParseAdts(Adts,A) Then Begin DelFile(Adts); Err:='Flux AAC invalide.'; Exit; End;
 FillChar(Tr,SizeOf(Tr),0);
 Tr[0].T:=@A; Tr[0].First:=0; Tr[0].Last:=A.N-1; Tr[0].Path:=Adts;
 Ok:=MuxMp4(Dst,'M4A ',Tr,1,Err);
 TrkClear(A); DelFile(Adts);
 WriteAacOut:=Ok;
End;

{ Piste audio du fichier de sortie : copie des paquets AAC ou transcodage }
Function PrepareAudio(Var M: TMedia; Const Pr: TProf; Var Src: TTrkIn; HaveSrc: Boolean; SrcFlv: Boolean; Const SrcPath: String;
 StartMs,EndMs: LongInt; Var Out: TTrkIn; Var OutPath: String; Var First,Last: LongInt; Var Err: String): Boolean;
Var Copy: Boolean; I: LongInt; Acc: Int64; T1,T2,T3: String; SP: TAP; AP: TAP; Rt: LongInt;
Begin
 PrepareAudio:=False; OutPath:='';
 Copy:=HaveSrc And (Src.Codec='mp4a') And (Src.Oti=$40) And (M.Vol=100) And (M.ADelay=0) And (CustRate=0) And (CustCh=0) And (Src.CfgLen>=2) And (Src.Chans<=2);
 If Copy Then Begin
  { fenetre temporelle }
  First:=-1; Last:=-1; Acc:=0;
  For I:=0 To Src.N-1 Do Begin
   If (First<0) And (Acc*1000.0/Src.Ts>=StartMs) Then First:=I;
   If (EndMs>0) And (Acc*1000.0/Src.Ts>=EndMs) Then Break;
   If First>=0 Then Last:=I;
   Inc(Acc,Src.Dur^[I]);
  End;
  If (First<0) Or (Last<First) Then Begin First:=0; Last:=Src.N-1; End;
  OutPath:=SrcPath; Move(Src,Out,SizeOf(Out)); { partage des tableaux }
  PrepareAudio:=True; Exit;
 End;
 { transcodage : decodage -> traitement -> AAC }
 T1:=TmpName('WAV'); T2:=TmpName('WAV'); T3:=TmpName('AAC');
 StageLo:=0; StageHi:=10;
 If Not GetPcm(M,T1,Err) Then Begin DelFile(T1); Exit; End;
 FillChar(SP,SizeOf(SP),0); SP.Vol:=100; SP.Speed:=100;
 BuildAP(M,Pr,AP,SP);
 AP.StartMs:=StartMs; AP.EndMs:=EndMs;
 If AP.OutRate<32000 Then AP.OutRate:=44100;
 If (AP.OutRate<>44100) And (AP.OutRate<>48000) And (AP.OutRate<>32000) Then AP.OutRate:=44100;
 If AP.OutCh=0 Then AP.OutCh:=2;
 If Not ProcessWav(T1,T2,AP,Err) Then Begin DelFile(T1); DelFile(T2); Exit; End;
 DelFile(T1);
 Rt:=Pr.AKb; If Rt<64 Then Rt:=128; If Rt>320 Then Rt:=256;
 If Not RunEng(ekEncAAC,T2,T3,Rt,Err) Then Begin DelFile(T2); DelFile(T3); Exit; End;
 DelFile(T2);
 If Not ParseAdts(T3,Out) Then Begin DelFile(T3); Err:='Encodage AAC invalide.'; Exit; End;
 OutPath:=T3; First:=0; Last:=Out.N-1;
 PrepareAudio:=True;
End;

Procedure FpsOf(Var V: TTrkIn; Var Fn,Fd: LongInt);
Var I: LongInt; Same: Boolean; Acc: Int64; G: LongInt;
Begin
 Fn:=25; Fd:=1; If V.N<1 Then Exit;
 Same:=True; Acc:=0;
 For I:=0 To V.N-1 Do Begin If V.Dur^[I]<>V.Dur^[0] Then Same:=False; Inc(Acc,V.Dur^[I]); End;
 If Same And (V.Dur^[0]>0) Then Begin Fn:=V.Ts; Fd:=V.Dur^[0]; End
 Else If Acc>0 Then Begin Fn:=Round(V.N*1000.0*V.Ts/Acc); Fd:=1000*V.Ts; Fn:=Round(V.N*V.Ts*1000.0/Acc); Fd:=1000; End;
 G:=Gcd(Fn,Fd); If G>1 Then Begin Fn:=Fn Div G; Fd:=Fd Div G; End;
 If (Fn<=0) Or (Fd<=0) Or (Fn Div Fd>240) Then Begin Fn:=25; Fd:=1; End;
End;

Procedure BuildAvcC(Var T: TTrkIn);
Var I,L: Integer;
Begin
 L:=0;
 T.Cfg[L]:=1; T.Cfg[L+1]:=X4SpsB[1]; T.Cfg[L+2]:=X4SpsB[2]; T.Cfg[L+3]:=X4SpsB[3]; T.Cfg[L+4]:=$FF; T.Cfg[L+5]:=$E1; Inc(L,6);
 T.Cfg[L]:=X4SpsLen Shr 8; T.Cfg[L+1]:=X4SpsLen And 255; Inc(L,2);
 For I:=0 To X4SpsLen-1 Do Begin T.Cfg[L]:=X4SpsB[I]; Inc(L); End;
 T.Cfg[L]:=1; Inc(L);
 T.Cfg[L]:=X4PpsLen Shr 8; T.Cfg[L+1]:=X4PpsLen And 255; Inc(L,2);
 For I:=0 To X4PpsLen-1 Do Begin T.Cfg[L]:=X4PpsB[I]; Inc(L); End;
 T.CfgLen:=L;
End;

{ Piste video issue de l'encodeur }
Procedure EncoderTrack(Var T: TTrkIn);
Var I: LongInt;
Begin
 FillChar(T,SizeOf(T),0);
 TrkAlloc(T,VEFrame);
 For I:=0 To VEFrame-1 Do Begin
  T.Off^[I]:=X4SampOff^[I]; T.Sz^[I]:=X4SampSz^[I]; T.Dur^[I]:=VEFd; T.Sync^[I]:=X4SampKey^[I];
 End;
 T.Ok:=True; T.IsVideo:=True; T.Codec:='avc1'; T.Ts:=VEFn; T.W:=VEW; T.H:=VEH;
 BuildAvcC(T);
End;

{ MP4/MOV/FLV H.264 -> MP4 (copie de flux ou transcodage) }
Function VideoJob(Var M: TMedia; Const Pr: TProf; Const Dst: String; Var Err: String): Boolean;
Var
 V,A,Vo: TTrkIn; Ok,HaveA,Reenc,AFlv: Boolean; Fmt: String; Tr: Array[0..1] of TMuxTrk; NT: Integer;
 AFirst,ALast,First,Last,I,Fn,Fd,StartMs,EndMs,K: LongInt; AOut: TTrkIn; APath: String; Acc: Int64; SkipV: Boolean;
 Rw,Rh: LongInt; DecMode: Integer;
Begin
 VideoJob:=False; Fmt:=M.Fmt;
 If InList(Fmt,'MP4,MOV,M4V,3GP') Then Ok:=Mp4Tracks(M.Path,V,A,Err)
 Else If Fmt='FLV' Then Ok:=FlvTracks(M.Path,V,A,Err)
 Else If Fmt='AVI' Then Begin Ok:=AviTracks(M.Path,V,Err); FillChar(A,SizeOf(A),0); End
 Else If InList(Fmt,'MKV,WEBM') Then Ok:=MkvTracks(M.Path,V,A,Err)
 Else Begin Err:='Conteneur vid'#233'o non pris en charge : '+Fmt+' (MP4, MOV, M4V, 3GP, FLV, AVI, MKV).'; Exit; End;
 If Not Ok Then Exit;
 If Not V.Ok Then Begin TrkClear(V); TrkClear(A); Err:='Aucune piste vid'#233'o dans ce fichier.'; Exit; End;
 DecMode:=VideoMode(Fmt,V);
 If DecMode<0 Then Begin
  Err:='Codec vid'#233'o '+V.Codec+' non d'#233'cod'#233' (H.264, MPEG-4/XviD/DivX seulement).'; TrkClear(V); TrkClear(A); Exit;
 End;
 If V.W=0 Then V.W:=M.W; If V.H=0 Then V.H:=M.H;
 HaveA:=A.Ok Or (M.ACodec<>''); AFlv:=Fmt='FLV';
 ParseRes(Pr.Res,VJResW,VJResH);
 If (Pr.Res='Auto') Or (Pr.Res='-') Then Begin VJResW:=0; VJResH:=0; End;
 StartMs:=M.TrimS; EndMs:=M.TrimE;
 Reenc:=(DecMode<>0) Or EditsPresent(M) Or (StartMs>0) Or ((VJResW>0) And ((VJResW<>V.W) Or (VJResH<>V.H))) Or (V.W=0);
 FillChar(Tr,SizeOf(Tr),0); NT:=0; Ok:=False; APath:=''; FillChar(AOut,SizeOf(AOut),0);
 SkipV:=False;
 { ---- audio ---- }
 If HaveA And (M.Vol>0) Then Begin
  If Not PrepareAudio(M,Pr,A,A.Ok,AFlv,M.Path,StartMs,EndMs,AOut,APath,AFirst,ALast,Err) Then Begin
   If Stopped Then Begin TrkClear(V); TrkClear(A); Exit; End;
   If Pos('Aucune piste audio',Err)=0 Then JobWarn:=' (sans audio : '+Err+')';
   HaveA:=False; Err:='';
  End;
 End Else HaveA:=False;
 { ---- video ---- }
 If Not Reenc Then Begin
  First:=0; Last:=V.N-1;
  If StartMs>0 Then Begin
   Acc:=0; K:=0;
   For I:=0 To V.N-1 Do Begin
    If Acc*1000.0/V.Ts<=StartMs Then If V.Sync^[I]<>0 Then K:=I;
    Inc(Acc,V.Dur^[I]);
   End;
   First:=K;
  End;
  If EndMs>0 Then Begin
   Acc:=0; Last:=V.N-1;
   For I:=0 To V.N-1 Do Begin
    If Acc*1000.0/V.Ts>=EndMs Then Begin Last:=I-1; Break; End;
    Inc(Acc,V.Dur^[I]);
   End;
   If Last<First Then Last:=First;
  End;
  Tr[0].T:=@V; Tr[0].First:=First; Tr[0].Last:=Last; Tr[0].Path:=M.Path; NT:=1;
  If HaveA Then Begin
   Tr[1].T:=@AOut; Tr[1].First:=AFirst; Tr[1].Last:=ALast; Tr[1].Path:=APath; NT:=2;
  End;
  StageLo:=90; StageHi:=100;
  Ok:=MuxMp4(Dst,BrandFor(Pr.Ext,False),Tr,NT,Err);
 End Else Begin
  FpsOf(V,Fn,Fd);
  VJFn:=Fn; VJFd:=Fd; VJMed:=@M; VJIdx:=0; VJN:=V.N; VJStarted:=False; VJNeedEdit:=EditsPresent(M);
  VJBitrate:=Pr.VKb*1000; If VJBitrate<=0 Then VJBitrate:=2000000;
  VJTrimS:=StartMs; VJTrimE:=EndMs; VJErr:=''; VJOut:=Nil;
  VFrameCb:=TranscodeCb;
  StageLo:=10; StageHi:=50; VJStarted:=False; VJCnt:=0;
  Ok:=DecodeVideoTrack(M.Path,V,0,DecMode,Err);
  VFrameCb:=Nil;
  If Ok And (VJErr<>'') Then Begin Ok:=False; Err:=VJErr; End;
  If Ok And Not VJStarted Then Begin Ok:=False; Err:='Aucune image d'#233'cod'#233'e.'; End;
  If VJStarted Then Begin
   If Ok Then Begin StageLo:=50; StageHi:=90; Ok:=EncodeTemp(Err); End;
   Close(VJTmp); DelFile(VJTmpName);
  End;
  If VJOut<>Nil Then Begin FreeMem(VJOut,VJOutW*VJOutH*3 Div 2+64); VJOut:=Nil; End;
  If Ok Then Begin
   EncoderTrack(Vo);
   Tr[0].T:=@Vo; Tr[0].First:=0; Tr[0].Last:=Vo.N-1; Tr[0].Mem:=PBArr(X4O); Tr[0].Annex:=True; NT:=1;
   If HaveA Then Begin
    Tr[1].T:=@AOut; Tr[1].First:=AFirst; Tr[1].Last:=ALast; Tr[1].Path:=APath; NT:=2;
   End;
   StageLo:=90; StageHi:=100;
   Ok:=MuxMp4(Dst,BrandFor(Pr.Ext,False),Tr,NT,Err);
   TrkClear(Vo);
  End;
  VEncFree;
 End;
 If HaveA Then Begin
  If (APath<>'') And (APath<>M.Path) Then Begin DelFile(APath); TrkClear(AOut); End;
 End;
 TrkClear(V); TrkClear(A);
 VideoJob:=Ok;
End;

{ Image / GIF anime -> video MP4 (H.264) }
Function ImageVideoJob(Var M: TMedia; Const Pr: TProf; Const Dst: String; Var Err: String): Boolean;
Var A: PAnim; K,Rep,R,I,Total: LongInt; Ok: Boolean; Vo: TTrkIn; Tr: Array[0..0] Of TMuxTrk; Im,T: PImg; Out: PEABuffer; OW,OH: LongInt;
Begin
 ImageVideoJob:=False;
 If Not LoadAnim(M.Path,A,MaxAnim) Then Begin Err:='Format d''image non pris en charge (BMP/GIF seulement).'; Exit; End;
 ParseRes(Pr.Res,VJResW,VJResH);
 If (Pr.Res='Auto') Or (Pr.Res='-') Then Begin VJResW:=0; VJResH:=0; End;
 For K:=1 To A^.N Do ApplyEdit(M,A^.F[K]);
 VJMed:=@M;
 CalcOutDims(M,A^.F[1]^.W,A^.F[1]^.H,OW,OH);
 { le redimensionnement est deja fait par ApplyEdit pour la rotation/crop : ne pas les refaire }
 OW:=A^.F[1]^.W And (Not 1); OH:=A^.F[1]^.H And (Not 1);
 If (VJResW>0) And (VJResH>0) Then Begin OW:=VJResW And (Not 1); OH:=VJResH And (Not 1); End;
 If OW<16 Then OW:=16; If OH<16 Then OH:=16;
 Total:=0;
 For K:=1 To A^.N Do Begin
  If A^.N=1 Then Rep:=125 Else Rep:=Max(1,(A^.Dly[K]*25+50) Div 100);
  Inc(Total,Rep);
 End;
 If Not VEncBegin(OW,OH,25,1,Total,Max(Pr.VKb*1000,1000000),Err) Then Begin AnimFree(A); Exit; End;
 GetMem(Out,OW*OH*3 Div 2+64);
 For K:=1 To A^.N Do Begin
  Im:=A^.F[K];
  If (Im^.W<>OW) Or (Im^.H<>OH) Then Begin
   T:=ImgFit(Im,OW,OH,0,0,0,False); If T<>Nil Then Begin ImgFree(A^.F[K]); A^.F[K]:=T; Im:=T; End;
  End;
  ImgToYuv(Im,Out);
  If A^.N=1 Then Rep:=125 Else Rep:=Max(1,(A^.Dly[K]*25+50) Div 100);
  For R:=1 To Rep Do Begin
   VEncFrame(Out);
   If (VEFrame And 7)=0 Then UiTick(VEFrame,Total);
   If Stopped Then Break;
  End;
  If Stopped Then Break;
 End;
 FreeMem(Out,OW*OH*3 Div 2+64); AnimFree(A);
 If Stopped Then Begin VEncFree; Err:='Conversion annul'#233'e.'; Exit; End;
 EncoderTrack(Vo);
 FillChar(Tr,SizeOf(Tr),0);
 Tr[0].T:=@Vo; Tr[0].First:=0; Tr[0].Last:=Vo.N-1; Tr[0].Mem:=PBArr(X4O); Tr[0].Annex:=True;
 StageLo:=90; StageHi:=100;
 Ok:=MuxMp4(Dst,BrandFor(Pr.Ext,False),Tr,1,Err);
 TrkClear(Vo); VEncFree;
 ImageVideoJob:=Ok;
End;
{$ENDIF}

{ ====================================================================== }
{ Dialogues : Modifier, Couper, Format de sortie, Preferences                }
{ ====================================================================== }
Procedure FitRect(Iw,Ih,Bx,By,Bw,Bh: LongInt; Var Rx,Ry,Rw,Rh: LongInt);
Begin
 If Iw<1 Then Iw:=1; If Ih<1 Then Ih:=1;
 If Iw*Bh>Ih*Bw Then Begin Rw:=Bw; Rh:=(Ih*Bw) Div Iw; End Else Begin Rh:=Bh; Rw:=(Iw*Bh) Div Ih; End;
 If Rw<1 Then Rw:=1; If Rh<1 Then Rh:=1;
 Rx:=Bx+(Bw-Rw) Div 2; Ry:=By+(Bh-Rh) Div 2;
End;

{ Image source (premiere image) pour un media, ou Nil }
Function SourceImage(Var M: TMedia): PImg;
Begin
 SourceImage:=Nil;
 If (M.Kind=3) Or (M.Fmt='GIF') Then SourceImage:=LoadFirst(M.Path)
 {$IFDEF FPC}
 Else If M.Kind=2 Then SourceImage:=VideoFirstFrame(M.Path,M.Fmt)
 {$ENDIF};
End;

Procedure Placeholder(X,Y,W,H: LongInt; Kind: Byte);
Begin
 Rect(X,Y,X+W-1,Y+H-1,cNavy);
 If Kind=1 Then Begin
  SetColor(cBlueL); Circle(X+W Div 2,Y+H Div 2,16);
  Line(X+W Div 2-10,Y+H Div 2,X+W Div 2-5,Y+H Div 2-8); Line(X+W Div 2-5,Y+H Div 2-8,X+W Div 2,Y+H Div 2+8);
  Line(X+W Div 2,Y+H Div 2+8,X+W Div 2+5,Y+H Div 2-4); Line(X+W Div 2+5,Y+H Div 2-4,X+W Div 2+10,Y+H Div 2);
 End Else Begin
  Rect(X+W Div 2-20,Y+H Div 2-14,X+W Div 2+20,Y+H Div 2+14,cBlue);
  Tri(X+W Div 2+1,Y+H Div 2,2,cWhite);
 End;
End;

Procedure OutDims(Const M: TMedia; Var W,H: LongInt);
Begin
 W:=M.W; H:=M.H;
 If M.CropW>0 Then Begin W:=M.CropW; H:=M.CropH; End;
 If Odd(M.Rot) Then Begin W:=M.H; H:=M.W; If M.CropW>0 Then Begin W:=M.CropH; H:=M.CropW; End; End;
End;

Procedure EditDlg(Idx: Integer; StartTab: Integer);
Const
 TabW: Array[0..4] Of Integer = (156,64,88,64,88);
 TabLab: Array[0..4] Of String[20] = ('Rotation & Rognage','Effet','Filigrane','Audio','Sous-titre');
Var
 W: TMedia; Orig,PvR: PImg; Tb: Integer; X1,Y1,X2,Y2: Integer; Done,Ok: Boolean; E: TEvent; Id,I,K: Integer;
 BoxLX,BoxLY,BoxW,BoxH,BoxRX: Integer; Rx,Ry,Rw,Rh: LongInt; Sw,Sh,Ow,Oh: LongInt; Sx0,Sy0,MX,MY: Integer;
 Fac: Double; Mk: TMedia; Sc: PImg; V: LongInt; S: String; Sx,Sy,Sw2,Sh2: Integer; Bm: Boolean;

 Procedure Render;
 Var F: Double;
 Begin
  ImgFree(PvR);
  If Orig=Nil Then Exit;
  F:=1.0; If Orig^.W>BoxW*2 Then F:=BoxW*2/Orig^.W;
  Sc:=ImgScale(Orig,Max(1,Round(Orig^.W*F)),Max(1,Round(Orig^.H*F)));
  If Sc=Nil Then Exit;
  Mk:=W; Mk.CropX:=Round(W.CropX*F); Mk.CropY:=Round(W.CropY*F); Mk.CropW:=Round(W.CropW*F); Mk.CropH:=Round(W.CropH*F);
  If (W.CropW>0) And (Mk.CropW<1) Then Mk.CropW:=1;
  If (W.CropW>0) And (Mk.CropH<1) Then Mk.CropH:=1;
  ApplyEdit(Mk,Sc);
  PvR:=Sc;
 End;

 Procedure Draw;
 Var X,Y,N,Z: Integer; Fg: Byte; Pw,Ph: LongInt; St: String; Bx,By: Integer;
 Begin
  HotClear;
  DlgFrame(X1,Y1,X2,Y2,'Modifier - '+Fit(NameOf(W.Path),420));
  { onglets }
  X:=X1+10;
  For N:=0 To 4 Do Begin
   Z:=TabW[N];
   If N=Tb Then Begin Rect(X,Y1+24,X+Z-1,Y1+44,cWhite); HLn(X,X+Z-1,Y1+24,cBlue); HLn(X,X+Z-1,Y1+25,cBlue); End;
   TxtC(X,X+Z-1,Y1+31,TabLab[N],Ord(N=Tb)*cBlue+Ord(N<>Tb)*cGrayD);
   HotAdd(X,Y1+24,Z,21,300+N);
   Inc(X,Z+4);
  End;
  HLn(X1+1,X2-1,Y1+45,cSteel);
  Rect(X1+1,Y1+46,X2-1,Y2-38,cWhite);
  { apercus }
  OutDims(W,Pw,Ph);
  If W.W>0 Then Txt(BoxLX,Y1+52,'Origine: '+IStr(W.W)+'x'+IStr(W.H),cBlack) Else Txt(BoxLX,Y1+52,'Origine : audio',cBlack);
  TxtC(BoxLX,BoxRX+BoxW,Y1+52,Fit(NameOf(W.Path),200),cGrayD);
  If W.W>0 Then TxtR(BoxRX+BoxW,Y1+52,'Sortie: '+IStr(Pw)+'x'+IStr(Ph),cBlack) Else TxtR(BoxRX+BoxW,Y1+52,'Sortie : audio',cBlack);
  Rect(BoxLX,BoxLY,BoxLX+BoxW-1,BoxLY+BoxH-1,cNavy); Rect(BoxRX,BoxLY,BoxRX+BoxW-1,BoxLY+BoxH-1,cNavy);
  FitRect(W.W,W.H,BoxLX,BoxLY,BoxW,BoxH,Rx,Ry,Rw,Rh);
  If Orig<>Nil Then DrawImg(Orig,BoxLX,BoxLY,BoxW,BoxH) Else Begin
   Placeholder(Rx,Ry,Rw,Rh,W.Kind);
  End;
  If (W.W>0) And (W.CropW>0) Then Begin
   Sx:=Rx+Integer((W.CropX*Rw) Div W.W); Sy:=Ry+Integer((W.CropY*Rh) Div W.H);
   Sw2:=Integer((W.CropW*Rw) Div W.W); Sh2:=Integer((W.CropH*Rh) Div W.H);
   SetColor(cGold); Rectangle(Sx,Sy,Sx+Sw2,Sy+Sh2); Rectangle(Sx+1,Sy+1,Sx+Sw2-1,Sy+Sh2-1);
   Rect(Sx-2,Sy-2,Sx+2,Sy+2,cWhite); Rect(Sx+Sw2-2,Sy-2,Sx+Sw2+2,Sy+2,cWhite);
   Rect(Sx-2,Sy+Sh2-2,Sx+2,Sy+Sh2+2,cWhite); Rect(Sx+Sw2-2,Sy+Sh2-2,Sx+Sw2+2,Sy+Sh2+2,cWhite);
  End;
  HotAdd(BoxLX,BoxLY,BoxW,BoxH,330);
  If (PvR<>Nil) Then DrawImg(PvR,BoxRX,BoxLY,BoxW,BoxH)
  Else If W.W>0 Then Begin
   OutDims(W,Pw,Ph); FitRect(Pw,Ph,BoxRX,BoxLY,BoxW,BoxH,Rx,Ry,Rw,Rh); Placeholder(Rx,Ry,Rw,Rh,W.Kind);
   If W.WmOn And (W.WmText<>'') Then TxtC(Rx,Rx+Rw-1,Ry+Rh-14,Fit(W.WmText,Integer(Rw)),cWhite);
  End;
  { barre de lecture }
  IcoPlay(X1+14,Y1+BoxH+BoxLY-Y1+6,cBlue); Rect(X1+30,BoxLY+BoxH+6,X1+38,BoxLY+BoxH+14,cGrayD);
  SetColor(cGrayD); Line(X1+48,BoxLY+BoxH+6,X1+48,BoxLY+BoxH+14); Line(X1+60,BoxLY+BoxH+6,X1+60,BoxLY+BoxH+14);
  Rect(X1+80,BoxLY+BoxH+9,X2-190,BoxLY+BoxH+11,cLine); Disc(X1+80,BoxLY+BoxH+10,4,cOrange);
  TxtR(X2-80,BoxLY+BoxH+6,TimeStrMs(0)+'/'+TimeStrMs(W.DurMs),cGrayD);
  IcoSpeaker(X2-64,BoxLY+BoxH+4,cBlue);
  { zone de reglages }
  Bx:=X1+20; By:=BoxLY+BoxH+34;
  Case Tb Of
   0: Begin
    Txt(Bx,By+4,'Rotation:',cBlack);
    Button(Bx+80,By,30,20,'<-',310,bsBlue); Button(Bx+118,By,30,20,'->',311,bsBlue);
    Button(Bx+156,By,30,20,'<>',312,bsBlue); Button(Bx+194,By,30,20,'^v',313,bsBlue);
    Button(Bx+240,By,128,20,'Appliquer '#224' Tout',314,bsNormal);
    Txt(Bx,By+34,'Zone '#224' rogner:',cBlack);
    If W.CropW>0 Then S:=IStr(W.CropW)+' x '+IStr(W.CropH) Else S:=IStr(W.W)+' x '+IStr(W.H);
    Combo(Bx+120,By+30,110,18,S,315);
    Txt(Bx+244,By+34,'Position:',cBlack);
    Combo(Bx+322,By+30,96,18,IStr(W.CropX)+','+IStr(W.CropY),316);
    Txt(Bx,By+60,'Ratio d''aspect:',cBlack);
    Case W.Aspect Of 1: S:='Original'; 2: S:='16:9'; 3: S:='4:3'; 4: S:='1:1'; 5: S:='9:16'; Else S:='Personnalis'#233; End;
    Combo(Bx+128,By+56,118,18,S,317);
    Txt(Bx+260,By+60,'Zoom:',cBlack);
    Case W.ZoomMode Of 1: S:='Pan & Scan'; 2: S:='Plein'; Else S:='Bo'#238'te aux lettres'; End;
    Combo(Bx+316,By+56,152,18,S,318);
    Button(Bx+480,By+56,76,18,'R'#233'init.',319,bsNormal);
   End;
   1: Begin
    Txt(Bx,By+4,'Luminosit'#233':',cBlack); SliderBar(Bx+100,By+2,220,W.Bright,-100,100,340); TxtR(Bx+390,By+4,IStr(W.Bright),cBlue);
    Txt(Bx,By+24,'Contraste:',cBlack); SliderBar(Bx+100,By+22,220,W.Contr,-100,100,341); TxtR(Bx+390,By+24,IStr(W.Contr),cBlue);
    Txt(Bx,By+44,'Saturation:',cBlack); SliderBar(Bx+100,By+42,220,W.Satur,-100,100,342); TxtR(Bx+390,By+44,IStr(W.Satur),cBlue);
    Txt(Bx,By+64,'Teinte:',cBlack); SliderBar(Bx+100,By+62,220,W.Hue,-100,100,343); TxtR(Bx+390,By+64,IStr(W.Hue),cBlue);
    CheckBox(Bx+420,By+4,'D'#233'sentrelacer',W.Deint,344);
    Button(Bx+420,By+30,100,20,'R'#233'initialiser',345,bsNormal);
   End;
   2: Begin
    CheckBox(Bx,By+4,'Filigrane texte',W.WmOn,350);
    Txt(Bx+140,By+4,'Texte:',cBlack); Combo(Bx+190,By,220,18,W.WmText,351);
    Txt(Bx,By+30,'Position:',cBlack);
    For N:=0 To 8 Do Begin
     Panel(Bx+80+(N Mod 3)*18,By+26+(N Div 3)*14,Bx+94+(N Mod 3)*18,By+36+(N Div 3)*14,Ord(N=W.WmPos)*cBlue+Ord(N<>W.WmPos)*cWhite,cSteel);
     HotAdd(Bx+80+(N Mod 3)*18,By+26+(N Div 3)*14,15,11,360+N);
    End;
    Txt(Bx+160,By+30,'Taille:',cBlack);
    Case W.WmSize Of 1: S:='Petit'; 2: S:='Moyen'; 3: S:='Grand'; Else S:='Tr'#232's grand'; End;
    Combo(Bx+220,By+26,100,18,S,352);
    Txt(Bx+160,By+56,'Opacit'#233':',cBlack); SliderBar(Bx+236,By+54,160,W.WmAlpha,0,100,353); TxtR(Bx+450,By+56,IStr(W.WmAlpha)+'%',cBlue);
   End;
   3: Begin
    Txt(Bx,By+4,'Volume:',cBlack); SliderBar(Bx+100,By+2,260,W.Vol,0,200,370); TxtR(Bx+430,By+4,IStr(W.Vol)+'%',cBlue);
    Txt(Bx,By+30,'D'#233'lai audio:',cBlack);
    Button(Bx+104,By+26,38,18,'-100',371,bsNormal); Button(Bx+146,By+26,32,18,'-10',372,bsNormal);
    Panel(Bx+184,By+26,Bx+264,By+43,cWhite,cSteel); TxtC(Bx+184,Bx+264,By+31,IStr(W.ADelay)+' ms',cBlack);
    Button(Bx+270,By+26,32,18,'+10',373,bsNormal); Button(Bx+306,By+26,38,18,'+100',374,bsNormal);
    Txt(Bx,By+56,'Piste audio:',cBlack); Combo(Bx+100,By+52,200,18,'Piste 1 (auto)',375);
   End;
   4: Begin
    Button(Bx,By,190,22,'+ Ajouter un sous-titre',380,bsBlue);
    If W.SubFile<>'' Then Begin
     Txt(Bx+200,By+7,Fit(NameOf(W.SubFile),260),cBlack); Button(Bx+490,By,80,22,'Supprimer',381,bsNormal);
    End Else Txt(Bx+200,By+7,'Aucun (.srt, .ass, .ssa, .sub)',cGrayD);
    Txt(Bx,By+36,'Position:',cBlack);
    Case W.SubPos Of 1: S:='Haut'; 2: S:='Centre'; Else S:='Bas'; End;
    Combo(Bx+80,By+32,100,18,S,382);
    Txt(Bx,By+62,'Les sous-titres ne sont incrust'#233's que par un encodeur vid'#233'o.',cGrayD);
   End;
  End;
  Button(X2-190,Y2-32,84,24,'OK',390,bsPrimary); Button(X2-98,Y2-32,84,24,'Annuler',391,bsNormal);
 End;

 Procedure SetCropAspect(A: Integer);
 Var Rr: Double; Cw,Ch: LongInt;
 Begin
  W.Aspect:=A;
  Case A Of 2: Rr:=16/9; 3: Rr:=4/3; 4: Rr:=1; 5: Rr:=9/16; Else Rr:=0; End;
  If A=1 Then Begin W.CropW:=0; W.CropH:=0; W.CropX:=0; W.CropY:=0; End
  Else If Rr>0 Then Begin
   If W.W/W.H>Rr Then Begin Ch:=W.H; Cw:=Round(W.H*Rr); End Else Begin Cw:=W.W; Ch:=Round(W.W/Rr); End;
   W.CropW:=Cw; W.CropH:=Ch; W.CropX:=(W.W-Cw) Div 2; W.CropY:=(W.H-Ch) Div 2;
  End;
 End;

 Procedure ApplyAll;
 Var N: Integer;
 Begin
  For N:=1 To NFiles Do If N<>Idx Then Begin
   Files[N]^.Rot:=W.Rot; Files[N]^.FlipH:=W.FlipH; Files[N]^.FlipV:=W.FlipV;
   Files[N]^.Bright:=W.Bright; Files[N]^.Contr:=W.Contr; Files[N]^.Satur:=W.Satur; Files[N]^.Hue:=W.Hue;
   Files[N]^.WmOn:=W.WmOn; Files[N]^.WmText:=W.WmText; Files[N]^.WmPos:=W.WmPos; Files[N]^.WmSize:=W.WmSize; Files[N]^.WmAlpha:=W.WmAlpha;
   Files[N]^.Vol:=W.Vol; Files[N]^.ADelay:=W.ADelay;
  End;
  Info('Les r'#233'glages ont '#233't'#233' appliqu'#233's '#224' tous les fichiers.');
 End;

 Procedure Slide(Var V: Integer; Lo,Hi,HotId: Integer);
 Var HX,HY,HW,HH: Integer; Mx,My: Integer; Bt: LongInt; Last: Integer;
 Begin
  If Not GetHot(HotId,HX,HY,HW,HH) Then Exit;
  Last:=V-1;
  Repeat
   ReadMouse(Mx,My,Bt);
   V:=SliderVal(HX,HW,Mx,Lo,Hi);
   If V<>Last Then Begin Last:=V; HideMouse; Draw; ShowMouse; End;
   Delay(5);
  Until (Bt And 1)=0;
  Render; HideMouse; Draw; ShowMouse;
 End;

Begin
 W:=Files[Idx]^;
 X1:=8; Y1:=22; X2:=ScrW-9; Y2:=ScrH-8; Tb:=StartTab;
 BoxLX:=X1+12; BoxLY:=Y1+68; BoxW:=290; BoxH:=140; BoxRX:=X1+ (X2-X1) Div 2+10;
 PvR:=Nil; Orig:=SourceImage(W);
 Render; Done:=False; Ok:=False;
 HideMouse; Draw; ShowMouse;
 Repeat
  WaitEvent(E);
  If E.Kind=evDown Then Begin
   Id:=HotAt(E.X,E.Y);
   If (Id=330) And (W.W>0) Then Begin
    { selection d'une zone de rognage a la souris }
    FitRect(W.W,W.H,BoxLX,BoxLY,BoxW,BoxH,Rx,Ry,Rw,Rh);
    Sx0:=E.X; Sy0:=E.Y;
    Repeat
     ReadMouse(MX,MY,V);
     MX:=Clip(MX,Rx,Rx+Rw-1); MY:=Clip(MY,Ry,Ry+Rh-1);
     Sx:=Clip(Sx0,Rx,Rx+Rw-1); Sy:=Clip(Sy0,Ry,Ry+Rh-1);
     If (Abs(MX-Sx)>3) And (Abs(MY-Sy)>3) Then Begin
      W.CropX:=((Min(MX,Sx)-Rx)*W.W) Div Rw; W.CropY:=((Min(MY,Sy)-Ry)*W.H) Div Rh;
      W.CropW:=Max(2,(Abs(MX-Sx)*W.W) Div Rw); W.CropH:=Max(2,(Abs(MY-Sy)*W.H) Div Rh);
      W.Aspect:=0;
      HideMouse; Draw; ShowMouse;
     End;
     Delay(10);
    Until Not MouseDown;
    Render; HideMouse; Draw; ShowMouse;
   End Else If Id=340 Then Begin Slide(W.Bright,-100,100,340); End
   Else If Id=341 Then Slide(W.Contr,-100,100,341)
   Else If Id=342 Then Slide(W.Satur,-100,100,342)
   Else If Id=343 Then Slide(W.Hue,-100,100,343)
   Else If Id=353 Then Slide(W.WmAlpha,0,100,353)
   Else If Id=370 Then Slide(W.Vol,0,200,370);
  End Else If E.Kind=evUp Then Begin
   Id:=HotAt(E.X,E.Y);
   If (Id>=300) And (Id<=304) Then Begin Tb:=Id-300; HideMouse; Draw; ShowMouse; End
   Else Case Id Of
    310: Begin W.Rot:=(W.Rot+3) Mod 4; Render; End;
    311: Begin W.Rot:=(W.Rot+1) Mod 4; Render; End;
    312: Begin W.FlipH:=Not W.FlipH; Render; End;
    313: Begin W.FlipV:=Not W.FlipV; Render; End;
    314: ApplyAll;
    315: Begin
     V:=W.CropW; If V=0 Then V:=W.W;
     If InputNum('Zone '#224' rogner','Largeur (pixels) :',V,2,W.W) Then Begin
      W.CropW:=V; K:=W.CropH; If K=0 Then K:=W.H; V:=K;
      If InputNum('Zone '#224' rogner','Hauteur (pixels) :',V,2,W.H) Then W.CropH:=V;
      W.Aspect:=0; If W.CropX+W.CropW>W.W Then W.CropX:=W.W-W.CropW; If W.CropY+W.CropH>W.H Then W.CropY:=W.H-W.CropH;
      Render;
     End;
    End;
    316: Begin
     V:=W.CropX; If InputNum('Position','X :',V,0,Max(0,W.W-Max(W.CropW,1))) Then Begin
      W.CropX:=V; V:=W.CropY;
      If InputNum('Position','Y :',V,0,Max(0,W.H-Max(W.CropH,1))) Then W.CropY:=V;
      If W.CropW=0 Then Begin W.CropW:=W.W-W.CropX; W.CropH:=W.H-W.CropY; End;
      Render;
     End;
    End;
    317: Begin
     I:=PopupMenu(E.X-60,E.Y+4,'Personnalis'#233'|Original|16:9|4:3|1:1|9:16',W.Aspect+1,110);
     If I>0 Then Begin If I=1 Then W.Aspect:=0 Else SetCropAspect(I-1); Render; End;
    End;
    318: Begin
     I:=PopupMenu(E.X-60,E.Y+4,'Bo'#238'te aux lettres|Pan & Scan|Plein',W.ZoomMode+1,150);
     If I>0 Then W.ZoomMode:=I-1;
    End;
    319: Begin W.CropX:=0; W.CropY:=0; W.CropW:=0; W.CropH:=0; W.Rot:=0; W.FlipH:=False; W.FlipV:=False; W.Aspect:=0; Render; End;
    344: W.Deint:=Not W.Deint;
    345: Begin W.Bright:=0; W.Contr:=0; W.Satur:=0; W.Hue:=0; Render; End;
    350: Begin W.WmOn:=Not W.WmOn; Render; End;
    351: Begin S:=W.WmText; If InputBox('Filigrane','Texte du filigrane :',S,40) Then Begin W.WmText:=S; W.WmOn:=S<>''; Render; End; End;
    352: Begin I:=PopupMenu(E.X-40,E.Y+4,'Petit|Moyen|Grand|Tr'#232's grand',W.WmSize,100); If I>0 Then Begin W.WmSize:=I; Render; End; End;
    360..368: Begin W.WmPos:=Id-360; Render; End;
    371: W.ADelay:=Clip(W.ADelay-100,-30000,30000);
    372: W.ADelay:=Clip(W.ADelay-10,-30000,30000);
    373: W.ADelay:=Clip(W.ADelay+10,-30000,30000);
    374: W.ADelay:=Clip(W.ADelay+100,-30000,30000);
    375: Info('Une seule piste audio disponible.');
    380: If FileDlg('Ajouter un sous-titre',False,False,4) Then W.SubFile:=PickList[1];
    381: W.SubFile:='';
    382: Begin I:=PopupMenu(E.X-20,E.Y+4,'Bas|Haut|Centre',W.SubPos+1,100); If I>0 Then W.SubPos:=I-1; End;
    390: Begin Ok:=True; Done:=True; End;
    391: Done:=True;
    Else If (E.X>=X2-18) And (E.X<=X2-3) And (E.Y>=Y1+3) And (E.Y<=Y1+18) Then Done:=True;
   End;
   If Not Done Then Begin HideMouse; Draw; ShowMouse; End;
  End Else If E.Kind=evKey Then Begin
   If E.Key=kEsc Then Done:=True;
  End;
 Until Done;
 If Ok Then Files[Idx]^:=W;
 ImgFree(Orig); ImgFree(PvR);
 Refresh;
End;

{ ---------------------------------------------------------------------- }
{ Couper                                                                      }
{ ---------------------------------------------------------------------- }
Procedure CutDlg(Idx: Integer);
Var
 M: PMedia; X1,Y1,X2,Y2: Integer; S,E2: LongInt; Done,Ok: Boolean; Ev: TEvent; Id: Integer; TX,TW: Integer; Orig: PImg; Dur: LongInt;
 Tmp: String; Mx,My: Integer; Bt: LongInt; Pos,Rx,Ry,Rw,Rh: LongInt;

 Function Px(Ms: LongInt): Integer;
 Begin
  If Dur<1 Then Px:=TX Else Px:=TX+Integer((Ms*TW) Div Dur);
 End;

 Procedure Draw;
 Begin
  HotClear;
  DlgFrame(X1,Y1,X2,Y2,'Couper - '+Fit(NameOf(M^.Path),360));
  Rect(X1+1,Y1+20,X2-1,Y2-1,cWhite);
  Rect(X1+90,Y1+30,X1+410,Y1+190,cNavy);
  FitRect(Max(M^.W,16),Max(M^.H,9),X1+90,Y1+30,320,160,Rx,Ry,Rw,Rh);
  If Orig<>Nil Then DrawImg(Orig,X1+90,Y1+30,320,160) Else Placeholder(Rx,Ry,Rw,Rh,M^.Kind);
  { ligne de temps }
  Rect(TX,Y1+212,TX+TW,Y1+224,cLine);
  Rect(Px(S),Y1+212,Px(E2),Y1+224,cSky);
  Frame(TX,Y1+212,TX+TW,Y1+224,cSteel);
  Rect(Px(S)-3,Y1+206,Px(S)+3,Y1+230,cBlue); Rect(Px(E2)-3,Y1+206,Px(E2)+3,Y1+230,cBlue);
  HotAdd(TX-6,Y1+204,TW+12,28,400);
  Txt(TX,Y1+236,TimeStrMs(0),cGrayD); TxtR(TX+TW,Y1+236,TimeStrMs(Dur),cGrayD);
  Txt(X1+30,Y1+262,'D'#233'but:',cBlack); Combo(X1+80,Y1+258,130,18,TimeStrMs(S),401);
  Txt(X1+240,Y1+262,'Fin:',cBlack); Combo(X1+280,Y1+258,130,18,TimeStrMs(E2),402);
  Txt(X1+30,Y1+288,'Dur'#233'e s'#233'lectionn'#233'e :',cBlack); Txt(X1+190,Y1+288,TimeStrMs(E2-S),cBlue);
  Button(X1+300,Y1+283,110,20,'R'#233'initialiser',403,bsNormal);
  Button(X2-190,Y2-34,84,24,'OK',404,bsPrimary); Button(X2-98,Y2-34,84,24,'Annuler',405,bsNormal);
 End;

Begin
 M:=Files[Idx]; Dur:=M^.DurMs; If Dur<1 Then Dur:=1;
 S:=M^.TrimS; E2:=M^.TrimE; If (E2=0) Or (E2>Dur) Then E2:=Dur;
 X1:=100; Y1:=70; X2:=ScrW-100; Y2:=ScrH-70; TX:=X1+40; TW:=X2-X1-80;
 Orig:=SourceImage(M^); Done:=False; Ok:=False;
 HideMouse; Draw; ShowMouse;
 Repeat
  WaitEvent(Ev);
  If Ev.Kind=evDown Then Begin
   If HotAt(Ev.X,Ev.Y)=400 Then Begin
    { choisit la poignee la plus proche et la deplace }
    If Abs(Ev.X-Px(S))<=Abs(Ev.X-Px(E2)) Then Id:=1 Else Id:=2;
    Repeat
     ReadMouse(Mx,My,Bt);
     Pos:=Clip(((Mx-TX)*Dur) Div TW,0,Dur);
     If Id=1 Then S:=Min(Pos,E2-100) Else E2:=Max(Pos,S+100);
     If S<0 Then S:=0; If E2>Dur Then E2:=Dur;
     HideMouse; Draw; ShowMouse; Delay(5);
    Until (Bt And 1)=0;
   End;
  End Else If Ev.Kind=evUp Then Begin
   Id:=HotAt(Ev.X,Ev.Y);
   Case Id Of
    401: Begin Tmp:=TimeStrMs(S); If InputBox('D'#233'but','Heure de d'#233'but (hh:mm:ss.mmm) :',Tmp,12) Then S:=Clip(ParseTime(Tmp),0,E2-100); End;
    402: Begin Tmp:=TimeStrMs(E2); If InputBox('Fin','Heure de fin (hh:mm:ss.mmm) :',Tmp,12) Then E2:=Clip(ParseTime(Tmp),S+100,Dur); End;
    403: Begin S:=0; E2:=Dur; End;
    404: Begin Ok:=True; Done:=True; End;
    405: Done:=True;
    Else If (Ev.X>=X2-18) And (Ev.X<=X2-3) And (Ev.Y>=Y1+3) And (Ev.Y<=Y1+18) Then Done:=True;
   End;
   If Not Done Then Begin HideMouse; Draw; ShowMouse; End;
  End Else If (Ev.Kind=evKey) And (Ev.Key=kEsc) Then Done:=True;
 Until Done;
 If Ok Then Begin
  M^.TrimS:=S; If E2>=Dur Then M^.TrimE:=0 Else M^.TrimE:=E2;
 End;
 ImgFree(Orig); Refresh;
End;

{ ---------------------------------------------------------------------- }
{ Format de sortie                                                           }
{ ---------------------------------------------------------------------- }
Procedure CustomDlg;
Var X1,Y1,X2,Y2: Integer; Done: Boolean; E: TEvent; Id,I: Integer; V: LongInt;
 Procedure Draw;
 Var S: String;
 Begin
  HotClear;
  DlgFrame(X1,Y1,X2,Y2,'Profil personnalis'#233' - '+Profs[CurProf].Name);
  Rect(X1+1,Y1+20,X2-1,Y2-1,cWhite);
  Txt(X1+20,Y1+38,'Encodeur vid'#233'o :',cBlack); Txt(X1+200,Y1+38,Profs[CurProf].VC,cGrayD);
  Txt(X1+20,Y1+62,'Encodeur audio :',cBlack); Txt(X1+200,Y1+62,Profs[CurProf].AC,cGrayD);
  Txt(X1+20,Y1+90,'D'#233'bit audio (kbps) :',cBlack); Combo(X1+200,Y1+86,120,18,IStr(Profs[CurProf].AKb),500);
  Txt(X1+20,Y1+116,'Fr'#233'quence (Hz) :',cBlack);
  If CustRate=0 Then S:='Auto' Else S:=IStr(CustRate);
  Combo(X1+200,Y1+112,120,18,S,501);
  Txt(X1+20,Y1+142,'Canaux :',cBlack);
  Case CustCh Of 1: S:='Mono'; 2: S:='St'#233'r'#233'o'; Else S:='Auto'; End;
  Combo(X1+200,Y1+138,120,18,S,502);
  Txt(X1+20,Y1+168,'D'#233'bit vid'#233'o (kbps) :',cBlack); Combo(X1+200,Y1+164,120,18,IStr(Profs[CurProf].VKb),503);
  Txt(X1+20,Y1+194,'Cadence (i/s) :',cBlack); Combo(X1+200,Y1+190,120,18,IStr(CustFps),504);
  Txt(X1+20,Y1+222,'Le d'#233'bit audio s''applique au MP3. Les r'#233'glages vid'#233'o sont conserv'#233's',cGrayD);
  Txt(X1+20,Y1+234,'pour le profil mais ne servent qu'#224' un encodeur vid'#233'o externe.',cGrayD);
  Button(X1+20,Y2-34,100,24,'Par d'#233'faut',505,bsNormal);
  Button(X2-190,Y2-34,84,24,'OK',506,bsPrimary); Button(X2-98,Y2-34,84,24,'Annuler',507,bsNormal);
 End;
Begin
 X1:=120; Y1:=80; X2:=ScrW-120; Y2:=ScrH-80; Done:=False;
 HideMouse; Draw; ShowMouse;
 Repeat
  WaitEvent(E);
  If E.Kind=evUp Then Begin
   Id:=HotAt(E.X,E.Y);
   Case Id Of
    500: Begin I:=PopupMenu(E.X-40,E.Y+4,'32|40|48|56|64|80|96|112|128|160|192|224|256|320',1,80);
      If I>0 Then Begin Case I Of 1: V:=32; 2: V:=40; 3: V:=48; 4: V:=56; 5: V:=64; 6: V:=80; 7: V:=96; 8: V:=112; 9: V:=128; 10: V:=160; 11: V:=192; 12: V:=224; 13: V:=256; Else V:=320 End; Profs[CurProf].AKb:=V; End; End;
    501: Begin I:=PopupMenu(E.X-40,E.Y+4,'Auto|8000|11025|16000|22050|32000|44100|48000',1,80);
      If I>0 Then Begin Case I Of 1: CustRate:=0; 2: CustRate:=8000; 3: CustRate:=11025; 4: CustRate:=16000; 5: CustRate:=22050; 6: CustRate:=32000; 7: CustRate:=44100; Else CustRate:=48000 End; End; End;
    502: Begin I:=PopupMenu(E.X-40,E.Y+4,'Auto|Mono|St'#233'r'#233'o',CustCh+1,80); If I>0 Then CustCh:=I-1; End;
    503: Begin V:=Profs[CurProf].VKb; If InputNum('D'#233'bit vid'#233'o','Kbps :',V,0,100000) Then Profs[CurProf].VKb:=V; End;
    504: Begin V:=CustFps; If InputNum('Cadence','Images par seconde :',V,1,120) Then CustFps:=V; End;
    505: Begin CustRate:=0; CustCh:=0; CustFps:=30; InitProfiles; End;
    506: Done:=True;
    507: Done:=True;
    Else If (E.X>=X2-18) And (E.X<=X2-3) And (E.Y>=Y1+3) And (E.Y<=Y1+18) Then Done:=True;
   End;
   If Not Done Then Begin HideMouse; Draw; ShowMouse; End;
  End Else If (E.Kind=evKey) And (E.Key=kEsc) Then Done:=True;
 Until Done;
 Refresh;
End;

Procedure FormatDlg;
Const CatN: Array[0..3] Of String[10] = ('Vid'#233'o','Audio','Appareil','Image');
Var X1,Y1,X2,Y2,Cat,Sel,I,N,Top: Integer; Done,Ok: Boolean; E: TEvent; Id: Integer; Idxs: Array[1..MaxProf] Of Integer;
 Procedure Collect;
 Var K: Integer;
 Begin
  N:=0;
  For K:=1 To NProf Do If Profs[K].Cat=Cat Then Begin Inc(N); Idxs[N]:=K; End;
 End;
 Procedure Draw;
 Var K,Row,Col,X,Y: Integer; P: TProf; Fg: Byte;
 Begin
  HotClear; Collect;
  DlgFrame(X1,Y1,X2,Y2,'Format de sortie');
  Rect(X1+1,Y1+20,X2-1,Y2-1,cWhite);
  For K:=0 To 3 Do Begin
   If K=Cat Then Begin Rect(X1+1,Y1+22+K*36,X1+110,Y1+56+K*36,cSky); Rect(X1+1,Y1+22+K*36,X1+4,Y1+56+K*36,cBlue); End;
   Txt(X1+16,Y1+35+K*36,CatN[K],Ord(K=Cat)*cBlue+Ord(K<>Cat)*cBlack);
   HotAdd(X1+1,Y1+22+K*36,110,34,600+K);
  End;
  VLn(X1+112,Y1+20,Y2-60,cSteel);
  For K:=Top To N Do Begin
   Row:=(K-Top) Div 2; Col:=(K-Top) Mod 2;
   If Row>=10 Then Break;
   X:=X1+122+Col*206; Y:=Y1+28+Row*24;
   P:=Profs[Idxs[K]];
   If Idxs[K]=Sel Then Panel(X,Y,X+200,Y+21,cSky,cBlue) Else Panel(X,Y,X+200,Y+21,cWhite,cLine);
   Txt(X+6,Y+7,Fit(P.Name,136),cBlack);
   Panel(X+152,Y+4,X+194,Y+17,cBlue,cBlue); TxtC(X+152,X+194,Y+6,P.Ext,cWhite);
   HotAdd(X,Y,201,22,1000+Idxs[K]);
  End;
  If N>20 Then Begin
   Button(X2-34,Y1+28,24,20,'^',610,bsNormal); Button(X2-34,Y1+232,24,20,'v',611,bsNormal);
  End;
  { detail }
  HLn(X1+114,X2-1,Y2-62,cSteel);
  P:=Profs[Sel];
  Txt(X1+122,Y2-58,Fit('Profil : '+P.Name+' ('+P.Ext+')',X2-X1-130),cNavy);
  Txt(X1+122,Y2-46,Fit('Vid'#233'o : '+P.VC+' '+P.Res+' '+IStr(P.VKb)+' kbps',X2-X1-130),cGrayD);
  Txt(X1+122,Y2-34,Fit('Audio : '+P.AC+' '+IStr(P.AKb)+' kbps '+IStr(P.Rate)+' Hz',X2-X1-300),cGrayD);
  If EngineOut(P.Ext) Then Txt(X1+122,Y2-22,#251+' Pris en charge par le moteur int'#233'gr'#233,cGreen)
  Else Txt(X1+122,Y2-22,Fit('! Pas d''encodeur pour ce conteneur (MP4 : oui)',X2-X1-300),cOrange);
  Button(X1+8,Y2-34,100,24,'Personnaliser',612,bsNormal);
  Button(X2-190,Y2-34,84,24,'OK',613,bsPrimary); Button(X2-98,Y2-34,84,24,'Annuler',614,bsNormal);
 End;
Begin
 X1:=50; Y1:=40; X2:=ScrW-50; Y2:=ScrH-30; Sel:=CurProf; Cat:=Profs[Sel].Cat; Top:=1; Done:=False; Ok:=False;
 HideMouse; Draw; ShowMouse;
 Repeat
  WaitEvent(E);
  If E.Kind=evUp Then Begin
   Id:=HotAt(E.X,E.Y);
   If (Id>=600) And (Id<=603) Then Begin Cat:=Id-600; Top:=1; End
   Else If Id>=1000 Then Begin
    If DblClick And (Id-1000=Sel) Then Begin Ok:=True; Done:=True; End;
    Sel:=Id-1000;
   End Else Case Id Of
    610: If Top>1 Then Dec(Top,2);
    611: If Top+20<=N Then Inc(Top,2);
    612: Begin CurProf:=Sel; CustomDlg; End;
    613: Begin Ok:=True; Done:=True; End;
    614: Done:=True;
    Else If (E.X>=X2-18) And (E.X<=X2-3) And (E.Y>=Y1+3) And (E.Y<=Y1+18) Then Done:=True;
   End;
   If Not Done Then Begin HideMouse; Draw; ShowMouse; End;
  End Else If (E.Kind=evKey) And (E.Key=kEsc) Then Done:=True;
 Until Done;
 If Ok Then CurProf:=Sel;
 Refresh;
End;

{ ---------------------------------------------------------------------- }
{ Preferences, A propos, Enregistrement                                       }
{ ---------------------------------------------------------------------- }
Procedure PrefDlg;
Var X1,Y1,X2,Y2: Integer; Done: Boolean; E: TEvent; Id,I: Integer; S: String;
 Procedure Draw;
 Var T: String;
 Begin
  HotClear;
  DlgFrame(X1,Y1,X2,Y2,'Pr'#233'f'#233'rences');
  Rect(X1+1,Y1+20,X2-1,Y2-1,cWhite);
  Txt(X1+20,Y1+40,'Dossier de sortie :',cBlack); Combo(X1+20,Y1+54,360,20,OutDir,700);
  Button(X1+386,Y1+54,70,20,'Parcourir',701,bsNormal);
  Txt(X1+20,Y1+90,'Dossier temporaire :',cBlack); Combo(X1+20,Y1+104,360,20,TmpDir,702);
  Txt(X1+20,Y1+140,'Apr'#232's la conversion :',cBlack);
  Case AfterAct Of 1: T:='Afficher le dossier de sortie'; 2: T:='Quitter l''application'; Else T:='Ne rien faire'; End;
  Combo(X1+170,Y1+136,220,20,T,703);
  CheckBox(X1+20,Y1+172,#201'craser les fichiers existants',OverwriteAll,704);
  CheckBox(X1+20,Y1+194,'Acc'#233'l'#233'ration mat'#233'rielle (indicatif)',HwAccel,705);
  CheckBox(X1+20,Y1+216,'Conversion rapide (indicatif)',Fast120,706);
  Txt(X1+20,Y1+248,'Langue : Fran'#231'ais',cGrayD);
  Button(X2-190,Y2-34,84,24,'OK',707,bsPrimary); Button(X2-98,Y2-34,84,24,'Annuler',708,bsNormal);
 End;
Begin
 X1:=80; Y1:=60; X2:=ScrW-80; Y2:=ScrH-60; Done:=False;
 HideMouse; Draw; ShowMouse;
 Repeat
  WaitEvent(E);
  If E.Kind=evUp Then Begin
   Id:=HotAt(E.X,E.Y);
   Case Id Of
    700: Begin S:=OutDir; If InputBox('Dossier de sortie','Chemin :',S,200) Then OutDir:=S; End;
    701: If FileDlg('Choisir le dossier de sortie',False,True,0) Then OutDir:=PickList[1];
    702: Begin S:=TmpDir; If InputBox('Dossier temporaire','Chemin :',S,200) Then TmpDir:=AddSlash(S); End;
    703: Begin I:=PopupMenu(E.X-100,E.Y+4,'Ne rien faire|Afficher le dossier de sortie|Quitter l''application',AfterAct+1,230); If I>0 Then AfterAct:=I-1; End;
    704: OverwriteAll:=Not OverwriteAll;
    705: HwAccel:=Not HwAccel;
    706: Fast120:=Not Fast120;
    707,708: Done:=True;
    Else If (E.X>=X2-18) And (E.X<=X2-3) And (E.Y>=Y1+3) And (E.Y<=Y1+18) Then Done:=True;
   End;
   If Not Done Then Begin HideMouse; Draw; ShowMouse; End;
  End Else If (E.Kind=evKey) And (E.Key=kEsc) Then Done:=True;
 Until Done;
 Refresh;
End;

Procedure AboutDlg;
Var R: Integer;
Begin
 R:=MsgBox(#192+' propos de AnyMP4','AnyMP4 Convertisseur Vid'#233'o Ultimate (clone Pascal) 1.00|'+
  'Sylvain Maltais - https://www.gladir.com/ffmpeg-0|'+
  'Video : decodeur H.264 (CAVLC/CABAC, I/P/B) et encodeur H.264 + muxeur MP4 (FFMPEG.PAS).|'+
  'Moteurs int'#233'gr'#233's (FFMPEG.PAS) : MP3, AAC-LC (decodeur et encodeur), AIFF, VOC, MOD.|'+
  'Extraction audio : AVI, FLV, MP4/MOV/M4A ; FLAC natif. Images : BMP, GIF anim'#233' (LZW).|'+
  'Aucune d'#233'pendance externe : tout est dans ANYMP4.PAS.','OK');
End;

Procedure RegDlg;
Var S: String; R: Integer;
Begin
 S:='';
 If InputBox('Enregistrer','Entrez votre code d''enregistrement :',S,40) Then Begin
  If S='' Then Exit;
  R:=MsgBox('Enregistrement','Code non valide : cette version de d'#233'monstration n''a pas de serveur de licences.','OK');
 End;
End;

{ ====================================================================== }
{ Boite de progression, ajout de fichiers                                    }
{ ====================================================================== }
Var
 ProgTitle: String;
 ProgText: String;

Procedure DrawProgBox;
Var X1,Y1,X2,Y2,Pct: Integer; Save: Integer;
Begin
 Pct:=0;
 If (JobIdx>=1) And (JobIdx<=MaxFiles+1) And (Files[JobIdx]<>Nil) Then Pct:=Files[JobIdx]^.Pct;
 X1:=170; Y1:=190; X2:=ScrW-170; Y2:=290;
 HideMouse;
 Shadow(X1,Y1,X2,Y2);
 Panel(X1,Y1,X2,Y2,cPanel,cNavy);
 Rect(X1+1,Y1+1,X2-1,Y1+19,cBlue); Txt(X1+8,Y1+7,ProgTitle,cWhite);
 Txt(X1+16,Y1+32,Fit(ProgText,X2-X1-32),cBlack);
 ProgBar(X1+16,Y1+50,X2-X1-32,14,Pct);
 TxtC(X1,X2,Y1+53,IStr(Pct)+' %',cNavy);
 Button(X2-96,Y2-28,80,20,'Annuler',0,bsNormal);
 CancelX1:=X2-96; CancelY1:=Y2-28; CancelX2:=X2-16; CancelY2:=Y2-8;
 ShowMouse;
End;

Procedure ProgBegin(Const Title,Text: String; Idx: Integer);
Begin
 ProgTitle:=Title; ProgText:=Text; ProgMode:=True; Running:=True; Stopped:=False;
 JobIdx:=Idx; If Files[Idx]<>Nil Then Files[Idx]^.Pct:=0;
 StageLo:=0; StageHi:=100; LastDraw:=0;
 DrawProgBox;
End;

Procedure ProgEnd;
Begin
 ProgMode:=False; Running:=False; JobIdx:=0; Refresh;
End;

Procedure NewSlot(Idx: Integer);
Begin
 If Files[Idx]=Nil Then New(Files[Idx]);
End;

Function AddOne(Const Path: String): Boolean;
Var M: PMedia;
Begin
 AddOne:=False;
 If NFiles>=MaxFiles Then Begin Info('Nombre maximal de fichiers atteint ('+IStr(MaxFiles)+').'); Exit; End;
 NewSlot(NFiles+1);
 Analyze(Files[NFiles+1]^,Path);
 If Files[NFiles+1]^.Kind=0 Then Begin
  Info('Format de fichier non reconnu :|'+NameOf(Path)); Exit;
 End;
 Inc(NFiles); AddOne:=True;
End;

Procedure AddFilesDlg;
Var I: Integer; Ok: Boolean;
Begin
 If FileDlg('Ajouter des fichiers',True,False,0) Then Begin
  For I:=1 To PickN Do Ok:=AddOne(PickList[I]);
 End;
 SubTab:=0; Dirty:=True;
End;

Procedure AddFolderDlg;
Var SR: SearchRec; Dir: String; Cnt: Integer; Ok: Boolean;
Begin
 If Not FileDlg('Ajouter un dossier',False,True,0) Then Begin Dirty:=True; Exit; End;
 Dir:=AddSlash(PickList[1]); Cnt:=0;
 FindFirst(Dir+'*',AnyFile,SR);
 While (DosError=0) And (NFiles<MaxFiles) Do Begin
  If ((SR.Attr And Directory)=0) And (MediaKind(ExtOf(SR.Name))<>0) Then Begin
   Ok:=AddOne(Dir+SR.Name); Inc(Cnt);
  End;
  FindNext(SR);
 End;
 If Cnt=0 Then Info('Aucun fichier m'#233'dia dans ce dossier.');
 SubTab:=0; Dirty:=True;
End;

Procedure RemoveFile(I: Integer);
Var K: Integer; P: PMedia;
Begin
 If (I<1) Or (I>NFiles) Then Exit;
 P:=Files[I];
 For K:=I To NFiles-1 Do Files[K]:=Files[K+1];
 Files[NFiles]:=P; Dec(NFiles);
 If ListTop>=NFiles Then ListTop:=Max(0,NFiles-1);
End;

Procedure ShowInfo(Var M: TMedia);
Var S: String;
Begin
 S:='Format : '+M.Fmt+'   Taille : '+SizeStr(M.Size)+'|Dur'#233'e : '+TimeStrMs(M.DurMs);
 If M.W>0 Then S:=S+'|Vid'#233'o : '+M.VCodec+'  '+IStr(M.W)+'x'+IStr(M.H);
 If M.FpsX100>0 Then S:=S+'  '+IStr(M.FpsX100 Div 100)+'.'+Pad2(M.FpsX100 Mod 100)+' i/s';
 If M.ACodec<>'' Then S:=S+'|Audio : '+M.ACodec+'  '+IStr(M.Rate)+' Hz  '+IStr(M.Chans)+' canal(aux)  '+IStr(M.KBps)+' kbps';
 If M.Frames>1 Then S:=S+'|Images : '+IStr(M.Frames);
 If M.Title<>'' Then S:=S+'|Titre : '+M.Title;
 S:=S+'|Chemin : '+M.Path;
 MsgBox('Informations',S,'OK');
End;

{ ====================================================================== }
{ Ripper (DVD)                                                               }
{ ====================================================================== }
Type
 TRipTitle = Record
  Num: Integer; Vobs: Integer; Size: LongInt; Sel: Boolean;
  Names: Array[1..9] Of String[12];
 End;
Var
 RipDir: String;
 RipT: Array[1..20] Of TRipTitle;
 RipN: Integer;

Procedure RipScan(Const Dir: String);
Var SR: SearchRec; D,Nm: String; Num,Part,I,K: Integer; T: Integer;
Begin
 RipN:=0; D:=AddSlash(Dir);
 If DirExists(D+'VIDEO_TS') Then D:=D+'VIDEO_TS'+Copy(D,Length(D),1);
 If Not DirExists(D) Then Exit;
 RipDir:=AddSlash(D);
 For Num:=1 To 99 Do Begin
  T:=0;
  For Part:=1 To 9 Do Begin
   Nm:='VTS_'+Pad2(Num)+'_'+IStr(Part)+'.VOB';
   FindFirst(RipDir+Nm,AnyFile,SR);
   If DosError<>0 Then Begin
    { systemes sensibles a la casse }
    Nm:='vts_'+Pad2(Num)+'_'+IStr(Part)+'.vob';
    FindFirst(RipDir+Nm,AnyFile,SR);
   End;
   If DosError=0 Then Begin
    If T=0 Then Begin
     If RipN>=20 Then Exit;
     Inc(RipN); T:=RipN; RipT[T].Num:=Num; RipT[T].Vobs:=0; RipT[T].Size:=0; RipT[T].Sel:=False;
    End;
    Inc(RipT[T].Vobs); RipT[T].Names[RipT[T].Vobs]:=Nm; Inc(RipT[T].Size,SR.Size);
   End;
  End;
  If (T>0) And (RipT[T].Size<100000) Then Begin Dec(RipN); End;
 End;
 For I:=1 To RipN Do RipT[I].Sel:=True;
End;

Procedure DrawRipper;
Var I,Y: Integer;
Begin
 Rect(0,96,ScrW-1,399,cWhite);
 If RipN=0 Then Begin
  IcoDisc(304,120,cBlue); SetColor(cBlue); Circle(320,136,40); Circle(320,136,12); Circle(320,136,38);
  TxtC(0,ScrW-1,200,'Charger un DVD',cBlack);
  TxtC(0,ScrW-1,222,'Cliquez sur "Charger DVD" puis choisissez le dossier du disque',cGrayD);
  TxtC(0,ScrW-1,234,'(le dossier contenant VIDEO_TS ou VIDEO_TS lui-m'#234'me).',cGrayD);
  TxtC(0,ScrW-1,260,'Les titres sont copi'#233's sans r'#233'encodage (flux MPEG-2 PS).',cGrayD);
  HotAdd(100,110,440,200,hAdd);
 End Else Begin
  Txt(14,102,'Disque : '+Fit(RipDir,520),cNavy);
  For I:=1 To Min(RipN,10) Do Begin
   Y:=118+(I-1)*27;
   Panel(8,Y,ScrW-10,Y+24,cWhite,cLine);
   CheckBox(16,Y+6,'',RipT[I].Sel,1200+I);
   Txt(44,Y+8,'Titre '+IStr(RipT[I].Num),cBlack);
   Txt(130,Y+8,'VTS_'+Pad2(RipT[I].Num)+'  '+IStr(RipT[I].Vobs)+' fichier(s) VOB',cGrayD);
   TxtR(430,Y+8,SizeStr(RipT[I].Size),cBlack);
   TxtR(540,Y+8,'~'+TimeStr((RipT[I].Size Div 560)),cGrayD);
  End;
 End;
End;

Procedure RipRun;
Var I,J,Done: Integer; FO,FI: File; Dst,Err,Base: String; Old: Byte; Tot,Cur,Sz: LongInt; Ok: Boolean;
Begin
 Done:=0;
 If RipN=0 Then Begin Info('Chargez d''abord un DVD.'); Exit; End;
 If Not InList(Profs[CurProf].Ext,'MPG,VOB') Then Begin
  I:=MsgBox('Ripper','Seule la copie MPEG-2 (profils "MPEG-2 PS" ou "DVD") est disponible : le d'#233'codeur AC3/MPEG-2 n''est pas inclus.|Utiliser le profil "MPEG-2 PS" ?','Oui|Non');
  If I<>1 Then Exit;
  For J:=1 To NProf Do If Profs[J].Ext='MPG' Then Begin CurProf:=J; Break; End;
 End;
 Base:=NameOf(Copy(RipDir,1,Length(RipDir)-1));
 If UpStr(Base)='VIDEO_TS' Then Base:='DVD' Else Base:=Base;
 NewSlot(MaxFiles+1);
 For I:=1 To RipN Do If RipT[I].Sel Then Begin
  Dst:=UniqueOut(OutDir,Base+'_Titre'+IStr(RipT[I].Num),'MPG');
  FillChar(Files[MaxFiles+1]^,SizeOf(TMedia),0);
  ProgBegin('Ripper','Titre '+IStr(RipT[I].Num)+' -> '+NameOf(Dst),MaxFiles+1);
  Err:=''; Ok:=CreateOut(Dst,FO,Err); Tot:=RipT[I].Size; Cur:=0;
  If Ok Then Begin
   For J:=1 To RipT[I].Vobs Do If Not Stopped Then Begin
    Assign(FI,RipDir+RipT[I].Names[J]); Old:=FileMode; FileMode:=0;
    {$I-}Reset(FI,1);{$I+}
    FileMode:=Old;
    If IOResult=0 Then Begin
     Sz:=FileSize(FI);
     While (Cur<Tot) And Not Stopped And (FilePos(FI)<Sz) Do Begin
      CopyRange(FI,FO,FilePos(FI),Min(2097152,Sz-FilePos(FI)),False);
      Cur:=Cur+Min(2097152,Sz);
      UiTick(Min(Cur,Tot),Tot);
     End;
     Close(FI);
    End;
   End;
   Close(FO);
   If Stopped Then DelFile(Dst) Else Begin AddConverted(Dst); Inc(Done); End;
  End;
  ProgEnd;
  If Stopped Then Break;
 End;
 If Done>0 Then Info(IStr(Done)+' titre(s) copi'#233'(s) dans :|'+OutDir)
 Else If Not Stopped Then Info('Aucun titre s'#233'lectionn'#233'.');
End;

{ ====================================================================== }
{ MV : diaporama                                                             }
{ ====================================================================== }
Const
 NThemes = 10;
 ThemeNames: Array[1..NThemes] Of String[12] = ('Simple','Heureux','Romantique','Mode','Voyage','Affaires','Mariage','R'#233'tro','Sport','F'#234'tes');
 ThemeBg: Array[1..NThemes,0..5] Of Byte = (
  (255,255,255,30,60,130),(255,214,90,120,40,0),(250,190,200,150,20,60),(20,20,20,255,255,255),(60,150,220,255,255,255),
  (30,60,110,255,255,255),(250,245,235,150,110,60),(110,90,60,255,235,190),(20,110,50,255,255,255),(170,30,40,255,235,120));

Var
 MvTheme: Integer;
 MvImgs: TPathList;
 MvN: Integer;
 MvDur: LongInt;
 MvFade: Integer;
 MvTitle,MvEnd,MvMusic: String;

Procedure DrawMV;
Var I,X,Y: Integer; Im: PImg;
Begin
 Rect(0,96,ScrW-1,399,cWhite);
 Txt(10,102,'Th'#232'me',cNavy);
 For I:=1 To NThemes Do Begin
  Y:=116+(I-1)*27;
  If I=MvTheme Then Panel(8,Y,130,Y+24,cSky,cBlue) Else Panel(8,Y,130,Y+24,cWhite,cLine);
  Rect(12,Y+4,30,Y+20,cBlack);
  Rect(13,Y+5,29,Y+19,NearPal(ThemeBg[I,0],ThemeBg[I,1],ThemeBg[I,2]));
  Txt(38,Y+8,ThemeNames[I],cBlack);
  HotAdd(8,Y,123,25,1300+I);
 End;
 Txt(146,102,'M'#233'dias ('+IStr(MvN)+'/12)',cNavy);
 For I:=0 To 11 Do Begin
  X:=146+(I Mod 6)*80; Y:=116+(I Div 6)*62;
  If I<MvN Then Begin
   Panel(X,Y,X+73,Y+54,cNavy,cSteel);
   Im:=GetThumb(MvImgs[I]);
   If Im<>Nil Then DrawImg(Im,X+1,Y+1,72,53) Else Txt(X+4,Y+22,'?',cWhite);
   Txt(X+3,Y+3,IStr(I+1),cGold);
  End Else Begin
   Panel(X,Y,X+73,Y+54,cPanel,cSteel);
   If I=MvN Then IcoPlus(X+37,Y+27,10,cBlue);
  End;
  HotAdd(X,Y,74,55,1320+I);
 End;
 Txt(146,246,'Dur'#233'e par image :',cBlack); Combo(290,242,70,18,IStr(MvDur)+' s',1340);
 Txt(372,246,'Transition :',cBlack); If MvFade>0 Then Combo(472,242,90,18,'Fondu',1341) Else Combo(472,242,90,18,'Aucune',1341);
 Txt(146,272,'Titre :',cBlack); Combo(208,268,190,18,MvTitle,1342);
 Txt(410,272,'Fin :',cBlack); Combo(456,268,160,18,MvEnd,1343);
 Txt(146,298,'Musique :',cBlack); Combo(224,294,290,18,NameOf(MvMusic),1344);
 Button(520,294,96,18,'Ajouter',1344,bsNormal);
 Button(146,330,120,26,'Aper'#231'u',1345,bsBlue);
 Button(276,330,140,26,'Exporter (GIF)',1346,bsPrimary);
 Para(146,366,470,'L''export cr'#233'e un GIF anim'#233' ; la musique est enregistr'#233'e '#224' c'#244't'#233' (MP3).',cGrayD);
End;

Function MvBuild(Var A: PAnim; Var Err: String): Boolean;
Begin
 MvBuild:=False;
 If MvN=0 Then Begin Err:='Ajoutez des images (BMP ou GIF).'; Exit; End;
 MvBuild:=BuildShow(MvImgs,MvN,320,180,Integer(MvDur*100),MvFade,ThemeBg[MvTheme,0],ThemeBg[MvTheme,1],ThemeBg[MvTheme,2],
  ThemeBg[MvTheme,3],ThemeBg[MvTheme,4],ThemeBg[MvTheme,5],MvTitle,MvEnd,A,Err);
End;

Procedure MvPreview;
Var A: PAnim; Err: String; K: Integer; T0: LongInt; E: TEvent; Stop: Boolean;
Begin
 If Not MvBuild(A,Err) Then Begin Info(Err); Exit; End;
 HideMouse;
 Rect(150,100,490,300,cNavy); Frame(150,100,490,300,cWhite);
 Txt(156,288,'Aper'#231'u - cliquez ou Echap pour fermer',cGrayD);
 ShowMouse;
 Stop:=False; K:=1;
 Repeat
  HideMouse; DrawImg(A^.F[K],155,104,330,170); ShowMouse;
  T0:=Ticks;
  Repeat
   If PollEvent(E) Then Begin If (E.Kind=evUp) Or (E.Kind=evKey) Then Stop:=True; End;
   Delay(10);
  Until Stop Or (Ticks-T0>=A^.Dly[K]) Or (Ticks<T0);
  Inc(K); If K>A^.N Then K:=1;
 Until Stop;
 AnimFree(A); Dirty:=True;
End;

Procedure MvExport;
Var A: PAnim; Err,Dst,Aud: String; Ok: Boolean; M: PMedia; SP: TAP; Pr: TProf; Tot: LongInt; I: Integer;
Begin
 If Not MvBuild(A,Err) Then Begin Info(Err); Exit; End;
 Dst:=UniqueOut(OutDir,'MV_'+ThemeNames[MvTheme],'GIF');
 NewSlot(MaxFiles+1); FillChar(Files[MaxFiles+1]^,SizeOf(TMedia),0);
 ProgBegin('Exporter MV','Cr'#233'ation du GIF '+NameOf(Dst),MaxFiles+1);
 Ok:=SaveGif(Dst,A,True);
 Tot:=0; For I:=1 To A^.N Do Inc(Tot,A^.Dly[I]*10);
 AnimFree(A);
 Aud:='';
 If Ok And (MvMusic<>'') And Not Stopped Then Begin
  Files[MaxFiles+1]^.Pct:=0; Analyze(Files[MaxFiles+1]^,MvMusic);
  If Files[MaxFiles+1]^.Kind In [1,2] Then Begin
   Pr:=Profs[18]; FillChar(SP,SizeOf(SP),0); SP.Vol:=100; SP.Speed:=100;
   Files[MaxFiles+1]^.TrimE:=Tot;
   Aud:=UniqueOut(OutDir,'MV_'+ThemeNames[MvTheme],'MP3'); ProgText:='Musique : '+NameOf(Aud);
   Ok:=DoConvert(Files[MaxFiles+1]^,Pr,Aud,SP,Err);
   If Not Ok Then Begin Info('GIF cr'#233#233' mais la musique a '#233'chou'#233' :|'+Err); Aud:=''; Ok:=True; End;
  End;
 End;
 ProgEnd;
 If Ok Then Begin AddConverted(Dst); Info('MV export'#233' :|'+Dst+Copy('|'+Aud,1,Ord(Aud<>'')*(Length(Aud)+1))); End
 Else Info('Export impossible.');
End;

Procedure MvClick(Id: Integer);
Var I,K: Integer;
Begin
 If (Id>=1301) And (Id<=1300+NThemes) Then MvTheme:=Id-1300
 Else If (Id>=1320) And (Id<=1331) Then Begin
  I:=Id-1320;
  If I<MvN Then Begin
   K:=PopupMenu(ScrW Div 2-60,200,'Supprimer|D'#233'placer '#224' gauche|D'#233'placer '#224' droite',0,140);
   If K=1 Then Begin For K:=I To MvN-2 Do MvImgs[K]:=MvImgs[K+1]; Dec(MvN); End
   Else If (K=2) And (I>0) Then Begin MvImgs[15]:=MvImgs[I]; MvImgs[I]:=MvImgs[I-1]; MvImgs[I-1]:=MvImgs[15]; End
   Else If (K=3) And (I<MvN-1) Then Begin MvImgs[15]:=MvImgs[I]; MvImgs[I]:=MvImgs[I+1]; MvImgs[I+1]:=MvImgs[15]; End;
  End Else If FileDlg('Ajouter des images (BMP, GIF)',True,False,3) Then Begin
   For K:=1 To PickN Do If MvN<12 Then Begin MvImgs[MvN]:=PickList[K]; Inc(MvN); End;
  End;
 End Else Case Id Of
  1340: Begin K:=PopupMenu(300,262,'1 s|2 s|3 s|5 s|8 s|10 s',0,70); If K>0 Then Begin Case K Of 1: MvDur:=1; 2: MvDur:=2; 3: MvDur:=3; 4: MvDur:=5; 5: MvDur:=8; Else MvDur:=10 End; End; End;
  1341: Begin K:=PopupMenu(436,262,'Aucune|Fondu',0,90); If K=1 Then MvFade:=0 Else If K=2 Then MvFade:=3; End;
  1342: InputBox('Titre','Texte du titre (premi'#232're image) :',MvTitle,30);
  1343: InputBox('Fin','Texte de fin :',MvEnd,30);
  1344: If FileDlg('Choisir la musique',False,False,2) Then MvMusic:=PickList[1];
  1345: MvPreview;
  1346: MvExport;
 End;
 Dirty:=True;
End;

{ ====================================================================== }
{ Collage                                                                     }
{ ====================================================================== }
Const
 ColRatios: Array[1..4] Of String[6] = ('16:9','4:3','1:1','9:16');
 ColW: Array[1..4] Of Integer = (1280,1024,900,540);
 ColH: Array[1..4] Of Integer = (720,768,900,960);
 ColBorderRGB: Array[1..8,0..2] Of Byte = ((255,255,255),(0,0,0),(20,60,130),(255,126,20),(40,160,70),(250,200,50),(120,126,138),(220,50,50));

Var
 ColLay,ColRatio,ColBorder,ColCol: Integer;
 ColPaths: TPathList;
 ColThumb: Array[0..8] Of PImg;

Procedure ColLoadThumb(K: Integer);
Var Im,T: PImg;
Begin
 ImgFree(ColThumb[K]);
 If ColPaths[K]='' Then Exit;
 Im:=LoadFirst(ColPaths[K]);
 If Im=Nil Then Exit;
 ColThumb[K]:=Im;
End;

Procedure DrawCollage;
Var I,N,X,Y,Pw,Ph,Ox,Oy,Cx,Cy,Cw,Ch,K: Integer; C: TLayout; L: TLayout; Nn: Integer;
Begin
 Rect(0,96,ScrW-1,399,cWhite);
 Txt(10,102,'Mod'#232'les',cNavy);
 For I:=1 To NLayouts Do Begin
  X:=10+((I-1) Mod 3)*50; Y:=116+((I-1) Div 3)*52;
  If I=ColLay Then Panel(X-2,Y-2,X+45,Y+37,cSky,cBlue) Else Panel(X-2,Y-2,X+45,Y+37,cWhite,cLine);
  GetLayout(I,Nn,L);
  For K:=1 To Nn Do Rect(X+(L[K].X*44) Div 100+1,Y+(L[K].Y*34) Div 100+1,X+((L[K].X+L[K].W)*44) Div 100-1,Y+((L[K].Y+L[K].H)*34) Div 100-1,cBlueL);
  HotAdd(X-2,Y-2,48,40,1400+I);
 End;
 Pw:=300; Ph:=(Pw*ColH[ColRatio]) Div ColW[ColRatio];
 If Ph>250 Then Begin Ph:=250; Pw:=(Ph*ColW[ColRatio]) Div ColH[ColRatio]; End;
 Ox:=170+(300-Pw) Div 2; Oy:=108+(250-Ph) Div 2;
 Rect(Ox,Oy,Ox+Pw-1,Oy+Ph-1,NearPal(ColBorderRGB[ColCol,0],ColBorderRGB[ColCol,1],ColBorderRGB[ColCol,2]));
 Frame(Ox,Oy,Ox+Pw-1,Oy+Ph-1,cSteel);
 GetLayout(ColLay,N,C);
 For K:=1 To N Do Begin
  Cx:=Ox+(C[K].X*Pw) Div 100+ColBorder Div 3; Cy:=Oy+(C[K].Y*Ph) Div 100+ColBorder Div 3;
  Cw:=(C[K].W*Pw) Div 100-2*(ColBorder Div 3); Ch:=(C[K].H*Ph) Div 100-2*(ColBorder Div 3);
  Rect(Cx,Cy,Cx+Cw-1,Cy+Ch-1,cPanel);
  If ColThumb[K-1]<>Nil Then DrawImg(ColThumb[K-1],Cx,Cy,Cw,Ch)
  Else Begin IcoPlus(Cx+Cw Div 2,Cy+Ch Div 2,8,cBlue); End;
  HotAdd(Cx,Cy,Cw,Ch,1420+K-1);
 End;
 Txt(490,108,'Ratio :',cBlack); Combo(550,104,76,18,ColRatios[ColRatio],1440);
 Txt(490,140,'Bordure :',cBlack); Txt(606,140,IStr(ColBorder),cBlue);
 SliderBar(490,158,134,ColBorder,0,30,1441);
 Txt(490,184,'Couleur :',cBlack);
 For I:=1 To 8 Do Begin
  X:=490+((I-1) Mod 4)*34; Y:=200+((I-1) Div 4)*28;
  Rect(X+2,Y+2,X+26,Y+22,NearPal(ColBorderRGB[I,0],ColBorderRGB[I,1],ColBorderRGB[I,2]));
  If I=ColCol Then Begin Frame(X,Y,X+28,Y+24,cBlue); Frame(X+1,Y+1,X+27,Y+23,cBlue); End Else Frame(X+1,Y+1,X+27,Y+23,cSteel);
  HotAdd(X,Y,28,24,1450+I);
 End;
 Button(490,272,136,26,'Exporter ...',1442,bsPrimary);
 Button(490,304,136,24,'Tout effacer',1443,bsNormal);
 Para(170,366,300,'Cliquez sur une cellule pour choisir une image (BMP, GIF).',cGrayD);
End;

Procedure ColExport;
Var Im: PImg; Err,Dst,Ext: String; K,Fm: Integer; A: PAnim; Ok: Boolean;
Begin
 K:=PopupMenu(420,270,'Image BMP|Image GIF',0,120);
 If K=0 Then Exit;
 NewSlot(MaxFiles+1); FillChar(Files[MaxFiles+1]^,SizeOf(TMedia),0);
 ProgBegin('Collage','Rendu de l''image...',MaxFiles+1);
 Im:=RenderCollage(ColLay,ColPaths,ColW[ColRatio],ColH[ColRatio],ColBorder,ColBorderRGB[ColCol,0],ColBorderRGB[ColCol,1],ColBorderRGB[ColCol,2],Err);
 Ok:=False;
 If Im<>Nil Then Begin
  If K=1 Then Begin Dst:=UniqueOut(OutDir,'Collage','BMP'); Ok:=SaveBmp(Dst,Im); End
  Else Begin
   New(A); A^.N:=1; A^.F[1]:=Im; A^.Dly[1]:=100; Im:=Nil;
   Dst:=UniqueOut(OutDir,'Collage','GIF'); Ok:=SaveGif(Dst,A,False); AnimFree(A);
  End;
  ImgFree(Im);
 End;
 ProgEnd;
 If Ok Then Begin AddConverted(Dst); Info('Collage enregistr'#233' :|'+Dst); End Else Info('Export impossible. '+Err);
End;

Procedure ColClick(Id: Integer);
Var K: Integer;
Begin
 If (Id>=1401) And (Id<=1400+NLayouts) Then ColLay:=Id-1400
 Else If (Id>=1420) And (Id<=1428) Then Begin
  K:=Id-1420;
  If FileDlg('Choisir une image (BMP, GIF)',False,False,3) Then Begin ColPaths[K]:=PickList[1]; ColLoadThumb(K); End;
 End Else If (Id>=1451) And (Id<=1458) Then ColCol:=Id-1450
 Else Case Id Of
  1440: Begin K:=PopupMenu(60,346,'16:9|4:3|1:1|9:16',ColRatio,70); If K>0 Then ColRatio:=K; End;
  1442: ColExport;
  1443: Begin For K:=0 To 8 Do Begin ColPaths[K]:=''; ImgFree(ColThumb[K]); End; End;
 End;
 Dirty:=True;
End;

{ ====================================================================== }
{ Boite a outils                                                              }
{ ====================================================================== }
Const
 NTools = 16;
 ToolNames: Array[1..NTools] Of String[16] = ('Compresseur','M'#233'tadonn'#233'es','Cr'#233'ateur GIF','Cr'#233'ateur 3D','Am'#233'lioration','Rogneur',
  'Fusion','Vitesse','Inverseur','Rotateur','Volume','Synchro audio','Couleurs','Recadrage','Filigrane','Extr. audio');
 ToolDesc: Array[1..NTools] Of String[30] = (
  'R'#233'duire la|taille',
  #201'tiquettes|MP3 (ID3)',
  'Images vers|GIF anim'#233,
  'Image 3D|anaglyphe',
  'Auto-niveaux|image / GIF',
  'Couper une|plage',
  'Fusionner|des audio',
  'Acc'#233'l'#233'rer ou|ralentir',
  'Lire '#224'|l''envers',
  'Rotation et|miroir',
  'Amplifier|le son',
  'D'#233'caler|l''audio',
  'Luminosit'#233',|teinte...',
  'Rogner image|ou GIF',
  'Effacer une|zone',
  'Audio d''une|vid'#233'o');

Procedure DrawToolbox;
Var I,X,Y,P: Integer; D1,D2: String;
Begin
 Rect(0,96,ScrW-1,399,cWhite);
 For I:=1 To NTools Do Begin
  X:=10+((I-1) Mod 4)*155; Y:=104+((I-1) Div 4)*74;
  Panel(X,Y,X+148,Y+68,cWhite,cLine);
  Rect(X+6,Y+8,X+32,Y+34,cSky);
  Case I Mod 4 Of
   1: Begin Disc(X+19,Y+21,8,cBlue); Rect(X+15,Y+19,X+23,Y+23,cWhite); End;
   2: Begin Rect(X+11,Y+13,X+27,Y+29,cBlue); Rect(X+13,Y+17,X+25,Y+18,cWhite); Rect(X+13,Y+22,X+25,Y+23,cWhite); End;
   3: Begin Tri(X+19,Y+21,2,cOrange); SetColor(cBlue); Circle(X+19,Y+21,9); End;
   Else Begin SetColor(cBlue); Line(X+11,Y+29,X+19,Y+13); Line(X+19,Y+13,X+27,Y+29); Line(X+11,Y+29,X+27,Y+29); End;
  End;
  Txt(X+38,Y+10,ToolNames[I],cNavy);
  P:=Pos('|',ToolDesc[I]); D1:=Copy(ToolDesc[I],1,P-1); D2:=Copy(ToolDesc[I],P+1,40);
  Txt(X+38,Y+26,D1,cGrayD); Txt(X+38,Y+38,D2,cGrayD);
  HotAdd(X,Y,149,69,1500+I);
 End;
 Para(12,384,616,'Ces outils fonctionnent sur les fichiers audio (MP3, WAV, AIFF, AAC...) et les images (BMP, GIF).',cGrayD);
End;

Function ToolPickProf(Audio: Boolean; Var M: TMedia): TProf;
Var P: TProf;
Begin
 If Audio Then Begin
  If Profs[CurProf].Cat=1 Then P:=Profs[CurProf] Else P:=Profs[18];
 End Else Begin
  If Profs[CurProf].Cat=3 Then P:=Profs[CurProf]
  Else If M.Fmt='GIF' Then P:=Profs[NProf-1] Else P:=Profs[NProf];
  If P.Ext='BMP' Then Begin End;
 End;
 ToolPickProf:=P;
End;

{ ID3v1 : lecture/ecriture }
Procedure MetaTool(Var M: TMedia);
Var F: File; B: Array[0..127] Of Byte; Old: Byte; Got: Word; I,K: Integer; Has: Boolean; Fld: Array[1..5] Of String[30]; Nm: Array[1..5] Of String[10];
 S: String; Ok: Boolean;
Begin
 Nm[1]:='Titre'; Nm[2]:='Artiste'; Nm[3]:='Album'; Nm[4]:='Ann'#233'e'; Nm[5]:='Commentaire';
 If M.Fmt<>'MP3' Then Begin ShowInfo(M); Exit; End;
 Assign(F,M.Path); Old:=FileMode; FileMode:=2;
 {$I-}Reset(F,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Begin Info('Fichier en lecture seule.'); Exit; End;
 FillChar(B,SizeOf(B),0); Has:=False;
 If FileSize(F)>128 Then Begin
  Seek(F,FileSize(F)-128); BlockRead(F,B,128,Got);
  Has:=(B[0]=84) And (B[1]=65) And (B[2]=71);
 End;
 If Not Has Then FillChar(B,SizeOf(B),0);
 For K:=1 To 5 Do Begin
  Fld[K]:='';
  Case K Of 1: I:=3; 2: I:=33; 3: I:=63; 4: I:=93; Else I:=97 End;
  Case K Of 4: S:=Copy(Chr(B[93])+Chr(B[94])+Chr(B[95])+Chr(B[96]),1,4); Else Begin S:=''; End End;
  Fld[K]:='';
  Case K Of 4: Begin For Got:=0 To 3 Do If B[93+Got]>31 Then Fld[K]:=Fld[K]+Chr(B[93+Got]); End;
   Else Begin For Got:=0 To 29 Do If B[I+Got]>31 Then Fld[K]:=Fld[K]+Chr(B[I+Got]); End End;
 End;
 For K:=1 To 5 Do Begin
  S:=Fld[K];
  If InputBox('M'#233'tadonn'#233'es - '+NameOf(M.Path),Nm[K]+' :',S,30) Then Fld[K]:=S Else Begin Close(F); Exit; End;
 End;
 FillChar(B,SizeOf(B),0); B[0]:=84; B[1]:=65; B[2]:=71; B[127]:=255;
 For K:=1 To 5 Do Begin
  Case K Of 1: I:=3; 2: I:=33; 3: I:=63; 4: I:=93; Else I:=97 End;
  For Got:=1 To Min(Length(Fld[K]),Ord(K=4)*4+Ord(K<>4)*30) Do B[I+Got-1]:=Ord(Fld[K][Got]);
 End;
 If Has Then Seek(F,FileSize(F)-128) Else Seek(F,FileSize(F));
 BlockWrite(F,B,128); Close(F);
 Info('Les '#233'tiquettes ID3v1 ont '#233't'#233' enregistr'#233'es dans le fichier.');
End;

{ Operations image : Kind 1 auto-niveaux, 2 anaglyphe 3D, 3 inverser (GIF), 4 vitesse (GIF), 5 effacer une zone }
Function ImageOp(Var M: TMedia; Op: Integer; Arg1,Arg2,Arg3,Arg4: LongInt; Const Dst: String; Var Err: String): Boolean;
Var A: PAnim; K,X,Y,N,Lo,Hi,C: LongInt; Hist: Array[0..255] Of LongInt; T: PImg; Cnt,Acc: LongInt; Tmp: PImg; Ok: Boolean; P: PImg;
 R,G,B,L: Byte; Dx,Half: LongInt; Rr,Gg,Bb: LongInt; Pr: TProf;
Begin
 ImageOp:=False;
 If Not LoadAnim(M.Path,A,MaxAnim) Then Begin Err:='Seuls les BMP et GIF sont pris en charge.'; Exit; End;
 For K:=1 To A^.N Do Begin
  P:=A^.F[K]; N:=P^.W*P^.H;
  Case Op Of
   1: Begin
    For C:=0 To 2 Do Begin
     FillChar(Hist,SizeOf(Hist),0);
     For X:=0 To N-1 Do Inc(Hist[P^.P^[X*3+C]]);
     Lo:=0; Acc:=0; While (Lo<254) And (Acc+Hist[Lo]<N Div 100) Do Begin Inc(Acc,Hist[Lo]); Inc(Lo); End;
     Hi:=255; Acc:=0; While (Hi>Lo+2) And (Acc+Hist[Hi]<N Div 100) Do Begin Inc(Acc,Hist[Hi]); Dec(Hi); End;
     For X:=0 To N-1 Do P^.P^[X*3+C]:=Clip(((P^.P^[X*3+C]-Lo)*255) Div Max(Hi-Lo,1),0,255);
    End;
    ImgAdjust(P,0,0,10,0);
   End;
   2: Begin
    Half:=P^.W Div 2; T:=ImgNew(Half,P^.H);
    If T<>Nil Then Begin
     For Y:=0 To P^.H-1 Do For X:=0 To Half-1 Do Begin
      Dx:=(Y*P^.W+X)*3; Rr:=(Y*P^.W+X+Half)*3;
      T^.P^[(Y*Half+X)*3]:=P^.P^[Dx];
      T^.P^[(Y*Half+X)*3+1]:=P^.P^[Rr+1]; T^.P^[(Y*Half+X)*3+2]:=P^.P^[Rr+2];
     End;
     ImgFree(A^.F[K]); A^.F[K]:=T;
    End;
   End;
   5: Begin
    For Y:=Arg2 To Arg2+Arg4-1 Do If (Y>=0) And (Y<P^.H) Then Begin
     For C:=0 To 2 Do Begin
      If Arg1>0 Then Lo:=P^.P^[(Y*P^.W+Arg1-1)*3+C] Else Lo:=P^.P^[(Y*P^.W+Min(Arg1+Arg3,P^.W-1))*3+C];
      If Arg1+Arg3<P^.W Then Hi:=P^.P^[(Y*P^.W+Arg1+Arg3)*3+C] Else Hi:=Lo;
      For X:=Arg1 To Arg1+Arg3-1 Do If (X>=0) And (X<P^.W) Then
       P^.P^[(Y*P^.W+X)*3+C]:=Lo+((Hi-Lo)*(X-Arg1)) Div Max(Arg3,1);
     End;
    End;
   End;
  End;
  UiTick(K,A^.N);
 End;
 If Op=3 Then Begin
  For K:=1 To A^.N Div 2 Do Begin
   T:=A^.F[K]; A^.F[K]:=A^.F[A^.N+1-K]; A^.F[A^.N+1-K]:=T;
   N:=A^.Dly[K]; A^.Dly[K]:=A^.Dly[A^.N+1-K]; A^.Dly[A^.N+1-K]:=N;
  End;
 End;
 If Op=4 Then For K:=1 To A^.N Do A^.Dly[K]:=Max(2,Round(A^.Dly[K]*100.0/Max(Arg1,10)));
 If ExtOf(Dst)='GIF' Then Ok:=SaveGif(Dst,A,True) Else Ok:=SaveBmp(Dst,A^.F[1]);
 If Not Ok Then Err:='Ecriture impossible.';
 AnimFree(A);
 ImageOp:=Ok;
End;

Procedure ToolGo(T: Integer);
Var M: PMedia; Pr: TProf; Dst,Err,Ext,Base: String; Ok,Audio: Boolean; SP: TAP; K,I: Integer; V,V2,V3,V4: LongInt; Sv: Array[1..MaxFiles] Of PMedia; SvN: Integer; A: PAnim; Lst: TPathList; Fr: PAnim; Im: PImg;
 Kd: Integer;
Begin
 Audio:=T In [11,12,16];
 If T In [8,9,1,6,7] Then Audio:=False;
 NewSlot(MaxFiles+1); M:=Files[MaxFiles+1];
 { fichiers d'entree }
 If T=3 Then Begin
  If Not FileDlg('Images pour le GIF (BMP, GIF)',True,False,3) Then Begin Dirty:=True; Exit; End;
  V:=320; I:=PopupMenu(ScrW Div 2-40,200,'320 x 180|480 x 270|640 x 360',0,110);
  If I=0 Then Exit; If I=2 Then V:=480; If I=3 Then V:=640;
  V2:=500; If Not InputNum('Cr'#233'ateur de GIF','D'#233'lai entre les images (ms) :',V2,20,10000) Then Exit;
  For K:=0 To 15 Do Lst[K]:='';
  For K:=1 To Min(PickN,16) Do Lst[K-1]:=PickList[K];
  FillChar(M^,SizeOf(TMedia),0);
  ProgBegin('Cr'#233'ateur de GIF','Assemblage...',MaxFiles+1);
  Err:='';
  If BuildShow(Lst,Min(PickN,16),V,(V*9) Div 16,Integer(V2 Div 10),0,0,0,0,255,255,255,'','',A,Err) Then Begin
   Dst:=UniqueOut(OutDir,'Anim','GIF'); Ok:=SaveGif(Dst,A,True); AnimFree(A);
  End Else Ok:=False;
  ProgEnd;
  If Ok Then Begin AddConverted(Dst); Info('GIF cr'#233#233' :|'+Dst); End Else Info('Echec : '+Err);
  Exit;
 End;
 If T=7 Then Begin
  { fusion : audio (ou GIF) }
  If Not FileDlg('Fichiers '#224' fusionner (audio)',True,False,2) Then Begin Dirty:=True; Exit; End;
  If PickN<2 Then Begin Info('Choisissez au moins deux fichiers.'); Exit; End;
  SvN:=NFiles; For K:=1 To NFiles Do Sv[K]:=Files[K];
  NFiles:=0;
  For K:=1 To PickN Do Begin New(Files[K]); Analyze(Files[K]^,PickList[K]); Inc(NFiles); End;
  Pr:=ToolPickProf(True,Files[1]^); Err:='';
  ProgBegin('Fusion','Fusion des fichiers audio...',1);
  Ok:=MergeAudio(Pr,Dst,Err);
  ProgEnd;
  For K:=1 To NFiles Do Dispose(Files[K]);
  NFiles:=SvN; For K:=1 To NFiles Do Files[K]:=Sv[K];
  If Ok Then Begin AddConverted(Dst); Info('Fusion termin'#233'e :|'+Dst); End Else Info('Echec : '+Err);
  Exit;
 End;
 Case T Of
  6,8,9,11,12,16,1,2: Kd:=2;
  Else Kd:=3;
 End;
 If Not FileDlg('Choisir un fichier',False,False,0) Then Begin Dirty:=True; Exit; End;
 Analyze(M^,PickList[1]); M^.Pct:=0; Dirty:=True;
 If M^.Kind=0 Then Begin Info('Format non reconnu.'); Exit; End;
 FillChar(SP,SizeOf(SP),0); SP.Vol:=100; SP.Speed:=100; Err:=''; Ok:=False;
 Case T Of
  2: Begin MetaTool(M^); Exit; End;
  1: Begin { compresseur }
   If M^.Kind=3 Then Begin Info('Choisissez un fichier audio ou un GIF.'); Exit; End;
   If InList(M^.Fmt,'GIF') Then Begin
    If Not LoadAnim(M^.Path,A,MaxAnim) Then Begin Info('GIF illisible.'); Exit; End;
    ProgBegin('Compresseur','R'#233'duction du GIF...',MaxFiles+1);
    For K:=1 To A^.N Do Begin Im:=ImgScale(A^.F[K],Max(2,A^.F[K]^.W Div 2),Max(2,A^.F[K]^.H Div 2)); If Im<>Nil Then Begin ImgFree(A^.F[K]); A^.F[K]:=Im; End; End;
    Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_compress'+#233,'GIF'); Ok:=SaveGif(Dst,A,True); AnimFree(A); ProgEnd;
   End Else Begin
    I:=PopupMenu(ScrW Div 2-60,200,'MP3 64 kbps|MP3 96 kbps|MP3 128 kbps|MP3 192 kbps',3,130);
    If I=0 Then Exit;
    Pr:=Profs[17]; Case I Of 1: Pr.AKb:=64; 2: Pr.AKb:=96; 3: Pr.AKb:=128; Else Pr.AKb:=192 End;
    If I=1 Then Pr.Rate:=32000;
    Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_compress'+#233,'MP3');
    ProgBegin('Compresseur','Encodage MP3...',MaxFiles+1); Ok:=DoConvert(M^,Pr,Dst,SP,Err); ProgEnd;
   End;
  End;
  4: Begin Pr:=ToolPickProf(False,M^); Pr.Ext:='BMP'; Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_3D','BMP');
   ProgBegin('Cr'#233'ateur 3D','Anaglyphe...',MaxFiles+1); Ok:=ImageOp(M^,2,0,0,0,0,Dst,Err); ProgEnd; End;
  5: Begin Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_am'+#233+'lior'+#233,LowExt(M^.Fmt));
   If Not InList(UpStr(ExtOf(Dst)),'GIF,BMP') Then Begin Info('Images BMP et GIF seulement.'); Exit; End;
   ProgBegin('Am'#233'lioration','Auto-niveaux...',MaxFiles+1); Ok:=ImageOp(M^,1,0,0,0,0,Dst,Err); ProgEnd; End;
  6: Begin
   If M^.Kind=3 Then Begin Info('Choisissez un audio ou un GIF anim'#233'.'); Exit; End;
   NewSlot(MaxFiles+1); CutDlg(MaxFiles+1);
   If InList(M^.Fmt,'GIF') Then Pr:=Profs[NProf-1] Else Pr:=ToolPickProf(True,M^);
   Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_rogn'+#233,Pr.Ext);
   ProgBegin('Rogneur','D'#233'coupe...',MaxFiles+1); Ok:=DoConvert(M^,Pr,Dst,SP,Err); ProgEnd;
  End;
  8: Begin
   V:=100; If Not InputNum('Vitesse','Vitesse en % (25 = 4x plus lent, 400 = 4x plus rapide) :',V,25,400) Then Exit;
   If InList(M^.Fmt,'GIF') Then Begin
    Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_vitesse','GIF');
    ProgBegin('Vitesse','GIF...',MaxFiles+1); Ok:=ImageOp(M^,4,V,0,0,0,Dst,Err); ProgEnd;
   End Else Begin
    SP.Speed:=V; Pr:=ToolPickProf(True,M^); Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_vitesse',Pr.Ext);
    ProgBegin('Vitesse','Audio...',MaxFiles+1); Ok:=DoConvert(M^,Pr,Dst,SP,Err); ProgEnd;
   End;
  End;
  9: Begin
   If InList(M^.Fmt,'GIF') Then Begin
    Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_inverse','GIF');
    ProgBegin('Inverseur','GIF...',MaxFiles+1); Ok:=ImageOp(M^,3,0,0,0,0,Dst,Err); ProgEnd;
   End Else Begin
    SP.Rev:=True; Pr:=ToolPickProf(True,M^); Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_inverse',Pr.Ext);
    ProgBegin('Inverseur','Audio...',MaxFiles+1); Ok:=DoConvert(M^,Pr,Dst,SP,Err); ProgEnd;
   End;
  End;
  10,13,14: Begin
   If (M^.Kind<>3) And (Not InList(M^.Fmt,'GIF')) Then Begin Info('Choisissez une image BMP ou un GIF.'); Exit; End;
   NewSlot(MaxFiles+1); Files[MaxFiles+1]^:=M^;
   If T=13 Then EditDlg(MaxFiles+1,1) Else EditDlg(MaxFiles+1,0);
   M:=Files[MaxFiles+1];
   Pr:=ToolPickProf(False,M^); Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_modif',Pr.Ext);
   ProgBegin('Image','Traitement...',MaxFiles+1); Ok:=DoConvert(M^,Pr,Dst,SP,Err); ProgEnd;
  End;
  11,12: Begin
   If M^.Kind=3 Then Begin Info('Choisissez un fichier audio.'); Exit; End;
   NewSlot(MaxFiles+1); Files[MaxFiles+1]^:=M^;
   If T=11 Then M^.Vol:=150;
   EditDlg(MaxFiles+1,3); M:=Files[MaxFiles+1];
   Pr:=ToolPickProf(True,M^); Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_modif',Pr.Ext);
   ProgBegin('Audio','Traitement...',MaxFiles+1); Ok:=DoConvert(M^,Pr,Dst,SP,Err); ProgEnd;
  End;
  15: Begin
   If (M^.Kind<>3) And (Not InList(M^.Fmt,'GIF')) Then Begin Info('Choisissez une image BMP ou un GIF.'); Exit; End;
   V:=0; V2:=0; V3:=Max(2,M^.W Div 4); V4:=Max(2,M^.H Div 8);
   If Not InputNum('Zone ('+IStr(M^.W)+'x'+IStr(M^.H)+')','X (gauche) :',V,0,M^.W-1) Then Exit;
   If Not InputNum('Zone','Y (haut) :',V2,0,M^.H-1) Then Exit;
   If Not InputNum('Zone','Largeur :',V3,2,M^.W-V) Then Exit;
   If Not InputNum('Zone','Hauteur :',V4,2,M^.H-V2) Then Exit;
   Dst:=UniqueOut(OutDir,BaseOf(M^.Path)+'_sans_filigrane',LowExt(M^.Fmt));
   ProgBegin('Filigrane','Effacement...',MaxFiles+1); Ok:=ImageOp(M^,5,V,V2,V3,V4,Dst,Err); ProgEnd;
  End;
  16: Begin
   Pr:=Profs[18]; If Profs[CurProf].Cat=1 Then Pr:=Profs[CurProf];
   Dst:=UniqueOut(OutDir,BaseOf(M^.Path),Pr.Ext);
   ProgBegin('Extraire l''audio','Extraction...',MaxFiles+1); Ok:=DoConvert(M^,Pr,Dst,SP,Err); ProgEnd;
  End;
 End;
 If Ok Then Begin AddConverted(Dst); Info('Termin'#233' :|'+Dst); End
 Else Begin DelFile(Dst); If Err='' Then Err:='Op'#233'ration impossible.'; Info('Echec : '+Err); End;
End;

{ ====================================================================== }
{ Dispatch des commandes, menus et boucle principale                       }
{ ====================================================================== }
Procedure DrawFooterLite;
Begin
 Rect(0,400,ScrW-1,ScrH-1,cPanel); HLn(0,ScrW-1,400,cSteel);
 Txt(12,413,'Enregistrer:',cBlack);
 Combo(100,408,420,22,OutDir,hDir);
 Panel(526,408,548,429,cWhite,cSteel); IcoFolder(530,412,cGold); HotAdd(526,408,23,22,hDirBtn);
 Txt(12,445,'Les fichiers cr'#233#233's sont ajout'#233's '#224' l''onglet Convertisseur > Converti.',cGrayD);
End;

Procedure DrawAll;
Begin
 HotClear;
 HideMouse;
 DrawMenuBar(0);
 DrawTabs;
 DrawToolbar;
 Case Tab Of
  0: DrawConvertScreen;
  1: DrawRipper;
  2: DrawMV;
  3: DrawCollage;
  4: DrawToolbox;
 End;
 If Tab<=1 Then DrawFooter Else DrawFooterLite;
 ShowMouse;
End;

Procedure ChooseFormat;
Begin
 FormatDlg;
End;

Procedure ChooseDir;
Begin
 If FileDlg('Dossier de sortie',False,True,0) Then OutDir:=PickList[1];
 Dirty:=True;
End;

Procedure RowAction(I,K: Integer);
Var R: Integer; S: String;
Begin
 If (I<1) Or (I>NFiles) Then Exit;
 Case K Of
  0: EditDlg(I,0);
  1: Begin
   If Files[I]^.Kind=3 Then Info('Cette image n''a pas de dur'#233'e '#224' couper.') Else CutDlg(I);
  End;
  2: EditDlg(I,1);
  3: FormatDlg;
  4: RemoveFile(I);
  5: Begin
   R:=PopupMenu(330,LastClickY+4,'Piste audio 1 (auto)|D'#233'sactiver l''audio',1,150);
   If R=2 Then Files[I]^.Vol:=0 Else If R=1 Then Files[I]^.Vol:=100;
  End;
  6: Begin
   R:=PopupMenu(430,LastClickY+4,'Aucun sous-titre|Ajouter un sous-titre...',1,160);
   If R=1 Then Files[I]^.SubFile:=''
   Else If R=2 Then If FileDlg('Ajouter un sous-titre',False,False,4) Then Files[I]^.SubFile:=PickList[1];
  End;
  7: ShowInfo(Files[I]^);
 End;
 Dirty:=True;
End;

Procedure MenuAction(Mn,It: Integer);
Var I: Integer;
Begin
 Case Mn Of
  1: Case It Of
   1: Begin Tab:=0; AddFilesDlg; End;
   2: Begin Tab:=0; AddFolderDlg; End;
   3: Begin For I:=1 To NFiles Do ; NFiles:=0; ListTop:=0; Dirty:=True; End;
   4: Quit:=True;
  End;
  2: Case It Of
   1: Begin For I:=1 To NFiles Do Files[I]^.Sel:=True; Info(IStr(NFiles)+' fichier(s) s'#233'lectionn'#233'(s).'); End;
   2: Begin NFiles:=0; ListTop:=0; Dirty:=True; End;
   3: PrefDlg;
  End;
  3: Case It Of
   1..5: Begin Tab:=It-1; Dirty:=True; End;
   6: Begin Tab:=0; SubTab:=1; Dirty:=True; End;
  End;
  4: Case It Of
   1: FormatDlg;
   2: ChooseDir;
   3: Begin Tab:=0; ConvertAll; End;
   4: Begin
    If NFiles>=1 Then ShowInfo(Files[1]^) Else Info('Aucun fichier.');
   End;
  End;
  5: Case It Of
   1: Info('Ajoutez des fichiers, choisissez un format de sortie puis cliquez sur Convertir Tout.|F1 .. F5 : onglets. Echap : annule une conversion.');
   2: RegDlg;
   3: AboutDlg;
  End;
 End;
End;

Procedure OpenMenu(Mn: Integer);
Var It,Cur: Integer; Items: String;
Begin
 Cur:=Mn;
 Repeat
  DrawMenuBar(Cur);
  Case Cur Of
   1: Items:='Ajouter fichier(s)...^Ctrl+O|Ajouter un dossier...|Effacer la liste|-|Quitter^Alt+X';
   2: Items:=#201'diter la s'#233'lection|Supprimer les fichiers|-|Pr'#233'f'#233'rences...';
   3: Items:='Convertisseur^F1|Ripper^F2|MV^F3|Collage^F4|Bo'#238'te '#224' outils^F5|-|Fichiers convertis';
   4: Items:='Format de sortie...|Dossier de sortie...|Convertir tout^F9|Informations du fichier...';
   Else Items:='Aide^F10|Enregistrer...|'#192' propos...';
  End;
  If Cur=2 Then Items:='S'#233'lectionner tout|Supprimer les fichiers|-|Pr'#233'f'#233'rences...';
  PopMenuBarH:=18; PopSwitch:=0; PopCurMenu:=Cur;
  It:=PopupMenu(MenuX[Cur]-4,18,Items,0,150);
  If (PopSwitch>0) And (PopSwitch<>Cur) Then Begin Cur:=PopSwitch; End
  Else Begin
   HotClear;
   If It>0 Then Begin
    { corrige la numerotation apres separateur }
    Case Cur Of
     1: If It=5 Then It:=4 Else If It=3 Then It:=3;
     2: If It=4 Then It:=3;
     3: If It=7 Then It:=6;
    End;
    DrawMenuBar(0);
    MenuAction(Cur,It);
   End;
   DrawMenuBar(0);
   Cur:=0;
  End;
 Until Cur=0;
 PopMenuBarH:=0;
 Dirty:=True;
End;

Procedure ColSlide;
Var HX,HY,HW,HH,Mx,My,V,Last: Integer; Bt: LongInt;
Begin
 If Not GetHot(1441,HX,HY,HW,HH) Then Exit;
 Last:=-1;
 Repeat
  ReadMouse(Mx,My,Bt);
  V:=SliderVal(HX,HW,Mx,0,30);
  If V<>Last Then Begin Last:=V; ColBorder:=V; HideMouse; DrawCollage; ShowMouse; End;
  Delay(8);
 Until (Bt And 1)=0;
 Dirty:=True;
End;

Procedure Click(Id,X,Y: Integer);
Var I,K: Integer; R: Integer;
Begin
 If (Id>=hMenu+1) And (Id<=hMenu+5) Then Begin OpenMenu(Id-hMenu); Exit; End;
 If Id=hMenu+9 Then Begin RegDlg; Dirty:=True; Exit; End;
 If (Id>=hTab) And (Id<=hTab+4) Then Begin Tab:=Id-hTab; Dirty:=True; Exit; End;
 Case Tab Of
  2: If (Id>=1300) And (Id<1400) Then Begin MvClick(Id); Exit; End;
  3: If (Id>=1400) And (Id<1500) Then Begin ColClick(Id); Exit; End;
  4: If (Id>=1501) And (Id<=1500+NTools) Then Begin ToolGo(Id-1500); Exit; End;
  1: If (Id>=1201) And (Id<=1220) Then Begin RipT[Id-1200].Sel:=Not RipT[Id-1200].Sel; Dirty:=True; Exit; End;
 End;
 Case Id Of
  hAdd,hAddArrow: Begin
   If Tab=1 Then Begin
    If FileDlg('Charger un dossier DVD',False,True,0) Then RipScan(PickList[1]);
    If RipN=0 Then Info('Aucun titre DVD (VTS_xx_x.VOB) trouv'#233' dans ce dossier.');
    Dirty:=True;
   End Else If Id=hAddArrow Then Begin
    K:=PopupMenu(6,94,'Ajouter Fichier(s)|Ajouter un dossier',0,150);
    If K=1 Then AddFilesDlg Else If K=2 Then AddFolderDlg;
   End Else AddFilesDlg;
  End;
  hSubConv: Begin SubTab:=0; Dirty:=True; End;
  hSubDone: Begin SubTab:=1; Dirty:=True; End;
  hHw: Begin
   HwAccel:=Not HwAccel;
   If HwAccel Then Info('Le moteur Pascal int'#233'gr'#233' fonctionne sur le processeur : aucune acc'#233'l'#233'ration GPU n''est disponible.');
   Dirty:=True;
  End;
  hFmt,hFmtGear: FormatDlg;
  hFast: Begin Fast120:=Not Fast120; Dirty:=True; End;
  hDir: Begin
   If InputBox('Enregistrer dans','Dossier de sortie :',OutDir,200) Then Begin End;
   Dirty:=True;
  End;
  hDirBtn: ChooseDir;
  hMerge: Begin MergeAll:=Not MergeAll; Dirty:=True; End;
  hConvAll: Begin
   If Tab=1 Then RipRun Else Begin Tab:=0; ConvertAll; End;
  End;
  hScrUp: Begin If ListTop>0 Then Dec(ListTop); Dirty:=True; End;
  hScrDn: Begin If ListTop+RowsVis<NFiles Then Inc(ListTop); Dirty:=True; End;
  Else If (Id>=110) And (Id<=360) And (Tab=0) Then Begin
   I:=(Id Div 10)-10; K:=Id Mod 10;
   If SubTab=1 Then Begin
    I:=NConv-I+1;
    If (I>=1) And (I<=NConv) Then Begin
     If K=7 Then Begin
      NewSlot(MaxFiles+1); Analyze(Files[MaxFiles+1]^,Converted[I]); ShowInfo(Files[MaxFiles+1]^);
     End Else If K=4 Then Begin
      R:=MsgBox('Supprimer','Supprimer ce fichier du disque ?|'+Converted[I],'Oui|Non');
      If R=1 Then Begin DelFile(Converted[I]); For K:=I To NConv-1 Do Converted[K]:=Converted[K+1]; Dec(NConv); End;
     End;
    End;
    Dirty:=True;
   End Else RowAction(I,K);
  End;
 End;
End;

Procedure HandleKey(K: Integer);
Begin
 Case K Of
  315..319: Begin Tab:=K-315; Dirty:=True; End;
  323: Begin Tab:=0; ConvertAll; End;
  15: AddFilesDlg;
  kPgUp: Begin If ListTop>0 Then Dec(ListTop); Dirty:=True; End;
  kPgDn: Begin If ListTop+RowsVis<NFiles Then Inc(ListTop); Dirty:=True; End;
  kEsc: ;
 End;
End;

Procedure InitApp;
Var I: Integer; S: String;
Begin
 InitializeGraphics;
 InitPalette;
 CaptureFont;
 If Not MouseDriverFound Then Begin
  CloseGraph; WriteLn('Pilote de souris requis.'); Halt;
 End;
 {$IFDEF FPC}
 PtcMouse.ShowMouse;
 {$ELSE}
 ShowMouse;
 {$ENDIF}
 InitProfiles; InitEngines;
 NFiles:=0; NConv:=0; Tab:=0; SubTab:=0; ListTop:=0; Quit:=False; Dirty:=True;
 For I:=1 To MaxFiles+1 Do Files[I]:=Nil;
 GetDir(0,S);
 OutDir:=AddSlash(S)+'Converted';
 S:=GetEnv('TEMP'); If S='' Then S:=GetEnv('TMP');
 {$IFDEF UNIX}
 If S='' Then S:='/tmp';
 {$ELSE}
 If S='' Then S:=OutDir;
 {$ENDIF}
 TmpDir:=AddSlash(S);
 MergeAll:=False; Fast120:=False; HwAccel:=False; AfterAct:=1; OverwriteAll:=False;
 CustRate:=0; CustCh:=0; CustFps:=30; Running:=False; ProgMode:=False; Stopped:=False;
 MvTheme:=1; MvN:=0; MvDur:=3; MvFade:=3; MvTitle:='Mon film'; MvEnd:='Fin'; MvMusic:='';
 ColLay:=1; ColRatio:=1; ColBorder:=6; ColCol:=1;
 For I:=0 To 15 Do Begin MvImgs[I]:=''; ColPaths[I]:=''; End;
 For I:=0 To 8 Do ColThumb[I]:=Nil;
 RipN:=0; MBtn0:=0; LastDir:=''; JobIdx:=0; LastDraw:=0;
 BarHitProc:=BarHit; PopMenuBarH:=0; RedrawHook:=DrawAll;
End;

Var
 Ev: TEvent;
 Id: Integer;
BEGIN
 InitApp;
 { fichiers passes sur la ligne de commande }
 If ParamCount>0 Then Begin
  For Id:=1 To ParamCount Do If FileExists(ParamStr(Id)) Then If AddOne(ParamStr(Id)) Then ;
 End;
 Repeat
  If Dirty Then Begin Dirty:=False; DrawAll; End;
  If PollEvent(Ev) Then Begin
   Case Ev.Kind Of
    evUp: Begin
     Id:=HotAt(Ev.X,Ev.Y);
     If Id<>0 Then Click(Id,Ev.X,Ev.Y);
    End;
    evKey: HandleKey(Ev.Key);
    evDown: Begin
     If (Tab=3) And (HotAt(Ev.X,Ev.Y)=1441) Then Begin
      ColSlide; 
     End;
    End;
   End;
  End Else Delay(8);
 Until Quit;
 CloseGraph;
END.
