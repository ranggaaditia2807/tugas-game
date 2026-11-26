# PixelEduRacing - Petualangan Keselamatan Jalan

Game edukasi berkendara 2D tampak atas yang dibuat menggunakan Free Pascal dan SDL3.

## Cara kompilasi (Windows)
1. Pastikan Free Pascal 32-bit tersedia dan sesuai dengan `SDL3.dll`.
2. Pastikan `SDL3.dll` berada di folder utama proyek.
3. Buka PowerShell di folder utama proyek.
4. Jalankan `build.bat`.
5. Setelah kompilasi berhasil, jalankan `src\main.exe`.

Perintah kompilasi manual:
```powershell
fpc -Mobjfpc -Sh -O2 -vew -Fu"src" -FU"compile" "src\main.pas"
```

## Berkas source
- `main.pas`: program utama dan alur permainan.
- `grafis.pas`: fungsi menggambar objek dan teks.
- `pemain.pas`: pergerakan mobil pemain.
- `kendaraan.pas`: kendaraan lain (NPC).
- `pejalan_kaki.pas`: pejalan kaki dan zebra cross.
- `lampu_lalu_lintas.pas`: aturan lampu lalu lintas.
- `rambu_lalu_lintas.pas`: aturan rambu lalu lintas.
- `tabrakan.pas`: deteksi tabrakan.
- `misi.pas`: pengaturan level dan misi.
- `skor.pas`: skor, nyawa, dan pesan informasi.
- `suara.pas`: musik dan efek suara.
- `sdl3.pas`: binding SDL3; nama API dipertahankan sesuai library.

## Kontrol
- Atas / W: gas.
- Bawah / S: rem.
- Kiri / A dan Kanan / D: belok.
- H / Spasi: klakson.
- ESC / P: jeda.
- Enter: pilih atau konfirmasi.

## Level permainan
1. Jalan Kota.
2. Lampu Lalu Lintas.
3. Zona Sekolah.
4. Jalan Raya.
5. Persimpangan Ramai.

Kata kunci Pascal, tipe data bawaan, dan fungsi SDL3 tidak diterjemahkan karena merupakan bagian dari bahasa dan library.
