object frmEditTags: TfrmEditTags
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'Edit tags and data'
  ClientHeight = 375
  ClientWidth = 285
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Icon.Data = {
    0000010001001010000001002000680400001600000028000000100000002000
    000001002000000000000000000000000000000000000000000000000000FFFF
    FF00FFFFFF00FFFFFF00FFFFFF00113D55F7285F87FB4988BDFB428DBCC17896
    AE53AAAAAA1EFFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
    FF00FFFFFF00FFFFFF00FFFFFF002B6583FB94C7F9FF91C9F9FF4185C9FF2367
    AAFF9DABB7FFAAAAAA21FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
    FF00FFFFFF00FFFFFF00FFFFFF004389AAFFE0F2FFFF549AD8FF1A7ABEFF4998
    C5FF458BC3FFA0AEBBFFABABAB21FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
    FF00FFFFFF00FFFFFF00FFFFFF001D699C637AB6D5FF90B7D1FF55C9E4FF5BDF
    F5FF78D0EDFF4E9ADAFFA5B1BBFFABABAB21FFFFFF00FFFFFF00FFFFFF00FFFF
    FF00FFFFFF00FFFFFF00FFFFFF00BABABA3B83A6B7F976B9D6FFC2F6FDFF63DF
    F7FF5DE2F8FF79D3F0FF4897DBFFA7B2BBFFABABAB21FFFFFF00FFFFFF00FFFF
    FF00FFFFFF00FFFFFF00BDBDBD3BBCBCBCF6E5E5E5FFB0D4E5FF77CBE7FFC7F7
    FDFF5EDCF5FF5AE1F7FF7BD4F1FF4A98DCFF9DAEBEFFACACAC21FFFFFF00FFFF
    FF00FFFFFF00C1C1C13BC0C0C0F6E7E7E7FFFDFDFDFFFBECD6FFBEC4A0FF79D3
    EEFFC7F7FDFF5FDCF5FF5BE2F7FF7AD6F2FF4E9FDEFFA1AFBBFFACACAC1FFFFF
    FF00C5C5C53BC3C3C3F6E8E8E8FFFDFDFDFFFBECD6FFFDCD88FFFFD598FFC1CE
    B2FF7DD4EDFFC4F6FDFF6CDDF6FF6DCAEDFF63A3D7FF649DD0FF6F9BC138C9C9
    C93DC7C7C7F6E9E9E9FFFDFDFDFFFBEBD3FFFFCC83FFFFD498FFFFD79EFFFFD6
    9BFFB5C6A8FF81D5EDFFB2E3F9FF8BC0E7FFAED3F6FFC4E0FCFF669FD3F7CBCB
    CBF6EBEBEBFFFDFDFDFFFAFAFAFFFBF3E7FFFECE89FFFFD496FFFFD59AFFFFCF
    8BFFFDE2BCFFAFE4F4FF77BEE7FFB4D2F0FFE5F3FFFFACD2EFFF488CC7E8CDCD
    CDFFFDFDFDFFFDFDFDFFFCFCFCFFF7F7F7FFFDF5EAFFFECF8AFFFFCC83FFFDE2
    BCFFFDFDFDFFDCDCDCFF92BBCAFF58A5D8FF85B1DBFF469DD0FF2B95D15ECECE
    CEFFFDFDFDFFE0E0E0FFCACACAF9C8C8C8E2F7F7F7FFFBF3E8FFFDE3BDFFFDFD
    FDFFDEDEDEFFC3C3C3FFBDBDBD15FFFFFF00FFFFFF00FFFFFF00FFFFFF00D0D0
    D0FFFDFDFDFFCDCDCDFFFFFFFF00CACACACDF3F3F3FFFBFBFBFFFDFDFDFFE0E0
    E0FFC7C7C7FFC0C0C015FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00D2D2
    D2FFFDFDFDFFE2E2E2FFCECECEFFE0E0E0FFFDFDFDFFFDFDFDFFE2E2E2FFCBCB
    CBFFC4C4C415FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00D3D3
    D3FFFDFDFDFFFDFDFDFFFDFDFDFFFDFDFDFFFDFDFDFFE4E4E4FFCDCDCDFFC8C8
    C815FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00D5D5
    D5FFD4D4D4FFD2D2D2FFD1D1D1FFD0D0D0FFCECECEFFCDCDCDFFCBCBCB15FFFF
    FF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00F0FF
    0000F03F0000F01F0000F80F0000F8070000F0030000E0010000C00100008000
    00000000000000010000001F0000103F0000007F000000FF000001FF0000}
  KeyPreview = True
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object pnlNav: TPanel
    Left = 0
    Top = 335
    Width = 285
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    Padding.Left = 4
    Padding.Top = 4
    Padding.Right = 4
    Padding.Bottom = 4
    TabOrder = 2
    object Bevel2: TBevel
      Left = 4
      Top = 4
      Width = 277
      Height = 5
      Align = alTop
      Shape = bsTopLine
      ExplicitLeft = -7
      ExplicitWidth = 396
    end
    object btnClose: TBitBtn
      Left = 184
      Top = 9
      Width = 97
      Height = 27
      Align = alRight
      Caption = '&Save'
      Default = True
      DoubleBuffered = False
      Layout = blGlyphRight
      ParentDoubleBuffered = False
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
  object grpTags: TGroupBox
    Left = 4
    Top = 4
    Width = 277
    Height = 249
    Caption = ' Tags '
    TabOrder = 0
    DesignSize = (
      277
      249)
    object Label1: TLabel
      Left = 8
      Top = 152
      Width = 49
      Height = 13
      Caption = 'Comment:'
    end
    object txtArtist: TLabeledEdit
      Left = 8
      Top = 36
      Width = 261
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      EditLabel.Width = 30
      EditLabel.Height = 13
      EditLabel.Caption = 'Artist:'
      TabOrder = 0
    end
    object txtTitle: TLabeledEdit
      Left = 8
      Top = 80
      Width = 261
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      EditLabel.Width = 24
      EditLabel.Height = 13
      EditLabel.Caption = 'Title:'
      TabOrder = 1
    end
    object txtComment: TMemo
      Left = 8
      Top = 168
      Width = 261
      Height = 73
      Anchors = [akLeft, akTop, akRight, akBottom]
      ScrollBars = ssVertical
      TabOrder = 3
    end
    object txtAlbum: TLabeledEdit
      Left = 8
      Top = 124
      Width = 261
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      EditLabel.Width = 33
      EditLabel.Height = 13
      EditLabel.Caption = 'Album:'
      TabOrder = 2
    end
  end
  object grpData: TGroupBox
    Left = 4
    Top = 264
    Width = 277
    Height = 65
    Caption = ' Data '
    TabOrder = 1
    DesignSize = (
      277
      65)
    object txtStreamname: TLabeledEdit
      Left = 8
      Top = 36
      Width = 261
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      EditLabel.Width = 64
      EditLabel.Height = 13
      EditLabel.Caption = 'Streamname:'
      TabOrder = 0
    end
  end
end
