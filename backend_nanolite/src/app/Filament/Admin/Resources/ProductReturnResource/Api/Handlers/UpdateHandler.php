<?php

namespace App\Filament\Admin\Resources\ProductReturnResource\Api\Handlers;

use App\Filament\Admin\Resources\ProductReturnResource;
use App\Filament\Admin\Resources\ProductReturnResource\Api\Requests\UpdateProductReturnRequest;
use Rupadana\ApiService\Http\Handlers;
use Illuminate\Support\Facades\Storage;

class UpdateHandler extends Handlers
{
    public static ?string $uri = '/{record}';

    public static ?string $resource = ProductReturnResource::class;

    public static function getMethod()
    {
        return Handlers::PUT;
    }

    public static function getModel()
    {
        return static::$resource::getModel();
    }

    /**
     * Update ProductReturn
     */
    public function handler(UpdateProductReturnRequest $request, $record)
    {
        $model = $record;

        // isi semua field kecuali image
        $data = $request->except('image');
        $model->fill($data);

        // handle multi-upload image
        if ($request->hasFile('image')) {
            // hapus foto lama kalau ada
            if ($model->image) {
                $oldFiles = json_decode($model->image, true);
                if (is_array($oldFiles)) {
                    foreach ($oldFiles as $old) {
                        if (Storage::disk('public')->exists($old)) {
                            Storage::disk('public')->delete($old);
                        }
                    }
                }
            }

            // upload baru
            $paths = [];
            foreach ($request->file('image') as $file) {
                $paths[] = $file->store('product-returns', 'public');
            }
            $model->image = json_encode($paths);
        }

        $model->save();

        return static::sendSuccessResponse($model, 'Successfully Update ProductReturn');
    }
}
