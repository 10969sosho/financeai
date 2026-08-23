# Financial Chat App — Core Concept

## 1. Tujuan

Aplikasi pencatatan keuangan yang menggunakan **chat sebagai interface utama**.

User tidak perlu mengisi form transaksi secara manual. User cukup berbicara dengan aplikasi seperti berbicara dengan asisten.

Contoh:

> "Tadi makan 25 ribu"

Aplikasi memahami transaksi dan menyimpannya ke database.

---

## 2. Core Navigation

Aplikasi hanya memiliki 3 menu utama:

### Chat

Tempat utama user berinteraksi dengan aplikasi.

Input:

* Text
* Voice
* Foto

AI dapat:

* Mencatat transaksi
* Mengubah transaksi
* Menghapus transaksi
* Menanyakan kondisi keuangan
* Menampilkan informasi keuangan

### Laporan

Menampilkan kondisi keuangan secara sederhana:

* Pengeluaran
* Pemasukan
* Mutasi
* Breakdown berdasarkan kategori
* Detail transaksi

### Profile

Pengaturan dasar user dan aplikasi.

---

## 3. Core Concept

AI bukan sekadar chatbot.

AI berfungsi sebagai **interface untuk mengelola data keuangan user**.

```text
User
 ↓
Chat
 ↓
AI
 ↓
Financial Action
 ↓
Backend
 ↓
Database
 ↓
Response
```

AI harus memahami maksud user dan menentukan tindakan yang diperlukan.

Contoh:

> "Makan tadi 30 ribu, bukan 25 ribu."

AI harus memahami bahwa transaksi sebelumnya perlu diperbarui.

---

## 4. Core Financial Data

Aplikasi minimal memiliki:

### Transaction

* Pemasukan
* Pengeluaran

Setiap transaksi memiliki informasi seperti:

* Nominal
* Kategori
* Deskripsi
* Waktu
* User

### Category

Contoh pengeluaran:

* Makanan
* Minuman
* Transportasi
* Belanja
* Hiburan
* Tagihan
* Lainnya

Contoh pemasukan:

* Gaji
* Project
* Bonus
* Transfer
* Lainnya

Kategori harus dapat dikembangkan kemudian.

---

## 5. AI Actions

AI harus dapat melakukan operasi utama terhadap data:

```text
Create Transaction
Update Transaction
Delete Transaction
Read Transaction
Get Balance
Get Report
```

AI tidak boleh dianggap sebagai database.

AI hanya menentukan **intent/action**.

Backend tetap bertanggung jawab terhadap validasi dan perubahan data.

---

## 6. Input

### Text

Contoh:

> "Beli kopi 20 ribu"

→ Pengeluaran Rp20.000
→ Kategori Minuman

### Voice

User berbicara secara natural.

Voice dikonversi menjadi text → diproses AI.

### Image

User dapat mengirim foto seperti:

* Struk belanja
* Bukti transfer
* Nota

AI mengambil informasi yang relevan dan mengubahnya menjadi transaksi.

---

## 7. Chat Session

User dapat membuat **New Session**.

Setiap session berisi percakapan user dengan AI.

Session digunakan agar AI dapat memahami konteks percakapan.

---

## 8. Laporan

Laporan harus tetap sederhana.

Contoh:

```text
Pemasukan
Rp12.500.000

Pengeluaran
Rp4.250.000

Mutasi
Rp8.250.000
```

User dapat membuka bagian tertentu untuk melihat detail.

Contoh:

```text
Pengeluaran
├── Makanan       Rp1.200.000
├── Transportasi  Rp500.000
├── Belanja       Rp800.000
└── Lainnya       Rp1.750.000
```

---

## 9. Prinsip Produk

### Simple

User tidak perlu belajar aplikasi finance.

### Conversational

Pencatatan dilakukan seperti percakapan biasa.

### Reliable

AI tidak boleh sembarangan mengubah data.

### Fast

Transaksi sederhana harus dapat dicatat dengan cepat.

### Personal

Data dan laporan setiap user terisolasi.

---

## 10. MVP

MVP pertama hanya perlu membuktikan satu hal:

> **User bisa mencatat dan mengelola keuangan hanya melalui chat.**

Prioritas:

1. Authentication
2. Chat
3. Text transaction
4. Transaction database
5. AI action
6. Laporan sederhana

Voice, foto, subscription, dan fitur tambahan dapat dikembangkan setelah core system stabil.
