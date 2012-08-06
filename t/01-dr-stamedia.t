#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib);

use Test::More tests    => 15;
use Encode qw(decode encode);


BEGIN {
    # Подготовка объекта тестирования для работы с utf8
    my $builder = Test::More->builder;
    binmode $builder->output,         ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output,    ":utf8";

    use_ok 'DR::StraMedia::SMS',
        'build_request', 'parse_response',
        'build_status_request', 'parse_status_response';
}

my ($login, $password, $phone, $text) = @ARGV;

my ($url, $xml) = build_request
    username    => $login || 'abc',
    password    => $password || 'cde',
    to          => $phone || '123-456-45-67',
    from        => 'test',
    text        => $text || 'test',
#     coding     => 'raw'
;

ok $url, 'url';
ok $xml, 'xml';

SKIP: {
    skip "Login and password wasn't defined", 12 unless $login and $password;

    require_ok 'LWP::UserAgent';
    require_ok 'HTTP::Request';
    require_ok 'HTTP::Headers';
    my $ua = LWP::UserAgent->new;


    my $request = HTTP::Request->new(
        POST => $url, HTTP::Headers->new({}), $xml
    );

    my $res = $ua->request($request);

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
};
