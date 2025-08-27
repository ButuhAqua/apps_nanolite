<?php

namespace App\Filament\Admin\Resources\CustomerResource\Api\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // izinkan semua request (bisa diubah pakai policy)
    }

    public function rules(): array
    {
        return [
            'company_id'             => 'required|exists:companies,id',
            'customer_categories_id' => 'required|exists:customer_categories,id',
            'department_id'          => 'required|exists:departments,id',
            'employee_id'            => 'nullable|exists:employees,id',
            'customer_program_id'    => 'nullable|exists:customer_programs,id',

            'name'   => 'required|string|max:255',
            'phone'  => 'required|string|max:20',
            'email'  => 'nullable|email',

            'address'     => 'nullable|array',
            'gmaps_link'  => 'nullable|string',
            'jumlah_program' => 'nullable|integer',
            'reward_point'   => 'nullable|integer',

            // ✅ multi foto
            'image'   => 'nullable',
            'image.*' => 'file|image|max:1048',     
             // max 2MB per foto

            'status'  => 'nullable|string|in:active,inactive,pending',
        ];
    }
}
