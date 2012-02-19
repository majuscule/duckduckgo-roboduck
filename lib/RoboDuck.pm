package RoboDuck;
use 5.10.0;

sub POE::Kernel::USE_SIGCHLD () { 1 }
use Moses;
use namespace::autoclean;
use strict; use warnings;
use Cwd qw(getcwd);
use Cwd;

# External plugins
use POE::Component::IRC::Plugin::Karma;
use POE::Component::IRC::Plugin::WWW::GetPageTitle;
use POE::Component::IRC::Plugin::SigFail;

with qw(MooseX::Daemonize);

has '+pidbase' => (
    default => sub { getcwd },
);

server $ENV{USER} eq 'roboduck' ? 'irc.freenode.net' : 'irc.perl.org';
nickname defined $ENV{ROBODUCK_NICKNAME} ? $ENV{ROBODUCK_NICKNAME} : $ENV{USER} eq 'roboduck' ? 'RoboDuck' : 'RoboDuckDev';
channels '#duckduckgo';

plugins
  DuckDuckGo => "RoboDuck::Plugin::DuckDuckGo",
  WolframAlpha => "RoboDuck::Plugin::WolframAlpha",
  Links => "RoboDuck::Plugin::Links",
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
        when (/^\?/) {
            $self->privmsg( $channel => "$nick: ?" );
        }
    }
};

1;
__END__
