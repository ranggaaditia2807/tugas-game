{ ==========================================================================
  traffic_light.pas  -  Simulasi lampu lalu lintas merah / kuning / hijau
  Merah  : berhenti total sebelum garis. Menerobos = -100.
  Kuning : bersiap berhenti.
  Hijau  : boleh jalan, +50 jika dipatuhi.
  ========================================================================== }
unit lampu_lalu_lintas;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, grafis, pemain, skor;

type
  // Tiga keadaan lampu: merah, kuning, hijau.
  TStatusLampu = (lampuMerah, lampuKuning, lampuHijau);

  // TLampuLaluLintas: data lampu: aktif, sudah dinilai, warna saat ini, posisi garis berhenti,
  // pewaktu pergantian warna, dan lama pemain menunggu.
  TLampuLaluLintas = record
    Aktif, SudahDinilai: Boolean;
    StatusGame: TStatusLampu;
    Y: Single;                { posisi garis berhenti di layar }
    Pewaktu, LamaMenunggu: Single;
  end;

var
  // LampuLaluLintas = lampu lalu lintas yang aktif; JumlahPatuhLampu = jumlah lampu yang dipatuhi pemain.
  LampuLaluLintas: TLampuLaluLintas;
  JumlahPatuhLampu: Integer;       { jumlah lampu yang dipatuhi }

procedure InisialisasiLampu;
procedure MunculkanLampu(y: Single);
procedure PerbaruiLampu(SelangWaktu: Single);
procedure GambarLampu;

implementation

// InisialisasiLampu: mematikan lampu dan mengosongkan hitungan kepatuhan di awal level.
procedure InisialisasiLampu;
begin
  LampuLaluLintas.Aktif := False;
  JumlahPatuhLampu := 0;
end;

// MunculkanLampu: memunculkan lampu lalu lintas dengan garis berhenti di posisi y. Awalnya MERAH selama 5,5 detik.
procedure MunculkanLampu(y: Single);
begin
  LampuLaluLintas.Aktif := True;
  LampuLaluLintas.SudahDinilai := False;
  LampuLaluLintas.StatusGame := lampuMerah;
  LampuLaluLintas.Pewaktu := 5.5;
  LampuLaluLintas.Y := y;
  LampuLaluLintas.LamaMenunggu := 0;
  TampilkanInfo('LAMPU LALU LINTAS: merah = berhenti, kuning = bersiap berhenti, hijau = jalan.');
end;

// PerbaruiLampu: tiap GambarBingkai menggeser lampu mengikuti laju mobil, mengganti warna (merah > hijau > kuning > merah),
// lalu menilai pemain saat mobil melewati garis berhenti.
procedure PerbaruiLampu(SelangWaktu: Single);
var
  d: Single;
begin
  if not LampuLaluLintas.Aktif then Exit;
  LampuLaluLintas.Y := LampuLaluLintas.Y + MobilPemain.Speed * SelangWaktu;
  if LampuLaluLintas.Y > TINGGI_LAYAR + 250 then
  begin
    LampuLaluLintas.Aktif := False;
    Exit;
  end;

  LampuLaluLintas.Pewaktu := LampuLaluLintas.Pewaktu - SelangWaktu;
  if LampuLaluLintas.Pewaktu <= 0 then
  begin
    // Pergantian warna: setiap pewaktu habis, lampu pindah ke warna berikutnya dengan durasi berbeda.
    case LampuLaluLintas.StatusGame of
      lampuMerah:
        begin
          LampuLaluLintas.StatusGame := lampuHijau;
          LampuLaluLintas.Pewaktu := 6.0;
        end;
      lampuHijau:
        begin
          LampuLaluLintas.StatusGame := lampuKuning;
          LampuLaluLintas.Pewaktu := 1.8;
        end;
      lampuKuning:
        begin
          LampuLaluLintas.StatusGame := lampuMerah;
          LampuLaluLintas.Pewaktu := 4.5;
        end;
    end;
  end;

  // Penilaian saat mobil melewati garis:
  // merah = menerobos (-100), kuning = hanya tip (tidak dinilai), hijau = patuh (+50).
  if not LampuLaluLintas.SudahDinilai then
  begin
    d := MobilPemain.Y - LampuLaluLintas.Y;
    if (d > 0) and (d < 240) and PemainBerhenti then
      LampuLaluLintas.LamaMenunggu := LampuLaluLintas.LamaMenunggu + SelangWaktu;
    if d <= 0 then
    begin
      LampuLaluLintas.SudahDinilai := True;
      case LampuLaluLintas.StatusGame of
        lampuMerah:
          TambahSkor(-100, 'Menerobos lampu merah!');
        lampuKuning:
          TampilkanInfo('Lampu kuning: bersiap berhenti, jangan memaksakan diri menerobos.');
        lampuHijau:
          begin
            TambahSkor(50, 'Mematuhi lampu lalu lintas!');
            Inc(JumlahPatuhLampu);
          end;
      end;
    end;
  end;
end;

// GambarLampu: menggambar garis berhenti putih di jalan serta tiang dan kepala lampu di trotoar kanan.
procedure GambarLampu;
var
  px, py: Single;
  i: Integer;
  on_: Boolean;
  cr, cg, cb: Byte;
begin
  if not LampuLaluLintas.Aktif then Exit;

  { garis berhenti }
  GambarKotak(POSISI_JALAN, LampuLaluLintas.Y - 4, LEBAR_JALAN, 8, 245, 245, 245);

  { tiang dan kepala lampu di trotoar kanan }
  px := BATAS_KANAN_JALAN + 10;
  GambarKotak(px + 12, LampuLaluLintas.Y - 22, 6, 46, 90, 95, 110);
  GambarKotak(px, LampuLaluLintas.Y - 102, 30, 82, 20, 24, 36);
  GambarBingkai(px, LampuLaluLintas.Y - 102, 30, 82, 2, 71, 85, 105);
  // Gambar 3 lampu (merah, kuning, hijau). Lampu yang menyala terang dengan cahaya,
  // lampu yang mati digambar versi gelap.
  i := 0;
  while i <= 2 do
  begin
    py := LampuLaluLintas.Y - 98 + i * 26;
    case i of
      0: begin on_ := LampuLaluLintas.StatusGame = lampuMerah;    cr := 239; cg := 68;  cb := 68;  end;
      1: begin on_ := LampuLaluLintas.StatusGame = lampuKuning; cr := 250; cg := 204; cb := 21;  end;
    else
      begin on_ := LampuLaluLintas.StatusGame = lampuHijau;  cr := 34;  cg := 197; cb := 94; end;
    end;
    if on_ then
    begin
      GambarKotak(px - 2, py - 2, 34, 26, cr, cg, cb, 70);
      GambarKotak(px + 5, py, 20, 20, cr, cg, cb);
      GambarKotak(px + 8, py + 3, 6, 5, 255, 255, 255, 160);
    end
    else
      GambarKotak(px + 5, py, 20, 20, cr div 4, cg div 4, cb div 4);
    Inc(i);
  end;
end;

end.
