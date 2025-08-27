<?php

namespace App\Filament\Admin\Resources;

use App\Filament\Admin\Resources\GaransiResource\Pages;
use App\Models\Garansi;
use App\Models\Employee;
use App\Models\Customer;
use App\Models\Brand;
use App\Models\Department;
use App\Models\CustomerCategories;
use App\Models\Category;
use App\Models\Product;
use Filament\Forms\Form;
use Filament\Tables\Filters\SelectFilter;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Repeater;
use Illuminate\Support\Str;
use Filament\Resources\Resource;
use Illuminate\Support\Facades\Storage;
use Filament\Forms\Components\FileUpload;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Table;
use Filament\Forms\Components\Grid;
use Filament\Tables\Actions\Action;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\BadgeColumn;
use Filament\Tables\Actions\ViewAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Actions\DeleteAction;
use Filament\Tables\Actions\DeleteBulkAction;
use Filament\Tables\Actions\CreateAction;
use App\Exports\FilteredGaransiExport;
use Filament\Forms\Components\Checkbox;
use Maatwebsite\Excel\Facades\Excel;

class GaransiResource extends Resource
{
    protected static ?string $model = Garansi::class;
    protected static ?string $navigationGroup = 'Sales Management';
    protected static ?int    $navigationSort  = 5;
    protected static ?string $recordTitleAttribute = 'no_garansi';

    public static function getNavigationBadge(): ?string
    {
        return static::getModel()::count();
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Select::make('department_id')
                    ->label('Department')
                    ->reactive()
                    ->afterStateUpdated(fn($state, callable $set) => [
                        $set('employee_id', null),
                        $set('customer_categories_id', null),
                        $set('customer_id', null),
                    ])
                    ->options(fn () => Department::where('status', 'active')->pluck('name', 'id'))
                    ->required()->searchable()->preload()->placeholder('Pilih Department'),

                Select::make('employee_id')
                    ->label('Karyawan')
                    ->reactive()
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
                    ->options(fn () => CustomerCategories::pluck('name', 'id'))
                    ->required()->searchable()->preload()->placeholder('Pilih Kategori Customer'),

                Select::make('customer_id')
                    ->label('Customer')
                    ->reactive()
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

                DatePicker::make('purchase_date')->label('Tanggal Pembelian')->required(),
                DatePicker::make('claim_date')->label('Tanggal Klaim Garansi')->required(),

                Textarea::make('reason')->label('Alasan Pengajuan Garansi')->required(),
                Textarea::make('note')->label('Catatan Tambahan')->nullable(),

                Repeater::make('products')
                    ->label('Detail Produk')->reactive()
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
                            ->required()->searchable(),

                        TextInput::make('quantity')->label('Jumlah')->numeric()->prefix('Qty')->required(),
                    ])
                    ->columns(3)->minItems(1)->defaultItems(1)->createItemButtonLabel('Tambah Produk')->required(),

                FileUpload::make('image')->label('Foto')->image()->directory('garansi-photos')->maxSize(2048),

                Select::make('status')->label('Status Pengajuan Garansi')
                    ->options(['pending' => 'Pending','approved' => 'Disetujui','rejected' => 'Ditolak'])
                    ->default('pending')->visible(fn ($context) => $context === 'edit')->searchable()
                    ->required(fn ($context) => $context === 'edit'),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc') // 🔥 terbaru dulu
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('no_garansi')->label('Garansi Number')->sortable()->searchable(),

                TextColumn::make('department.name')->label('Department')->searchable()->sortable(),
                TextColumn::make('employee.name')->label('Karyawan')->searchable()->sortable(),
                TextColumn::make('customer.name')->label('Customer')->sortable()->searchable(),
                TextColumn::make('customerCategory.name')->label('Kategori Customer')->sortable()->searchable(),

                TextColumn::make('phone')->label('Phone')->sortable(),
                TextColumn::make('address')->label('Address')->limit(50),

                TextColumn::make('products_details')->label('Detail Produk')->html()->sortable(),
                TextColumn::make('purchase_date')->label('Tanggal Pembelian')->date()->sortable(),
                TextColumn::make('claim_date')->label('Tanggal Klaim')->date()->sortable(),

                TextColumn::make('reason')->label('Alasan Klaim Garansi')->toggleable()->limit(500),

                TextColumn::make('note')->label('Catatan Tambahan')
                    ->getStateUsing(fn ($record) => ($note = trim((string) $record->note ?? '')) !== '' ? $note : '-')
                    ->wrap()->extraAttributes(['style' => 'white-space: normal;']),

                ImageColumn::make('image')->label('Gambar')->circular(),

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
                Action::make('export')
                    ->label('Export Data Garansi')
                    ->form([
                        Grid::make(4)->schema([
                            Select::make('department_id')->label('Department')
                                ->options(Department::pluck('name', 'id'))->searchable()->preload(),

                            Select::make('employee_id')->label('Karyawan')
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
                        $export = new FilteredGaransiExport($data);
                        $rows = $export->array();

                        if (count($rows) <= 2) {
                            \Filament\Notifications\Notification::make()
                                ->title('Data Garansi Tidak Ditemukan')
                                ->body('Tidak ditemukan data Garansi produk berdasarkan filter yang Anda pilih. Silakan periksa kembali pilihan filter Anda.')
                                ->danger()->send();
                            return null;
                        }

                        return Excel::download($export, 'export_garansi.xlsx');
                    })
            ])
            ->actions([
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make(),

                Action::make('downloadInvoice')
                    ->label('Download File PDF')
                    ->icon('heroicon-o-document-arrow-down')
                    ->url(fn (Garansi $record) => Storage::url($record->garansi_file))
                    ->openUrlInNewTab()
                    ->visible(fn (Garansi $record) => ! empty($record->garansi_file)),

                Action::make('downloadExcel')
                    ->label('Download File Excel')
                    ->icon('heroicon-o-document-arrow-down')
                    ->url(fn (Garansi $record) => Storage::url($record->garansi_excel))
                    ->openUrlInNewTab(),
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
            'index'  => Pages\ListGaransis::route('/'),
            'create' => Pages\CreateGaransi::route('/create'),
            'edit'   => Pages\EditGaransi::route('/{record}/edit'),
        ];
    }
}
