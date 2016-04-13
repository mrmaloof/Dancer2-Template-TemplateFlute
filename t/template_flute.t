use strict;
use warnings;
use Dancer2::Core::Hook;
use Plack::Test;
use HTTP::Request::Common;
use HTTP::Cookies;
use Dancer2::Template::TemplateFlute;

use File::Spec;
use File::Basename 'dirname';

use Test::More tests => 6;

my $views = File::Spec->rel2abs(
    File::Spec->catfile( dirname(__FILE__), 'views' ) );

my $flute = Dancer2::Template::TemplateFlute->new(
    views  => $views,
    layout => 'main',
);

{

    package Bar;
    use Dancer2;
    use Dancer2::Plugin::Form;

    # set template engine for first app
    Dancer2->runner->apps->[0]->set_template_engine($flute);
    set session => 'Simple';

    get '/' => sub { template index => { var => 42 } };
    get '/select' => sub {
        template select => {
            colors => [
                { label => 'Red',   value => '#FF000' },
                { label => 'Green', value => '#00FF00' },
                { label => 'Blue',  value => '#0000FF' },
            ]
        };
    };
    my $products = [
        { sku => 1001, title => q{Joseph Phelps Insignia 1997} },
        {   sku   => 1002,
            title => q{Limerick Lane Russian River Valley Zinfandel 2012}
        },
        {   sku   => 1003,
            title => q{M. Chapoutier Bila Haut Occultum Lapidem 2013}
        },
    ];
    get '/mini_products' => sub {
        template
            mini_products => {
            products           => $products,
            specification_file => 'products.xml'
            },
            { layout => undef };
    };
    get '/products' => sub {
        template products => { products => $products };
    };
    any [qw/get post/] => '/register' => sub {
        my $form = form('registration');
        my %values = %{$form->values};
        # VALIDATE, filter, etc. the values
        $form->fill(\%values);
        template register => {form => $form };
    };
}

my $app = Bar->to_app;

test_psgi $app, sub {
    my $cb = shift;

    my $jar  = HTTP::Cookies->new();

    my $req = GET 'http://localhost:3000/register';
    my $res = $cb->($req);
    $jar->extract_cookies($res);

    $req = POST 'http://localhost:3000/register', ['email' => 'evan@bottlenose-wine.com'];
    $jar->add_cookie_header($req);
    $cb->($req);

    $req = GET 'http://localhost:3000/register';
    $jar->add_cookie_header($req);

    my $content = $cb->($req)->content;
    ok($content =~ /evan\@bottlenose-wine.com/, 'Form refilled.');

    ok( $cb->( GET '/mini_products' )->content
            =~ /Limerick Lane Russian River Valley Zinfandel 2012/,
        q{[GET /mini_products] list}
    );
    ok( $cb->( GET '/products' )->content
            =~ /Limerick Lane Russian River Valley Zinfandel 2012/,
        q{[GET /products] list}
    );
    ok( $cb->( GET '/select' )->content
            =~ m{<option value="#FF000">Red</option><option value="#00FF00">Green</option><option value="#0000FF">Blue</option>},
        q{[GET /select] Content with iterator}
    );
};

{

    package Foo;

    use Dancer2;
    set views => '/this/is/our/path';

    get '/default_views'          => sub { set 'views' };
    get '/set_views_via_settings' => sub { set views => '/other/path' };
    get '/get_views_via_settings' => sub { set 'views' };
}

$app = Foo->to_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    is( $cb->( GET '/default_views' )->content,
        '/this/is/our/path',
        '[GET /default_views] Correct content',
    );

    # trigger a test via a route
    $cb->( GET '/set_views_via_settings' );

    is( $cb->( GET '/get_views_via_settings' )->content,
        '/other/path', '[GET /get_views_via_settings] Correct content',
    );
};

done_testing;
