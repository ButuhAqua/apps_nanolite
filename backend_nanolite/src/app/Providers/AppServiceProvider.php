<?php

namespace App\Providers;

use App\Models\User;
use App\Policies\ActivityPolicy;
use Filament\Actions\MountableAction;
use Filament\Notifications\Livewire\Notifications;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Support\Enums\Alignment;
use Filament\Support\Enums\VerticalAlignment;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\ValidationException;
use Spatie\Activitylog\Models\Activity;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // --- Yang sudah ada ---
        Gate::policy(Activity::class, ActivityPolicy::class);
        Page::formActionsAlignment(Alignment::Right);
        Notifications::alignment(Alignment::End);
        Notifications::verticalAlignment(VerticalAlignment::End);
        Page::$reportValidationErrorUsing = function (ValidationException $exception) {
            Notification::make()
                ->title($exception->getMessage())
                ->danger()
                ->send();
        };
        MountableAction::configureUsing(function (MountableAction $action) {
            $action->modalFooterActionsAlignment(Alignment::Right);
        });

        // --- Tambahan: sembunyikan activity milik admin dari non-admin ---
        Activity::addGlobalScope('hide-admin-activity-for-non-admin', function (Builder $query) {
            $user = auth()->user();
            if (! $user) {
                return;
            }

            // GANTI sesuai nama role admin yang dipakai di aplikasi Anda
            $adminRoleNames = ['Admin', 'admin', 'super_admin', 'Super Admin'];

            // Jika user saat ini admin, biarkan melihat semua
            if (method_exists($user, 'hasAnyRole') && $user->hasAnyRole($adminRoleNames)) {
                return;
            }

            // Ambil semua user id yang punya salah satu role admin
            $adminIds = User::query()
                ->when(method_exists(User::class, 'roles'), function ($q) use ($adminRoleNames) {
                    // spatie/permission relation 'roles'
                    $q->whereHas('roles', fn ($qq) => $qq->whereIn('name', $adminRoleNames));
                }, function ($q) {
                    // Jika model User tidak punya relasi roles, jangan filter apa-apa (hindari error).
                    // Kembalikan kosong agar clause di bawah tidak memfilter apa pun.
                    $q->whereRaw('1 = 0');
                })
                ->pluck('id');

            if ($adminIds->isEmpty()) {
                return;
            }

            // Dapatkan morph class untuk kolom causer_type (aman bila ada morphMap)
            $userMorph = (new User)->getMorphClass();

            // Tampilkan hanya activity yang BUKAN dibuat oleh user admin
            $query->where(function (Builder $q) use ($adminIds, $userMorph) {
                $q->whereNull('causer_type')                          // tidak ada pelaku
                  ->orWhere('causer_type', '!=', $userMorph)          // pelaku bukan model User
                  ->orWhere(function (Builder $qq) use ($adminIds, $userMorph) { // pelaku User tapi bukan admin
                      $qq->where('causer_type', $userMorph)
                         ->whereNotIn('causer_id', $adminIds);
                  });
            });
        });
    }
}
