{ ==========================================================================
  PixelEduRacing  -  Game edukasi balap 2D top-down (Free Pascal + SDL3)

  main.pas : program utama
    - membuat window & renderer SDL3
    - game loop (while do)
    - membaca input keyboard
    - mengatur state: menu, cara bermain, intro level, bermain, jeda,
      level selesai, game over, hasil akhir
    - menggambar semua tampilan
  ========================================================================== }
program TugasGame;
//mengatur fpc agar menggunakan bahasa object pascal agar kita dapat menggunakan fitur
//yang ada di dalam object pascal
{$mode objfpc}{$H+}

// uses berfungsi seperti koneksi yang dimna dia dapat menghubungkan/memanggil file' lain
uses
  SysUtils, Math, sdl3, grafis, skor, suara, pemain, kendaraan, tabrakan,
  rambu_lalu_lintas, lampu_lalu_lintas, pejalan_kaki, misi;

type //membuat tipe data yg dimna kita dapat mendeklarasikan nya ke dalam variabel 
  // TStatusGame: daftar "layar/keadaan" game: menu, cara bermain, intro level, bermain, jeda,
  // level selesai, game over, dan hasil akhir. Game selalu berada di salah satunya.
  TStatusGame = (statusMenu, statusCaraBermain, statusPembukaLevel, statusBermain, statusJeda,
                statusLevelSelesai, statusGameOver, statusSelesai);

var
  // Variabel global game:
  // Jendela = jendela; StatusGame = keadaan saat ini; PilihanMenu/PilihanJeda = pilihan menu yang disorot;
  // GameBerjalan = game masih berjalan, GeserJalan = jarak gulir jalan (animasi), WaktuKedip = pewaktu teks berkedip;
  // Ev = kejadian SDL; StatusTombol = statusKecepatan keyboard; WaktuFrameLalu/WaktuFrameSekarang/SelangWaktu = pewaktu antar GambarBingkai.
  Jendela: PSDL_Window;
  StatusGame: TStatusGame;
  PilihanMenu, PilihanJeda: Integer;
  GameBerjalan: Boolean;
  GeserJalan: Double;
  WaktuKedip: Single;
  Ev: TSDL_Event;
  StatusTombol: PKeyState;
  WaktuFrameLalu, WaktuFrameSekarang: UInt64;
  SelangWaktu: Single;

{ ------------------------------------------------------------------ }
{ Alur permainan                                                     }
{ ------------------------------------------------------------------ }

// MulaiLevel: menyiapkan level n (reset mobil, lalu lintas, rambu, misi) lalu menampilkan layar intro level.
procedure MulaiLevel(n: Integer);
begin
  MulaiMisiLevel(n);
  InisialisasiTabrakan;
  StatusGame := statusPembukaLevel;
end;

// GameBaru: memulai permainan baru, skor direset dan masuk ke level 1.
procedure GameBaru;
begin
  SkorGameBaru;
  MulaiLevel(1);
end;

// TanganiTombol: menanggapi SATU KALI penekanan tombol sesuai layar yang aktif (menu, jeda, dan lain-lain).
// Tombol yang ditahan (gas, rem, belok) dibaca terpisah di PerbaruiGame.
procedure TanganiTombol(kodeTombol: UInt32);
begin
  case StatusGame of
    // Menu utama: atas/bawah memilih, Enter/Spasi mengonfirmasi (Mulai Game / Cara Bermain / Keluar).
    statusMenu:
      case kodeTombol of
        SC_UP, SC_W:      PilihanMenu := (PilihanMenu + 2) mod 3;
        SC_DOWN, SC_S:    PilihanMenu := (PilihanMenu + 1) mod 3;
        SC_RETURN, SC_SPACE:
          case PilihanMenu of
            0: GameBaru;
            1: StatusGame := statusCaraBermain;
            2: GameBerjalan := False;
          end;
        SC_ESC:           GameBerjalan := False;
      end;

    // Layar cara bermain: Enter/Esc/Spasi kembali ke menu.
    statusCaraBermain:
      case kodeTombol of
        SC_RETURN, SC_ESC, SC_SPACE: StatusGame := statusMenu;
      end;

    // Intro level: Enter/Spasi mulai bermain, Esc kembali ke menu.
    statusPembukaLevel:
      case kodeTombol of
        SC_RETURN, SC_SPACE: StatusGame := statusBermain;
        SC_ESC:              StatusGame := statusMenu;
      end;

    // Sedang bermain: Esc atau P membuka layar jeda.
    statusBermain:
      case kodeTombol of
        SC_ESC, SC_P:
          begin
            PilihanJeda := 0;
            StatusGame := statusJeda;
          end;
      end;

    // Layar jeda: pilih Lanjutkan, Ulangi Level, atau Menu Utama.
    statusJeda:
      case kodeTombol of
        SC_UP, SC_W:      PilihanJeda := (PilihanJeda + 2) mod 3;
        SC_DOWN, SC_S:    PilihanJeda := (PilihanJeda + 1) mod 3;
        SC_ESC, SC_P:     StatusGame := statusBermain;
        SC_RETURN, SC_SPACE:
          case PilihanJeda of
            0: StatusGame := statusBermain;
            1: begin
                 MulaiLevel(LevelSaatIni);
                 InisialisasiTabrakan;
                 StatusGame := statusBermain;
               end;
            2: StatusGame := statusMenu;
          end;
      end;

    // Level selesai: Enter lanjut ke level berikutnya (atau ke hasil akhir jika itu level terakhir).
    statusLevelSelesai:
      case kodeTombol of
        SC_RETURN, SC_SPACE:
          if LevelSaatIni < JUMLAH_LEVEL then
            MulaiLevel(LevelSaatIni + 1)
          else
            StatusGame := statusSelesai;
      end;

    // Game over: Enter main lagi, Esc kembali ke menu.
    statusGameOver:
      case kodeTombol of
        SC_RETURN, SC_SPACE: GameBaru;
        SC_ESC:              StatusGame := statusMenu;
      end;

    // Hasil akhir setelah semua level selesai: Enter/Esc/Spasi kembali ke menu.
    statusSelesai:
      case kodeTombol of
        SC_RETURN, SC_ESC, SC_SPACE: StatusGame := statusMenu;
      end;
  end;
end;

// PerbaruiGame: logika permainan yang dijalankan tiap GambarBingkai. SelangWaktu = detik sejak GambarBingkai sebelumnya,
// sehingga gerakan tetap sama cepat di komputer yang lambat maupun cepat.
procedure PerbaruiGame(SelangWaktu: Single);
var
  kiri, kanan, gas, rem, klakson, selesai: Boolean;
begin
  // menambah pewaktu untuk teks yang berkedip
  WaktuKedip := WaktuKedip + SelangWaktu;
  case StatusGame of
    // Di menu dan cara bermain, jalan di latar tetap bergulir pelan sebagai hiasan.
    statusMenu, statusCaraBermain:
      GeserJalan := GeserJalan + 180 * SelangWaktu;

    statusBermain:
      begin
        // Baca tombol yang sedang DITAHAN: kiri/kanan (A/D), gas (atas/W), rem (bawah/S), klakson (H/Spasi).
        StatusTombol := SDL_GetKeyboardState(nil);
        kiri  := StatusTombol^[SC_LEFT] or StatusTombol^[SC_A];
        kanan := StatusTombol^[SC_RIGHT] or StatusTombol^[SC_D];
        gas   := StatusTombol^[SC_UP] or StatusTombol^[SC_W];
        rem := StatusTombol^[SC_DOWN] or StatusTombol^[SC_SPACE];
        klakson  := StatusTombol^[SC_H] or StatusTombol^[SC_S];

        // Perbarui seluruh dunia game, satu per satu:
        // mobil pemain, jalan bergulir, mobil NPC, rambu, lampu, pejalan kaki, tabrakan, misi, lalu skor.
        PerbaruiPemain(SelangWaktu, kiri, kanan, gas, rem, klakson);
        GeserJalan := GeserJalan + MobilPemain.Speed * SelangWaktu;
        PerbaruiKendaraan(SelangWaktu);
        PerbaruiRambu(SelangWaktu);
        PerbaruiLampu(SelangWaktu);
        PerbaruiPejalanKaki(SelangWaktu);
        PerbaruiTabrakan(SelangWaktu);
        selesai := ProsesMisi(SelangWaktu);
        PerbaruiSkor(SelangWaktu);

        // Jika nyawa habis pindah ke Game Over (dan mainkan melodi). Jika misi selesai pindah ke Level Selesai.
        if ApakahGameOver then
        begin
          StatusGame := statusGameOver;
          SuaraGameOver;
        end
        else if selesai then
          StatusGame := statusLevelSelesai;
      end;
  end;
end;

{ ------------------------------------------------------------------ }
{ Menggambar                                                         }
{ ------------------------------------------------------------------ }

// GambarJalan: menggambar latar jalan yang bergulir: rumput + pohon, trotoar dengan curb merah-putih,
// aspal dengan garis tepi, dan garis tengah kuning putus-putus. Posisi gambar mengikuti GeserJalan.
procedure GambarJalan;
var
  j, k, geser, dasar, x, posisiY: Integer;
begin
  // Rumput hijau di seluruh layar, ditambah semak dan pohon pixel di kiri dan kanan jalan.
  GambarKotak(0, 0, LEBAR_LAYAR, TINGGI_LAYAR, 28, 78, 42);
  dasar := Trunc(GeserJalan / 80);
  geser := Trunc(GeserJalan) mod 80;
  j := -1;
  while j <= 9 do
  begin
    k := j - dasar;
    posisiY := j * 80 + geser;
    x := 10 + (Abs(k * 53 + 7) mod 300);
    GambarKotak(x, posisiY + 20, 8, 8, 40, 105, 55);
    GambarKotak(x + 8, posisiY + 24, 4, 4, 55, 125, 70);
    x := 910 + (Abs(k * 91 + 11) mod 320);
    GambarKotak(x, posisiY + 44, 8, 8, 40, 105, 55);
    GambarKotak(x + 8, posisiY + 48, 4, 4, 55, 125, 70);
    if (Abs(k) mod 3) = 0 then
    begin
      x := 60 + (Abs(k * 31) mod 240);
      GambarKotak(x, posisiY, 40, 40, 22, 70, 38);
      GambarKotak(x + 6, posisiY + 6, 28, 28, 30, 95, 50);
      GambarKotak(x + 12, posisiY + 10, 10, 10, 60, 135, 80);
    end;
    if (Abs(k) mod 3) = 1 then
    begin
      x := 960 + (Abs(k * 17) mod 240);
      GambarKotak(x, posisiY, 40, 40, 22, 70, 38);
      GambarKotak(x + 6, posisiY + 6, 28, 28, 30, 95, 50);
      GambarKotak(x + 12, posisiY + 10, 10, 10, 60, 135, 80);
    end;
    Inc(j);
  end;

  // Trotoar abu-abu di kedua sisi jalan, dengan curb merah-putih yang bergantian saat bergulir.
  GambarKotak(POSISI_JALAN - 42, 0, 36, TINGGI_LAYAR, 148, 157, 176);
  GambarKotak(BATAS_KANAN_JALAN + 6, 0, 36, TINGGI_LAYAR, 148, 157, 176);
  dasar := Trunc(GeserJalan / 40);
  geser := Trunc(GeserJalan) mod 40;
  j := -1;
  while j <= 18 do
  begin
    posisiY := j * 40 + geser;
    if ((j - dasar) and 1) = 0 then
    begin
      GambarKotak(POSISI_JALAN - 56, posisiY, 14, 40, 220, 38, 38);
      GambarKotak(BATAS_KANAN_JALAN + 42, posisiY, 14, 40, 220, 38, 38);
    end
    else
    begin
      GambarKotak(POSISI_JALAN - 56, posisiY, 14, 40, 240, 240, 240);
      GambarKotak(BATAS_KANAN_JALAN + 42, posisiY, 14, 40, 240, 240, 240);
    end;
    GambarKotak(POSISI_JALAN - 42, posisiY, 36, 2, 120, 128, 148);
    GambarKotak(BATAS_KANAN_JALAN + 6, posisiY, 36, 2, 120, 128, 148);
    Inc(j);
  end;

  // Aspal gelap tempat mobil berjalan, dengan garis putih di tepi kiri dan kanan.
  GambarKotak(POSISI_JALAN - 6, 0, LEBAR_JALAN + 12, TINGGI_LAYAR, 50, 54, 66);
  GambarKotak(POSISI_JALAN - 6, 0, 6, TINGGI_LAYAR, 236, 236, 236);
  GambarKotak(BATAS_KANAN_JALAN, 0, 6, TINGGI_LAYAR, 236, 236, 236);

  // Garis kuning putus-putus pemisah dua jalur; posisinya mengikuti laju mobil agar terlihat bergerak.
  geser := Trunc(GeserJalan) mod 90;
  j := -1;
  while j <= 8 do
  begin
    GambarKotak(POSISI_JALAN + LEBAR_JALUR - 3, j * 90 + geser, 6, 50, 250, 204, 21);
    Inc(j);
  end;
end;

// GambarDunia: menggambar isi dunia dari yang paling bawah ke atas: ZebraCross, lampu, rambu, mobil NPC, mobil pemain,
// lalu pejalan kaki (urutan ini menentukan siapa yang tampak di depan).
procedure GambarDunia;
begin
  GambarZebraCross;
  GambarLampu;
  GambarRambu;
  GambarKendaraan;
  GambarPemain;
  GambarPejalanKaki;
end;

// GambarInfoGame: menggambar semua panel informasi: skor, batas kecepatan, misi, kontrol keyboard, dan speedometer.
procedure GambarInfoGame;
var
  kecepatanKmh: Integer;
  statusKecepatan: string;
  over: Boolean;
begin
  GambarTampilanSkor;

  // Panel batas kecepatan: rambu bulat bertepi merah berisi angka batas (atau "--" bila bebas).
  GambarKotak(20, 160, 360, 60, 12, 18, 34, 215);
  GambarBingkai(20, 160, 360, 60, 3, 60, 75, 110);
  GambarKotak(32, 168, 44, 44, 215, 30, 40);
  GambarKotak(36, 172, 36, 36, 250, 250, 250);
  if BatasKecepatan > 0 then
    GambarTeksTengah(54, 184, IntToStr(BatasKecepatan), 2, 20, 20, 20)
  else
    GambarTeksTengah(54, 184, '--', 2, 20, 20, 20);
  GambarTeks(92, 170, 'BATAS', 2, 148, 163, 184);
  if BatasKecepatan > 0 then
    GambarTeks(92, 192, IntToStr(BatasKecepatan) + ' KM/J', 2, 255, 255, 255)
  else
    GambarTeks(92, 192, 'BEBAS', 2, 255, 255, 255);

  GambarPanelMisi;

  // Panel petunjuk kontrol keyboard di kiri-bawah.
  GambarKotak(20, 548, 360, 152, 12, 18, 34, 215);
  GambarBingkai(20, 548, 360, 152, 3, 60, 75, 110);
  GambarTeks(36, 558, 'KONTROL KEYBOARD:', 2, 250, 204, 21);
  GambarTeks(36, 586, 'GAS     : ATAS / W', 2, 255, 255, 255);
  GambarTeks(36, 608, 'REM     : BAWAH / SPASI', 2, 255, 255, 255);
  GambarTeks(36, 630, 'BELOK   : KIRI/KANAN', 2, 255, 255, 255);
  GambarTeks(36, 652, 'KLAKSON : H / SP', 2, 255, 255, 255);
  GambarTeks(36, 674, 'JEDA    : ESC', 2, 255, 255, 255);

  // Speedometer di bawah tengah: kecepatan km/j dan statusKecepatan (BERHENTI/REM/GAS/CRUISE).
  // Warna merah bila melebihi batas kecepatan, hijau bila aman.
  kecepatanKmh := KecepatanPemainKmh;
  if MobilPemain.Speed < 3 then
    statusKecepatan := 'BERHENTI'
  else if MobilPemain.Braking then
    statusKecepatan := 'REM'
  else if MobilPemain.Gassing then
    statusKecepatan := 'GAS'
  else
    statusKecepatan := 'CRUISE';
  over := (BatasKecepatan > 0) and (kecepatanKmh > BatasKecepatan + 6);
  GambarKotak(470, 672, 340, 36, 12, 18, 34, 225);
  GambarBingkai(470, 672, 340, 36, 3, 60, 75, 110);
  if over then
    GambarTeksTengah(640, 682, IntToStr(kecepatanKmh) + ' KM/J [' + statusKecepatan + ']', 2, 248, 113, 113)
  else
    GambarTeksTengah(640, 682, IntToStr(kecepatanKmh) + ' KM/J [' + statusKecepatan + ']', 2, 74, 222, 128);

  GambarPesan;
end;

{ musik latar: hanya saat bermain; jeda saat pause; berhenti di layar lain }
// SyncMusic: menyesuaikan musik latar dengan layar: main = musik jalan, jeda = musik ditahan, layar lain = berhenti.
procedure SyncMusic;
begin
  case StatusGame of
    statusBermain: AturMusik(1);
    statusJeda:  AturMusik(2);
  else
    AturMusik(0);
  end;
  PerbaruiSuara;
end;

// Dim: menggelapkan seluruh layar (kotak gelap transparan) agar panel menu/jeda lebih mudah terbaca.
procedure Dim(a: Byte);
begin
  GambarKotak(0, 0, LEBAR_LAYAR, TINGGI_LAYAR, 6, 10, 20, a);
end;

// OverlayPanel: menggambar panel kotak di tengah layar dengan bingkai berwarna, tempat teks menu/hasil ditulis.
procedure OverlayPanel(w, h: Single; r, g, b: Byte);
begin
  GambarKotak((LEBAR_LAYAR - w) / 2, (TINGGI_LAYAR - h) / 2, w, h, 12, 18, 34, 245);
  GambarBingkai((LEBAR_LAYAR - w) / 2, (TINGGI_LAYAR - h) / 2, w, h, 4, r, g, b);
end;

// GambarMenu: menggambar menu utama: judul game, tiga tombol (Mulai Game, Cara Bermain, Keluar) dengan sorotan kuning pada pilihan aktif.
procedure GambarMenu;
const
  Items: array[0..2] of string = ('MULAI GAME', 'CARA BERMAIN', 'KELUAR');
var
  i: Integer;
  y: Single;
begin
  Dim(150);
  GambarTeksTengah(640, 80, 'PIXEL EDU RACING', 6, 250, 204, 21);
  GambarTeksTengah(640, 150, 'PETUALANGAN KESELAMATAN JALAN', 3, 56, 189, 248);
  GambarTeksTengah(640, 192, 'Game edukasi rambu, lampu lalu lintas & keselamatan pejalan kaki', 1, 200, 210, 225);
  i := 0;
  while i <= 2 do
  begin
    y := 270 + i * 80;
    if i = PilihanMenu then
    begin
      GambarKotak(640 - 240, y - 12, 480, 60, 234, 179, 8, 240);
      GambarBingkai(640 - 240, y - 12, 480, 60, 3, 254, 240, 138);
      GambarTeksTengah(640, y + 2, Items[i], 4, 20, 20, 30);
    end
    else
    begin
      GambarKotak(640 - 240, y - 12, 480, 60, 12, 18, 34, 230);
      GambarBingkai(640 - 240, y - 12, 480, 60, 3, 60, 75, 110);
      GambarTeksTengah(640, y + 2, Items[i], 4, 255, 255, 255);
    end;
    Inc(i);
  end;
  GambarTeksTengah(640, 540, 'ATAS / BAWAH : pilih      ENTER : konfirmasi', 2, 148, 163, 184);
  GambarTeksTengah(640, 690, 'Free Pascal + SDL3  |  Skor Tertinggi: ' + TeksSkor(Sc.SkorTertinggi), 2, 100, 116, 139);
end;

// GambarCaraBermain: menggambar layar cara bermain: kontrol keyboard serta aturan dan skor.
procedure GambarCaraBermain;
var
  y: Single;

  procedure L(const s: string; r, g, b: Byte);
  begin
    GambarTeks(110, y, s, 2, r, g, b);
    y := y + 28;
  end;

begin
  Dim(200);
  OverlayPanel(1120, 600, 56, 189, 248);
  GambarTeksTengah(640, 76, 'CARA BERMAIN', 4, 250, 204, 21);
  y := 130;
  L('KONTROL', 56, 189, 248);
  L('ATAS / W   : gas             BAWAH / SPASI : rem', 255, 255, 255);
  L('KIRI / A   : belok kiri      KANAN / D : belok kanan', 255, 255, 255);
  L('H / S  : klakson         ESC / P   : jeda', 255, 255, 255);
  y := y + 10;
  L('ATURAN & SKOR', 56, 189, 248);
  L('Lampu MERAH: berhenti total di belakang garis (menerobos -100)', 255, 255, 255);
  L('Lampu HIJAU: boleh jalan, patuhi lampu +50', 255, 255, 255);
  L('Zebra cross: berhenti, beri jalan pejalan kaki +50 (tidak: -50)', 255, 255, 255);
  L('Rambu STOP: berhenti total +50 (menerobos -50)', 255, 255, 255);
  L('Batas kecepatan: patuhi +25 (melebihi -30)', 255, 255, 255);
  L('Dilarang masuk: jangan masuk jalur berpalang +30 (-50)', 255, 255, 255);
  L('Menabrak kendaraan -50, pejalan kaki -100, dan kehilangan 1 nyawa', 248, 113, 113);
  L('Selesaikan misi +100. Nyawa habis = PERMAINAN BERAKHIR', 74, 222, 128);
  GambarTeksTengah(640, 600, 'ENTER / ESC : kembali', 2, 148, 163, 184);
end;

// GambarPembukaLevel: menggambar intro level: judul level, misi, dan tulisan "TEKAN ENTER" yang berkedip.
procedure GambarPembukaLevel;
begin
  Dim(150);
  OverlayPanel(720, 300, 56, 189, 248);
  GambarTeksTengah(640, 230, DaftarLevel[LevelSaatIni].Judul, 3, 250, 204, 21);
  GambarTeksTengah(640, 280, 'MISI:', 2, 56, 189, 248);
  BungkusTeks(640 - 320, 312, 40, DaftarLevel[LevelSaatIni].Tujuan, 2, 255, 255, 255, True);
  if (Trunc(WaktuKedip * 2) mod 2) = 0 then
    GambarTeksTengah(640, 440, 'TEKAN ENTER UNTUK MULAI', 2, 74, 222, 128);
end;

// GambarJeda: menggambar menu jeda: Lanjutkan, Ulangi Level, Menu Utama.
procedure GambarJeda;
const
  Items: array[0..2] of string = ('LANJUTKAN', 'ULANGI LEVEL', 'MENU UTAMA');
var
  i: Integer;
  y: Single;
begin
  Dim(170);
  OverlayPanel(560, 380, 250, 204, 21);
  GambarTeksTengah(640, 190, 'JEDA', 5, 250, 204, 21);
  i := 0;
  while i <= 2 do
  begin
    y := 280 + i * 62;
    if i = PilihanJeda then
    begin
      GambarKotak(640 - 200, y - 8, 400, 48, 234, 179, 8, 240);
      GambarTeksTengah(640, y + 6, Items[i], 3, 20, 20, 30);
    end
    else
    begin
      GambarKotak(640 - 200, y - 8, 400, 48, 30, 41, 59, 240);
      GambarTeksTengah(640, y + 6, Items[i], 3, 255, 255, 255);
    end;
    Inc(i);
  end;
end;

// GambarLevelSelesai: menggambar layar "MISI SELESAI" beserta skor.
procedure GambarLevelSelesai;
begin
  Dim(160);
  OverlayPanel(720, 320, 74, 222, 128);
  GambarTeksTengah(640, 210, 'MISI SELESAI!', 5, 74, 222, 128);
  GambarTeksTengah(640, 280, DaftarLevel[LevelSaatIni].Judul, 3, 250, 204, 21);
  GambarTeksTengah(640, 330, 'SKOR: ' + TeksSkor(Sc.Skor), 3, 255, 255, 255);
  if (Trunc(WaktuKedip * 2) mod 2) = 0 then
  begin
    if LevelSaatIni < JUMLAH_LEVEL then
      GambarTeksTengah(640, 420, 'ENTER : level selanjutnya', 2, 56, 189, 248)
    else
      GambarTeksTengah(640, 420, 'ENTER : lihat hasil akhir', 2, 56, 189, 248);
  end;
end;

// GambarGameOver: menggambar layar "PERMAINAN BERAKHIR": skor akhir, jumlah pelanggaran, level, dan peringkat.
procedure GambarGameOver;
begin
  Dim(180);
  OverlayPanel(720, 400, 248, 113, 113);
  GambarTeksTengah(640, 180, 'PERMAINAN BERAKHIR', 6, 248, 113, 113);
  GambarTeksTengah(640, 255, 'Tabrakan! Nyawa habis.', 2, 255, 255, 255);
  GambarTeksTengah(640, 300, 'SKOR AKHIR: ' + TeksSkor(Sc.Skor), 3, 250, 204, 21);
  GambarTeksTengah(640, 350, 'Pelanggaran: ' + IntToStr(Sc.Pelanggaran) + '   Level: ' + IntToStr(LevelSaatIni), 2, 255, 255, 255);
  GambarTeksTengah(640, 380, PeringkatSkor, 2, 56, 189, 248);
  GambarTeksTengah(640, 450, 'ENTER : main lagi      ESC : menu utama', 2, 148, 163, 184);
end;

// GambarHasilAkhir: menggambar layar hasil akhir setelah semua level selesai: skor, hi-skor, akurasi, dan peringkat.
procedure GambarHasilAkhir;
begin
  Dim(200);
  OverlayPanel(980, 520, 250, 204, 21);
  GambarTeksTengah(640, 130, 'SELAMAT! SEMUA MISI SELESAI', 3, 74, 222, 128);
  GambarTeksTengah(640, 190, 'SKOR AKHIR: ' + TeksSkor(Sc.Skor), 4, 250, 204, 21);
  GambarTeksTengah(640, 250, 'Skor Tertinggi        : ' + TeksSkor(Sc.SkorTertinggi), 2, 255, 255, 255);
  GambarTeksTengah(640, 280, 'Tindakan benar : ' + IntToStr(Sc.PoinBenar), 2, 255, 255, 255);
  GambarTeksTengah(640, 310, 'Pelanggaran    : ' + IntToStr(Sc.Pelanggaran), 2, 255, 255, 255);
  GambarTeksTengah(640, 340, 'Akurasi        : ' + IntToStr(AkurasiSkor) + '%', 2, 255, 255, 255);
  GambarTeksTengah(640, 385, PeringkatSkor, 3, 56, 189, 248);
  BungkusTeks(640 - 400, 440, 50, 'Ingat: patuhi rambu dan lampu lalu lintas, serta selalu utamakan pejalan kaki di jalan raya.', 2, 200, 210, 225, True);
  GambarTeksTengah(640, 560, 'ENTER : menu utama', 2, 148, 163, 184);
end;

// Render: menggambar satu GambarBingkai penuh: bersihkan layar, gambar jalan, lalu gambar isi sesuai StatusGame
// (menu, cara bermain, atau dunia + HUD + panel overlay), kemudian tampilkan ke layar.
procedure Render;
begin
  SDL_SetRenderDrawColor(Perender, 0, 0, 0, 255);
  SDL_RenderClear(Perender);
  GambarJalan;
  case StatusGame of
    statusMenu:
      begin
        GambarPemain;
        GambarMenu;
      end;
    statusCaraBermain:
      GambarCaraBermain;
  else
    begin
      GambarDunia;
      GambarInfoGame;
      case StatusGame of
        statusPembukaLevel: GambarPembukaLevel;
        statusJeda:     GambarJeda;
        statusLevelSelesai:  GambarLevelSelesai;
        statusGameOver:   GambarGameOver;
        statusSelesai:   GambarHasilAkhir;
      end;
    end;
  end;
  SDL_RenderPresent(Perender);
end;

{ ------------------------------------------------------------------ }
{ Program utama                                                      }
{ ------------------------------------------------------------------ }

begin
  // PROGRAM UTAMA dimulai di sini.
  // Matikan error hitung desimal agar game tidak crash karena pembagian/overflow kecil.
  SetExceptionMask([exDenormalized, exInvalidOp, exOverflow, exPrecision,
                    exUnderflow, exZeroDivide]);
  // acak ulang angka acak supaya kendaraan dan warna berbeda setiap kali main
  Randomize;

  // Nyalakan SDL (video). Jika gagal, tampilkan pesan error lalu keluar.
  if not SDL_Init(SDL_INIT_VIDEO) then
  begin
    WriteLn('SDL_Init gagal: ', SDL_GetError);
    Halt(1);
  end;

  // Buat jendela game 1280x720 beserta kanvas gambarnya.
  if not SDL_CreateWindowAndRenderer('PixelEduRacing - Road Safety Adventure',
    LEBAR_LAYAR, TINGGI_LAYAR, 0, Jendela, Perender) then
  begin
    WriteLn('Gagal membuat window/renderer: ', SDL_GetError);
    SDL_Quit;
    Halt(1);
  end;
  // Aktifkan transparansi (panel setengah tembus pandang) dan vsync (gambar mulus sesuai refresh layar).
  SDL_SetRenderDrawBlendMode(Perender, SDL_BLENDMODE_BLEND);
  SDL_SetRenderVSync(Perender, 1);
  // Siapkan audio: musik latar, bunyi poin, tabrakan, dan game over.
  InisialisasiSuara;

  // Atur nilai awal: skor kosong, mobil di posisi awal, mulai dari layar menu.
  SkorGameBaru;
  Sc.SkorTertinggi := 0;
  InisialisasiPemain;
  StatusGame := statusMenu;
  PilihanMenu := 0;
  PilihanJeda := 0;
  GeserJalan := 0;
  WaktuKedip := 0;
  GameBerjalan := True;
  // catat waktu awal untuk menghitung SelangWaktu
  WaktuFrameLalu := SDL_GetTicks;

  // GAME LOOP: berulang terus selama game berjalan. Tiap putaran = satu GambarBingkai:
  // (1) baca input, (2) hitung SelangWaktu, (3) update logika, (4) atur musik, (5) gambar.
  while GameBerjalan do
  begin
    // (1) Baca semua kejadian: tutup jendela = keluar; tombol ditekan (bukan tahan) = TanganiTombol.
    while SDL_PollEvent(Ev) do
    begin
      case Ev.typ of
        SDL_EVENT_QUIT:
          GameBerjalan := False;
        SDL_EVENT_KEY_DOWN:
          if not Ev.kb.rep then TanganiTombol(Ev.kb.scancode);
      end;
    end;

    // (2) Hitung SelangWaktu (detik antar GambarBingkai). Dibatasi maksimal 0,05 detik agar tidak ada lompatan besar saat game tersendat.
    WaktuFrameSekarang := SDL_GetTicks;
    SelangWaktu := (Int64(WaktuFrameSekarang) - Int64(WaktuFrameLalu)) / 1000;
    WaktuFrameLalu := WaktuFrameSekarang;
    if SelangWaktu > 0.05 then SelangWaktu := 0.05;
    if SelangWaktu < 0 then SelangWaktu := 0;

    // (3) update logika, (4) sinkronkan musik, (5) gambar ke layar
    PerbaruiGame(SelangWaktu);
    SyncMusic;
    Render;
    // jeda 1 ms agar CPU tidak terpakai penuh
    SDL_Delay(1);
  end;

  // Game selesai: tutup audio, kanvas, jendela, dan SDL.
  MatikanSuara;
  SDL_DestroyRenderer(Perender);
  SDL_DestroyWindow(Jendela);
  SDL_Quit;
end.
