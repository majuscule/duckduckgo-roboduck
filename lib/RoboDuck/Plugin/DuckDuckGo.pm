package RoboDuck::Plugin::DuckDuckGo;
use 5.10.0;
use Moses::Plugin;
use WWW::DuckDuckGo;
use HTML::Entities;
use MooseX::Aliases;

has ddg => (
    isa     => 'WWW::DuckDuckGo',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_ddg',
    handles => { search => 'zci', },
);

sub _build_ddg {
    WWW::DuckDuckGo->new( http_agent_name => __PACKAGE__ . '/' . "0.0development", safeoff => 1 );
}

sub S_say_later {
	my ( $self, $channel, $msg ) = @_[ OBJECT, ARG0, ARG1 ];
	$self->privmsg( $channel => $msg );
    return PCI_EAT_NONE;
};


sub S_bot_addressed {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;

    given ($$message) {
        when (/^(.+)$/i) {
            my $res = $self->search($1);
            given ($res) {
                when ( $_->has_redirect ) { 
                    $reply = $_->redirect;
                }
                when ( $_->has_answer ) {
                    $reply = "${\$res->answer} (${\$res->answer_type})";
                }                
                when ( $_->has_definition ) {
                    $reply = $res->definition;
                    $reply .= " (".$res->definition_source.")" if $res->has_definition_source;
                }
                when ( $_->has_abstract_text ) {
                    $reply = $res->abstract_text;
                    $reply .= " (".$res->abstract_source.")" if $res->has_abstract_source;
                    $reply .= " ".$res->abstract_url if $res->has_abstract_url;
                }
                when ( $_->default_related_topics ) {
                    $reply = $_->default_related_topics->[0]->text." ".$_->default_related_topics->[0]->first_url;
                    $reply .=  " (disambig: ".$res->abstract_url." )" if $res->has_abstract_url;
                }
                when ( $_->has_heading ) {
                    $reply = $res->heading;
                }
                default {
                    return PCI_EAT_NONE; # pass it to other plugins and let them reply if they fail
#return PCI_EAT_ALL;
                }
            }
            if ($reply) { 
                $reply =~ s/\s*<br>\s*/, /g; $reply =~ s/\s*\n\s*/ /g;
                $self->privmsg( $_ => "$nick: ".decode_entities($reply) ) for @$$channels; 
            }
            return PCI_EAT_ALL;
        }
        default { return PCI_EAT_NONE; };
    }
}

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;

    given ($$message) {
        when (/^(o|oh)?\W*(almighty|mighty|great|powerful)?\s*(duck)?oracle\W/i) {
            my $zci = $self->search("yes or no");
            $self->privmsg( $_ => "The almighty DuckOracle says..." ) for @$$channels;
            if ($zci->answer =~ /^no /) {
                $self->bot->delay_add( say_later => 2, $_, "... no" ) for @$$channels;
            } else {
                $self->bot->delay_add( say_later => 2, $_, "... yes" ) for @$$channels;
            }
            return PCI_EAT_ALL;
        }
    }
}

1;
__END__
