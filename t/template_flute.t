use strict;
use warnings;
use Test::More;
use Dancer2::Core::Hook;
use Plack::Test;
use HTTP::Request::Common;

use File::Spec;
use File::Basename 'dirname';

plan tests => 8;

eval { require Template::Flute; Template::Flute->import(); 1 }
    or plan skip_all => 'Template::Flute probably missing.';

use_ok('Dancer2::Template::TemplateFlute');

my $views = File::Spec->rel2abs(
    File::Spec->catfile( dirname(__FILE__), 'views' ) );

my $flute = Dancer2::Template::TemplateFlute->new(
    views  => $views,
    layout => 'main',
);

isa_ok $flute, 'Dancer2::Template::TemplateFlute';
ok $flute->does('Dancer2::Core::Role::Template');

$flute->add_hook(
    Dancer2::Core::Hook->new(
        name => 'engine.template.before_render',
        code => sub {
            my $tokens = shift;
            $tokens->{before_template_render} = 1;
        },
    )
);

$flute->add_hook(
    Dancer2::Core::Hook->new(
        name => 'engine.template.before_layout_render',
        code => sub {
            my $tokens  = shift;
            my $content = shift;

            $tokens->{before_layout_render} = 1;
            $$content .= qq{\ncontent added in before_layout_render};
        },
    )
);

$flute->add_hook(
    Dancer2::Core::Hook->new(
        name => 'engine.template.after_layout_render',
        code => sub {
            my $content = shift;
            $$content .= qq{\ncontent added in after_layout_render\n};
        },
    )
);

$flute->add_hook(
    Dancer2::Core::Hook->new(
        name => 'engine.template.after_render',
        code => sub {
            my $content = shift;
            $$content .= qq{\ncontent added in after_template_render};
        },
    )
);

{

    package Bar;
    use Dancer2;

    # set template engine for first app
    Dancer2->runner->apps->[0]->set_template_engine($flute);

    get '/' => sub { template index => { var => 42 } };
    get '/color' => sub {
        template color => {
            colors => [
                { label => 'Red',   value => '#FF000' },
                { label => 'Green', value => '#00FF00' },
                { label => 'Blue',  value => '#0000FF' },
            ]
        };
    };
}

my $app    = Bar->to_app;
my $space  = ' ';
my $result = <<"EOR";
<html><head><title>
            Dancer2::Template::TemaplateFlute test
        </title></head><body>
        layout top
        var = <div class="var">42</div>
        before_layout_render = <div class="before_layout_render">1</div>
        ---
        <div id="content">[index]
var = <div class="var">42</div>

before_layout_render = <div class="before_layout_render"></div>
before_template_render = <div class="before_template_render">1</div>
content added in after_template_render
content added in before_layout_render</div>
        ---
        layout bottom
    </body></html>
content added in after_layout_render
EOR

test_psgi $app, sub {
    my $cb = shift;
    ok( $cb->( GET '/color' )->content
            =~ m{<option value="#FF000">Red</option><option value="#00FF00">Green</option><option value="#0000FF">Blue</option>},
        q{[GET /color] Content with iterator}
    );
    is( $cb->( GET '/' )->content,
        $result, '[GET /] Correct content with template hooks',
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
