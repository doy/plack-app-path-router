#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Path::Router;
use Plack::Test;
use Plack::Middleware::Auth::Basic;

BEGIN {
    use_ok('Plack::App::Path::Router');
}

sub auth_cb {
    my ($username, $password) = @_;
    return $username eq 'admin' && $password eq 's3cr3t';
}

my $router = Path::Router->new;
$router->add_route('/foo'     => target => Plack::Middleware::Auth::Basic->new( authenticator => \&auth_cb, app => sub { 'FOO' } ) );
$router->add_route('/bar'     => target => sub { 'BAR' } );
$router->add_route('/bar/baz' => target => Plack::Middleware::Auth::Basic->new( authenticator => \&auth_cb, app => sub { 'BAR/BAZ' } ) );

my $app = Plack::App::Path::Router->new( router => $router );

test_psgi
      app    => $app,
      client => sub {
          my $cb = shift;
          {
              my $req = HTTP::Request->new(GET => "http://localhost/foo");
              my $res = $cb->($req);
              is($res->code, 401, '... got the expected auth fail');
          }
          {
              my $req = HTTP::Request->new(GET => "http://localhost/bar");
              my $res = $cb->($req);
              is($res->code, 200, '... got the expected auth fail');
              is($res->content, 'BAR', '... got the right value for /bar');
          }
          {
              my $req = HTTP::Request->new(GET => "http://localhost/bar/baz");
              my $res = $cb->($req);
              is($res->code, 401, '... got the expected auth fail');
          }
          {
              my $req = HTTP::Request->new(GET => "http://localhost/foo", [ "Authorization" => "Basic YWRtaW46czNjcjN0" ]);
              my $res = $cb->($req);
              is($res->code, 200, '... got the expected auth fail');
              is($res->content, 'FOO', '... got the right value for /foo');
          }
          {
              my $req = HTTP::Request->new(GET => "http://localhost/bar/baz", [ "Authorization" => "Basic YWRtaW46czNjcjN0" ]);
              my $res = $cb->($req);
              is($res->code, 200, '... got the expected auth fail');
              is($res->content, 'BAR/BAZ', '... got the right value for /bar/baz');
          }
          {
              my $req = HTTP::Request->new(GET => "http://localhost/bar/baz", [ "Authorization" => "Basic fake" ]);
              my $res = $cb->($req);
              is($res->code, 401, '... got the expected auth fail');
          }
      };

done_testing;

