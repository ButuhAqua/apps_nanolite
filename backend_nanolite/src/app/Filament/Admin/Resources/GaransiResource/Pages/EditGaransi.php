<?php

namespace App\Filament\Admin\Resources\GaransiResource\Pages;

use App\Filament\Admin\Resources\GaransiResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditGaransi extends EditRecord
{
    protected static string $resource = GaransiResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
