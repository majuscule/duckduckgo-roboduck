package RoboDuck::Plugin::WolframAlpha;
use 5.10.0;
our $VERSION = '0.01';
use Moses::Plugin;
use WWW::WolframAlpha;
use Moose::Util::TypeConstraints;
use POE::Component::IRC::Plugin::SigFail;
use HTML::Entities;
use warnings; use strict;

class_type 'WWW::WolframAlpha';
has wa => (
    isa => 'WWW::WolframAlpha|Undef',
    is => 'ro',
    lazy => 1,
    builder => '_build_wa',
    handles => { search => 'query', },
);

sub _build_wa {
    defined $ENV{ROBODUCK_WA_APPID} ? WWW::WolframAlpha->new( appid => $ENV{ROBODUCK_WA_APPID}, ) : undef;
}

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;

    given ($$message) {
        when (/^(?:$mynick|!wa)\W?\s*(.*)/) {
            warn $1;
            my $res = $self->search( input => $1 ) if $self->wa;
            warn "WolframAlpha APPID not set, or something's borked" unless $self->wa;
            given ($res) {
                my @output;
                if ($res->success) {
                    for my $pod (@{$res->pods}) {
                        for my $subpod (@{$pod->subpods}) {
                            last if length(join(', ', @output)) > 200;
                            my $plaintext = $subpod->plaintext;
                            $plaintext =~ s/\n/; /g if $plaintext;
                            push(@output, $plaintext) if $plaintext;
                        }
                    }
                }
                $reply = (@output) ? join(', ', @output) : '<irc_sigfail:FAIL>';
                $reply = decode_entities($reply);
                $self->privmsg( $_ => "$nick: ".$reply ) for @$$channels;
            }
        }
        return PCI_EAT_ALL;
    }
}

1;
__END__
