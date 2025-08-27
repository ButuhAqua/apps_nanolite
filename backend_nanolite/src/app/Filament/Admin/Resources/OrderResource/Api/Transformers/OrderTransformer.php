<?php

namespace App\Filament\Admin\Resources\OrderResource\Api\Transformers;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;
use App\Models\Product;
use Laravolt\Indonesia\Models\Provinsi;
use Laravolt\Indonesia\Models\Kabupaten;
use Laravolt\Indonesia\Models\Kecamatan;
use Laravolt\Indonesia\Models\Kelurahan;
use App\Models\PostalCode;

class OrderTransformer extends JsonResource
{
    public function toArray($request): array
    {
        $this->resource->loadMissing([
            'department:id,name',
            'employee:id,name',
            'customer:id,name,customer_category_id,phone,address',
            'customerCategory:id,name',
            'customerProgram:id,name',
        ]);

        $statusPembayaranLabel = match ($this->status_pembayaran) {
            'sudah bayar' => 'Sudah Bayar',
            'belum bayar' => 'Belum Bayar',
            default       => ucfirst((string)$this->status_pembayaran),
        };

        $statusLabel = match ($this->status) {
            'approved' => 'Disetujui',
            'rejected' => 'Ditolak',
            'pending'  => 'Pending',
            default    => ucfirst((string)$this->status),
        };

        $alamatReadable   = $this->mapAddressesReadable($this->address);
        $productsReadable = $this->mapProductsReadable($this->products);

        return [
            'no_order'             => $this->no_order,
            'department'           => $this->department?->name ?? '-',
            'employee'             => $this->employee?->name ?? '-',

            // Relasi customer & kategori
            'customer_id'          => $this->customer?->id ?? null,
            'customer'             => $this->customer?->name ?? '-',
            'customer_category_id' => $this->customer?->customer_category_id ?? null,
            'customer_category'    => $this->customerCategory?->name ?? '-',
            'customer_program_id'  => $this->customerProgram?->id ?? null,
            'customer_program'     => $this->customerProgram?->name ?? null,

            // Kontak
            'phone'                => $this->customer?->phone ?? $this->phone,
            'address_text'         => $this->addressText($alamatReadable),
            'address_detail'       => $alamatReadable,

            // Produk
            'products'             => $productsReadable,

            // Diskon
            'diskon' => [
                'enabled'             => (bool)($this->diskons_enabled ?? false),
                'diskon_1'            => (float)($this->diskon_1 ?? 0),
                'penjelasan_diskon_1' => $this->penjelasan_diskon_1,
                'diskon_2'            => (float)($this->diskon_2 ?? 0),
                'penjelasan_diskon_2' => $this->penjelasan_diskon_2,
            ],

            // Reward & Program Point
            'reward' => [
                'enabled' => (bool)($this->reward_enabled ?? false),
                'points'  => (int)($this->reward_point ?? 0),
            ],
            'program_point' => [
                'enabled' => (bool)($this->program_enabled ?? false),
                'points'  => (int)($this->jumlah_program ?? 0),
            ],

            // Status & pembayaran
            'payment_method'       => $this->payment_method === 'tempo' ? 'Tempo' : 'Cash',
            'status_pembayaran'    => $statusPembayaranLabel,
            'status'               => $statusLabel,

            // Total harga
            'total_harga'          => (int)($this->total_harga ?? 0),
            'total_harga_after_tax'=> (int)($this->total_harga_after_tax ?? 0),

            // File unduhan
            'invoice_pdf_url'      => $this->order_file  ? Storage::url($this->order_file)  : null,
           
            'created_at'           => optional($this->created_at)->format('d/m/Y'),
            'updated_at'           => optional($this->updated_at)->format('d/m/Y'),
        ];
    }

    /* ---------------- Helpers ---------------- */

    private function addressText(array $items): ?string
    {
        if (empty($items)) return null;
        return collect($items)->map(function ($a) {
            $parts = [
                $a['detail_alamat'] ?? null,
                $a['kelurahan']['name'] ?? null,
                $a['kecamatan']['name'] ?? null,
                $a['kota_kab']['name'] ?? null,
                $a['provinsi']['name'] ?? null,
                $a['kode_pos'] ?? null,
            ];
            return implode(', ', array_filter($parts));
        })->join(' | ');
    }

    private function mapAddressesReadable($address): array
    {
        $items = is_array($address) ? $address : json_decode($address ?? '[]', true);
        if (!is_array($items)) $items = [];

        return array_map(function ($a) {
            $provCode = $a['provinsi']  ?? null;
            $kabCode  = $a['kota_kab']  ?? null;
            $kecCode  = $a['kecamatan'] ?? null;
            $kelCode  = $a['kelurahan'] ?? null;

            return [
                'detail_alamat' => $a['detail_alamat'] ?? null,
                'provinsi'      => ['code' => $provCode, 'name' => $this->nameFromCode(Provinsi::class, $provCode)],
                'kota_kab'      => ['code' => $kabCode,  'name' => $this->nameFromCode(Kabupaten::class, $kabCode)],
                'kecamatan'     => ['code' => $kecCode,  'name' => $this->nameFromCode(Kecamatan::class, $kecCode)],
                'kelurahan'     => ['code' => $kelCode,  'name' => $this->nameFromCode(Kelurahan::class, $kelCode)],
                'kode_pos'      => $a['kode_pos'] ?? $this->postalByVillage($kelCode),
            ];
        }, $items);
    }

    private function nameFromCode(string $model, ?string $code): ?string
    {
        if (!$code) return null;
        return optional($model::where('code', $code)->first())->name;
    }

    private function postalByVillage(?string $villageCode): ?string
    {
        if (!$villageCode) return null;
        return optional(PostalCode::where('village_code', $villageCode)->first())->postal_code;
    }

    private function mapProductsReadable($products): array
    {
        $items = is_array($products) ? $products : json_decode($products ?? '[]', true);
        if (!is_array($items)) $items = [];

        return array_map(function ($p) {
            $product = isset($p['produk_id'])
                ? Product::with(['brand:id,name', 'category:id,name'])->find($p['produk_id'])
                : null;

            // Ambil warna dari JSON product->colors
        $colorName = null;
        if ($product && !empty($p['warna_id'])) {
            $colors = collect($product->colors ?? []);
            $colorObj = $colors->firstWhere('id', $p['warna_id']);
            $colorName = $colorObj['name'] ?? $p['warna_id'];
        }

            return [
                'brand'    => $product?->brand?->name ?? null,
                'category' => $product?->category?->name ?? null,
                'product'  => $product?->name ?? null,
                'color'    => $colorName,
                'quantity' => (int)($p['quantity'] ?? 0),
                'price'    => isset($p['price']) ? (int)$p['price'] : null,
                'subtotal' => isset($p['subtotal']) ? (int)$p['subtotal'] : null,
            ];
        }, $items);
    }
}
