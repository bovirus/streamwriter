{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2012 Alexander Nottelmann

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
unit HomeCommunication;

interface

uses
  Windows, SysUtils, Classes, HTTPThread, StrUtils, Generics.Collections,
  Sockets, WinSock, ZLib, Communication, Protocol, Commands, ExtendedStream,
  HomeCommands, DataManager, AppData, AudioFunctions;

type
  TCommErrors = (ceUnknown, ceAuthRequired, ceNotification, ceOneTimeNotification);

  THomeThread = class(TCommandThreadBase)
  private
    FLists: TDataLists;

    FAuthenticated: Boolean;
    FIsAdmin: Boolean;

    FHandshakeSuccess: Boolean;

    FNetworkTitleChanged: TCommandNetworkTitleChangedResponse;

    FServerInfoClientCount: Cardinal;
    FServerInfoRecordingCount: Cardinal;

    FErrorID: TCommErrors;
    FErrorMsg: string;

    FOnHandshakeReceived: TSocketEvent;
    FOnLogInReceived: TSocketEvent;
    FOnLogOutReceived: TSocketEvent;
    FOnServerDataReceived: TSocketEvent;
    FOnNetworkTitleChangedReceived: TSocketEvent;
    FOnServerInfoReceived: TSocketEvent;
    FOnErrorReceived: TSocketEvent;

    procedure DoHandshakeReceived(CommandHeader: TCommandHeader; Command: TCommandHandshakeResponse);
    procedure DoLogInReceived(CommandHeader: TCommandHeader; Command: TCommandLogInResponse);
    procedure DoLogOutReceived(CommandHeader: TCommandHeader; Command: TCommandLogOutResponse);
    procedure DoServerDataReceived(CommandHeader: TCommandHeader; Command: TCommandGetServerDataResponse);
    procedure DoNetworkTitleChanged(CommandHeader: TCommandHeader; Command: TCommandNetworkTitleChangedResponse);
    procedure DoServerInfoReceived(CommandHeader: TCommandHeader; Command: TCommandServerInfoResponse);
    procedure DoMessageReceived(CommandHeader: TCommandHeader; Command: TCommandMessageResponse);
  protected
    procedure DoReceivedCommand(ID: Cardinal; CommandHeader: TCommandHeader; Command: TCommand); override;
    procedure DoException(E: Exception); override;
    procedure DoEnded; override;
  public
    constructor Create(Lists: TDataLists);
    destructor Destroy; override;

    property OnHandshakeReceived: TSocketEvent read FOnHandshakeReceived write FOnHandshakeReceived;
    property OnLogInReceived: TSocketEvent read FOnLogInReceived write FOnLogInReceived;
    property OnLogOutReceived: TSocketEvent read FOnLogOutReceived write FOnLogOutReceived;
    property OnServerDataReceived: TSocketEvent read FOnServerDataReceived write FOnServerDataReceived;
    property OnNetworkTitleChangedReceived: TSocketEvent read FOnNetworkTitleChangedReceived write FOnNetworkTitleChangedReceived;
    property OnServerInfoReceived: TSocketEvent read FOnServerInfoReceived write FOnServerInfoReceived;
    property OnErrorReceived: TSocketEvent read FOnErrorReceived write FOnErrorReceived;
  end;

  TBooleanEvent = procedure(Sender: TObject; Value: Boolean) of object;
  TStreamsReceivedEvent = procedure(Sender: TObject) of object;
  TChartsReceivedEvent = procedure(Sender: TObject) of object;
  TTitleChangedEvent = procedure(Sender: TObject; ID: Cardinal; Name, Title, CurrentURL, TitlePattern: string; Format: TAudioTypes; Kbps: Cardinal) of object;
  TServerInfoEvent = procedure(Sender: TObject; ClientCount, RecordingCount: Cardinal) of object;
  TErrorEvent = procedure(Sender: TObject; ID: TCommErrors; Msg: string) of object;

  THomeCommunication = class
  private
    FDisabled: Boolean;
    FThread: THomeThread;

    FLists: TDataLists;

    FAuthenticated, FIsAdmin, FWasConnected, FConnected, FNotifyTitleChanges: Boolean;
    FTitleNotificationsSet: Boolean;

    FOnStateChanged: TNotifyEvent;
    FOnTitleNotificationsChanged: TNotifyEvent;
    FOnBytesTransferred: TTransferProgressEvent;

    FOnHandshakeReceived: TBooleanEvent;
    FOnLogInReceived: TBooleanEvent;
    FOnLogOutReceived: TNotifyEvent;
    FOnStreamsReceived: TStreamsReceivedEvent;
    FOnChartsReceived: TChartsReceivedEvent;
    FOnNetworkTitleChangedReceived: TTitleChangedEvent;
    FOnServerInfoReceived: TServerInfoEvent;
    FOnErrorReceived: TErrorEvent;

    procedure HomeThreadConnected(Sender: TSocketThread);
    procedure HomeThreadBeforeEnded(Sender: TSocketThread);
    procedure HomeThreadEnded(Sender: TSocketThread);
    procedure HomeThreadBytesTransferred(Sender: TObject; Direction: TTransferDirection; CommandID: Cardinal; CommandHeader: TCommandHeader; Transferred: UInt64);

    procedure HomeThreadHandshakeReceived(Sender: TSocketThread);
    procedure HomeThreadLogInReceived(Sender: TSocketThread);
    procedure HomeThreadLogOutReceived(Sender: TSocketThread);
    procedure HomeThreadServerDataReceived(Sender: TSocketThread);
    procedure HomeThreadNetworkTitleChangedReceived(Sender: TSocketThread);
    procedure HomeThreadServerInfoReceived(Sender: TSocketThread);
    procedure HomeThreadErrorReceived(Sender: TSocketThread);
  public
    constructor Create(Lists: TDataLists);
    destructor Destroy; override;

    procedure Connect;
    procedure Terminate;
    function SendCommand(Cmd: TCommand): Boolean;
    procedure SendHandshake;
    procedure SendLogIn(User, Pass: string);
    procedure SendLogOut;
    function SendGetServerData: Boolean;
    procedure SendUpdateStats(List: TList<Cardinal>; RecordingCount: Cardinal);
    procedure SendSetSettings(TitleNotifications: Boolean);
    procedure SendClientStats(Auto: Boolean);
    procedure SendSubmitStream(URL: string);
    procedure SendSetStreamData(StreamID: Cardinal; Rating: Byte);
    procedure SendTitleChanged(StreamID: Cardinal; StreamName, Title, CurrentURL, URL: string; Format: TAudioTypes;
      Kbps: Cardinal; URLs: TStringList);

    property Disabled: Boolean read FDisabled;
    property WasConnected: Boolean read FWasConnected;
    property Connected: Boolean read FConnected;
    property Authenticated: Boolean read FAuthenticated;
    property NotifyTitleChanges: Boolean read FNotifyTitleChanges;
    property IsAdmin: Boolean read FIsAdmin;

    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnTitleNotificationsChanged: TNotifyEvent read FOnTitleNotificationsChanged write FOnTitleNotificationsChanged;
    property OnBytesTransferred: TTransferProgressEvent read FOnBytesTransferred write FOnBytesTransferred;

    property OnHandshakeReceived: TBooleanEvent read FOnHandshakeReceived write FOnHandshakeReceived;
    property OnLogInReceived: TBooleanEvent read FOnLogInReceived write FOnLogInReceived;
    property OnLogOutReceived: TNotifyEvent read FOnLogOutReceived write FOnLogOutReceived;
    property OnStreamsReceived: TStreamsReceivedEvent read FOnStreamsReceived write FOnStreamsReceived;
    property OnChartsReceived: TChartsReceivedEvent read FOnChartsReceived write FOnChartsReceived;
    property OnNetworkTitleChangedReceived: TTitleChangedEvent read FOnNetworkTitleChangedReceived write FOnNetworkTitleChangedReceived;
    property OnServerInfoReceived: TServerInfoEvent read FOnServerInfoReceived write FOnServerInfoReceived;
    property OnErrorReceived: TErrorEvent read FOnErrorReceived write FOnErrorReceived;
  end;

var
  HomeComm: THomeCommunication;

implementation

{ THomeThread }

constructor THomeThread.Create(Lists: TDataLists);
begin
  FLists := Lists; // TODO: Lists im Thread. Betrifft Streams und Charts. �BERALL im programm muss dann gepr�ft werden,
                   // ob der thread gerade aktiv ist und was macht, bevor drauf zu gegriffen wird.

  inherited Create('mistake.ws', 7085, TSocketStream.Create);
  //inherited Create('gaia', 7085, TSocketStream.Create);

  UseSynchronize := True;
end;

destructor THomeThread.Destroy;
begin

  inherited;
end;

procedure THomeThread.DoEnded;
begin
  inherited;

  Sleep(3000);
end;

procedure THomeThread.DoMessageReceived(CommandHeader: TCommandHeader;
  Command: TCommandMessageResponse);
begin
  FErrorID := TCommErrors(Command.MessageID);
  FErrorMsg := Command.MessageMsg;

  if Assigned(FOnErrorReceived) then
    Sync(FOnErrorReceived);
end;

procedure THomeThread.DoException(E: Exception);
begin
  inherited;

end;

procedure THomeThread.DoHandshakeReceived(CommandHeader: TCommandHeader;
  Command: TCommandHandshakeResponse);
begin
  FHandshakeSuccess := Command.Success;

  if Assigned(FOnHandshakeReceived) then
    Sync(FOnHandshakeReceived);
end;

procedure THomeThread.DoLogInReceived(CommandHeader: TCommandHeader;
  Command: TCommandLogInResponse);
begin
  FAuthenticated := Command.Success;
  FIsAdmin := Command.IsAdmin;

  if Assigned(FOnLogInReceived) then
    Sync(FOnLogInReceived);
end;

procedure THomeThread.DoLogOutReceived(CommandHeader: TCommandHeader;
  Command: TCommandLogOutResponse);
begin
  FAuthenticated := False;

  if Assigned(FOnLogOutReceived) then
    Sync(FOnLogOutReceived);
end;

procedure THomeThread.DoNetworkTitleChanged(CommandHeader: TCommandHeader;
  Command: TCommandNetworkTitleChangedResponse);
begin
  if not AppGlobals.AutoTuneIn then
    Exit;

  FNetworkTitleChanged := Command;

  if (FNetworkTitleChanged.StreamName <> '') and (FNetworkTitleChanged.Title <> '') and (FNetworkTitleChanged.CurrentURL <> '') then
    if Assigned(FOnNetworkTitleChangedReceived) then
      Sync(FOnNetworkTitleChangedReceived);
end;

procedure THomeThread.DoReceivedCommand(ID: Cardinal; CommandHeader: TCommandHeader; Command: TCommand);
var
  HandShake: TCommandHandshakeResponse absolute Command;
  LogIn: TCommandLogInResponse absolute Command;
  LogOut: TCommandLogOutResponse absolute Command;
  GetServerData: TCommandGetServerDataResponse absolute Command;
  NetworkTitleChanged: TCommandNetworkTitleChangedResponse absolute Command;
  ServerInfo: TCommandServerInfoResponse absolute Command;
  Error: TCommandMessageResponse absolute Command;
begin
  inherited;

  case CommandHeader.CommandType of
    ctHandshakeResponse:
      DoHandshakeReceived(CommandHeader, HandShake);
    ctLoginResponse:
      DoLogInReceived(CommandHeader, LogIn);
    ctLogout: ;
    ctLogoutResponse:
      DoLogOutReceived(CommandHeader, LogOut);
    ctGetServerDataResponse:
      DoServerDataReceived(CommandHeader, GetServerData);
    ctNetworkTitleChangedResponse:
      DoNetworkTitleChanged(CommandHeader, NetworkTitleChanged);
    ctServerInfoResponse:
      DoServerInfoReceived(CommandHeader, ServerInfo);
    ctMessageResponse:
      DoMessageReceived(CommandHeader, Error);
  end;
end;

procedure THomeThread.DoServerDataReceived(CommandHeader: TCommandHeader;
  Command: TCommandGetServerDataResponse);
var
  i: Integer;
  Count: Cardinal;
  Stream: TExtendedStream;
  StreamEntry, StreamEntry2: TStreamBrowserEntry;
  Genre: TGenre;

  Genres: TGenreList;
  Charts: TChartList;
  Streams: TStreamBrowserList;
begin
  Stream := TExtendedStream(Command.Stream);

  Genres := TGenreList.Create;
  Charts := TChartList.Create;
  Streams := TStreamBrowserList.Create;
  try
    // Genres laden
    Stream.Read(Count);
    for i := 0 to Count - 1 do
      Genres.Add(TGenre.LoadFromHome(Stream, CommandHeader.Version));

    // Streams laden und OwnRating synchronisieren
    Stream.Read(Count);
    for i := 0 to Count - 1 do
    begin
      StreamEntry := TStreamBrowserEntry.LoadFromHome(Stream, CommandHeader.Version);
      for StreamEntry2 in FLists.BrowserList do
        if StreamEntry.ID = StreamEntry2.ID then
        begin
          StreamEntry.OwnRating := StreamEntry2.OwnRating;
          Break;
        end;
      Streams.Add(StreamEntry);
    end;
    Streams.CreateDict;

    // Charts laden
    Stream.Read(Count);
    for i := 0 to Count - 1 do
      Charts.Add(TChartEntry.LoadFromHome(Stream, nil, CommandHeader.Version, Streams));

    // Wenn alles erfolgreich geladen wurde alte Listen leeren.
    // Falls hier jetzt eine Exception kommt wird es bitter...
    for Genre in FLists.GenreList do
      Genre.Free;
    FLists.GenreList.Clear;
    for StreamEntry in FLists.BrowserList do
      StreamEntry.Free;
    FLists.BrowserList.Clear;
    for i := 0 to FLists.ChartList.Count - 1 do
      FLists.ChartList[i].Free;
    FLists.ChartList.Clear;

    // Der Liste alle Sachen wieder hinzuf�gen
    for Genre in Genres do
      FLists.GenreList.Add(Genre);
    for StreamEntry in Streams do
      FLists.BrowserList.Add(StreamEntry);
    for i := 0 to Charts.Count - 1 do
      FLists.ChartList.Add(Charts[i]);
  except
    for i := 0 to Genres.Count - 1 do
      Genres[i].Free;
    for i := 0 to Charts.Count - 1 do
      Charts[i].Free;
    for i := 0 to Streams.Count - 1 do
      Streams[i].Free;

    Genres.Free;
    Charts.Free;
    Streams.Free;
  end;

  if Assigned(FOnServerDataReceived) then
    Sync(FOnServerDataReceived);
end;

procedure THomeThread.DoServerInfoReceived(CommandHeader: TCommandHeader;
  Command: TCommandServerInfoResponse);
begin
  FServerInfoClientCount := Command.ClientCount;
  FServerInfoRecordingCount := Command.RecordingCount;

  if Assigned(FOnServerInfoReceived) then
    Sync(FOnServerInfoReceived);
end;

{ THomeCommunication }

procedure THomeCommunication.HomeThreadBytesTransferred(Sender: TObject;
  Direction: TTransferDirection; CommandID: Cardinal; CommandHeader: TCommandHeader;
  Transferred: UInt64);
begin
  if Assigned(FOnBytesTransferred) then
    FOnBytesTransferred(Sender, Direction, CommandID, CommandHeader, Transferred);
end;

constructor THomeCommunication.Create(Lists: TDataLists);
begin
  inherited Create;

  FLists := Lists;
  FTitleNotificationsSet := False;
end;

destructor THomeCommunication.Destroy;
begin

  inherited;
end;

procedure THomeCommunication.SendLogIn(User, Pass: string);
begin
  if not FConnected then
    Exit;

  FThread.SendCommand(TCommandLogIn.Create(User, Pass));
end;

procedure THomeCommunication.SendLogOut;
begin
  if not FConnected then
    Exit;

  FThread.SendCommand(TCommandLogOut.Create)
end;

procedure THomeCommunication.SendSetSettings(TitleNotifications: Boolean);
begin
  if not FConnected then
    Exit;

  FNotifyTitleChanges := TitleNotifications;

  FThread.SendCommand(TCommandSetSettings.Create(TitleNotifications));

  if Assigned(FOnTitleNotificationsChanged) then
    FOnTitleNotificationsChanged(Self);
end;

procedure THomeCommunication.SendSetStreamData(StreamID: Cardinal;
  Rating: Byte);
var
  Cmd: TCommandSetStreamData;
begin
  if not FConnected then
    Exit;

  Cmd := TCommandSetStreamData.Create;
  Cmd.StreamID := StreamID;
  Cmd.Rating := Rating;

  FThread.SendCommand(Cmd);
end;

procedure THomeCommunication.SendSubmitStream(URL: string);
begin
  if not FConnected then
    Exit;

  FThread.SendCommand(TCommandSubmitStream.Create(URL));
end;

procedure THomeCommunication.SendTitleChanged(StreamID: Cardinal;
  StreamName, Title, CurrentURL, URL: string; Format: TAudioTypes; Kbps: Cardinal;
  URLs: TStringList);
begin
  if not FConnected then
    Exit;

  FThread.SendCommand(TCommandTitleChanged.Create(StreamID, StreamName, Title,
    CurrentURL, URL, Format, Kbps, URLs.Text));
end;

procedure THomeCommunication.SendUpdateStats(List: TList<Cardinal>;
  RecordingCount: Cardinal);
var
  i: Integer;
  Cmd: TCommandUpdateStats;
  Stream: TExtendedStream;
begin
  if not FConnected then
    Exit;

  Cmd := TCommandUpdateStats.Create;
  Stream := TExtendedStream(Cmd.Stream);

  Stream.Write(Cardinal(List.Count));
  for i := 0 to List.Count - 1 do
  begin
    Stream.Write(List[i]);
  end;

  Stream.Write(RecordingCount);

  FThread.SendCommand(Cmd);
end;

procedure THomeCommunication.Terminate;
begin
  FOnStateChanged := nil;
  FOnTitleNotificationsChanged := nil;
  FOnBytesTransferred := nil;
  FOnHandshakeReceived := nil;
  FOnLogInReceived := nil;
  FOnLogOutReceived := nil;
  FOnStreamsReceived := nil;
  FOnChartsReceived := nil;
  FOnNetworkTitleChangedReceived := nil;
  FOnErrorReceived := nil;

  if FThread <> nil then
    FThread.Terminate;
end;

procedure THomeCommunication.SendClientStats(Auto: Boolean);
begin
  if not FConnected then
    Exit;

  if Auto then
    FThread.SendCommand(TCommandClientStats.Create(csAutoSave))
  else
    FThread.SendCommand(TCommandClientStats.Create(csSave));
end;

function THomeCommunication.SendCommand(Cmd: TCommand): Boolean;
begin
  Result := True;
  if not FConnected then
    Exit(False);

  FThread.SendCommand(Cmd);
end;

function THomeCommunication.SendGetServerData: Boolean;
begin
  Result := True;
  if not FConnected then
    Exit(False);

  FThread.SendCommand(TCommandGetServerData.Create)
end;

procedure THomeCommunication.HomeThreadConnected(Sender: TSocketThread);
begin
  inherited;

  FConnected := True;

  SendHandshake;
end;

procedure THomeCommunication.HomeThreadBeforeEnded(Sender: TSocketThread);
begin
  FConnected := False;
  FAuthenticated := False;
  FIsAdmin := False;
  FTitleNotificationsSet := False;
  FThread := nil;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure THomeCommunication.HomeThreadEnded(Sender: TSocketThread);
begin
  if THomeThread(Sender).Terminated then
    Exit;

  Connect;
end;

procedure THomeCommunication.HomeThreadErrorReceived(
  Sender: TSocketThread);
begin
  if Assigned(FOnErrorReceived) then
    FOnErrorReceived(Self, FThread.FErrorID, FThread.FErrorMsg);
end;

procedure THomeCommunication.HomeThreadHandshakeReceived(
  Sender: TSocketThread);
begin
  FDisabled := not THomeThread(Sender).FHandshakeSuccess;

  if not FDisabled then
  begin
    if AppGlobals.UserWasSetup and (AppGlobals.User <> '') and (AppGlobals.Pass <> '') then
      SendLogIn(AppGlobals.User, AppGlobals.Pass);

    FWasConnected := False;
    if Assigned(FOnStateChanged) then
      FOnStateChanged(Self);
    FWasConnected := True;
  end;

  if FDisabled then
    Sender.Terminate;

  if Assigned(FOnHandshakeReceived) then
    FOnHandshakeReceived(Self, THomeThread(Sender).FHandshakeSuccess);
end;

procedure THomeCommunication.HomeThreadLogInReceived(Sender: TSocketThread);
begin
  FAuthenticated := THomeThread(Sender).FAuthenticated;
  FIsAdmin := THomeThread(Sender).FIsAdmin;

  if Assigned(FOnLogInReceived) then
    FOnLogInReceived(Self, FAuthenticated);
end;

procedure THomeCommunication.HomeThreadLogOutReceived(Sender: TSocketThread);
begin
  FAuthenticated := THomeThread(Sender).FAuthenticated;
  FIsAdmin := THomeThread(Sender).FIsAdmin;

  if Assigned(FOnLogOutReceived) then
    FOnLogOutReceived(Self);
end;

procedure THomeCommunication.HomeThreadServerDataReceived(Sender: TSocketThread);
begin
  if Assigned(FOnStreamsReceived) then
    FOnStreamsReceived(Self);

  if Assigned(FOnChartsReceived) then
    FOnChartsReceived(Self);
end;

procedure THomeCommunication.HomeThreadServerInfoReceived(
  Sender: TSocketThread);
begin
  if Assigned(FOnServerInfoReceived) then
    FOnServerInfoReceived(Self, THomeThread(Sender).FServerInfoClientCount, THomeThread(Sender).FServerInfoRecordingCount);
end;

procedure THomeCommunication.HomeThreadNetworkTitleChangedReceived(
  Sender: TSocketThread);
begin
  if Assigned(FOnNetworkTitleChangedReceived) then
    FOnNetworkTitleChangedReceived(Self,  THomeThread(Sender).FNetworkTitleChanged.StreamID, THomeThread(Sender).FNetworkTitleChanged.StreamName,
      THomeThread(Sender).FNetworkTitleChanged.Title, THomeThread(Sender).FNetworkTitleChanged.CurrentURL,
      THomeThread(Sender).FNetworkTitleChanged.TitleRegEx, THomeThread(Sender).FNetworkTitleChanged.Format,
      THomeThread(Sender).FNetworkTitleChanged.Bitrate);
end;

procedure THomeCommunication.SendHandshake;
var
  Cmd: TCommandHandshake;
begin
  if not Connected then
    Exit;

  Cmd := TCommandHandshake.Create;
  Cmd.ID := AppGlobals.ID;
  Cmd.VersionMajor := AppGlobals.AppVersion.Major;
  Cmd.VersionMinor := AppGlobals.AppVersion.Minor;
  Cmd.VersionRevision := AppGlobals.AppVersion.Revision;
  Cmd.VersionBuild := AppGlobals.AppVersion.Build;
  Cmd.Build := AppGlobals.BuildNumber;
  Cmd.Language := AppGlobals.Language;
  Cmd.ProtoVersion := 1;

  FThread.SendCommand(Cmd);
end;

procedure THomeCommunication.Connect;
begin
  if FDisabled then
    Exit;

  if FThread <> nil then
    Exit;

  FThread := THomeThread.Create(FLists);
  FThread.OnConnected := HomeThreadConnected;
  FThread.OnEnded := HomeThreadEnded;
  FThread.OnBeforeEnded := HomeThreadBeforeEnded;
  FThread.OnBytesTransferred := HomeThreadBytesTransferred;

  FThread.OnHandshakeReceived := HomeThreadHandshakeReceived;
  FThread.OnLogInReceived := HomeThreadLogInReceived;
  FThread.OnLogOutReceived := HomeThreadLogOutReceived;
  FThread.OnServerDataReceived := HomeThreadServerDataReceived;

  FThread.OnServerInfoReceived := HomeThreadServerInfoReceived;
  FThread.OnErrorReceived := HomeThreadErrorReceived;

  FThread.OnNetworkTitleChangedReceived := HomeThreadNetworkTitleChangedReceived;

  FThread.Start;
end;

initialization
  TCommand.RegisterCommand(ctHandshakeResponse, TCommandHandshakeResponse);
  TCommand.RegisterCommand(ctLogInResponse, TCommandLogInResponse);
  TCommand.RegisterCommand(ctLogOutResponse, TCommandLogOutResponse);
  TCommand.RegisterCommand(ctGetServerDataResponse, TCommandGetServerDataResponse);
  TCommand.RegisterCommand(ctServerInfoResponse, TCommandServerInfoResponse);
  TCommand.RegisterCommand(ctMessageResponse, TCommandMessageResponse);
  TCommand.RegisterCommand(ctNetworkTitleChangedResponse, TCommandNetworkTitleChangedResponse);

  HomeComm := nil;

finalization
  HomeComm.Free;

end.
