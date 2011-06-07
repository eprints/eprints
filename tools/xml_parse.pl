#!/usr/bin/perl -w 

my $file = join( '', <> );

while( $file ne "" )
{
	if( $file =~ s/^([^<]+)//s )
	{
		text( $1 );
		next;
	}

	if( $file =~ s/^<\?(.*)\?>//s )
	{
		pdir( $1 ); 
		next;
	}
	if( $file =~ s/^<!--(.*)-->//s )
	{
		comment( $1 );
		next;
	}

	if( $file =~ s/<(([^>'"]*|"[^"]*"|'[^']*')+)>//s )
	{
		tag( $1 );
		next;
	}

	print "DAMN:$file\n";
	exit;
}


sub text
{
	my( $val ) = @_;
	$val = "\U$val";

	print $val;
}
		
sub pdir
{
	print "<?".$_[0]."?>";
}

sub comment
{
	print "<!--".$_[0]."-->";
}

sub tag
{
	my $tag = $_[0];
	if( $tag =~ m/^\// )
	{
		print "<$tag>";
		return;
	}	

	print "<";
	$tag =~ s/^([^\s>]+)//;
	print $1;
	while( $tag ne "" )
	{
		next if( $tag=~s/^\s// );
		if( $tag=~s/^([^\s=]+)\s*=\s*'([^']+)'// )
		{
			sattr( $1, $2 );
			next;
		}
		if( $tag=~s/^([^\s=]+)\s*=\s*"([^"]+)"// )
		{
			dattr( $1, $2 );
			next;
		}
		if( $tag=~s/^\/// )
		{
			print "/";
			next;
		}
		print "DAMN! --($tag)--\n";
		exit;
	}
	print ">";
}

sub sattr
{
	my( $name, $val ) = @_;

	$val = "\U$val";

	print " ".$name."='(".$val.")'";
}
sub dattr
{
	my( $name, $val ) = @_;

	$val = "\U$val";

	print " ".$name.'="('.$val.')"';
}
