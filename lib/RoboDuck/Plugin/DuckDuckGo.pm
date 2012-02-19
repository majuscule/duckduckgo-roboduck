package RoboDuck::Plugin::DuckDuckGo;
use 5.10.0;
our $VERSION = '0.01';
use Moses::Plugin;
use WWW::DuckDuckGo;
use POE::Component::IRC::Plugin::SigFail;
use HTML::Entities;

has ddg => (
    isa     => 'WWW::DuckDuckGo',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_ddg',
    handles => { search => 'zci', },
);

sub _build_ddg {
    WWW::DuckDuckGo->new( http_agent_name => __PACKAGE__ . '/' . $VERSION );
}


#
# Blatantly Stolen from RoboDuck (Getty++)
#

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;

    given ($$message) {
        when (/^(?:$mynick|!ddg)\W?\s*(.*)?$/) {
            my $res = $self->search($1);
            warn $res->heading;
            given ($res) {
                when ( $_->has_answer ) {
                    $reply = "${\$res->answer} (${\$res->answer_type})";
                }                
                when ( $_->has_definition ) {
                    $reply = $res->definition;
                }
                when ( $_->has_abstract_text ) {
                    $reply = $res->abstract_text;
                    $reply .= " (".$res->abstract_source.")" if $res->has_abstract_source;
                    $reply .= " ".$res->abstract_url if $res->has_abstract_url;
                }
                when ( $_->has_heading ) {
                    $reply = $res->heading;
                }
                default {
                    return PCI_EAT_NONE; # pass it to other plugins and let them reply if they fail
                }
            }
            if ($reply) { $self->privmsg( $_ => "$nick: ".$reply ) for @$$channels; }
            return PCI_EAT_ALL;
        }
        default { return PCI_EAT_NONE; };
    }
}

1;
__END__
