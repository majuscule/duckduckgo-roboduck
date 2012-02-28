package RoboDuck::Plugin::YouTube;
use 5.10.0;
use Moses::Plugin;
use WebService::GData::YouTube;

my $yt = WebService::GData::YouTube->new();
$yt->query->orderby("relevance");

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;
    
    given ($$message) {
        when (/^(?:yt|youtube)\s+(.+)/) {
            $yt->query->q($1)->limit(1,0);
            my $videos = $yt->search_video();
            $reply = $videos->[0]->title if @$videos;
            $reply .= ": https://www.youtube.com/watch?v=".$videos->[0]->video_id if @$videos;
        }
    }
    if ($reply) { 
        $self->privmsg( $_ => "$nick: $reply" ) for @$$channels;
        return PCI_EAT_ALL;
    }
}

1;
__END__
