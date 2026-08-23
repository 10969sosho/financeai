<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_creates_user_and_returns_token(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Budi',
            'email' => 'budi@mail.com',
            'password' => 'rahasia123',
            'password_confirmation' => 'rahasia123',
        ]);

        $response->assertCreated()
            ->assertJsonStructure([
                'user' => ['id', 'name', 'email'],
                'token',
            ])
            ->assertJsonPath('user.name', 'Budi')
            ->assertJsonPath('user.email', 'budi@mail.com');

        $this->assertDatabaseHas('users', ['email' => 'budi@mail.com']);
    }

    public function test_register_rejects_duplicate_email_and_password_mismatch(): void
    {
        User::factory()->create(['email' => 'budi@mail.com']);

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Budi',
            'email' => 'budi@mail.com',
            'password' => 'rahasia123',
            'password_confirmation' => 'rahasia123',
        ])->assertUnprocessable()->assertJsonValidationErrors(['email']);

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Budi',
            'email' => 'other@mail.com',
            'password' => 'rahasia123',
            'password_confirmation' => 'beda12345',
        ])->assertUnprocessable()->assertJsonValidationErrors(['password']);
    }

    public function test_login_returns_token_for_valid_credentials(): void
    {
        $user = User::factory()->create([
            'email' => 'budi@mail.com',
            'password' => 'rahasia123',
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'budi@mail.com',
            'password' => 'rahasia123',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['user' => ['id', 'name', 'email'], 'token'])
            ->assertJsonPath('user.id', $user->id);
    }

    public function test_login_with_invalid_credentials_fails(): void
    {
        User::factory()->create([
            'email' => 'budi@mail.com',
            'password' => 'rahasia123',
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'budi@mail.com',
            'password' => 'salah-total',
        ])->assertUnprocessable()->assertJsonValidationErrors(['email']);
    }

    public function test_me_requires_authentication(): void
    {
        $this->getJson('/api/v1/me')
            ->assertUnauthorized()
            ->assertJson(['message' => 'Unauthenticated.']);
    }

    public function test_me_returns_authenticated_user_profile(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('user.email', $user->email)
            ->assertJsonMissing(['password']);
    }

    public function test_logout_revokes_current_token(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        $this->withToken($token)
            ->postJson('/api/v1/auth/logout')
            ->assertOk()
            ->assertJson(['message' => 'Logged out.']);

        // Guard di-cache antar-request dalam satu proses test; reset agar
        // request berikutnya melakukan lookup token ulang.
        $this->app->make('auth')->forgetGuards();

        // Token sudah di-revoke → request berikutnya 401 (IS-4).
        $this->withToken($token)
            ->getJson('/api/v1/me')
            ->assertUnauthorized();
    }
}
