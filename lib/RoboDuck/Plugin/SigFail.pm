package RoboDuck::Plugin::SigFail;
use Moose;
use MooseX::NonMoose;
extends qw( POE::Component::IRC::Plugin::SigFail );

around __make_sigfail_messages => sub { 
    my $next = shift; 
    my $output = $next->(@_); 
    $_ =~ s/google/Duck/i for @$output; 
    return $output; 
};
1;
__END__
