<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Maatwebsite\Excel\Facades\Excel;
use App\Exports\OrderExport;
use Illuminate\Database\Eloquent\Casts\Attribute;
use App\Models\Product;
use Illuminate\Support\Facades\Mail;
use App\Mail\OrderInvoiceMail;
use App\Models\Concerns\OwnedByEmployee; // ⬅️ tambah
use App\Models\Concerns\LatestFirst; 

class Order extends Model
{
    use HasFactory, OwnedByEmployee, LatestFirst; // ⬅️ tambah

    protected $fillable = [
        'no_order',
        'company_id',
        'customer_id',
        'employee_id',
        'customer_categories_id',
        'customer_program_id',
        'department_id',
        'phone',
        'address',
        'diskon_1',
        'diskon_2',
        'penjelasan_diskon_1',
        'penjelasan_diskon_2',
        'diskons_enabled',
        'products',
        'jumlah_program',
        'program_enabled',
        'reward_enabled',
        'reward_point',
        'total_harga',
        'total_harga_after_tax',
        'payment_method',
        'status_pembayaran',
        'status',
        'order_file',
        'order_excel',
    ];

    protected $casts = [
        'company_id'             => 'integer',
        'customer_id'            => 'integer',
        'employee_id'            => 'integer',
        'department_id'          => 'integer',
        'customer_categories_id' => 'integer',
        'customer_program_id'    => 'integer',
        'products'               => 'array',
        'address'                => 'array',
        'diskon_1'               => 'float',
        'diskon_2'               => 'float',
        'diskons_enabled'        => 'boolean',
        'program_enabled'        => 'boolean',
        'reward_enabled'         => 'boolean',
        'jumlah_program'         => 'integer',
        'total_harga'            => 'integer',
        'total_harga_after_tax'  => 'integer',
        'status'                 => 'string',
    ];

    protected $appends = ['invoice_pdf_url', 'invoice_excel_url'];

    protected static function booted()
    {
        static::creating(function (Order $order) {
            $order->no_order = 'ORD-' . now()->format('Ymd') . strtoupper(Str::random(4));
            self::hitungHargaDanSubtotal($order);
        });

        static::updating(function (Order $order) {
            self::hitungHargaDanSubtotal($order);
        });

        static::saved(function (Order $order) {
            if (!is_array($order->products) || empty($order->products)) {
                \Log::warning("Order ID {$order->id} tidak memiliki data produk saat export.");
                return;
            }

            $html = view('invoices.order', compact('order'))->render();
            $pdf  = Pdf::loadHtml($html)->setPaper('a4', 'portrait');

            $pdfFileName = "Order-{$order->no_order}.pdf";
            Storage::disk('public')->put($pdfFileName, $pdf->output());
            $order->updateQuietly(['order_file' => $pdfFileName]);

            $excelFileName = "Order-{$order->no_order}.xlsx";
            Excel::store(new OrderExport($order), $excelFileName, 'public');
            $order->updateQuietly(['order_excel' => $excelFileName]);
        });
    }

    protected static function hitungHargaDanSubtotal(Order $order): void
    {
        $produkBaru = collect($order->products ?? [])->map(function ($item) {
            $priceRaw = $item['price'] ?? 0;
            $qty = (int) ($item['quantity'] ?? 0);

            $price = is_string($priceRaw) ? (int) str_replace('.', '', $priceRaw) : (int) $priceRaw;
            $subtotal = $price * $qty;

            $item['price'] = $price;
            $item['subtotal'] = $subtotal;
            return $item;
        });

        $total = $produkBaru->sum('subtotal');
        $disc1 = floatval($order->diskon_1 ?? 0);
        $disc2 = floatval($order->diskon_2 ?? 0);
        $isDiskonOn = $order->diskons_enabled ?? false;

        $diskonTotal = $isDiskonOn ? $disc1 + $disc2 : 0;
        $totalAfter = $total * (1 - $diskonTotal / 100);

        $order->products = $produkBaru->toArray();
        $order->total_harga = (int) $total;
        $order->total_harga_after_tax = (int) round($totalAfter);
    }

    public function getInvoicePdfUrlAttribute(): ?string
    {
        if (empty($this->order_file)) return null;
        return url(Storage::disk('public')->url($this->order_file));
    }

    public function getInvoiceExcelUrlAttribute(): ?string
    {
        if (empty($this->order_excel)) return null;
        return url(Storage::disk('public')->url($this->order_excel));
    }

    public function company(){ return $this->belongsTo(Company::class); }
    public function department(){ return $this->belongsTo(Department::class, 'department_id'); }
    public function employee(){ return $this->belongsTo(Employee::class); }
    public function customer(){ return $this->belongsTo(Customer::class); }
    public function customerCategory(){ return $this->belongsTo(CustomerCategories::class, 'customer_categories_id'); }
    public function customerProgram(){ return $this->belongsTo(CustomerProgram::class, 'customer_program_id'); }

    public function productsWithDetails(): array
    {
        $raw = $this->products;
        if (is_string($raw)) $raw = json_decode($raw, true) ?: [];
        elseif (!is_array($raw)) $raw = [];

        return array_map(function ($item) {
            $product = Product::find($item['produk_id'] ?? null);

            return [
                'brand_id'      => $product?->brand_id ?? null,
                'category_id'   => $product?->category_id ?? null,
                'product_id'    => $product?->id ?? null,
                'brand_name'    => $product?->brand?->name ?? '(Brand hilang)',
                'category_name' => $product?->category?->name ?? '(Kategori hilang)',
                'product_name'  => $product?->name ?? '(Produk hilang)',
                'color'         => $item['warna_id'] ?? '-',
                'price'         => $item['price'] ?? 0,
                'quantity'      => $item['quantity'] ?? 0,
                'subtotal'      => $item['subtotal'] ?? (($item['price'] ?? 0) * ($item['quantity'] ?? 0)),
            ];
        }, $raw);
    }

    public function getProductsDetailsAttribute(): string
    {
        $items = $this->productsWithDetails();
        if (empty($items)) return '';
        return collect($items)->map(fn($i) =>
            "{$i['brand_name']} – {$i['category_name']} – {$i['product_name']} – {$i['color']} – Rp"
            . number_format($i['price'], 0, ',', '.')
            . " – Qty: {$i['quantity']}"
        )->implode('<br>');
    }

    public function getTotalDiscountAttribute(): int
    {
        if (!$this->diskons_enabled) return 0;
        return (int) round($this->diskon_1 + $this->diskon_2);
    }

    public function getTotalAfterDiscountAttribute(): int
    {
        $total = $this->total_harga;
        $disc = $this->total_discount;
        return (int) max($total * (1 - $disc / 100), 0);
    }

    public function getTotalHargaAfterTaxAttribute(): int
    {
        $base = $this->total_after_discount;
        return (int) $base;
    }
}
