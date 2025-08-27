<?php

namespace App\Filament\Admin\Resources\CustomerResource\Api\Transformers;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;
use Laravolt\Indonesia\Models\Provinsi;
use Laravolt\Indonesia\Models\Kabupaten;
use Laravolt\Indonesia\Models\Kecamatan;
use Laravolt\Indonesia\Models\Kelurahan;
use App\Models\PostalCode;

class CustomerTransformer extends JsonResource
{
    public function toArray($request): array
    {
        $this->resource->loadMissing([
            'department:id,name',
            'employee:id,name',
            'customerCategory:id,name',
            'customerProgram:id,name',
        ]);

        $statusPengajuanLabel = match ($this->status_pengajuan) {
            'approved' => 'Disetujui',
            'rejected' => 'Ditolak',
            default    => 'Pending',
        };

        $alamatReadable = $this->mapAddressesReadable($this->address);

        // 🔥 gabungkan alamat lengkap
        $alamatFull = null;
        if (!empty($alamatReadable)) {
            $a = $alamatReadable[0];
            $alamatFull = collect([
                $a['detail_alamat'] ?? null,
                $a['kelurahan']['name'] ?? null,
                $a['kecamatan']['name'] ?? null,
                $a['kota_kab']['name'] ?? null,
                $a['provinsi']['name'] ?? null,
                $a['kode_pos'] ?? null,
            ])
            ->filter(fn($v) => $v && trim($v) !== '-') // buang kosong/strip
            ->implode(', ');
        }

        return [
            'id'                     => $this->id,
            'company_id'             => $this->company_id,
            'department_id'          => $this->department_id,
            'employee_id'            => $this->employee_id,
            'customer_categories_id' => $this->customer_categories_id,

            'department'             => $this->department?->name ?? '-',
            'employee'               => $this->employee?->name ?? '-',
            'name'                   => $this->name ?? '-',
            'category_name'          => $this->customerCategory?->name ?? '-',
            'phone'                  => $this->phone ?? '-',
            'email'                  => $this->email,

            'alamat'                 => $alamatFull,
            'alamat_detail'          => $alamatReadable,
            'maps'                   => $this->gmaps_link,

            'customer_program_id'    => $this->customer_program_id,
            'customer_program_name'  => $this->customerProgram?->name ?? '-',

            'program_point'          => (int)($this->jumlah_program ?? 0),
            'reward_point'           => (int)($this->reward_point ?? 0),

            // ✅ fix gambar biar bisa diakses Flutter
            'image'  => (is_array($this->image) && !empty($this->image))
                        ? Storage::url($this->image[0])
                        : (is_string($this->image) ? Storage::url($this->image) : null),

            'images' => is_array($this->image)
                        ? collect($this->image)->map(fn($i) => Storage::url($i))->toArray()
                        : ((is_string($this->image) && !empty($this->image))
                            ? [Storage::url($this->image)]
                            : []),

            'status'     => $statusPengajuanLabel,
            'created_at' => optional($this->created_at)->toDateTimeString(),
            'updated_at' => optional($this->updated_at)->toDateTimeString(),
        ];
    }

    /* ---------- Helpers: address mapping ---------- */
    private function mapAddressesReadable($address): array
    {
        $items = is_array($address) ? $address : json_decode($address ?? '[]', true);
        if (!is_array($items)) $items = [];

        return array_map(function ($a) {
            // 🔥 ambil dari *_code (sesuai request Flutter)
            $provCode = $a['provinsi_code']  ?? $a['provinsi']  ?? null;
            $kabCode  = $a['kota_kab_code']  ?? $a['kota_kab']  ?? null;
            $kecCode  = $a['kecamatan_code'] ?? $a['kecamatan'] ?? null;
            $kelCode  = $a['kelurahan_code'] ?? $a['kelurahan'] ?? null;

            return [
                'detail_alamat' => $a['detail_alamat'] ?? null,
                'provinsi'      => [
                    'code' => $provCode,
                    'name' => $this->nameFromCode(Provinsi::class, $provCode),
                ],
                'kota_kab'      => [
                    'code' => $kabCode,
                    'name' => $this->nameFromCode(Kabupaten::class, $kabCode),
                ],
                'kecamatan'     => [
                    'code' => $kecCode,
                    'name' => $this->nameFromCode(Kecamatan::class, $kecCode),
                ],
                'kelurahan'     => [
                    'code' => $kelCode,
                    'name' => $this->nameFromCode(Kelurahan::class, $kelCode),
                ],
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
}
