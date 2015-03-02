# ABSTRACT: Template flute engine for Dancer2

package Dancer2::Template::TemplateFlute;

use Moo;
use Carp qw/croak/;
use Dancer2::Core::Types;
use Template::Flute;

with 'Dancer2::Core::Role::Template';

sub default_tmpl_ext {'html'}

sub render {
    my ( $self, $template, $tokens ) = @_;

    ( ref $template || -f $template )
        or croak "$template is not a regular file or reference";

    my $content = '';

    my $args = {
        template_file  => $template,
        scopes         => 1,
        auto_iterators => 1,
        values         => $tokens,
        filters        => $self->config->{filters},
    };
    $args->{specification_file}
        = Template::Flute::Utils::derive_filename( $template, '.xml' );
    $args->{specification} = q{<specification></specification>}
        unless -f $args->{specification_file};
    my $flute = Template::Flute->new(%$args);
    $content = $flute->process()
        or croak $flute->error;
    return $content;
}

1;

__END__

=head1 SYNOPSIS

To use this engine, you may configure L<Dancer2> via C<config.yaml>:

    template:   "template_flute"

Or you may also change the rendering engine on a per-route basis by
setting it manually with C<set>:

    # code code code
    set template => 'template_flute';

=head1 DESCRIPTION

This template engine allows you to use L<Template::Flute> in L<Dancer2>.

=method render($template, \%tokens)

Renders the template.  The first arg is a filename for the template file
or a reference to a string that contains the template.  The second arg
is a hashref for the tokens that you wish to pass to
L<Template::Toolkit> for rendering.

=head1 SEE ALSO

L<Dancer2>, L<Dancer2::Core::Role::Template>, L<Template::Flute>.
