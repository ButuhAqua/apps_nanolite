<?php

namespace App\Filament\Admin\Resources;

use App\Filament\Admin\Resources\ProductReturnResource\Pages;
use App\Models\ProductReturn;
use App\Models\Product;
use App\Models\Brand;
use App\Models\Department;
use App\Models\Employee;
use App\Models\CustomerCategories;
use App\Models\Customer;
use App\Models\Category;
use Filament\Forms\Form;
use Illuminate\Support\Str;
use Maatwebsite\Excel\Facades\Excel;
use Filament\Forms\Components\FileUpload;
use Filament\Tables\Columns\ImageColumn;
use Filament\Forms\Components\Hidden;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Grid;
use Filament\Forms\Components\Textarea;
use Filament\Resources\Resource;
use Filament\Tables\Table;
use App\Exports\FilteredReturnExport;
use Illuminate\Support\Facades\Storage;
use Filament\Tables\Actions\Action;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\BadgeColumn;
use Filament\Tables\Actions\ViewAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Actions\DeleteAction;
use Filament\Tables\Actions\DeleteBulkAction;
use Filament\Tables\Actions\CreateAction;
use Filament\Forms\Components\Checkbox;

class ProductReturnResource extends Resource
{
    protected static ?string $model = ProductReturn::class;
    protected static ?string $navigationGroup = 'Sales Management';
    protected static ?int    $navigationSort  = 3;
    protected static ?string $recordTitleAttribute = 'no_return';

    public static function getNavigationBadge(): ?string
    {
        return static::getModel()::count();
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Select::make('department_id')->label('Department')->reactive()
                    ->afterStateUpdated(fn($state, callable $set) => [
                        $set('employee_id', null),
                        $set('customer_categories_id', null),
                        $set('customer_id', null),
                    ])
                    ->options(fn () => Department::where('status', 'active')->pluck('name', 'id'))
                    ->required()->searchable()->preload()->placeholder('Pilih Department'),

                Select::make('employee_id')->label('Karyawan')->reactive()
                    ->afterStateUpdated(fn($state, callable $set) => [
                        $set('customer_categories_id', null),
                        $set('customer_id', null),
                    ])
                    ->options(function (callable $get) {
                        $departmentId = $get('department_id');
                        if (!$departmentId) return [];
                        return Employee::where('status', 'active')
                            ->where('department_id', $departmentId)
                            ->pluck('name', 'id');
                    })
                    ->required()->searchable()->preload()->placeholder('Pilih Karyawan'),


                Select::make('customer_categories_id')
                    ->label('Kategori Customer')
                    ->reactive()
                    ->afterStateUpdated(fn($state, callable $set) => $set('customer_id', null))
                    ->options(function (callable $get) {
                        $employeeId = $get('employee_id');
                        if (!$employeeId) {
                            return [];
                        }

                        return CustomerCategories::whereHas('customers', function ($q) use ($employeeId) {
                                $q->where('employee_id', $employeeId);
                            })
                            ->pluck('name', 'id');
                    })
                    ->required()
                    ->searchable()
                    ->preload()
                    ->placeholder('Pilih Kategori Customer'),

                Select::make('customer_id')->label('Customer')->reactive()
                    ->options(function (callable $get) {
                        $employeeId = $get('employee_id');
                        $categoryId = $get('customer_categories_id');
                        if (blank($employeeId) || blank($categoryId)) return [];
                        return Customer::where('status', 'active')
                            ->where('employee_id', $employeeId)
                            ->where('customer_categories_id', $categoryId)
                            ->pluck('name', 'id');
                    })
                    ->afterStateUpdated(function ($state, callable $set) {
                        $customer = Customer::with('customerProgram')->find($state);
                        if ($customer) {
                            $set('phone', $customer->phone);
                            $set('address', $customer->full_address);
                            $set('customer_program_id', $customer->customer_program_id ?? null);
                        } else {
                            $set('phone', null);
                            $set('address', null);
                            $set('customer_program_id', null);
                        }
                    })
                    ->required()->preload()->searchable()->placeholder('Pilih Customer'),

                TextInput::make('phone')->label('Phone')->reactive()->required(),
                Textarea::make('address')->label('Address')->reactive()->rows(2),

                TextInput::make('amount')->label('Nominal')->numeric()->prefix('Rp')->rules(['min:1'])->required(),

                Textarea::make('reason')->label('Alasan Return')->required(),
                Textarea::make('note')->label('Catatan Tambahan')->nullable(),

                FileUpload::make('image')
                    ->label('Gambar')
                    ->image()
                    ->disk('public')          // ⬅️ penting
                    ->directory('return')
                    ->visibility('public')
                    ->nullable(),


                Repeater::make('products')->label('Detail Produk')->reactive()
                    ->schema([
                        Select::make('brand_produk_id')->label('Brand')
                            ->options(fn () => Brand::pluck('name', 'id'))
                            ->afterStateUpdated(fn ($state, callable $set) => $set('kategori_produk_id', null))
                            ->required()->searchable(),

                        Select::make('kategori_produk_id')->label('Kategori')
                            ->options(fn (callable $get) => $get('brand_produk_id')
                                ? Category::where('brand_id', $get('brand_produk_id'))->pluck('name', 'id')
                                : [])
                            ->afterStateUpdated(fn ($state, callable $set) => $set('produk_id', null))
                            ->required()->searchable(),

                        Select::make('produk_id')->label('Produk')
                            ->options(fn (callable $get) => $get('kategori_produk_id')
                                ? Product::where('category_id', $get('kategori_produk_id'))->pluck('name', 'id')
                                : [])
                            ->required()->searchable(),

                        Select::make('warna_id')->label('Warna')
                            ->options(fn (callable $get) => $get('produk_id')
                                ? collect(Product::find($get('produk_id'))->colors ?? [])->mapWithKeys(fn($c) => [$c => $c])->toArray()
                                : [])
                            ->searchable()->required(),

                        TextInput::make('quantity')->label('Jumlah')->numeric()->prefix('Qty')->required(),
                    ])
                    ->columns(3)->minItems(1)->defaultItems(1)->createItemButtonLabel('Tambah Produk')->required(),

                Select::make('status')->label('Status Pengajuan Return')
                    ->options(['pending' => 'Pending','approved' => 'Disetujui','rejected' => 'Ditolak'])
                    ->default('pending')->searchable()->visible(fn ($context) => $context === 'edit')
                    ->required(fn ($context) => $context === 'edit'),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc') // 🔥 terbaru dulu
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('no_return')->label('Return Number')->sortable()->searchable(),

                TextColumn::make('department.name')->label('Department')->searchable()->sortable(),
                TextColumn::make('employee.name')->label('Karyawan')->searchable()->sortable(),
                TextColumn::make('customer.name')->label('Customer')->sortable()->searchable(),

                TextColumn::make('category.name')->label('Kategori Customer')->sortable()->searchable(),

                TextColumn::make('phone')->label('Phone')->sortable(),
                TextColumn::make('address')
    ->label('Address')
    ->formatStateUsing(function ($state) {
        // Jika string JSON -> decode
        if (is_string($state) && str_starts_with(trim($state), '{')) {
            $decoded = json_decode($state, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $state = $decoded;
            }
        }

        // Jika array/JSON, ambil bagian yang penting
        if (is_array($state)) {
            $detail = data_get($state, 'detail_alamat') ?? data_get($state, '0.detail_alamat') ?? '';
            $kel    = data_get($state, 'kelurahan.name') ?? data_get($state, 'kelurahan_name') ?? data_get($state, '0.kelurahan.name') ?? data_get($state, '0.kelurahan_name');
            $kec    = data_get($state, 'kecamatan.name') ?? data_get($state, 'kecamatan_name') ?? data_get($state, '0.kecamatan.name') ?? data_get($state, '0.kecamatan_name');
            $kota   = data_get($state, 'kota_kab.name') ?? data_get($state, 'kota_kab_name') ?? data_get($state, '0.kota_kab.name') ?? data_get($state, '0.kota_kab_name');
            $prov   = data_get($state, 'provinsi.name') ?? data_get($state, 'provinsi_name') ?? data_get($state, '0.provinsi.name') ?? data_get($state, '0.provinsi_name');
            $kode   = data_get($state, 'kode_pos') ?? data_get($state, '0.kode_pos');

            $parts = array_filter([$detail, $kel, $kec, $kota, $prov, $kode], fn ($v) =>
                filled($v) && strtolower((string)$v) !== 'null'
            );
            return $parts ? implode(', ', $parts) : '-';
        }

        // Sudah string biasa
        return $state ?: '-';
    }),


                TextColumn::make('products_details')->label('Detail Produk')->html()->sortable(),

                TextColumn::make('amount')->label('Nominal (Rp)')
                    ->formatStateUsing(fn ($state) => 'Rp ' . number_format($state, 0, ',', '.'))
                    ->sortable(),

                TextColumn::make('reason')->label('Alasan Return')->toggleable()->limit(500),

                TextColumn::make('note')->label('Catatan Tambahan')
                    ->getStateUsing(fn ($record) => ($note = trim((string) $record->note ?? '')) !== '' ? $note : '-')
                    ->wrap()->extraAttributes(['style' => 'white-space: normal;']),

                    ImageColumn::make('image')
                    ->label('Gambar')
                    ->getStateUsing(function ($record) {
                        $val = $record->image;
                
                        if (is_string($val) && str_starts_with($val, '[')) {
                            $decoded = json_decode($val, true);
                            $val = is_array($decoded) ? ($decoded[0] ?? null) : $val;
                        }
                        if (is_array($val)) {
                            $val = $val[0] ?? null;
                        }
                        if (blank($val)) {
                            return null;
                        }
                
                        $val = preg_replace('#^/?storage/#', '', $val);
                        if (preg_match('#^https?://#', $val)) {
                            return $val;
                        }
                        return asset('storage/' . ltrim($val, '/'));
                    })
                    ->disk('public')
                    ->circular(),
                

                BadgeColumn::make('status')->label('Status')
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'pending'  => 'Pending',
                        'approved' => 'Disetujui',
                        'rejected' => 'Ditolak',
                        default    => ucfirst($state),
                    })
                    ->colors(['warning' => 'pending','success' => 'approved','danger' => 'rejected'])
                    ->sortable(),

                TextColumn::make('created_at')->label('Dibuat Pada')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('updated_at')->label('Diupdate')->dateTime('d M Y H:i')->sortable(),
            ])
            ->headerActions([
                Action::make('export')->label('Export Data Return')
                    ->form([
                        Grid::make(4)->schema([
                            Select::make('department_id')->label('Department')
                                ->options(Department::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('employee_id')->label('Sales')
                                ->options(Employee::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('customer_id')->label('Customer')
                                ->options(Customer::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('customer_categories_id')->label('Kategori Customer')
                                ->options(CustomerCategories::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('status')->label('Status')
                                ->options(['pending' => 'Pending','approved' => 'Disetujui','rejected' => 'Ditolak'])
                                ->searchable(),

                            Select::make('brand_id')->label('Brand')->searchable()->options(Brand::pluck('name', 'id')),
                            Select::make('category_id')->label('Kategori Produk')->searchable()->options(Category::pluck('name', 'id')),
                            Select::make('product_id')->label('Produk')->searchable()->options(Product::pluck('name', 'id')),

                            Checkbox::make('export_all')->label('Print Semua Data')->reactive(),
                        ])
                    ])
                    ->action(function (array $data) {
                        $export = new FilteredReturnExport($data);
                        $rows = $export->array();

                        if (count($rows) <= 2) {
                            \Filament\Notifications\Notification::make()
                                ->title('Data Return Tidak Ditemukan')
                                ->body('Tidak ditemukan data Return produk berdasarkan filter yang Anda pilih. Silakan periksa kembali pilihan filter Anda.')
                                ->danger()->send();
                            return null;
                        }

                        return Excel::download($export, 'export_return.xlsx');
                    })
            ])
            ->actions([
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make(),

                Action::make('downloadInvoice')
                    ->label('Download File PDF')
                    ->icon('heroicon-o-document-arrow-down')
                    ->url(fn (ProductReturn $record) => Storage::url($record->return_file))
                    ->openUrlInNewTab()
                    ->visible(fn (ProductReturn $record) => ! empty($record->return_file)),

                Action::make('downloadExcel')
                    ->label('Download File Excel')
                    ->icon('heroicon-o-document-arrow-down')
                    ->url(fn (ProductReturn $record) => Storage::url($record->return_excel))
                    ->openUrlInNewTab()
                    ->visible(fn (ProductReturn $record) => ! empty($record->return_excel)),
            ])
            ->bulkActions([
                DeleteBulkAction::make(),
            ])
            ->emptyStateActions([
                CreateAction::make(),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListProductReturns::route('/'),
            'create' => Pages\CreateProductReturn::route('/create'),
            'edit'   => Pages\EditProductReturn::route('/{record}/edit'),
        ];
    }
}