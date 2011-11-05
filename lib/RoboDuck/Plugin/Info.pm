package RoboDuck::Plugin::Info;
use 5.10.0;
our $VERSION = '0.01';
use Moses::Plugin;
use DateTime;
use WWW::DuckDuckGo;

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
    given ($$message) {
        when (/^\.quack\s*(.*)?$/) {
            warn $1;
            my $res = $self->search($1);
            warn $res->heading;
            given ($res) {
                warn $_->heading;
                when ( $_->has_answer ) {
                    my $reply = "${\$res->answer} (${\$res->answer_type})";
                    $self->privmsg( $_ => $reply ) for @$$channels;
                }                
                when ( $_->has_definition ) {
                    my $reply = $res->definition;
                    $self->privmsg( $_ => $reply ) for @$$channels;
                }
                when ( $_->has_abstract_text ) {
                    my $reply = $res->abstract_text;
                    $self->privmsg( $_ => $reply ) for @$$channels;
                }
                when ( $_->has_heading ) {
                    my $reply = $res->heading;
                    warn $reply;
                    $self->privmsg( $_ => $reply ) for @$$channels;
                }
                default {
                    my $reply = "No clue.";
                    $self->privmsg( $_ => $reply ) for @$$channels;
                }
            }
            return PCI_EAT_ALL;
        }
        default { return PCI_EAT_NONE; };
    }
}

1;
__END__
