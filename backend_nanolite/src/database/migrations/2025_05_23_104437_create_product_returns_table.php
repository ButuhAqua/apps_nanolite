<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('product_returns', function (Blueprint $table) {
            $table->id();

            $table->string('no_return')->unique();

            // Relasi ke company (opsional)
            $table->foreignId('company_id')
                ->nullable()
                ->constrained('companies')
                ->nullOnDelete();

            // Relasi ke customer category (opsional)
            $table->foreignId('customer_categories_id')
                ->nullable()
                ->constrained('customer_categories')
                ->nullOnDelete();

            // Relasi ke customer dan employee (wajib)
            $table->foreignId('customer_id')->constrained('customers')->onDelete('cascade');
            $table->foreignId('employee_id')->constrained('employees')->onDelete('cascade');

            $table->foreignId('department_id')
                  ->constrained('departments')
                  ->cascadeOnDelete();

            // Informasi kontak dan alamat
            $table->string('phone');
            $table->json('address');

            // Alasan return dan catatan tambahan
            $table->text('reason')->comment('Alasan Return');
            $table->text('note')->nullable()->comment('Catatan Tambahan');

            // Jika berupa uang
            $table->decimal('amount', 15, 2)->nullable()->comment('Nominal jika type = money');

            // Bukti gambar
            $table->string('image')->nullable();

            // Produk yang dikembalikan (format JSON)
            $table->json('products')->comment('Detail produk JSON');

            // Status pengembalian
            $table->enum('status', ['pending', 'approved', 'rejected'])
                ->default('pending')
                ->comment('Status refund (pending, approved, rejected)');

            // File export
            $table->string('return_file')->nullable()->comment('Path file PDF return di storage/public');
            $table->string('return_excel')->nullable()->comment('Path file Excel return di storage/public');

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('product_returns');
    }
};
