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
program streamwriter;

uses
  MM in '..\..\common\MM.pas',
  Windows,
  Forms,
  Main in 'Main.pas' {frmStreamWriterMain},
  ClientView in 'controls\ClientView.pas',
  DataManager in 'DataManager.pas',
  Settings in 'Settings.pas' {frmSettings},
  AppData in 'AppData.pas',
  Wizard in 'Wizard.pas' {frmWizard},
  ExtendedStream in '..\..\common\ExtendedStream.pas',
  Functions in '..\..\common\Functions.pas',
  AppDataBase in '..\..\common\AppDataBase.pas',
  UpdateClient in '..\..\common\UpdateClient.pas',
  LanguageObjects in '..\..\common\LanguageObjects.pas',
  GUIFunctions in '..\..\common\GUIFunctions.pas',
  Update in '..\..\common\forms\Update.pas' {frmUpdate},
  Changelog in '..\..\common\forms\Changelog.pas' {frmChangeLog},
  LanguageIcons in '..\..\common\LanguageIcons.pas',
  MsgDlg in '..\..\common\forms\MsgDlg.pas' {frmMsgDlg},
  SettingsStorage in '..\..\common\SettingsStorage.pas',
  WizardBase in '..\..\common\forms\WizardBase.pas' {frmSetupWizard},
  AppStartup in '..\..\common\AppStartup.pas',
  ProfileSettings in '..\..\common\forms\ProfileSettings.pas' {frmProfileSettings},
  SettingsBase in '..\..\common\forms\SettingsBase.pas' {frmSettingsBase},
  Plugins in 'Plugins.pas',
  StreamBrowserView in 'controls\StreamBrowserView.pas',
  StationCombo in 'controls\StationCombo.pas',
  StreamInfoView in 'controls\StreamInfoView.pas',
  StreamDebugView in 'controls\StreamDebugView.pas',
  PluginsShared in 'PluginsShared.pas',
  Base64 in 'Base64.pas',
  DynBASS in 'audio\DynBASS.pas',
  AudioStream in 'audio\AudioStream.pas',
  ClientTab in 'controls\ClientTab.pas',
  CutTab in 'controls\CutTab.pas',
  MControls in '..\..\common\MControls.pas',
  Tabs in 'controls\Tabs.pas',
  CutView in 'controls\CutView.pas',
  SavedTab in 'controls\SavedTab.pas',
  WaveData in 'audio\WaveData.pas',
  About in '..\..\common\forms\About.pas' {frmAbout},
  CheckFilesThread in 'CheckFilesThread.pas',
  ListsTab in 'controls\ListsTab.pas',
  UpdatedInfo in '..\..\common\forms\UpdatedInfo.pas' {frmUpdatedInfo},
  SharedControls in 'controls\SharedControls.pas',
  ClientManager in 'streaming\ClientManager.pas',
  ICEClient in 'streaming\ICEClient.pas',
  ICEPlayer in 'streaming\ICEPlayer.pas',
  ICEStream in 'streaming\ICEStream.pas',
  ICEThread in 'streaming\ICEThread.pas',
  MPEG in 'audio\MPEG.pas',
  CommunityLogin in 'CommunityLogin.pas' {frmCommunityLogin},
  Commands in '..\..\common\sockets\Commands.pas',
  Communication in '..\..\common\sockets\Communication.pas',
  Protocol in '..\..\common\sockets\Protocol.pas',
  HTTPStream in '..\..\common\sockets\HTTPStream.pas',
  HTTPThread in '..\..\common\sockets\HTTPThread.pas',
  Sockets in '..\..\common\sockets\Sockets.pas',
  Int32Protocol in '..\..\common\sockets\Int32Protocol.pas',
  HomeCommunication in 'HomeCommunication.pas';

{$SetPEOptFlags $0140}

{$R *.res}
{$R res\language.res}
{$R res\icons.res}
{$R res\bass.res}
{$R ..\..\common\res\language.res}
{$R ..\..\common\res\lang_icons.res}
{$R ..\..\common\res\icons.res}

var
  frmStreamWriterMain: TfrmStreamWriterMain;
begin
  Application.Title := AppGlobals.AppName;
  Application.Icon.Handle := LoadIcon(HInstance, 'A');

  Bass := TBassLoader.Create;
  if not Bass.InitializeBass then
  begin
    MsgBox(0, _('The BASS library or it''s AAC plugin could not be extracted/loaded. Without this library streamWriter can not record streams. Please look for help at streamWriter''s board.'), _('Error'), MB_ICONERROR);
    Bass.Free;
    Exit;
  end;

  if InitApp and AppGlobals.WasSetup then
  begin
    Application.CreateForm(TfrmStreamWriterMain, frmStreamWriterMain);
  end;

  Application.Run;
  Bass.Free;
end.
