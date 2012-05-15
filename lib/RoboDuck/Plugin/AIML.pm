package RoboDuck::Plugin::AIML;
use Moose;
use Moses::Plugin;
extends qw(Adam::Plugin);

# ABSTRACT: A Plugin for talking to Pandorabots.com

use Acme::LOLCAT;
use POE::Component::IRC::Plugin qw(PCI_EAT_ALL);
use Net::AIML;

has botid => (
    isa     => 'Str',
    is      => 'ro',
    default => sub {'8215c8b9fe34cb3e'},
);

has _custids => (
    isa     => 'HashRef',
    traits  => ['Hash'],
    is      => 'ro',
    default => sub { {} },
    handles => {
        'get_custid' => 'get',
        'set_custid' => 'set',
    }
);

has _aiml => (
    isa     => 'Net::AIML',
    lazy    => 1,
    default => sub { Net::AIML->new( botid => $_[0]->botid ) },
    handles => { tell_bot => 'tell' }
);

sub S_bot_addressed {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    $message = $$message;
    return unless $message =~ /^(?:hi|chat|say)\W+(.+)$/;
    my @channels = @{$$channels};
    my ($nick) = split /!/, $$nickstring;
    my ( $res, $id ) = $self->tell_bot( $1, $self->get_custid($nick) );
    $self->set_custid( $nick => $id );
    $self->privmsg( $_ => "$nick: " . ucfirst(lc(translate($res))) ) for @channels;
    return PCI_EAT_ALL;
}

1;
__END__
