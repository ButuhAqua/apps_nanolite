<?php

namespace App\Filament\Admin\Resources;

use App\Filament\Admin\Resources\CustomerResource\Pages;
use App\Filament\Admin\Resources\CustomerResource\Api\Transformers\CustomerTransformer;
use App\Models\Customer;
use App\Models\PostalCode;
use App\Models\Employee;
use App\Models\Department;
use App\Models\CustomerCategories;
use App\Models\CustomerProgram;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Select;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Forms\Components\Grid;
use Filament\Tables\Filters\SelectFilter;
use Filament\Forms\Components\Repeater;
use Filament\Tables\Table;
use Filament\Tables\Columns\BadgeColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Forms\Components\FileUpload;
use Filament\Tables\Columns\ImageColumn;
use Laravolt\Indonesia\Models\Provinsi;
use Laravolt\Indonesia\Models\Kabupaten;
use Laravolt\Indonesia\Models\Kecamatan;
use Laravolt\Indonesia\Models\Kelurahan;
use App\Exports\CustomerExport;
use Filament\Forms\Components\Checkbox;
use Maatwebsite\Excel\Facades\Excel;
use Illuminate\Support\Str;
use Filament\Tables\Actions\ViewAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Actions\DeleteAction;
use Filament\Tables\Actions\DeleteBulkAction;
use Filament\Tables\Actions\CreateAction;
use Illuminate\Support\Facades\Storage;
use Filament\Tables\Actions\Action;
use App\Filament\Admin\Resources\CustomerResource\Api\Handlers\CreateHandler;
use Filament\Notifications\Notification;

class CustomerResource extends Resource
{
    protected static ?string $model = Customer::class;

    protected static ?string $navigationGroup = 'Client Management';

    protected static ?string $recordTitleAttribute = 'name';

    protected static ?int $navigationSort = 3;

    public static function getApiTransformer()
    {
        return CustomerTransformer::class;
    }

    public static function getNavigationBadge(): ?string
    {
        return static::getModel()::count();
    }

    public static function form(Form $form): Form
    {
       return $form->schema([
            Select::make('department_id')
                ->label('Department')
                ->reactive()
                ->afterStateUpdated(fn($state, callable $set) => [
                    $set('employee_id', null),
                ])
                ->options(fn () => Department::where('status', 'active')->pluck('name', 'id'))
                ->required()
                ->searchable()
                ->preload()
                ->placeholder('Pilih Department'),

            Select::make('employee_id')
                ->label('Karyawan')
                ->reactive()
                ->options(function (callable $get) {
                    $departmentId = $get('department_id');
                    if (!$departmentId) return [];
                    return Employee::where('status', 'active')
                        ->where('department_id', $departmentId)
                        ->pluck('name', 'id');
                })
                ->required()
                ->searchable()
                ->preload()
                ->placeholder('Pilih Karyawan'),

            TextInput::make('name')->label('Nama Customer')->required(),
            TextInput::make('phone')->label('Telepon')->required(),
            TextInput::make('email')->label('Email')->email()->nullable(),

            Select::make('customer_categories_id')
                ->label('Kategori Customer')
                ->options(fn () => CustomerCategories::where('status', 'active')->pluck('name', 'id'))
                ->preload()->searchable()->required(),

            Select::make('customer_program_id')
                ->label('Program Customer')
                ->options(fn () => CustomerProgram::where('status', 'active')->pluck('name', 'id'))
                ->preload()->searchable()->nullable(),

            TextInput::make('gmaps_link')->label('Link Google Maps')->url()->nullable(),

            Repeater::make('address')
                ->label('Alamat')
                ->schema([
                    Select::make('provinsi')
                        ->label('Provinsi')
                        ->options(fn () => Provinsi::pluck('name', 'code')->toArray())
                        ->searchable()->reactive()
                        ->afterStateUpdated(fn (callable $set) => $set('kota_kab', null)),

                    Select::make('kota_kab')
                        ->label('Kota/Kabupaten')
                        ->options(function (callable $get) {
                            if ($prov = $get('provinsi')) {
                                return Kabupaten::where('province_code', $prov)->pluck('name', 'code')->toArray();
                            }
                            return [];
                        })
                        ->searchable()->reactive()
                        ->afterStateUpdated(fn (callable $set) => $set('kecamatan', null)),

                    Select::make('kecamatan')
                        ->label('Kecamatan')
                        ->options(function (callable $get) {
                            if ($kab = $get('kota_kab')) {
                                return Kecamatan::where('city_code', $kab)->pluck('name', 'code')->toArray();
                            }
                            return [];
                        })
                        ->searchable()->reactive()
                        ->afterStateUpdated(fn (callable $set) => $set('kelurahan', null)),

                    Select::make('kelurahan')
                        ->label('Kelurahan')
                        ->options(function (callable $get) {
                            if ($kec = $get('kecamatan')) {
                                return Kelurahan::where('district_code', $kec)->pluck('name', 'code')->toArray();
                            }
                            return [];
                        })
                        ->searchable()->reactive()
                        ->afterStateUpdated(function (callable $set, $state) {
                            $postal = \App\Models\PostalCode::where('village_code', $state)->first();
                            $set('kode_pos', $postal?->postal_code ?? null);
                        }),

                    TextInput::make('kode_pos')->label('Kode Pos')->readOnly(),
                    Textarea::make('detail_alamat')->label('Detail Alamat')->rows(3)->required(),
                ])
                ->columns(3)->defaultItems(1)
                ->disableItemCreation()->disableItemDeletion()->dehydrated(),

                FileUpload::make('image')
                ->label('Gambar')
                ->image()
                ->disk('public')          // ⬅️ penting
                ->directory('customers')
                ->visibility('public')
                ->nullable(),
            

            Select::make('status_pengajuan')
                ->label('Status Pengajuan')
                ->options([
                    'pending' => 'Pending',
                    'approved' => 'Disetujui',
                    'rejected' => 'Ditolak',
                ])
                ->default('pending')->visibleOn('edit')->searchable()->required(),

            Select::make('status')
                ->label('Status')
                ->options([
                    'pending' => 'Pending',
                    'active'     => 'Aktif',
                    'non-active' => 'Tidak Aktif',
                ])
                ->default('pending')->visibleOn('edit')->searchable()->required(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc') // 🔥 terbaru dulu
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),

                TextColumn::make('department.name')->label('Department')->searchable()->sortable(),
                TextColumn::make('employee.name')->label('Karyawan')->searchable()->sortable(),

                TextColumn::make('name')->label('Nama')->searchable()->sortable(),
                TextColumn::make('customerCategory.name')->label('Kategori Customer')->searchable()->sortable(),

                TextColumn::make('phone')->label('Telepon'),

                TextColumn::make('email')
                    ->label('Email')->searchable()->sortable()
                    ->getStateUsing(fn ($record) => $record->email ?: '-')
                    ->sortable(),

                TextColumn::make('full_address')->label('Alamat')->toggleable()->limit(50),

                TextColumn::make('gmaps_link')
                    ->label('Link Google Maps')
                    ->url(fn ($record) => $record->gmaps_link, true)
                    ->getStateUsing(fn ($record) => $record->gmaps_link ?: '-')
                    ->limit(30),

                TextColumn::make('customerProgram.name')
                    ->label('Program Customer')
                    ->getStateUsing(fn ($record) => $record->customerProgram->name ?? '-')
                    ->sortable(),

                TextColumn::make('jumlah_program')
                    ->label('Program Point')
                    ->getStateUsing(fn ($record) => $record->jumlah_program ?? 0)
                    ->sortable()->alignCenter(),

                TextColumn::make('reward_point')
                    ->label('Reward Point')
                    ->getStateUsing(fn ($record) => $record->reward_point ?? 0)
                    ->sortable()->alignCenter(),

                    ImageColumn::make('image')
                    ->label('Gambar')
                    ->getStateUsing(function ($record) {
                        $val = $record->image;
                
                        // Jika tersimpan sebagai JSON string: "[\"path1\",\"path2\"]"
                        if (is_string($val) && str_starts_with($val, '[')) {
                            $decoded = json_decode($val, true);
                            $val = is_array($decoded) ? ($decoded[0] ?? null) : $val;
                        }
                
                        // Jika array langsung
                        if (is_array($val)) {
                            $val = $val[0] ?? null;
                        }
                
                        if (blank($val)) {
                            return null;
                        }
                
                        // Buat absolut: pastikan tanpa prefix "storage/"
                        $val = preg_replace('#^/?storage/#', '', $val);
                
                        // Kalau sudah absolut, langsung pakai
                        if (preg_match('#^https?://#', $val)) {
                            return $val;
                        }
                
                        // Perlu symlink storage:link
                        return asset('storage/' . ltrim($val, '/'));
                    })
                    ->disk('public')
                    ->square(),
                

                BadgeColumn::make('status_pengajuan')
                    ->label('Status Pengajuan')
                    ->formatStateUsing(fn(string $state): string => match($state) {
                        'pending'  => 'Pending',
                        'approved' => 'Disetujui',
                        'rejected' => 'Ditolak',
                        default    => ucfirst($state),
                    })
                    ->colors([
                        'warning' => 'pending',
                        'success' => 'approved',
                        'danger'  => 'rejected',
                    ])->sortable(),

                BadgeColumn::make('status')
                    ->label('Status')
                    ->formatStateUsing(fn(string $state): string => match($state) {
                        'pending'    => 'Pending',
                        'active'     => 'Aktif',
                        'non-active' => 'Tidak Aktif',
                        default      => ucfirst($state),
                    })
                    ->colors([
                        'warning' => 'pending',
                        'success' => 'active',
                        'danger'  => 'non-active',
                    ])->sortable(),

                TextColumn::make('created_at')->label('Diajukan')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('updated_at')->label('Diupdate')->dateTime('d M Y H:i')->sortable(),
            ])
            ->filters([
                SelectFilter::make('status_pengajuan')
                    ->label('Status Pengajuan')
                    ->options([
                        'pending'  => 'Pending',
                        'approved' => 'Disetujui',
                        'rejected' => 'Ditolak',
                    ])->searchable(),

                SelectFilter::make('status')
                    ->label('Status Akun')
                    ->options([
                        'pending'  => 'Pending',
                        'active' => 'Aktif',
                        'non-active' => 'Tidak Aktif',
                    ])->searchable(),
            ])
            ->headerActions([
                Action::make('export')
                    ->label('Export Data Customer')
                    ->form([
                        Grid::make(2)->schema([
                            Select::make('department_id')->label('Department')
                                ->options(Department::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('employee_id')->label('Karyawan')
                                ->options(Employee::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('customer_categories_id')->label('Kategori Customer')
                                ->options(CustomerCategories::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('customer_program_id')->label('Program')
                                ->options(CustomerProgram::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('status_pengajuan')->label('Status Pengajuan')
                                ->options(['pending' => 'Pending','approved' => 'Approved','rejected' => 'Rejected'])
                                ->searchable(),

                            Select::make('status')->label('Status Akun')
                                ->options(['active' => 'Aktif','non-active' => 'Nonaktif'])
                                ->searchable(),

                            Checkbox::make('export_all')->label('Print Semua Data')->reactive(),
                        ])
                    ])
                    ->action(function (array $data) {
                        $export = new CustomerExport($data);
                        $rows = $export->array();

                        if (count($rows) <= 2) {
                            \Filament\Notifications\Notification::make()
                                ->title('Data Customer Tidak Ditemukan')
                                ->body('Tidak ditemukan data berdasarkan filter yang Anda pilih.')
                                ->danger()->send();
                            return null;
                        }

                        return Excel::download($export, 'export_customer.xlsx');
                    })
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\DeleteBulkAction::make(),
            ])
            ->emptyStateActions([
                Tables\Actions\CreateAction::make(),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListCustomers::route('/'),
            'create' => Pages\CreateCustomer::route('/create'),
            'edit'   => Pages\EditCustomer::route('/{record}/edit'),
        ];
    }
}