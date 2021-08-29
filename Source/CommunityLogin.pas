{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2021 Alexander Nottelmann

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

unit CommunityLogin;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Buttons, LanguageObjects, ShellAPI, Functions,
  AppData, ComCtrls, HomeCommunication, Logging, MControls, SharedData,
  Images;

type

  { TfrmCommunityLogin }

  TfrmCommunityLogin = class(TForm)
    pnlHeader: TPanel;
    Shape1: TShape;
    lblTop: TLabel;
    pnlNav: TPanel;
    Bevel2: TBevel;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    pnlConnecting: TPanel;
    lblConnecting: TLabel;
    prgConnecting: TProgressBar;
    pnlConnect: TPanel;
    txtPassword: TLabeledEdit;
    txtUsername: TLabeledEdit;
    txtText: TMemo;
    lblSignup: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure lblSignupClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    procedure ShowConnecting(Show: Boolean);
  protected
    procedure DoClose(var Action: TCloseAction); override;
  public
    procedure HomeCommLogIn(Sender: TObject; Success: Boolean);
  end;

implementation

{$R *.lfm}

procedure TfrmCommunityLogin.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmCommunityLogin.btnOKClick(Sender: TObject);
begin
  if (Trim(txtUsername.Text) = '') or (Trim(txtPassword.Text) = '') then
  begin
    MsgBox(Handle, _('You have to enter your username and your password.'), _('Info'), MB_ICONINFORMATION);
    Exit;
  end;

  if not HomeComm.CommunicationEstablished then
  begin
    MsgBox(Handle, _('streamWriter is not connected to the server.'#13#10'Please make sure your internet connection is up.'), _('Info'), MB_ICONINFORMATION);
    Exit;
  end;

  ShowConnecting(True);

  HomeComm.SendLogIn(Trim(txtUsername.Text), Trim(txtPassword.Text));
end;

procedure TfrmCommunityLogin.DoClose(var Action: TCloseAction);
begin
  if AppGlobals.UserWasSetup then
    Action := caFree
  else
  begin
    Action := caFree;
    AppGlobals.UserWasSetup := True;
    AppGlobals.User := '';
    AppGlobals.Pass := '';
  end;

  if Action = caFree then
    inherited;
end;

procedure TfrmCommunityLogin.FormCreate(Sender: TObject);
begin
  pnlConnecting.BevelOuter := bvNone;
  pnlConnect.BevelOuter := bvNone;
  pnlConnecting.Align := alClient;
  pnlConnect.Align := alClient;

  txtText.Text := _('Logging in to the streamWriter community gives you some more options, for example setting ratings for streams.'#13#10 +
                    'More community features may get introduced in the future. If you don''t have an account yet, click the link below to signup for free.');

  txtUsername.Text := AppGlobals.User;
  txtPassword.Text := AppGlobals.Pass;

  modSharedData.imgImages.GetIcon(TImages.USER, Icon);
end;

procedure TfrmCommunityLogin.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = 27 then
  begin
    Key := 0;
    Close;
  end;
end;

procedure TfrmCommunityLogin.FormShow(Sender: TObject);
begin
  Language.Translate(Self);

  txtUsername.ApplyFocus;
  ShowConnecting(False);
end;

procedure TfrmCommunityLogin.HomeCommLogIn(Sender: TObject; Success: Boolean);
begin
  if (not HomeComm.CommunicationEstablished) and (pnlConnecting.Visible) then
  begin
    ShowConnecting(False);
    MsgBox(Handle, _('The connection to the server was closed while authenticating.'#13#10'Please try again later.'), _('Error'), MB_ICONERROR);
  end;

  if HomeComm.CommunicationEstablished and pnlConnecting.Visible then
  begin
    ShowConnecting(False);

    if Success then
    begin
      if not AppGlobals.UserWasSetup then
        MsgBox(Handle, _('You are now logged in.'#13#10'Your credentials will be saved and streamWriter will try to login automatically next time. You can logoff by using the corresponding item in the main menu.'), _('Info'), MB_ICONINFORMATION);

      AppGlobals.User := txtUsername.Text;
      AppGlobals.Pass := txtPassword.Text;
      AppGlobals.UserWasSetup := True;

      Close;
    end else
    begin
      MsgBox(Handle, _('You have entered an unknown username or a wrong password.'#13#10'Please try again.'), _('Error'), MB_ICONERROR);
    end;
  end;
end;

procedure TfrmCommunityLogin.lblSignupClick(Sender: TObject);
begin
  ShellExecuteW(0, 'open', PWideChar(UnicodeString('https://streamwriter.org/benutzer/anmelden/')), '', '', 1);
end;

procedure TfrmCommunityLogin.ShowConnecting(Show: Boolean);
begin
  if Show then
    prgConnecting.Style := pbstMarquee
  else
  begin
    prgConnecting.Style := pbstNormal;
    prgConnecting.Position := 0;
  end;

  pnlConnect.Visible := not Show;
  pnlConnecting.Visible := Show;

  btnOK.Enabled := not Show;
end;

end.
