{ ==========================================================================
  traffic_sign.pas  -  Rambu lalu lintas interaktif
    - Batas kecepatan : jaga kecepatan <= batas. +25 jika patuh, -30 jika tidak.
    - STOP            : berhenti total di belakang garis. +50 / -50.
    - Dilarang masuk  : jalur yang ditutup palang. Jangan masuk jalur itu. +30 / -50.
  Juga mengelola batas kecepatan aktif (SpeedLimit) dan penaltinya.
  ========================================================================== }
unit rambu_lalu_lintas;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, grafis, pemain, skor;

const
  // Jumlah rambu maksimal di layar, dan jarak palang jalan di depan tiang rambu "dilarang masuk".
  MAKS_RAMBU = 3;
  JARAK_PALANG = 260;        { palang berada sekian px di depan tiang rambu }

type
  // Jenis rambu: batas kecepatan, STOP, dan dilarang masuk.
  TJenisRambu = (rambuBatasKecepatan, rambuBerhenti, rambuDilarangMasuk);

  // TRambu: data satu rambu: aktif, sudah dinilai, jenis, nilai (batas kecepatan), jalur yang ditutup,
  // posisi, dan lama pemain berhenti.
  TRambu = record
    Aktif, SudahDinilai, SudahDiberiInfo: Boolean;
    Jenis: TJenisRambu;
    Nilai, Jalur: Integer;     { Value = batas kecepatan; Lane = jalur yang ditutup }
    Y, LamaMenunggu: Single;        { Y = posisi tiang rambu / garis STOP }
  end;

var
  // DaftarRambu = daftar rambu aktif. BatasKecepatan = batas kecepatan yang berlaku sekarang (0 = bebas).
  // JumlahPatuhRambu = jumlah rambu yang dipatuhi. WaktuPelanggaran = pewaktu pelanggaran kecepatan.
  DaftarRambu: array[0..MAKS_RAMBU - 1] of TRambu;
  BatasKecepatan: Integer;        { batas kecepatan aktif (km/j), 0 = tanpa batas }
  JumlahPatuhRambu: Integer;        { jumlah rambu yang dipatuhi }
  WaktuPelanggaran: Single;

procedure InisialisasiRambu;
procedure AturBatasKecepatan(v: Integer);
procedure MunculkanRambu(jenis: TJenisRambu; nilai, jalur: Integer);
procedure PerbaruiRambu(SelangWaktu: Single);
procedure GambarRambu;
function InfoRambu(jenis: TJenisRambu; nilai: Integer): string;
function PersegiPalangRambu(i: Integer; var rx, ry, rw, rh: Single): Boolean;

implementation

// InisialisasiRambu: menghapus semua rambu dan hitungan kepatuhan di awal level.
procedure InisialisasiRambu;
var
  i: Integer;
begin
  i := 0;
  while i <= MAKS_RAMBU - 1 do
  begin
    DaftarRambu[i].Aktif := False;
    Inc(i);
  end;
  JumlahPatuhRambu := 0;
  WaktuPelanggaran := 0;
end;

// AturBatasKecepatan: mengubah batas kecepatan yang berlaku.
procedure AturBatasKecepatan(v: Integer);
begin
  BatasKecepatan := v;
  WaktuPelanggaran := 0;
end;

// InfoRambu: teks pengetahuan/edukasi untuk tiap jenis rambu yang tampil di panel INFO.
function InfoRambu(jenis: TJenisRambu; nilai: Integer): string;
begin
  case jenis of
    rambuBatasKecepatan:
      Result := 'RAMBU BATAS KECEPATAN: jangan melaju lebih cepat dari ' + IntToStr(nilai) + ' km/j.';
    rambuBerhenti:
      Result := 'RAMBU STOP: berhenti total di belakang garis, lalu lanjut jika aman.';
  else
    Result := 'RAMBU DILARANG MASUK: jangan masuk ke jalur yang ditutup palang.';
  end;
end;

// MunculkanRambu: memunculkan rambu baru di atas layar (cari indeksKosong kosong dulu).
procedure MunculkanRambu(jenis: TJenisRambu; nilai, jalur: Integer);
var
  i, indeksKosong: Integer;
begin
  indeksKosong := -1;
  i := 0;
  while i <= MAKS_RAMBU - 1 do
  begin
    if not DaftarRambu[i].Aktif then
    begin
      indeksKosong := i;
      Break;
    end;
    Inc(i);
  end;
  if indeksKosong < 0 then Exit;
  DaftarRambu[indeksKosong].Aktif := True;
  DaftarRambu[indeksKosong].SudahDinilai := False;
  DaftarRambu[indeksKosong].SudahDiberiInfo := False;
  DaftarRambu[indeksKosong].Jenis := jenis;
  DaftarRambu[indeksKosong].Nilai := nilai;
  DaftarRambu[indeksKosong].Jalur := jalur;
  DaftarRambu[indeksKosong].LamaMenunggu := 0;
  if jenis = rambuBerhenti then
    DaftarRambu[indeksKosong].Y := -120
  else
    DaftarRambu[indeksKosong].Y := -60;
end;

// PersegiPalangRambu: mengambil kotak palang jalan untuk rambu "dilarang masuk" (dipakai untuk menggambar dan mendeteksi tabrakan).
function PersegiPalangRambu(i: Integer; var rx, ry, rw, rh: Single): Boolean;
begin
  Result := DaftarRambu[i].Aktif and (DaftarRambu[i].Jenis = rambuDilarangMasuk);
  if Result then
  begin
    rx := POSISI_JALAN + DaftarRambu[i].Jalur * LEBAR_JALUR + 14;
    ry := DaftarRambu[i].Y - JARAK_PALANG - 16;
    rw := LEBAR_JALUR - 28;
    rh := 32;
  end;
end;

// PerbaruiRambu: tiap GambarBingkai menggeser rambu mengikuti laju mobil, menampilkan tip, dan menilai pemain
// saat mobil melewati rambu, serta menghukum bila terus melebihi batas kecepatan.
procedure PerbaruiRambu(SelangWaktu: Single);
var
  i: Integer;
  d: Single;
begin
  i := 0;
  while i <= MAKS_RAMBU - 1 do
  begin
    if DaftarRambu[i].Aktif then
    begin
      DaftarRambu[i].Y := DaftarRambu[i].Y + MobilPemain.Speed * SelangWaktu;
      if DaftarRambu[i].Y > TINGGI_LAYAR + 120 then
      begin
        DaftarRambu[i].Aktif := False;
        Inc(i);          // naikkan i dulu karena Continue melompati Inc di akhir loop
        Continue;
      end;

      // saat rambu mendekat, tampilkan tip tentang rambu itu satu kali
      if (not DaftarRambu[i].SudahDiberiInfo) and (DaftarRambu[i].Y > 130) then
      begin
        DaftarRambu[i].SudahDiberiInfo := True;
        TampilkanInfo(InfoRambu(DaftarRambu[i].Jenis, DaftarRambu[i].Nilai));
      end;

      if not DaftarRambu[i].SudahDinilai then
      begin
        d := MobilPemain.Y - DaftarRambu[i].Y;
        case DaftarRambu[i].Jenis of
          // STOP: pemain harus berhenti total minimal 0,8 detik. Berhasil +50, menerobos -50.
          rambuBerhenti:
            begin
              if (d > 0) and (d < 240) and PemainBerhenti then
                DaftarRambu[i].LamaMenunggu := DaftarRambu[i].LamaMenunggu + SelangWaktu;
              if d <= 0 then
              begin
                DaftarRambu[i].SudahDinilai := True;
                if DaftarRambu[i].LamaMenunggu >= 0.8 then
                begin
                  TambahSkor(50, 'Berhenti di rambu STOP!');
                  Inc(JumlahPatuhRambu);
                end
                else
                  TambahSkor(-50, 'Menerobos rambu STOP!');
              end;
            end;
          // Batas kecepatan: saat melewati rambu, batas baru berlaku. Patuh (toleransi 4 km/j) +25, melebihi -30.
          rambuBatasKecepatan:
            if d <= 0 then
            begin
              DaftarRambu[i].SudahDinilai := True;
              AturBatasKecepatan(DaftarRambu[i].Nilai);
              if KecepatanPemainKmh <= DaftarRambu[i].Nilai + 4 then
              begin
                TambahSkor(25, 'Patuh batas ' + IntToStr(DaftarRambu[i].Nilai) + ' km/j!');
                Inc(JumlahPatuhRambu);
              end
              else
                TambahSkor(-30, 'Melebihi batas ' + IntToStr(DaftarRambu[i].Nilai) + ' km/j!');
            end;
          // Dilarang masuk: jangan berada di jalur yang ditutup. Salah jalur -50, benar +30.
          rambuDilarangMasuk:
            if d <= 0 then
            begin
              DaftarRambu[i].SudahDinilai := True;
              if JalurPemain = DaftarRambu[i].Jalur then
                TambahSkor(-50, 'Melanggar rambu dilarang masuk!')
              else
              begin
                TambahSkor(30, 'Patuh rambu dilarang masuk!');
                Inc(JumlahPatuhRambu);
              end;
            end;
        end;
      end;
    end;
    Inc(i);
  end;

  // Selama kecepatan melebihi batas aktif, pewaktu bertambah; tiap 2,2 detik pemain kena -30.
  // Jika kecepatan sudah aman, pewaktu berkurang kembali.
  if (BatasKecepatan > 0) and (KecepatanPemainKmh > BatasKecepatan + 4) then
  begin
    WaktuPelanggaran := WaktuPelanggaran + SelangWaktu;
    if WaktuPelanggaran >= 2.2 then
    begin
      TambahSkor(-30, 'Melebihi batas kecepatan ' + IntToStr(BatasKecepatan) + ' km/j!');
      WaktuPelanggaran := 0;
    end;
  end
  else
  begin
    WaktuPelanggaran := WaktuPelanggaran - SelangWaktu * 2;
    if WaktuPelanggaran < 0 then WaktuPelanggaran := 0;
  end;
end;

// GambarPapanRambu: menggambar papan rambu dari kotak-kotak: tiang, lalu papan sesuai jenis
// (lingkaran merah berisi angka, segi delapan STOP, atau papan merah dengan garis putih).
procedure GambarPapanRambu(jenis: TJenisRambu; nilai: Integer; x, y: Single);
begin
  { tiang }
  GambarKotak(x + 22, y + 46, 5, 46, 150, 155, 165);
  case jenis of
    rambuBatasKecepatan:
      begin
        GambarKotak(x, y, 48, 48, 215, 30, 40);
        GambarKotak(x + 5, y + 5, 38, 38, 250, 250, 250);
        GambarTeksTengah(x + 24, y + 17, IntToStr(nilai), 2, 20, 20, 20);
      end;
    rambuBerhenti:
      begin
        GambarKotak(x + 10, y, 28, 48, 215, 30, 40);
        GambarKotak(x, y + 10, 48, 28, 215, 30, 40);
        GambarKotak(x + 4, y + 4, 40, 40, 215, 30, 40);
        GambarBingkai(x + 4, y + 4, 40, 40, 2, 250, 250, 250);
        GambarTeksTengah(x + 24, y + 20, 'STOP', 1, 255, 255, 255);
      end;
  else
    begin
      GambarKotak(x + 10, y, 28, 48, 215, 30, 40);
      GambarKotak(x, y + 10, 48, 28, 215, 30, 40);
      GambarKotak(x + 4, y + 4, 40, 40, 215, 30, 40);
      GambarKotak(x + 8, y + 20, 32, 9, 250, 250, 250);
    end;
  end;
end;

// GambarRambu: menggambar semua rambu: garis STOP di jalan, palang merah-putih untuk dilarang masuk,
// dan papan rambu di trotoar kanan.
procedure GambarRambu;
var
  i, k: Integer;
  bx, by, bw, bh: Single;
begin
  i := 0;
  while i <= MAKS_RAMBU - 1 do
  begin
    if DaftarRambu[i].Aktif then
    begin
      if DaftarRambu[i].Jenis = rambuBerhenti then
      begin
        GambarKotak(POSISI_JALAN, DaftarRambu[i].Y - 4, LEBAR_JALAN, 8, 245, 245, 245);
        GambarTeks(POSISI_JALAN + LEBAR_JALUR / 2 - 48, DaftarRambu[i].Y + 16, 'STOP', 3, 200, 200, 205);
        GambarTeks(POSISI_JALAN + LEBAR_JALUR + LEBAR_JALUR / 2 - 48, DaftarRambu[i].Y + 16, 'STOP', 3, 200, 200, 205);
      end;

      if PersegiPalangRambu(i, bx, by, bw, bh) then
      begin
        GambarKotak(bx, by, bw, bh, 245, 245, 245);
        k := 0;
        while k * 30 < bw do
        begin
          if (k mod 2) = 0 then
            GambarKotak(bx + k * 30, by, 30, bh, 220, 38, 38);
          Inc(k);
        end;
        GambarBingkai(bx, by, bw, bh, 2, 60, 20, 20);
        GambarTeksTengah(bx + bw / 2, by - 22, 'DILARANG MASUK', 1, 255, 255, 255);
      end;

      GambarPapanRambu(DaftarRambu[i].Jenis, DaftarRambu[i].Nilai, BATAS_KANAN_JALAN + 4, DaftarRambu[i].Y - 92);
    end;
    Inc(i);
  end;
end;

end.
