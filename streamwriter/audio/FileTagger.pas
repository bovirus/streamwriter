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
unit FileTagger;

interface

uses
  Windows, SysUtils, Classes, AudioGenie, AddonAudioGenie, SyncObjs, Graphics,
  JPEG, PngImage, Math, Base64;

type
  TTagData = class
  private
    FArtist, FTitle, FAlbum, FComment, FTrackNumber: string;
    FCoverImage: TBitmap;
  public
    constructor Create;
    destructor Destroy; override;
    function Copy: TTagData;

    property Artist: string read FArtist write FArtist;
    property Title: string read FTitle write FTitle;
    property Album: string read FAlbum write FAlbum;
    property Comment: string read FComment write FComment;
    property TrackNumber: string read FTrackNumber write FTrackNumber;
    property CoverImage: TBitmap read FCoverImage;
  end;

  TFileTagger = class
  private
    FAG: TAudioGenie3;
    FFilename: string;
    FAudioType: TAudioFormatID;
    FTag: TTagData;

    function FindGraphicClass(const Buffer; const BufferSize: Int64;
      out GraphicClass: TGraphicClass): Boolean;
    procedure ResizeBitmap(var Bitmap: TBitmap; MaxSize: Integer);
    procedure ReadCover(AG: TAudioGenie3);
  public
    constructor Create;
    destructor Destroy; override;

    function Read(Filename: string): Boolean;
    function Write(Filename: string): Boolean;

    property Filename: string read FFilename;
    property Tag: TTagData read FTag;
    {
    property Artist: string read FArtist write FArtist;
    property Title: string read FTitle write FTitle;
    property Album: string read FAlbum write FAlbum;
    property Comment: string read FComment write FComment;
    property TrackNumber: string read FTrackNumber write FTrackNumber;
    property CoverImage: TBitmap read FCoverImage;
    }
  end;

implementation

uses
  AppData;

var
  FileTaggerLock: TCriticalSection;

{ TFileTagger }

constructor TFileTagger.Create;
begin
  inherited;

  FTag := TTagData.Create;
end;

destructor TFileTagger.Destroy;
begin
  FTag.Free;

  inherited;
end;

function TFileTagger.FindGraphicClass(const Buffer; const BufferSize: Int64;
  out GraphicClass: TGraphicClass): Boolean;
var
  LongWords: array[Byte] of LongWord absolute Buffer;
  Words: array[Byte] of Word absolute Buffer;
begin
  GraphicClass := nil;

  if BufferSize < 44 then
    Exit(False);

  if Words[0] = $D8FF then
    GraphicClass := TJPEGImage
  else if Int64(Buffer) = $A1A0A0D474E5089 then
    GraphicClass := TPNGImage;

  Result := (GraphicClass <> nil);
end;

procedure TFileTagger.ResizeBitmap(var Bitmap: TBitmap; MaxSize: Integer);
var
  MinSize, FW, FH: Integer;
  Res: TBitmap;
begin
  begin
    if Bitmap.Width >= Bitmap.Height then
    begin
      FW := MaxSize;
      FH := Trunc((Bitmap.Height / Bitmap.Width) * MaxSize);
    end else
    begin
      FH := MaxSize;
      FW := Trunc((Bitmap.Width / Bitmap.Height) * MaxSize);
    end;

    Res := TBitmap.Create;
    Res.Width := FW;
    Res.Height := FH;
    Res.Canvas.StretchDraw(Rect(0, 0, FW, FH), Bitmap);

    Bitmap.Free;
    Bitmap := Res;
  end;
end;

function Swap32(Data: Integer): Integer; assembler;
asm
  BSWAP eax
end;

procedure TFileTagger.ReadCover(AG: TAudioGenie3);
var
  PicFrameCount: SmallInt;
  Mem: Pointer;
  PicSize, Len: Integer;
  MS: TMemoryStream;
  GraphicClass: TGraphicClass;
  Graphic: TGraphic;
  Keys: string;
  ImageData: AnsiString;
  x: Cardinal;
  b: byte;
begin
  Graphic := nil;

  case FAudioType of
    MPEG:
      begin
        PicFrameCount := AG.ID3V2GetFrameCountW(ID3F_APIC);
        if PicFrameCount > 0 then
        begin
          PicSize := AG.ID3V2GetPictureSizeW(PicFrameCount);
          if (PicSize > 0) and (PicSize < 1000000) then
          begin
            Mem := AllocMem(PicSize);
            if Mem <> nil then
            begin
              if AG.ID3V2GetPictureArrayW(Mem, PicSize, PicFrameCount) > 0 then
              begin
                MS := TMemoryStream.Create;
                try
                  MS.Write(Mem^, PicSize);
                  MS.Position := 0;

                  if FindGraphicClass(MS.Memory^, MS.Size, GraphicClass) then
                  begin
                    Graphic := GraphicClass.Create;
                    Graphic.LoadFromStream(MS);
                  end;
                finally
                  MS.Free;
                end;
              end;
              FreeMem(Mem);
            end;
          end;
        end;
      end;
    OGGVORBIS:
      begin
        Keys := AG.OGGGetItemKeysW;
        if Pos('METADATA_BLOCK_PICTURE', Keys) > 0 then
        begin
          ImageData := AG.OGGUserItemW['METADATA_BLOCK_PICTURE'];
          if (Length(ImageData) > 0) and (Length(ImageData) < 1000000) then
          begin
            ImageData := Base64.Decode(ImageData);

            MS := TMemoryStream.Create;
            try
              MS.Write(ImageData[1], Length(ImageData));

              // Siehe http://flac.sourceforge.net/format.html#metadata_block_picture
              MS.Seek(4, soFromBeginning);

              MS.Read(Len, SizeOf(Len));
              Len := Swap32(Len);
              MS.Seek(Len, soFromCurrent);

              MS.Read(Len, SizeOf(Len));
              Len := Swap32(Len);
              MS.Seek(Len, soFromCurrent);

              MS.Seek(20, soFromCurrent);

              if FindGraphicClass(Pointer(Int64(MS.Memory) + MS.Position)^, MS.Size, GraphicClass) then
              begin
                Graphic := GraphicClass.Create;
                Graphic.LoadFromStream(MS);
              end;
            finally
              MS.Free;
            end;
          end;
        end;
      end;
    MP4M4A:
      begin
        // ...
      end;
  end;

  if Graphic <> nil then
  begin
    try
      FTag.FCoverImage := TBitmap.Create;
      FTag.FCoverImage.Assign(Graphic);

      // TODO: das geh�rt in gui, nicht hier hin.
      //ResizeBitmap(FCoverImage, MaxCoverWidth);
    finally
      Graphic.Free;
    end;
  end;
end;

function TFileTagger.Read(Filename: string): Boolean;
var
  AG: TAudioGenie3;
begin
  Result := False;
  FFilename := '';

  if not TAddonAudioGenie(AppGlobals.AddonManager.Find(TAddonAudioGenie)).FilesExtracted then
    Exit;

  FFilename := Filename;

  FileTaggerLock.Enter;
  try
    AG := TAudioGenie3.Create(TAddonAudioGenie(AppGlobals.AddonManager.Find(TAddonAudioGenie)).DLLPath);
    try
      FAudioType := AG.AUDIOAnalyzeFileW(Filename);
      if FAudioType <> UNKNOWN then
      begin
        FTag.FArtist := AG.AUDIOArtistW;
        FTag.FTitle := AG.AUDIOTitleW;
        FTag.FAlbum := AG.AUDIOAlbumW;
        FTag.FComment := AG.AUDIOCommentW;
        FTag.FTrackNumber := AG.AUDIOTrackW;

        ReadCover(AG);

        Result := True;
      end;
    finally
      AG.Free;
    end;
  finally
    FileTaggerLock.Leave;
  end;
end;

function TFileTagger.Write(Filename: string): Boolean;
var
  AG: TAudioGenie3;
begin
  Result := False;

  if not TAddonAudioGenie(AppGlobals.AddonManager.Find(TAddonAudioGenie)).FilesExtracted then
    Exit;

  FileTaggerLock.Enter;
  try
    AG := TAudioGenie3.Create(TAddonAudioGenie(AppGlobals.AddonManager.Find(TAddonAudioGenie)).DLLPath);
    try
      if AG.AUDIOAnalyzeFileW(Filename) <> UNKNOWN then
      begin
        AG.AUDIOArtistW := FTag.FArtist;
        AG.AUDIOTitleW := FTag.FTitle;
        AG.AUDIOAlbumW := FTag.FAlbum;
        AG.AUDIOCommentW := FTag.FComment;
        AG.AUDIOTrackW := FTag.FTrackNumber;

        if AG.AUDIOSaveChangesW then
          Result := True;
      end;
    finally
      AG.Free;
    end;
  finally
    FileTaggerLock.Leave;
  end;
end;

{ TTagData }

function TTagData.Copy: TTagData;
begin
  Result := TTagData.Create;
  Result.FArtist := FArtist;
  Result.FTitle := FTitle;
  Result.FAlbum := FAlbum;
  Result.FComment := FComment;
  Result.FTrackNumber := FTrackNumber;

  if FCoverImage <> nil then
  begin
    Result.FCoverImage := TBitmap.Create;
    Result.FCoverImage.Assign(FCoverImage);
  end;
end;

constructor TTagData.Create;
begin
  inherited;

end;

destructor TTagData.Destroy;
begin
  if FCoverImage <> nil then
    FCoverImage.Free;

  inherited;
end;

initialization
  FileTaggerLock := TCriticalSection.Create;

finalization
  FileTaggerLock.Free;

end.
