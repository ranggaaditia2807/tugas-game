{ ==========================================================================
  collision.pas  -  Deteksi tabrakan: kendaraan NPC, pejalan kaki, palang jalan
  Setiap tabrakan: penalti skor, kehilangan 1 nyawa. Nyawa habis = PERMAINAN BERAKHIR.
  ========================================================================== }
unit tabrakan;

{$mode objfpc}{$H+}

interface

uses
  grafis, skor, suara, pemain, kendaraan, pejalan_kaki, lampu_lalu_lintas;

var
  // PenandaGameOver = True bila nyawa habis; dibaca oleh main.pas untuk pindah ke layar Game Over.
  PenandaGameOver: Boolean;

procedure InisialisasiTabrakan;
procedure PerbaruiTabrakan(SelangWaktu: Single);
function ApakahGameOver: Boolean;
function PersegiBertabrakan(ax, ay, aw, ah, bx, by, bw, bh: Single): Boolean;

implementation

// PersegiBertabrakan: mengecek apakah dua persegi panjang (A dan B) saling bertumpang tindih. Dasar semua deteksi tabrakan.
function PersegiBertabrakan(ax, ay, aw, ah, bx, by, bw, bh: Single): Boolean;
begin
  Result := (ax < bx + bw) and (ax + aw > bx) and (ay < by + bh) and (ay + ah > by);
end;

// InisialisasiTabrakan: menghapus statusKecepatan game over (dipanggil saat level dimulai).
procedure InisialisasiTabrakan;
begin
  PenandaGameOver := False;
end;

// ApakahGameOver: memberi tahu bagian lain apakah permainan sudah berakhir.
function ApakahGameOver: Boolean;
begin
  Result := PenandaGameOver;
end;

// ProsesTabrakan: aksi yang terjadi saat mobil menabrak: kurangi skor (penalti), kurangi 1 nyawa,
// buat mobil melambat dan kebal sementara, mainkan suara tabrakan, dan tandai game over jika nyawa habis.
procedure ProsesTabrakan(penalti: Integer; const teks: string);
begin
  TambahSkor(penalti, teks);
  KurangiNyawa;
  PemainMenabrak;
  SuaraTabrakan;
  if Sc.Nyawa <= 0 then PenandaGameOver := True;
end;

// PerbaruiTabrakan: dijalankan tiap GambarBingkai; mengecek tabrakan mobil pemain dengan kendaraan, pejalan kaki, dan palang.
procedure PerbaruiTabrakan(SelangWaktu: Single);
var
  i: Integer;
  px, py, pw, ph: Single;
  rx, ry, rw, rh: Single;
begin
  // jika sudah game over, tidak perlu cek tabrakan lagi
  if PenandaGameOver then Exit;
  { hitbox pemain dibuat sedikit lebih kecil dari gambar }
  px := MobilPemain.X + 4;
  py := MobilPemain.Y + 6;
  pw := MobilPemain.W - 8;
  ph := MobilPemain.H - 12;

  // masa kebal setelah tabrakan: abaikan tabrakan baru agar nyawa tidak habis beruntun
  if MobilPemain.Invul > 0 then Exit;

  // Tabrakan dengan kendaraan lain (-50): mobil NPC yang ditabrak dihilangkan.
  i := 0;
  while i <= MAKS_KENDARAAN_NPC - 1 do
  begin
    if DaftarKendaraanNPC[i].Aktif then
      if PersegiBertabrakan(px, py, pw, ph, DaftarKendaraanNPC[i].X + 4, DaftarKendaraanNPC[i].Y + 6, DaftarKendaraanNPC[i].W - 8, DaftarKendaraanNPC[i].H - 12) then
      begin
        DaftarKendaraanNPC[i].Aktif := False;
        ProsesTabrakan(-50, 'Menabrak kendaraan lain!');
        TampilkanInfo('Jaga jarak aman dan hindari kendaraan di depanmu.');
        Exit;
      end;
    Inc(i);
  end;

  // Tabrakan dengan pejalan kaki (-100): penalti terberat.
  i := 0;
  while i <= MAKS_PEJALAN_KAKI - 1 do
  begin
    if PersegiPejalanKaki(i, rx, ry, rw, rh) then
      if PersegiBertabrakan(px, py, pw, ph, rx, ry, rw, rh) then
      begin
        DaftarPejalanKaki[i].Aktif := False;
        ProsesTabrakan(-100, 'Menabrak pejalan kaki!');
        TampilkanInfo('Pejalan kaki selalu diutamakan. Berhenti sebelum zebra cross.');
        Exit;
      end;
    Inc(i);
  end;
end;
end.
