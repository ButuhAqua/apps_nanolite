<?php

namespace App\Filament\Admin\Resources\CustomerResource\Api\Handlers;

use App\Filament\Admin\Resources\CustomerResource;
use App\Filament\Admin\Resources\CustomerResource\Api\Requests\UpdateCustomerRequest;
use Rupadana\ApiService\Http\Handlers;
use Illuminate\Support\Facades\Storage;

class UpdateHandler extends Handlers
{
    public static ?string $uri = '/{record}';
    public static ?string $resource = CustomerResource::class;

    public static function getMethod()
    {
        return Handlers::PUT;
    }

    public static function getModel()
    {
        return static::$resource::getModel();
    }

    /**
     * Update Customer
     */
    public function handler(UpdateCustomerRequest $request, $record)
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
                $paths[] = $file->store('customers', 'public');
            }
            $model->image = json_encode($paths);
        }

        $model->save();

        return static::sendSuccessResponse($model, 'Successfully Update Customer');
    }
}
