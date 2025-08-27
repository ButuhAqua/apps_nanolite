<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('garansis', function (Blueprint $table) {
            $table->id();


            $table->string('no_garansi')->unique();

            // Relasi ke company (nullable)
            $table->foreignId('company_id')
                  ->nullable()
                  ->constrained('companies')
                  ->nullOnDelete();

            // Relasi ke customer category (nullable)
            $table->foreignId('customer_categories_id')
                  ->nullable()
                  ->constrained('customer_categories')
                  ->nullOnDelete();

            // Relasi ke employee & customer
            $table->foreignId('employee_id')
                  ->constrained('employees')
                  ->cascadeOnDelete();

            $table->foreignId('department_id')
                  ->constrained('departments')
                  ->cascadeOnDelete();
                  

            $table->foreignId('customer_id')
                  ->constrained('customers')
                  ->cascadeOnDelete();

            // Data alamat dan kontak
            $table->json('address');
            $table->string('phone');

            // Detail produk (brand, kategori, produk, warna, quantity)
            $table->json('products')->comment('Detail produk JSON');

            // Tanggal pembelian dan klaim
            $table->date('purchase_date')->comment('Tanggal Pembelian');
            $table->date('claim_date')->comment('Tanggal Klaim Garansi');

            // Alasan dan catatan
            $table->text('reason')->comment('Alasan Mengajukan Garansi');
            $table->text('note')->nullable()->comment('Catatan Tambahan');

            // Foto bukti jika ada
            $table->string('image')->nullable();

            // Status proses
            $table->enum('status', ['pending', 'approved', 'rejected'])
                  ->default('pending')
                  ->comment('Status Pengajuan Garansi');

            // File PDF dan Excel
            $table->string('garansi_file')->nullable()->comment('Path file PDF garansi di storage/public');
            $table->string('garansi_excel')->nullable()->comment('Path file Excel garansi di storage/public');

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('garansis');
    }
};
