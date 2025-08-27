<?php

namespace App\Filament\Admin\Resources\ProductReturnResource\Api\Handlers;

use App\Filament\Admin\Resources\ProductReturnResource;
use App\Filament\Admin\Resources\ProductReturnResource\Api\Requests\CreateProductReturnRequest;
use Rupadana\ApiService\Http\Handlers;

class CreateHandler extends Handlers
{
    public static ?string $uri = '/';

    public static ?string $resource = ProductReturnResource::class;

    public static function getMethod()
    {
        return Handlers::POST;
    }

    public static function getModel()
    {
        return static::$resource::getModel();
    }

    /**
     * Create ProductReturn
     */
    public function handler(CreateProductReturnRequest $request)
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
                $paths[] = $file->store('product-returns', 'public');
            }
        }

        if (!empty($paths)) {
            $model->image = json_encode($paths);
        }

        $model->save();

        return static::sendSuccessResponse($model, 'Successfully Create ProductReturn');
    }
}
