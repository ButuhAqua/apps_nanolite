<?php

namespace App\Filament\Admin\Resources\GaransiResource\Api\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateGaransiRequest extends FormRequest
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
            'employee_id'            => 'sometimes|exists:employees,id',
            'customer_id'            => 'sometimes|exists:customers,id',
            'address'                => 'sometimes|array',
            'phone'                  => 'sometimes|string|max:20',
            'products'               => 'sometimes|array',
            'purchase_date'          => 'sometimes|date',
            'claim_date'             => 'sometimes|date|after_or_equal:purchase_date',
            'reason'                 => 'sometimes|string|nullable',
            'note'                   => 'sometimes|string|nullable',
            'image'                  => 'sometimes|string|nullable',
            'status'                 => 'sometimes|string|in:pending,approved,rejected',
        ];
    }
}
