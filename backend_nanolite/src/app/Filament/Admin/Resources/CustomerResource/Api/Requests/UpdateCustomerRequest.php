<?php

namespace App\Filament\Admin\Resources\ProductReturnResource\Api\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProductReturnRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'company_id'             => 'sometimes|exists:companies,id',
            'customer_categories_id' => 'sometimes|exists:customer_categories,id',
            'department_id'          => 'sometimes|exists:departments,id',
            'customer_id'            => 'sometimes|exists:customers,id',
            'employee_id'            => 'sometimes|exists:employees,id',

            'reason' => 'sometimes|string',
            'amount' => 'sometimes|numeric|min:0',
            'phone'  => 'sometimes|string|max:20',
            'note'   => 'nullable|string',

            // ✅ alamat repeater
            'address'                       => 'nullable|array',
            'address.*.detail_alamat'       => 'sometimes|string',
            'address.*.kelurahan'           => 'sometimes|string',
            'address.*.kecamatan'           => 'sometimes|string',
            'address.*.kota_kab'            => 'sometimes|string',
            'address.*.provinsi'            => 'sometimes|string',
            'address.*.kode_pos'            => 'sometimes|string',

            // ✅ produk
            'products'                      => 'nullable|array|min:1',
            'products.*.produk_id'          => 'required_with:products|integer|exists:products,id',
            'products.*.warna_id'           => 'required_with:products|string',
            'products.*.quantity'           => 'required_with:products|integer|min:1',

            // ✅ multi foto update
            'image'   => 'nullable|array',
            'image.*' => 'file|image|max:2048',

            'status'  => 'nullable|string|in:pending,approved,rejected',
        ];
    }
}
