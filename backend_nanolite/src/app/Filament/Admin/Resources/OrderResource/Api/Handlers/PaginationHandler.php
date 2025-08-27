<?php

namespace App\Filament\Admin\Resources\OrderResource\Api\Handlers;

use App\Filament\Admin\Resources\OrderResource;
use App\Support\ApiPaging;
use Rupadana\ApiService\Http\Handlers;
use Spatie\QueryBuilder\QueryBuilder;
use App\Filament\Admin\Resources\OrderResource\Api\Transformers\OrderTransformer;
use App\Models\CustomerProgram;
use App\Models\Customer;

class PaginationHandler extends Handlers
{
    use ApiPaging;

    public static ?string $uri = '/';
    public static ?string $resource = OrderResource::class;

    public function handler()
    {
        switch (request('type')) {
            case 'departments':
                return \App\Models\Department::select('id','name')
                    ->orderBy('name')
                    ->get();

            case 'employees':
                return \App\Models\Employee::select('id','name')
                    ->when(request('department_id'), function ($q) {
                        $q->where('department_id', request('department_id'));
                    })
                    ->orderBy('name')
                    ->get();

            case 'customer-categories':
                return \App\Models\CustomerCategory::select('id','name')
                    ->orderBy('name')
                    ->get();

            case 'customers':
                return Customer::select('id','name','phone','customer_categories_id','customer_program_id')
                    ->when(request('customer_category_id'), function ($q) {
                        $q->where('customer_categories_id', request('customer_category_id'));
                    })
                    ->orderBy('name')
                    ->get();

            case 'customer-programs':
                if (request('customer_id')) {
                    $customer = Customer::with('customerProgram')->find(request('customer_id'));
                    if ($customer && $customer->customerProgram) {
                        return collect([$customer->customerProgram->only('id','name')]);
                    }
                    return collect([]);
                }
                return CustomerProgram::select('id','name')
                    ->orderBy('name')
                    ->get();
        }

        // default pagination
        $paginator = QueryBuilder::for(static::getModel())
            ->allowedFilters([
                'status',
                'status_pembayaran',
                'payment_method',
                'customer_id',
                'employee_id',
                'department_id',
                'customer_categories_id',
            ])
            ->with([
                'department:id,name',
                'employee:id,name',
                'customer:id,name',
                'customerCategory:id,name',
                'customerProgram:id,name',
            ])
            ->latest('id')
            ->paginate($this->perPage(request()))
            ->appends(request()->query())
            ->through(fn ($row) => new OrderTransformer($row));

        return static::sendSuccessResponse($paginator, 'Order list retrieved successfully');
    }
}
