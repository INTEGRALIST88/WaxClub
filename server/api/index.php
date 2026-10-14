<?php
// API do WaxClub (https://api.waxclub.com.br) — roteador. Todas as respostas são JSON.
declare(strict_types=1);

require __DIR__ . '/lib/bootstrap.php';
require __DIR__ . '/lib/mail.php';
require __DIR__ . '/lib/geo.php';
require __DIR__ . '/lib/auth.php';
require __DIR__ . '/lib/collection.php';

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$path = preg_replace('#^/api(?=/|$)#', '', $path); // também responde em waxclub.com.br/api/
$path = rtrim($path, '/') ?: '/';

$routes = [
    ['GET', '#^/(v1(/health)?)?$#', function (): void {
        json_out(200, ['ok' => true, 'service' => 'waxclub-api', 'version' => API_VERSION, 'schema' => schema_version()]);
    }],
    ['POST', '#^/v1/auth/register$#', 'auth_register'],
    ['POST', '#^/v1/auth/verify-email$#', 'auth_verify_email'],
    ['POST', '#^/v1/auth/verify-email/resend$#', 'auth_verify_resend'],
    ['POST', '#^/v1/auth/login$#', 'auth_login'],
    ['POST', '#^/v1/auth/password/forgot$#', 'auth_password_forgot'],
    ['POST', '#^/v1/auth/password/reset$#', 'auth_password_reset'],
    ['GET', '#^/v1/auth/username-available$#', 'auth_username_available'],
    ['GET', '#^/v1/geo/countries$#', 'geo_countries'],
    ['GET', '#^/v1/geo/states$#', 'geo_states'],
    ['GET', '#^/v1/geo/cities$#', 'geo_cities'],
    ['POST', '#^/v1/auth/email/start$#', 'auth_email_start'],
    ['POST', '#^/v1/auth/email/verify$#', 'auth_email_verify'],
    ['POST', '#^/v1/auth/google$#', 'auth_google'],
    ['POST', '#^/v1/auth/logout$#', 'auth_logout'],
    ['GET', '#^/v1/me$#', 'me_get'],
    ['PATCH', '#^/v1/me$#', 'me_patch'],
    ['DELETE', '#^/v1/me$#', 'me_delete'],
    ['GET', '#^/v1/collection$#', 'collection_list'],
    ['POST', '#^/v1/collection/sync$#', 'collection_sync'],
    ['PUT', '#^/v1/collection/(.+)$#', 'collection_put'],
    ['DELETE', '#^/v1/collection/(.+)$#', 'collection_delete'],
    ['GET', '#^/v1/plays$#', 'plays_list'],
    ['POST', '#^/v1/plays$#', 'plays_add'],
];

$pathMatched = false;
foreach ($routes as [$verb, $pattern, $handler]) {
    if (!preg_match($pattern, $path, $m)) {
        continue;
    }
    $pathMatched = true;
    if ($verb !== $method) {
        continue;
    }
    $args = array_map('rawurldecode', array_slice($m, 1));
    // a rota de saúde captura grupos opcionais que não são argumentos
    $handler(...($handler instanceof Closure ? [] : $args));
    exit;
}
fail($pathMatched ? 405 : 404, $pathMatched ? 'method_not_allowed' : 'not_found');
