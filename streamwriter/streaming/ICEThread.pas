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
unit ICEThread;

interface

uses
  SysUtils, Windows, WinSock, Classes, HTTPThread, ExtendedStream, ICEStream,
  Functions, SocketThread, SyncObjs, AudioStream, Generics.Collections,
  AppData, ICEPlayer, RelayServer, LanguageObjects;

type
  TICEThreadStates = (tsRecording, tsRetrying, tsIOError);

  {TRelayInfo = record
    Thread: TRelayThread;
    FirstSent: Boolean;
  end;
  PRelayInfo = ^TRelayInfo;}
  TRelayInfoList = TList<TRelayThread>;

  TICEThread = class(THTTPThread)
  private
    FTitle: string;
    FState: TICEThreadStates;
    FPlayer: TICEPlayer;
    FRecording: Boolean;
    FRecordingStarted: Boolean;
    FPlaying: Boolean;
    FPlayingStarted: Boolean;
    FSleepTime: Integer;

    FRelayThreads: TRelayInfoList;

    FOnTitleChanged: TNotifyEvent;
    FOnSongSaved: TNotifyEvent;
    FOnNeedSettings: TNotifyEvent;
    FOnStateChanged: TNotifyEvent;
    FOnAddRecent: TNotifyEvent;
    FOnTitleAllowed: TNotifyEvent;

    FTypedStream: TICEStream;
    FPlayBufferLock: TCriticalSection;
    FPlayBuffer: TAudioStreamMemory;

    procedure StartRecordingInternal;
    procedure StopRecordingInternal;
    procedure StartPlayInternal;
    procedure StopPlayInternal;

    procedure StreamTitleChanged(Sender: TObject);
    procedure StreamSongSaved(Sender: TObject);
    procedure StreamNeedSettings(Sender: TObject);
    procedure StreamChunkReceived(Buf: Pointer; Len: Integer);
    procedure StreamIOError(Sender: TObject);
    procedure StreamTitleAllowed(Sender: TObject);

    procedure ThreadNeedStartData(Sender: TObject);
  protected
    procedure Execute; override;

    procedure DoStuff; override;
    procedure DoHeaderRemoved; override;
    procedure DoReceivedData(Buf: Pointer; Len: Integer); override;
    procedure DoConnecting; override;
    procedure DoConnected; override;
    procedure DoDisconnected; override;
    procedure DoEnded; override;
    procedure DoSpeedChange; override;
    procedure DoException(E: Exception); override;
  public
    constructor Create(URL: string); reintroduce;
    destructor Destroy; override;

    procedure SetSettings(Settings: TStreamSettings);
    procedure StartRelay(Thread: TRelayThread);

    procedure StartPlay;
    procedure StopPlay;
    procedure StartRecording;
    procedure StopRecording;
    procedure SetVolume(Vol: Integer);

    procedure LockRelay;
    procedure UnlockRelay;

    property RecvStream: TICEStream read FTypedStream;
    property Title: string read FTitle;
    property State: TICEThreadStates read FState;

    property Recording: Boolean read FRecordingStarted;
    property Playing: Boolean read FPlayingStarted;
    property SleepTime: Integer read FSleepTime write FSleepTime;
    property RelayThreads: TRelayInfoList read FRelayThreads;

    property OnTitleChanged: TNotifyEvent read FOnTitleChanged write FOnTitleChanged;
    property OnSongSaved: TNotifyEvent read FOnSongSaved write FOnSongSaved;
    property OnNeedSettings: TNotifyEvent read FOnNeedSettings write FOnNeedSettings;
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnAddRecent: TNotifyEvent read FOnAddRecent write FOnAddRecent;
    property OnTitleAllowed: TNotifyEvent read FOnTitleAllowed write FOnTitleAllowed;
  end;

implementation

{ TICEThread }

procedure TICEThread.SetSettings(Settings: TStreamSettings);
begin
  // Das hier wird nur gesynct aus dem Mainthread heraus aufgerufen.
  FTypedStream.Settings.Assign(Settings);
end;

procedure TICEThread.SetVolume(Vol: Integer);
begin
  FPlayer.SetVolume(Vol);
end;

procedure TICEThread.StartRelay(Thread: TRelayThread);
begin
  Thread.OnNeedStartData := ThreadNeedStartData;
end;

procedure TICEThread.StartPlay;
begin
  FPlayingStarted := True;
end;

procedure TICEThread.StartPlayInternal;
var
  P: Integer;
begin
  FPlaying := True;
  if FPlayBuffer = nil then
    Exit;

  if not FPlayer.Playing then
  begin
    FPlayer.Mem.Clear;

    FPlayBufferLock.Enter;
    try
      P := FPlayBuffer.GetFrame(0, False);
      if P = -1 then
        P := 0;
      FPlayBuffer.Seek(P, soFromBeginning);
      FPlayer.PushData(Pointer(Integer(FPlayBuffer.Memory) + P), FPlayBuffer.Size - P);
    finally
      FPlayBufferLock.Leave;
    end;

    FPlayer.Play;

    if Assigned(FOnStateChanged) then
      FOnStateChanged(Self);
  end;
end;

procedure TICEThread.StopPlay;
begin
  FPlayingStarted := False;
end;

procedure TICEThread.StopPlayInternal;
begin
  FPlaying := False;
  FPlayer.Stop;
  DoStuff; // Das muss so, damit der Thread aufs Fadeout-Ende wartet!

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TICEThread.StartRecording;
begin
  FRecordingStarted := True;
end;

procedure TICEThread.StartRecordingInternal;
begin
  FRecording := True;
  FTypedStream.StartRecording;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TICEThread.StopRecording;
begin
  FRecordingStarted := False;
end;

procedure TICEThread.StopRecordingInternal;
begin
  FRecording := False;
  FTypedStream.StopRecording;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TICEThread.StreamNeedSettings(Sender: TObject);
begin
  Sync(FOnNeedSettings);
end;

procedure TICEThread.StreamChunkReceived(Buf: Pointer; Len: Integer);
var
  RemoveTo: Int64;
  Thread: TRelayThread;
const
  MAX_BUFFER_SIZE = 256000;
begin
  if FPlaying and (not FPlayer.Playing) then
    FPlayer.Play;

  if FPlaying then
  begin
    FPlayer.PushData(Buf, Len);
    //WriteDebug(Format('Playbuffer size: %d', [FPlayer.Mem.Size]));
  end;

  if FPlayBuffer = nil then
    Exit;
  FPlayBufferLock.Enter;
  try
    FPlayBuffer.Seek(0, soFromEnd);
    FPlayBuffer.WriteBuffer(Buf^, Len);

    //WriteDebug(Format('Playbuffer size: %d bytes', [FPlayBuffer.Size]));

    if FPlayBuffer.Size > MAX_BUFFER_SIZE then
    begin
      // Puffer "rotieren"
      RemoveTo := FPlayBuffer.GetFrame(65536, False);
      FPlayBuffer.RemoveRange(0, RemoveTo - 1);
      //WriteDebug(Format('Playbuffer size after remove: %d bytes', [FPlayBuffer.Size]));
    end;
  finally
    FPlayBufferLock.Leave;
  end;

  for Thread in FRelayThreads do
  begin
    // Wenn schon was gesendet wurde, die neuen Daten schicken
    Thread.SendLock.Enter;
    try
      Thread.SendStream.Seek(0, soFromEnd);
      Thread.SendStream.Write(Buf^, Len);

      //WriteDebug(Format('Wrote %d bytes to relaythread, new size is %d', [Len, Thread.Thread.SendStream.Size]));
    finally
      Thread.SendLock.Leave;
    end;
  end;
end;

procedure TICEThread.StreamIOError(Sender: TObject);
begin
  FState := tsIOError;
  Sync(FOnStateChanged);
end;

procedure TICEThread.StreamTitleAllowed(Sender: TObject);
begin
  Sync(FOnTitleAllowed);
end;

procedure TICEThread.StreamSongSaved(Sender: TObject);
begin
  Sync(FOnSongSaved);
end;

procedure TICEThread.StreamTitleChanged(Sender: TObject);
begin
  Sync(FOnTitleChanged);
  FState := tsRecording;
  Sync(FOnStateChanged);
end;

procedure TICEThread.ThreadNeedStartData(Sender: TObject);
var
  P: Integer;
  Thread: TRelayThread;
begin
  Thread := TRelayThread(Sender);
  if FPlayBuffer <> nil then
  begin
    FPlayBufferLock.Enter;
    try
      Thread.SendLock.Enter;
      try
        P := FPlayBuffer.GetFrame(0, False);
        if P = -1 then
          P := 0;
        FPlayBuffer.Seek(P, soFromBeginning);
        Thread.SendStream.Seek(0, soFromEnd);
        Thread.SendStream.CopyFrom(FPlayBuffer, FPlayBuffer.Size - P);
      finally
        Thread.SendLock.Leave;
      end;
    finally
      FPlayBufferLock.Leave;
    end;
  end;
end;

procedure TICEThread.DoConnecting;
begin
  inherited;
  WriteDebug(Format(_('Connecting to %s:%d...'), [Host, Port]), 0, 0);
end;

procedure TICEThread.DoConnected;
begin
  WriteDebug(_('Connected'), 0, 0);
  inherited;
end;

procedure TICEThread.DoDisconnected;
begin
  inherited;

  if FClosed then
    if (FTypedStream.AudioType <> atNone) then
      raise Exception.Create(_('Connection closed'));
  Sleep(100);
end;

procedure TICEThread.DoEnded;
var
  Thread: TRelayThread;
begin
  inherited;
  for Thread in FRelayThreads do
    Thread.Terminate;

  Sleep(FSleepTime * 1000);
end;

procedure TICEThread.DoException(E: Exception);
var
  StartTime: Cardinal;
  Delay: Cardinal;
begin
  inherited;

  WriteDebug(Format(_('%s'), [E.Message]), '', 3, 0);

  Delay := FTypedStream.Settings.RetryDelay * 1000;
  if FState <> tsIOError then
  begin
    FState := tsRetrying;
    Sync(FOnStateChanged);
    StartTime := GetTickCount;
    while StartTime > GetTickCount - Delay do
    begin
      Sleep(500);
      if Terminated then
        Exit;
    end;
  end;
end;

procedure TICEThread.DoStuff;
begin
  inherited;

  while FPlayer.FadingOut do
    Sleep(20);

  if FRecordingStarted and (not FRecording) then
  begin
    StartRecordingInternal;
    FRecording := True;
  end;
  if (not FRecordingStarted) and FRecording then
  begin
    StopRecordingInternal;
    FRecording := False;
  end;

  if FPlayingStarted and (not FPlaying) then
  begin
    StartPlayInternal;
  end;
  if (not FPlayingStarted) and FPlaying then
  begin
    StopPlayInternal;
  end;
end;

procedure TICEThread.DoHeaderRemoved;
begin
  inherited;

  case FTypedStream.AudioType of
    atMPEG:
      FPlayBuffer := TMPEGStreamMemory.Create;
    atAAC:
      FPlayBuffer := TAACStreamMemory.Create;
  end;

  if (FTypedStream.HeaderType = 'icy') and
     (FTypedStream.StreamName <> '') then
    Sync(FOnAddRecent);
end;

procedure TICEThread.DoReceivedData(Buf: Pointer; Len: Integer);
begin
  inherited;

end;

procedure TICEThread.DoSpeedChange;
begin
  inherited;

end;

procedure TICEThread.Execute;
begin
  inherited;

end;

procedure TICEThread.LockRelay;
begin
  FPlayBufferLock.Enter;
end;

procedure TICEThread.UnlockRelay;
begin
  FPlayBufferLock.Leave;
end;

constructor TICEThread.Create(URL: string);
var
  Host, Data: string;
  SendData: AnsiString;
  Port: Integer;
begin
  inherited Create(URL, TICEStream.Create);

  FRecording := False;
  FRecordingStarted := False;
  FPlaying := False;
  FPlayingStarted := False;
  FSleepTime := 0;

  AppGlobals.Lock;
  ProxyEnabled := AppGlobals.ProxyEnabled;
  ProxyHost := AppGlobals.ProxyHost;
  ProxyPort := AppGlobals.ProxyPort;
  AppGlobals.Unlock;

  FPlayBufferLock := TCriticalSection.Create;
  FRelayThreads := TRelayInfoList.Create;
  FTitle := '';
  FPlayer := TICEPlayer.Create;

  FUserAgent := AnsiString(AppGlobals.AppName) + ' v' + AppGlobals.AppVersion.AsString;

  ParseURL(URL, Host, Port, Data);

  FTypedStream := TICEStream(FRecvStream);
  FTypedStream.OnTitleChanged := StreamTitleChanged;
  FTypedStream.OnSongSaved := StreamSongSaved;
  FTypedStream.OnNeedSettings := StreamNeedSettings;
  FTypedStream.OnChunkReceived := StreamChunkReceived;
  FTypedStream.OnIOError := StreamIOError;
  FTypedStream.OnTitleAllowed := StreamTitleAllowed;

  if ProxyEnabled then
    SendData := 'GET ' + AnsiString(URL) + ' HTTP/1.1'#13#10
  else
    SendData := 'GET ' + AnsiString(Data) + ' HTTP/1.1'#13#10;
  SendData := SendData + 'Host: ' + AnsiString(Host) + #13#10;
  SendData := SendData + 'Accept: */*'#13#10;
  SendData := SendData + 'User-Agent: mhttplib/' + FUserAgent + #13#10;
  SendData := SendData + 'Icy-MetaData:1'#13#10;
  SendData := SendData + 'Connection: close'#13#10;
  SendData := SendData + #13#10;
  FSendStream.SetData(SendData);
end;

destructor TICEThread.Destroy;
begin
  FPlayer.Free;
  if FPlayBuffer <> nil then
    FPlayBuffer.Free;
  FPlayBufferLock.Free;
  FRelayThreads.Free;
  inherited;
end;

end.
