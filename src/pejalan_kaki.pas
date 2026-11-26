{ ==========================================================================
  pedestrian.pas  -  Zebra cross + pejalan kaki yang menyeberang
  Aturan: pemain harus berhenti dan memberi jalan selama ada pejalan kaki
  di jalan. Tidak memberi jalan = penalti, menabrak = penalti berat.
  ========================================================================== }
unit pejalan_kaki;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, grafis, pemain, skor;

const
  // Jumlah pejalan kaki per ZebraCross cross dan ukuran gambar satu pejalan kaki.
  MAKS_PEJALAN_KAKI = 3;
  LEBAR_PEJALAN_KAKI = 18;
  TINGGI_PEJALAN_KAKI = 20;

type
  // TPejalanKaki: data satu pejalan kaki: aktif, sedang berjalan, posisi, kecepatan, jeda sebelum mulai,
  // arah (1 = ke kanan, -1 = ke kiri), dan warna baju.
  TPejalanKaki = record
    Aktif, Walking: Boolean;
    X, OffY, Speed, Delay: Single;
    Dir: Integer;             { 1 = ke kanan, -1 = ke kiri }
    Shirt: Integer;
  end;

  // TZebraCross: data ZebraCross cross: posisi, tinggi, apakah sudah dinilai, dan berapa lama pemain menunggu.
  TZebraCross = record
    Aktif, SudahDinilai, Triggered: Boolean;
    Y, H, LamaMenunggu: Single;     { Y = tengah zebra cross di layar }
  end;

var
  // ZebraCross = ZebraCross cross yang aktif; DaftarPejalanKaki = para pejalan kaki; JumlahMemberiJalan = berapa kali pemain memberi jalan dengan benar.
  ZebraCross: TZebraCross;
  DaftarPejalanKaki: array[0..MAKS_PEJALAN_KAKI - 1] of TPejalanKaki;
  JumlahMemberiJalan: Integer;        { jumlah kali pemain memberi jalan dengan benar }

procedure InisialisasiPejalanKaki;
procedure MunculkanZebraCross(y: Single);
procedure PerbaruiPejalanKaki(SelangWaktu: Single);
procedure GambarZebraCross;
procedure GambarPejalanKaki;
function PejalanKakiDiJalan: Boolean;
function PersegiPejalanKaki(i: Integer; var rx, ry, rw, rh: Single): Boolean;

implementation

// InisialisasiPejalanKaki: menghapus ZebraCross cross dan semua pejalan kaki di awal level.
procedure InisialisasiPejalanKaki;
var
  i: Integer;
begin
  ZebraCross.Aktif := False;
  i := 0;
  while i <= MAKS_PEJALAN_KAKI - 1 do
  begin
    DaftarPejalanKaki[i].Aktif := False;
    Inc(i);
  end;
  JumlahMemberiJalan := 0;
end;

// MunculkanZebraCross: memunculkan ZebraCross cross di posisi y beserta 3 pejalan kaki yang menunggu di tepi jalan
// (semuanya menyeberang ke arah yang sama, dengan jeda berbeda-beda).
procedure MunculkanZebraCross(y: Single);
var
  i, d: Integer;
begin
  ZebraCross.Aktif := True;
  ZebraCross.SudahDinilai := False;
  ZebraCross.Triggered := False;
  ZebraCross.Y := y;
  ZebraCross.H := 70;
  ZebraCross.LamaMenunggu := 0;
  if Random(2) = 0 then d := 1 else d := -1;
  i := 0;
  while i <= MAKS_PEJALAN_KAKI - 1 do
  begin
    DaftarPejalanKaki[i].Aktif := True;
    DaftarPejalanKaki[i].Walking := False;
    DaftarPejalanKaki[i].Speed := 105 + Random(30);
    DaftarPejalanKaki[i].Delay := i * 0.9;
    DaftarPejalanKaki[i].Dir := d;
    if DaftarPejalanKaki[i].Dir > 0 then
      DaftarPejalanKaki[i].X := POSISI_JALAN - 24 - LEBAR_PEJALAN_KAKI / 2
    else
      DaftarPejalanKaki[i].X := BATAS_KANAN_JALAN + 24 - LEBAR_PEJALAN_KAKI / 2;
    DaftarPejalanKaki[i].OffY := -22 + i * 22;
    DaftarPejalanKaki[i].Shirt := Random(4);
    Inc(i);
  end;
  TampilkanInfo('ZEBRA CROSS: berhenti dan beri jalan kepada pejalan kaki.');
end;

// PejalanKakiDiJalan: True bila ada pejalan kaki yang sedang berada di area jalan.
function PejalanKakiDiJalan: Boolean;
var
  i: Integer;
begin
  Result := False;
  i := 0;
  while i <= MAKS_PEJALAN_KAKI - 1 do
  begin
    if DaftarPejalanKaki[i].Aktif and DaftarPejalanKaki[i].Walking and
       (DaftarPejalanKaki[i].X + LEBAR_PEJALAN_KAKI > POSISI_JALAN - 6) and (DaftarPejalanKaki[i].X < BATAS_KANAN_JALAN + 6) then
      Result := True;
    Inc(i);
  end;
end;

// PersegiPejalanKaki: mengambil kotak tabrakan pejalan kaki ke-i (dipakai tabrakan.pas). Hasil False bila tidak sedang berjalan.
function PersegiPejalanKaki(i: Integer; var rx, ry, rw, rh: Single): Boolean;
begin
  Result := ZebraCross.Aktif and DaftarPejalanKaki[i].Aktif and DaftarPejalanKaki[i].Walking;
  if Result then
  begin
    rx := DaftarPejalanKaki[i].X + 2;
    ry := ZebraCross.Y + DaftarPejalanKaki[i].OffY - TINGGI_PEJALAN_KAKI / 2 + 2;
    rw := LEBAR_PEJALAN_KAKI - 4;
    rh := TINGGI_PEJALAN_KAKI - 4;
  end;
end;

// PerbaruiPejalanKaki: tiap GambarBingkai menggeser ZebraCross mengikuti laju mobil, mulai menyeberangkan pejalan kaki,
// lalu menilai pemain saat bagian depan mobil mencapai ZebraCross cross.
procedure PerbaruiPejalanKaki(SelangWaktu: Single);
var
  i: Integer;
  bottom, d: Single;
begin
  if not ZebraCross.Aktif then Exit;
  ZebraCross.Y := ZebraCross.Y + MobilPemain.Speed * SelangWaktu;
  if ZebraCross.Y > TINGGI_LAYAR + 120 then
  begin
    ZebraCross.Aktif := False;
    i := 0;
    while i <= MAKS_PEJALAN_KAKI - 1 do
    begin
      DaftarPejalanKaki[i].Aktif := False;
      Inc(i);
    end;
    Exit;
  end;

  // Pejalan kaki mulai menyeberang setelah ZebraCross mendekati layar, satu per satu sesuai jeda (Delay).
  if (not ZebraCross.Triggered) and (ZebraCross.Y > -60) then ZebraCross.Triggered := True;

  i := 0;
  while i <= MAKS_PEJALAN_KAKI - 1 do
  begin
    if DaftarPejalanKaki[i].Aktif then
    begin
      if ZebraCross.Triggered and (not DaftarPejalanKaki[i].Walking) and (not ZebraCross.SudahDinilai) then
      begin
        DaftarPejalanKaki[i].Delay := DaftarPejalanKaki[i].Delay - SelangWaktu;
        if DaftarPejalanKaki[i].Delay <= 0 then DaftarPejalanKaki[i].Walking := True;
      end;
      if DaftarPejalanKaki[i].Walking then
      begin
        DaftarPejalanKaki[i].X := DaftarPejalanKaki[i].X + DaftarPejalanKaki[i].Dir * DaftarPejalanKaki[i].Speed * SelangWaktu;
        if (DaftarPejalanKaki[i].Dir > 0) and (DaftarPejalanKaki[i].X > BATAS_KANAN_JALAN + 24) then
          DaftarPejalanKaki[i].Aktif := False
        else if (DaftarPejalanKaki[i].Dir < 0) and (DaftarPejalanKaki[i].X < POSISI_JALAN - 24 - LEBAR_PEJALAN_KAKI) then
          DaftarPejalanKaki[i].Aktif := False;
      end;
    end;
    Inc(i);
  end;

  // Penilaian saat mobil sampai di ZebraCross: waktu menunggu dihitung selama pemain berhenti dan ada pejalan kaki.
  // Masih melaju saat ada pejalan kaki = -50. Berhenti cukup lama (>= 0,4 detik) = +50 dan dihitung memberi jalan.
  if not ZebraCross.SudahDinilai then
  begin
    bottom := ZebraCross.Y + ZebraCross.H / 2;
    d := MobilPemain.Y - bottom;
    if (d > 0) and (d < 260) and PejalanKakiDiJalan and PemainBerhenti then
      ZebraCross.LamaMenunggu := ZebraCross.LamaMenunggu + SelangWaktu;
    if d <= 0 then
    begin
      ZebraCross.SudahDinilai := True;
      if PejalanKakiDiJalan and (MobilPemain.Speed > 15) then
        TambahSkor(-50, 'Tidak memberi jalan pada pejalan kaki!')
      else if ZebraCross.LamaMenunggu >= 0.4 then
      begin
        TambahSkor(50, 'Memberi jalan pada pejalan kaki!');
        Inc(JumlahMemberiJalan);
      end
      else
        TampilkanInfo('Pejalan kaki sudah selesai menyeberang. Tetap waspada di zebra cross.');
    end;
  end;
end;

// GambarZebraCross: menggambar garis-garis putih ZebraCross cross (8 balok) melintang di jalan.
procedure GambarZebraCross;
var
  i: Integer;
begin
  if not ZebraCross.Aktif then Exit;
  i := 0;
  while i <= 7 do
  begin
    GambarKotak(POSISI_JALAN + 8 + i * 54, ZebraCross.Y - ZebraCross.H / 2, 32, ZebraCross.H, 236, 236, 236);
    Inc(i);
  end;
end;

// GambarPejalanKaki: menggambar karakter pejalan kaki dari kotak-kotak: bayangan, kaki, badan, tangan, kepala, dan rambut.
// Kaki bergantian maju-mundur saat berjalan, dan warna baju berbeda-beda.
procedure GambarPejalanKaki;
var
  i: Integer;
  x, y: Single;
  sr, sg, sb: Byte;
  step: Integer;
begin
  if not ZebraCross.Aktif then Exit;
  i := 0;
  while i <= MAKS_PEJALAN_KAKI - 1 do
  begin
    if DaftarPejalanKaki[i].Aktif then
    begin
      x := DaftarPejalanKaki[i].X;
      y := ZebraCross.Y + DaftarPejalanKaki[i].OffY - TINGGI_PEJALAN_KAKI / 2;
      case DaftarPejalanKaki[i].Shirt of
        0: begin sr := 56;  sg := 150; sb := 230; end;
        1: begin sr := 236; sg := 100; sb := 160; end;
        2: begin sr := 250; sg := 204; sb := 21;  end;
      else
        begin sr := 80; sg := 200; sb := 120; end;
      end;
      // step bergantian 0/1 sesuai posisi, untuk membuat animasi kaki melangkah
      step := Trunc(x / 7) mod 2;
      GambarKotak(x + 2, y + 3, LEBAR_PEJALAN_KAKI, TINGGI_PEJALAN_KAKI, 0, 0, 0, 60);              { bayangan }
      if DaftarPejalanKaki[i].Walking then
      begin
        GambarKotak(x + 3, y + 15 + step * 2, 5, 5, 40, 40, 60);          { kaki }
        GambarKotak(x + 10, y + 17 - step * 2, 5, 5, 40, 40, 60);
      end
      else
      begin
        GambarKotak(x + 3, y + 15, 5, 5, 40, 40, 60);
        GambarKotak(x + 10, y + 15, 5, 5, 40, 40, 60);
      end;
      GambarKotak(x + 1, y + 7, 16, 10, sr, sg, sb);                      { badan }
      GambarKotak(x - 1, y + 8, 3, 7, 241, 194, 125);                     { tangan }
      GambarKotak(x + 16, y + 8, 3, 7, 241, 194, 125);
      GambarKotak(x + 5, y + 0, 8, 8, 241, 194, 125);                     { kepala }
      GambarKotak(x + 5, y + 0, 8, 3, 60, 40, 30);                        { rambut }
    end;
    Inc(i);
  end;
end;

end.
