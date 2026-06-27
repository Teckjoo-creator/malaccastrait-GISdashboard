# OIL TANKER GIS DASHBOARD FOR STRAIT OF MALACCA
A real-time web-based maritime surveillance and intelligence system for monitoring vessel traffic through the **Strait of Malacca** — one of the world's most critical shipping chokepoints.

---

## Tajuk Projek / Project Title

**OIL TANKER GIS DASHBOARD FOR STRAIT OF MALACCA**  
_Sistem Papan Pemuka Risikan Maritim Selat Melaka_

---

## Objektif / Objectives

1. Membangunkan sistem pemantauan kapal secara real-time menggunakan peta interaktif berasaskan web.
2. Menyediakan analitik trafik maritim termasuk kiraan kapal, halaju purata, dan isipadu minyak harian.
3. Menjejak dan melogkan insiden maritim (penahanan, kehilangan AIS, penyelewengan kelajuan, dsb.).
4. Memaparkan statistik bulanan transit dan pecahan kargo melalui Selat Melaka.
5. Menyediakan REST API backend yang boleh dikembangkan untuk integrasi data AIS sebenar.

---

## Ahli Kumpulan / Group Members

| No. | Nama | Matriks |
|-----|------|---------|
| 1   | *TAN TECK JOO* | *A22BE0385* |
| 2   | *TAN QIAO YING* | *A22BE0384* |


---

##  Struktur Fail / File Structure

```
malacca-dashboard/
├── dashboard.html        # Antara muka utama (frontend)
├── api/
│   ├── index.php         # REST API endpoint router
│   └── db.php            # Konfigurasi sambungan pangkalan data (PDO)
├── malacca_db.sql        # Skrip SQL — skema + data awal
└── README.md
```

---

##  Fungsi Sistem / System Features

###  Peta Interaktif
- Peta berasaskan **Leaflet.js** dengan tile layer gelap (navigasi gaya operasi tentera)
- Penanda kapal berwarna mengikut jenis: VLCC, Suezmax, Aframax, LNG, LPG
- Klik pada penanda untuk memaparkan butiran kapal — nama, bendera, kelajuan, arah, cargo, pelabuhan asal/destinasi

### Panel KPI (Key Performance Indicators)
- Jumlah kapal aktif dalam laluan
- Bilangan kapal dalam amaran/insiden
- Isipadu minyak harian dalam thousand barrels/day (kbd)
- Halaju purata dalam knot

###  Carta & Statistik
- **Carta trafik jam-ke-jam** — bilangan kapal mengikut waktu (Chart.js)
- **Carta transit bulanan** — jumlah transit mengikut bulan dan kategori kapal
- **Pecahan kargo** — Crude, LNG, LPG, Petroleum
- **Distribusi bendera negara** — flag state paling ramai

###  Panel Insiden & Amaran
- Senarai insiden aktif mengikut keutamaan keparahan (critical → high → medium → low)
- Jenis insiden: Penahanan, Kehilangan AIS, Penyelewengan Kelajuan, Aktiviti Mencurigakan
- Koordinat insiden dipaparkan pada peta

###  REST API Backend (PHP + MySQL)
| Endpoint | Kaedah | Penerangan |
|----------|--------|------------|
| `?endpoint=vessels` | GET | Semua kapal + kedudukan terkini |
| `?endpoint=vessel&id=X` | GET | Butiran kapal tunggal |
| `?endpoint=traffic` | GET | Trafik jam-ke-jam (hari ini) |
| `?endpoint=monthly&year=YYYY` | GET | Transit bulanan mengikut tahun |
| `?endpoint=incidents` | GET | Senarai insiden aktif |
| `?endpoint=kpi` | GET | Ringkasan KPI papan pemuka |
| `?endpoint=cargo` | GET | Pecahan jenis kargo |
| `?endpoint=flags` | GET | Distribusi bendera negara |
| `?endpoint=update_position` | POST | Kemaskini kedudukan kapal |
| `?endpoint=add_incident` | POST | Log insiden baharu |

---

##  Pangkalan Data / Database

Sistem menggunakan **MySQL** dengan lima jadual utama:

| Jadual | Penerangan |
|--------|------------|
| `vessels` | Maklumat statik kapal (MMSI, IMO, nama, jenis, bendera, DWT) |
| `vessel_positions` | Rekod kedudukan GPS + kelajuan + arah + status navigasi |
| `voyages` | Maklumat pelayaran aktif (pelabuhan asal, destinasi, jenis kargo) |
| `incidents` | Log insiden dan amaran keselamatan maritim |
| `traffic_stats` | Statistik trafik jam-ke-jam |
| `monthly_transits` | Agregat transit bulanan mengikut kategori kapal |

Data awal merangkumi **16 kapal** merentasi Selat Melaka dengan koordinat sebenar dalam kawasan 1°N–5.3°N, 98°E–103.9°E.

---

##  Cara Menjalankan Sistem / How to Run

### Keperluan / Requirements
- [XAMPP](https://www.apachefriends.org/) (Apache + MySQL/MariaDB + PHP 7.4+)
- Pelayar web moden (Chrome, Firefox, Edge)
- Sambungan internet (untuk Leaflet.js CDN dan Google Fonts)

---

### Langkah-langkah / Steps

#### 1. Persediaan XAMPP
Muat turun dan pasang XAMPP. Mulakan modul **Apache** dan **MySQL** melalui XAMPP Control Panel.

#### 2. Import Pangkalan Data
1. Buka `http://localhost/phpmyadmin` dalam pelayar
2. Klik **Import** → pilih fail `malacca_db.sql`
3. Klik **Go** — pangkalan data `malacca_db` akan dicipta secara automatik bersama skema dan data awal

#### 3. Salin Fail Projek
Salin folder projek ke dalam direktori web XAMPP:
```
C:\xampp\htdocs\malacca-dashboard\
```
Pastikan struktur fail adalah seperti berikut:
```
C:\xampp\htdocs\malacca-dashboard\
├── dashboard.html
├── api\
│   ├── index.php
│   └── db.php
└── malacca_db.sql
```

#### 4. Semak Konfigurasi Database *(jika perlu)*
Buka `api/db.php` dan pastikan tetapan berikut betul:
```php
define('DB_HOST', 'localhost');
define('DB_USER', 'root');      // Pengguna XAMPP lalai
define('DB_PASS', '');          // Kata laluan lalai XAMPP: kosong
define('DB_NAME', 'malacca_db');
```

#### 5. Buka Dashboard
Buka pelayar dan pergi ke:
```
http://localhost/malacca-dashboard/dashboard.html
```

Papan pemuka akan memuatkan peta, data kapal, dan carta secara automatik melalui API.

---

##  Ujian API Secara Berasingan / Testing the API

Boleh diuji terus dalam pelayar atau menggunakan alat seperti Postman:

```
http://localhost/malacca-dashboard/api/?endpoint=vessels
http://localhost/malacca-dashboard/api/?endpoint=kpi
http://localhost/malacca-dashboard/api/?endpoint=incidents
http://localhost/malacca-dashboard/api/?endpoint=traffic
http://localhost/malacca-dashboard/api/?endpoint=monthly&year=2025
```

---

## Teknologi Digunakan / Tech Stack

| Lapisan | Teknologi |
|---------|-----------|
| Frontend | HTML5, CSS3, Vanilla JavaScript |
| Peta | [Leaflet.js](https://leafletjs.com/) v1.9.4 |
| Carta | [Chart.js](https://www.chartjs.org/) v4.4.1 |
| Tipografi | Google Fonts (Barlow Condensed, Share Tech Mono) |
| Backend | PHP 8.x (PDO, REST API) |
| Pangkalan Data | MySQL 5.7+ / MariaDB 10.3+ |
| Server | Apache (via XAMPP) |

---

## Penyelesaian Masalah / Troubleshooting

| Masalah | Penyelesaian |
|---------|-------------|
| Peta tidak muncul | Semak sambungan internet (Leaflet CDN diperlukan) |
| Data kapal tidak muncul | Pastikan Apache dan MySQL dalam XAMPP sedang berjalan |
| Ralat `Unknown database` | Import `malacca_db.sql` melalui phpMyAdmin dahulu |
| Ralat `Access denied` | Semak `DB_USER` dan `DB_PASS` dalam `api/db.php` |
| Ralat `Connection refused` | Mulakan MySQL dalam XAMPP Control Panel |
| Halaman kosong di `index.php` | Pastikan fail disimpan dalam folder `api/` bukan root |

---

## Nota / Notes

- Sistem ini menggunakan data **simulasi** dan bukan data AIS sebenar.
- Untuk penggunaan sebenar, API boleh disambungkan kepada penyedia data AIS seperti [MarineTraffic](https://www.marinetraffic.com/) atau [AISHub](https://www.aishub.net/).
- Dashboard direka bentuk dengan estetika **Military Ops Dark** — tema gelap bernuansa operasi maritim.

---

## Lesen / License

Projek ini dibangunkan untuk tujuan akademik. Sebarang penggunaan semula hendaklah dengan keizinan ahli kumpulan.
