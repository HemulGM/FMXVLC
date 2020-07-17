program VideoPlayer;

uses
  System.StartUpCopy,
  FMX.Forms,
  VideoPlayer.Main in 'VideoPlayer.Main.pas' {FormMain},
  VideoPlayer.MediaInfo in 'VideoPlayer.MediaInfo.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
