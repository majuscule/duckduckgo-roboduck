package RoboDuck::Plugin::Links;
use 5.10.0;
use Moses::Plugin;
use String::Trim;

my %links = (
    # duckduckgo.com/*.html / etc.
    "goodie"    => "https://duckduckgo.com/goodies.html",
    "bang"      => "https://duckduckgo.com/bang.html",
    "newbang"   => "https://duckduckgo.com/newbang.html",
    "about"     => "https://duckduckgo.com/about.html",
    "setting"   => "https://duckduckgo.com/settings.html",
    "param"     => "https://duckduckgo.com/params.html",
    "privacy"   => "https://duckduckgo.com/privacy.html",
    "feedback"  => "https://duckduckgo.com/feedback.html",
    "spread"    => "https://duckduckgo.com/spread.html",
    "traffic"   => "https://duckduckgo.com/traffic.html",
    "tech"      => "https://duckduckgo.com/tech.html",
    "searchbox" => "https://duckduckgo.com/search_box.html",
    "api"       => "https://api.duckduckgo.com/",
    "homepage"  => "https://duckduckgo.com/",
    "home"      => \"homepage",
    "h"         => \"homepage",
    "shorturl"  => "http://ddg.gg/",

    # minisites
    "dontbubble"=> "http://dontbubble.us/",
    "donttrack" => "http://donttrack.us/",
    "duckduckhack"=> "http://duckduckhack.com/",
    "hack"      => \"duckduckhack",
    "ddh"       => \"duckduckhack",

    # other DDG sites
    "help"      => "https://help.duckduckgo.com/",
    "community" => "https://dukgo.com/",
    "forum"     => "https://duck.co/",
    "duckpan"   => "http://duckpan.org/",

    # social
    "twitter"   => "https://twitter.com/duckduckgo",
    "facebook"  => "https://facebook.com/duckduckgo",
    "sticker"   => "https://www.stickermule.com/duckduckgo",
    "github"    => "https://github.com/duckduckgo",
    "store"     => "http://cafepress.com/duckduckgo",
    "reddit"    => "http://www.reddit.com/r/duckduckgo",
    "identica"  => "https://identi.ca/duckduckgo",
    "diaspora"  => "https://joindiaspora.com/u/duckduckgo",

    # official ddg articles (help.ddg, blogposts, etc)
    "browser"   => "http://help.duckduckgo.com/customer/portal/articles/216425-browsers",
    "addsite"   => "http://help.duckduckgo.com/customer/portal/articles/216407",
    "addad"     => "http://help.duckduckgo.com/customer/portal/articles/216405",
    "syntax"    => "http://help.duckduckgo.com/customer/portal/articles/300304-syntax",
    "image"     => "http://help.duckduckgo.com/customer/portal/articles/215615-images",
    "email"     => "http://help.duckduckgo.com/customer/portal/articles/215614-email",
    "history"   => "http://help.duckduckgo.com/customer/portal/articles/216406-history",
    "source"    => "http://help.duckduckgo.com/customer/portal/articles/216399-sources",
    "spam"      => "http://help.duckduckgo.com/customer/portal/articles/215611-spam",
    "logo"      => "http://help.duckduckgo.com/customer/portal/articles/485613-holiday-logos",
    "pii"       => "http://www.gabrielweinberg.com/blog/2010/11/how-to-not-log-personally-identifiable-information.html",

    # specific browsers
    "firefox"   => "http://help.duckduckgo.com/customer/portal/articles/216441-firefox",
    "chrome"    => "http://help.duckduckgo.com/customer/en/portal/articles/216440",
    "opera"     => "http://help.duckduckgo.com/customer/portal/articles/216453-opera",
    "safari"    => "http://help.duckduckgo.com/customer/portal/articles/216447-safari",
    "android"   => "http://help.duckduckgo.com/customer/portal/articles/216461-android",
    "ie"        => "http://help.duckduckgo.com/customer/portal/articles/216464-internet-explorer",
    "omniweb"   => "http://help.duckduckgo.com/customer/portal/articles/216459-omniweb",
    "epiphany"  => "http://help.duckduckgo.com/customer/portal/articles/216460-epiphany",
    "conkeror"  => "http://help.duckduckgo.com/customer/portal/articles/216462-conkeror",

    # random
    "soul"      => "http://www.youtube.com/watch?v=XvwK-3cQ6gE",
    "die"       => "http://www.youtube.com/watch?v=K5sANHYp_IQ",
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
1;
__END__
