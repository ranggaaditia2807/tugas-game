{ ==========================================================================
  sdl3.pas  -  Binding SDL3 minimal untuk Free Pascal (hanya yang dipakai game)
  Semua fungsi memakai API SDL3 (bukan SDL2). Membutuhkan SDL3.dll (Windows).
  ========================================================================== }
unit sdl3;

{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

const
  // Nama pustaka SDL3 yang dipanggil game (SDL3.dll di Windows).
  SDL3_LIB = 'SDL3';

  // Bendera untuk menyalakan sistem audio dan video SDL.
  SDL_INIT_AUDIO = $00000010;
  SDL_INIT_VIDEO = $00000020;

  { Audio SDL3 }
  // Pengaturan audio: format suara 16-bit, dan "perangkat default" = speaker bawaan komputer.
  SDL_AUDIO_S16 = $8010;                      { signed 16-bit little-endian }
  SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK = $FFFFFFFF;

  // Mode pencampuran warna: BLEND dipakai agar kotak transparan (alpha) bisa tembus pandang.
  SDL_BLENDMODE_NONE  = $00000000;
  SDL_BLENDMODE_BLEND = $00000001;

  // Kode kejadian: tombol tutup jendela, tombol keyboard ditekan, dan dilepas.
  SDL_EVENT_QUIT     = $100;
  SDL_EVENT_KEY_DOWN = $300;
  SDL_EVENT_KEY_UP   = $301;

  // Kode tombol keyboard yang dipakai game: huruf A D H P S W, Enter, Esc, Spasi, dan tombol panah.
  { Scancode SDL3 (sama dengan USB HID) }
  SC_A      = 4;
  SC_D      = 7;
  SC_H      = 11;
  SC_P      = 19;
  SC_S      = 22;
  SC_W      = 26;
  SC_RETURN = 40;
  SC_ESC    = 41;
  SC_SPACE  = 44;
  SC_RIGHT  = 79;
  SC_LEFT   = 80;
  SC_DOWN   = 81;
  SC_UP     = 82;

type
  // Tipe data SDL: Window (jendela), Renderer (kanvas gambar), AudioStream (aliran suara).
  TSDL_Window = record end;
  PSDL_Window = ^TSDL_Window;
  TSDL_Renderer = record end;
  PSDL_Renderer = ^TSDL_Renderer;

  TSDL_AudioStream = record end;
  PSDL_AudioStream = ^TSDL_AudioStream;

  // AudioSpec: format suara yang diminta (jenis data, jumlah kanal, dan frekuensi sampel).
  TSDL_AudioSpec = record
    format: LongInt;      { SDL_AudioFormat (enum 32-bit) }
    channels: LongInt;
    freq: LongInt;
  end;
  PSDL_AudioSpec = ^TSDL_AudioSpec;

  // FRect: persegi panjang (x, y, lebar, tinggi) untuk menggambar kotak.
  TSDL_FRect = record
    x, y, w, h: Single;
  end;
  PSDL_FRect = ^TSDL_FRect;

  { SDL_KeyboardEvent (SDL3) }
  // Data kejadian keyboard dan Event: wadah semua jenis kejadian dari SDL (tombol, tutup jendela, dll).
  TSDL_KeyboardEvent = record
    typ: UInt32;
    reserved: UInt32;
    timestamp: UInt64;
    windowID: UInt32;
    which: UInt32;
    scancode: UInt32;
    key: UInt32;
    modk: UInt16;
    raw: UInt16;
    down: ByteBool;
    rep: ByteBool;
  end;

  { SDL_Event: union berukuran 128 byte }
  TSDL_Event = record
    case Integer of
      0: (typ: UInt32);
      1: (kb: TSDL_KeyboardEvent);
      2: (pad: array[0..127] of Byte);
  end;

  // Daftar status semua tombol (True = sedang ditahan). Dipakai untuk gas, rem, dan belok.
  TKeyState = array[0..511] of ByteBool;
  PKeyState = ^TKeyState;

// FUNGSI SDL: menyalakan/mematikan SDL, mengambil pesan error, dan menyalakan sub-sistem audio.
function SDL_Init(flags: UInt32): ByteBool; cdecl; external SDL3_LIB name 'SDL_Init';
procedure SDL_Quit; cdecl; external SDL3_LIB name 'SDL_Quit';
function SDL_GetError: PAnsiChar; cdecl; external SDL3_LIB name 'SDL_GetError';
function SDL_InitSubSystem(flags: UInt32): ByteBool; cdecl; external SDL3_LIB name 'SDL_InitSubSystem';

{ --- Audio --- }
// FUNGSI AUDIO: membuka aliran suara, memutar/menjeda, mengirim data suara, mengosongkan, dan menutupnya.
function SDL_OpenAudioDeviceStream(devid: UInt32; spec: PSDL_AudioSpec;
  callback: Pointer; userdata: Pointer): PSDL_AudioStream;
  cdecl; external SDL3_LIB name 'SDL_OpenAudioDeviceStream';
function SDL_GetCurrentAudioDriver: PAnsiChar; cdecl; external SDL3_LIB name 'SDL_GetCurrentAudioDriver';
function SDL_ResumeAudioStreamDevice(stream: PSDL_AudioStream): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_ResumeAudioStreamDevice';
function SDL_PauseAudioStreamDevice(stream: PSDL_AudioStream): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_PauseAudioStreamDevice';
function SDL_PutAudioStreamData(stream: PSDL_AudioStream; buf: Pointer; len: LongInt): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_PutAudioStreamData';
function SDL_GetAudioStreamQueued(stream: PSDL_AudioStream): LongInt;
  cdecl; external SDL3_LIB name 'SDL_GetAudioStreamQueued';
function SDL_ClearAudioStream(stream: PSDL_AudioStream): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_ClearAudioStream';
procedure SDL_DestroyAudioStream(stream: PSDL_AudioStream);
  cdecl; external SDL3_LIB name 'SDL_DestroyAudioStream';

// FUNGSI JENDELA: membuat jendela + kanvas gambar, dan menghancurkannya saat game selesai.
function SDL_CreateWindowAndRenderer(title: PAnsiChar; width, height: LongInt;
  window_flags: UInt64; var window: PSDL_Window; var renderer: PSDL_Renderer): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_CreateWindowAndRenderer';
procedure SDL_DestroyRenderer(renderer: PSDL_Renderer); cdecl; external SDL3_LIB name 'SDL_DestroyRenderer';
procedure SDL_DestroyWindow(window: PSDL_Window); cdecl; external SDL3_LIB name 'SDL_DestroyWindow';

// FUNGSI MENGGAMBAR: vsync, warna kuas, skala, hapus layar, kotak, garis, teks, dan tampilkan hasil ke layar.
function SDL_SetRenderVSync(renderer: PSDL_Renderer; vsync: LongInt): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_SetRenderVSync';
function SDL_SetRenderDrawColor(renderer: PSDL_Renderer; r, g, b, a: UInt8): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_SetRenderDrawColor';
function SDL_SetRenderDrawBlendMode(renderer: PSDL_Renderer; blendMode: UInt32): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_SetRenderDrawBlendMode';
function SDL_SetRenderScale(renderer: PSDL_Renderer; scaleX, scaleY: Single): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_SetRenderScale';
function SDL_RenderClear(renderer: PSDL_Renderer): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_RenderClear';
function SDL_RenderFillRect(renderer: PSDL_Renderer; rect: PSDL_FRect): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_RenderFillRect';
function SDL_RenderRect(renderer: PSDL_Renderer; rect: PSDL_FRect): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_RenderRect';
function SDL_RenderLine(renderer: PSDL_Renderer; x1, y1, x2, y2: Single): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_RenderLine';
function SDL_RenderDebugText(renderer: PSDL_Renderer; x, y: Single; str: PAnsiChar): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_RenderDebugText';
function SDL_RenderPresent(renderer: PSDL_Renderer): ByteBool;
  cdecl; external SDL3_LIB name 'SDL_RenderPresent';

// FUNGSI INPUT & WAKTU: membaca kejadian, status keyboard, jeda singkat, dan jam (milidetik).
function SDL_PollEvent(var event: TSDL_Event): ByteBool; cdecl; external SDL3_LIB name 'SDL_PollEvent';
function SDL_GetKeyboardState(numkeys: PLongInt): PKeyState; cdecl; external SDL3_LIB name 'SDL_GetKeyboardState';

procedure SDL_Delay(ms: UInt32); cdecl; external SDL3_LIB name 'SDL_Delay';
function SDL_GetTicks: UInt64; cdecl; external SDL3_LIB name 'SDL_GetTicks';

implementation

end.
