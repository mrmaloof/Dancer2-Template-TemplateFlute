use strict;
use warnings;
use Test::More;
use Dancer2::Core::Hook;
use Plack::Test;
use HTTP::Request::Common;
use Dancer2::Template::TemplateFlute;

use File::Spec;
use File::Basename 'dirname';

my $test_count = 1;
plan tests => $test_count;

my $views = File::Spec->rel2abs(
    File::Spec->catfile( dirname(__FILE__), 'views' ) );

my $flute = Dancer2::Template::TemplateFlute->new(
    views  => $views,
    layout => 'main',
);

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

    is( $cb->( GET '/' )->content,
        $result, '[GET /] Correct content with template hooks',
    );
};

done_testing($test_count);
