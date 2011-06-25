//* File:     Lib\GUI\uSounds.pas
//* Created:  2000-05-01
//* Modified: 2007-12-28
//* Version:  1.1.39.8
//* Author:   David Safranek (Safrad)
//* E-Mail:   safrad at email.cz
//* Web:      http://safrad.own.cz

unit uSounds;

interface

uses
	uTypes, uDForm, uWave,
	Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
	StdCtrls, uDButton, uDImage, uDView, uDLabel, ExtCtrls, Menus, Dialogs,
	uDWinControl;

type
	TfSounds = class(TDForm)
		DViewSounds: TDView;
		ButtonOK: TDButton;
		ButtonApply: TDButton;
		ButtonCancel: TDButton;
		OpenDialog1: TOpenDialog;
		BevelSQ: TBevel;
		LabelSQ: TLabel;
		LabelFrequency: TLabel;
		ComboBoxFrequency: TComboBox;
		Button16bits: TDButton;
		ButtonStereo: TDButton;
		ButtonReduce: TDButton;
		ButtonMusic: TDButton;
		ButtonSounds: TDButton;
		PopupMenuSounds: TPopupMenu;
		Enable1: TMenuItem;
		Disable1: TMenuItem;
		N1: TMenuItem;
		Preview1: TMenuItem;
		N2: TMenuItem;
		Select1: TMenuItem;
		SetBeep1: TMenuItem;
		SetDefault1: TMenuItem;
		procedure FormResize(Sender: TObject);
		procedure FormCreate(Sender: TObject);
		procedure ButtonCancelClick(Sender: TObject);
		procedure ButtonOKClick(Sender: TObject);
		procedure ButtonApplyClick(Sender: TObject);
		procedure DViewSoundsDblClick(Sender: TObject);
		procedure DViewSoundsGetData(Sender: TObject; var Data: String; ColIndex,
			RowIndex: Integer; Rect: TRect);
		procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
		procedure FormShow(Sender: TObject);
		procedure Select1Click(Sender: TObject);
		procedure PopupMenuSoundsPopup(Sender: TObject);
	private
		{ Private declarations }
	public
		{ Public declarations }
	end;

const
	Center = MaxInt;
var
	SoundEnabled: BG = True;
	MusicEnabled: BG = True;
	WavePlayer: TWavePlayer;

procedure AddSounds(const SoundNames: array of string; const Disabled: BG = False);
procedure ReadSounds;
procedure FreeSounds;

procedure PlaySound(const SoundKind: SG); overload;
procedure PlaySound(const SoundKind: SG; const CX, CXCount: SG); overload;
procedure UnuseSounds;

procedure FormSounds;

implementation

{$R *.dfm}
uses
	uData, uFiles, uDIniFile, uInputFormat, uMath, uMenus, uOutputFormat;

type
	PSound = ^TSound; // Used Sounds
	TSound = packed record // 16
		Wave: PWave; // 4
		Enabled, Used: B1; // 2
		Reserved: array[0..1] of U1; // 2
		Name: string; // 4
		FileName: TFileName; // 4
	end;
	PDSound = ^TDSound; // Form Sounds
	TDSound = packed record // 16
		Wave: PWave; // 4
		Enabled: B1; // 1
		Exists: B1; // 1
		Reserved: array[0..1] of U1; // 2
		Length: U4; // 4
		FileName: TFileName; // 4
	end;

var
	fSounds: TfSounds;

	Sounds: TData;
	DSounds: TData;
	SoundsChanged: BG;

	SoundReduce: BG = True;
	Sound16bits: BG = True;
	SoundFrequency: SG = 22050;
	SoundStereo: BG = True;

procedure InitSound;
begin
	if WavePlayer = nil then Exit;
	WavePlayer.Close;
	if Sound16bits then
		WavePlayer.Bits := 16
	else
		WavePlayer.Bits := 8;
	WavePlayer.Frequency := SoundFrequency;
	if SoundStereo then
		WavePlayer.Channels := 2
	else
		WavePlayer.Channels := 1;
//	WavePlayer.BufferTime := 200;
//	WavePlayer.VolumeLeft := 0; //MaxVolume div 2;
//	WavePlayer.VolumeRight := 0; //MaxVolume div 2;
	if SoundEnabled then
		WavePlayer.Open;
end;

procedure RWOptions(const Save: Boolean);
var
	Section: string;
	i: SG;
	P: PSound;
begin
	if MainIni = nil then Exit;
	Section := 'Sounds';
	MainIni.RWBool(Section, 'Enabled', SoundEnabled, Save);
	MainIni.RWBool(Section, 'Music', MusicEnabled, Save);
	if Assigned(WavePlayer) then
	begin
		MainIni.RWBool(Section, 'Reduce', SoundReduce, Save);
		MainIni.RWBool(Section, '16bits', Sound16bits, Save);
		MainIni.RWNum(Section, 'Frequency', SoundFrequency, Save);
		MainIni.RWBool(Section, 'Stereo', SoundStereo, Save);
		InitSound;
	end;

	if Save and (SoundsChanged = False) then Exit;
	if Sounds.Count = 0 then Exit;
	P := Sounds.GetFirst;
	for i := 0 to Sounds.Count - 1 do
	begin
		MainIni.RWFileName(Section, P.Name, P.FileName, Save);
		MainIni.RWBool(Section, P.Name + ' Enabled', P.Enabled, Save);
		Inc(P);
	end;
end;

procedure AddSounds(const SoundNames: array of string; const Disabled: BG = False);
var
	i: SG;
	P: PSound;
begin
	for i := 0 to Length(SoundNames) - 1 do
	begin
		DSounds.Add;
		P := Sounds.Add;
		P.Name := SoundNames[i];
		if P.Name = 'Warning' then
			P.FileName := ''
		else
			P.FileName := 'Sounds' + PathDelim + SoundNames[i] + '.wav';
//			P.FileName := ShortDir(SoundsDir + SoundNames[i] + '.wav');
		P.Enabled := not Disabled;
	end;
end;

var
	SoundBuffer: PWave;
	SoundBufferSize: UG;
	IniLoaded: BG;

procedure ReadSounds;
var
	i: SG;
	P: PSound;
begin
	if IniLoaded = False then
	begin
		IniLoaded := True;
		RWOptions(False);
	end;

	P := Sounds.GetFirst;
	for i := 0 to Sounds.Count - 1 do
	begin
		if P.FileName <> '' then
			WaveReadFromFile(P.Wave, P.FileName);
		Inc(P);
	end;
end;

procedure FreeSounds;
var
	i: SG;
	P: PSound;
begin
	FormFree(TForm(fSounds));
	if IniLoaded then
		RWOptions(True);
	if Sounds.Count = 0 then Exit;
	P := Sounds.GetFirst;
	for i := 0 to Sounds.Count - 1 do
	begin
		WaveFree(P.Wave);
		Inc(P);
	end;
	Sounds.Clear;
	DSounds.Clear;
	FreeMem(SoundBuffer); SoundBuffer := nil;
end;

procedure PlaySound(const SoundKind: SG);
var
	P: PSound;
begin
	if IniLoaded = False then
	begin
		IniLoaded := True;
		RWOptions(False);
	end;

	if SoundEnabled = False then Exit;
	P := Sounds.Get(SoundKind);
	if P.Enabled then
	begin
		if P.FileName = '' then
			PlayWinSound(wsDefaultSound)
		else
		begin
			P.Enabled := False;
			if P.Wave = nil then
				WaveReadFromFile(P.Wave, P.FileName);
			if P.Wave <> nil then
			begin
				P.Enabled := True;
				PlayWave(P.Wave);
			end;
		end;
	end;
end;

procedure PlaySound(const SoundKind: SG; const CX, CXCount: SG);
var
	P: PSound;
	Pan: SG;
	SoundLeft, SoundRight: SG;
	NewSize: UG;
begin
	if IniLoaded = False then
	begin
		IniLoaded := True;
		RWOptions(False);
	end;

	if (SoundEnabled = False) or (not Assigned(Sounds)) then Exit;
	P := Sounds.Get(SoundKind);
	if P.Enabled then
	begin
		if P.Wave = nil then
			WaveReadFromFile(P.Wave, P.FileName);
		if (P.Wave <> nil) then
		begin
			if WavePlayer = nil then
			begin
				NewSize := 2{Convert from Mono to Stereo} * (P.Wave.BytesFollowing + 8);
				if SoundBufferSize < NewSize then
				begin
					FreeMem(SoundBuffer);
					SoundBufferSize := NewSize;
					GetMem(SoundBuffer, SoundBufferSize);
				end;
				SoundLR(SoundLeft, SoundRight, CX, CXCount);
				ConvertChannels(P.Wave, SoundBuffer, 2, SoundLeft, SoundRight);
				PlayWave(SoundBuffer);
			end
			else if ((SoundReduce = False) or (P.Used = False)) then
			begin
				if SoundStereo and (CX <> Center) then
				begin
		//			i := MaxVolume div 2;
					Pan := RoundDiv(MaxVolume * CX, CXCount);
					WavePlayer.VolumeLeft := (MaxVolume - Pan) div 2;
					WavePlayer.VolumeRight := Pan div 2;
				end
				else
				begin
					WavePlayer.VolumeLeft := MaxVolume div 2;
					WavePlayer.VolumeRight := MaxVolume div 2;
				end;
				WavePlayer.Play(P.Wave);
				P.Used := True;
			end;
		end;
	end;
end;

procedure UnuseSounds;
var
	P: PSound;
	i: SG;
begin
	P := Sounds.GetFirst;
	for i := 0 to Sounds.Count - 1 do
	begin
		P.Used := False;
		Inc(P);
	end;
end;

procedure FormSounds;
begin
	if IniLoaded = False then
	begin
		IniLoaded := True;
		RWOptions(False);
	end;
	if not Assigned(fSounds) then fSounds := TfSounds.Create(nil);
	fSounds.DViewSounds.RowCount := Sounds.Count;
	fSounds.ShowModal;
end;

procedure TfSounds.FormResize(Sender: TObject);
var
	Top: SG;
	L: SG;
begin
	Top := ClientHeight - FormBorder - ButtonOK.Height;

	ButtonCancel.SetBounds(ClientWidth - FormBorder - ButtonCancel.Width, Top, ButtonCancel.Width, ButtonCancel.Height);
	ButtonApply.SetBounds(ButtonCancel.Left - 2 * FormBorder - ButtonApply.Width, Top, ButtonApply.Width, ButtonApply.Height);
	ButtonOK.SetBounds(ButtonApply.Left - 2 * FormBorder - ButtonOK.Width, Top, ButtonOK.Width, ButtonOK.Height);

	ButtonSounds.Top := ButtonOK.Top;
	ButtonMusic.Top := ButtonOK.Top;

	if WavePlayer <> nil then
		L := BevelSQ.Top + BevelSQ.Height + FormBorder
	else
		L := FormBorder;
	DViewSounds.SetBounds(DViewSounds.Left, L,
		ClientWidth - FormBorder - DViewSounds.Left,
		ButtonCancel.Top - FormBorder - L);
end;

procedure TfSounds.FormCreate(Sender: TObject);
var
	B: BG;
begin
	Background := baGradient;
	MenuSet(PopupMenuSounds);

	OpenDialog1.Filter := AllSounds + '|' + AllFiles;

	DViewSounds.AddColumn('Event', 114);
	DViewSounds.AddColumn('Enabled', 48);
	DViewSounds.AddColumn('File Name', DViewSounds.Width - 114 - 64 - 48);
	DViewSounds.AddColumn('Length', 64);

	if Assigned(MainIni) then
	begin
		MainIni.RWFormPos(Self, False);
		DViewSounds.Serialize(MainIni, False);
	end;

	ButtonSounds.Down := SoundEnabled;
	ButtonReduce.Down := SoundReduce;
	Button16bits.Down := Sound16bits;
	ComboBoxFrequency.Text := IntToStr(SoundFrequency);
	ButtonStereo.Down := SoundStereo;
	ButtonMusic.Down := MusicEnabled;

	B := WavePlayer <> nil;
	LabelSQ.Visible := B;
	BevelSQ.Visible := B;
	ButtonReduce.Visible := B;
	Button16bits.Visible := B;
	LabelFrequency.Visible := B;
	ComboBoxFrequency.Visible := B;
	ButtonStereo.Visible := B;
end;

procedure TfSounds.ButtonCancelClick(Sender: TObject);
begin
	Close;
end;

procedure TfSounds.ButtonOKClick(Sender: TObject);
begin
	ButtonApplyClick(Sender);
	Close;
end;

procedure TfSounds.ButtonApplyClick(Sender: TObject);
var
	NewFrequency: SG;
	i: SG;
	Sound: PSound;
	DSound: PDSound;
begin
	if WavePlayer <> nil then
	begin
		NewFrequency := StrToValI(ComboBoxFrequency.Text, True, 100, UG(22050), 100000, 1);
		SoundReduce := ButtonReduce.Down;
		if (SoundEnabled <> ButtonSounds.Down)
		or (Sound16bits <> Button16bits.Down)
		or (SoundFrequency <> NewFrequency)
		or (SoundStereo <> ButtonStereo.Down) then
		begin
			SoundEnabled := ButtonSounds.Down;
//			BSounds := SoundEnabled;
			Sound16bits := Button16bits.Down;
			SoundFrequency := NewFrequency;
			SoundStereo := ButtonStereo.Down;
			InitSound;
		end;
	end;

	if SoundEnabled <> ButtonSounds.Down then
	begin
		SoundEnabled := ButtonSounds.Down;
//		BSounds := SoundEnabled;
		if SoundEnabled then
		begin
			if Assigned(WavePlayer) then
				WavePlayer.Open;
//				if Pause = False then InitSound;
		end
		else
		begin
			if Assigned(WavePlayer) then
				WavePlayer.Close;
//				if DXSound1.Initialized then DXSound1.Finalize;
		end;
	end;

	if ButtonMusic.Down <> MusicEnabled then
	begin
		MusicEnabled := not MusicEnabled;
{			B := False;
		for gk := Low(TGameKind) to High(TGameKind) do
			if GameStart[gk] then
			begin
				B := True;
				Break;
			end;
		if B  and Pause = False then
		begin
			if MusicEnabled = False then
			begin
				MidiMCIStop;
				MidiMCIClose;
			end
			else
			begin
				OpenMusic;
				MidiMCIPlay;
			end;
		end;}
	end;


	Sound := Sounds.GetFirst;
	DSound := DSounds.GetFirst;
	for i := 0 to Sounds.Count - 1 do
	begin
		Sound.FileName := DSound.FileName;
		if DSound.Wave <> nil then
			Sound.Wave := DSound.Wave
		else
		begin
			if Sound.FileName <> '' then
				WaveReadFromFile(Sound.Wave, Sound.FileName);
		end;

		Sound.Enabled := DSound.Enabled;
		DSound.Wave := nil;

		Inc(Sound);
		Inc(DSound);
	end;
end;

procedure TfSounds.DViewSoundsDblClick(Sender: TObject);
begin
	if DViewSounds.Where = vaRow then
	begin
		TComponent(Sender).Tag := Preview1.Tag;
		Select1Click(Sender);
	end;
end;

procedure TfSounds.DViewSoundsGetData(Sender: TObject; var Data: String;
	ColIndex, RowIndex: SG; Rect: TRect);
var
	Sound: PSound;
	DSound: PDSound;
begin
	Sound := Sounds.Get(RowIndex);
	DSound := DSounds.Get(RowIndex);

	DViewSounds.Bitmap.Canvas.Font.Style := [];
	if Sound.Used then
		DViewSounds.Bitmap.Canvas.Font.Style := DViewSounds.Bitmap.Canvas.Font.Style + [fsBold];
	case ColIndex of
	0:
	begin
		if DSound.Enabled = False then
			DViewSounds.Bitmap.Canvas.Font.Style := DViewSounds.Bitmap.Canvas.Font.Style + [fsStrikeOut];
		Data := Sound.Name;
	end;
	1: Data := NToS(SG(DSound.Enabled));
	2:
	begin
		if DSound.Exists = False then
			DViewSounds.Bitmap.Canvas.Font.Style := DViewSounds.Bitmap.Canvas.Font.Style + [fsStrikeOut];
		Data := DSound.FileName;
	end;
	3:
	begin
		Data := MsToStr(DSound.Length, diSD, 3, False, ofDisplay);
	end;
	end;
end;

procedure TfSounds.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
	if Assigned(MainIni) then
	begin
		MainIni.RWFormPos(Self, True);
		DViewSounds.Serialize(MainIni, True);
	end;
end;

procedure UpdateDSound(DSound: PDSound);
begin
	DSound.Exists := FileExists(DSound.FileName);
	DSound.Length := WaveLength(DSound.FileName);
end;

procedure TfSounds.FormShow(Sender: TObject);
var
	i: SG;
	Sound: PSound;
	DSound: PDSound;
begin
	Sound := Sounds.GetFirst;
	DSound := DSounds.GetFirst;
	for i := 0 to Sounds.Count - 1 do
	begin
		DSound.FileName := Sound.FileName;
		DSound.Enabled := Sound.Enabled;
		DSound.Wave := nil;
		UpdateDSound(DSound);

		Inc(Sound);
		Inc(DSound);
	end;
	DViewSounds.Invalidate;
end;

procedure TfSounds.Select1Click(Sender: TObject);
var
	i, Tag: SG;
	P: PDSound;
	P2: PSound;
	SoundsC: BG;
begin
	SoundsC := False;
	Tag := TDButton(Sender).Tag;
	for i := 0 to DViewSounds.RowCount - 1 do
	begin
		if DViewSounds.SelectedRows[i] then
		begin
			P := DSounds.Get(i);
			if P <> nil then
			case Tag of
			0:
			begin
				if P.FileName = '' then
					PlayWinSound(wsDefaultSound)
				else
				begin
					if P.Wave = nil then
					begin
						WaveReadFromFile(P.Wave, P.FileName);
					end;
					if P.Wave <> nil then
						PlayWave(P.Wave);
				end;
			end;
			1:
			begin
				P.Enabled := True;
				SoundsC := True;
			end;
			2:
			begin
				P.Enabled := False;
				SoundsC := True;
			end;
			3: // Select
			begin
				if ExecuteDialog(OpenDialog1, P.FileName) then
				begin
					WaveReadFromFile(P.Wave, P.FileName);
					UpdateDSound(P);
					SoundsC := True;
				end;
			end;
			4: // Default
			begin
				P2 := PSound(Sounds.Get(i));
				P.FileName := 'Sounds' + PathDelim + P2.Name + '.wav';
				UpdateDSound(P);
				SoundsC := True;
			end;
			5: // Beep
			begin
				P.FileName := '';
				UpdateDSound(P);
				SoundsC := True;
			end;
			end;
		end;
	end;
	if SoundsC then
	begin
		DViewSounds.Invalidate;
		SoundsChanged := True;
	end;
end;

procedure TfSounds.PopupMenuSoundsPopup(Sender: TObject);
var
	i: SG;
	C, E: BG;
	P: PDSound;
begin
	i := DViewSounds.RowOrder[DViewSounds.ActualRow];
	if (i >= 0) and (i < SG(DSounds.Count)) then
	begin
		P := DSounds.Get(i);
		C := P.Enabled;
		E := True;
	end
	else
	begin
		E := False;
		C := False;
	end;
	Enable1.Enabled := E;
	Disable1.Enabled := E;
	Enable1.Checked := C;
	Disable1.Checked := not C;
end;

initialization
	Sounds := TData.Create(True);
	Sounds.ItemSize := SizeOf(TSound);
	DSounds := TData.Create(True);
	DSounds.ItemSize := SizeOf(TDSound);
finalization
	FreeAndNil(DSounds);
	FreeAndNil(Sounds);
end.