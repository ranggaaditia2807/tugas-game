{ ==========================================================================
  scoring.pas  -  Skor, nyawa, pesan pelanggaran, tip edukasi, dan HUD skor
  ========================================================================== }
unit skor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, grafis, suara;

const
  // Jumlah nyawa di awal permainan.
  NYAWA_AWAL = 3;

type
  // TDataSkor: semua data skor dalam satu wadah: skor, skor tertinggi, nyawa, jumlah pelanggaran,
  // jumlah tindakan benar, pesan besar di tengah jalan, dan tip edukasi di panel kiri (beserta pewaktunya).
  TDataSkor = record
    Skor, SkorTertinggi, Nyawa: Integer;
    Pelanggaran: Integer;      { jumlah pelanggaran }
    PoinBenar: Integer;         { jumlah tindakan benar }
    Pesan: string;              { pesan besar di tengah jalan }
    MsgTimer: Single;
    MsgGood: Boolean;
    Tip: string;              { tip / informasi edukasi di panel kiri }
    TipTimer: Single;
  end;

var
  // Sc = data skor yang dipakai bersama oleh seluruh game.
  Sc: TDataSkor;

procedure SkorGameBaru;
procedure TambahSkor(perubahan: Integer; const teks: string);
procedure KurangiNyawa;
procedure TampilkanInfo(const t: string);
procedure PerbaruiSkor(SelangWaktu: Single);
function TeksSkor(n: Integer): string;
function PeringkatSkor: string;
function AkurasiSkor: Integer;
procedure GambarTampilanSkor;
procedure GambarPesan;

implementation

// SkorGameBaru: mengatur ulang skor, nyawa, dan pesan untuk permainan baru (skor tertinggi tetap disimpan).
procedure SkorGameBaru;
begin
  Sc.Skor := 0;
  Sc.Nyawa := NYAWA_AWAL;
  Sc.Pelanggaran := 0;
  Sc.PoinBenar := 0;
  Sc.Pesan := '';
  Sc.MsgTimer := 0;
  Sc.Tip := '';
  Sc.TipTimer := 0;
end;

// TambahSkor: menambah/mengurangi skor sebesar perubahan dan menampilkan pesan teks di layar.
// Perubahan negatif = pelanggaran (pesan merah), perubahan positif = tindakan benar (pesan hijau + bunyi poin).
procedure TambahSkor(perubahan: Integer; const teks: string);
begin
  Sc.Skor := Sc.Skor + perubahan;
  // skor tidak boleh di bawah 0, dan skor tertinggi diperbarui bila terlampaui
  if Sc.Skor < 0 then Sc.Skor := 0;
  if Sc.Skor > Sc.SkorTertinggi then Sc.SkorTertinggi := Sc.Skor;
  // Pelanggaran: hitung jumlahnya dan siapkan pesan merah berisi nilai pengurangan.
  if perubahan < 0 then
  begin
    Inc(Sc.Pelanggaran);
    Sc.MsgGood := False;
    Sc.Pesan := teks + ' ' + IntToStr(perubahan);
  end
  else
  begin
    Inc(Sc.PoinBenar);
    Sc.MsgGood := True;
    // Tindakan benar: mainkan bunyi poin "ding-ding".
    if perubahan > 0 then SuaraPoin;
    Sc.Pesan := teks;
    if perubahan > 0 then Sc.Pesan := Sc.Pesan + ' +' + IntToStr(perubahan);
  end;
  // pesan tampil selama 3 detik
  Sc.MsgTimer := 3.0;
end;

// KurangiNyawa: mengurangi 1 nyawa (tidak akan di bawah 0).
procedure KurangiNyawa;
begin
  if Sc.Nyawa > 0 then Dec(Sc.Nyawa);
end;

// TampilkanInfo: menampilkan tip/pengetahuan lalu lintas di panel INFO selama 8 detik.
procedure TampilkanInfo(const t: string);
begin
  Sc.Tip := t;
  Sc.TipTimer := 8.0;
end;

// PerbaruiSkor: menghitung mundur pewaktu pesan dan tip setiap GambarBingkai, agar hilang sendiri saat waktunya habis.
procedure PerbaruiSkor(SelangWaktu: Single);
begin
  if Sc.MsgTimer > 0 then Sc.MsgTimer := Sc.MsgTimer - SelangWaktu;
  if Sc.TipTimer > 0 then Sc.TipTimer := Sc.TipTimer - SelangWaktu;
end;

// TeksSkor: mengubah skor menjadi teks 6 digit dengan angka nol di depan (contoh 000150).
function TeksSkor(n: Integer): string;
begin
  Result := IntToStr(n);
  while Length(Result) < 6 do
    Result := '0' + Result;
end;

// PeringkatSkor: memberi peringkat berdasarkan skor: GOLD >= 1500, SILVER >= 900, BRONZE >= 400, selain itu PEMULA.
function PeringkatSkor: string;
begin
  if Sc.Skor >= 1500 then
    Result := 'GOLD - PENGEMUDI TELADAN'
  else if Sc.Skor >= 900 then
    Result := 'SILVER - PENGEMUDI BAIK'
  else if Sc.Skor >= 400 then
    Result := 'BRONZE - CUKUP BAIK'
  else
    Result := 'PEMULA - AYO BELAJAR LAGI';
end;

// AkurasiSkor: persentase tindakan benar dibanding seluruh tindakan (benar + pelanggaran).
function AkurasiSkor: Integer;
var
  jumlahTotal: Integer;
begin
  jumlahTotal := Sc.PoinBenar + Sc.Pelanggaran;
  if jumlahTotal = 0 then
    Result := 100
  else
    Result := (Sc.PoinBenar * 100) div jumlahTotal;
end;

// GambarTampilanSkor: menggambar panel kiri-atas: skor, skor tertinggi, ikon nyawa (hati merah), dan panel tip.
procedure GambarTampilanSkor;
var
  i: Integer;
begin
  GambarKotak(20, 20, 360, 130, 12, 18, 34, 215);
  GambarBingkai(20, 20, 360, 130, 3, 60, 75, 110);
  GambarTeks(36, 36, 'SKOR:', 2, 250, 204, 21);
  GambarTeks(130, 32, TeksSkor(Sc.Skor), 3, 255, 255, 255);
  GambarTeks(36, 74, 'HI-SKOR:', 2, 148, 163, 184);
  GambarTeks(176, 74, TeksSkor(Sc.SkorTertinggi), 2, 148, 163, 184);
  GambarTeks(36, 112, 'NYAWA:', 2, 148, 163, 184);
  // gambar kotak merah untuk tiap nyawa yang tersisa, kotak abu-abu untuk nyawa yang hilang
  i := 0;
  while i <= NYAWA_AWAL - 1 do
  begin
    if i < Sc.Nyawa then
    begin
      GambarKotak(140 + i * 40, 106, 30, 26, 239, 68, 68);
      GambarKotak(144 + i * 40, 110, 8, 6, 252, 165, 165);
    end
    else
      GambarKotak(140 + i * 40, 106, 30, 26, 51, 65, 85);
    Inc(i);
  end;

  // Panel INFO: muncul hanya selama pewaktu tip masih menyala; tingginya menyesuaikan jumlah baris teks.
  if Sc.TipTimer > 0 then
  begin
    i := BungkusTeks(36, 262, 20, Sc.Tip, 2, 255, 255, 255, False);
    GambarKotak(20, 232, 360, 50 + i * 22, 12, 18, 34, 215);
    GambarBingkai(20, 232, 360, 50 + i * 22, 3, 56, 189, 248);
    GambarTeks(36, 242, 'INFO:', 2, 56, 189, 248);
    BungkusTeks(36, 266, 20, Sc.Tip, 2, 255, 255, 255, True);
  end;
end;

// GambarPesan: menggambar pesan besar di tengah jalan (hijau = benar, merah = pelanggaran) selama pewaktunya menyala.
procedure GambarPesan;
var
  n: Integer;
  h: Single;
begin
  if Sc.MsgTimer <= 0 then Exit;
  n := BungkusTeks(0, 0, 26, Sc.Pesan, 2, 0, 0, 0, False);
  h := 24 + n * 22;
  if Sc.MsgGood then
  begin
    GambarKotak(POSISI_JALAN, 170, LEBAR_JALAN, h, 21, 94, 52, 235);
    GambarBingkai(POSISI_JALAN, 170, LEBAR_JALAN, h, 3, 74, 222, 128);
  end
  else
  begin
    GambarKotak(POSISI_JALAN, 170, LEBAR_JALAN, h, 127, 29, 29, 235);
    GambarBingkai(POSISI_JALAN, 170, LEBAR_JALAN, h, 3, 248, 113, 113);
  end;
  BungkusTeks(POSISI_JALAN + 14, 182, 26, Sc.Pesan, 2, 255, 255, 255, True);
end;

end.
