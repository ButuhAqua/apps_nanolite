<?php

namespace App\Filament\Admin\Resources\OrderResource\Api\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // bisa diatur pakai policy kalau perlu
    }

    public function rules(): array
    {
        return [
            /* ================= RELASI ================= */
            'company_id'             => ['required', 'integer', 'exists:companies,id'],
            'department_id'          => ['required', 'integer', 'exists:departments,id'],
            'employee_id'            => ['required', 'integer', 'exists:employees,id'],
            'customer_id'            => ['required', 'integer', 'exists:customers,id'],
            'customer_categories_id' => ['nullable', 'integer', 'exists:customer_categories,id'],
            'customer_program_id'    => ['nullable', 'integer', 'exists:customer_programs,id'],

            /* ================= PRODUK ================= */
            'products'               => ['required', 'array', 'min:1'],
            'products.*.produk_id'   => ['required', 'integer', 'exists:products,id'],
            'products.*.warna_id'    => ['nullable', 'string'],
            'products.*.quantity'    => ['required', 'integer', 'min:1'],
            'products.*.price'       => ['required', 'numeric', 'min:0'],

            /* ================= DISKON ================= */
            'diskon_1'               => ['nullable', 'numeric', 'min:0', 'max:100'],
            'penjelasan_diskon_1'    => ['nullable', 'string'],
            'diskon_2'               => ['nullable', 'numeric', 'min:0', 'max:100'],
            'penjelasan_diskon_2'    => ['nullable', 'string'],
            'diskons_enabled'        => ['boolean'],

            /* ========== PROGRAM & REWARD POINT ========= */
            'program_enabled'        => ['boolean'],
            'jumlah_program'         => ['nullable', 'integer'],
            'reward_enabled'         => ['boolean'],
            'reward_point'           => ['nullable', 'integer'],

            /* ================= TOTAL HARGA ============= */
            'total_harga'            => ['required', 'numeric', 'min:0'],
            'total_harga_after_tax'  => ['nullable', 'numeric', 'min:0'],

            /* ================= STATUS & PEMBAYARAN ===== */
            'payment_method'         => ['nullable', 'string', 'in:cash,transfer,tempo'],
            'status_pembayaran'      => ['nullable', 'string', 'in:sudah bayar,belum bayar'],
            'status'                 => ['required', 'string', 'in:pending,processing,completed,cancelled'],
        ];
    }
}
