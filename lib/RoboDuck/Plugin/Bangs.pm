package RoboDuck::Plugin::Bangs;
use 5.10.0;
use Moses::Plugin;
use URI::Escape;

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;

    given ($$message) {
        when (/^!(\w+)\s+(.*)/) {
            my $query = uri_escape("$1 $2");
            $query =~ s/%20/+/g;
            $self->privmsg( $_ => "$nick: https://duckduckgo.com/?q=!$query" ) for @$$channels;
            return PCI_EAT_ALL;
        }
    }
    return PCI_EAT_NONE;
}

1;
__END__
