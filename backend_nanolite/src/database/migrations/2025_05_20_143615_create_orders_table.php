<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();

            $table->string('no_order')->unique();

            // Relasi penting
            $table->foreignId('company_id')->nullable()->constrained('companies')->nullOnDelete();
            $table->foreignId('customer_id')->constrained()->cascadeOnDelete();
            $table->foreignId('employee_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_categories_id')->nullable()->constrained('customer_categories')->nullOnDelete();
           
            $table->foreignId('department_id')
                  ->constrained('departments')
                  ->cascadeOnDelete();

            // Kontak & alamat
            $table->string('phone');
            $table->json('address');

            // Diskon
            $table->decimal('diskon_1', 5, 2)->default(0);
            $table->decimal('diskon_2', 5, 2)->default(0);
            $table->boolean('diskons_enabled')->default(false);
            $table->text('penjelasan_diskon_1')->nullable();
            $table->text('penjelasan_diskon_2')->nullable();
           

            // Detail produk dalam JSON
            $table->json('products')->nullable();

            // Jumlah produk & point reward
            $table->boolean('program_enabled')->default(false);
            $table->foreignId('customer_program_id')->nullable()->constrained('customer_programs')->nullOnDelete();
            $table->integer('jumlah_program')->default(0);
            $table->boolean('reward_enabled')->default(false);
            $table->string('reward_point')->nullable();

            // Harga total
            $table->decimal('total_harga', 15, 2)->default(0);
            $table->decimal('total_harga_after_tax', 15, 2)->default(0);

            // Status pembayaran & pengajuan
            $table->enum('payment_method', ['tempo', 'cash'])->default('tempo');
            $table->enum('status_pembayaran', ['belum bayar', 'sudah bayar'])->default('belum bayar');
            $table->enum('status', ['pending','approved','rejected'])->default('pending');

            // File order
            $table->string('order_file')->nullable();
            $table->string('order_excel')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
