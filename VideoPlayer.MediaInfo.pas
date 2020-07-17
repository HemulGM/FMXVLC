unit VideoPlayer.MediaInfo;

interface

uses
  system.generics.collections;

type
  ///  <summary>
  ///    This record is used to store information about the video tracks
  ///    discovered in the target file.
  ///  </summary>
  TVideoTrackInfo = record
    FrameRate: int32;
    Duration: int32;
    xRes: int32;
    yRes: int32;
  end;

  ///  <summary>
  ///    This class provides array-style access to the video track information
  ///    discovered in the target media file.
  ///  </summary>
  TMediaMeta = class
  private
    fVideoTracks: TList<TVideoTrackInfo>;
    fFilename: string;
    fFilepath: string;
  private
    procedure ExtractMeta;
    function getVideoTrackCount: uint32;
    function getVideoTrackInfo(idx: uint32): TVideoTrackInfo;
  public
    constructor Create(Filepath: string; Filename: string); reintroduce;
    destructor Destroy; override;
  public
    property VideoTrackCount: uint32 read getVideoTrackCount;
    property VideoTrackInfo[idx: uint32]: TVideoTrackInfo read getVideoTrackInfo;
  end;

implementation

uses
{$ifdef ANDROID}
  AndroidAPI.JNIBridge, AndroidAPI.JNI.JavaTypes, AndroidAPI.JNI.Media, AndroidAPI.Helpers,
{$endif}
{$ifdef MSWINDOWS}
  sysutils, WMPLib_TLB,
{$endif}
  System.IOUtils;

{ TMediaMeta }

constructor TMediaMeta.Create(Filepath, Filename: string);
begin
  inherited Create;
  fFilePath := Filepath;
  fFilename := Filename;
  fVideoTracks := TList<TVideoTrackInfo>.Create;
  if TFile.Exists(IncludeTrailingPathDelimiter(Filepath) + Filename) then
    ExtractMeta;
end;

destructor TMediaMeta.Destroy;
begin
  fVideoTracks.DisposeOf;
  inherited;
end;

{$ifdef ANDROID}
procedure TMediaMeta.ExtractMeta;
var
  f: JFile;
  fis: JFileInputStream;
  fd: JFileDescriptor;
  Extractor: JMediaExtractor;
  Format: JMediaFormat;
  FormatClass: JMediaFormatClass;
  numTracks: int32;
  counter: int32;
  idx: int32;
  mime: JString;
  ARecord: TVideoTrackInfo;
begin
  f := TJFile.JavaClass.init(StringToJString(fFilepath), StringToJString(fFilename));
  fis := TJFileInputStream.JavaClass.init(f);
  fd := fis.getFD;
  Extractor := TJMediaExtractor.JavaClass.init;
  Extractor.setDataSource(fd);
  numTracks := Extractor.getTrackCount;
  counter := 0;
  for idx := 0 to pred(numTracks) do
  begin
    Format := Extractor.getTrackFormat(idx);
    mime := Format.getString(TJMediaFormat.JavaClass.KEY_MIME);
    if mime.startsWith(StringToJString('video/')) then
    begin
      if Format.containsKey(TJMediaFormat.JavaClass.KEY_FRAME_RATE) then
      begin
        ARecord.FrameRate := Format.getInteger(TJMediaFormat.JavaClass.KEY_FRAME_RATE);
        ARecord.Duration := Format.getInteger(TJMediaFormat.JavaClass.KEY_DURATION);
        ARecord.xRes := Format.getInteger(TJMediaFormat.JavaClass.KEY_WIDTH);
        ARecord.yRes := Format.getInteger(TJMediaFormat.JavaClass.KEY_HEIGHT);
        fVideoTracks.Add(ARecord);
      end;
    end;
  end;
end;
{$endif}
{$ifdef MSWINDOWS}

procedure TMediaMeta.ExtractMeta;
var
  MediaPlayer: TWindowsMediaPlayer;
  Media: IWMPMedia;
  ARecord: TVideoTrackInfo;
begin
  MediaPlayer := TWindowsMediaPlayer.Create(nil);
  try
    try
      Media := MediaPlayer.DefaultInterface.newMedia('file://' + fFilePath + '\' + fFilename);
      ARecord.FrameRate := StrToInt(Media.getItemInfo('FrameRate')) div 1000;
      ARecord.Duration := StrToInt(Media.getItemInfo('Duration'));
      ARecord.xRes := StrToInt(Media.getItemInfo('WM/VideoWidth'));
      ARecord.yRes := StrToInt(Media.getItemInfo('WM/VideoHeight'));
      fVideoTracks.Add(ARecord);
    finally
      MediaPlayer.DisposeOf;
    end;
  except
  end;
end;
{$endif}

function TMediaMeta.getVideoTrackCount: uint32;
begin
  Result := fVideoTracks.Count;
end;

function TMediaMeta.getVideoTrackInfo(idx: uint32): TVideoTrackInfo;
begin
  Result := fVideoTracks.Items[idx];
end;

end.

