# Planx-Bot

**Planx-Bot** adalah skrip Ruby untuk mengotomatiskan tugas-tugas di platform PlanX, seperti login harian, lotre, dan interaksi media sosial (misalnya, mengikuti akun atau membagikan konten). Skrip ini dirancang untuk memproses beberapa akun secara berurutan dengan dukungan proxy opsional untuk menghindari batasan.

🌟 **Fitur Utama**:
- Otomatisasi tugas PlanX (Daily Login, Lottery, Follow, Share, dll.).
- Dukungan multi-akun melalui file `data.txt`.
- Penggunaan proxy opsional melalui file `proxy.txt`.
- Output berwarna untuk memudahkan debugging (hijau untuk sukses, merah untuk gagal).
- Iterasi berulang setiap 3 jam untuk tugas harian.
- Banner keren dengan kredit pengembang.

## Prasyarat

- **Ruby**: Versi 2.7 atau lebih baru.
- **Termux** (jika dijalankan di Android) atau lingkungan Linux/Windows/MacOS.
- Koneksi internet stabil.
- Token PlanX yang valid (dimasukkan ke `data.txt`).
- Proxy opsional (dimasukkan ke `proxy.txt` untuk menghindari batasan laju).

## Instalasi

1. **Install Ruby**:
   - **Termux**:
     ```bash
     pkg update && pkg upgrade
     pkg install ruby
     ```
   - **Linux (Debian/Ubuntu)**:
     ```bash
     sudo apt update
     sudo apt install ruby
     ```
   - **Windows**: Unduh dan install Ruby dari [rubyinstaller.org](https://rubyinstaller.org/).
   - **MacOS**:
     ```bash
     brew install ruby
     ```

2. **Install Dependensi Ruby**:
   Instal gem secara manual:
   ```bash
   gem install httparty
   gem install colorize
   gem install json
   ```

3. **Clone Repositori**:
   ```bash
   git clone https://github.com/Yuurichan-N3/Planx-Bot.git
   cd Planx-Bot
   ```

4. **Siapkan File Konfigurasi**:
   - Buat file `data.txt` dan masukkan token PlanX (satu per baris). Contoh:
     ```
     eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
     eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
     ```
   - (Opsional) Buat file `proxy.txt` untuk proxy. Contoh:
     ```
     http://user:pass@proxy_ip:port
     http://192.168.1.1:8080
     ```

## Penggunaan

1. **Jalankan Skrip**:
   ```bash
   ruby bot.rb
   ```

2. **Apa yang Akan Terjadi**:
   - Skrip akan membaca token dari `data.txt` dan proxy (jika ada) dari `proxy.txt`.
   - Pada iterasi pertama, skrip akan:
     - Memproses tugas "call" (misalnya, bergabung ke komunitas, mengikuti akun).
     - Menunggu 10 detik, lalu mengklaim semua tugas.
   - Pada iterasi berikutnya (setiap 3 jam), skrip hanya mengklaim tugas harian (Daily Login dan Lottery).
   - Output akan menunjukkan status setiap tugas:
     - 🟢 `Task [nama] berhasil`
     - 🔴 `Task [nama] gagal`
   - Tekan `Ctrl+C` untuk menghentikan skrip.

3. **Catatan**:
   - Pastikan token di `data.txt` valid dan tidak kadaluarsa.
   - Gunakan proxy di `proxy.txt` jika mendapat error batasan laju (misalnya, Cloudflare 1015).
   - Skrip berjalan terus-menerus dengan delay 3 jam antar iterasi.

## Struktur File

```
Planx-Bot/
├── bot.rb
├── data.txt
├── proxy.txt
└── README.md
```

## Pemecahan Masalah

- **Error: "data.txt tidak ditemukan"**:
  - Pastikan file `data.txt` ada di direktori yang sama dengan `bot.rb` dan berisi token valid.
- **Error: "Task [nama] gagal"**:
  - Periksa token di `data.txt`. Token mungkin kadaluarsa atau salah.
  - Tambahkan proxy ke `proxy.txt` untuk menghindari batasan laju.
  - Pastikan koneksi internet stabil.
- **Error: Gem tidak ditemukan**:
  - Instal dependensi dengan `gem install httparty colorize json`.
- **Skrip berhenti tiba-tiba di Termux**:
  - Jalankan `termux-wake-lock` untuk menjaga Termux aktif.
  - Periksa penyimpanan dan koneksi internet.
 
## 📜 Lisensi  

Script ini didistribusikan untuk keperluan pembelajaran dan pengujian. Penggunaan di luar tanggung jawab pengembang.  

Untuk update terbaru, bergabunglah di grup **Telegram**: [Klik di sini](https://t.me/sentineldiscus).


---

## 💡 Disclaimer
Penggunaan bot ini sepenuhnya tanggung jawab pengguna. Kami tidak bertanggung jawab atas penyalahgunaan skrip ini.
