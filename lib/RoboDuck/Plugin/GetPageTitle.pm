package RoboDuck::Plugin::GetPageTitle;
use Moose;

extends 'POE::Component::IRC::Plugin::WWW::GetPageTitle';

around _make_response_message => sub {
    my ( $orig, $self, $in_ref ) = @_;

    my $ret = $self->$orig($in_ref);
    return $ret unless $$ret[0] =~ /^\[.+\]\sN\/A$/;
    '';
};

1;
__END__
