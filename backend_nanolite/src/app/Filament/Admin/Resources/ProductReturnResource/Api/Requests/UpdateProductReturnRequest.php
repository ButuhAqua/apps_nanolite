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
            'company_id'              => ['sometimes', 'integer', 'exists:companies,id'],
            'customer_categories_id'  => ['sometimes', 'integer', 'exists:customer_categories,id'],
            'customer_id'             => ['sometimes', 'integer', 'exists:customers,id'],
            'employee_id'             => ['sometimes', 'integer', 'exists:employees,id'],
            'reason'                  => ['sometimes', 'string'],
            'amount'                  => ['sometimes', 'numeric', 'min:0'],
            'image'                   => ['sometimes', 'string'],
            'phone'                   => ['sometimes', 'string'],
            'note'                    => ['sometimes', 'string'],
            'address'                 => ['sometimes', 'array'],
            'address.detail_alamat'   => ['sometimes', 'string'],
            'address.kelurahan'       => ['sometimes', 'string'],
            'address.kecamatan'       => ['sometimes', 'string'],
            'address.kota_kab'        => ['sometimes', 'string'],
            'address.provinsi'        => ['sometimes', 'string'],
            'address.kode_pos'        => ['sometimes', 'string'],
            'products'                => ['sometimes', 'array', 'min:1'],
            'products.*.produk_id'    => ['required_with:products', 'integer', 'exists:products,id'],
            'products.*.warna_id'     => ['required_with:products', 'string'],
            'products.*.quantity'     => ['required_with:products', 'integer', 'min:1'],
            'status'                  => ['sometimes', 'in:pending,approved,rejected'],
        ];
    }
}
