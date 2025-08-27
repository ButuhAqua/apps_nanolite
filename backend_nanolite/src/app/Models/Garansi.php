<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Product;
use Illuminate\Support\Facades\Storage;
use Barryvdh\DomPDF\Facade\Pdf;
use Maatwebsite\Excel\Facades\Excel;
use App\Exports\GaransiExport;
use Illuminate\Support\Str;
use App\Models\Concerns\OwnedByEmployee; // ⬅️ tambah
use App\Models\Concerns\LatestFirst; 

class Garansi extends Model
{
    use HasFactory, OwnedByEmployee, LatestFirst; // ⬅️ tambah

    protected $fillable = [
        'no_garansi',
        'company_id',
        'customer_categories_id',
        'employee_id',
        'customer_id',
        'department_id',
        'address',
        'phone',
        'products',
        'purchase_date',
        'claim_date',
        'reason',
        'note',
        'image',
        'status',
        'garansi_file',
        'garansi_excel',
    ];

    protected $casts = [
        'company_id'             => 'integer',
        'customer_id'            => 'integer',
        'employee_id'            => 'integer',
        'department_id'          => 'integer',
        'customer_categories_id' => 'integer',
        'address'                => 'array',
        'products'               => 'array',
        'purchase_date'          => 'date',
        'claim_date'             => 'date',
    ];

    public function company(){ return $this->belongsTo(Company::class); }
    public function customerCategory(){ return $this->belongsTo(CustomerCategories::class, 'customer_categories_id'); }
    public function department(){ return $this->belongsTo(Department::class, 'department_id'); }
    public function employee(){ return $this->belongsTo(Employee::class); }
    public function customer(){ return $this->belongsTo(Customer::class); }

    protected static function booted()
    {
        static::creating(function (Garansi $garansi) {
            $garansi->no_garansi = 'GAR-' . now()->format('Ymd') . strtoupper(Str::random(4));
        });

        static::saved(function (Garansi $garansi) {
            $html = view('invoices.garansi', compact('garansi'))->render();
            $pdf = Pdf::loadHtml($html)->setPaper('a4', 'portrait');

            $pdfFileName = "Garansi-{$garansi->no_garansi}.pdf";
            Storage::disk('public')->put($pdfFileName, $pdf->output());
            $garansi->updateQuietly(['garansi_file' => $pdfFileName]);

            $excelFileName = "Garansi-{$garansi->no_garansi}.xlsx";
            Excel::store(new GaransiExport($garansi), $excelFileName, 'public');
            $garansi->updateQuietly(['garansi_excel' => $excelFileName]);
        });
    }

    public function productsWithDetails(): array
    {
        $raw = $this->products;
        if (is_string($raw)) $raw = json_decode($raw, true) ?: [];
        elseif (!is_array($raw)) $raw = [];

        return array_map(function ($item) {
            $product = Product::find($item['produk_id'] ?? null);
            return [
                'brand_name'    => $product?->brand?->name ?? '(Brand hilang)',
                'category_name' => $product?->category?->name ?? '(Kategori hilang)',
                'product_name'  => $product?->name ?? '(Produk hilang)',
                'color'         => $item['warna_id'] ?? '-',
                'quantity'      => $item['quantity'] ?? 0,
            ];
        }, $raw);
    }

    public function getProductsDetailsAttribute(): string
    {
        $items = $this->productsWithDetails();
        if (empty($items)) return '';
        return collect($items)->map(fn ($i) =>
            "{$i['brand_name']} – {$i['category_name']} – {$i['product_name']} – {$i['color']} – Qty: {$i['quantity']}"
        )->implode('<br>');
    }
}
