<?php

namespace App\Filament\Admin\Resources\ProductReturnResource\Api\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateProductReturnRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // bisa diatur policy kalau perlu
    }

    public function rules(): array
    {
        return [
            'company_id'             => 'required|exists:companies,id',
            'customer_categories_id' => 'required|exists:customer_categories,id',
            'customer_id'            => 'required|exists:customers,id',
            'employee_id'            => 'required|exists:employees,id',
            'department_id'          => 'required|exists:departments,id',

            'reason'  => 'required|string',
            'amount'  => 'required|numeric|min:0',
            'phone'   => 'required|string|max:20',
            'note'    => 'nullable|string',

            // 👉 address boleh string ATAU array detail
            'address'                 => 'required',            // terima apa saja dulu
            'address.*.detail_alamat' => 'sometimes|string',
            'address.*.kelurahan'     => 'sometimes|string',
            'address.*.kecamatan'     => 'sometimes|string',
            'address.*.kota_kab'      => 'sometimes|string',
            'address.*.provinsi'      => 'sometimes|string',
            'address.*.kode_pos'      => 'sometimes|string',

            // 👉 products dikirim sebagai JSON string
            'products'               => 'required|json',
            // item di-validate manual setelah decode

            // file
            'image'   => 'nullable',
            'image.*' => 'file|image|max:2048',

            'status'  => 'nullable|string|in:pending,approved,rejected',
        ];
    }

    protected function passedValidation()
    {
        // Normalisasi: jika address berupa string, bungkus jadi array seragam
        if (is_string($this->address)) {
            $this->merge([
                'address' => [[
                    'detail_alamat' => $this->address,
                ]],
            ]);
        }

        // Decode products JSON agar jadi array untuk dipakai di controller/model
        if (is_string($this->products)) {
            $decoded = json_decode($this->products, true) ?: [];
            $this->merge(['products' => $decoded]);
        }

        // ===== Simpan gambar dan merge path string TANPA KUTIP =====
        $paths = [];
        $files = $this->file('image');                // terima image[] atau single

        if ($files) {
            foreach ((array) $files as $file) {
                if ($file && $file->isValid()) {
                    // Samakan folder dengan yang dipakai di admin: `product-returns`
                    $paths[] = $file->store('product-returns', 'public'); // "product-returns/xxx.jpg"
                }
            }
        }

        if (!empty($paths)) {
            // jadikan satu file pertama sebagai cover
            $this->merge([
                'image' => $paths[0],                 // <-- string bersih, bukan array/json
                // kalau mau simpan semua:
                // 'images' => $paths,
            ]);
        }
    }
}
