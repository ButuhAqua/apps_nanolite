<?php

namespace App\Filament\Admin\Resources;

use App\Filament\Admin\Resources\OrderResource\Pages;
use App\Models\Order;
use App\Models\Brand;
use App\Models\Department;
use App\Models\Employee;
use App\Models\CustomerProgram;
use App\Models\Category;
use App\Models\CustomerCategories;
use App\Models\Product;
use App\Models\Customer;
use Filament\Forms\Form;
use Filament\Tables\Filters\SelectFilter;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Textarea;
use Filament\Resources\Resource;
use Filament\Forms\Components\Grid;
use Filament\Notifications\Notification;
use Filament\Tables\Table;
use Filament\Tables\Columns\BadgeColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Actions\ViewAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Actions\DeleteAction;
use Filament\Tables\Actions\DeleteBulkAction;
use Filament\Tables\Actions\CreateAction;
use Filament\Tables\Actions\Action;
use Illuminate\Support\Facades\Storage;
use App\Exports\FilteredOrdersExport;
use Filament\Forms\Components\Checkbox;
use Maatwebsite\Excel\Facades\Excel;

class OrderResource extends Resource
{
    protected static ?string $model                = Order::class;
    protected static ?string $navigationGroup      = 'Sales Management';
    protected static ?int    $navigationSort       = 2;
    protected static ?string $recordTitleAttribute = 'no_order';

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

                TextInput::make('reward_point')->label('Poin Reward')->numeric()->reactive()
                    ->disabled(fn($get) => ! $get('reward_enabled'))->default(0)->nullable()->required()->dehydrated(true),

                Toggle::make('reward_enabled')->label('Reward Aktif')->reactive(),

                TextInput::make('jumlah_program')->label('Poin Program')->numeric()->reactive()
                    ->disabled(fn($get) => ! $get('program_enabled'))->default(0)->dehydrated(),

                Toggle::make('program_enabled')->label('Program Aktif')->reactive(),

                Select::make('customer_program_id')->label('Program Pelanggan')
                    ->options(fn () => CustomerProgram::pluck('name', 'id'))
                    ->disabled()->dehydrated()->default(null)->searchable(),

                Toggle::make('diskons_enabled')->label('Diskon Aktif')->live()
                    ->afterStateUpdated(fn($state, callable $set) => $set('total_harga_after_tax', null))
                    ->reactive(),

                TextInput::make('diskon_1')->label('Diskon 1 (%)')->numeric()->live()->reactive()
                    ->disabled(fn($get) => ! $get('diskons_enabled'))
                    ->afterStateUpdated(fn($state, callable $set) => $set('total_harga_after_tax', null))
                    ->default(0)->helperText('Masukkan persentase diskon pertama (contoh: 10 untuk 10%)'),

                TextInput::make('penjelasan_diskon_1')->label('Penjelasan Diskon 1')
                    ->required()->dehydrated()->disabled(fn($get) => ! $get('diskons_enabled'))->nullable(),

                TextInput::make('diskon_2')->label('Diskon 2 (%)')->numeric()->live()->reactive()
                    ->disabled(fn($get) => ! $get('diskons_enabled'))
                    ->afterStateUpdated(fn($state, callable $set) => $set('total_harga_after_tax', null))
                    ->default(0)->helperText('Masukkan persentase diskon pertama (contoh: 10 untuk 10%)'),

                TextInput::make('penjelasan_diskon_2')->label('Penjelasan Diskon 2')
                    ->required()->dehydrated()->disabled(fn($get) => ! $get('diskons_enabled'))->nullable(),

                Select::make('payment_method')->label('Metode Pembayaran')
                    ->options(['tempo' => 'Tempo','cash'  => 'Cash'])->required()->searchable(),

                TextInput::make('total_harga')->label('Total Harga')->disabled()->prefix('Rp')
                    ->dehydrated()->reactive()->numeric()->live()
                    ->afterStateHydrated(fn(callable $set, $state) => $set('total_harga', $state)),

                Select::make('status_pembayaran')->label('Status Pembayaran')
                    ->options(['belum bayar' => 'Belum Bayar','sudah bayar' => 'Sudah Bayar'])->required()->searchable(),

                TextInput::make('total_harga_after_tax')->label('Total Harga Akhir')->disabled()->prefix('Rp')
                    ->dehydrated()->numeric()->reactive()->live()
                    ->afterStateHydrated(function (callable $set, callable $get) {
                        $total = collect($get('products') ?? [])->sum(fn($i) => $i['subtotal'] ?? 0);
                        $disc1 = floatval($get('diskon_1') ?? 0);
                        $disc2 = floatval($get('diskon_2') ?? 0);
                        $isDiskonOn = $get('diskons_enabled') ?? false;

                        $totalDiskon = $isDiskonOn ? $disc1 + $disc2 : 0;
                        $totalAkhir = $total * (1 - $totalDiskon / 100);

                        $set('total_harga_after_tax', round($totalAkhir));
                    }),

                Repeater::make('products')->label('Detail Produk')->reactive()->live()
                    ->schema([
                        Select::make('brand_produk_id')->label('Brand')
                            ->options(fn() => Brand::pluck('name','id'))
                            ->reactive()
                            ->afterStateUpdated(fn($state, callable $set) => [
                                $set('kategori_produk_id', null),
                                $set('produk_id', null),
                                $set('warna_id', null),
                            ])
                            ->required()->searchable(),

                        Select::make('kategori_produk_id')->label('Kategori')
                            ->options(fn(callable $get) =>
                                $get('brand_produk_id')
                                    ? Category::where('brand_id', $get('brand_produk_id'))->pluck('name','id')
                                    : []
                            )
                            ->reactive()
                            ->afterStateUpdated(fn($state, callable $set) => [
                                $set('produk_id', null),
                                $set('warna_id', null),
                            ])->searchable()->required(),

                        Select::make('produk_id')->label('Produk')
                            ->options(fn(callable $get) => $get('kategori_produk_id')
                                ? Product::where('category_id', $get('kategori_produk_id'))->pluck('name','id')
                                : [])
                            ->reactive()
                            ->afterStateUpdated(function($state, callable $set, callable $get) {
                                $price = Product::find($state)?->price ?? 0;
                                $set('price', $price);
                                $set('subtotal', $price * ($get('quantity') ?? 0));
                            })
                            ->searchable()->required(),

                        Select::make('warna_id')->label('Warna')
                            ->options(fn(callable $get) => $get('produk_id')
                                ? collect(Product::find($get('produk_id'))->colors ?? [])->mapWithKeys(fn($c) => [$c => $c])->toArray()
                                : [])
                            ->required()->searchable(),

                        TextInput::make('price')->label('Harga / Produk')->prefix('Rp')->disabled()->live()->numeric()
                            ->dehydrated()
                            ->dehydrateStateUsing(fn($state) => is_string($state) ? (int) str_replace('.', '', $state) : $state),

                        TextInput::make('quantity')->label('Jumlah')->reactive()->prefix('Qty')->numeric()
                            ->afterStateUpdated(function ($state, callable $set, callable $get) {
                                $price = (int) ($get('price') ?? 0);
                                $qty = (int) $state;

                                $subtotal = $price * $qty;
                                $set('subtotal', $subtotal);

                                $products = $get('../../products') ?? [];
                                $totalHarga = collect($products)->sum(fn($item) => $item['subtotal'] ?? 0);
                                $set('../../total_harga', $totalHarga);

                                $diskon1 = floatval($get('../../diskon_1') ?? 0);
                                $diskon2 = floatval($get('../../diskon_2') ?? 0);
                                $isDiskonOn = $get('../../diskons_enabled') ?? false;
                                $diskonPersen = $isDiskonOn ? $diskon1 + $diskon2 : 0;

                                $totalAkhir = $totalHarga * (1 - $diskonPersen / 100);

                                if ($totalAkhir < 1000) {
                                    Notification::make()
                                        ->title('Total terlalu kecil, mohon periksa kembali diskon dan quantity.')
                                        ->danger()->persistent()->send();

                                    $set('../../total_harga_after_tax', null);
                                    return;
                                }

                                $set('../../total_harga_after_tax', round($totalAkhir));
                            })
                            ->required(),

                        TextInput::make('subtotal')->label('Subtotal')->disabled()->prefix('Rp')->dehydrated()->numeric()->live(),
                    ])
                    ->columns(3)->defaultItems(1)->minItems(1)->createItemButtonLabel('Tambah Produk')->dehydrated(),

                Select::make('status')->label('Status')
                    ->options(['approved' => 'Disetujui','rejected' => 'Ditolak'])
                    ->visibleOn('edit')->required()->searchable()
                    ->afterStateUpdated(function ($state, callable $get) {
                        if ($state === 'approved') {
                            $customerId = $get('customer_id');
                            $reward = (int) $get('reward_point');
                            $program = (int) $get('jumlah_program');

                            if ($customerId) {
                                $customer = Customer::find($customerId);
                                if ($customer) {
                                    $customer->reward_point = ($customer->reward_point ?? 0) + $reward;

                                    if ($customer->customer_program_id) {
                                        $customer->jumlah_program = ($customer->jumlah_program ?? 0) + $program;
                                    }

                                    $customer->save();
                                }
                            }
                        }
                    }),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->query(Order::withCount('customer'))
            ->defaultSort('created_at', 'desc') // 🔥 terbaru dulu
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('no_order')->label('Order Number')->sortable()->searchable(),

                TextColumn::make('department.name')->label('Department')->searchable()->sortable(),
                TextColumn::make('employee.name')->label('Karyawan')->searchable()->sortable(),
                TextColumn::make('customer.name')->label('Customer')->sortable()->searchable(),
                TextColumn::make('customerCategory.name')->label('Kategori Customer')->sortable()->searchable(),

                TextColumn::make('address')->label('Address')->limit(50),
                TextColumn::make('phone')->label('Telepon')->sortable(),

                TextColumn::make('products_details')->label('Detail Produk')->html()->searchable()->sortable(),

                TextColumn::make('total_harga')->label('Total Harga')
                    ->formatStateUsing(fn ($state) => 'Rp ' . number_format($state, 0, ',', '.'))
                    ->sortable(),

                TextColumn::make('semua_diskon')->label('Diskon')
                    ->getStateUsing(function ($record) {
                        $d1 = $record->diskon_1 ?? 0;
                        $d2 = $record->diskon_2 ?? 0;
                        if ((float)$d1 === 0.0 && (float)$d2 === 0.0) return '-';
                        return collect([$d1, $d2])->filter(fn($v) => (float)$v > 0)->map(fn($v) => "{$v}%")->implode(' + ');
                    })
                    ->sortable(),

                TextColumn::make('penjelasan_diskon')->label('Penjelasan Diskon')
                    ->getStateUsing(function ($record) {
                        $d1 = trim($record->penjelasan_diskon_1 ?? '');
                        $d2 = trim($record->penjelasan_diskon_2 ?? '');
                        if ($d1 === '' && $d2 === '') return '-';
                        return collect([$d1, $d2])->filter()->implode(' + ');
                    })
                    ->wrap()->extraAttributes(['style' => 'white-space: normal;'])->sortable(),

                TextColumn::make('customerProgram.name')->label('Program Pelanggan')->searchable()
                    ->getStateUsing(fn ($record) => $record->customerProgram->name ?? '-'),

                TextColumn::make('jumlah_program')->label('Program Point')->alignCenter()
                    ->formatStateUsing(fn($state) => !$state ? '-' : "{$state}"),

                TextColumn::make('reward_point')->label('Reward Point')->alignCenter()
                    ->formatStateUsing(fn($state) => !$state ? '-' : "{$state}"),

                TextColumn::make('total_harga_after_tax')->label('Total Akhir')
                    ->formatStateUsing(fn ($state) => 'Rp ' . number_format($state, 0, ',', '.'))
                    ->sortable(),

                TextColumn::make('payment_method')->label('Metode Pembayaran')->alignCenter()->searchable()->sortable(),

                BadgeColumn::make('status_pembayaran')->label('Status Pembayaran')
                    ->formatStateUsing(fn(string $state): string => match($state) {
                        'belum bayar' => 'Belum Bayar',
                        'sudah bayar' => 'Sudah Bayar',
                        default       => ucfirst($state),
                    })
                    ->colors(['warning' => 'belum bayar','success' => 'sudah bayar'])
                    ->sortable(),

                BadgeColumn::make('status')->label('Status')
                    ->formatStateUsing(fn(string $state): string => match($state) {
                        'pending'  => 'Pending',
                        'approved' => 'Disetujui',
                        'rejected' => 'Ditolak',
                        default    => ucfirst($state),
                    })
                    ->colors(['warning' => 'pending','success' => 'approved','danger' => 'rejected'])
                    ->sortable(),

                TextColumn::make('created_at')->label('Dibuat')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('updated_at')->label('Diupdate')->dateTime('d M Y H:i')->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')->label('Status')
                    ->options(['pending' => 'Pending','approved' => 'Disetujui','rejected' => 'Ditolak']),
            ])
            ->headerActions([
                Action::make('export')->label('Export Data Order')
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
                            Select::make('payment_method')->label('Metode Pembayaran')
                                ->options(['cash' => 'Cash','tempo' => 'Tempo'])->searchable(),
                            Select::make('status')->label('Status')
                                ->options(['pending' => 'Pending','approved' => 'Approved','rejected' => 'Rejected'])->searchable(),
                            Select::make('status_pembayaran')->label('Status Pembayaran')
                                ->options(['belum bayar' => 'Belum Bayar','sudah bayar' => 'Sudah Bayar'])->searchable(),
                            Select::make('customer_program_id')->label('Program Pelanggan')
                                ->options(CustomerProgram::pluck('name', 'id'))->searchable()->preload(),
                            Select::make('brand_id')->label('Brand')->searchable()->options(Brand::pluck('name', 'id')),
                            Select::make('product_id')->label('Produk')->searchable()->options(Product::pluck('name', 'id')),
                            Select::make('category_id')->label('Kategori Produk')->searchable()->options(Category::pluck('name', 'id')),
                            Select::make('has_diskon')->label('Ada Diskon?')->options(['ya' => 'Ya','tidak' => 'Tidak'])->searchable(),
                            Select::make('has_reward_point')->label('Ada Reward Point?')->options(['ya' => 'Ya','tidak' => 'Tidak'])->searchable(),
                            Select::make('has_program_point')->label('Ada Program Point?')->options(['ya' => 'Ya','tidak' => 'Tidak'])->searchable(),
                            Checkbox::make('export_all')->label('Print Semua Data')->reactive(),
                        ])
                    ])
                    ->action(function (array $data) {
                        $export = new FilteredOrdersExport($data);
                        $rows = $export->array();

                        if (count($rows) <= 2) {
                            \Filament\Notifications\Notification::make()
                                ->title('Data Order Tidak Ditemukan')
                                ->body('Tidak ditemukan data Order produk berdasarkan filter yang Anda pilih. Silakan periksa kembali pilihan filter Anda.')
                                ->danger()->send();
                            return null;
                        }

                        return Excel::download($export, 'export_orders.xlsx');
                    })
            ])
            ->actions([
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make(),

                Action::make('downloadInvoice')
                    ->label('Download File PDF')
                    ->icon('heroicon-o-document-arrow-down')
                    ->visible(fn (Order $record) =>
                        filled($record->order_file) && Storage::disk('public')->exists($record->order_file)
                    )
                    ->action(function (Order $record) {
                        abort_unless(
                            filled($record->order_file) && Storage::disk('public')->exists($record->order_file),
                            404
                        );

                        return Storage::disk('public')->download(
                            $record->order_file,
                            "Order-{$record->no_order}.pdf",
                            ['Content-Type' => 'application/pdf']
                        );
                    }),

                Action::make('downloadExcel')
                    ->label('Download File Excel')
                    ->icon('heroicon-o-document-arrow-down')
                    ->visible(fn (Order $record) =>
                        filled($record->order_excel) && Storage::disk('public')->exists($record->order_excel)
                    )
                    ->action(function (Order $record) {
                        abort_unless(
                            filled($record->order_excel) && Storage::disk('public')->exists($record->order_excel),
                            404
                        );

                        return Storage::disk('public')->download(
                            $record->order_excel,
                            "Order-{$record->no_order}.xlsx",
                            ['Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
                        );
                    }),
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
            'index'  => Pages\ListOrders::route('/'),
            'create' => Pages\CreateOrder::route('/create'),
            'edit'   => Pages\EditOrder::route('/{record}/edit'),
        ];
    }

    public static function mutateFormDataBeforeSave(array $data): array
    {
        $data['products'] = collect($data['products'] ?? [])->map(function ($item) {
            $priceRaw    = $item['price'] ?? 0;
            $subtotalRaw = $item['subtotal'] ?? 0;

            $price    = is_string($priceRaw) ? (int) str_replace('.', '', $priceRaw) : (int) $priceRaw;
            $subtotal = is_string($subtotalRaw) ? (int) str_replace('.', '', $subtotalRaw) : (int) $subtotalRaw;

            $item['price']    = $price;
            $item['subtotal'] = $subtotal;

            return $item;
        })->toArray();

        $data['diskon_1'] = is_string($data['diskon_1'] ?? '') ? floatval(str_replace(',', '.', $data['diskon_1'])) : floatval($data['diskon_1'] ?? 0);
        $data['diskon_2'] = is_string($data['diskon_2'] ?? '') ? floatval(str_replace(',', '.', $data['diskon_2'])) : floatval($data['diskon_2'] ?? 0);

        if (!empty($data['customer_program_id']) && $data['customer_program_id'] !== 'Tidak Ikut Program') {
            $program = CustomerProgram::where('name', $data['customer_program_id'])->first();
            $data['customer_program_id'] = $program?->id ?? null;
        } else {
            $data['customer_program_id'] = null;
        }

        return $data;
    }
}
