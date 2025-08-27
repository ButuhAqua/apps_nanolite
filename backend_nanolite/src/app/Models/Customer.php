<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Support\Facades\Storage;
use Barryvdh\DomPDF\Facade\Pdf;
use Maatwebsite\Excel\Facades\Excel;
use App\Exports\CustomerExport;
use App\Exports\CustomerProgramExport;
use Illuminate\Support\Str;
use App\Models\Concerns\OwnedByEmployee; // ⬅️ tambah
use App\Models\Concerns\LatestFirst; 

class Customer extends Model
{
    use HasFactory, OwnedByEmployee, LatestFirst; // ⬅️ tambah

  
    protected $fillable = [
        'company_id',
        'customer_categories_id',
        'employee_id',
        'customer_program_id',
        'department_id',
        'name',
        'phone',
        'email',
        'address',
        'gmaps_link',
        'jumlah_program',
        'reward_point',
        'image',
        'status_pengajuan',
        'status',
    ];

    protected $casts = [
        'company_id'             => 'integer',
        'customer_categories_id' => 'integer',
        'department_id'          => 'integer',
        'employee_id'            => 'integer',
        'customer_program_id'    => 'integer',
        'address'                => 'array',
        'image'                  => 'array', // 🔥 penting untuk multi
    ];



    public function company(){ return $this->belongsTo(Company::class); }
    public function department(){ return $this->belongsTo(Department::class, 'department_id'); }
    public function customerCategory(){ return $this->belongsTo(CustomerCategories::class, 'customer_categories_id'); }
    public function customerProgram(){ return $this->belongsTo(CustomerProgram::class, 'customer_program_id'); }
    public function employee(){ return $this->belongsTo(Employee::class); }
    public function orders(){ return $this->hasMany(Order::class); }
    public function productReturns(){ return $this->hasMany(ProductReturn::class); }
    public function garansis(){ return $this->hasMany(Garansi::class); }

    protected static function booted()
    {
        static::saved(function (Customer $customer) {
            $excelFileName = "Customer-{$customer->id}.xlsx";
            Excel::store(new CustomerExport(collect([$customer])), $excelFileName, 'public');
        });
    }

    public function getFullAddressAttribute(): string
    {
        $items = is_array($this->address) ? $this->address : json_decode($this->address, true);
        if (!$items || !is_array($items)) return '-';

        return collect($items)->map(function ($i) {
            return sprintf(
                "%s, %s, %s, %s, %s, %s",
                $i['detail_alamat'] ?? '-',
                $this->getNameFromCode(\Laravolt\Indonesia\Models\Kelurahan::class, $i['kelurahan'] ?? null),
                $this->getNameFromCode(\Laravolt\Indonesia\Models\Kecamatan::class, $i['kecamatan'] ?? null),
                $this->getNameFromCode(\Laravolt\Indonesia\Models\Kabupaten::class, $i['kota_kab'] ?? null),
                $this->getNameFromCode(\Laravolt\Indonesia\Models\Provinsi::class, $i['provinsi'] ?? null),
                $i['kode_pos'] ?? '-'
            );
        })->implode('<br>');
    }

    protected function getNameFromCode($model, $code)
    {
        return $code ? optional($model::where('code', $code)->first())->name : '-';
    }
}
