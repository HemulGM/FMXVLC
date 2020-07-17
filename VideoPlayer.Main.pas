unit VideoPlayer.Main;

interface

uses
  Winapi.Windows, System.SysUtils, System.Types, System.Generics.Collections, System.UITypes, System.Classes, System.Variants, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects, FmxPasLibVlcPlayerUnit, FMX.Layouts,
  FMX.ListView.Types, FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.Controls.Presentation, FMX.StdCtrls,
  FMX.ListView, System.IOUtils, FMX.Ani, FMX.Effects, FMX.ScrollBox, FMX.Memo,
  Radiant.Shapes;

type
  TArrayOfString = TArray<string>;

  TArrayOfStringHelper = record helper for TArrayOfString
    function InArray(Value: string): Boolean;
  end;

  TFormMain = class(TForm)
    LayoutFiles: TLayout;
    LayoutPlayer: TLayout;
    ListViewFiles: TListView;
    RectanglePlayer: TRectangle;
    VlcPlayer: TFmxPasLibVlcPlayer;
    StyleBook: TStyleBook;
    Layout1: TLayout;
    Button1: TButton;
    Button5: TButton;
    LayoutControl: TLayout;
    TimerHideControl: TTimer;
    FloatAnimationHide: TFloatAnimation;
    FloatAnimationShow: TFloatAnimation;
    Rectangle1: TRectangle;
    ButtonPlayPrev: TButton;
    ButtonPlayNext: TButton;
    ButtonFiles: TButton;
    ButtonPlay: TButton;
    LayoutTrackPos: TLayout;
    TrackBarPos: TTrackBar;
    TrackBarVolume: TTrackBar;
    Splitter: TSplitter;
    LabelTimeLeft: TLabel;
    LabelTimeRight: TLabel;
    TimerClick: TTimer;
    RadiantGear1: TRadiantGear;
    FloatAnimation1: TFloatAnimation;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ListViewFilesItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure TrackBarPosChange(Sender: TObject);
    procedure VlcPlayerMediaPlayerPositionChanged(Sender: TObject; position: Single);
    procedure TrackBarPosMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure TrackBarPosMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure ButtonPlayClick(Sender: TObject);
    procedure TrackBarVolumeChange(Sender: TObject);
    procedure ButtonFilesClick(Sender: TObject);
    procedure VlcPlayerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure TimerHideControlTimer(Sender: TObject);
    procedure VlcPlayerMediaPlayerPaused(Sender: TObject);
    procedure VlcPlayerMediaPlayerPlaying(Sender: TObject);
    procedure ButtonPlayPrevClick(Sender: TObject);
    procedure ButtonPlayNextClick(Sender: TObject);
    procedure VlcPlayerMediaPlayerStopped(Sender: TObject);
    procedure VlcPlayerMediaPlayerLengthChanged(Sender: TObject; time: Int64);
    procedure FloatAnimationHideFinish(Sender: TObject);
    procedure VlcPlayerDblClick(Sender: TObject);
    procedure VlcPlayerClick(Sender: TObject);
    procedure TimerClickTimer(Sender: TObject);
    procedure VlcPlayerMouseLeave(Sender: TObject);
  private
    FStarting: Boolean;
    FChangingPos: Boolean;
    FUserChangePos: Boolean;
    FDblClick: Boolean;
    procedure FillDirectory(Dir: string);
    procedure SetVideoFullScreen(const Value: Boolean);
    function GetVideoFullScreen: Boolean;
    procedure PlayNext(Handle: Boolean);
    procedure PlayPrev(Handle: Boolean);
    procedure Play(FileName: string);
    procedure HideControls;
    procedure ShowControls;
  public
    property VideoFullScreen: Boolean read GetVideoFullScreen write SetVideoFullScreen;
  end;

var
  FormMain: TFormMain;
  AllowExts: TArrayOfString = ['.mp4', '.avi', '.flv', '.ts', '.mkv'];
  PathCache: string;
  PathHome: string;

implementation

uses
  System.DateUtils, VideoPlayer.MediaInfo;

{$R *.fmx}

function MsToTimeStr(Value: Int64): string;
var
  H, M, S: Integer;
begin
  try
    Value := Value div MSecsPerSec;
    H := Value div SecsPerHour;
    Value := Value - (H * SecsPerHour);
    M := Value div SecsPerMin;
    Value := Value - (M * SecsPerMin);
    S := Value;
    Result := Format('%.2d:%.2d:%.2d', [H, M, S]);
  except
    Result := '';
  end;
end;

function SecToTimeStr(Value: Int64): string;
var
  H, M, S: Integer;
begin
  try
    H := Value div SecsPerHour;
    Value := Value - (H * SecsPerHour);
    M := Value div SecsPerMin;
    Value := Value - (M * SecsPerMin);
    S := Value;
    Result := Format('%.2d:%.2d:%.2d', [H, M, S]);
  except
    Result := '';
  end;
end;

function ExecuteProcess(const FileName, Params: string; Folder: string; WaitUntilTerminated, WaitUntilIdle, RunMinimized:
  boolean; var ErrorCode: integer): boolean;
const
  ThreadWaitTimeOut = 10 * 1000;
var
  CmdLine: string;
  WorkingDirP: PChar;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
begin
  Result := true;
  CmdLine := FileName + ' ' + Params;
  if Folder = '' then
    Folder := ExcludeTrailingPathDelimiter(ExtractFilePath(FileName));
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  if RunMinimized then
  begin
    StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
    StartupInfo.wShowWindow := SW_HIDE;
  end;
  if Folder <> '' then
    WorkingDirP := PChar(Folder)
  else
    WorkingDirP := nil;
  if not CreateProcess(nil, PChar(CmdLine), nil, nil, false, 0, nil, WorkingDirP, StartupInfo, ProcessInfo) then
  begin
    Result := false;
    ErrorCode := GetLastError;
    Exit;
  end;
  with ProcessInfo do
  begin
    CloseHandle(hThread);
    if WaitUntilIdle then
      WaitForInputIdle(hProcess, ThreadWaitTimeOut);
    if WaitUntilTerminated then
      WaitForSingleObject(hProcess, ThreadWaitTimeOut);
    CloseHandle(hProcess);
  end;
end;

function GetVideoDuration(VideoFile: string; var Duration: string): Boolean;
var
  MediaMeta: TMediaMeta;
  idx: int32;
begin
  Result := False;
  MediaMeta := TMediaMeta.Create(ExtractFilePath(VideoFile), ExtractFileName(VideoFile));
  try
    if MediaMeta.VideoTrackCount > 0 then
    begin
      Duration := SecToTimeStr(MediaMeta.VideoTrackInfo[0].Duration);
      Result := not Duration.IsEmpty;
    end;
  finally
    MediaMeta.Free;
  end;
end;

function GetThumbnail(VideoFile: string; var ThumbFile: string): Boolean;
var
  ErrorCode: Integer;
begin
  if not TDirectory.Exists(PathCache) then
    TDirectory.CreateDirectory(PathCache);
  ThumbFile := IncludeTrailingPathDelimiter(PathCache) + ExtractFileName(VideoFile) + '.png';
  if not FileExists(ThumbFile) then
  begin
    Result := ExecuteProcess('ffmpeg', '-i "' + VideoFile + '" -ss 00:00:05.000 -vframes 1 "' + ThumbFile + '"',
      TPath.GetLibraryPath, True, True, True, ErrorCode) and FileExists(ThumbFile);
  end
  else
    Result := True;
end;

function SelectDirectory(var Dir: string): Boolean;
begin
  Result := FMX.Dialogs.SelectDirectory('', '', Dir);
end;

procedure TFormMain.Button1Click(Sender: TObject);
var
  Dir: string;
begin
  if SelectDirectory(Dir) then
  begin
    FillDirectory(Dir);
  end;
end;

procedure TFormMain.ButtonFilesClick(Sender: TObject);
begin
  LayoutFiles.Visible := not LayoutFiles.Visible;
  Splitter.Visible := LayoutFiles.Visible;
end;

procedure TFormMain.ButtonPlayClick(Sender: TObject);
begin
  if VlcPlayer.IsPlay then
    VlcPlayer.Pause
  else if VlcPlayer.IsPause then
    VlcPlayer.Resume;
end;

procedure TFormMain.PlayNext(Handle: Boolean);
begin
  if ListViewFiles.ItemIndex < ListViewFiles.Items.Count - 1 then
  begin
    ListViewFiles.ItemIndex := ListViewFiles.ItemIndex + 1;
    Play(ListViewFiles.Items[ListViewFiles.ItemIndex].Data['Path'].AsString);
  end;
end;

procedure TFormMain.PlayPrev(Handle: Boolean);
begin
  if ListViewFiles.ItemIndex > 0 then
  begin
    ListViewFiles.ItemIndex := ListViewFiles.ItemIndex - 1;
    Play(ListViewFiles.Items[ListViewFiles.ItemIndex].Data['Path'].AsString);
  end;
end;

procedure TFormMain.ButtonPlayNextClick(Sender: TObject);
begin
  PlayNext(True);
end;

procedure TFormMain.ButtonPlayPrevClick(Sender: TObject);
begin
  PlayPrev(True);
end;

procedure TFormMain.FillDirectory(Dir: string);
var
  FileName: string;
  Files: TArrayOfString;
begin
  if not TDirectory.Exists(Dir) then
    Exit;
  Files := TDirectory.GetFiles(Dir, TSearchOption.soTopDirectoryOnly,
    function(const Path: string; const SearchRec: TSearchRec): Boolean
    begin
      Result := AllowExts.InArray(ExtractFileExt(SearchRec.Name));
    end);
  ListViewFiles.BeginUpdate;
  ListViewFiles.Items.Clear;
  for FileName in Files do
  begin
    with ListViewFiles.Items.Add do
    begin
      Text := ExtractFileName(FileName);
      Text := Text.Substring(0, Text.Length - 4);
      Detail := '';
      Data['Path'] := FileName;
    end;
  end;
  ListViewFiles.EndUpdate;
  TThread.CreateAnonymousThread(
    procedure
    var
      i: Integer;
      FN, S: string;
      BMP: TBitmap;
    begin
      for i := 0 to ListViewFiles.Items.Count - 1 do
      begin
        FN := ListViewFiles.Items[i].Data['Path'].AsString;
        if GetVideoDuration(FN, S) then
        begin
          ListViewFiles.Items[i].Detail := S;
        end;
        if GetThumbnail(FN, S) then
        begin
          BMP := TBitmap.Create;
          TThread.Synchronize(nil,
            procedure
            begin
              BMP.LoadFromFile(S);
            end);
          ListViewFiles.Items[i].Bitmap := BMP;
        end;
      end;
    end).Start;
end;

procedure TFormMain.FloatAnimationHideFinish(Sender: TObject);
begin
  LayoutControl.Visible := False;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FDblClick := False;
  FillDirectory('D:\Мультимедиа\Видео1');
end;

function TFormMain.GetVideoFullScreen: Boolean;
begin
  Result := FullScreen;
end;

procedure TFormMain.Play(FileName: string);
begin
  FStarting := True;
  TThread.CreateAnonymousThread(
    procedure
    begin
      VlcPlayer.Play(FileName);
      FStarting := False;
    end).Start;
end;

procedure TFormMain.ListViewFilesItemClick(const Sender: TObject; const AItem: TListViewItem);
begin
  Play(AItem.Data['Path'].AsString)
end;

procedure TFormMain.SetVideoFullScreen(const Value: Boolean);
begin
  FullScreen := Value;
  LayoutFiles.Visible := not Value;
  Splitter.Visible := not Value;
  if Value then
    HideControls;
end;

procedure TFormMain.TrackBarPosChange(Sender: TObject);
begin
  if not FChangingPos and VlcPlayer.IsPlay then
    VlcPlayer.SetVideoPosInPercent(TrackBarPos.Value);
  TrackBarPos.Repaint;
end;

procedure TFormMain.TrackBarPosMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  FUserChangePos := True;
end;

procedure TFormMain.TrackBarPosMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  FUserChangePos := False;
end;

procedure TFormMain.TrackBarVolumeChange(Sender: TObject);
begin
  TrackBarVolume.Hint := Round(TrackBarVolume.Value).ToString;
  VlcPlayer.SetAudioVolume(Round(TrackBarVolume.Value));
end;

procedure TFormMain.VlcPlayerClick(Sender: TObject);
begin
  FDblClick := False;
  TimerClick.Enabled := False;
  TimerClick.Enabled := True;
end;

procedure TFormMain.VlcPlayerDblClick(Sender: TObject);
begin
  FDblClick := True;
  TimerClick.Enabled := False;
  VideoFullScreen := not VideoFullScreen;
end;

procedure TFormMain.VlcPlayerMediaPlayerLengthChanged(Sender: TObject; time: Int64);
begin
  LabelTimeRight.Text := MsToTimeStr(VlcPlayer.GetVideoLenInMs);
end;

procedure TFormMain.VlcPlayerMediaPlayerPaused(Sender: TObject);
begin
  ButtonPlay.StyleLookup := 'playtoolbutton';
end;

procedure TFormMain.VlcPlayerMediaPlayerPlaying(Sender: TObject);
begin
  ButtonPlay.StyleLookup := 'pausetoolbutton';
end;

procedure TFormMain.VlcPlayerMediaPlayerPositionChanged(Sender: TObject; position: Single);
begin
  if not FUserChangePos then
  begin
    FChangingPos := True;
    TrackBarPos.Value := VlcPlayer.GetVideoPosInPercent;
    FChangingPos := False;
  end;
  LabelTimeLeft.Text := MsToTimeStr(VlcPlayer.GetVideoPosInMs);
end;

procedure TFormMain.VlcPlayerMediaPlayerStopped(Sender: TObject);
begin
  PlayNext(False);
end;

procedure TFormMain.TimerClickTimer(Sender: TObject);
begin
  TimerClick.Enabled := False;
  if not FDblClick then
    ButtonPlayClick(nil);
end;

procedure TFormMain.TimerHideControlTimer(Sender: TObject);
var
  MPos: TPointF;
begin
  TimerHideControl.Enabled := False;
  MPos := ScreenToClient(Screen.MousePos);
  if (not LayoutControl.PointInObject(MPos.X, MPos.Y)) and (VlcPlayer.IsPlay) then
  begin
    HideControls;
  end;
end;

procedure TFormMain.HideControls;
begin
  VlcPlayer.Cursor := TCursor(-1);
  FloatAnimationShow.Stop;
  FloatAnimationHide.Start;
end;

procedure TFormMain.ShowControls;
begin
  VlcPlayer.Cursor := crDefault;
  if not LayoutControl.Visible then
    LayoutControl.Visible := True;
  if (LayoutControl.Opacity < 1) and (not FloatAnimationShow.Running) then
  begin
    FloatAnimationShow.Start;
  end;
end;

procedure TFormMain.VlcPlayerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  TimerHideControl.Enabled := False;
  TimerHideControl.Enabled := True;
  ShowControls;
end;

procedure TFormMain.VlcPlayerMouseLeave(Sender: TObject);
var
  MPos: TPointF;
begin
  MPos := ScreenToClient(Screen.MousePos);
  if (not LayoutControl.PointInObject(MPos.X, MPos.Y)) and (VlcPlayer.IsPlay) then
    HideControls;
end;

{ TArrayOfStringHelper }

function TArrayOfStringHelper.InArray(Value: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(Self) to High(Self) do
    if Self[i] = Value then
      Exit(True);
end;

initialization
  PathHome := IncludeTrailingPathDelimiter(TPath.GetHomePath) + 'VideoPlayer';
  PathCache := IncludeTrailingPathDelimiter(PathHome) + 'cache';

end.

