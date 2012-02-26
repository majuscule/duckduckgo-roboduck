package RoboDuck::Plugin::Goodies;
use 5.10.0;
use Moses::Plugin;

sub S_bot_addressed {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;

    given ($$message) {
        when (/^\W*$/i) {
            $reply = "I'm here, version ".$RoboDuck::VERSION;
        }
        when (/^.*your\s+(order|rule)/) {
            $reply = "$nick: 1. Serve the public trust, 2. Protect the innocent, 3. Uphold the law, 4. .... and dont track you! http://donttrack.us/";
        }
        when (/^(you are|are you)\s+(?!not)\w*\s?(awesome|great|wonderful|perfect|amazing|($mynick))/i) {
            $reply = "Yes. Yes I am.";
        }
        when (/^$mynick\W*$/i) {
            $reply = "That's me! My source: http://github.com/Getty/duckduckgo-roboduck";
        }
        default {
            return PCI_EAT_NONE;
        }
    }
    if ($reply) { 
        $self->privmsg( $_ => $reply ) for @$$channels;
        return PCI_EAT_ALL;
    }
}

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;

    given ($$message) {
        when (/(^|\W)(cows?|moo)($|\W)/i) {
            $reply = "MOOOOooo! http://www.youtube.com/watch?v=FavUpD_IjVY";
        }
        when (/(^|\W)(meow|cats?|kittens?|kitty|kitties)($|\W)/i) {
            $reply = "MEOW. https://www.youtube.com/watch?v=QNwCojCJ3-Q";
        }
        when (/(\W|^)(bear|cycles?)(\W|$)/) {
            $reply = "http://www.youtube.com/watch?v=-0Xa4bHcJu8";
        }
    }
    if ($reply) { 
        $self->privmsg( $_ => $reply ) for @$$channels;
        return PCI_EAT_ALL;
    }
}

1;
__END__
