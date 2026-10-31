{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/ffmpeg-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application ANYMP4 (Convertisseur Video Ultimate).
   Interface graphique complete, moteurs audio (MP3, WAV, AIFF, VOC, MOD,
   encodeur MP3) adaptes de FFMPEG.PAS, extraction audio AVI/FLV/MP4/MOV/M4A, FLAC natif,
   GIF anime, collage et diaporama. Aucune dependance externe.
   Les moteurs audio (MP3, AAC-LC, AIFF, VOC, MOD, encodeur MP3, primitives
   ADPCM) proviennent de FFMPEG.PAS et sont adaptes de FFmpeg (LGPL-2.1+). }

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
 EngineOut:=InList(Ext,'MP3,WAV,AIF,AU,GIF,BMP');
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

{ ====================================================================== }
{ Colle entre l'interface et les moteurs audio                             }
{ ====================================================================== }
Const
 ekMP3 = 1; ekAIFF = 2; ekVOC = 3; ekMOD = 4; ekEncMP3 = 5; ekAAC = 6;

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
  End;
  RunEng:=True;
 End Else Begin
  If Kind=ekAAC Then AacCleanup(True);
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
 ProgMode: Boolean;
 StageLo,StageHi: Integer;
 CancelX1,CancelY1,CancelX2,CancelY2: Integer;
 Running: Boolean;

Procedure DrawRowProgress; Forward;
Procedure DrawConvertScreen; Forward;
Procedure DrawFooter; Forward;
Procedure DrawProgBox; Forward;
Procedure DrawAll; Forward;

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
 DoConvert:=False; Err:='';
 Audio:=InList(Pr.Ext,'MP3,WAV,AIF,AU');
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
 End Else Begin
  If M.Kind=1 Then Err:='Un fichier audio ne peut pas devenir une vid'#233'o. Choisissez un profil Audio.'
  Else If M.Kind=3 Then Err:='Choisissez un profil Image (GIF/BMP) ou Audio pour ce fichier.'
  Else Err:='Le moteur int'#233'gr'#233' ne contient pas d''encodeur vid'#233'o '+Pr.VC+'. Utilisez un profil Audio (MP3, WAV, AIFF, AU) ou Image.';
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
 If MergeAll And InList(Pr.Ext,'MP3,WAV,AIF,AU') And (NFiles>1) Then Begin
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
   SetStatus(I,2,NameOf(Dst)); Files[I]^.OutFile:=Dst; Files[I]^.Pct:=100;
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
Var ThC: Array[0..15] Of TTh; ThN: Integer;

Function GetThumb(Const Path: String): PImg;
Var K: Integer; A: PAnim; T: PImg;
Begin
 GetThumb:=Nil;
 For K:=0 To 15 Do If (ThC[K].Img<>Nil) And (ThC[K].Path=Path) Then Begin GetThumb:=ThC[K].Img; Exit; End;
 If Not LoadAnim(Path,A,1) Then Exit;
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
 If (M.Kind=3) Or (M.Fmt='GIF') Then Im:=GetThumb(M.Path);
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
 If InList(Pr.Ext,'MP3,WAV,AIF,AU') Then Begin
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
 If (M.Kind=3) Or (M.Fmt='GIF') Then SourceImage:=LoadFirst(M.Path);
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
  Else Txt(X1+122,Y2-22,Fit('! Pas d''encodeur vid'#233'o : audio/image seulement',X2-X1-300),cOrange);
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
  'Moteurs int'#233'gr'#233's (FFMPEG.PAS) : MP3, AAC-LC, AIFF, VOC, MOD, encodeur MP3.|'+
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
