#!/usr/bin/perl
#
# [Description]
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Yet another IRC bot
#
# Automatic ops, welcome messages, statistics, log and...
# uhm some kinda fun :)
# It hopefully grows to somethin' like a KI
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# [Author]
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Programmed by Bastian Ballmann 
# E-Mail: Crazydj@chaostal.de
# Web: http://www.geektown.de
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# [Todo]
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# -> Answers should be catagorized more
# -> The bot should remember if he likes one or not
# -> The bot should react on bad words and change behavior
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# Last update: 18.06.2005
#
# Remember... There is no spoon. And take the red pill!


###[ Loading modules ]###

use Net::IRC;
use XML::Simple;
use strict;


###[ Config ]###

my $cfgfile = "/etc/ircbot/config.xml";
my $cfg = read_cfg();
my $speech = read_speechdb();


###[ MAIN PART ]###

# Stat vars
my (%fragen,%grinsen,%heulen,%schimpfen);

# IRC object
my $irc = new Net::IRC;

# Shall we log the text?
my $log = 0;
my $logfile = "";

# Array to store possible answers
my @answer;

# Array to store notes
my @notes;

# Used nick
my $nick = 0;

# Connect to IRC server
print "Connecting to " . $cfg->{'irc'}->{'server'} . "\n";
my $first_nick;

if(ref($cfg->{'ident'}->{'nicks'}->{'item'}))
{
    $first_nick = $cfg->{'ident'}->{'nicks'}->{'item'}->[0];
}
else
{
    $first_nick = $cfg->{'ídent'}->{'nicks'}->{'item'};
}

my $conn = $irc->newconn(Nick => $first_nick,
			 Server => $cfg->{'irc'}->{'server'},
			 Port => $cfg->{'irc'}->{'port'},
			 Ircname => $cfg->{'ident'}->{'name'},
			 Username => $cfg->{'ident'}->{'user'}) or die "Cannot connect!\n";



###[ Event handler ]###

# Join channel after connect
sub on_connect
{
    # Fork a child process for random answers from time to time
    plappermaul($_[0]);

    print "Joining channel $cfg->{'irc'}->{'channel'}\n";
    $_[0]->join($cfg->{'irc'}->{'channel'});
}


# Rejoin on being kicked
sub on_kick { map { $_[0]->join($cfg->{'irc'}->{'channel'}) if $_[1]->{'to'}[0] eq $_ } @{$cfg->{'ident'}->{'nicks'}->{'item'}}; }


# React on taken nick name
sub on_nick_taken { $_[0]->nick($cfg->{'ident'}->{'nicks'}->{'item'}[$nick++]); }


# Give op and / or print welcome message on join
sub on_join
{
    my ($self,$event) = @_;

    my $hosts = $cfg->{'users'}->{'masters'}->{lc($event->nick)}->{'host'};

    if(ref($hosts))
    {
	foreach my $host (@{$hosts})
	{
	    if($event->host =~ /$host/)
	    {
		$self->mode($cfg->{'irc'}->{'channel'},'+o',$event->nick);
	    }
	}
    }
    else
    {
	if($event->host =~ /$hosts/)
	{
	    $self->mode($cfg->{'irc'}->{'channel'},'+o',$event->nick);
	}
    }

    if($cfg->{'welcome'}->{lc($event->nick)})
    {
	my $msgs = $cfg->{'welcome'}->{lc($event->nick)}->{'msg'};
	my $msg;

	if(ref($msgs))
	{
	    $msg = $msgs->[int(rand(scalar(@{$cfg->{'welcome'}->{lc($event->nick)}->{'msg'}})))];
	}
	else
	{
	    $msg = $msgs;
	}

	$self->privmsg($cfg->{'irc'}->{'channel'},$msg);
    }
}


# Process commands
sub on_msg
{
    my ($self,$event) = @_;
    my $text = $event->{args}[0];
    my $root = 0;

    # Lookup root user
    if(lc($event->nick) eq $cfg->{'users'}->{'root'}->{'nick'})
    {
	my $hosts = $cfg->{'users'}->{'masters'}->{lc($event->nick)}->{'host'};

	if(ref($hosts))
	{
	    foreach my $host (@{$hosts})
	    {
		$root = 1 if $event->host =~ /$host/;
	    }
	}
	else
	{
	    $root = 1 if $event->host =~ /$hosts/;
	}
    }

    # Only the root is allowed to send us commands!    
    if($root)
    {
	# Say something
	if($text =~ /^say\s(.*)/)
	{
	    $self->privmsg($cfg->{'irc'}->{'channel'},$1);
	}

	# Kick someone in the ass
	elsif($text =~ /^kick\s(.*)/)
	{
	    $self->kick($cfg->{'irc'}->{'channel'},$1);
	}

	# Add / delete a new master
	elsif($text =~ /^addmaster\s(.*)/)
	{
	    push @{$cfg->{'users'}->{'masters'}->{$1}->{'host'}},$event->host;
	}
	elsif($text =~ /^delmaster\s(.*)/)
	{
	    delete $cfg->{'users'}->{'masters'}->{$1};
	}

	# Add / delete / list a fun messge
	elsif($text =~ /^addfunmsg\s(.*)/)
	{
	    push @{$speech->{'direct'}->{'else'}}, $1;
	}
	elsif($text =~ /^delfunmsg\s(.*)/)
	{
	    delete $speech->{'direct'}->{'else'}->[$1];
	}
	elsif($text =~ /^listfunmsg/)
	{
	    map { $self->privmsg($event->nick,$_); sleep 1 } @{$speech->{'direct'}->{'else'}};
	}

	# Add / delete a fun nick
	elsif($text =~ /^addfunnick\s(.*)/)
	{
	    $cfg->{'users'}->{'fun'}->{$1} = 1;
	}
	elsif($text =~ /^delfunnick\s(.*)/)
	{
	    delete $cfg->{'users'}->{'fun'}->{$1};
	}

	# Add / delete a bad word
	elsif($text =~ /^addbadword\s(.*)/)
	{
	    $cfg->{'badwords'}->{$1} = 0;
	}
	elsif($text =~ /^delbadword\s(.*)/)
	{
	    delete $cfg->{'badwords'}->{$1};
	}

	# Say a text in a loop
	elsif($text =~ /^loop\s(\d+)\s(.*)/)
	{
	    for(my $i=0; $i<$1; $i++)
	    {
		$self->privmsg($cfg->{'irc'}->{'channel'},$2);
		sleep 1;
	    }
	}

	# Change your nick
	elsif($text =~ /^nick\s(.*)/)
	{
	    $self->nick($1);
	}

	# Take a note
	elsif($text =~ /^addnote\s(.*)/)
	{
	    push @notes, $1;
	}

	# List all notes
	elsif($text =~ /^listnotes/)
	{
	    for(@notes)
	    {
		$self->privmsg($event->nick,$_);
		sleep 1;
	    }
	}

	# Encrypt something to rot13
	elsif($text =~ /^encrypt\s(.*)/)
	{
	    my $string = $1;
	    $string =~ tr/A-Z a-z/N-ZA-M n-za-m/;
	    $self->privmsg($cfg->{'irc'}->{'channel'},$string);	    
	}

	# Decrypt something to rot13
	elsif($text =~ /^decrypt\s(.*)/)
	{
	    my $string = $1;
	    $string =~ tr/N-ZA-M n-za-m/A-Z a-z/;
	    $self->privmsg($cfg->{'irc'}->{'channel'},$string);	    
	}

	# Start / stop logging
	elsif($text =~ /^log\s(.*)/)
	{
	    $log = 1;
	    $logfile = $1;
	    open(LOG,">$logfile");
	}
	elsif($text =~ /^endlog/)
	{
	    $log = 0;
	    $logfile = "";
	    close(LOG);
	}

	# Reread config file
	elsif($text =~ /^reconfigure/)
	{
	    $cfg = read_cfg();
	}

	# Reread speech database
	elsif($text =~ /^reload/)
	{
	    $speech = read_speechdb();
	}

	# Print status
	elsif($text =~ /^status/)
	{
	    $self->privmsg($event->nick,"Masters:");
	    while(my ($nick, $hosts) = each %{$cfg->{'users'}->{'masters'}})
	    {
		if(ref($hosts->{'host'}))
		{
		    $self->privmsg($event->nick,"$nick from following hosts:");
		    
		    foreach my $host (@{$hosts->{'host'}})
		    {
			$self->privmsg($event->nick,$host);
			sleep 1;
		    }
		}
		else
		{
		    $self->privmsg($event->nick,"$nick from $hosts->{'host'}");
		}

		sleep 1;
	    }

	    $self->privmsg($event->nick,"Fun messages:");
	    map { $self->privmsg($event->nick,$_); sleep 1 } @{$speech->{'direct'}->{'else'}};

	    $self->privmsg($event->nick,"Fun nicks:");
	    while(my ($nick,$bla) = each %{$cfg->{'users'}->{'fun'}})
	    {
		$self->privmsg($event->nick,$nick); 
		sleep 1;
	    }

	    if($log)
	    {
		$self->privmsg($event->nick,"Logging is active");
		$self->privmsg($event->nick,"Logfile: $logfile");
	    }
	    else
	    {
		$self->privmsg($event->nick,"Logging is disabled");
	    }
	}

	# Print statistics
	elsif($text =~ /^stats\s*$/)
	{
	    $self->privmsg($event->nick,"Schimpfwoerter:");
	    while(my ($wort, $count) = each %{$cfg->{'badwords'}})
	    {
		$self->privmsg($event->nick,"$wort: $count");
		sleep 1;
	    }

	    $self->privmsg($event->nick,"Wer hat am meisten geschimpft?");	    
	    while(my ($nick, $count) = each %schimpfen)
	    {
		$self->privmsg($event->nick,"$nick: $count");
		sleep 1;
	    }

	    $self->privmsg($event->nick,"Wer hat am meisten gelacht?");	    
	    while(my ($nick, $count) = each %grinsen)
	    {
		$self->privmsg($event->nick,"$nick: $count");
		sleep 1;
	    }

	    $self->privmsg($event->nick,"Wer hat am meisten geheult?");	    
	    while(my ($nick, $count) = each %heulen)
	    {
		$self->privmsg($event->nick,"$nick: $count");
		sleep 1;
	    }

	    $self->privmsg($event->nick,"Wer hat am meisten Fragen gestellt?");	    
	    while(my ($nick, $count) = each %fragen)
	    {
		$self->privmsg($event->nick,"$nick: $count");
		sleep 1;
	    }
	}

	# Print usage
	elsif($text =~ /^help\s*$/)
	{
	    $self->privmsg($event->nick,"say <text>");
	    $self->privmsg($event->nick,"kick <nick>");
	    sleep 1;
	    $self->privmsg($event->nick,"addmaster <nick>");
	    $self->privmsg($event->nick,"delmaster <nick>");
	    sleep 1;
	    $self->privmsg($event->nick,"addfunmsg <msg>");
	    $self->privmsg($event->nick,"delfunmsg <number>");
	    sleep 1;
	    $self->privmsg($event->nick,"listfunmsg");
	    $self->privmsg($event->nick,"addfunnick <nick>");
	    sleep 1;
	    $self->privmsg($event->nick,"delfunnick <nick>");
	    $self->privmsg($event->nick,"addbadword <word>");
	    sleep 1;
	    $self->privmsg($event->nick,"delbadword <word>");
	    $self->privmsg($event->nick,"log <file>");
	    sleep 1;
	    $self->privmsg($event->nick,"endlog");
	    $self->privmsg($event->nick,"loop <number> <text>");
	    sleep 1;
	    $self->privmsg($event->nick,"nick <new_nick>");
	    $self->privmsg($event->nick,"decrypt <text>");
	    sleep 1;
	    $self->privmsg($event->nick,"encrypt <text>");
	    $self->privmsg($event->nick,"addnote <text>");
	    sleep 2;
	    $self->privmsg($event->nick,"listnotes");
	    $self->privmsg($event->nick,"reload");
	    sleep 2;	    
	    $self->privmsg($event->nick,"reconfigure");
	    $self->privmsg($event->nick,"status");
	    sleep 2;
	    $self->privmsg($event->nick,"stats");
	    $self->privmsg($event->nick,"login <password>");
	}
    }
    else
    {
	# The root user can login from an unkown host
	if( ($root) && ($text =~ /^login\s(.*)/) )
	{
	    $cfg->{'users'}->{'masters'}->{$cfg->{'users'}->{'root'}->{'nick'}} = $event->host if $1 eq $cfg->{'users'}->{'root'}->{'password'};
	}

	# Unauthorized user
	else
	{
	    $self->privmsg($event->nick,"Follow the white rabbit");
	}
    }
}


# React on public messages
# Talk to funnicks, be brave and say something if someone is leavin the channel or
# says something like re or brb, maybe log the stuff and collect some statistical data
sub on_public
{
    my ($self,$event) = @_;
    my $text = $event->{args}[0];
    my $answer;
    my $heard_nick = 0;
    @answer = ();

    foreach my $nick (@{$cfg->{'ident'}->{'nicks'}->{'item'}})
    {
	$heard_nick = 1 if $text =~ /$nick/ig;
    }


    ###[ Direct conversation ]###

    # Heard one of my nicks
    if($heard_nick)
    {	
	# Was it a welcome message?
	if( ($text =~ /guten morgen/ig) ||
	    ($text =~ /^morgen$/ig) ||
	    ($text =~ /^morjen$/ig) ||
	    ($text =~ /^morgaehn$/ig) ||
	    ($text =~ /^guten tag$/ig) ||
	    ($text =~ /tach/ig) ||
	    ($text =~ /hallo/ig) ||
	    ($text =~ /moin/ig) ||
	    ($text =~ /^mahlzeit\s*$/ig) ||
	    ($text =~ /^n?abend/ig) ||
	    ($text =~ /^guten abend/ig) )
	{
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	    $hour = "0" . $hour if $hour < 10;
	    $min = "0" . $min if $min < 10;
	    
	    # in the morning
	    if( ($text =~ /guten morgen/ig) ||
		($text =~ /^morgaehn$/ig) ||
		($text =~ /^morgen$/ig) ||
		($text =~ /^morjen$/ig) )
	    {
		# it "normal" morning time
		if( ($hour >= 7) && ($hour <= 10) )
		{
		    @answer = ("guten morgen",
			       "morjen",
			       "moin",
			       "morgen",
			       "morgaehn",
			       "*gaehn*");
		}
		
		# it's a little bit late today :)
		else
		{
		    @answer = ("morgen? es ist $hour:$min");
		}
	    }
	    
	    # midday
	    elsif( ($text =~ /guten tag/ig) ||
		   ($text =~ /tach/ig) ||
		   ($text =~ /^mahlzeit$/ig) )
	    {
		# it's "normal" midday
		if( ($hour >= 10) && ($hour <= 17) )
		{
		    @answer = ("tag",
			       "tach",
			       "moin",
			       "hi",
			       "hallo",
			       "mahlzeit");
		}
		else
		{
		    @answer = ("es ist $hour:$min... o.0");
		}
	    }
	    
	    # in the evening
	    elsif( ($text =~ /^n?abend$/ig) ||
		   ($text =~ /guten abend/ig) )
	    {
		if( ($hour >= 17) && ($hour <= 23) )
		{
		    @answer = ("nabend",
			       "moin",
			       "hi",
			       "hallo");
		}
		else
		{
		    @answer = ("nabend? es ist $hour:$min o.0");
		}
	    }
		
	    # in general
	    elsif( ($text =~ /hallo/ig) ||
		   ($text =~ /moin/ig) )
	    {
		@answer = ("hi",
			   "hallo",
			   "moin",
			   "*ruelps*");
	    }
	}
	else
	{
	    # It's a fun user speakin
	    if($cfg->{'users'}->{'fun'}->{lc($event->nick)})
	    {
		# Was it a question?
		if($text =~ /\?/)
		{		
		    # question about time
		    if( ($text =~ /(wieviel)|(was sagt die) uhr(\w*\s*)*/ig) ||
			($text =~ /wie spaet(\w*\s*)*/ig) ||
			($text =~ /\s*timer\?\s*/ig) ||
			($text =~ /\s*uhrzeit\?\s*/ig) )
		    {
			my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#			$hour = "0" . $hour if $hour < 10;
#			$min = "0" . $min if $min < 10;
#			push @answer, "es ist $hour:$min MET";

			if($hour > 19)
			{
			    $hour -= 19;
			}
			else
			{
			    $hour += 5;
			}

			if($min > 43)
			{
			    $min -= 17;
			}
			else
			{
			    $min += 17;
			}

			$hour = "0" . $hour if $hour < 10;
			$min = "0" . $min if $min < 10;
			push @answer, "es ist $hour:$min TOLD";
		    }
		    
		    # question about date
		    elsif( ($text =~ /welche[rn] tag(\w*\s*)*/ig) ||
			   ($text =~ /der wie\s?vielte ist heute/ig) ||
			   ($text =~ /\s*datum\?\s*/ig) )
		    {
			my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
			$wday--;
			my @wochentag = ("montag",
					 "dienstag",
					 "mittwoch",
					 "donnerstag",
					 "freitag",
					 "samstag",
					 "sonntag");
			$year += 1900;
			$mon++;
			$mon = "0" . $mon if $mon < 10;
			$mday = "0" . $mday if $mday < 10;
#			push @answer, "heute ist $wochentag[$wday], der $mday.$mon.$year";
			push @answer, `ddate`;
		    }
		    
		    # Normal question
		    else
		    {
			search_answer($text, $speech->{'direct'}->{'question'});
		    }
		}
		
		# Statement
		else
		{
		    # Was it a command?
		    if( ($text =~ /mach sitz/ig) ||
			($text =~ /sitz\!/ig) ||
			($text =~ /aus\!/ig) ||
			($text =~ /gib pfoedchen/ig) ||
			($text =~ /fass/ig) ||
			($text =~ /such\!/ig) ||
			($text =~ /komm her/ig) ||
			($text =~ /zieh dich aus/ig) ||
			($text =~ /sei lieb/ig) ||
			($text =~ /sei brav/ig) )
		    {
			# Was it a command by the obey user?
			if($event->nick eq $cfg->{'users'}->{'obey'})
			{
			    if(($text =~ /mach sitz/ig) || ($text =~ /sitz\!/ig))
			    {
				@answer = ("*macht_sitz*");
			    }
			    elsif($text =~ /sitz\!/ig)
			    {
				@answer = ("*jaul*");
			    }
			    elsif($text =~ /gib pfoedchen/ig)
			    {
				@answer = ("*gibt pfoedchen*");
			    }
			    elsif($text =~ /fass/ig)
			    {
				@answer = ("*knurr*");
			    }
			    elsif($text =~ /such\!/ig)
			    {
				@answer = ("o.o");
			    }
			    elsif($text =~ /komm her/ig)
			    {
				@answer = ("*jaul*");
			    }
			    elsif( ($text =~ /sei lieb/ig) ||
				   ($text =~ /sei brav/ig) )
			    {
				@answer = ("*jaul*",
					   "*unschuldig_kuck*",
					   "*g*",
					   "hrrhrr",
					   "klar! *pfeif*");
			    }
			    elsif($text =~ /zieh dich aus/ig)
			    {
				@answer = ("*strip* *tabledance*");
			    }
			}
			else
			{
			    @answer = ("*knurr*",
				       "*ans_bein_pinkel*",
				       "*in_den_schuh_beiss*",
				       "pueh",
				       "hihi",
				       "o.0",
				       "DROP");
			}
		    }	    
		
		    # Normal Statement
		    else
		    {
			search_answer($text, $speech->{'direct'}->{'statement'});
		    }
		}
	    }
	}
    }


    ###[ Indirect conversation ]###

    else
    {
	# was the message send directly to another user?
	# than ignore it
	unless($text =~ /^(.*)\:|\,\.\;\s+/)
	{   
	    # Question
	    if($text =~ /\?/)
	    {
		search_answer($text, $speech->{'indirect'}->{'question'});
	    }
	    
	    # Statement
	    else
	    {
		search_answer($text, $speech->{'indirect'}->{'statement'});
	    }
	}
    }

    # Give the answer
    my $msg = $answer[int(rand(scalar(@answer)))] if scalar(@answer) > 0;

    if($msg ne "")
    {
	$answer = $event->nick . ": $msg";
	my $wait = int(rand(5));
	$wait = 2 if $wait < 2;
	sleep $wait;
	$self->privmsg($cfg->{'irc'}->{'channel'},$answer);
    }

    # Log the shit
    print LOG $event->nick . ": $text\n" if $log;

    # Collect statistical data
    while(my ($wort,$count) = each %{$cfg->{'badwords'}})
    {
	if($text =~ /$wort/ig)
	{
	    $cfg->{'badwords'}->{$wort}++;
	    $schimpfen{$event->nick}++;
	}
    }

    if($text =~ /\?\s*$/)
    {
	$fragen{$event->nick}++;
    }

    if( ($text =~ /[\;\:]\-?[\)dp]/ig) || ($text =~ /\^\^/ig) || ($text =~ /\*g+\*/ig) || ($text =~ /\*?lol\*?/ig) )
    {
	$grinsen{$event->nick}++;
    }

    if($text =~ /\:\~?\-?\(/)
    {
	$heulen{$event->nick}++;
    }
}

# Register event handler
$conn->add_handler('join', \&on_join);
$conn->add_handler('kick', \&on_kick);
$conn->add_handler('msg', \&on_msg);
$conn->add_handler('public', \&on_public);
$conn->add_global_handler(376, \&on_connect);
$conn->add_global_handler(433, \&on_nick_taken);

# Let's have some fun :)
$irc->start;



###[ Subroutines ]###

# Search recursive through possible cases and return
# a list of possible answers
# Parameter: text_to_scan, cases_to_check
sub search_answer
{
    my ($text, $input) = @_;

    # No case found?
    return unless $input->{'case'};

    # More than one case
    if(ref($input->{'case'}) eq "ARRAY")
    {
	# Check each case
	foreach my $case (@{$input->{'case'}})
	{
	    scan_text($text, $case);
	}
    }

    # Only one possible case
    else
    {
	scan_text($text, $input->{'case'});
    }

    # text not in case. use the default
    if( (scalar(@answer) < 1) && ($input->{'default'}) )
    {
	if(ref($input->{'default'}->{'output'}->{'text'}) eq "ARRAY")
	{
	    @answer = @{$input->{'default'}->{'output'}->{'text'}};
	}
	else
	{
	    push @answer, $input->{'default'}->{'output'}->{'text'};
	}
    }
}


# Check if text and input match
sub scan_text
{
    my ($text, $case) = @_;

    # More than one possible input text
    if(ref($case->{'input'}->{'text'}) eq "ARRAY")
    {
	# Check each input text
	foreach my $msg (@{$case->{'input'}->{'text'}})
	{
	    # Does it fit?
	    if($text =~ /$msg/ig)
	    {
		# Found more cases to check?
		if($case->{'case'})
		{
		    search_answer($text, $case);
		}
		
		# Found possible answer(s)
		else
		{
		    if(ref($case->{'output'}->{'text'}) eq "ARRAY")
		    {
			@answer = @{$case->{'output'}->{'text'}};
		    }
		    else
		    {
			push @answer, $case->{'output'}->{'text'};
		    }
		    
		    last;
		}
	    }
	}
    }

    # Only one possible input text
    else
    {
	# Does it fit?
	if($text =~ /$case->{'input'}->{'text'}/ig)
	{
	    # Found more cases to check?
	    if($case->{'case'})
	    {
		search_answer($text, $case);
	    }
	    
	    # Found possible answer(s)
	    else
	    {
		if(ref($case->{'output'}->{'text'}) eq "ARRAY")
		{
		    @answer = @{$case->{'output'}->{'text'}};
		}
		else
		{
		    push @answer, $case->{'output'}->{'text'};
		}
	    }
	}
    }
}

# Read an XML config file
sub read_cfg { return XMLin($cfgfile) or die "Cannot read config file $cfgfile!\n$!\n"; }

# Read an XML speech database
sub read_speechdb { return XMLin($cfg->{'speech'}) or die "Cannot read speech database $cfg->{'speech'}!\n$!\n"; }

# Fork a child process for random answers from time to time
sub plappermaul
{    
    my $self = shift;
    my $pid = fork();
    return if $pid;
       
    my @answer = ('Ein Schueler erreichte einen breiten Fluss, und als er seinen Meister am entfernten Ufer sah, rief er: "Meister, wie komme ich auf die andere Seite?" "Narr!", rief der Meister, "Du bist schon auf der anderen Seite."',
	  '"Suche nicht die Wahrheit, sondern hoer auf, dich Vorstellungen hinzugeben." "Wenn du an Gott glaubst, irrst du dich. Wenn du nicht an Gott glaubst irrst du dich." (zen-spruch)',
	  'Das Leben ist eine Anschauung. Und nichts ist wie es scheint.',
	  'Welche Farbe hat der Wind? (zen-spruch)',
	  'Wenn Du Dich auf einem Weg befindest, gehst Du in die falsche Richtung.',
	  'Widerstehe der Versuchung, die Welt zu nehmen und zu schuetteln. Schuettele dich stattdessen selbst.',
	  'Versuch nicht die Speisekarte zu essen.',
	  'Das Leben ist zu wichtig, um ernst genommen zu werden.',
	  'Benutze den ganzen Mist des Lebens, um damit eine Blume zu duengen.',
	  'Was ist Glauben? Wenn Du nicht an die Schwerkraft glauben wuerdest, koenntest Du dann fliegen?',
	  'Menschen wollen die Welt veraendern. Was fuer Narren! Aendere Dich selbst und die Welt wird sich von selbst veraendern.',
	  'Es ist nichts falsch an Religion, solange Gott nicht im Weg steht.',
	  'Alles das Gleiche, alles verschieden. (zen-spruch)',
	  'Ein Hund, der seinen eigenen Schwanz jagt, ist nicht verrueckter als ein Mensch, der nach Erleuchtung sucht.',
	  'Das Glueck liegt im Geist.',
	  'Du siehst einen grossen Felsen. Ist er innerhalb oder ausserhalb deines Geistes?',
	  'Das Hindernis ist der Weg.',
	  'Die Weisheit der Welt ist nicht mehr als eine verfeinerte Form von Dummheit.',
	  'Einem ruhigen Geist gibt sich das ganze Universum preis.',
	  'Wenn Du lange in einen Abgrund blickst, blickt der Abgrund auch in Dich hinein. - Nietzsche',
	  'Die Leute reden von Geist und Materie. Ich weiss wo der Geist ist, aber wo ist Materie?',
	  'Wenn Du Aufregung suchst, setze Deine Unterhose in Flammen.',
	  'Das Letzte, was die meisten kennen wollen, sind sie selbst.',
	  'Vernunft ist ein gutes Werkzeug. Ebenso wie ein Hammer. Versuche ein Haus zu bauen mit nichts als einen Hammer.',
	  'Alle Fundamentalisten, ob Theisten oder Rationalisten, bauen sich ein Gefaengnis und laden dich ein, es mit ihnen zu teilen.',
	  'Alle Religionen verschleiern mit besten Absichten die Wahrheit.',
	  'Der, der Nichts haelt, ist formlos.',
	  'Wer ist der Seher, der sieht? Wer ist der Denker, der denkt?',
	  'Suche nicht nach Antworten. Fragen sind viel spannender.',
	  'Penner!',
          'Arschloch!',
	  'Er wars!',
	  'AUAAAAAAAAAAAA',
          'SCHILY',
	  'DIE sind hinter mir her! o.o',
          'Leck mich!',
          'SCHEISSE!',
          'Wichser!',
          'mmm',
          'Verpiss Dich!',
          'Wo bin ich?',
          'Zahnbuerste?',
          'Fick Dich!',
          'FUCKUP',
          'Pappnase!',
          'Grossmaul!',
          'Du Idiot!',
          'Narr!',
          'Hoerst Du das auch?',
          'Du Flachzange, Du!',
          'wer war das?!',
          'Eine Null ist eine Eins. Eine Eins ist eine Null.',
	  'Kampf den Windmuehlen!',
	  'Nieder mit der Schwerkaft!',
          'Wat? Wer bist Du denn?',
          'Ha...Hallo?',
          '*hatschi*',
          '*hust*',
          '*ruelps*',
          '*in_der_nase_popel*',
          'hehe',
          '*schlapp_lach*',
          'Wer an Wahrheit glaubt, scheint falsches zu wissen.',
          'Du wurdest gelehrt das Weltall sei ein unendlich herrlicher Raum. Gewaltig und majestaetisch. Du weisst gar nichts.',
	  'Alles was Du siehst ist unwahr.',
          'tammtamm',
          '*summ*',
          '*gaehn*',
          '*seufts*');

    while(1)
    {
	my $wait = int(rand(30)) * 60;
	$wait = $wait * int(rand(3));
	$wait = 3600 if $wait == 0;
	sleep $wait; 
	my $msg = $answer[int(rand(scalar(@answer)))] if scalar(@answer) > 0;
	$self->privmsg($cfg->{'irc'}->{'channel'},$msg);
    }
}

###[ Ok. I think that's the end phreak :) ]###
