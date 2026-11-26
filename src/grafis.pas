{ ==========================================================================
  gfx.pas  -  Konstanta layar/jalan + fungsi gambar dasar (kotak, teks, mobil)
  Semua visual dibuat dari bentuk geometris SDL3 (pixel art tanpa file gambar).
  ========================================================================== }
unit grafis;

{$mode objfpc}{$H+}

interface

uses
  sdl3;

const
  // Ukuran jendela game dalam piksel (lebar x tinggi).
  LEBAR_LAYAR = 1280;
  TINGGI_LAYAR = 720;

  // Letak jalan di layar: POSISI_JALAN = tepi kiri, LEBAR_JALAN = lebar jalan, BATAS_KANAN_JALAN = tepi kanan.
  // Jalan punya 2 jalur, tiap jalur selebar LEBAR_JALUR.
  POSISI_JALAN = 420;            { sisi kiri area jalan yang bisa dilalui }
  LEBAR_JALAN = 440;            { lebar jalan (2 jalur) }
  BATAS_KANAN_JALAN = 860;            { sisi kanan jalan = ROAD_X + ROAD_W }
  LEBAR_JALUR = 220;            { lebar satu jalur }

  // Pengubah kecepatan dunia game (piksel/detik) menjadi angka km/jam yang tampil di layar.
  KONVERSI_KE_KMJAM = 0.27;     { konversi kecepatan dunia (px/detik) ke km/j }

var
  // Perender = "kanvas" SDL3 tempat semua gambar dilukis. Dipakai bersama oleh semua unit.
  Perender: PSDL_Renderer;

function BatasiNilai(v, lo, hi: Single): Single;
function UbahKecerahan(c: Byte; d: Integer): Byte;

procedure GambarKotak(x, y, w, h: Single; r, g, b: Byte; a: Byte = 255);
procedure GambarBingkai(x, y, w, h, t: Single; r, g, b: Byte);

procedure GambarTeks(x, y: Single; const s: string; scale: Single; r, g, b: Byte);
procedure GambarTeksTengah(cx, y: Single; const s: string; scale: Single; r, g, b: Byte);
function LebarTeks(const s: string; scale: Single): Single;
function BungkusTeks(x, y: Single; maxChars: Integer; const s: string; scale: Single;
  r, g, b: Byte; draw: Boolean): Integer;

procedure GambarMobil(x, y, w, h: Single; r, g, b: Byte; jenis: Integer);

implementation

// BatasiNilai: membatasi nilai v agar selalu di antara lo (minimum) dan hi (maksimum).
// Dipakai supaya mobil tidak keluar dari jalan dan kecepatan tidak melebihi batas.
function BatasiNilai(v, lo, hi: Single): Single;
begin
  if v < lo then
    Result := lo
  else if v > hi then
    Result := hi
  else
    Result := v;
end;

// UbahKecerahan: membuat satu kanal warna (0-255) lebih terang (d positif) atau lebih gelap (d negatif).
// Dipakai untuk efek sorotan dan bayangan pada bodi mobil.
function UbahKecerahan(c: Byte; d: Integer): Byte;
var
  v: Integer;
begin
  v := c + d;
  if v < 0 then v := 0;
  if v > 255 then v := 255;
  Result := v;
end;

// GambarKotak: menggambar KOTAK berwarna penuh di posisi (x,y) berukuran w x h.
// Ini "kuas" dasar game: jalan, mobil, rambu, dan HUD semuanya disusun dari kotak.
// Parameter a = transparansi (255 = solid, makin kecil makin tembus pandang).
procedure GambarKotak(x, y, w, h: Single; r, g, b: Byte; a: Byte);
var
  rc: TSDL_FRect;
begin
  // pilih warna kuas
  SDL_SetRenderDrawColor(Perender, r, g, b, a);
  // isi data persegi panjang yang akan digambar (posisi dan ukuran)
  rc.x := x;
  rc.y := y;
  rc.w := w;
  rc.h := h;
  // lukis kotak terisi ke layar
  SDL_RenderFillRect(Perender, @rc);
end;

// GambarBingkai: menggambar BINGKAI (garis tepi) kotak dengan ketebalan t.
// Dibuat dari 4 kotak tipis: atas, bawah, kiri, kanan.
procedure GambarBingkai(x, y, w, h, t: Single; r, g, b: Byte);
begin
  GambarKotak(x, y, w, t, r, g, b);
  GambarKotak(x, y + h - t, w, t, r, g, b);
  GambarKotak(x, y, t, h, r, g, b);
  GambarKotak(x + w - t, y, t, h, r, g, b);
end;

{ Teks memakai font debug bawaan SDL3 (8x8 piksel, ASCII saja) }
// GambarTeks: menulis teks di posisi (x,y). scale = pembesaran huruf, (r,g,b) = warna teks.
// Teks diberi bayangan hitam tipis supaya mudah dibaca di atas gambar apa pun.
procedure GambarTeks(x, y: Single; const s: string; scale: Single; r, g, b: Byte);
begin
  if s = '' then Exit;
  // perbesar skala agar huruf 8x8 piksel tampil lebih besar
  SDL_SetRenderScale(Perender, scale, scale);
  // tulis dulu teks hitam yang digeser sedikit (efek bayangan)
  SDL_SetRenderDrawColor(Perender, 0, 0, 0, 255);
  SDL_RenderDebugText(Perender, (x + scale) / scale, (y + scale) / scale, PAnsiChar(s));
  // lalu tulis teks utama berwarna di atas bayangan
  SDL_SetRenderDrawColor(Perender, r, g, b, 255);
  SDL_RenderDebugText(Perender, x / scale, y / scale, PAnsiChar(s));
  // kembalikan skala ke normal agar gambar lain tidak ikut membesar
  SDL_SetRenderScale(Perender, 1.0, 1.0);
end;

// LebarTeks: menghitung lebar teks dalam piksel (tiap huruf 8 piksel x skala).
// Dipakai untuk menengahkan teks.
function LebarTeks(const s: string; scale: Single): Single;
begin
  Result := Length(s) * 8 * scale;
end;

// GambarTeksTengah: menulis teks RATA TENGAH terhadap titik cx (geser ke kiri setengah lebar teks).
procedure GambarTeksTengah(cx, y: Single; const s: string; scale: Single; r, g, b: Byte);
begin
  GambarTeks(cx - LebarTeks(s, scale) / 2, y, s, scale, r, g, b);
end;

{ Pembungkus kata. draw=False hanya menghitung jumlah baris. }
// BungkusTeks: memotong kalimat panjang menjadi beberapa baris (maksimal maxChars huruf per baris).
// Jika draw = True teks digambar; jika False hanya menghitung jumlah baris (untuk menentukan tinggi panel).
// Hasil fungsi = jumlah baris.
function BungkusTeks(x, y: Single; maxChars: Integer; const s: string; scale: Single;
  r, g, b: Byte; draw: Boolean): Integer;
var
  baris, kata: string;
  i, jumlahBaris: Integer;
  tinggiBaris: Single;

  procedure Flush;
  begin
    if draw then
      GambarTeks(x, y + jumlahBaris * tinggiBaris, baris, scale, r, g, b);
    Inc(jumlahBaris);
  end;

begin
  // tinggiBaris = tinggi satu baris. Lalu kalimat dibaca huruf demi huruf; setiap spasi menandai satu kata selesai.
  // Kata ditambahkan ke baris saat ini, atau memulai baris baru jika sudah melebihi maxChars.
  tinggiBaris := 8 * scale + 6;
  baris := '';
  kata := '';
  jumlahBaris := 0;
  i := 1;
  while i <= Length(s) + 1 do
  begin
    if (i > Length(s)) or (s[i] = ' ') then
    begin
      if baris = '' then
        baris := kata
      else if Length(baris) + 1 + Length(kata) > maxChars then
      begin
        Flush;
        baris := kata;
      end
      else
        baris := baris + ' ' + kata;
      kata := '';
    end
    else
      kata := kata + s[i];
    Inc(i);
  end;
  if baris <> '' then Flush;
  Result := jumlahBaris;
end;

{ Mobil tampak atas, bagian depan menghadap ke atas.
  kind: 0 = sport (garis putih), 1 = sedan, 2 = van/truk, 3 = mobil kecil }
// GambarMobil: BAGIAN INI MEMBUAT KARAKTER MOBIL.
// Mobil digambar dari kotak-kotak (GambarKotak): bayangan, roda, bodi, kaca/detail, dan lampu.
// Dipakai untuk mobil pemain maupun semua mobil NPC; (r,g,b) = warna bodi, jenis = model mobil.
procedure GambarMobil(x, y, w, h: Single; r, g, b: Byte; jenis: Integer);
begin
  // 1) Bayangan: kotak hitam transparan yang digeser sedikit agar mobil tampak timbul dari jalan.
  GambarKotak(x + 4, y + 5, w, h, 0, 0, 0, 70);
  // 2) Roda: 4 kotak gelap kecil di sisi kiri dan kanan bodi (2 depan, 2 belakang).
  GambarKotak(x - 3, y + h * 0.14, 5, h * 0.2, 15, 15, 20);
  GambarKotak(x + w - 2, y + h * 0.14, 5, h * 0.2, 15, 15, 20);
  GambarKotak(x - 3, y + h * 0.66, 5, h * 0.2, 15, 15, 20);
  GambarKotak(x + w - 2, y + h * 0.66, 5, h * 0.2, 15, 15, 20);
  // 3) Bodi: kotak utama berwarna (r,g,b). Sisi kiri dibuat lebih terang, sisi kanan lebih gelap,
  // dan ada garis gelap di bagian depan, supaya terlihat seperti 3D.
  GambarKotak(x, y, w, h, r, g, b);
  GambarKotak(x, y, 4, h, UbahKecerahan(r, 45), UbahKecerahan(g, 45), UbahKecerahan(b, 45));
  GambarKotak(x + w - 4, y, 4, h, UbahKecerahan(r, -50), UbahKecerahan(g, -50), UbahKecerahan(b, -50));
  GambarKotak(x + 3, y, w - 6, 5, UbahKecerahan(r, -60), UbahKecerahan(g, -60), UbahKecerahan(b, -60));

  // 4) Detail sesuai model: 0 = sport (garis putih di tengah + kaca biru), 1 = sedan,
  // 2 = van/truk (atap panjang), selain itu = mobil kecil. Kaca digambar sebagai kotak biru gelap.
  case jenis of
    0:
      begin
        GambarKotak(x + w * 0.42, y, w * 0.16, h, 245, 245, 245);
        GambarKotak(x + w * 0.16, y + h * 0.30, w * 0.68, h * 0.2, 35, 70, 140);
        GambarKotak(x + w * 0.22, y + h * 0.33, w * 0.22, 4, 150, 190, 240);
        GambarKotak(x + w * 0.16, y + h * 0.66, w * 0.68, h * 0.1, 35, 70, 140);
      end;
    1:
      begin
        GambarKotak(x + w * 0.14, y + h * 0.26, w * 0.72, h * 0.14, 40, 55, 85);
        GambarKotak(x + w * 0.18, y + h * 0.40, w * 0.64, h * 0.26, UbahKecerahan(r, 30), UbahKecerahan(g, 30), UbahKecerahan(b, 30));
        GambarKotak(x + w * 0.14, y + h * 0.66, w * 0.72, h * 0.1, 40, 55, 85);
      end;
    2:
      begin
        GambarKotak(x + w * 0.12, y + h * 0.10, w * 0.76, h * 0.14, 40, 55, 85);
        GambarKotak(x + 4, y + h * 0.28, w - 8, h * 0.64, UbahKecerahan(r, 55), UbahKecerahan(g, 55), UbahKecerahan(b, 55));
        GambarKotak(x + 4, y + h * 0.28, w - 8, 3, UbahKecerahan(r, 90), UbahKecerahan(g, 90), UbahKecerahan(b, 90));
        GambarKotak(x + w * 0.45, y + h * 0.28, 3, h * 0.64, UbahKecerahan(r, 10), UbahKecerahan(g, 10), UbahKecerahan(b, 10));
      end;
  else
    begin
      GambarKotak(x + w * 0.16, y + h * 0.28, w * 0.68, h * 0.16, 45, 60, 90);
      GambarKotak(x + w * 0.16, y + h * 0.62, w * 0.68, h * 0.12, 45, 60, 90);
    end;
  end;

  // 5) Lampu: kuning di bagian depan (atas), merah di bagian belakang (bawah).
  GambarKotak(x + 3, y + 2, w * 0.2, 5, 255, 240, 150);
  GambarKotak(x + w - 3 - w * 0.2, y + 2, w * 0.2, 5, 255, 240, 150);
  GambarKotak(x + 3, y + h - 6, w * 0.2, 5, 200, 25, 25);
  GambarKotak(x + w - 3 - w * 0.2, y + h - 6, w * 0.2, 5, 200, 25, 25);
end;

end.
