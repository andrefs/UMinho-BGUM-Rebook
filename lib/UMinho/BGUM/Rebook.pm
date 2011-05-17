package UMinho::BGUM::Rebook;

use Moose;
use Config::Any;
use Data::Dumper;
use WWW::Scripter::Plugin::JavaScript;
use XML::XPath;
use Email::Send;
use Email::Send::Gmail;
use Email::Simple::Creator;
use DateTime;
use Carp;
#use Net::Twitter:Lite;

use utf8;
binmode(STDERR,":utf8");

our $VERSION = '0.01';

has 'config' => (
	is => 'rw',
);

has 'scripter' => (
	is => 'rw',
);

sub load_config{
	my ($self,$rcfile) = @_;
	my $cfg = Config::Any->load_files({files => [$rcfile], flatten_to_hash => 1, use_ext => 1});
	my $config = $cfg->{$rcfile} or die "Could not read configuration file $rcfile.";
	$self->config($config);
	return;
}
	
sub login{
	my $self = shift;
    my $w = WWW::Scripter->new(noproxy => [0]);
    $w->use_plugin('JavaScript');
    $w->get('http://aleph.sdum.uminho.pt');             # Homepage
    $w->follow_link(url_regex => qr/login-session/);    # Login link
    $w->submit_form(                                    # Fill login form and submit
        form_name => 'form1',
        fields => {
            bor_id => $self->config->{AUTH}{sdum_user},
            bor_verification => $self->config->{AUTH}{sdum_pass},
        }   
    );  
    $self->scripter($w); 
	return;
}

sub status{
	my $self = shift;
    $self->scripter->follow_link(url_regex => qr/bor-info/);         # Area Pessoal
    $self->scripter->follow_link(url_regex => qr/bor-loan/);         # Emprestimos

    my $regsep = qr{<!-- filename: bor-loan-body -->|<!-- filename: bor-loan-tail -->};
    my @tr = split /\s*$regsep\s*/,$self->scripter->content;
    shift @tr; pop @tr;
	my $books = [];
    for(@tr){
        s!<br>!<br />!g;
        my $xp = XML::XPath->new( xml => $_ );
        my $nodeset = $xp->find('/tr/td');
        my @nodes = $nodeset->get_nodelist;
		push @$books, {title => $nodes[1]->string_value, date => $nodes[2]->string_value};
    }
	return $books;
}

sub status2str{
	my $books = shift;
	my $res;
	$res.= "\t[$_->{date}] $_->{title}\n" foreach(@$books);
	return $res;
}


	

sub renew{
	my $self = shift;
    $self->scripter->follow_link(url_regex => qr/bor-info/);         # Area Pessoal
    $self->scripter->follow_link(url_regex => qr/bor-loan/);         # Emprestimos
    $self->scripter->follow_link(url_regex => qr/bor-renew-all/);    # Renovar todos

    my $cont = $self->scripter->content;
	my ($code, $msg);
    if ($cont =~ qq{<span class="NormalRed">Exemplares n&atilde;o foram renovados com sucesso</span>}){
        $code = 1;
		$msg = 'Exemplares não foram renovados com sucesso.';
    }
    elsif( $cont =~ qq{<span class="NormalRed">Exemplares renovados</span>}){
        $code = 0;
		$msg = 'Exemplares renovados.';
    }   
    else {
        $cont =~ qr{<span class="NormalRed">(.*?)</span>};
        $code = 2;
		$msg = $1;
    }
	print STDERR "$msg\n";
	return { code => $code, message => $msg };

}

sub publish{
	my ($self,$exit) = @_;
	my $auth_opt = $self->config->{AUTH};
	# if(defined($auth_opt->{twitter_user})){
	# 	$self->publish_twitter($exit);
	# }
	if(defined($auth_opt->{gmail_user})){
		$self->publish_gmail($exit);
	}
}	

sub publish_gmail{
	my ($self,$exit) = @_;
	my $warn_level = $self->config->{WARN}->{level};
	$warn_level //= 'norenew';
	print STDERR "Warn level is set to '$warn_level'.\n";
	return if $warn_level =~ /never/;

	my $dt = DateTime->now;
	my ($msg, $subject) = ("Dear user,\n\n",'');
	my $email;

	if($exit->{code} == 0){
		$msg.= "Your books have been renewed successfully!\n\nHere's the list of your books and return dates:\n\n";
		$subject = '['.$dt->ymd('/').'] Rebook BGUM Successful!';
	}
	else {
		$msg.= "Your books have NOT been renewed because the script terminated with exit code $exit->{code}:\n\t$exit->{message}\n\nHere's the list of your books and return dates:\n\n";
		$subject = '['.$dt->ymd('/').'] Rebook BGUM Failed!';
	}
	
	my $books = $self->status;
	$msg.= status2str($books);


	if($warn_level =~ /always/ or ($warn_level =~ /failed/ and $exit->{code} != 0)){
		print STDERR "Sending email... ";
		my $email = Email::Simple->create(
		  header => [
		      From    => $self->config->{AUTH}->{gmail_user},
		      To      => $self->config->{PUBLISH}->{mail},
		      Subject => $subject,
		  ],
		  body => $msg,
		);

		my $sender = Email::Send->new(
		    {   mailer      => 'Gmail',
		        mailer_args => [
		            username => $self->config->{AUTH}->{gmail_user},
		            password => $self->config->{AUTH}->{gmail_pass},
		        ]
		    }
		);

		eval { $sender->send($email) };
		die "Error sending email: $@" if $@;
		print STDERR "DONE\n";
	}
	
	print STDERR "\nList of loans:\n", status2str($books);
}


no Moose;

__PACKAGE__->meta->make_immutable;

1; 
