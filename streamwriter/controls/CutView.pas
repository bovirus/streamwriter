{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010 Alexander Nottelmann

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 3
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
    ------------------------------------------------------------------------
}
unit CutView;

interface

uses
  SysUtils, Windows, Classes, Controls, StdCtrls, ExtCtrls, Functions,
  Graphics, DynBASS, Forms, Math, Generics.Collections, GUIFunctions,
  LanguageObjects, WaveData, Messages, ComCtrls, AppData;

type
  TPeakEvent = procedure(P, AI, L, R: Integer) of object;

  TWavBufArray = array of SmallInt;

  TCutView = class;

  TScanThread = class(TThread)
  private
    FFilename: string;
    FWaveData: TWaveData;

    FOnScanProgress: TNotifyEvent;
    FOnEndScan: TNotifyEvent;
    FOnScanError: TNotifyEvent;

    procedure SyncScanProgress;
    procedure SyncEndScan;
    procedure SyncScanError;

    procedure WaveDataScanProgress(Sender: TObject);
  protected
    procedure Execute; override;
  public
    constructor Create(Filename: string);
    destructor Destroy; override;

    property OnScanProgress: TNotifyEvent read FOnScanProgress write FOnScanProgress;
    property OnEndScan: TNotifyEvent read FOnEndScan write FOnEndScan;
    property OnScanError: TNotifyEvent read FOnScanError write FOnScanError;
  end;

  TMouseMode = (mmDown, mmMove, mmUp);

  PMouseButton = ^TMouseButton;

  TCutPaintBox = class(TGraphicControl)
  const
    ScrollbarHeight = 8;
    MinimumDisplayedSampleCount = 30;
  private
    FBuf: TBitmap;
    FCutView: TCutView;
    FTimer: TTimer;
    FPlayingIndex: Cardinal;

    FPeakColor, FPeakEndColor, FStartColor, FEndColor, FPlayColor, FZoomOuterColor, FZoomInnerColor: TColor;
    FStartLine, FEndLine, FPlayLine, FZoomStartLine, FZoomEndLine: Cardinal;
    FDoZoom: Boolean;

    FMouseOldX, FMouseOldY, FMouseMoveStartX: integer;
    FScrollbarActive: boolean;

    procedure BuildBuffer;
    procedure SetLine(X: Integer; Button: TMouseButton; Mode: TMouseMode);
    function HandleScrollBar(X: Integer; Y: Integer; Button: PMouseButton;
      Mode: TMouseMode): Boolean;
    function PixelsToArray(X: Integer): Cardinal;
    function GetPlayerPos: Cardinal;

    procedure TimerTimer(Sender: TObject);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X: Integer;
      Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X: Integer; Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X: Integer;
      Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TLineMode = (lmEdit, lmPlay, lmZoom);

  TCutView = class(TPanel)
  private
    FScanThread: TScanThread;
    FPB: TCutPaintBox;
    FWaveData: TWaveData;
    FError: Boolean;
    FLineMode: TLineMode;
    FVolume: Integer;
    FProgressBarLoad: TProgressBar;

    FPlayer: Cardinal;
    FSync, FSync2: Cardinal;
    FFilename: string;

    FOnStateChanged: TNotifyEvent;

    procedure ThreadScanProgress(Sender: TObject);
    procedure ThreadEndScan(Sender: TObject);
    procedure ThreadScanError(Sender: TObject);
    procedure ThreadTerminate(Sender: TObject);

    procedure MsgRefresh(var Msg: TMessage); message WM_USER + 1234;

    procedure FSetVolume(Value: Integer);
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure LoadFile(Filename: string);

    procedure Cut;
    procedure Undo;
    function Save: Boolean;
    procedure SaveAs;
    procedure Play;
    procedure Stop;
    procedure AutoCut(MaxPeaks: Cardinal; MinDuration: Cardinal);

    function CanCut: Boolean;
    function CanUndo: Boolean;
    function CanSave: Boolean;
    function CanPlay: Boolean;
    function CanStop: Boolean;
    function CanAutoCut: Boolean;
    function CanSetLine: Boolean;
    function CanZoom: Boolean;

    property LineMode: TLineMode read FLineMode write FLineMode;
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
    property Volume: Integer read FVolume write FSetVolume;
  end;

  procedure LoopSyncProc(handle: HSYNC; channel, data: DWORD; user: Pointer); stdcall;

implementation

{ TScanThread }

constructor TScanThread.Create(Filename: string);
begin
  inherited Create(True);
  FFilename := Filename;
  FWaveData := TWaveData.Create;
  FWaveData.OnProgress := WaveDataScanProgress;
end;

destructor TScanThread.Destroy;
begin
  //FWaveData.Free;
  inherited;
end;

procedure TScanThread.Execute;
begin
  try
    FWaveData.Load(FFilename);
  except
    FWaveData.Free;
    Synchronize(SyncScanError);
    Exit;
  end;
  Synchronize(SyncEndScan);
end;

procedure TScanThread.SyncEndScan;
begin
  if Assigned(FOnEndScan) then
    FOnEndScan(Self);
end;

procedure TScanThread.SyncScanError;
begin
  if Assigned(FOnScanError) then
    FOnScanError(Self);
end;

procedure TScanThread.SyncScanProgress;
begin
  if Assigned(FOnScanProgress) then
    FOnScanProgress(Self);
end;

procedure TScanThread.WaveDataScanProgress(Sender: TObject);
begin
  Synchronize(SyncScanProgress);
end;

{ TCutView }

constructor TCutView.Create(AOwner: TComponent);
begin
  inherited;

  BevelOuter := bvNone;

  FPB := TCutPaintBox.Create(Self);
  FPB.Parent := Self;
  FPB.Align := alClient;

  FLineMode := lmPlay;

  FProgressBarLoad := TProgressBar.Create(Self);
  FProgressBarLoad.Parent := Self;
end;

destructor TCutView.Destroy;
begin
  if FScanThread <> nil then
  begin
    FScanThread.Terminate;
    while FScanThread <> nil do
    begin
      Application.ProcessMessages;
    end;
  end;

  FWaveData.Free;

  if FPlayer > 0 then
  begin
    // Das hier gibt gerne Exceptions. Aber nur, wenn ein CutView auf ist, und mann das Programm beendet.
    // Schie� mich tot... das hier hilft, keine Ahnung woher der Fehler kommt.
    try
      BASSStreamFree(FPlayer);
    except end;
    FPlayer := 0;
  end;

  inherited;
end;

procedure TCutView.FSetVolume(Value: Integer);
begin
  FVolume := Value;
  if FPlayer > 0 then
    BASSChannelSetAttribute(FPlayer, 2, Value / 100);
end;

procedure TCutView.LoadFile(Filename: string);
begin
  if FScanThread <> nil then
    Exit;

  FFilename := Filename;

  FScanThread := TScanThread.Create(Filename);
  FScanThread.FreeOnTerminate := True;
  FScanThread.OnTerminate := ThreadTerminate;
  FScanThread.OnEndScan := ThreadEndScan;
  FScanThread.OnScanError := ThreadScanError;
  FScanThread.OnScanProgress := ThreadScanProgress;

  FPB.BuildBuffer;
  FPB.Paint;

  BASSSetDevice(AppGlobals.SoundDevice + 1);

  if FPlayer > 0 then
    BASSStreamFree(FPlayer);
  FPlayer := BASSStreamCreateFile(False, PChar(FFilename), 0, 0, {$IFDEF UNICODE}BASS_UNICODE{$ENDIF});

  FScanThread.Resume;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TCutView.MsgRefresh(var Msg: TMessage);
begin
  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);

  FPB.BuildBuffer;
  FPB.Paint;
end;

procedure TCutView.Cut;
var
  P: QWORD;
begin
  if not CanCut then
    Exit;

  FWaveData.Cut(FPB.FStartLine, FPB.FEndLine);

  if FPlayer > 0 then
  begin
    P := BASSChannelGetPosition(FPlayer, BASS_POS_BYTE);
    if (FWaveData.WaveArray[FPB.FStartLine].Pos > P) or
       (FWaveData.WaveArray[FPB.FEndLine].Pos < P) then
    begin
      BASSChannelStop(FPlayer);
      FPB.FPlayLine := FWaveData.CutStart;
    end;

    if FSync > 0 then
    begin
      BASSChannelRemoveSync(FPlayer, FSync);
      BASSChannelRemoveSync(FPlayer, FSync2);
    end;
    FSync := BASSChannelSetSync(FPlayer, BASS_SYNC_POS, FWaveData.WaveArray[FWaveData.CutEnd].Pos, LoopSyncProc, Self);
    FSync2 := BASSChannelSetSync(FPlayer, BASS_SYNC_END, 0, LoopSyncProc, Self);
  end;

  FPB.FZoomStartLine := FPB.FStartLine;
  FPB.FZoomEndLine := FPB.FEndLine;
  FPB.FDoZoom := True;

  FPB.BuildBuffer;
  FPB.Paint;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TCutView.Undo;
begin
  if not CanUndo then
    Exit;

  FWaveData.CutStates[FWaveData.CutStates.Count - 1].Free;
  FWaveData.CutStates.Delete(FWaveData.CutStates.Count - 1);

  if FPlayer > 0 then
  begin
    if FSync > 0 then
    begin
      BASSChannelRemoveSync(FPlayer, FSync);
      BASSChannelRemoveSync(FPlayer, FSync2);
    end;
    FSync := BASSChannelSetSync(FPlayer, BASS_SYNC_POS, FWaveData.WaveArray[FWaveData.CutEnd].Pos, LoopSyncProc, Self);
    FSync2 := BASSChannelSetSync(FPlayer, BASS_SYNC_END, 0, LoopSyncProc, Self);
  end;

  FPB.FStartLine := FWaveData.CutStates[FWaveData.CutStates.Count - 1].CutStart;
  FPB.FEndLine := FWaveData.CutStates[FWaveData.CutStates.Count - 1].CutEnd;
  FPB.FPlayLine := FPB.FStartLine;

  FPB.FZoomStartLine := FPB.FStartLine;
  FPB.FZoomEndLine := FPB.FEndLine;
  FPB.FDoZoom := True;

  FPB.BuildBuffer;
  FPB.Paint;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

function TCutView.Save: Boolean;
begin
  Result := False;

  if not CanSave then
    Exit;

  if FPlayer > 0 then
  begin
    BASSStreamFree(FPlayer);
    FPlayer := 0;
  end;

  try
    if FWaveData.Save(FFilename) then
    begin
      FreeAndNil(FWaveData);
      LoadFile(FFilename);

      Result := True;
    end else
    begin
      MsgBox(Handle, _('The file could not be saved.'#13#10'Please make sure the file is not in use by another application.'), _('Info'), MB_ICONINFORMATION);
    end;
  finally
    // Wenn Result = True wird FPlayer in LoadFile() neu erstellt
    if not Result then
    begin
      FPlayer := BASSStreamCreateFile(False, PChar(FFilename), 0, 0, {$IFDEF UNICODE}BASS_UNICODE{$ENDIF});
    end;
  end;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TCutView.SaveAs;
begin
  raise Exception.Create('');
end;

procedure TCutView.Play;
begin
  if not CanPlay then
    Exit;

  FPB.FPlayingIndex := 0;

  if FPlayer = 0 then
  begin
    Exit;
  end;

  if FWaveData.TimeBetween(FPB.FPlayLine, FWaveData.CutEnd) <= 0.3 then
    FPB.FPlayLine := FWaveData.CutStart;

  BASSChannelSetPosition(FPlayer, FWaveData.WaveArray[FPB.FPlayLine].Pos, BASS_POS_BYTE);
  if FPlayer > 0 then
    BASSChannelSetAttribute(FPlayer, 2, FVolume / 100);
  BASSChannelPlay(FPlayer, False);
  if FSync > 0 then
  begin
    BASSChannelRemoveSync(FPlayer, FSync);
    BASSChannelRemoveSync(FPlayer, FSync2);
  end;
  FSync := BASSChannelSetSync(FPlayer, BASS_SYNC_POS, FWaveData.WaveArray[FWaveData.CutEnd].Pos, LoopSyncProc, Self);
  FSync2 := BASSChannelSetSync(FPlayer, BASS_SYNC_END, 0, LoopSyncProc, Self);

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TCutView.Resize;
begin
  inherited;

  FProgressBarLoad.Width := Min(350, ClientWidth - 50);
  FProgressBarLoad.Height := 24;
  FProgressBarLoad.Left := ClientWidth div 2 - FProgressBarLoad.Width div 2;
  FProgressBarLoad.Top := ClientHeight div 2 - FProgressBarLoad.Height div 2 + 20;
end;

procedure TCutView.Stop;
begin
  if not CanStop then
    Exit;

  if FPlayer > 0 then
  begin
    BASSChannelStop(FPlayer);
  end;
  FPB.BuildBuffer;
  FPB.Paint;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TCutView.AutoCut(MaxPeaks: Cardinal; MinDuration: Cardinal);
begin
  if FWaveData = nil then
    Exit;

  FWaveData.AutoCut(MaxPeaks, MinDuration);

  FPB.BuildBuffer;
  FPB.Repaint;
end;

function TCutView.CanCut: Boolean;
begin
  Result := (FWaveData <> nil) and (FPB.FEndLine - FPB.FStartLine > 0) and
    (FWaveData.TimeBetween(FPB.FStartLine, FPB.FEndLine) >= 0.5) and
    ((FWaveData.CutStart <> FPB.FStartLine) or (FWaveData.CutEnd <> FPB.FEndLine));
end;

function TCutView.CanUndo: Boolean;
begin
  Result := (FWaveData <> nil) and (FWaveData.CutStates.Count > 1);
end;

function TCutView.CanSave: Boolean;
begin
  Result := (FWaveData <> nil) and (FWaveData.CutStates.Count > 1);
end;

function TCutView.CanPlay: Boolean;
begin
  Result := (FPlayer > 0) and (FWaveData <> nil) and (FPB.FStartLine < FPB.FEndLine) and
    //(FWaveData.TimeBetween(FPB.FStartLine, FPB.FEndLine) >= 0.5) and

    //(FWaveData.TimeBetween(FPB.FPlayLine, FWaveData.CutEnd) >= 0.5) and

    (BASSChannelIsActive(FPlayer) <> BASS_ACTIVE_PLAYING);
end;

function TCutView.CanStop: Boolean;
begin
  Result := (FPlayer > 0) and (BASSChannelIsActive(FPlayer) = BASS_ACTIVE_PLAYING);
end;

function TCutView.CanAutoCut: Boolean;
begin
  Result := FWaveData <> nil;
end;

function TCutView.CanSetLine: Boolean;
begin
  Result := FWaveData <> nil;
end;

function TCutView.CanZoom: Boolean;
begin
  Result := FWaveData <> nil;
end;

procedure TCutView.ThreadEndScan(Sender: TObject);
begin
  if FWaveData <> nil then
    FWaveData.Free;
  FWaveData := FScanThread.FWaveData;

  FPB.FStartLine := 0;
  FPB.FEndLine := High(FWaveData.WaveArray);
  FPB.FPlayLine := 0;

  // Hier auch, damit BuildBuffer kein "Loading..." malt.
  FScanThread := nil;

  FPB.BuildBuffer;
  FPB.Repaint;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TCutView.ThreadScanError(Sender: TObject);
begin
  FError := True;

  FPB.BuildBuffer;
  FPB.Repaint;
end;

procedure TCutView.ThreadScanProgress(Sender: TObject);
begin
  FProgressBarLoad.Position := FScanThread.FWaveData.Progress;
end;

procedure TCutView.ThreadTerminate(Sender: TObject);
begin
  FProgressBarLoad.Visible := False;
  FScanThread := nil;
end;

procedure LoopSyncProc(handle: HSYNC; channel, data: DWORD; user: Pointer); stdcall;
var
  PV: TCutView;
begin
  PV := TCutView(user);
  BASSChannelStop(PV.FPlayer);

  PostMessage(PV.Handle, WM_USER + 1234, 0, 0);
end;

{ TCutPaintBox }

procedure TCutPaintBox.BuildBuffer;
  procedure DrawLine(ArrayIdx: Cardinal; Color: TColor);
  var
    L: Cardinal;
  begin
    L := Trunc(((ArrayIdx - FCutView.FWaveData.ZoomStart) / FCutView.FWaveData.ZoomSize) * FBuf.Width);

    FBuf.Canvas.Pen.Color := Color;
    FBuf.Canvas.MoveTo(L, 0);
    FBuf.Canvas.LineTo(L, FBuf.Height - ScrollbarHeight - 1);

    FBuf.Canvas.Brush.Color := clBlack;
  end;
  procedure DrawTransparentBox(StartIdx: Cardinal; EndIdx: Cardinal; LineColor: TColor; FillColor: TColor);
  var rectStart, rectEnd: Cardinal;
      originalMode: TPenMode;
  begin
    rectStart := Trunc(((StartIdx - FCutView.FWaveData.ZoomStart) / FCutView.FWaveData.ZoomSize) * FBuf.Width);
    rectEnd := Trunc(((EndIdx - FCutView.FWaveData.ZoomStart) / FCutView.FWaveData.ZoomSize) * FBuf.Width);
    with FBuf.Canvas do
    begin
      Pen.Color := LineColor;
      originalMode := Pen.Mode;
      Pen.Mode := TPenMode.pmNotXor;
      Brush.Color := FillColor;
      Rectangle(rectStart, 0, rectEnd, FBuf.Height - ScrollbarHeight - 1);
      Pen.Mode := originalMode;
    end;
  end;
  procedure DrawScrollBar(Color: TColor);
  var StartX, StartY, EndX: Integer;
      y: Cardinal;
  begin
    with FBuf.Canvas do
    begin
      //Draw Outline
      Pen.Color := Color;
      StartY := Height - 2 - ScrollbarHeight;
      MoveTo(1, StartY);
      LineTo(Width - 2, StartY);
      LineTo(Width - 2, Height - 2);
      LineTo(1, Height - 2);
      LineTo(1, StartY);

      //Draw Bar
      StartX := Trunc((FCutView.FWaveData.ZoomStart * (FBuf.Width - 6)) / High(FCutView.FWaveData.WaveArray)) + 3;
      EndX := Trunc((FCutView.FWaveData.ZoomEnd * (FBuf.Width - 6)) / High(FCutView.FWaveData.WaveArray)) + 3;
      if StartX = EndX then
        EndX := StartX + 1;
      for y := 0 to ScrollbarHeight - 4 do
      begin
        MoveTo(StartX, StartY + y + 2);
        LineTo(EndX, StartY + y + 2);
      end;
    end;
  end;
  function BuildTime(T: Double): string;
  var
    Min, Sec, MSec: Word;
  begin
    Min := Trunc(T / 60);
    T := T - Trunc(T / 60) * 60;
    Sec := Trunc(T);
    T := T - Trunc(T);
    MSec := (Trunc(T * 1000) div 10) * 10;
    Result := Format('%0.2d:%0.2d.%0.3d', [Min, Sec, MSec]) + ' ' + _('minutes');
  end;
  procedure DrawLineText(ArrayIdx, X: Cardinal);
  var
    L: Integer;
    TS: TSize;
    SecText: string;
  begin
    L := Trunc(((ArrayIdx - FCutView.FWaveData.ZoomStart) / FCutView.FWaveData.ZoomSize) * FBuf.Width);
    SecText := BuildTime(FCutView.FWaveData.WaveArray[ArrayIdx].Sec); // - FCutView.FWaveData.WaveArray[FCutView.FWaveData.ZoomStart].Sec);
    FBuf.Canvas.Font.Color := clWhite;
    SetBkMode(FBuf.Canvas.Handle, TRANSPARENT);
    TS := GetTextSize(SecText, Canvas.Font);
    if FBuf.Width < L + 4 + TS.cx then
      FBuf.Canvas.TextOut(L - 4 - TS.cx, X, SecText)
    else
      FBuf.Canvas.TextOut(L + 4, X, SecText);
  end;
var
  i, v, vnext: Integer;
  v2: Double;
  Last: Integer;
  LBuf, RBuf: Cardinal;
  Added: Cardinal;
  HT: Cardinal;
  TS: TSize;
  Txt: string;
  ArrayFrom, ArrayTo: Cardinal;
  L1, L2: Cardinal;
  CS, CE: Cardinal;
begin
  FBuf.Canvas.Brush.Color := clBlack;
  FBuf.Canvas.FillRect(Rect(0, 0, FBuf.Width, FBuf.Height));

  if (ClientHeight < 2) or (ClientWidth < 2) then
    Exit;

  if FCutView.FError then
  begin
    Txt := _('Error loading file');
    TS := GetTextSize(Txt, Canvas.Font);
    FBuf.Canvas.Font.Color := clWhite;
    SetBkMode(FBuf.Canvas.Handle, TRANSPARENT);
    FBuf.Canvas.TextOut(FBuf.Width div 2 - TS.cx div 2, FBuf.Height div 2 - TS.cy, Txt);
    Exit;
  end;

  if (FCutView.FWaveData = nil) or (FCutView.FScanThread <> nil) then
  begin
    Txt := _('Loading file...');
    TS := GetTextSize(Txt, Canvas.Font);
    FBuf.Canvas.Font.Color := clWhite;
    SetBkMode(FBuf.Canvas.Handle, TRANSPARENT);
    FBuf.Canvas.TextOut(FBuf.Width div 2 - TS.cx div 2, FBuf.Height div 2 - TS.cy, Txt);
  end;

  if (FCutView = nil) or (FCutView.FWaveData = nil) then
    Exit;

  if Length(FCutView.FWaveData.WaveArray) = 0 then
    Exit;


  ht := (FBuf.Height div 2) - ScrollbarHeight - 1;

  LBuf := 0;
  RBuf := 0;
  Added := 0;
  Last := 0;

  if FDoZoom then
  begin
    if FZoomStartLine = High(Cardinal) then
    begin
      FCutView.FWaveData.ZoomStart := 0;
      FCutView.FWaveData.ZoomEnd := High(FCutView.FWaveData.WaveArray);
    end else
    begin
      FCutView.FWaveData.ZoomStart := FZoomStartLine;
      FCutView.FWaveData.ZoomEnd := FZoomEndLine;
      FZoomStartLine := High(Cardinal);
      FZoomEndLine := High(Cardinal);
    end;
    FDoZoom := False;
  end;

  for i := 0 to FCutView.FWaveData.Silence.Count - 1 do
  begin
    CS := FCutView.FWaveData.Silence[i].CutStart;
    CE := FCutView.FWaveData.Silence[i].CutEnd;

    if (CS < FCutView.FWaveData.CutStart) and (CE < FCutView.FWaveData.CutStart) then
      Continue;
    if CS > FCutView.FWaveData.CutEnd then
      Continue;

    if CS < FCutView.FWaveData.CutStart then
      CS := FCutView.FWaveData.CutStart;
    if CE > FCutView.FWaveData.CutEnd then
      CE := FCutView.FWaveData.CutEnd;

    L1 := Floor(((CS - FCutView.FWaveData.ZoomStart) / FCutView.FWaveData.ZoomSize) * FBuf.Width);
    L2 := Ceil(((CE - FCutView.FWaveData.ZoomStart) / FCutView.FWaveData.ZoomSize) * FBuf.Width);

    if L2 - L1 <= 2 then
      Inc(L2);

    FBuf.Canvas.Brush.Color := clGray;
    FBuf.Canvas.FillRect(Rect(L1, 0, L2, ht - 1));
    FBuf.Canvas.FillRect(Rect(L1, ht + 1, L2, FBuf.Height - ScrollbarHeight - 3));
  end;

  ArrayFrom := FCutView.FWaveData.ZoomStart;
  ArrayTo := FCutView.FWaveData.ZoomEnd;

  v2 := (1 / 1) * FBuf.Width;

  for i := ArrayFrom - 1 to ArrayTo do
  begin
    v := Integer(Trunc(((i - Int64(ArrayFrom)) / (ArrayTo - ArrayFrom)) * v2));
    vnext := Integer(Trunc(((i - Int64(ArrayFrom) + 1) / (ArrayTo - ArrayFrom)) * v2));

    if v = Last then
    begin
      LBuf := LBuf + FCutView.FWaveData.WaveArray[i].L;
      RBuf := RBuf + FCutView.FWaveData.WaveArray[i].R;
      Added := Added + 1;
      Continue;
    end else
    begin
      if Added > 0 then
      begin
        LBuf := LBuf div Added;
        RBuf := RBuf div Added;
      end else
      begin
        LBuf := FCutView.FWaveData.WaveArray[i].L;
        RBuf := FCutView.FWaveData.WaveArray[i].R;
      end;
    end;

    FBuf.Canvas.Pen.Color := FPeakColor;
    FBuf.Canvas.Brush.Color := FPeakColor;
    if abs(vnext - v) <= 2 then
    begin
      FBuf.Canvas.MoveTo(v, ht - 1);
      FBuf.Canvas.LineTo(v, ht - 1 - Trunc((LBuf / 33000) * ht));
      FBuf.Canvas.Pixels[v, ht - 1 - Trunc((LBuf / 33000) * ht)] := FPeakEndColor;
      FBuf.Canvas.MoveTo(v, ht + 1);
      FBuf.Canvas.LineTo(v, ht + 1 + Trunc((RBuf / 33000) * ht));
      FBuf.Canvas.Pixels[v, ht + 1 + Trunc((RBuf / 33000) * ht)] := FPeakEndColor;
    end else
    begin
      FBuf.Canvas.FillRect(Rect(v, ht, vnext - 1, ht - Trunc((LBuf / 33000) * ht)));
      FBuf.Canvas.FillRect(Rect(v, ht + 1, vnext - 1, ht + 1 + Trunc((LBuf / 33000) * ht)));
    end;

    RBuf := 0;
    LBuf := 0;
    Added := 0;

    Last := v;
  end;

  FBuf.Canvas.Pen.Color := FZoomOuterColor;
  FBuf.Canvas.MoveTo(0, ht);
  FBuf.Canvas.LineTo(FBuf.Width, ht);

  DrawLine(FStartLine, FStartColor);
  DrawLine(FEndLine, FEndColor);

  DrawTransparentBox(FZoomStartLine, FZoomEndLine, FZoomOuterColor, FZoomInnerColor);

  DrawLineText(FStartLine, 16);
  DrawLineText(FEndLine, 28);

  DrawLine(FPlayLine, FPlayColor);
  DrawLineText(FPlayLine, 40);

  DrawScrollBar(FZoomOuterColor);

  {
  if BASSChannelIsActive(FCutView.FPlayer) = BASS_ACTIVE_PLAYING then
  begin
  end;
  }

  {
  for i := 0 to FCutView.FWaveData.Silence.Count - 1 do
  begin
    if (FCutView.FWaveData.CutStart <= FCutView.FWaveData.Silence[i].CutStart) and
       (FCutView.FWaveData.CutEnd >= FCutView.FWaveData.Silence[i].CutEnd) then
    begin
      DrawLine(FCutView.FWaveData.Silence[i].CutStart, clPurple);
      DrawLine(FCutView.FWaveData.Silence[i].CutEnd, clPurple);
    end;
  end;
  }

  FBuf.Canvas.Font.Color := clWhite;
  FBuf.Canvas.TextOut(4, 4, BuildTime(FCutView.FWaveData.Secs) + ' - ' + RemoveFileExt(ExtractFileName(FCutView.FFilename)));
end;

constructor TCutPaintBox.Create(AOwner: TComponent);
begin
  inherited;

  FPeakColor := HTML2Color('3b477e');
  FPeakEndColor := HTML2Color('424e83');
  FStartColor := HTML2Color('ece52b');
  FEndColor := HTML2Color('218030');
  FPlayColor := HTML2Color('c33131');
  FZoomOuterColor :=  HTML2Color('748cf7');
  FZoomInnerColor := HTML2Color('4d5ea5');

  FCutView := TCutView(AOwner);
  if FBuf = nil then
    FBuf := TBitmap.Create;

  FZoomStartLine := High(Cardinal);
  FZoomEndLine := High(Cardinal);

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 50;
  FTimer.OnTimer := TimerTimer;
end;

destructor TCutPaintBox.Destroy;
begin
  FBuf.Free;
  FTimer.Enabled := False;
  inherited;
end;

procedure TCutPaintBox.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;

  if FCutView.FWaveData = nil then
    Exit;

  if Button = mbLeft then
    FMouseMoveStartX := X;

  if not HandleScrollBar(X, Y, @Button, mmDown) then
    SetLine(X, Button, mmDown);
end;

procedure TCutPaintBox.MouseMove(Shift: TShiftState; X, Y: Integer);
var Button: PMouseButton;
    ButtonData: TMouseButton;
begin
  inherited;

  if FCutView.FWaveData = nil then
    Exit;

  if (X <> FMouseOldX) or (Y <> FMouseOldY) then
  begin
    if ssLeft in Shift then
    begin
      ButtonData := mbLeft;
      Button := @ButtonData;
    end
    else if ssRight in Shift then
    begin
      ButtonData := mbRight;
      Button := @ButtonData;
    end
    else
      Button := nil;
    if not HandleScrollBar(X, Y, Button, mmMove) then
    begin
      if Button <> nil then
        SetLine(X, Button^, mmMove);

{      if ssLeft in Shift then
        SetLine(X, mbLeft, mmMove)
      else if ssRight in Shift then
        SetLine(X, mbRight, mmMove);}
    end;
    FMouseOldX := X;
    FMouseOldY := Y;
  end;
end;

procedure TCutPaintBox.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;

  if FCutView.FWaveData = nil then
    Exit;

  if not HandleScrollBar(X, Y, @Button, mmUp) then
    SetLine(X, Button, mmUp);
end;

procedure TCutPaintBox.Paint;
begin
  inherited;

  Canvas.Draw(0, 0, FBuf);
end;

procedure TCutPaintBox.Resize;
begin
  inherited;

  if FBuf = nil then
    Exit;

  FBuf.Width := ClientWidth;
  FBuf.Height := ClientHeight;

  BuildBuffer;
end;

function TCutPaintBox.PixelsToArray(X: Integer): Cardinal;
begin
  // Wichtig weil Integer und Cardinal.
  if X < 0 then
    X := 0;
  if X > ClientWidth then
    X := ClientWidth;

  Result := FCutView.FWaveData.ZoomStart + Cardinal(Ceil((X / FBuf.Width) * FCutView.FWaveData.ZoomSize));

  if Result > FCutView.FWaveData.ZoomEnd then
    Result := FCutView.FWaveData.ZoomEnd;
  if Result < FCutView.FWaveData.ZoomStart then
    Result := FCutView.FWaveData.ZoomStart;
end;

function TCutPaintBox.GetPlayerPos: Cardinal;
var
  i: Integer;
  SearchFrom, BytePos: Cardinal;
begin
  Result := 0;
  BytePos := BASSChannelGetPosition(FCutView.FPlayer, BASS_POS_BYTE);

  SearchFrom := 0;
  if BytePos > FCutView.FWaveData.WaveArray[FPlayingIndex].Pos then
  begin
    SearchFrom := FPlayingIndex;
  end;

  for i := SearchFrom to FCutView.FWaveData.CutEnd do
  begin
    if FCutView.FWaveData.WaveArray[i].Pos >= BytePos then
    begin
      Result := i;
      Break;
    end;
  end;
end;

procedure TCutPaintBox.SetLine(X: Integer; Button: TMouseButton; Mode: TMouseMode);
var
  ArrayPos: Cardinal;
  Swap: Cardinal;
begin
  ArrayPos := PixelsToArray(X);

  if ArrayPos < FCutView.FWaveData.ZoomStart then
    ArrayPos := FCutView.FWaveData.ZoomStart;
  if ArrayPos > FCutView.FWaveData.ZoomEnd then
    ArrayPos := FCutView.FWaveData.ZoomEnd;

  case FCutView.FLineMode of
    lmEdit:
      if (Button = mbLeft) and (Mode <> mmUp) then
      begin
        FStartLine := ArrayPos;
        if FStartLine >= FCutView.FWaveData.ZoomEnd then
          FStartLine := FCutView.FWaveData.ZoomEnd - 1;
        if FEndLine <= FStartLine then
          FEndLine := FStartLine + 1;
      end else if (Button = mbRight) and (Mode <> mmUp) then
      begin
        FEndLine := ArrayPos;
        if FEndLine <= FCutView.FWaveData.ZoomStart then
          FEndLine := FCutView.FWaveData.ZoomStart + 1;
        if FStartLine >= FEndLine then
          FStartLine := FEndLine - 1;
      end;
    lmPlay:
      if (Button = mbLeft) and (Mode <> mmUp) then
      begin
        if FCutView.FPlayer > 0 then
        begin
          //BASSChannelStop(FCutView.FPlayer);
          BASSChannelSetPosition(FCutView.FPlayer, FCutView.FWaveData.WaveArray[ArrayPos].Pos, BASS_POS_BYTE);
        end;
        FPlayLine := ArrayPos;
      end;
    lmZoom:
      begin
        if (Button = mbLeft) and (Mode <> mmUp) then
        begin
          if (FZoomStartLine = High(Cardinal)) or (Mode = mmDown) then
          begin
            FZoomStartLine := ArrayPos;
            FZoomEndLine := ArrayPos;
            FDoZoom := False;
          end else
          begin
            FZoomEndLine := ArrayPos;
          end;
        end;

        if (Button = mbLeft) and (Mode = mmUp) then
        begin
          if FZoomStartLine > FZoomEndLine then
          begin
            Swap := FZoomStartLine;
            FZoomStartLine := FZoomEndLine;
            FZoomEndLine := Swap;
          end;
          if FZoomEndLine - FZoomStartLine < MinimumDisplayedSampleCount then
          begin
            if FZoomStartLine = 0 then
              inc(FZoomEndLine, MinimumDisplayedSampleCount - FZoomEndLine + FZoomStartLine)
            else
              dec(FZoomStartLine, MinimumDisplayedSampleCount - FZoomEndLine + FZoomStartLine);
          end;
          FDoZoom := True;
        end;

        if Button = mbRight then
        begin
          FZoomStartLine := High(Cardinal);
          FZoomEndLine := High(Cardinal);
          FDoZoom := True;
        end;
      end;
  end;

  if Assigned(FCutView.FOnStateChanged) then
    FCutView.FOnStateChanged(FCutView);

  begin
    {
    P := BASSChannelGetPosition(FCutView.FPlayer, BASS_POS_BYTE);
    if (FCutView.FWaveData.WaveArray[FStartLine].Pos > P) or
       (FCutView.FWaveData.WaveArray[FEndLine].Pos < P) then
    begin
      BASSChannelStop(FCutView.FPlayer);
    end else
    begin
      if not IsStart then
      begin
        if FCutView.FSync > 0 then
          BASSChannelRemoveSync(FCutView.FPlayer, FCutView.FSync);
        FCutView.FSync := BASSChannelSetSync(FCutView.FPlayer, BASS_SYNC_POS or BASS_SYNC_MIXTIME, FCutView.FWaveData.WaveArray[FEndLine].Pos, LoopSyncProc, FCutView);
      end;
    end;
    }
  end;

  BuildBuffer;
  Paint;
end;

function TCutPaintBox.HandleScrollBar(X: Integer; Y: Integer; Button: PMouseButton;
  Mode: TMouseMode) : Boolean;
var ButtonData: TMouseButton;
    StartX, EndX, DiffX: Integer;
begin
  if (Button <> nil) then
  begin
    ButtonData := Button^;
    if (ButtonData = mbLeft) and (Y >= Height - ScrollbarHeight - 2) then
    begin
      if (Mode = mmMove) or (Mode = mmDown) then
        FScrollbarActive := True;
    end;
  end;

  if FScrollbarActive then
  begin
    if Mode = mmUp then
    begin
      FScrollbarActive := False;
      Result := true;
      Exit;
    end else
    begin
      DiffX := Trunc(((X - FMouseMoveStartX) * High(FCutView.FWaveData.WaveArray)) / (FBuf.Width - 6));
//      OutputDebugString(PWideChar(' DiffX: '+ IntToStr(DiffX)));
      StartX := FCutView.FWaveData.ZoomStart + Cardinal(DiffX);
      EndX := FCutView.FWaveData.ZoomEnd + Cardinal(DiffX);
      if StartX < 0 then
      begin
        StartX := 0;
        EndX := FCutView.FWaveData.ZoomSize;
      end;
      if EndX > High(FCutView.FWaveData.WaveArray) then
      begin
        EndX := High(FCutView.FWaveData.WaveArray);
        StartX := EndX - FCutView.FWaveData.ZoomSize;
      end;
      FZoomStartLine := StartX;
      FZoomEndLine := EndX;
      FMouseMoveStartX := X;
      FDoZoom := true;
      BuildBuffer;
      Paint;
    end;
  end;

  Result := FScrollbarActive;
end;

procedure TCutPaintBox.TimerTimer(Sender: TObject);
begin
  if csDestroying in ComponentState then
    Exit;

  if (FCutView.FPlayer > 0) and (BASSChannelIsActive(FCutView.FPlayer) = BASS_ACTIVE_PLAYING) then
  begin
    FPlayingIndex := GetPlayerPos;
    FPlayLine := FPlayingIndex;
    {
    if FCutStates.Count > 1 then
    begin
      LastCut := FCutStates[FCutStates.Count - 1];
      P := BASSChannelGetPosition(FPlayer, BASS_POS_BYTE);
      if (P < LastCut.CutStart + FStartLine) or
         (P > LastCut.CutStart + FEndLine) then
      begin
        BASSChannelStop(FPlayer);
      end;
    end;
    }
    BuildBuffer;
    Paint;
  end;
end;

end.

