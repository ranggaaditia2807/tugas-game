{ ==========================================================================
  traffic.pas  -  Kendaraan NPC: muncul berkala, bergerak, variasi warna/jenis
  Posisi layar NPC berubah sebesar (kecepatan pemain - kecepatan NPC) * dt.
  ========================================================================== }
unit kendaraan;

{$mode objfpc}{$H+}

interface

uses
  grafis, pemain;

const
  // Jumlah maksimal kendaraan NPC yang boleh ada bersamaan.
  MAKS_KENDARAAN_NPC = 8;

type
  // TKendaraanNPC: data satu kendaraan NPC: aktif atau tidak, posisi, ukuran, kecepatan, model, warna, dan jalur.
  TKendaraanNPC = record
    Aktif: Boolean;
    X, Y, W, H, Speed: Single;
    Jenis: Integer;            { 1 sedan, 2 van, 3 kecil }
    R, G, B: Byte;
    Jalur: Integer;
  end;

var
  // DaftarKendaraanNPC = daftar semua kendaraan NPC. WaktuMuncul/JedaKemunculan = pewaktu kemunculan kendaraan baru.
  DaftarKendaraanNPC: array[0..MAKS_KENDARAAN_NPC - 1] of TKendaraanNPC;
  WaktuMuncul, JedaKemunculan: Single;

procedure InisialisasiKendaraan;
procedure AturJedaKendaraan(detik: Single);
procedure PerbaruiKendaraan(SelangWaktu: Single);
procedure GambarKendaraan;

implementation

// InisialisasiKendaraan: menghapus semua NPC dan mengatur pewaktu kemunculan di awal level.
procedure InisialisasiKendaraan;
var
  i: Integer;
begin
  i := 0;
  while i <= MAKS_KENDARAAN_NPC - 1 do
  begin
    DaftarKendaraanNPC[i].Aktif := False;
    Inc(i);
  end;
  WaktuMuncul := 1.5;
  JedaKemunculan := 2.6;
end;

// AturJedaKendaraan: mengatur seberapa sering kendaraan muncul (detik); kecil = lebih ramai.
procedure AturJedaKendaraan(detik: Single);
begin
  JedaKemunculan := detik;
end;

{ true bila jalur lane bebas di sekitar posisi ys }
// JalurKosong: True bila jalur tertentu kosong di sekitar posisi posisiY, agar mobil baru tidak muncul menumpuk.
function JalurKosong(jalur: Integer; posisiY: Single): Boolean;
var
  i: Integer;
begin
  Result := True;
  i := 0;
  while i <= MAKS_KENDARAAN_NPC - 1 do
  begin
    if DaftarKendaraanNPC[i].Aktif and (DaftarKendaraanNPC[i].Jalur = jalur) and (Abs(DaftarKendaraanNPC[i].Y - posisiY) < 320) then
      Result := False;
    Inc(i);
  end;
end;

// MunculkanKendaraan: memunculkan satu kendaraan NPC baru dengan jalur, model, ukuran, kecepatan, dan warna acak.
procedure MunculkanKendaraan;
var
  i, jalur, indeksKosong: Integer;
  posisiY, kecepatan: Single;
  dariAtas: Boolean;
begin
  indeksKosong := -1;
  i := 0;
  while i <= MAKS_KENDARAAN_NPC - 1 do
  begin
    if not DaftarKendaraanNPC[i].Aktif then
    begin
      indeksKosong := i;
      Break;
    end;
    Inc(i);
  end;
  if indeksKosong < 0 then Exit;

  // Jika pemain ngebut, NPC muncul dari atas (lebih lambat, terlihat di depan).
  // Jika pemain pelan, NPC muncul dari bawah dan menyalip, tapi tidak di jalur pemain.
  dariAtas := MobilPemain.Speed >= 330;
  if dariAtas then
  begin
    posisiY := -140;
    jalur := Random(2);
  end
  else
  begin
    { dari belakang: jangan di jalur pemain agar tidak menabrak dari belakang }
    posisiY := TINGGI_LAYAR + 140;
    jalur := 1 - JalurPemain;
  end;
  if not JalurKosong(jalur, posisiY) then Exit;

  if dariAtas then
  begin
    kecepatan := 130 + Random(100);
    if kecepatan > MobilPemain.Speed - 40 then kecepatan := MobilPemain.Speed - 40;
  end
  else
    kecepatan := MobilPemain.Speed + 80 + Random(100);

  DaftarKendaraanNPC[indeksKosong].Aktif := True;
  DaftarKendaraanNPC[indeksKosong].Jalur := jalur;
  DaftarKendaraanNPC[indeksKosong].Speed := kecepatan;
  // Model acak: 1 sedan, 2 van (lebih besar), 3 mobil kecil. Ukuran disesuaikan model.
  DaftarKendaraanNPC[indeksKosong].Jenis := 1 + Random(3);
  case DaftarKendaraanNPC[indeksKosong].Jenis of
    2:
      begin
        DaftarKendaraanNPC[indeksKosong].W := 60;
        DaftarKendaraanNPC[indeksKosong].H := 124;
      end;
    3:
      begin
        DaftarKendaraanNPC[indeksKosong].W := 48;
        DaftarKendaraanNPC[indeksKosong].H := 88;
      end;
  else
    begin
      DaftarKendaraanNPC[indeksKosong].W := 54;
      DaftarKendaraanNPC[indeksKosong].H := 100;
    end;
  end;
  DaftarKendaraanNPC[indeksKosong].X := POSISI_JALAN + jalur * LEBAR_JALUR + (LEBAR_JALUR - DaftarKendaraanNPC[indeksKosong].W) / 2 + (Random(41) - 20);
  DaftarKendaraanNPC[indeksKosong].Y := posisiY;
  // Warna bodi diambil acak dari 6 pilihan warna.
  case Random(6) of
    0: begin DaftarKendaraanNPC[indeksKosong].R := 56;  DaftarKendaraanNPC[indeksKosong].G := 189; DaftarKendaraanNPC[indeksKosong].B := 248; end;
    1: begin DaftarKendaraanNPC[indeksKosong].R := 250; DaftarKendaraanNPC[indeksKosong].G := 204; DaftarKendaraanNPC[indeksKosong].B := 21;  end;
    2: begin DaftarKendaraanNPC[indeksKosong].R := 74;  DaftarKendaraanNPC[indeksKosong].G := 222; DaftarKendaraanNPC[indeksKosong].B := 128; end;
    3: begin DaftarKendaraanNPC[indeksKosong].R := 192; DaftarKendaraanNPC[indeksKosong].G := 132; DaftarKendaraanNPC[indeksKosong].B := 252; end;
    4: begin DaftarKendaraanNPC[indeksKosong].R := 226; DaftarKendaraanNPC[indeksKosong].G := 232; DaftarKendaraanNPC[indeksKosong].B := 240; end;
  else
    begin DaftarKendaraanNPC[indeksKosong].R := 251; DaftarKendaraanNPC[indeksKosong].G := 146; DaftarKendaraanNPC[indeksKosong].B := 60; end;
  end;
end;

// PerbaruiKendaraan: tiap GambarBingkai memunculkan NPC sesuai pewaktu, menggerakkan semua NPC, dan menghapus yang sudah keluar layar.
procedure PerbaruiKendaraan(SelangWaktu: Single);
var
  i, j: Integer;
begin
  WaktuMuncul := WaktuMuncul - SelangWaktu;
  if WaktuMuncul <= 0 then
  begin
    MunculkanKendaraan;
    WaktuMuncul := JedaKemunculan * (0.7 + Random * 0.6);
  end;

  i := 0;
  while i <= MAKS_KENDARAAN_NPC - 1 do
  begin
    if DaftarKendaraanNPC[i].Aktif then
    begin
      // Posisi layar NPC berubah sebesar selisih kecepatan pemain dan kecepatan NPC (pemain lebih cepat = NPC terlihat turun).
      DaftarKendaraanNPC[i].Y := DaftarKendaraanNPC[i].Y + (MobilPemain.Speed - DaftarKendaraanNPC[i].Speed) * SelangWaktu;
      if (DaftarKendaraanNPC[i].Y > TINGGI_LAYAR + 260) or (DaftarKendaraanNPC[i].Y < -300) then
        DaftarKendaraanNPC[i].Aktif := False;
    end;
    Inc(i);
  end;

  // Agar NPC tidak saling tabrak: NPC yang terlalu dekat di belakang NPC lain ikut melambat.
  { NPC yang lebih cepat menyesuaikan kecepatan dengan NPC di depannya }
  i := 0;
  while i <= MAKS_KENDARAAN_NPC - 1 do
  begin
    if DaftarKendaraanNPC[i].Aktif then
    begin
      j := 0;
      while j <= MAKS_KENDARAAN_NPC - 1 do
      begin
        if (i <> j) and DaftarKendaraanNPC[j].Aktif and (DaftarKendaraanNPC[i].Jalur = DaftarKendaraanNPC[j].Jalur) then
          if (DaftarKendaraanNPC[i].Y > DaftarKendaraanNPC[j].Y) and (DaftarKendaraanNPC[i].Y - (DaftarKendaraanNPC[j].Y + DaftarKendaraanNPC[j].H) < 16) and
             (DaftarKendaraanNPC[i].Speed > DaftarKendaraanNPC[j].Speed) then
            DaftarKendaraanNPC[i].Speed := DaftarKendaraanNPC[j].Speed;
        Inc(j);
      end;
    end;
    Inc(i);
  end;
end;

// GambarKendaraan: menggambar semua NPC aktif memakai GambarMobil.
procedure GambarKendaraan;
var
  i: Integer;
begin
  i := 0;
  while i <= MAKS_KENDARAAN_NPC - 1 do
  begin
    if DaftarKendaraanNPC[i].Aktif then
      GambarMobil(DaftarKendaraanNPC[i].X, DaftarKendaraanNPC[i].Y, DaftarKendaraanNPC[i].W, DaftarKendaraanNPC[i].H,
        DaftarKendaraanNPC[i].R, DaftarKendaraanNPC[i].G, DaftarKendaraanNPC[i].B, DaftarKendaraanNPC[i].Jenis);
    Inc(i);
  end;
end;

end.
