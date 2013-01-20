#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib);

use Test::More tests    => 29;
use Encode qw(decode encode);


BEGIN {
    # Подготовка объекта тестирования для работы с utf8
    my $builder = Test::More->builder;
    binmode $builder->output,         ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output,    ":utf8";

    use_ok 'DR::StraMedia::SMS',
        'build_request', 'parse_response',
        'build_status_request', 'parse_status_response',
        'build_balance_request', 'parse_balance_response';
}

my ($login, $password, $phone, $text) = @ARGV;

my ($url, $xml) = build_request
        username    => $login || 'abc',
        password    => $password || 'cde',
        to          => $phone || '123-456-45-67',
        from        => 'test',
        text        => $text || 'test',
    ;
ok $url, 'url';
ok $xml, 'xml';

($url, $xml) = build_balance_request
        username    => $login || 'abc',
        password    => $password || 'cde',
    ;
ok $url, 'url';
ok $xml, 'xml';

($url, $xml) = build_status_request
        username    => $login || 'abc',
        password    => $password || 'cde',
        id          => 123,
    ;
ok $url, 'url';
ok $xml, 'xml';

SKIP: {
    my $cnt = 22;
    skip "Login and password wasn't defined", $cnt unless $login and $password;

    require_ok 'LWP::UserAgent';
    require_ok 'HTTP::Request';
    require_ok 'HTTP::Headers';
    my $ua = LWP::UserAgent->new;
    my ($request, $res);


    ($url, $xml) = build_balance_request
        username    => $login,
        password    => $password,
    ;
    $request = HTTP::Request->new( POST => $url, HTTP::Headers->new({}), $xml );
    $res = $ua->request($request);
    $res = parse_balance_response $res->content;


    isa_ok $res => 'HASH';
    unless (is $res->{status}, 'ok', 'message was sent') {
        diag explain $res;
        skip "Couldn't get balance", $cnt - 5;

    }
    like $res->{balance}, qr{^-?\d+(\.\d+)?$}, 'balance: ' .
        ($res->{balance} || '');
    like $res->{message}, qr{Success}, 'message';

    ($url, $xml) = build_request
        username    => $login,
        password    => $password,
        to          => $phone || '123-456-45-67',
        from        => 'test',
        text        => $text || 'balance: ' . $res->{balance},
    ;

    $request = HTTP::Request->new( POST => $url, HTTP::Headers->new({}), $xml );
    $res = $ua->request($request);

    $res = parse_response $res->content;

    isa_ok $res => 'HASH';
    is $res->{status}, 'ok', 'message was sent';
    ok $res->{id}, 'id message';

    ($url, $xml) = build_status_request
        username    => $login,
        password    => $password,
        id          => $res->{id}
    ;
    ok $url, 'url';
    ok $xml, 'xml';

    $request = HTTP::Request->new( POST => $url, HTTP::Headers->new({}), $xml );
    $res = $ua->request($request);

    $res = parse_status_response $res->content;
    isa_ok $res => 'HASH';
    is $res->{status}, 'ok', 'message was sent';
    ok $res->{id}, 'id message';
    like $res->{code}, qr{^(0|1|2|4|8|16|32)$}, 'code';
    like $res->{message}, qr{was sent}, 'message';

    ($url, $xml) = build_status_request
        username    => $login,
        password    => $password,
        id          => $res->{id} . 'aaa'
    ;
    ok $url, 'url';
    ok $xml, 'xml';

    $request = HTTP::Request->new( POST => $url, HTTP::Headers->new({}), $xml );
    $res = $ua->request($request);

    $res = parse_status_response $res->content;
    isa_ok $res => 'HASH';
    is $res->{status}, 'error', 'message was sent';
    like $res->{message}, qr{Error}, 'message';
};
