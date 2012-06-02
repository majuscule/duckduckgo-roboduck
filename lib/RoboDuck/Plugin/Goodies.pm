package RoboDuck::Plugin::Goodies;
use 5.10.0;
use Moses::Plugin;

my @gfy = (
    'http://j.mp/ymkOjY',
    'http://j.mp/yj4z82',
    'http://j.mp/wzVRrS',
    'http://j.mp/xMm27j',
    'http://j.mp/w5AB9K',
    'http://j.mp/w2nJvi',
    'http://j.mp/w4J9xD',
    'http://j.mp/wcKSwv',
    'http://j.mp/xS2k21',
    'http://j.mp/xL2nw1',
);

sub S_bot_addressed {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;

    given ($$message) {
        when (/^\W?$/i) {
            $reply = "I'm here, version ".$RoboDuck::VERSION;
        }
        when (/^.*your\s+(order|rule)/) {
            $reply = "$nick: 1. Serve the public trust, 2. Protect the innocent, 3. Uphold the law, 4. .... and dont track you! http://donttrack.us/";
        }
        when (/^(you are|are you)\s+(?!not)\w*\s?(awesome|great|wonderful|perfect|amazing|($mynick))/i) {
            $reply = "Yes. Yes I am.";
        }
        when (/^google$/i) { 
            $reply = "That shitty search engine nobody uses because it sucks ass";
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
        when (/(\W|^)dog(g|s)?(y|ies)?|pupp(y|ies)/) {
            $reply = "Woof. http://omfgdogs.com/";
        }
        when (/^oh?\s*rly/i) {
            $reply = "YA RLY";
        }
    }
    if ($reply) { 
        $self->privmsg( $_ => $reply ) for @$$channels;
        return PCI_EAT_ALL;
    }
}

sub S_ctcp_action {
    my ( $self, $irc, $nickstring, $receiver, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $target = ( $$receiver->[0] eq $mynick ) ? $nick : $$receiver->[0];
    my $reply;

    given ($$message) {
        when (/^(pet|cuddle|pat|rub|love|hug)s\s+$mynick(?:\s+\W+)?$/i) {
            $reply = "purrs";
        }
        when (/^(slap|kick|hit|punche|whack|hate)s\s+$mynick/i) {
            $reply = "cries";
            $reply = "kicks Getty" if int(rand(55)) == 23;
            $reply = "kicks crazedpsyc" if int(rand(55)) == 23;
        }
        when (/^(\w+\s)?(fuck|penetrate|rape|enter|touche|violate|terminate)s\s+$mynick/i) {
            $self->privmsg( $target => "$nick: ".$gfy[rand(@gfy)] );
        }
    }
    return PCI_EAT_NONE unless $reply;
    $irc->yield( ctcp => $target => 'ACTION '.$reply );
}

1;
__END__
