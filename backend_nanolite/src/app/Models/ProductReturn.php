<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Support\Str;
use Maatwebsite\Excel\Facades\Excel;
use App\Exports\ProductReturnExport;
use App\Models\Concerns\OwnedByEmployee; // ⬅️ tambah
use App\Models\Concerns\LatestFirst; 

class ProductReturn extends Model
{
    use OwnedByEmployee, LatestFirst; // ⬅️ tambah

    protected $fillable = [
        'no_return',
        'company_id',
        'customer_categories_id',
        'customer_id',
        'employee_id',
        'department_id',
        'reason',
        'amount',
        'image',
        'phone',
        'note',
        'address',
        'products',
        'status',
        'return_file',
        'return_excel',
    ];

    protected $casts = [
        'company_id'             => 'integer',
        'customer_id'            => 'integer',
        'employee_id'            => 'integer',
        'department_id'          => 'integer',
        'customer_categories_id' => 'integer',
        'products'               => 'array',
        'address'                => 'array',
        'amount'                 => 'decimal:2',
        'created_at'             => 'datetime',
        'updated_at'             => 'datetime',
    ];

    protected static function booted()
    {
        static::creating(function (ProductReturn $return) {
            $return->no_return = 'RET-' . now()->format('Ymd') . strtoupper(Str::random(4));
        });

        static::saved(function (ProductReturn $return) {
            $html = view('invoices.product-return', compact('return'))->render();
            $pdf = Pdf::loadHtml($html)->setPaper('a4', 'portrait');

            $pdfFileName = "Return-{$return->no_return}.pdf";
            Storage::disk('public')->put($pdfFileName, $pdf->output());
            $return->updateQuietly(['return_file' => $pdfFileName]);

            $excelFileName = "Return-{$return->no_return}.xlsx";
            Excel::store(new ProductReturnExport($return), $excelFileName, 'public');
            $return->updateQuietly(['return_excel' => $excelFileName]);
        });
    }

    public function customer(): BelongsTo { return $this->belongsTo(Customer::class, 'customer_id'); }
    public function department(){ return $this->belongsTo(Department::class, 'department_id'); }
    public function employee(): BelongsTo { return $this->belongsTo(Employee::class, 'employee_id'); }
    public function company(): BelongsTo { return $this->belongsTo(Company::class, 'company_id'); }
    public function category(): BelongsTo { return $this->belongsTo(CustomerCategories::class, 'customer_categories_id'); }

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
