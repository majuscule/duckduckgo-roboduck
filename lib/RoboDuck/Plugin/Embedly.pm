package RoboDuck::Plugin::Embedly;
use 5.10.1;
use Moses::Plugin;
use WebService::Embedly;
use Moose::Util::TypeConstraints;
use Regexp::Common 'URI';
use URL::Encode 'url_decode_utf8';

class_type 'WebService::Embedly';
has embedly => (
    isa     => 'WebService::Embedly|Undef',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_embedly',
);

sub _build_embedly {
    defined $ENV{ROBODUCK_EMBEDLY_KEY} ? WebService::Embedly->new( api_key => $ENV{ROBODUCK_EMBEDLY_KEY}, words => 20 ) : undef;
}

sub get_description {
    my ($self, $url, $nick, $channels) = @_;

    if ( $url =~ m{://duckduckgo\.com/.+q=(.+?)(?:&|$)} ) {
        use DDP;
        my $decoded_q = url_decode_utf8($1);
        my $ret = $self->{bot}{heap}{_irc}->plugin_get('DuckDuckGo')->S_bot_addressed($self->{bot}{heap}{_irc}, $nick, $channels, \$decoded_q, internal => 1);
        return $ret unless $ret eq 1;
        return $decoded_q . " at DuckDuckGo";
    }

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
        my $desc = $self->get_description($1, $nickstring, $channels);

#           unless ($desc) { # get the title of normal pages
#              $self->title->get_title({ page => $1, event => 'announce_page_title' });
#              return;
#          }
        return PCI_EAT_NONE unless $desc;
        $self->privmsg( $_ => "> $desc" ) for @$$channels;
        }
    }
}

1;
__END__
