<?php
// First-boot setup for LinkStack on Railway, run as the apache user before
// Apache starts. It replaces the web installer: the installer is open to the
// first visitor (including a /skip route that logs in as a seeded admin), so
// it must never be reachable on a public URL.
//
// Every boot: make sure the app key exists and run database migrations.
// First boot only (the INSTALLING marker exists): create the admin account
// from LINKSTACK_ADMIN_EMAIL / LINKSTACK_ADMIN_PASSWORD, switch to production
// mode, and remove the installer markers.

declare(strict_types=1);

use App\Models\User;
use GeoSot\EnvEditor\Facades\EnvEditor;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\Hash;

const ROOT = '/htdocs';

function fail(string $msg): void
{
    fwrite(STDERR, "railway-bootstrap: $msg\n");
    exit(1);
}

function setKey(string $key, string $value): void
{
    if (EnvEditor::keyExists($key)) {
        EnvEditor::editKey($key, $value);
    } else {
        EnvEditor::addKey($key, $value);
    }
}

chdir(ROOT);
require ROOT . '/vendor/autoload.php';
$app = require ROOT . '/bootstrap/app.php';
$kernel = $app->make(Kernel::class);
$kernel->bootstrap();

if ((string) EnvEditor::getKey('APP_KEY') === '') {
    setKey('APP_KEY', 'base64:' . base64_encode(random_bytes(32)));
    echo "railway-bootstrap: generated APP_KEY\n";
}

if ($kernel->call('migrate', ['--force' => true]) !== 0) {
    fail('php artisan migrate failed: ' . trim($kernel->output()));
}

$installing = file_exists(ROOT . '/INSTALLING') || file_exists(ROOT . '/INSTALLERLOCK');
if (!$installing) {
    echo "railway-bootstrap: already set up, migrations current\n";
    exit(0);
}

$email = trim((string) getenv('LINKSTACK_ADMIN_EMAIL'));
$password = (string) getenv('LINKSTACK_ADMIN_PASSWORD');
$handle = trim((string) (getenv('LINKSTACK_ADMIN_HANDLE') ?: 'admin'));

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    fail('LINKSTACK_ADMIN_EMAIL must be set to a valid email address for the first start');
}
if (strlen($password) < 12) {
    fail('LINKSTACK_ADMIN_PASSWORD must be at least 12 characters for the first start');
}
if (!preg_match('/^[A-Za-z0-9_-]{1,50}$/', $handle)) {
    fail('LINKSTACK_ADMIN_HANDLE may only contain letters, numbers, "-" and "_"');
}

if (User::query()->count() === 0) {
    $user = User::create([
        'name' => $handle,
        'email' => $email,
        'password' => Hash::make($password),
        'littlelink_name' => $handle,
        'littlelink_description' => 'admin page',
        'block' => 'no',
    ]);
    $user->forceFill(['role' => 'admin', 'email_verified_at' => now()])->save();
    echo "railway-bootstrap: created admin account $email (page @$handle)\n";
} elseif (!User::query()->where('role', 'admin')->exists()) {
    fail('the database has users but no admin; not touching existing accounts');
}

setKey('ADMIN_EMAIL', $email);
setKey('APP_ENV', 'production');
setKey('APP_DEBUG', 'false');
setKey('ALLOW_REGISTRATION', 'false');

if (!file_exists(ROOT . '/config/advanced-config.php')) {
    copy(ROOT . '/storage/templates/advanced-config.php', ROOT . '/config/advanced-config.php');
}
if (!is_dir(ROOT . '/storage/app')) {
    mkdir(ROOT . '/storage/app', 0755, true);
}
touch(ROOT . '/storage/app/ISINSTALLED');
@unlink(ROOT . '/INSTALLERLOCK');
@unlink(ROOT . '/INSTALLING');

echo "railway-bootstrap: setup complete\n";
