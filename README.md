# 🍩 Simulasi Stok Donut

## ℹ️ Konteks
Seorang manajer toko roti perlu merencanakan produksi donat hariannya agar tidak mengalami kekurangan stok maupun kelebihan stok yang merugikan. Ia memiliki data historis tentang jumlah pelanggan yang datang setiap hari serta banyaknya lusin donat yang dibeli oleh masing-masing pelanggan. Selain itu, struktur biaya sudah jelas: setiap lusin donat dijual seharga Rp80.000 dengan biaya produksi Rp55.000, sedangkan sisa donat dapat dijual ke warung terdekat dengan harga salvage Rp40.000 per lusin. Permintaan pelanggan bersifat acak dan ditentukan oleh dua distribusi diskrit, yaitu jumlah pelanggan per hari dan jumlah lusin donat yang dibeli per pelanggan.

## 🎯 Pernyataan Masalah
"Berapa lusin donat yang harus dibuat setiap harinya?"

## 📐 Formulasi Model

### a. Distribusi Statistik
**1. Pelanggan per hari**

| Jumlah pelanggan | 8 orang | 10 orang | 12 orang | 14 orang |
|------------------|---------|----------|----------|----------|
| Probabilitas     | 0.35    | 0.30     | 0.25     | 0.10     |

**2. Jumlah donat yang dibeli per pelanggan**

| Jumlah donat | 1 lusin | 2 lusin | 3 lusin | 4 lusin |
|--------------|---------|---------|---------|---------|
| Probabilitas | 0.40    | 0.30    | 0.20    | 0.10    |

### b. Parameter Ekonomi
1. Harga jual reguler: Rp80.000/lusin  
2. Biaya produksi: Rp55.000/lusin (terbayar untuk setiap lusin yang diproduksi)  
3. Harga jual salvage (stok sisa): Rp40.000/lusin

### c. Parameter Simulasi
1. Batas jumlah stok yang diuji: 100 lusin (kelipatan 5)  
2. Jumlah trial Monte Carlo per kandidat stok: 100  
3. Horizon simulasi per trial: 5 hari

## 💡 Solusi

### a. Trial
Bangun daftar kandidat stok (5, 10, 15, 20, …, stok maksimum). Untuk setiap kandidat stok, dihitung:
1. Total profit  
2. Total revenue  
3. Total regular revenue (revenue dari pelanggan)  
4. Total salvage revenue (revenue dari leftover)  
5. Total cost (stok × Rp55.000)  
6. Rata-rata leftover per hari

### b. Experiment
Untuk masing-masing kandidat stok, jalankan trial sebanyak 100 kali, lalu rangkum:
1. Mean profit  
2. Mean total revenue  
3. Mean regular revenue  
4. Mean salvage revenue  
5. Mean total cost  
6. Mean leftover rata-rata harian  
7. Standar deviasi profit (sebagai informasi tambahan yang menggambarkan sebaran profit antar trial sehingga kita memahami risiko variabilitas).

### c. Simulation Dashboard
1. **Live App**: <https://ardian.shinyapps.io/ui-ac-id-donut-stock-simulation>  
2. **Source Code**: <https://github.com/ardianibnfadl/ui.ac.id-donut-stock-simulation.git>

## 📊 Analisis
Simulasi Monte Carlo selama lima hari penjualan menunjukkan bahwa rata-rata profit meningkat seiring penambahan stok hingga mencapai titik optimum pada 20 lusin, lalu menurun secara konsisten setelahnya. Pola ini tampak jelas pada grafik Profit vs Production, yang berbentuk kurva naik-turun (concave curve), menandakan adanya batas produksi optimal sebelum kelebihan stok mulai menekan profit.

Pada titik 20 lusin, toko memperoleh mean 5-day profit tertinggi sebesar Rp2.130.800 dengan rata-rata sisa stok hanya 2 lusin per hari. Jika produksi dinaikkan menjadi 25 lusin, profit justru sedikit turun menjadi sekitar Rp2,099 juta, sementara sisa stok meningkat menjadi sekitar 5 lusin per hari. Kenaikan stok di atas 20 lusin tidak memberikan tambahan keuntungan yang berarti, tetapi meningkatkan biaya dan risiko penumpukan produk yang tidak terjual.

Dengan mempertimbangkan hasil simulasi tersebut, jumlah produksi optimal adalah 20 lusin donat per hari. Keputusan ini memberikan profit maksimum dengan tingkat efisiensi bahan yang tinggi serta jumlah sisa yang masih sangat rendah, sehingga keseimbangan antara keuntungan dan risiko kelebihan stok dapat tercapai secara optimal.

## 🚀 Jalankan Aplikasi Secara Lokal

### Prasyarat
- Sudah menginstal **R**  
- Sudah menginstal **RStudio Desktop** (opsional tetapi memudahkan)  
- Sudah menginstal paket: `shiny`, `shinydashboard`, `plotly`, `DT`

### Langkah Menjalankan
```bash
git clone https://github.com/ardianibnfadl/ui.ac.id-donut-stock-simulation.git
cd ui.ac.id-donut-stock-simulation
```

```r
install.packages(c("shiny", "shinydashboard", "plotly", "DT"))
shiny::runApp("app.R")
```
