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
unit ClientView;

interface

uses
  Windows, SysUtils, Classes, Messages, ComCtrls, ActiveX, Controls, Buttons,
  StdCtrls, Menus, ImgList, Math, ICEClient, VirtualTrees, LanguageObjects,
  Graphics, DragDrop, DragDropFile, Functions, AppData, Tabs, DropComboTarget,
  DropSource, ShlObj, ComObj, ShellAPI, DataManager;

type
  TAccessCanvas = class(TCanvas);

  TMClientView = class;

  TClientArray = array of TICEClient;

  TNodeTypes = (ntCategory, ntClient, ntAll);

  TClientNodeData = record
    Client: TICEClient;
    Category: TListCategory;
  end;
  PClientNodeData = ^TClientNodeData;

  TEntryTypes = (etStream, {etRelay,} etFile);

  TNodeDataArray = array of PClientNodeData;

  TStartStreamingEvent = procedure(Sender: TObject; URL: string; Node: PVirtualNode; Mode: TVTNodeAttachMode) of object;

  TMClientView = class(TVirtualStringTree)
  private
    FPopupMenu: TPopupMenu;
    FDragSource: TDropFileSource;
    FDragNodes: TNodeArray;

    FInitialSorted: Boolean;
    FSortColumn: Integer;
    FSortDirection: VirtualTrees.TSortDirection;

    FColName: TVirtualTreeColumn;
    FColTitle: TVirtualTreeColumn;
    FColRcvd: TVirtualTreeColumn;
    FColSongs: TVirtualTreeColumn;
    FColSpeed: TVirtualTreeColumn;
    FColStatus: TVirtualTreeColumn;

    FOnStartStreaming: TStartStreamingEvent;

    procedure FitColumns;
  protected
    procedure DoGetText(Node: PVirtualNode; Column: TColumnIndex;
      TextType: TVSTTextType; var Text: UnicodeString); override;
    function DoGetImageIndex(Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
      var Ghosted: Boolean; var Index: Integer): TCustomImageList; override;
    procedure DoFreeNode(Node: PVirtualNode); override;
    procedure DoDragging(P: TPoint); override;
    function DoGetNodeTooltip(Node: PVirtualNode; Column: TColumnIndex; var LineBreakStyle: TVTTooltipLineBreakStyle): UnicodeString; override;
    procedure DoHeaderClick(HitInfo: TVTHeaderHitInfo); override;
    function DoCompare(Node1, Node2: PVirtualNode; Column: TColumnIndex): Integer; override;
    function DoIncrementalSearch(Node: PVirtualNode;
      const Text: string): Integer; override;
    procedure DoDragDrop(Source: TObject; DataObject: IDataObject; Formats: TFormatArray; Shift: TShiftState; Pt: TPoint;
      var Effect: Integer; Mode: TDropMode); override;
    function DoDragOver(Source: TObject; Shift: TShiftState; State: TDragState; Pt: TPoint; Mode: TDropMode;
      var Effect: Integer): Boolean; override;
    procedure DoCanEdit(Node: PVirtualNode; Column: TColumnIndex; var Allowed: Boolean); override;
    function DoEndEdit: Boolean; override;
    procedure DoNewText(Node: PVirtualNode; Column: TColumnIndex; Text: UnicodeString); override;
  public
    constructor Create(AOwner: TComponent; PopupMenu: TPopupMenu); reintroduce;
    destructor Destroy; override;

    function AddClient(Client: TICEClient): PVirtualNode;
    function RefreshClient(Client: TICEClient): Boolean;
    function GetClientNodeData(Client: TICEClient): PClientNodeData;
    function GetClientNode(Client: TICEClient): PVirtualNode;
    function GetCategoryNode(Idx: Integer): PVirtualNode;
    procedure RemoveClient(Client: TICEClient);
    procedure SortItems;
    function AddCategory(Category: TListCategory): PVirtualNode; overload;
    function AddCategory: PVirtualNode; overload;

    function GetNodes(NodeTypes: TNodeTypes; SelectedOnly: Boolean): TNodeArray;
    function NodesToData(Nodes: TNodeArray): TNodeDataArray;
    function NodesToClients(Nodes: TNodeArray): TClientArray;
    function GetEntries(T: TEntryTypes): TPlaylistEntryArray;

    property OnStartStreaming: TStartStreamingEvent read FOnStartStreaming write FOnStartStreaming;
  end;

implementation

{ TMStreamView }

function TMClientView.AddCategory(Category: TListCategory): PVirtualNode;
var
  Node: PVirtualNode;
  NodeData: PClientNodeData;
begin
  Node := AddChild(nil);
  NodeData := GetNodeData(Node);
  NodeData.Client := nil;
  NodeData.Category := Category;
  Result := Node;
end;

function TMClientView.AddCategory: PVirtualNode;
var
  Node: PVirtualNode;
  NodeData: PClientNodeData;
begin
  Node := AddChild(nil);
  NodeData := GetNodeData(Node);
  NodeData.Client := nil;
  NodeData.Category := TListCategory.Create(_('New category'), 0);
  EditNode(Node, 0);
  Result := Node;
end;

function TMClientView.AddClient(Client: TICEClient): PVirtualNode;
var
  Node: PVirtualNode;
  NodeData: PClientNodeData;
begin
  Node := AddChild(nil);
  NodeData := GetNodeData(Node);
  NodeData.Client := Client;
  NodeData.Category := nil;
  Result := Node;
end;

constructor TMClientView.Create(AOwner: TComponent; PopupMenu: TPopupMenu);
begin
  inherited Create(AOwner);

  NodeDataSize := SizeOf(TClientNodeData);
  IncrementalSearch := isVisibleOnly;
  Header.Options := [hoColumnResize, hoDrag, hoShowSortGlyphs, hoVisible];
  TreeOptions.SelectionOptions := [toMultiSelect, toRightClickSelect, toFullRowSelect];
  TreeOptions.AutoOptions := [toAutoScrollOnExpand];
  TreeOptions.PaintOptions := [toThemeAware, toHideFocusRect, toShowDropmark];
  TreeOptions.MiscOptions := TreeOptions.MiscOptions + [toAcceptOLEDrop, toEditable];
  Header.Options := Header.Options + [hoAutoResize];
  Header.Options := Header.Options - [hoDrag];
  Header.AutoSizeIndex := 1;
  DragMode := dmAutomatic;
  ShowHint := True;
  HintMode := hmTooltip;

  FPopupMenu := PopupMenu;
  FDragSource := TDropFileSource.Create(Self);

  FSortColumn := 0;
  FSortDirection := VirtualTrees.sdAscending;

  FColName := Header.Columns.Add;
  FColName.Text := _('Name');
  FColTitle := Header.Columns.Add;
  FColTitle.Text := _('Title');
  FColRcvd := Header.Columns.Add;
  FColRcvd.Text := _('Received');
  FColSongs := Header.Columns.Add;
  FColSongs.Text := _('Songs');
  FColSpeed := Header.Columns.Add;
  FColSpeed.Text := _('Speed');
  FColStatus := Header.Columns.Add;
  FColStatus.Text := _('State');
  FitColumns;
end;

destructor TMClientView.Destroy;
begin
  FDragSource.Free;
  inherited;
end;

procedure TMClientView.DoFreeNode(Node: PVirtualNode);
begin
  inherited;
end;

function TMClientView.DoGetImageIndex(Node: PVirtualNode; Kind: TVTImageKind;
  Column: TColumnIndex; var Ghosted: Boolean;
  var Index: Integer): TCustomImageList;
var
  NodeData: PClientNodeData;
begin
  Result := inherited;

  if Kind = ikOverlay then
    Exit;
  
  NodeData := GetNodeData(Node);
  if NodeData.Client <> nil then    
    case Column of
      0:
        begin
          if NodeData.Client.Playing and NodeData.Client.Paused and NodeData.Client.Recording then
            Index := 5
          else if NodeData.Client.Playing and NodeData.Client.Recording then
            Index := 2
          else if NodeData.Client.Recording then
            Index := 0
          else if NodeData.Client.Playing and NodeData.Client.Paused then
            Index := 4
          else if NodeData.Client.Playing then
            Index := 1
          else
            Index := 3;
        end;
    end
  else if Column = 0 then         
    Index := 6;
end;

function TMClientView.DoGetNodeTooltip(Node: PVirtualNode;
  Column: TColumnIndex;
  var LineBreakStyle: TVTTooltipLineBreakStyle): UnicodeString;
var
  Text: UnicodeString;
begin
  Text := '';
  DoGetText(Node, Column, ttNormal, Text);
  Result := Text;
end;

procedure TMClientView.DoGetText(Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType; var Text: UnicodeString);
var
  NodeData: PClientNodeData;
begin
  inherited;
  Text := '';
  NodeData := PClientNodeData(GetNodeData(Node));
  if NodeData.Client <> nil then
  begin
    case Column of
      0:
        if NodeData.Client.Entry.Name = '' then
          if NodeData.Client.Entry.StartURL = '' then
            Text := _('Unknown')
          else
            Text := NodeData.Client.Entry.StartURL
        else
          Text := NodeData.Client.Entry.Name;
      1:
        if NodeData.Client.Title = '' then
          if (NodeData.Client.State = csConnected) or (NodeData.Client.State = csConnecting) then
            Text := _('Unknown')
          else
            Text := ''
        else
          Text := NodeData.Client.Title;
      2:
        Text := MakeSize(NodeData.Client.Entry.BytesReceived);
      3:
        Text := IntToStr(NodeData.Client.Entry.SongsSaved);
      4:
        Text := MakeSize(NodeData.Client.Speed) + '/s';
      5:
        case NodeData.Client.State of
          csConnecting:
            Text := _('Connecting...');
          csConnected:
            Text := _('Connected');
          csRetrying:
            Text := _('Waiting...');
          csStopped:
            Text := _('Stopped');
          csStopping:
            Text := _('Stopping...');
          csIOError:
            Text := _('Error creating file');
        end;
    end
  end else
    if Column = 0 then    
      Text := NodeData.Category.Name;
end;

procedure TMClientView.DoHeaderClick(HitInfo: TVTHeaderHitInfo);
var
  i: Integer;
  Nodes: TNodeArray;
begin
  inherited;
  if HitInfo.Button = mbLeft then
  begin
    if FSortColumn <> HitInfo.Column then
    begin
      FSortColumn := HitInfo.Column;
      if (HitInfo.Column <> 0) and (HitInfo.Column <> 1) then
        FSortDirection := sdDescending
      else
        FSortDirection := sdAscending;
    end else
    begin
      if FSortDirection = sdAscending then
        FSortDirection := sdDescending
      else
        FSortDirection := sdAscending;
    end;
    Sort(nil, HitInfo.Column, FSortDirection);
    Nodes := GetNodes(ntCategory, False);
    for i := 0 to Length(Nodes) - 1 do
      Sort(Nodes[i], FSortColumn, FSortDirection);
  end;
end;

function TMClientView.DoIncrementalSearch(Node: PVirtualNode;
  const Text: string): Integer;
var
  s, NodeText: string;
  NodeData: PClientNodeData;
begin
  Result := 0;
  S := Text;
  NodeData := GetNodeData(Node);
  if NodeData = nil then
    Exit;
  DoGetText(Node, 0, ttNormal, NodeText);
  Result := StrLIComp(PChar(s), PChar(NodeText), Min(Length(s), Length(NodeText)));
end;

procedure TMClientView.DoNewText(Node: PVirtualNode; Column: TColumnIndex;
  Text: UnicodeString);
var
  NodeData: PClientNodeData;
begin
  inherited;

  if Trim(Text) <> '' then
  begin
    NodeData := GetNodeData(Node);
    NodeData.Category.Name := Text;
  end;
end;

procedure TMClientView.FitColumns;
  function GetTextWidth(Text: string): Integer;
  var
    Canvas: TAccessCanvas;
  begin
    Canvas := TAccessCanvas.Create;
    try
      Canvas.Handle := GetDC(GetDesktopWindow);
      SelectObject(Canvas.Handle, Header.Font.Handle);
      Result := Canvas.TextWidth(Text) + 20;
      ReleaseDC(GetDesktopWindow, Canvas.Handle);
    finally
      Canvas.Free;
    end;
  end;
begin
  FColName.Width := 120;
  FColStatus.Width := 100;
  FColRcvd.Width := GetTextWidth(FColRcvd.Text);
  FColSpeed.Width := Max(GetTextWidth('11,11KB/s'), GetTextWidth(FColSpeed.Text));
  FColSongs.Width := GetTextWidth(FColSongs.Text);
end;

function TMClientView.DoDragOver(Source: TObject; Shift: TShiftState; State: TDragState; Pt: TPoint; Mode: TDropMode;
  var Effect: Integer): Boolean;
var
  i, n: Integer;
  Children: TNodeArray;
  HitNode: PVirtualNode;
begin
  Result := True;
  if Length(FDragNodes) > 0 then
  begin
    HitNode := GetNodeAt(Pt.X, Pt.Y);
    Result := True;

    // Drop darf nur erlaubt sein, wenn Ziel-Node nicht in gedraggten
    // Nodes vorkommt und Ziel-Node kein Kind von Drag-Node ist
    for i := 0 to Length(FDragNodes) - 1 do
    begin
      if HitNode = FDragNodes[i] then
      begin
        Result := False;
        Break;
      end;

      Children := GetNodes(ntClient, False);
      for n := 0 to Length(Children) - 1 do
        if (Children[n] = HitNode) and (HitNode.Parent = FDragNodes[i]) then
        begin
          Result := False;
          Exit;
        end;
    end;
    //if HitNode <> nil then
    //  HitNodeData := GetNodeData(HitNode);
    //if (HitNode = FDragNode) or (HitNode = nil) {or ((HitNode <> nil) and (HitNodeData.Client <> nil))} then
      //Result := False;
  end;
end;

function TMClientView.DoEndEdit: Boolean;
begin
  Result := inherited;
end;

function TMClientView.GetClientNodeData(Client: TICEClient): PClientNodeData;
var
  Nodes: TNodeArray;
  Node: PVirtualNode;
  NodeData: PClientNodeData;
begin
  Result := nil;
  Nodes := GetNodes(ntClient, False);
  for Node in Nodes do
  begin
    NodeData := GetNodeData(Node);
    if NodeData.Client = Client then
    begin
      Result := NodeData;
      Exit;
    end;
  end;
end;

function TMClientView.GetClientNode(Client: TICEClient): PVirtualNode;
var
  Nodes: TNodeArray;
  Node: PVirtualNode;
  NodeData: PClientNodeData;
begin
  Result := nil;
  Nodes := GetNodes(ntClient, False);
  for Node in Nodes do
  begin
    NodeData := GetNodeData(Node);
    if NodeData.Client = Client then
    begin
      Result := Node;
      Exit;
    end;
  end;
end;

function TMClientView.GetCategoryNode(Idx: Integer): PVirtualNode;
var
  Nodes: TNodeArray;
  Node: PVirtualNode;
  NodeData: PClientNodeData;
begin
  Result := nil;
  Nodes := GetNodes(ntCategory, False);
  for Node in Nodes do
  begin
    NodeData := GetNodeData(Node);
    if (NodeData.Category <> nil) and (NodeData.Category.Index = Idx) then
    begin
      Result := Node;
      Exit;
    end;
  end;
end;

function TMClientView.GetNodes(NodeTypes: TNodeTypes; SelectedOnly: Boolean): TNodeArray;
var
  Node: PVirtualNode;
  NodeData: PClientNodeData;
begin
  SetLength(Result, 0);
  Node := GetFirst;
  while Node <> nil do
  begin
    NodeData := GetNodeData(Node);

    if SelectedOnly and (not Selected[Node]) then
    begin
      Node := GetNext(Node);
      Continue;
    end;

    if ((NodeTypes = ntClient) and (NodeData.Client = nil)) or
       ((NodeTypes = ntCategory) and (NodeData.Client <> nil)) then
    begin
      Node := GetNext(Node);
      Continue;
    end;
    
    SetLength(Result, Length(Result) + 1);
    Result[Length(Result) - 1] := Node;
    Node := GetNext(Node);
  end;

{
  SetLength(Result, 0);
  if not SelectedOnly then begin
    Node := GetFirst;
    while Node <> nil do begin
      if GetNodeLevel(Node) = 0 then
      begin
        Node := GetNext(Node);
        Continue;
      end;
      SetLength(Result, Length(Result) + 1);
      Result[Length(Result) - 1] := Node;
      Node := GetNext(Node);
    end;
  end else begin
    SetLength(Result, 0);
    Nodes := GetSortedSelection(True);
    for i := 0 to Length(Nodes) - 1 do begin
      if GetNodeLevel(Node) = 0 then
        Continue;
      SetLength(Result, Length(Result) + 1);
      Result[Length(Result) - 1] := Nodes[i];
    end;
  end;
}
end;

function TMClientView.RefreshClient(Client: TICEClient): Boolean;
var
  i: Integer;
  Nodes: TNodeArray;
  NodeData: PClientNodeData;
begin
  Result := False;
  Nodes := GetNodes(ntClient, False);
  for i := 0 to Length(Nodes) - 1 do
  begin
    NodeData := GetNodeData(Nodes[i]);
    if NodeData.Client = Client then
    begin
      Result := True;
      InvalidateNode(Nodes[i]);
      Break;
    end;
  end;
end;

procedure TMClientView.RemoveClient(Client: TICEClient);
var
  i: Integer;
  Nodes: TNodeArray;
  NodeData: PClientNodeData;
begin
  Nodes := GetNodes(ntClient, False);
  for i := Length(Nodes) - 1 downto 0 do
  begin
    NodeData := GetNodeData(Nodes[i]);
    if NodeData.Client = Client then
    begin
      DeleteNode(Nodes[i]);
      Break;
    end;
  end;
end;

procedure TMClientView.SortItems;
var
  i: Integer;
  Nodes: TNodeArray;
begin
  Sort(nil, -1, sdAscending);
  Nodes := GetNodes(ntCategory, False);
  for i := 0 to Length(Nodes) - 1 do
    Sort(Nodes[i], -1, sdAscending);
  FInitialSorted := True;
end;

function TMClientView.NodesToData(Nodes: TNodeArray): TNodeDataArray;
var
  i: Integer;
  Data: PClientNodeData;
begin
  SetLength(Result, Length(Nodes));
  for i := 0 to Length(Nodes) - 1 do
  begin
    Data := GetNodeData(Nodes[i]);
    Result[i] := Data;
  end;
end;

function TMClientView.NodesToClients(Nodes: TNodeArray): TClientArray;
var
  i: Integer;
  Data: PClientNodeData;
begin
  SetLength(Result, Length(Nodes));
  for i := 0 to Length(Nodes) - 1 do
  begin
    Data := GetNodeData(Nodes[i]);
    Result[i] := Data.Client;
  end;
end;

procedure TMClientView.DoCanEdit(Node: PVirtualNode; Column: TColumnIndex;
  var Allowed: Boolean);
var
  NodeData: PClientNodeData;
begin
  inherited; 
  NodeData := GetNodeData(Node);
  Allowed := NodeData.Category <> nil;
end;

function TMClientView.DoCompare(Node1, Node2: PVirtualNode;
  Column: TColumnIndex): Integer;
  function CmpInt(a, b: Integer): Integer;
  begin
    if a > b then
      Result := 1
    else if a < b then
      Result := -1
    else
      Result := 0;
  end;
  function CmpIntR(a, b: Integer): Integer;
  begin
    if a < b then
      Result := 1
    else if a > b then
      Result := -1
    else
      Result := 0;
  end;
var
  Data1, Data2: PClientNodeData;
  I1, I2: Integer;
begin
  Result := 0;
  Data1 := GetNodeData(Node1);
  Data2 := GetNodeData(Node2);

  if (Column = -1) and (not FInitialSorted) then
  begin
    // Mit Column -1 hei�t nach Programmstart sortieren
    if Data1.Client <> nil then
      I1 := Data1.Client.Entry.Index
    else
      I1 := Data1.Category.Index;

    if Data2.Client <> nil then
      I2 := Data2.Client.Entry.Index
    else
      I2 := Data2.Category.Index;

    Result := CmpInt(I1, I2);
    Exit;
  end;

  if (Data1.Client <> nil) and (Data2.Client <> nil) then
    case Column of
      0: Result := CompareText(Data1.Client.Entry.Name, Data2.Client.Entry.Name);
      1: Result := CompareText(Data1.Client.Title, Data2.Client.Title);
      2: Result := CmpInt(Data1.Client.Entry.BytesReceived, Data2.Client.Entry.BytesReceived);
      3: Result := CmpInt(Data1.Client.Entry.SongsSaved, Data2.Client.Entry.SongsSaved);
      4: Result := CmpInt(Data1.Client.Speed, Data2.Client.Speed);
      5: Result := CmpIntR(Integer(Data1.Client.State), Integer(Data2.Client.State));
    end
  else if (Data1.Category <> nil) and (Data2.Category <> nil) then
    if Column = 0 then
      Result := CompareText(Data1.Category.Name, Data2.Category.Name);
end;

function GetFileListFromObj(const DataObj: IDataObject;
  const FileList: TStrings): Boolean;
var
  FormatEtc: TFormatEtc;
  Medium: TStgMedium;
  FileName: string;
  i, DroppedFileCount, FileNameLength: Integer;
begin
  Result := False;
  try
    FormatEtc.cfFormat := CF_HDROP;
    FormatEtc.ptd := nil;
    FormatEtc.dwAspect := DVASPECT_CONTENT;
    FormatEtc.lindex := -1;
    FormatEtc.tymed := TYMED_HGLOBAL;
    OleCheck(DataObj.GetData(FormatEtc, Medium));
    try
      try
        DroppedFileCount := DragQueryFile(Medium.hGlobal, $FFFFFFFF, nil, 0);
        for i := 0 to Pred(DroppedFileCount) do
        begin
          FileNameLength := DragQueryFile(Medium.hGlobal, i, nil, 0);
          SetLength(FileName, FileNameLength);
          DragQueryFile(Medium.hGlobal, i, PChar(FileName), FileNameLength + 1);
          FileList.Add(FileName);
        end;
      finally
        DragFinish(Medium.hGlobal);
      end;
    finally
      ReleaseStgMedium(Medium);
    end;
    Result := FileList.Count > 0;
  except end;
end;

function GetWideStringFromObj(const DataObject: IDataObject; var S: string): Boolean;
var
  FormatEtc: TFormatEtc;
  Medium: TStgMedium;
  OLEData,
  Head: PWideChar;
  Chars: Integer;
begin
  S := '';

  FormatEtc.cfFormat := CF_UNICODETEXT;
  FormatEtc.ptd := nil;
  FormatEtc.dwAspect := DVASPECT_CONTENT;
  FormatEtc.lindex := -1;
  FormatEtc.tymed := TYMED_HGLOBAL;

  if DataObject.QueryGetData(FormatEtc) = S_OK then
  begin
    if DataObject.GetData(FormatEtc, Medium) = S_OK then
    begin
      OLEData := GlobalLock(Medium.hGlobal);
      if Assigned(OLEData) then
      begin
        Chars := 0;
        Head := OLEData;
        try
          while Head^ <> #0 do
          begin
            Head := Pointer(Integer(Head) + SizeOf(WideChar));
            Inc(Chars);
          end;

          SetString(S, OLEData, Chars);
        finally
          GlobalUnlock(Medium.hGlobal);
        end;
      end;
      ReleaseStgMedium(Medium);
    end;
  end;
  Result := S <> '';
end;

procedure TMClientView.DoDragDrop(Source: TObject; DataObject: IDataObject;
  Formats: TFormatArray; Shift: TShiftState; Pt: TPoint;
  var Effect: Integer; Mode: TDropMode);
  procedure UnkillCategory(Node: PVirtualNode);
  var
    NodeData: PClientNodeData;
  begin
    if Node <> nil then
    begin
      NodeData := GetNodeData(Node);
      if NodeData.Category <> nil then
        NodeData.Category.Killed := False;
    end;
  end;
var
  Attachmode: TVTNodeAttachMode;
  Nodes: TNodeArray;
  i: Integer;
  Files: TStringList;
  HitNodeData, DragNodeData: PClientNodeData;
  DropURL: string;
  HI: THitInfo;
  R: TRect;
  RelevantWidth: Integer;
begin
  inherited;

  Nodes := nil;
  DropURL := '';
  Attachmode := amInsertAfter;
  Effect := DROPEFFECT_COPY;
  HitNodeData := nil;

  GetHitTestInfoAt(Pt.X, Pt.Y, True, HI);
  if Hi.HitNode <> nil then
  begin
    HitNodeData := GetNodeData(HI.HitNode);
    R := GetDisplayRect(HI.HitNode, 0, False);

    RelevantWidth := 6;

    if Pt.Y > R.Bottom - RelevantWidth then
      AttachMode := amInsertAfter
    else if Pt.Y < R.Top + RelevantWidth then
      AttachMode := amInsertBefore
    else
      AttachMode := amNoWhere;
  end;

  if DataObject <> nil then
  begin
    if Length(FDragNodes) > 0 then
    begin
      if (HI.HitNode <> nil) and (HitNodeData <> nil) then
      begin
        if (HitNodeData.Client = nil) and (((Attachmode = amInsertAfter) and Expanded[HI.HitNode]) or (Attachmode = amNoWhere)) then
        begin
          for i := 0 to Length(FDragNodes) - 1 do
          begin
            DragNodeData := GetNodeData(FDragNodes[i]);
            if DragNodeData.Category = nil then
              MoveTo(FDragNodes[i], HI.HitNode, amAddChildLast, False)
            else
              MoveTo(FDragNodes[i], HI.HitNode, amInsertAfter, False);
            UnkillCategory(HI.HitNode);
          end;
        end else
        begin
          if (HI.HitNode <> nil) and Expanded[HI.HitNode] and (Attachmode <> amInsertBefore) then
            Attachmode := amAddChildLast;
          if AttachMode = amNoWhere then
            AttachMode := amInsertAfter;
          for i := 0 to Length(FDragNodes) - 1 do
          begin
            DragNodeData := GetNodeData(FDragNodes[i]);
            if (DragNodeData.Category <> nil) then
              if GetNodeLevel(HI.HitNode) > 0 then
              begin
                HI.HitNode := HI.HitNode.Parent;
                Attachmode := amInsertAfter;
              end;
            MoveTo(FDragNodes[i], HI.HitNode, Attachmode, False);
            UnkillCategory(HI.HitNode);
          end;
        end;
        Exit;
      end else
        // Nodes ins "nichts" gedraggt
        Exit;
    end;

    Files := TStringList.Create;
    try
      if GetFileListFromObj(DataObject, Files) and (Files.Count > 0) then
        DropURL := Files[0];

      if DropURL = '' then
        for i := 0 to High(Formats) do
        begin
          case Formats[i] of
            CF_UNICODETEXT:
              begin
                if GetWideStringFromObj(DataObject, DropURL) then
                  Break;
              end;
          end;
        end;

      if (DropURL <> '') then
        if ((HI.HitNode <> nil) and (HitNodeData.Client = nil) and (Attachmode = amInsertAfter) and Expanded[HI.HitNode]) or (Attachmode = amNoWhere) then
          OnStartStreaming(Self, DropURL, HI.HitNode, amAddChildLast)
        else
        begin
          if (HI.HitNode <> nil) and Expanded[HI.HitNode] and (Attachmode <> amInsertBefore) then
            Attachmode := amAddChildLast;
          if AttachMode = amNoWhere then
            AttachMode := amInsertAfter;
          OnStartStreaming(Self, DropURL, HI.HitNode, Attachmode);
        end;
        UnkillCategory(HI.HitNode);
    finally
      Files.Free;
    end;

  end;
end;

procedure TMClientView.DoDragging(P: TPoint);
var
  i: Integer;
  //UseRelay: Boolean;
  UseFile: Boolean;
  Entries: TPlaylistEntryArray;
  Client: TICEClient;
  Clients: TClientArray;
  Node: PVirtualNode;
  Nodes: TNodeArray;
begin
  if FDragSource.DragInProgress then
    Exit;

  if ((Length(GetNodes(ntCategory, True)) = 0) and (Length(GetNodes(ntClient, True)) = 0)) or
     ((Length(GetNodes(ntCategory, True)) > 0) and (Length(GetNodes(ntClient, True)) > 0)) then
  begin
    // Raus, wenn nichts markiert ist oder von beiden etwas...
    Exit;
  end;

  //UseRelay := AppGlobals.Relay;
  UseFile := True;

  SetLength(FDragNodes, 0);
  FDragSource.Files.Clear;

  Clients := NodesToClients(GetNodes(ntClient, True));
  if Length(Clients) > 0 then
  begin
    for Client in Clients do
    begin
      //if AppGlobals.Relay then
      //  if not Client.Active then
      //    UseRelay := False;
      SetLength(FDragNodes, Length(FDragNodes) + 1);
      FDragNodes[High(FDragNodes)] := GetClientNode(Client);
      if not Client.Active then
        UseFile := False;
    end;

    SetLength(Entries, 0);

    case AppGlobals.DefaultAction of
      //caStartStop:
        //if UseRelay then
        //  Entries := GetEntries(etRelay);
      caStream:
        Entries := GetEntries(etStream);
      //caRelay:
      //  if UseRelay then
      //    Entries := GetEntries(etRelay);
      caFile:
        if UseFile then
          Entries := GetEntries(etFile);
    end;

    if Length(Entries) = 0 then
      Entries := GetEntries(etStream);

    for i := 0 to Length(Entries) - 1 do
      FDragSource.Files.Add(AnsiString(Entries[i].URL));

    if FDragSource.Files.Count = 0 then
      Exit;
  end else
  begin
    Nodes := GetNodes(ntCategory, True);
    for Node in Nodes do
    begin
      SetLength(FDragNodes, Length(FDragNodes) + 1);
      FDragNodes[High(FDragNodes)] := Node;
    end;
  end;

  DoStateChange([], [tsOLEDragPending, tsOLEDragging, tsClearPending]);
  FDragSource.Execute(False);
  SetLength(FDragNodes, 0);
end;

function TMClientView.GetEntries(T: TEntryTypes): TPlaylistEntryArray;
var
  Add: Boolean;
  Name, URL: string;
  Clients: TClientArray;
  Client: TICEClient;
begin
  SetLength(Result, 0);
  Clients := NodesToClients(GetNodes(ntClient, True));
  for Client in Clients do
  begin
    Add := True;
    if Client.Entry.Name = '' then
      Name := Client.Entry.StartURL
    else
      Name := Client.Entry.Name;

    //if (T = etRelay) and (not Client.Active) then
    //  Add := False;
    if (T = etFile) and (Client.Filename = '') then
      Add := False;

    if Add then
    begin
      case T of
        etStream: URL := Client.Entry.StartURL;
        //etRelay: URL := Client.RelayURL;
        etFile: URL := Client.Filename;
      end;

      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].URL := URL;
      Result[High(Result)].Name := Name;
    end;
  end;
end;

end.

