package RoboDuck::Plugin::MetaCPAN;
use 5.10.0;
use Moses::Plugin;

use MetaCPAN::API;
use RoboDuck::Plugin::SigFail;
use HTML::Entities;

has mcpan => (
    isa => "MetaCPAN::API",
    is      => 'ro',
    lazy    => 1,
    builder => '_build_mcpan',
    handles => { fetch => 'fetch', release => 'release', },
);

sub _build_mcpan {
    MetaCPAN::API->new;
}

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;

    given ($$message) {
        when (/^m?cpan\s+(.+)$/) {
            try {
                my $query = $1;
                $query =~ s/::/-/g;

                my $result = $self->fetch( '/release', q => $query, size => 1 );
                unless (defined $$result{hits}{hits}[0]) {
                    $self->privmsg( $_ => decode_entities("$nick: <irc_sigfail:FAIL>") ) for @$$channels;
                    return PCI_EAT_ALL;
                }
                my $dist = $$result{hits}{hits}[0]{_source}{distribution};
                my $mod = $self->release( distribution => $dist );
                return PCI_EAT_NONE unless defined $$mod{abstract};

                my $name = $dist;
                $name =~ s/-/::/g;
                my $output = "$name - ".$$mod{abstract}.": https://metacpan.org/module/$name";
                $self->privmsg( $_ => "$nick: $output" ) for @$$channels;
                return PCI_EAT_ALL;
                
            } catch { 
                $self->privmsg( $_ => "Ouch." ) for @$$channels;
                return PCI_EAT_ALL;
            }
        }
    }
}

1;
__END__
