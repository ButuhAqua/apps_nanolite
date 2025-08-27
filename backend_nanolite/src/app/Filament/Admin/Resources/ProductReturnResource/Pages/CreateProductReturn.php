<?php

namespace App\Filament\Admin\Resources\ProductReturnResource\Pages;

use App\Filament\Admin\Resources\ProductReturnResource;
use Filament\Actions;
use Filament\Resources\Pages\CreateRecord;

class CreateProductReturn extends CreateRecord
{
    protected static string $resource = ProductReturnResource::class;
    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data['status'] = 'pending';
        return $data;
    }

}
