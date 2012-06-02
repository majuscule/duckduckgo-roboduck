package RoboDuck::Plugin::WubWubWUb;
use Moses::Plugin;

sub new {
	my $package = shift; 
	my $args = shift;
	my $self = {
		threshold => 0.5, #Threshold to limit unnecessary wubs.
		period    => 30,  #A time period to rate limit wubs.
		last_wub  => 0,
		max_wubs =>  20,  #maximum amount of wubs in one message
		min_wubs =>  5,   #minimum amount of wubs in one message.
		wub_str  => "WUB", #wubstr
	};
	$self->{threshold} ||= $args->{threshold};
	$self->{threshold} = 0.5 if $self->{threshold} >= 1 or $self->{threshold} <= 0; #sanity check lol.
	$self->{period}    ||= $args->{period};
	$self->{period}    = 30  if $self->{period} <= 0;	 				#same
	$self->{max_wubs}  ||= $args->{max_wubs};
	$self->{max_wubs}  = 20  if $self->{max_wubs} <= 0; 					#same, chap.
	$self->{min_wubs}  ||= $args->{min_wubs};
	$self->{min_wubs}  = 5 if $self->{min_wubs} <= 0;					#no sense in having 0 as minimum amirite
	$self->{min_wubs}  = $self->{max_wubs} - 1 if $self->{min_wubs} > $self->{max_wubs};	#don't want minimum > maximum
	$self->{max_wubs}  = $self->{min_wubs} + 5 if $self->{min_wubs} > $self->{max_wubs};	#same except different.
	$self->{wub_str}   ||= $args->{wub_str};
	return bless $self, $package;
}

sub S_public {
	my($self, $irc) = splice @_, 0, 2;
	my $channel = ${ $_[0] }->[0];
	my $cur_time = time;
	my $old_time = $self->{last_wub};
	my $chance = rand;
	my $retval = PCI_EAT_NONE;
	if($cur_time - $old_time > $self->{period} &&
	   $chance > $self->{threshold}) {
			my $repetitions = (int rand($self->{max_wubs}-$self->{min_wubs})+$self->{min_wubs});
			my $wubstr = $self->{wub_str}x$repetitions;
			$irc->yield(privmsg => $channel => $wubstr);
			$self->{last_wub} = time;
			$retval = PCI_EAT_PLUGIN;
	} 
	
	return $retval;
}
			
1;
