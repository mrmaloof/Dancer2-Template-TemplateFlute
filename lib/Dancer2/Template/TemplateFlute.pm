# ABSTRACT: Template flute engine for Dancer2

package Dancer2::Template::TemplateFlute;

use Moo;
use Carp qw/croak/;
use Dancer2::Core::Types;
use Template::Flute;
use Template::Flute::Utils;
use Scalar::Util qw/blessed/;

with 'Dancer2::Core::Role::Template';

use version; our $VERSION = version->new('v0.0.1');

sub default_tmpl_ext {'html'}

sub render {
    my ( $self, $template, $tokens ) = @_;
    use Data::Dumper;
    #print Dumper $tokens->{form}->fields;

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
        = $tokens->{settings}->{views} . '/' . $tokens->{specification_file}
        if $tokens->{specification_file};
    $args->{specification_file}
        ||= Template::Flute::Utils::derive_filename( $template, '.xml' );
    $args->{specification} = q{<specification></specification>}
        unless -f $args->{specification_file};
    my $flute = Template::Flute->new(%$args);
    
    $flute->process_template();
    
	# check for forms
    if (my @forms = $flute->template->forms) {
        if ($tokens->{form}) {
            $self->_tf_manage_forms($flute, $tokens, @forms);
        } else {
            croak 'Missing form parameters for forms ' . join(", ", sort map { $_->name } @forms);
        }
    }
    
    $content = $flute->process()
        or croak $flute->error;
    return $content;
}

sub _tf_manage_forms {
    my ($self, $flute, $tokens, @forms) = @_;

    # simple case: only one form passed and one in the flute
    if (ref($tokens->{form}) ne 'ARRAY') {
        my $form_name = $tokens->{form}->name;
        if (@forms == 1) {
            my $form = shift @forms;
            if ( $form_name eq 'main' or $form_name eq $form->name ) {
                $self->_tf_fill_forms($flute, $tokens->{form}, $form, $tokens);
            }
        } else {
            my $found = 0;
            foreach my $form (@forms) {
                if ($form_name eq $form->name) {
                    $self->_tf_fill_forms($flute, $tokens->{form}, $form, $tokens);
                    $found++;
                }
            }
            if ($found != 1) {
                croak ("Multiple form are not being managed correctly, found $found corresponding forms, but we expected just one!")
            }
        }
    } else {
        foreach my $passed_form (@{$tokens->{form}}) {
            foreach my $form (@forms) {
                if ($passed_form->name eq $form->name) {
                    $self->_tf_fill_forms($flute, $passed_form, $form, $tokens);
                }
            }
        }
    }
}

sub _tf_fill_forms {
    my ($self, $flute, $passed_form, $form, $tokens) = @_;
    my ($iter, $action);
    for my $name ($form->iterators) {
        if (ref($tokens->{$name}) eq 'ARRAY') {
            $iter = Template::Flute::Iterator->new($tokens->{$name});
            $flute->specification->set_iterator($name, $iter);
        }
    }
    if ($action = $passed_form->action()) {
        $form->set_action($action);
    }
    $passed_form->fields([map {$_->{name}} @{$form->fields()}]);
    $form->fill($passed_form->fill());

    if ($self->settings->{session}) {
        $passed_form->to_session;
    }
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
