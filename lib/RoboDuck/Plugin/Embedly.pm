package RoboDuck::Plugin::Embedly;
use 5.10.1;
use Moses::Plugin;
use WebService::Embedly;
use Moose::Util::TypeConstraints;
use Regexp::Common 'URI';

class_type 'WebService::Embedly';
has embedly => (
    isa     => 'WebService::Embedly|Undef',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_embedly',
);

sub _build_embedly {
    defined $ENV{ROBODUCK_EMBEDLY_KEY} ? WebService::Embedly->new( api_key => $ENV{ROBODUCK_EMBEDLY_KEY}, maxwidth => 300 ) : undef;
}

sub get_description {
    my $self = shift;
    my $url = shift;

    my $oembed_ref = $self->embedly->oembed( $url );
    if (defined $$oembed_ref{description}) {
        my $title = ($$oembed_ref{description} =~ /$$oembed_ref{title}/) ? $$oembed_ref{description} : $$oembed_ref{title}." - ".$$oembed_ref{description};
        $title = ($$oembed_ref{title} =~ /$$oembed_ref{description}/) ? $$oembed_ref{title} :  $title;
        return $$oembed_ref{provider_name}." - ".$title;
    }
    return $$oembed_ref{title};
}

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;

    given ($$message) {
        when (/($RE{URI}{HTTP}{ -scheme => qr\/https?\/ })/) {
        my $desc = $self->get_description($1);

#           unless ($desc) { # get the title of normal pages
#              $self->title->get_title({ page => $1, event => 'announce_page_title' });
#              return;
#          }

        $self->privmsg( $_ => "> $desc" ) for @$$channels;
        }
    }
}

1;
__END__
