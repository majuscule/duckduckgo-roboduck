package RoboDuck::Plugin::CommitHook;
use 5.10.0;
use Moses::Plugin;
use POE::Component::WWW::Shorten;
use POE::Component::FastCGI;
use JSON::XS;

sub S_connected {
    my $self = shift;
    $self->fcgi;
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
};

sub received_git_commit {
    my ( $self, $info ) = @_;

    my ( $pusher, $repo, $commits, $ref ) = @{$info}{ 'pusher', 'repository', 'commits', 'ref' };
    my $repo_base_url = $repo->{url};
    my $repo_url = $repo_base_url;
    if ($ref =~ m|^refs/heads/|) {
        $ref =~ s{^refs/heads/}{};
        $repo_url = "$repo_base_url/tree/$ref" unless $ref eq "master";
    }

    my $repo_name = $repo->{name};
    my $pusher_name = $pusher->{name};
    my $commit_count = scalar @{$commits};
    my $plural = ($commit_count == 1) ? '' : 's';
    my $link_and_ref = ($repo_url eq $repo_base_url) ? "$repo_url" : "$repo_name/$ref ($repo_url)";

    my $initial_msg = "[git] $pusher_name pushed $commit_count commit$plural to $link_and_ref";

    for (@{$self->{bot}->get_channels}) {
        $self->privmsg( $_ => $initial_msg ) if $commit_count;
        $self->privmsg( $_ => "[git] $pusher_name tagged $repo_url \"$1\"" ) if !$commit_count && $ref =~ qr|^refs/tags/(.+)$|;
    }

    for (@{$commits}) {
        my ( $id, $url, $author, $msg ) = @{$_}{ 'id', 'url', 'author', 'message' };
        my $short_id = substr $id, 0, 7;
        my $author_name = $author->{name};

        my $commit_message = "[$short_id] $author_name - $msg SHORT_URL";
        $self->shorten->shorten({
                url => $url,
                event => 'announce_shortened_url',
                session => $self->{bot}->get_session_id,
                _message => $commit_message
            });
    }
}


1;
__END__
