<?php
// Envio de e-mail: SMTP autenticado da Hostinger (assinado com DKIM, fora do spam) com envio local de reserva.
declare(strict_types=1);

function send_mail(string $to, string $subject, string $text): bool
{
    $from = cfg('MAIL_FROM', 'waxclub@waxclub.com.br');
    $headers = [
        'Date: ' . date(DATE_RFC2822),
        'Message-ID: <' . bin2hex(random_bytes(16)) . '@waxclub.com.br>',
        'From: WaxClub <' . $from . '>',
        'Reply-To: ' . $from,
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: 8bit',
    ];
    if (cfg('SMTP_PASS') !== '' && smtp_send($from, $to, $subject, $text, $headers)) {
        $GLOBALS['mail_delivery'] = 'smtp';
        return true;
    }
    // sem SMTP (ou SMTP recusado): envio local do servidor, que pode cair no spam
    $GLOBALS['mail_delivery'] = isset($GLOBALS['smtp_error']) ? 'fallback (' . $GLOBALS['smtp_error'] . ')' : 'mail';
    return mail($to, $subject, $text, implode("\r\n", $headers), '-f' . $from);
}

/** Cliente SMTP mínimo (SSL implícito na porta 465, AUTH LOGIN). */
function smtp_send(string $from, string $to, string $subject, string $text, array $headers): bool
{
    $host = cfg('SMTP_HOST', 'smtp.hostinger.com');
    $port = (int) cfg('SMTP_PORT', '465');
    $user = cfg('SMTP_USER', $from);
    $sock = @stream_socket_client("ssl://$host:$port", $errno, $errstr, 15);
    if (!$sock) {
        error_log("[waxclub-api] smtp connect: $errstr");
        $GLOBALS['smtp_error'] = "connect $errno";
        return false;
    }
    stream_set_timeout($sock, 15);
    $read = function () use ($sock): string {
        $resp = '';
        while (($line = fgets($sock, 1024)) !== false) {
            $resp .= $line;
            if (strlen($line) < 4 || $line[3] === ' ') {
                break;
            }
        }
        return $resp;
    };
    $cmd = function (string $line, string $expect, string $stage) use ($sock, $read): bool {
        if ($line !== '') {
            fwrite($sock, $line . "\r\n");
        }
        $resp = $read();
        if (strncmp($resp, $expect, 3) !== 0) {
            error_log('[waxclub-api] smtp: ' . trim($resp));
            $GLOBALS['smtp_error'] = $stage . ' ' . (substr($resp, 0, 3) ?: 'timeout');
            return false;
        }
        return true;
    };
    $body = preg_replace('/^\./m', '..', str_replace(["\r\n", "\n"], ["\n", "\r\n"], $text));
    $subjectHeader = 'Subject: =?UTF-8?B?' . base64_encode($subject) . '?=';
    $data = implode("\r\n", array_merge($headers, ['To: <' . $to . '>', $subjectHeader])) . "\r\n\r\n" . $body . "\r\n.";
    $ok = $cmd('', '220', 'greeting')
        && $cmd('EHLO api.waxclub.com.br', '250', 'ehlo')
        && $cmd('AUTH LOGIN', '334', 'auth')
        && $cmd(base64_encode($user), '334', 'auth-user')
        && $cmd(base64_encode(cfg('SMTP_PASS')), '235', 'auth-pass')
        && $cmd('MAIL FROM:<' . $from . '>', '250', 'mail-from')
        && $cmd('RCPT TO:<' . $to . '>', '250', 'rcpt-to')
        && $cmd('DATA', '354', 'data')
        && $cmd($data, '250', 'send');
    fwrite($sock, "QUIT\r\n");
    fclose($sock);
    return $ok;
}
