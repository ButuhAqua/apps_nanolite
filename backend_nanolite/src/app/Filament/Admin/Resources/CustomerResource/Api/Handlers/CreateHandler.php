<?php

namespace App\Filament\Admin\Resources\CustomerResource\Api\Handlers;

use App\Filament\Admin\Resources\CustomerResource;
use App\Filament\Admin\Resources\CustomerResource\Api\Requests\CreateCustomerRequest;
use Rupadana\ApiService\Http\Handlers;
use Illuminate\Support\Facades\Storage;

class CreateHandler extends Handlers
{
    public static ?string $uri = '/';
    public static ?string $resource = CustomerResource::class;

    public static function getMethod()
    {
        return Handlers::POST;
    }

    public static function getModel()
    {
        return static::$resource::getModel();
    }

    /**
     * Create Customer
     */
    public function handler(CreateCustomerRequest $request)
    {
        $model = new (static::getModel());

        // isi semua field kecuali image
        $data = $request->except('image');
        $model->fill($data);

        // handle multi-upload image
        $paths = [];
        $files = $request->file('image') ?? $request->file('image.*') ?? $request->file('image[]');

        if ($files) {
            foreach ((array) $files as $file) {
                $paths[] = $file->store('customers', 'public');
            }
        }

        if (!empty($paths)) {
            $model->image = json_encode($paths);
        }


        $model->save();

        return static::sendSuccessResponse($model, 'Successfully Create Customer');
    }
}
