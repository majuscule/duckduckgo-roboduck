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
use POE::Component::IRC::Plugin::SigFail;
use POE::Component::WWW::Shorten;
use POE::Component::FastCGI;

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
			trigger   => qr/^/,
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
	default => sub { WWW::DuckDuckGo->new( http_agent_name => __PACKAGE__.'/'.$VERSION ) },
);

my $APPID;
$APPID = $ENV{'ROBODUCK_WA_APPID'} if $ENV{'ROBODUCK_WA_APPID'};
$APPID = '' unless $ENV{'ROBODUCK_WA_APPID'};
has wa => (
	isa => 'WWW::WolframAlpha',
	is => 'rw',
	traits => [ 'NoGetopt' ],
	lazy => 1,
	default => sub { WWW::WolframAlpha->new( appid => $APPID ) },
);

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
	$ref =~ s{^refs/heads/}{};

	my $repo_name = $repo->{name};
	my $pusher_name = $pusher->{name};
	my $commit_count = scalar @{$commits};
	my $plural = ($commit_count == 1) ? '' : 's';

	my $initial_msg = "[git] $pusher_name pushed $commit_count commit$plural to $repo_name/$ref";

	for (@{$self->get_channels}) {
		$self->privmsg( $_ => $initial_msg );
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
	if ( $what =~ /^$nick(\?|!|:|,)(|\s|$)/) {
		$what =~ s/^$nick\??:?!?(\s|$)?//i;
		&myself($self,$nickstr,$channels->[0],$what);
	}
	if ( $what =~ /^(!|\?)\s/ ) {
		$what =~ s/^(!|\?)\s//;
		&myself($self,$nickstr,$channels->[0],$what);
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
	if ( $msg =~ /(\W|^)cows{0,1}(\W|$)/i ) {
		for (@{$channels}) {
			$self->privmsg( $_ => "MOOOOooo! http://www.youtube.com/watch?v=FavUpD_IjVY" );
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
	

sub myself {
	my ( $self, $nickstr, $channel, $msg ) = @_;
	my ( $nick ) = split /!/, $nickstr;
	$self->debug($nick.' told me "'.$msg.'" on '.$channel);
	my $reply;
	my $zci;
	my $waq;
	try {
		print "1";
		if (!$msg) {
			$reply = "I'm here in version ".$VERSION ;
		} elsif ($msg =~ /your order/i or $msg =~ /your rules/i) {
			$reply = "1. Serve the public trust, 2. Protect the innocent, 3. Uphold the law, 4. .... and dont track you! http://donttrack.us/";
		} elsif ($msg =~ /[are you|you are] [awesome|great|wonderful|perfect]/i) {
			$reply = "Yes. Yes I am.";
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
			} elsif ($zci->has_heading) {
				$reply = $zci->heading;
			
			} elsif ($APPID && ($waq = $self->wa->query( input => $msg, ))) {
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
			}
		} else {
			$reply = '0 :(';
		}
		$reply = decode_entities($reply);
		$self->privmsg( $channel => "$nick: ".$reply );
	} catch {
		$self->privmsg( $channel => "doh!" );
		p($_);
	}
};

event say_later => sub {
	my ( $self, $channel, $msg ) = @_[ OBJECT, ARG0, ARG1 ];
	$self->privmsg( $channel => $msg );
};

event 'no' => sub {
};

1;
