{ ==========================================================================
  sound.pas  -  Efek suara & musik latar (SDL3 Audio)
  Semua suara dibuat (disintesis) lewat kode, jadi TIDAK butuh file .wav/.mp3.
    - SoundPoint    : bunyi "ding" saat mendapat poin
    - Musik latar   : berulang selama bermain (SoundMusicSet)
    - SoundCrash    : suara tabrakan
    - SoundGameOver : melodi turun saat game over
  Bila perangkat audio tidak ada, game tetap jalan tanpa suara.
  Catatan diagnosa ditulis ke file sound_log.txt di folder game.
  ========================================================================== }
unit suara;

{$mode objfpc}{$H+}

interface

uses
  sdl3;

procedure InisialisasiSuara;
procedure MatikanSuara;
procedure PerbaruiSuara;                  { panggil tiap frame (mengulang musik) }
procedure AturMusik(mode: Integer); { 0 = berhenti, 1 = main, 2 = jeda }
procedure SuaraPoin;
procedure SuaraTabrakan;
procedure SuaraGameOver;

implementation

uses
  SysUtils;

const
  // Kualitas suara: 22050 sampel per detik (cukup untuk efek 8-bit, hemat memori).
  RATE = 22050;

type
  // TBuf = data suara siap putar (angka 16-bit). TMix = bahan campuran suara (angka desimal) sebelum diubah.
  TBuf = array of SmallInt;
  TMix = array of Single;

var
  // Wadah suara yang sudah jadi: musik latar, bunyi poin, tabrakan, dan game over.
  BufMusic, BufPoint, BufCrash, BufOver: TBuf;
  // Tiga "jalur suara": musik, poin, dan tabrakan/game over. Dipisah agar bisa berbunyi bersamaan.
  StMusic, StPoint, StHit: PSDL_AudioStream;
  // Ready = audio berhasil dibuka. MusicMode = 0 berhenti, 1 main, 2 jeda.
  Ready: Boolean;
  MusicMode: Integer;
  // agar pesan gagal kirim suara hanya dicatat sekali
  PutFailLogged: Boolean;

{ ------------------------------------------------------------------ }
{ Sintesis                                                           }
{ ------------------------------------------------------------------ }

// Gelombang: bentuk gelombang suara. Sinus = lembut, kotak = bunyi "game retro", segitiga = lembut berwarna,
// noise = desis acak (dipakai untuk efek ledakan/tabrakan dan hi-hat).
function Gelombang(jenis: Integer; ph: Single): Single;
begin
  case jenis of
    0: Result := Sin(ph * 2 * Pi);                       { sinus }
    1: if ph < 0.5 then Result := 1 else Result := -1;   { kotak }
    2: Result := 4 * Abs(ph - 0.5) - 1;                  { segitiga }
  else
    Result := Random * 2 - 1;                            { noise }
  end;
end;

// BuatCampuranSuara: membuat lembar suara kosong (hening) sepanjang sekian detik, siap diisi nada.
function BuatCampuranSuara(seconds: Single): TMix;
var
  i: Integer;
begin
  SetLength(Result, Round(seconds * RATE));
  i := 0;
  while i <= High(Result) do
  begin
    Result[i] := 0;
    Inc(i);
  end;
end;

// BuatNada: menambahkan satu NADA ke lembar suara. t0 = detik mulai, dur = lama, f0 -> f1 = frekuensi awal ke akhir
// (meluncur naik/turun), vol = kenyaringan, jenis = bentuk gelombang. Volume meluruh agar tidak berbunyi "klik".
procedure BuatNada(var m: TMix; t0, dur, f0, f1, vol: Single; jenis: Integer);
var
  i, n, s0: Integer;
  ph, f, t, env: Single;
begin
  n := Round(dur * RATE);
  s0 := Round(t0 * RATE);
  ph := 0;
  i := 0;
  while i <= n - 1 do
  begin
    if s0 + i > High(m) then Break;
    t := i / n;
    f := f0 + (f1 - f0) * t;
    ph := Frac(ph + f / RATE);
    env := 1 - t;
    if i < 150 then env := env * (i / 150);              { hindari bunyi "klik" }
    m[s0 + i] := m[s0 + i] + Gelombang(jenis, ph) * env * vol;
    Inc(i);
  end;
end;

// UbahKeBuffer: mengubah lembar suara menjadi data 16-bit yang bisa diputar SDL (nilai dipotong agar tidak pecah).
function UbahKeBuffer(const m: TMix): TBuf;
var
  i: Integer;
  v: Single;
begin
  SetLength(Result, Length(m));
  i := 0;
  while i <= High(m) do
  begin
    v := m[i];
    if v > 1 then v := 1;
    if v < -1 then v := -1;
    Result[i] := Round(v * 30000);
    Inc(i);
  end;
end;

// BuatEfekSuara: membuat SEMUA suara game lewat kode (tanpa file audio).
procedure BuatEfekSuara;
const
  Lead: array[0..15] of Single = (
    440, 523.25, 659.25, 523.25,  440, 523.25, 659.25, 880,
    349.23, 440, 523.25, 440,     392, 493.88, 587.33, 493.88);
  Bass: array[0..3] of Single = (110, 110, 87.31, 98);
  StepT = 0.2;
var
  m: TMix;
  i: Integer;
begin
  // Bunyi poin: dua nada tinggi berurutan "ding-ding".
  m := BuatCampuranSuara(0.4);
  BuatNada(m, 0.00, 0.08, 988, 988, 0.30, 1);
  BuatNada(m, 0.07, 0.30, 1319, 1319, 0.30, 1);
  BufPoint := UbahKeBuffer(m);

  // Suara tabrakan: ledakan noise + dentuman rendah yang turun.
  m := BuatCampuranSuara(0.6);
  BuatNada(m, 0, 0.45, 0, 0, 0.55, 3);
  BuatNada(m, 0, 0.50, 200, 45, 0.60, 1);
  BufCrash := UbahKeBuffer(m);

  // Suara game over: melodi turun 4 nada, nada terakhir panjang dan makin rendah.
  m := BuatCampuranSuara(2.0);
  BuatNada(m, 0.00, 0.28, 392.0, 392.0, 0.35, 2);
  BuatNada(m, 0.30, 0.28, 329.6, 329.6, 0.35, 2);
  BuatNada(m, 0.60, 0.28, 261.6, 261.6, 0.35, 2);
  BuatNada(m, 0.90, 0.90, 196.0, 98.0, 0.40, 1);
  BufOver := UbahKeBuffer(m);

  // Musik latar: 16 langkah. Tiap langkah ada nada melodi (arpeggio), tiap 4 langkah ada nada bass,
  // langkah ganjil ada "hi-hat" (noise pendek). Ujung musik menyambung ke awal agar berulang mulus.
  m := BuatCampuranSuara(16 * StepT);
  i := 0;
  while i <= 15 do
  begin
    BuatNada(m, i * StepT, 0.18, Lead[i], Lead[i], 0.16, 2);
    if (i mod 4) = 0 then
      BuatNada(m, i * StepT, 0.70, Bass[i div 4], Bass[i div 4], 0.16, 1);
    if (i mod 2) = 1 then
      BuatNada(m, i * StepT, 0.04, 0, 0, 0.07, 3);
    Inc(i);
  end;
  BufMusic := UbahKeBuffer(m);
end;

{ ------------------------------------------------------------------ }
{ Pemutaran                                                          }
{ ------------------------------------------------------------------ }

// CatatLogSuara: menulis satu baris catatan ke file sound_log.teks (di folder game).
// Dipakai untuk melihat apakah audio berhasil dibuka, tanpa perlu jendela konsol.
procedure CatatLogSuara(const Pesan: string);
var
  f: TextFile;
begin
  AssignFile(f, 'sound_log.txt');
  {$I-}
  if FileExists('sound_log.txt') then Append(f) else Rewrite(f);
  {$I+}
  if IOResult <> 0 then Exit;
  WriteLn(f, Pesan);
  CloseFile(f);
end;

// BukaAliranSuara: membuka satu jalur suara ke speaker default (mono, 16-bit) lalu mengaktifkannya.
function BukaAliranSuara: PSDL_AudioStream;
var
  spec: TSDL_AudioSpec;
begin
  spec.format := SDL_AUDIO_S16;
  spec.channels := 1;
  spec.freq := RATE;
  Result := SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, @spec, nil, nil);
  if Result <> nil then SDL_ResumeAudioStreamDevice(Result);
end;

// Play: mengirim data suara ke sebuah jalur. interrupt = True memotong suara lama di jalur itu;
// False = diantrekan, diputar setelah suara sebelumnya selesai.
procedure Play(st: PSDL_AudioStream; const b: TBuf; interrupt: Boolean);
begin
  if (not Ready) or (st = nil) or (Length(b) = 0) then Exit;
  if interrupt then SDL_ClearAudioStream(st);
  // kirim data suara ke jalur; bila gagal, catat alasannya sekali saja
  if (not SDL_PutAudioStreamData(st, @b[0], Length(b) * SizeOf(SmallInt))) and (not PutFailLogged) then
  begin
    PutFailLogged := True;
    CatatLogSuara('Gagal mengirim suara: ' + string(SDL_GetError));
  end;
end;

// InisialisasiSuara: menyalakan audio, membuat semua suara, dan membuka 3 jalur suara. Jika gagal, game tetap jalan tanpa suara.
// Hasil tiap langkah dicatat di sound_log.teks.
procedure InisialisasiSuara;
begin
  Ready := False;
  MusicMode := 0;
  PutFailLogged := False;
  CatatLogSuara('--- SoundInit ---');
  // 1) nyalakan sistem audio SDL
  if not SDL_InitSubSystem(SDL_INIT_AUDIO) then
  begin
    CatatLogSuara('GAGAL SDL_InitSubSystem(AUDIO): ' + string(SDL_GetError));
    Exit;
  end;
  CatatLogSuara('Audio SDL menyala. Driver: ' + string(SDL_GetCurrentAudioDriver));
  // 2) buat semua suara (musik, poin, tabrakan, game over)
  BuatEfekSuara;
  // 3) buka tiga jalur suara ke speaker default
  StMusic := BukaAliranSuara;
  StPoint := BukaAliranSuara;
  StHit := BukaAliranSuara;
  CatatLogSuara('Jalur suara dibuka: musik=' + BoolToStr(StMusic <> nil, True) +
       ' poin=' + BoolToStr(StPoint <> nil, True) +
       ' tabrak=' + BoolToStr(StHit <> nil, True));
  Ready := (StMusic <> nil) and (StPoint <> nil) and (StHit <> nil);
  if not Ready then
  begin
    CatatLogSuara('GAGAL membuka audio: ' + string(SDL_GetError));
    Exit;
  end;
  SDL_PauseAudioStreamDevice(StMusic);   // musik baru jalan saat bermain
  // 4) bunyi tes: "ding-ding" sekali saat game dibuka, tanda audio bekerja
  Play(StPoint, BufPoint, True);
  CatatLogSuara('Audio siap. Bunyi tes dikirim.');
end;

// MatikanSuara: menutup semua jalur suara saat game keluar.
procedure MatikanSuara;
begin
  if not Ready then Exit;
  Ready := False;
  SDL_DestroyAudioStream(StMusic);
  SDL_DestroyAudioStream(StPoint);
  SDL_DestroyAudioStream(StHit);
end;

// PerbaruiSuara: dipanggil tiap GambarBingkai. Jika antrean musik tinggal sedikit, musik diisi lagi sehingga terus berulang.
procedure PerbaruiSuara;
begin
  if (not Ready) or (MusicMode <> 1) then Exit;
  { isi ulang sebelum antrean habis agar musik tidak putus }
  if SDL_GetAudioStreamQueued(StMusic) < (Length(BufMusic) * SizeOf(SmallInt)) div 2 then
    Play(StMusic, BufMusic, False);
end;

// AturMusik: mengatur musik latar. 1 = mulai/lanjut, 2 = jeda (saat pause), 0 = berhenti dan dikosongkan.
procedure AturMusik(mode: Integer);
begin
  if (not Ready) or (mode = MusicMode) then Exit;
  case mode of
    1: begin
         if MusicMode = 0 then
         begin
           SDL_ClearAudioStream(StMusic);
           Play(StMusic, BufMusic, False);
         end;
         SDL_ResumeAudioStreamDevice(StMusic);
       end;
    2: SDL_PauseAudioStreamDevice(StMusic);
  else
    begin
      SDL_ClearAudioStream(StMusic);
      SDL_PauseAudioStreamDevice(StMusic);
    end;
  end;
  MusicMode := mode;
end;

// SuaraPoin: bunyi saat mendapat poin (memotong bunyi poin sebelumnya agar tidak menumpuk).
procedure SuaraPoin;
begin
  Play(StPoint, BufPoint, True);
end;

// SuaraTabrakan: bunyi saat menabrak.
procedure SuaraTabrakan;
begin
  Play(StHit, BufCrash, True);
end;

// SuaraGameOver: melodi game over.
procedure SuaraGameOver;
begin
  { tanpa interrupt: diputar setelah suara tabrakan selesai }
  Play(StHit, BufOver, False);
end;

end.
