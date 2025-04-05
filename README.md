# PlanX Task Bot - Python & Ruby

Skrip otomatisasi untuk menyelesaikan tugas harian di PlanX Wallet, tersedia dalam dua bahasa: **Python** dan **Ruby**. Keduanya memiliki fungsi yang sama: menjalankan dan mengklaim tugas harian seperti *Daily Login* dan *Lottery*.

## Fitur

- Mendukung tugas harian PlanX (Call + Claim)
- Token didecode dari JWT untuk mengambil `user_id`
- Support multi akun
- Python: mendukung multi-thread dan logging warna-warni
- Otomatis berjalan setiap 3 jam 10 menit (versi Python)

## Kebutuhan

Python (`bot.py`)

- Python 3.8+
- Install dependencies:

```bash
pip install requests rich
```

Ruby (`bot.rb`)

Ruby 2.7+

Install dependencies:

```
gem install httparty
gem install colorize
```

### Cara Jalankan

Python

```
python bot.py
```

Akan diminta memasukkan jumlah thread.

Ruby

```
ruby bot.rb
```

### Format (`data.txt`)

Isi file data.txt dengan token JWT, satu per baris:

```
Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

Pastikan token diawali dengan Bearer .

## 📜 Lisensi  

Script ini didistribusikan untuk keperluan pembelajaran dan pengujian. Penggunaan di luar tanggung jawab pengembang.  

Untuk update terbaru, bergabunglah di grup **Telegram**: [Klik di sini](https://t.me/sentineldiscus).


---

## 💡 Disclaimer
Penggunaan bot ini sepenuhnya tanggung jawab pengguna. Kami tidak bertanggung jawab atas penyalahgunaan skrip ini.


---
