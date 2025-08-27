<?php

namespace App\Filament\Admin\Resources\GaransiResource\Api\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateGaransiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'company_id'             => 'required|exists:companies,id',
            'customer_categories_id' => 'required|exists:customer_categories,id',
            'employee_id'            => 'required|exists:employees,id',
            'customer_id'            => 'required|exists:customers,id',
            'address'                => 'nullable|array',
            'phone'                  => 'required|string|max:20',
            'products'               => 'required|array',
            'purchase_date'          => 'required|date',
            'claim_date'             => 'required|date|after_or_equal:purchase_date',
            'reason'                 => 'nullable|string',
            'note'                   => 'nullable|string',
            'image'                  => 'nullable|string',
            'status'                 => 'required|string|in:pending,approved,rejected',
        ];
    }
}
