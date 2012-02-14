package RoboDuck;
# ABSTRACT: The IRC bot of the #duckduckgo Channel

sub POE::Kernel::USE_SIGCHLD () { 1 }

use Moses;
use namespace::autoclean;
use Cwd;

our $VERSION ||= '0.0development';

use WWW::DuckDuckGo;
use WWW::WolframAlpha;
use POE::Component::IRC::Plugin::Karma;
use POE::Component::IRC::Plugin::WWW::GetPageTitle;
use Cwd qw( getcwd );
use File::Spec;
use Try::Tiny;
use HTML::Entities;
use JSON::XS;
use String::Trim;
use POE::Component::IRC::Plugin::SigFail;
use POE::Component::WWW::Shorten;
use POE::Component::FastCGI;
use Moose::Util::TypeConstraints;

with qw(
	MooseX::Daemonize
);

if ($ENV{ROBODUCK_XMPP_JID} and $ENV{ROBODUCK_XMPP_PASSWORD}) {
	with 'RoboDuck::XMPP';
}

server $ENV{USER} eq 'roboduck' ? 'irc.freenode.net' : 'irc.perl.org';
nickname defined $ENV{ROBODUCK_NICKNAME} ? $ENV{ROBODUCK_NICKNAME} : $ENV{USER} eq 'roboduck' ? 'RoboDuck' : 'RoboDuckDev';
channels '#duckduckgo';
username 'duckduckgo';
plugins (
	'Karma' => POE::Component::IRC::Plugin::Karma->new(
		extrastats => 1,
		sqlite => File::Spec->catfile( getcwd(), 'karma_stats.db' ),),
		'SigFail' => POE::Component::IRC::Plugin::SigFail->new,
		'Title' => POE::Component::IRC::Plugin::WWW::GetPageTitle->new(
			max_uris  => 2,
			find_uris => 1,
			addressed => 0,
			trigger   => qw|https?://|,
			debug => 0,
		),
);

after start => sub {
	my $self = shift;
	return unless $self->is_daemon;

	$self->fcgi; # init it!

	# Required, elsewhere your POE goes nuts
	POE::Kernel->has_forked if !$self->foreground;
	POE::Kernel->run;
};

has fcgi => (
	is => 'ro',
	isa => 'Int',
	traits => [ 'NoGetopt' ],
	lazy_build => 1
);

sub _build_fcgi {
	my $self = shift;
	POE::Component::FastCGI->new(
		Port => 8667,
		Handlers => [
			[ '/gh-commit' => sub { $self->gh_commit(@_) } ],
		]
	);
}

sub gh_commit {
	my ( $self, $request ) = @_;
	my $response = $request->make_response;
	my $ok = 0;
	eval {
		$request->query('payload');
		$self->received_git_commit( decode_json($request->query('payload')) );
		$ok = 1;
	};
	$response->header( "Content-Type" => "text/plain" );
	$response->content( $ok ? "OK!" : "NOT OK!" );
}

has shorten => (
	is => 'ro',
	isa => 'POE::Component::WWW::Shorten',
	traits => [ 'NoGetopt' ],
	lazy_build => 1
);

sub _build_shorten {
	my $self = shift;

	my $type;
	my @params;
	if ( defined $ENV{ROBODUCK_BITLY_USERNAME} && defined $ENV{ROBODUCK_BITLY_KEY} ) {
		$type = 'Bitly';
		@params = ($ENV{ROBODUCK_BITLY_USERNAME}, $ENV{ROBODUCK_BITLY_KEY});
	} else {
		$type = 'IsGd';
	}

	POE::Component::WWW::Shorten->spawn(
		alias => 'shorten',
		type => $type,
		params => \@params
	);
}

has ddg => (
	isa => 'WWW::DuckDuckGo',
	is => 'rw',
	traits => [ 'NoGetopt' ],
	lazy => 1,
	default => sub { WWW::DuckDuckGo->new( http_agent_name => __PACKAGE__.'/'.$VERSION, safeoff => 1 ) },
);

class_type 'WWW::WolframAlpha';
has wa => (
	isa => 'WWW::WolframAlpha|Undef',
	is => 'rw',
	traits => [ 'NoGetopt' ],
	lazy_build => 1,
);

sub _build_wa {
	defined $ENV{ROBODUCK_WA_APPID} ? WWW::WolframAlpha->new( appid => $ENV{ROBODUCK_WA_APPID} ) : undef;
}
has '+pidbase' => (
    default => sub { getcwd },
);
sub external_message {
	my ( $self, $msg ) = @_;

	for (@{$self->get_channels}) {
		$self->privmsg( $_ => $msg );
	}
}

sub received_git_commit {
	my ( $self, $info ) = @_;

	my ( $pusher, $repo, $commits, $ref ) = @{$info}{ 'pusher', 'repository', 'commits', 'ref' };
	my $repo_base_url = $repo->{url};
	my $repo_url;
	if ($ref =~ m|^refs/heads/|) {
		$ref =~ s{^refs/heads/}{};
		$repo_url = "$repo_base_url/tree/$ref";
	}
	else {
		$repo_url = $repo_base_url;
	}

	my $repo_name = $repo->{name};
	my $pusher_name = $pusher->{name};
	my $commit_count = scalar @{$commits};
	my $plural = ($commit_count == 1) ? '' : 's';
	my $link_and_ref = ($repo_url = $repo_base_url) ? "$repo_url" : "$repo_name/$ref ($repo_url)";

	my $initial_msg = "[git] $pusher_name pushed $commit_count commit$plural to $link_and_ref";

	for (@{$self->get_channels}) {
		$self->privmsg( $_ => $initial_msg ) unless ($commit_count == 0);
	}

	for (@{$commits}) {
		my ( $id, $url, $author, $msg ) = @{$_}{ 'id', 'url', 'author', 'message' };
		my $short_id = substr $id, 0, 7;
		my $author_name = $author->{name};

		my $commit_message = "[$short_id] $author_name - $msg SHORT_URL";
		$self->shorten->shorten({
				url => $url,
				event => 'announce_shortened_url',
				session => $self->get_session_id,
				_message => $commit_message
			});
	}
}

event announce_shortened_url => sub {
	my ( $self, $returned ) = @_[ OBJECT, ARG0 ];

	my ( $message, $url ) = @{$returned}{ '_message', 'short' };
	$message =~ s/SHORT_URL/$url/;

	for (@{$self->get_channels}) {
		$self->privmsg( $_ => $message );
	}
};

event irc_public => sub {
	my ( $self, $nickstr, $channels, $msg ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	my $what = lc($msg);
	my $nick = lc($self->nick);
	if ( $what =~ /^$nick(\?|!|:|,)(|\s|$)/i) {
		$what =~ s/^$nick\??:?!?(\s|$)?//i;
		$self->myself($nickstr,$channels->[0],$what);
        return;
	}
	if ( $what =~ /^(!|\?)\s/ ) {
		$what =~ s/^(!|\?)\s//;
		$self->myself($nickstr,$channels->[0],$what);
	}
    if ( $what =~ /^\.(\w+)(\s+[^\s]+)?$/ ) {
		my $name = $1;
        my $target = trim($2);
		$self->linkgrabber($nickstr,$channels->[0],$name,$target);
    }
	if ($msg =~ /^!yesorno /i) {
		my $zci = $self->ddg->zci("yes or no");
		for (@{$channels}) {
			$self->privmsg( $_ => "The almighty DuckOracle says..." );
		}
		if ($zci->answer =~ /^no /) {
			for (@{$channels}) {
				$self->delay_add( say_later => 2, $_, "... no" );
			}
		} else {
			for (@{$channels}) {
				$self->delay_add( say_later => 2, $_, "... yes" );
			}
		}
		return;
	}
	if ( $msg =~ /(\W|^)(moo|cows?)(\W|$)/i ) {
		for (@{$channels}) {
			$self->privmsg( $_ => "MOOOOooo! http://www.youtube.com/watch?v=FavUpD_IjVY" );
		}
	}
	elsif ( $msg =~ /(\W|^)(meow|cats?|kittens?|kitty|kitties)(\W|$)/i ) {
		for (@{$channels}) {
			$self->privmsg( $_ => "MEOW. https://www.youtube.com/watch?v=QNwCojCJ3-Q" );	
		}
	}
	elsif ( $msg =~ /(\W|^)(bear|cycles?)(\W|$)/i ) {
		for (@{$channels}) {
			$self->privmsg( $_ => "http://www.youtube.com/watch?v=-0Xa4bHcJu8" );
		}
	}
};

event irc_msg => sub {
	my ( $self, $nickstr, $msg ) = @_[ OBJECT, ARG0, ARG2 ];
	my $what = lc($msg);
	my $mynick = lc($self->nick);
	my ( $nick ) = split /!/, $nickstr;
	&myself($self,$nickstr,$nick,$what);
};

event irc_mode => sub {
	my ( $self, $nickstr, $channel, $modes, $target ) = @_[ OBJECT, ARG0, ARG1, ARG2, ARG3 ];
	$self->debug( $nickstr." ".$channel." ".$modes );
	my ( $nick ) = split /!/, $nickstr;
	if ($target) {
		$self->debug( $nick." changed mode of ".$target );
		my $mynick = lc($self->nick);
		if (($target =~ m#^$mynick$#i) && ($modes =~ m#[+][o]#)) {
			print "OK, Do stuff.";
		}
	}
};

sub myself {
	my ( $self, $nickstr, $channel, $msg ) = @_;
	my ( $nick ) = split /!/, $nickstr;
	$self->debug($nick.' told me "'.$msg.'" on '.$channel);
	my $reply;
	my $zci;
	my $waq;
    my $mynick = $self->nick;
	try {
		if (!$msg) {
			$reply = "I'm here, version ".$VERSION ;
        } elsif ($msg =~ /^($mynick)\W?$/i) {
            $reply = "That's me! My source: http://github.com/Getty/duckduckgo-roboduck";
		} elsif ($msg =~ /your order/i or $msg =~ /your rules/i) {
			$reply = "1. Serve the public trust, 2. Protect the innocent, 3. Uphold the law, 4. .... and dont track you! http://donttrack.us/";
		} elsif ($msg =~ /^(are you|you are)\s+(awesome|great|wonderful|perfect)/i) {
			$reply = "Yes. Yes I am.";
		} elsif ($msg =~ /^google$/i) {
			$reply = "google definition: that shitty search engine that nobody cares about because it sucks ass.";
		} elsif ($zci = $self->ddg->zci($msg)) {
			if ($zci->has_answer) {
				$reply = $zci->answer;
				$reply .= " (".$zci->answer_type.")";
			} elsif ($zci->has_definition) {
				$reply = $zci->definition;
				$reply .= " (".$zci->definition_source.")" if $zci->has_definition_source;
			} elsif ($zci->has_abstract_text) {
				$reply = $zci->abstract_text;
				$reply .= " (".$zci->abstract_source.")" if $zci->has_abstract_source;
				$reply .= " ".$zci->abstract_url if $zci->has_abstract_url;
			} elsif ($self->wa && ($waq = $self->wa->query( input => $msg, ))) {
				$reply = '';
				my @output = ();
				if ($waq->success) {
					for my $pod (@{$waq->pods}) {				    					    	
						for my $subpod (@{$pod->subpods}) {
							last if length(join(', ', @output)) > 200;
							my $plaintext = $subpod->plaintext;
							$plaintext =~ s/\n/; /g;
			    			push(@output, $plaintext) if $plaintext;
				        }
					}
				}
				$reply = join(', ', @output) if @output;
				$reply = '<irc_sigfail:FAIL>' unless @output;
			} else {
				$reply = '<irc_sigfail:FAIL>';
			}
		} else {
			$reply = '0 :(';
		}
		$reply = decode_entities($reply);
		$reply =~ s/\n/; /g;
		$self->privmsg( $channel => "$nick: ".$reply );
	} catch {
		$self->privmsg( $channel => "doh!" );
		#p($_);
	}
};

sub linkgrabber {
	my ( $self, $nickstr, $channel, $msg, $target ) = @_;
	my ( $nick ) = split /!/, $nickstr;
	$self->debug($nick.' asked for "'.$msg.'" on '.$channel);
    my $reply;

	$target = ($target) ? $target : $nick;

	my %links = (
		"goodies" 	=> "https://duckduckgo.com/goodies.html",
		"bang" 		=> "https://duckduckgo.com/bang.html",
		"newbang" 	=> "https://duckduckgo.com/newbang.html",
		"about" 	=> "https://duckduckgo.com/about.html",
		"settings" 	=> "https://duckduckgo.com/settings.html",
		"privacy" 	=> "https://duckduckgo.com/privacy.html",
		"dontbubble"=> "http://dontbubble.us/",
		"donttrack"	=> "http://donttrack.us/",
		"help" 		=> "https://help.duckduckgo.com/",
		"feedback"	=> "https://duckduckgo.com/feedback.html",
		"community"	=> "https://dukgo.com/",
		"forum"		=> "https://duck.co/",
		"spread"	=> "https://duckduckgo.com/spread.html",
		"twitter"	=> "https://twitter.com/duckduckgo",
		"facebook"	=> "https://facebook.com/duckduckgo",
		"stickers"	=> "https://duckduckgo.com/stickers.html & https://www.stickermule.com/duckduckgo",
		"shorturl"	=> "http://ddg.gg/",
		"github"	=> "https://github.com/duckduckgo",
		"store"		=> "http://cafepress.com/duckduckgo",
		"reddit"	=> "http://www.reddit.com/r/duckduckgo",
		"identica"	=> "https://identi.ca/duckduckgo",
		"diaspora"	=> "https://joindiaspora.com/u/duckduckgo",
		"duckpan"	=> "http://duckpan.org/",
        "homepage"  => "https://duckduckgo.com/",
        "home"      => \"homepage",
        "h"         => \"homepage",
        "api"       => "https://api.duckduckgo.com/",
        "traffic"   => "https://duckduckgo.com/traffic.html",
        "browser"   => "http://help.duckduckgo.com/customer/portal/articles/216425-browsers",
        "addsite"   => "http://help.duckduckgo.com/customer/portal/articles/216407",
        "addad"     => "http://help.duckduckgo.com/customer/portal/articles/216405",
        "syntax"    => "http://help.duckduckgo.com/customer/portal/articles/300304-syntax",
		"image"		=> "http://help.duckduckgo.com/customer/portal/articles/215615-images",
		"email"		=> "http://help.duckduckgo.com/customer/portal/articles/215614-email",
        "soul"      => "http://www.youtube.com/watch?v=XvwK-3cQ6gE",
        "die"       => "http://www.youtube.com/watch?v=K5sANHYp_IQ",
		);

	try {
		if ( exists $links{$msg} ) {
			my $value = $links{$msg};
            $reply = ref $value eq 'SCALAR' ? $links{$$value} : $value;
		}
		else {
			$reply = "I don't have a link to \"$msg\"";
		}
		$reply = decode_entities($reply);
		$self->privmsg( $channel => "$target: ".$reply );
	} catch {
		$self->privmsg( $channel => "doh!" );
	}

};

event say_later => sub {
	my ( $self, $channel, $msg ) = @_[ OBJECT, ARG0, ARG1 ];
	$self->privmsg( $channel => $msg );
};

event 'no' => sub {
};

1;
