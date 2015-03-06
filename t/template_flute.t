use strict;
use warnings;
use Dancer2::Core::Hook;
use Plack::Test;
use HTTP::Request::Common;
use Dancer2::Template::TemplateFlute;

use File::Spec;
use File::Basename 'dirname';

use Test::More tests => 5;

my $views = File::Spec->rel2abs(
    File::Spec->catfile( dirname(__FILE__), 'views' ) );

my $flute = Dancer2::Template::TemplateFlute->new(
    views  => $views,
    layout => 'main',
);

{

    package Bar;
    use Dancer2;

    # set template engine for first app
    Dancer2->runner->apps->[0]->set_template_engine($flute);

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
}

my $app    = Bar->to_app;

test_psgi $app, sub {
    my $cb = shift;
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
