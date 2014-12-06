{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2014 Alexander Nottelmann

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

{ Unit TypeDefs }
unit TypeDefs;

interface

uses
  Windows, SysUtils, Classes;

type
  // An array of integer.........
  TIntArray = array of Integer;
  TCardinalArray = array of Cardinal;

  TStringEvent = procedure(Sender: TObject; Data: string) of object;

  // TODO: TDebugTypes nach TLogTypes umbenennen
  // TODO: das "s" am ende der typnamen wegmachen. sind doch keine sets...
  TDebugTypes = (dtSocket, dtMessage, dtSong, dtError, dtSaved, dtPostProcess, dtSchedule); // TODO: wo wird das benutzt? ist das nur f�r das icon?
  TDebugLevels = (dlNormal, dlDebug);

  TLogSource = (lsGeneral, lsAutomatic, lsStream);
  TLogLevel = (llDebug, llError, llInfo); // TODO: wird noch nicht �berall ordentlich benutzt..

  // Defines all possible types of lists
  TListType = (ltSave, ltIgnore, ltAutoDetermine);

  // Do not change the values' order since the enum is used when saving settings
  TStreamOpenActions = (oaStart, oaPlay, oaPlayExternal, oaAdd, oaOpenWebsite, oaBlacklist,
    oaCopy, oaSave, oaSetData, oaRefresh, oaRate1, oaRate2, oaRate3, oaRate4,
    oaRate5, oaNone);

  TStartStreamingInfo = record
  public
    ID, Bitrate: Cardinal;
    Name, URL: string;
    RegExes: TStringList;
    IgnoreTitles: TStringList;
    constructor Create(ID, Bitrate: Cardinal; Name, URL: string; RegExes, IgnoreTitles: TStringList);
  end;
  TStartStreamingInfoArray = array of TStartStreamingInfo;

  TWishlistTitleInfo = record
  public
    Hash: Cardinal;
    Title: string;
    IsArtist: Boolean;
    constructor Create(Hash: Cardinal; Title: string; IsArtist: Boolean);
  end;
  TWishlistTitleInfoArray = array of TWishlistTitleInfo;

implementation

{ TStartStreamingInfo }

constructor TStartStreamingInfo.Create(ID, Bitrate: Cardinal; Name, URL: string;
  RegExes, IgnoreTitles: TStringList);
begin
  Self.ID := ID;
  Self.Bitrate := Bitrate;
  Self.Name := Name;
  Self.URL := Trim(URL);
  Self.RegExes := RegExes;
  Self.IgnoreTitles := IgnoreTitles;
end;

{ TWishlistTitleInfo }

constructor TWishlistTitleInfo.Create(Hash: Cardinal; Title: string; IsArtist: Boolean);
begin
  Self.Hash := Hash;
  Self.Title := Title;
  Self.IsArtist := IsArtist;
end;

end.
