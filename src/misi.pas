{ ==========================================================================
  mission.pas  -  5 level misi edukasi: instruksi, jadwal kemunculan objek
  (rambu / lampu / zebra), pengecekan target, dan panel status misi.
  ========================================================================== }
unit misi;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, grafis, skor, pemain, kendaraan, rambu_lalu_lintas, lampu_lalu_lintas, pejalan_kaki;

const
  // Jumlah level permainan.
  JUMLAH_LEVEL = 5;

type
  // Jenis kejadian yang bisa muncul di jalan: rambu batas kecepatan, STOP, dilarang masuk, lampu, ZebraCross cross.
  TJenisKejadian = (kejBatasKecepatan, kejBerhenti, kejDilarangMasuk, kejLampu, kejZebra);

  // TDataLevel: definisi satu level: judul, tujuan misi, target yang harus dicapai (rambu/lampu/ZebraCross/jarak bersih),
  // batas kecepatan, jarak antar kejadian, keramaian lalu lintas, dan urutan kejadian (Pattern).
  TDataLevel = record
    Judul, NamaSingkat, Tujuan: string;
    ButuhRambu, ButuhLampu, ButuhPejalanKaki, ButuhJarakBersih: Integer;   { target; NeedClean dalam meter }
    Limit, SignValue: Integer;
    JarakKemunculan, TrafficGap: Single;
    PatternLen: Integer;
    Pattern: array[0..7] of TJenisKejadian;
  end;

var
  // DaftarLevel = data kelima level. LevelSaatIni = level yang dimainkan. JarakBersih = jarak tanpa pelanggaran. Selesai = misi sudah selesai.
  DaftarLevel: array[1..JUMLAH_LEVEL] of TDataLevel;
  LevelSaatIni: Integer;
  JarakBersih: Single;          { jarak tanpa pelanggaran (px dunia) }
  Selesai: Boolean;

procedure MulaiMisiLevel(n: Integer);
function ProsesMisi(SelangWaktu: Single): Boolean;
function ProgresMisi: Single;
procedure GambarPanelMisi;

implementation

var
  // Variabel internal: SpawnAcc = jarak sejak kejadian terakhir, EventIdx = urutan kejadian berikutnya,
  // LastViol = jumlah pelanggaran terakhir (untuk mengulang hitungan jarak bersih).
  SpawnAcc: Single;
  EventIdx: Integer;
  LastViol: Integer;

// AturLevel: mengisi data dasar satu level (judul, tujuan, target, batas kecepatan, jarak, keramaian).
procedure AturLevel(n: Integer; const Judul, shortn, obj: string;
  nSign, nLight, nPed, nClean, limit, sval: Integer; JarakKemunculan, gap: Single);
begin
  DaftarLevel[n].Judul := Judul;
  DaftarLevel[n].NamaSingkat := shortn;
  DaftarLevel[n].Tujuan := obj;
  DaftarLevel[n].ButuhRambu := nSign;
  DaftarLevel[n].ButuhLampu := nLight;
  DaftarLevel[n].ButuhPejalanKaki := nPed;
  DaftarLevel[n].ButuhJarakBersih := nClean;
  DaftarLevel[n].Limit := limit;
  DaftarLevel[n].SignValue := sval;
  DaftarLevel[n].JarakKemunculan := JarakKemunculan;
  DaftarLevel[n].TrafficGap := gap;
  DaftarLevel[n].PatternLen := 0;
end;

// TambahKejadian: menambahkan satu kejadian ke urutan (Pattern) level; urutan ini diulang terus selama bermain.
procedure TambahKejadian(n: Integer; k: TJenisKejadian);
begin
  DaftarLevel[n].Pattern[DaftarLevel[n].PatternLen] := k;
  Inc(DaftarLevel[n].PatternLen);
end;

// InisialisasiLevel: mendefinisikan KELIMA LEVEL:
// 1 Jalan Kota (rambu), 2 Kendaraan LampuLaluLintas, 3 Zona Sekolah (ZebraCross, 40 km/j), 4 Jalan Raya (500 m tanpa pelanggaran), 5 Persimpangan Ramai (semua aturan).
procedure InisialisasiLevel;
begin
  AturLevel(1, 'LEVEL 1 - CITY ROAD', 'Jalan Kota',
    'Patuhi rambu: batas kecepatan, STOP, dan dilarang masuk.',
    4, 0, 0, 0, 60, 50, 1300, 2.6);
  TambahKejadian(1, kejBatasKecepatan); TambahKejadian(1, kejBerhenti); TambahKejadian(1, kejDilarangMasuk);
  TambahKejadian(1, kejBatasKecepatan); TambahKejadian(1, kejBerhenti); TambahKejadian(1, kejDilarangMasuk);

  AturLevel(2, 'LEVEL 2 - TRAFFIC LIGHT', 'Lampu Lalu Lintas',
    'Berhenti saat lampu merah, jalan saat hijau.',
    0, 3, 0, 0, 60, 60, 1400, 2.6);
  TambahKejadian(2, kejLampu);

  AturLevel(3, 'LEVEL 3 - SCHOOL ZONE', 'Zona Sekolah',
    'Zona sekolah! Maks 40 km/j. Beri jalan pada pejalan kaki.',
    0, 0, 3, 0, 40, 40, 1400, 2.8);
  TambahKejadian(3, kejBatasKecepatan); TambahKejadian(3, kejZebra); TambahKejadian(3, kejZebra);

  AturLevel(4, 'LEVEL 4 - HIGHWAY', 'Jalan Raya',
    'Jaga maks 80 km/j dan jarak aman tanpa pelanggaran 500 m.',
    0, 0, 0, 500, 80, 80, 1800, 1.4);
  TambahKejadian(4, kejBatasKecepatan);

  AturLevel(5, 'LEVEL 5 - BUSY INTERSECTION', 'Persimpangan Ramai',
    'Terapkan semua aturan: lampu, zebra, STOP, batas kecepatan.',
    2, 2, 2, 0, 50, 50, 1500, 1.8);
  TambahKejadian(5, kejLampu); TambahKejadian(5, kejZebra); TambahKejadian(5, kejBerhenti);
  TambahKejadian(5, kejLampu); TambahKejadian(5, kejZebra); TambahKejadian(5, kejBatasKecepatan);
end;

// MulaiMisiLevel: memulai level n: mengatur ulang mobil, lalu lintas, rambu, lampu, dan ZebraCross,
// menetapkan batas kecepatan awal, lalu menampilkan tujuan misi.
procedure MulaiMisiLevel(n: Integer);
begin
  LevelSaatIni := n;
  InisialisasiPemain;
  InisialisasiKendaraan;
  AturJedaKendaraan(DaftarLevel[n].TrafficGap);
  InisialisasiRambu;
  InisialisasiLampu;
  InisialisasiPejalanKaki;
  AturBatasKecepatan(DaftarLevel[n].Limit);
  SpawnAcc := DaftarLevel[n].JarakKemunculan - 450;
  EventIdx := 0;
  JarakBersih := 0;
  LastViol := Sc.Pelanggaran;
  Selesai := False;
  Sc.MsgTimer := 0;
  TampilkanInfo(DaftarLevel[n].Tujuan);
end;

// Ratio: perbandingan capaian a terhadap target b (0 sampai 1), untuk bar kemajuan.
function Ratio(a, b: Integer): Single;
begin
  if b <= 0 then
    Result := 1
  else if a >= b then
    Result := 1
  else
    Result := a / b;
end;

// TargetTercapai: True bila SEMUA target level sudah tercapai.
function TargetTercapai: Boolean;
begin
  Result := (JumlahPatuhRambu >= DaftarLevel[LevelSaatIni].ButuhRambu) and
            (JumlahPatuhLampu >= DaftarLevel[LevelSaatIni].ButuhLampu) and
            (JumlahMemberiJalan >= DaftarLevel[LevelSaatIni].ButuhPejalanKaki) and
            (JarakBersih / 10 >= DaftarLevel[LevelSaatIni].ButuhJarakBersih);
end;

// MunculkanKejadian: memunculkan objek jalan sesuai jenis kejadian (rambu, lampu, atau ZebraCross cross).
procedure MunculkanKejadian(k: TJenisKejadian);
begin
  case k of
    kejBatasKecepatan:   MunculkanRambu(rambuBatasKecepatan, DaftarLevel[LevelSaatIni].SignValue, 0);
    kejBerhenti:    MunculkanRambu(rambuBerhenti, 0, 0);
    kejDilarangMasuk: MunculkanRambu(rambuDilarangMasuk, 0, JalurPemain);
    kejLampu:   MunculkanLampu(-150);
    kejZebra:   MunculkanZebraCross(-120);
  end;
end;

// ProsesMisi: dijalankan tiap GambarBingkai. Memunculkan kejadian baru setiap jarak tertentu, menghitung jarak tanpa pelanggaran,
// lalu mengecek apakah misi selesai (+100 poin). Hasil True = level selesai.
function ProsesMisi(SelangWaktu: Single): Boolean;
var
  moved: Single;
begin
  Result := False;
  moved := MobilPemain.Speed * SelangWaktu;

  SpawnAcc := SpawnAcc + moved;
  if SpawnAcc >= DaftarLevel[LevelSaatIni].JarakKemunculan then
  begin
    SpawnAcc := 0;
    MunculkanKejadian(DaftarLevel[LevelSaatIni].Pattern[EventIdx mod DaftarLevel[LevelSaatIni].PatternLen]);
    Inc(EventIdx);
  end;

  if Sc.Pelanggaran <> LastViol then
  begin
    LastViol := Sc.Pelanggaran;
    JarakBersih := 0;
  end
  else
    JarakBersih := JarakBersih + moved;

  if (not Selesai) and TargetTercapai then
  begin
    Selesai := True;
    TambahSkor(100, 'Misi selesai!');
    Result := True;
  end;
end;

// ProgresMisi: persentase kemajuan misi (0 sampai 1) dari rata-rata semua target, untuk bar di panel misi.
function ProgresMisi: Single;
var
  n: Integer;
  f: Single;
begin
  f := 0;
  n := 0;
  with DaftarLevel[LevelSaatIni] do
  begin
    if ButuhRambu > 0 then begin f := f + Ratio(JumlahPatuhRambu, ButuhRambu); Inc(n); end;
    if ButuhLampu > 0 then begin f := f + Ratio(JumlahPatuhLampu, ButuhLampu); Inc(n); end;
    if ButuhPejalanKaki > 0 then begin f := f + Ratio(JumlahMemberiJalan, ButuhPejalanKaki); Inc(n); end;
    if ButuhJarakBersih > 0 then begin f := f + Ratio(Trunc(JarakBersih / 10), ButuhJarakBersih); Inc(n); end;
  end;
  if n = 0 then
    Result := 1
  else
    Result := f / n;
end;

// GambarPanelMisi: menggambar panel misi di kanan-atas: nama level, tujuan, progres tiap target (hijau jika tercapai), dan bar kemajuan.
procedure GambarPanelMisi;
var
  lines, cats: Integer;
  h, y, p: Single;

  procedure CatLine(const teks: string; cur, need: Integer);
  begin
    if cur >= need then
      GambarTeks(906, y, teks, 2, 74, 222, 128)
    else
      GambarTeks(906, y, teks, 2, 255, 255, 255);
    y := y + 22;
  end;

begin
  lines := BungkusTeks(0, 0, 21, DaftarLevel[LevelSaatIni].Tujuan, 2, 0, 0, 0, False);
  cats := 0;
  with DaftarLevel[LevelSaatIni] do
  begin
    if ButuhRambu > 0 then Inc(cats);
    if ButuhLampu > 0 then Inc(cats);
    if ButuhPejalanKaki > 0 then Inc(cats);
    if ButuhJarakBersih > 0 then Inc(cats);
  end;
  h := 84 + lines * 22 + 8 + cats * 22 + 34;

  GambarKotak(890, 20, 370, h, 12, 18, 34, 215);
  GambarBingkai(890, 20, 370, h, 3, 60, 75, 110);
  GambarTeks(906, 34, 'MISI EDUKASI #' + IntToStr(LevelSaatIni), 2, 56, 189, 248);
  GambarTeks(906, 58, DaftarLevel[LevelSaatIni].NamaSingkat, 2, 250, 204, 21);
  BungkusTeks(906, 88, 21, DaftarLevel[LevelSaatIni].Tujuan, 2, 255, 255, 255, True);

  y := 88 + lines * 22 + 8;
  with DaftarLevel[LevelSaatIni] do
  begin
    if ButuhRambu > 0 then
      CatLine('Rambu patuh: ' + IntToStr(JumlahPatuhRambu) + '/' + IntToStr(ButuhRambu), JumlahPatuhRambu, ButuhRambu);
    if ButuhLampu > 0 then
      CatLine('Lampu dipatuhi: ' + IntToStr(JumlahPatuhLampu) + '/' + IntToStr(ButuhLampu), JumlahPatuhLampu, ButuhLampu);
    if ButuhPejalanKaki > 0 then
      CatLine('Beri jalan: ' + IntToStr(JumlahMemberiJalan) + '/' + IntToStr(ButuhPejalanKaki), JumlahMemberiJalan, ButuhPejalanKaki);
    if ButuhJarakBersih > 0 then
      CatLine('Bersih: ' + IntToStr(Trunc(JarakBersih / 10)) + '/' + IntToStr(ButuhJarakBersih) + ' m',
        Trunc(JarakBersih / 10), ButuhJarakBersih);
  end;

  p := ProgresMisi;
  GambarKotak(906, y + 4, 338, 16, 30, 41, 59);
  GambarKotak(906, y + 4, 338 * p, 16, 234, 179, 8);
  GambarBingkai(906, y + 4, 338, 16, 2, 71, 85, 105);
end;

// Bagian ini berjalan otomatis saat program dimulai: menyiapkan data kelima level.
initialization
  InisialisasiLevel;

end.
