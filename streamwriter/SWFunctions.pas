{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2019 Alexander Nottelmann

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

unit SWFunctions;

interface

uses
  Windows, SysUtils, AudioFunctions, Functions, PerlRegEx, Classes,
  Generics.Defaults, Generics.Collections, Constants;

function GetAutoTuneInMinKbps(AudioType: TAudioTypes; Idx: Integer): Cardinal;
function FixPatternFilename(Filename: string): string;
function SecureSWURLToInsecure(URL: string): string;
function ConvertPattern(OldPattern: string): string;
function GetBestRegEx(Title: string; RegExps: TStringList): string;

implementation

function GetAutoTuneInMinKbps(AudioType: TAudioTypes; Idx: Integer): Cardinal;
begin
  Result := 0;
  case AudioType of
    atMPEG:
      begin
        case Idx of
          0: Result := 192;
          1: Result := 128;
        end;
      end;
    atAAC:
      begin
        case Idx of
          0: Result := 96;
          1: Result := 48;
        end;
      end;
  end;
end;

function FixPatternFilename(Filename: string): string;
var
  i: Integer;
begin
  Result := Filename;

  // Remove subsequent \
  i := 1;
  if Length(Result) > 0 then
    while True do
    begin
      if i = Length(Result) then
        Break;
      if Result[i] = '\' then
        if Result[i + 1] = '\' then
        begin
          Result := Copy(Result, 1, i) + Copy(Result, i + 2, Length(Result) - i);
          Continue;
        end;
      Inc(i);
    end;

  // Replace invalid characters for filenames
  Result := StringReplace(Result, '/', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, ':', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '*', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '"', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '?', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '<', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '>', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '|', ' ', [rfReplaceAll]);

  // Make sure there is no \ at the beginning/ending
  if Length(Result) > 0 then
    if Result[1] = '\' then
      Result := Copy(Result, 2, Length(Result) - 1);
  if Length(Result) > 0 then
    if Result[Length(Result)] = '\' then
      Result := Copy(Result, 1, Length(Result) - 1);
end;

function SecureSWURLToInsecure(URL: string): string;
var
  Res: TParseURLRes;
begin
  Result := URL;
  Res := ParseURL(URL);
  if Res.Success and Res.Secure and (Pos('streamwriter.', LowerCase(Res.Host)) > 0) then
    Result := 'http://' + Res.Host + ':80' + Res.Data;
end;

function ConvertPattern(OldPattern: string): string;
var
  i: Integer;
  C: Char;
  Patterns: string;
  Arr: TPatternReplaceArray;
begin
  Patterns := 'fatlusndi';
  SetLength(Arr, Length(Patterns));
  for i := 0 to Length(Patterns) - 1 do
  begin
    Arr[i].C := Patterns[i + 1];
    C := Arr[i].C[1];
    case C of
      'f':
        Arr[i].Replace := '%filename%';
      'a':
        Arr[i].Replace := '%artist%';
      't':
        Arr[i].Replace := '%title%';
      'l':
        Arr[i].Replace := '%album%';
      'u':
        Arr[i].Replace := '%streamtitle%';
      's':
        Arr[i].Replace := '%streamname%';
      'n':
        Arr[i].Replace := '%number%';
      'd':
        Arr[i].Replace := '%day%.%month%.%year%';
      'i':
        Arr[i].Replace := '%hour%.%minute%.%second%';
    end;
  end;

  Result := PatternReplace(OldPattern, Arr);
end;

function GetBestRegEx(Title: string; RegExps: TStringList): string;
type
  TRegExData = record
    RegEx: string;
    BadWeight: Integer;
  end;
var
  i, n: Integer;
  R: TPerlRegEx;
  MArtist, MTitle, MAlbum, DefaultRegEx: string;
  RED: TRegExData;
  REDs: TList<TRegExData>;
const
  BadChars: array[0..3] of string = (':', '-', '|', '*');
begin
  Result := DefaultRegEx;

  REDs := TList<TRegExData>.Create;
  try
    for i := 0 to RegExps.Count - 1 do
    begin
      RED.RegEx := RegExps[i];
      RED.BadWeight := 0;
      if RED.RegEx = DEFAULT_TITLE_REGEXP then
        RED.BadWeight := 1;

      MArtist := '';
      MTitle := '';
      MAlbum := '';

      R := TPerlRegEx.Create;
      try
        R.Options := R.Options + [preCaseLess];
        R.Subject := Title;
        R.RegEx := RED.RegEx;
        try
          if R.Match then
          begin
            try
              if R.NamedGroup('a') > 0 then
              begin
                MArtist := Trim(R.Groups[R.NamedGroup('a')]);
                for n := 0 to High(BadChars) do
                  if Pos(BadChars[n], MArtist) > 0 then
                    RED.BadWeight := RED.BadWeight + 2;
                if ContainsRegEx('(\d{2})', MArtist) then
                  RED.BadWeight := RED.BadWeight + 2;
              end
                else RED.BadWeight := RED.BadWeight + 3;
            except end;
            try
              if R.NamedGroup('t') > 0 then
              begin
                MTitle := Trim(R.Groups[R.NamedGroup('t')]);
                for n := 0 to High(BadChars) do
                  if Pos(BadChars[n], MTitle) > 0 then
                    RED.BadWeight := RED.BadWeight + 2;
                if ContainsRegEx('(\d{2})', MTitle) then
                  RED.BadWeight := RED.BadWeight + 2;
              end
                else RED.BadWeight := RED.BadWeight + 3;
            except end;
            try
              if R.NamedGroup('l') > 0 then
              begin
                RED.BadWeight := RED.BadWeight - 6;
                MAlbum := Trim(R.Groups[R.NamedGroup('l')]);
                for n := 0 to High(BadChars) do
                  if Pos(BadChars[n], MAlbum) > 0 then
                    RED.BadWeight := RED.BadWeight + 2;
              end;
            except end;

            if MAlbum = '' then
              RED.BadWeight := RED.BadWeight + 10;
          end else
            RED.BadWeight := RED.BadWeight + 50;

          REDs.Add(RED);
        except end;
      finally
        R.Free;
      end;
    end;

    REDs.Sort(TComparer<TRegExData>.Construct(
      function (const L, R: TRegExData): integer
      begin
        Result := CmpInt(L.BadWeight, R.BadWeight);
      end
    ));

    if REDs.Count > 0 then
      Result := REDs[0].RegEx;
  finally
    REDs.Free;
  end;
end;

end.
