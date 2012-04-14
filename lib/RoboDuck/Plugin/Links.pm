package RoboDuck::Plugin::Links;
use 5.10.0;
use Moses::Plugin;
use String::Trim;

my %links = (
    "goodie"    => "https://duckduckgo.com/goodies.html",
    "bang"      => "https://duckduckgo.com/bang.html",
    "newbang"   => "https://duckduckgo.com/newbang.html",
    "about"     => "https://duckduckgo.com/about.html",
    "setting"   => "https://duckduckgo.com/settings.html",
    "privacy"   => "https://duckduckgo.com/privacy.html",
    "dontbubble"=> "http://dontbubble.us/",
    "donttrack" => "http://donttrack.us/",
    "help"      => "https://help.duckduckgo.com/",
    "feedback"  => "https://duckduckgo.com/feedback.html",
    "community" => "https://dukgo.com/",
    "forum"     => "https://duck.co/",
    "spread"    => "https://duckduckgo.com/spread.html",
    "twitter"   => "https://twitter.com/duckduckgo",
    "facebook"  => "https://facebook.com/duckduckgo",
    "sticker"   => "https://duckduckgo.com/stickers.html & https://www.stickermule.com/duckduckgo",
    "shorturl"  => "http://ddg.gg/",
    "github"    => "https://github.com/duckduckgo",
    "store"     => "http://cafepress.com/duckduckgo",
    "reddit"    => "http://www.reddit.com/r/duckduckgo",
    "identica"  => "https://identi.ca/duckduckgo",
    "diaspora"  => "https://joindiaspora.com/u/duckduckgo",
    "duckpan"   => "http://duckpan.org/",
    "homepage"  => "https://duckduckgo.com/",
    "home"      => \"homepage",
    "h"         => \"homepage",
    "api"       => "https://api.duckduckgo.com/",
    "traffic"   => "https://duckduckgo.com/traffic.html",
    "browser"   => "http://help.duckduckgo.com/customer/portal/articles/216425-browsers",
    "addsite"   => "http://help.duckduckgo.com/customer/portal/articles/216407",
    "addad"     => "http://help.duckduckgo.com/customer/portal/articles/216405",
    "syntax"    => "http://help.duckduckgo.com/customer/portal/articles/300304-syntax",
    "image"     => "http://help.duckduckgo.com/customer/portal/articles/215615-images",
    "email"     => "http://help.duckduckgo.com/customer/portal/articles/215614-email",
    "soul"      => "http://www.youtube.com/watch?v=XvwK-3cQ6gE",
    "die"       => "http://www.youtube.com/watch?v=K5sANHYp_IQ",
    "history"   => "http://help.duckduckgo.com/customer/portal/articles/216406-history",
    "source"    => "http://help.duckduckgo.com/customer/portal/articles/216399-sources",
    "tech"      => "https://duckduckgo.com/tech.html",
    "pii"       => "http://www.gabrielweinberg.com/blog/2010/11/how-to-not-log-personally-identifiable-information.html",
    "searchbox" => "https://duckduckgo.com/search_box.html",
    "spam"      => "http://help.duckduckgo.com/customer/portal/articles/215611-spam",
    "hackhackgo"=> "http://duckduckhack.com/",
    "hack"      => \"hackhackgo",
);

sub give_link {
    my ( $self, $channels, $target, $key ) = @_;
    my $reply;
    $key =~ s/[-_']//g;
    $key =~ s/s$//;

    if ( exists $links{$key} ) {
        my $value = $links{$key};
        $reply = ref $value eq 'SCALAR' ? $links{$$value} : $value;
    } else {
        $reply = "I don't have a link to \"$key\"";
    }
    $self->privmsg( $_ => "$target: ".$reply ) for @$$channels;
}

sub S_public {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my ( $nick ) = split /!/, $$nickstring;
    my $mynick = $self->nick;
    my $reply;

    $message = lc($$message);

    given ($message) {
        when (/^\.(\w+)(\s+[^\s]+)?$/) {
            my $target = trim($2);
            $target = ($target) ? $target : $nick;
            $self->give_link( $channels, $target, $1 );
            return PCI_EAT_ALL;
        }
    }
}
