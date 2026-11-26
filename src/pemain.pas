{ ==========================================================================
  player.pas  -  Mobil pemain: posisi, kecepatan, gerak kiri/kanan, gambar
  Mobil tetap di bagian bawah layar; dunia (jalan) yang bergerak turun
  sesuai Plr.Speed (px/detik).
  ========================================================================== }
unit pemain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, grafis;

const
  // Ukuran mobil pemain, posisi tetap di bagian bawah layar (POSISI_ATAS_MOBIL), dan kecepatan maksimum.
  LEBAR_MOBIL_PEMAIN = 54;
  TINGGI_MOBIL_PEMAIN = 100;
  POSISI_ATAS_MOBIL = 520;           { koordinat Y bagian depan mobil }
  KECEPATAN_MAKS = 520.0;          { px/detik, sekitar 140 km/j }

type
  // TMobilPemain: data mobil pemain: posisi (X,Y), ukuran (W,H), kecepatan, sisa waktu klakson,
  // sisa waktu kebal, sisa waktu getar, serta statusKecepatan sedang mengerem/menggas.
  TMobilPemain = record
    X, Y, W, H: Single;
    Speed: Single;            { kecepatan maju (px/detik) }
    Klakson: Single;             { sisa waktu efek klakson }
    Invul: Single;            { kebal sementara setelah tabrakan }
    Shake: Single;            { getaran setelah tabrakan }
    Braking, Gassing: Boolean;
  end;

var
  // MobilPemain = mobil pemain (satu-satunya, dipakai bersama oleh semua unit).
  MobilPemain: TMobilPemain;

procedure InisialisasiPemain;
procedure PerbaruiPemain(SelangWaktu: Single; kiri, kanan, gas, rem, klakson: Boolean);
procedure GambarPemain;
procedure PemainMenabrak;
function KecepatanPemainKmh: Integer;
function PemainBerhenti: Boolean;
function TitikTengahPemain: Single;
function JalurPemain: Integer;

implementation

// InisialisasiPemain: menaruh mobil di jalur kanan, bagian bawah layar, dalam keadaan diam dan normal.
procedure InisialisasiPemain;
begin
  MobilPemain.W := LEBAR_MOBIL_PEMAIN;
  MobilPemain.H := TINGGI_MOBIL_PEMAIN;
  MobilPemain.X := POSISI_JALAN + LEBAR_JALUR + (LEBAR_JALUR - LEBAR_MOBIL_PEMAIN) / 2;
  MobilPemain.Y := POSISI_ATAS_MOBIL;
  MobilPemain.Speed := 0;
  MobilPemain.Klakson := 0;
  MobilPemain.Invul := 0;
  MobilPemain.Shake := 0;
  MobilPemain.Braking := False;
  MobilPemain.Gassing := False;
end;

// PerbaruiPemain: memperbarui mobil tiap GambarBingkai berdasarkan tombol yang ditekan (belok, gas, rem, klakson).
procedure PerbaruiPemain(SelangWaktu: Single; kiri, kanan, gas, rem, klakson: Boolean);
var
  lat, k: Single;
begin
  MobilPemain.Gassing := gas and (not rem);
  MobilPemain.Braking := rem;

  // Kecepatan: gas menambah, melepas gas memperlambat pelan-pelan, rem memperlambat cepat.
  // Hasilnya dibatasi 0 sampai KECEPATAN_MAKS.
  if gas and (not rem) then
    MobilPemain.Speed := MobilPemain.Speed + 170 * SelangWaktu
  else if not rem then
    MobilPemain.Speed := MobilPemain.Speed - 45 * SelangWaktu;
  if rem then
    MobilPemain.Speed := MobilPemain.Speed - 480 * SelangWaktu;
  MobilPemain.Speed := BatasiNilai(MobilPemain.Speed, 0, KECEPATAN_MAKS);

  // Belok kiri/kanan: makin cepat mobil melaju, makin responsif beloknya. Posisi dibatasi di dalam jalan.
  k := MobilPemain.Speed / 200;
  if k > 1 then k := 1;
  lat := 0;
  if kiri then lat := lat - 1;
  if kanan then lat := lat + 1;
  MobilPemain.X := MobilPemain.X + lat * 300 * (0.45 + 0.55 * k) * SelangWaktu;
  MobilPemain.X := BatasiNilai(MobilPemain.X, POSISI_JALAN + 4, BATAS_KANAN_JALAN - LEBAR_MOBIL_PEMAIN - 4);

  // Klakson: tampilan "TIN TIN!" menyala 0,3 detik. Lalu kurangi pewaktu klakson, kebal, dan getar.
  if klakson then MobilPemain.Klakson := 0.3;
  if MobilPemain.Klakson > 0 then MobilPemain.Klakson := MobilPemain.Klakson - SelangWaktu;
  if MobilPemain.Invul > 0 then MobilPemain.Invul := MobilPemain.Invul - SelangWaktu;
  if MobilPemain.Shake > 0 then MobilPemain.Shake := MobilPemain.Shake - SelangWaktu;
end;

// PemainMenabrak: efek tabrakan pada mobil: kecepatan jadi 20%, kebal 1,8 detik, dan getar 0,35 detik.
procedure PemainMenabrak;
begin
  MobilPemain.Speed := MobilPemain.Speed * 0.2;
  MobilPemain.Invul := 1.8;
  MobilPemain.Shake := 0.35;
end;

// GambarPemain: menggambar mobil pemain (merah) memakai GambarMobil, plus lampu rem, tulisan klakson, dan efek getar/kedip.
procedure GambarPemain;
var
  sx: Single;
begin
  // saat kebal, mobil berkedip (tidak digambar sebagian waktu) agar pemain tahu sedang kebal
  if (MobilPemain.Invul > 0) and ((Trunc(MobilPemain.Invul * 10) mod 2) = 1) then Exit;
  sx := 0;
  // efek getar setelah tabrakan: mobil digeser acak beberapa piksel ke kiri/kanan
  if MobilPemain.Shake > 0 then sx := (Random(7) - 3);
  GambarMobil(MobilPemain.X + sx, MobilPemain.Y, MobilPemain.W, MobilPemain.H, 230, 40, 70, 0);
  // lampu rem merah menyala di belakang mobil saat mengerem
  if MobilPemain.Braking and (MobilPemain.Speed > 1) then
  begin
    GambarKotak(MobilPemain.X + sx + 2, MobilPemain.Y + MobilPemain.H - 8, 16, 8, 255, 70, 70);
    GambarKotak(MobilPemain.X + sx + MobilPemain.W - 18, MobilPemain.Y + MobilPemain.H - 8, 16, 8, 255, 70, 70);
  end;
  if MobilPemain.Klakson > 0 then
  begin
    GambarTeksTengah(MobilPemain.X + MobilPemain.W / 2, MobilPemain.Y - 34, 'TIN TIN!', 2, 250, 204, 21);
  end;
end;

// KecepatanPemainKmh: kecepatan mobil dalam km/jam untuk ditampilkan dan dicocokkan dengan batas kecepatan.
function KecepatanPemainKmh: Integer;
begin
  Result := Round(MobilPemain.Speed * KONVERSI_KE_KMJAM);
end;

// PemainBerhenti: True bila mobil dianggap berhenti (di bawah sekitar 5 km/j). Dipakai untuk menilai lampu merah, STOP, dan ZebraCross.
function PemainBerhenti: Boolean;
begin
  Result := MobilPemain.Speed < 18;        { kurang dari sekitar 5 km/j }
end;

// TitikTengahPemain: titik tengah mobil secara horizontal.
function TitikTengahPemain: Single;
begin
  Result := MobilPemain.X + MobilPemain.W / 2;
end;

// JalurPemain: mobil sedang di jalur mana (0 = kiri, 1 = kanan).
function JalurPemain: Integer;
begin
  if TitikTengahPemain < POSISI_JALAN + LEBAR_JALUR then
    Result := 0
  else
    Result := 1;
end;

end.
