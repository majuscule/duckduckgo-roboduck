package RoboDuck;
use 5.10.0;

sub POE::Kernel::USE_SIGCHLD () { 1 }
use Moses;
use namespace::autoclean;
use Cwd qw(getcwd);
use HTML::Entities;

our $VERSION ||= '0.0development';

use RoboDuck::Plugin::SigFail;

# External plugins
use POE::Component::IRC::Plugin::Karma;
use POE::Component::IRC::Plugin::WWW::GetPageTitle;

with qw(MooseX::Daemonize);

has '+pidbase' => (
    default => sub { getcwd },
);

server $ENV{USER} eq 'roboduck' ? 'irc.freenode.net' : 'irc.perl.org';
nickname $ENV{ROBODUCK_NICKNAME} || ( $ENV{USER} eq 'roboduck' ? 'RoboDuck' : 'RoboDuckDev' );
channels '#duckduckgo';
username 'duckduckgo';

plugins
  Goodies => "RoboDuck::Plugin::Goodies",
  DuckDuckGo => "RoboDuck::Plugin::DuckDuckGo",
  WolframAlpha => "RoboDuck::Plugin::WolframAlpha",
  Links => "RoboDuck::Plugin::Links",
  YouTube => "RoboDuck::Plugin::YouTube",
  MetaCPAN => "RoboDuck::Plugin::MetaCPAN",
  'Karma' => POE::Component::IRC::Plugin::Karma->new(
    extrastats => 1,
    sqlite => File::Spec->catfile( getcwd(), 'karma_stats.db' ),),
  'SigFail' => RoboDuck::Plugin::SigFail->new,
  'Title' => POE::Component::IRC::Plugin::WWW::GetPageTitle->new(
    max_uris  => 2,
    find_uris => 1,
    addressed => 0,
    trigger   => qw|https?://|,
    debug => 0,
   ),
  Bangs => "RoboDuck::Plugin::Bangs",
  #AIML => "RoboDuck::Plugin::AIML",
  ;

after start => sub {
    my $self = shift;
    return unless $self->is_daemon();
    POE::Kernel->has_forked if !$self->foreground;
    POE::Kernel->run;
};

event irc_bot_addressed => sub {
    my ( $self, $nickstr, $channel, $msg ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
    my ($nick) = split /!/, $nickstr;
    given ($msg) {
        when (/.*/) {
            $self->privmsg( $channel => "$nick: <irc_sigfail:FAIL>" );
        }
    }
};

event say_later => sub {
    my ( $self, $channel, $msg ) = @_[ OBJECT, ARG0, ARG1 ];
    $self->privmsg( $channel => $msg );
};

event irc_001 => sub {
    my $self = $_[ OBJECT ];
    $self->privmsg('NickServ' => 'identify '.$ENV{ROBODUCK_NICKSERV_PASSWORD}) if defined $ENV{ROBODUCK_NICKSERV_PASSWORD} && $self->server_name =~ /\.freenode\.net$/;
};

1;
__END__
