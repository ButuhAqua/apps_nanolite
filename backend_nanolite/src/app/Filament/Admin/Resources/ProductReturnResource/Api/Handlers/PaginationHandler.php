<?php

namespace App\Filament\Admin\Resources\ProductReturnResource\Api\Handlers;

use App\Filament\Admin\Resources\ProductReturnResource;
use App\Filament\Admin\Resources\ProductReturnResource\Api\Requests\CreateProductReturnRequest;
use App\Filament\Admin\Resources\ProductReturnResource\Api\Transformers\ProductReturnTransformer;
use App\Models\ProductReturn;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Rupadana\ApiService\Http\Handlers;
use Spatie\QueryBuilder\QueryBuilder;

class PaginationHandler extends Handlers
{
    use \App\Support\ApiPaging;

    public static ?string $uri = '/';
    public static ?string $resource = ProductReturnResource::class;

    public function handler()
    {
        /* ====== Tambahkan blok ini untuk CREATE (POST /product-returns) ====== */
        if (request()->isMethod('post')) {
            // validasi pakai rules yang sama dengan FormRequest
            $rules = (new CreateProductReturnRequest)->rules();
            $data  = Validator::make(request()->all(), $rules)->validate();

            // --- normalisasi address dari [*_code] menjadi struktur yang disimpan
            // address akan berbentuk array index 0..n
            $addrIn  = (array)($data['address'] ?? []);
            $addrOut = [];
            foreach ($addrIn as $a) {
                $addrOut[] = [
                    'detail_alamat' => $a['detail_alamat'] ?? ($a['detail'] ?? null),
                    'provinsi'      => $a['provinsi']      ?? $a['provinsi_code']  ?? null,
                    'kota_kab'      => $a['kota_kab']      ?? $a['kota_kab_code']  ?? null,
                    'kecamatan'     => $a['kecamatan']     ?? $a['kecamatan_code'] ?? null,
                    'kelurahan'     => $a['kelurahan']     ?? $a['kelurahan_code'] ?? null,
                    'kode_pos'      => $a['kode_pos']      ?? null,
                ];
            }
            $data['address'] = $addrOut;

            // --- products: rules meminta JSON; decode ke array utk penyimpanan
            if (is_string($data['products'] ?? null)) {
                $data['products'] = json_decode($data['products'], true) ?: [];
            }

            // --- upload image (kolom di DB bertipe string -> simpan satu file saja)
            if (request()->hasFile('image')) {
                $file = request()->file('image');
                // handle jika user kirim array 'image[]'
                if (is_array($file)) $file = $file[0];
                $data['image'] = $file->store('return', 'public');
            }

            $row = ProductReturn::create($data);

            return static::sendSuccessResponse(
                new ProductReturnTransformer($row),
                'Product return created.',
                201
            );
        }
        /* ====== END blok POST ====== */

        // ------ GET list (tetap seperti semula) ------
        switch (request('type')) {
            case 'status':
                return static::getModel()::select('status')->distinct()->orderBy('status')->get();
            case 'customers':
                return \App\Models\Customer::select('id','name')->orderBy('name')->get();
            case 'employees':
                return \App\Models\Employee::select('id','name')
                    ->when(request('department_id'), fn($q) => $q->where('department_id', request('department_id')))
                    ->orderBy('name')->get();
            case 'departments':
                return \App\Models\Department::select('id','name')->orderBy('name')->get();
            case 'categories':
                return \App\Models\CustomerCategory::select('id','name')->orderBy('name')->get();
        }

        $paginator = QueryBuilder::for(static::getModel())
            ->allowedFilters(['no_return','status','customer_id','employee_id','department_id','customer_categories_id'])
            ->with(['department:id,name','employee:id,name','customer:id,name','category:id,name'])
            ->latest('id')
            ->paginate($this->perPage(request()))
            ->appends(request()->query())
            ->through(fn ($row) => new ProductReturnTransformer($row));

        return static::sendSuccessResponse($paginator, 'Product return list retrieved successfully');
    }
}