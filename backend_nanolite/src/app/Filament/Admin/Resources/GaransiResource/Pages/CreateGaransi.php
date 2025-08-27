<?php

namespace App\Filament\Admin\Resources\GaransiResource\Pages;

use App\Filament\Admin\Resources\GaransiResource;
use Filament\Actions;
use Filament\Resources\Pages\CreateRecord;

class CreateGaransi extends CreateRecord
{
    protected static string $resource = GaransiResource::class;
    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data['status'] = 'pending';
        return $data;
    }

}
