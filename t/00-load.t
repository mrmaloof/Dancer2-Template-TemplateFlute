use strict;
use warnings FATAL => 'all';
use Test::More tests => 4;

use constant { MODULE => 'Dancer2::Template::TemplateFlute' };

BEGIN { use_ok(MODULE); }
can_ok( MODULE, 'new' );

my $flute = MODULE->new;
isa_ok $flute, MODULE;
ok $flute->does('Dancer2::Core::Role::Template');
