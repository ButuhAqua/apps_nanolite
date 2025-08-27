<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Support\Facades\Storage;
use Barryvdh\DomPDF\Facade\Pdf;
use Maatwebsite\Excel\Facades\Excel;
use App\Exports\CustomerProgramExport;
use Illuminate\Support\Str;


class CustomerProgram extends Model
{
    protected $fillable = [
        'company_id',
        'name',
        'status',
        'deskripsi',
    ];

    protected $casts = [
        'company_id' => 'integer',
    ];

    /**
     * Relasi ke perusahaan pemilik program
     */

    protected static function booted()
    {
        static::saved(function (CustomerProgram $program) {
        $slug = Str::slug($program->name);
        // Buat nama file berdasarkan ID dan nama program
        $excelFileName = "CustomerProgram-{$program->id}-{$slug}.xlsx";

        // Export satu program dalam bentuk collection
        Excel::store(new CustomerProgramExport(collect([$program])), $excelFileName, 'public');
        });
    }

    

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    /**
     * Relasi many-to-many ke banyak kategori pelanggan
     */
    public function customerCategories()
    {
        return $this->belongsToMany(CustomerCategories::class, 'customer_category_customer_program', 'program_id', 'category_id');
    }

    /**
     * Relasi ke semua pelanggan yang tergabung dalam program ini
     */
    public function customers()
    {
        return $this->hasMany(Customer::class, 'customer_program_id');
    }

    /**
     * Relasi ke semua karyawan yang menangani program ini
     */
    public function employees()
    {
        return $this->hasMany(Employee::class, 'customer_program_id');
    }

    /**
     * Relasi ke semua pesanan dari pelanggan yang mengikuti program ini
     */
    public function orders()
    {
        return $this->hasMany(Order::class, 'customer_program_id');
    }

}
