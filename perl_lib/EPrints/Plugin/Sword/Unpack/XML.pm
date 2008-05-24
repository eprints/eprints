######################################################################
#
# EPrints::Plugin::Sword::Unpack::XML
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

######################################################################
#
# PURPOSE:
#
#	This is a pseudo-unpacker for XML files. It just verifies
#	that there is one file of MIME type 'text/xml' and returns.
#
# METHODS:
#
# export( $plugin, %opts )
#       The method called by DepositHandler. The %opts hash contains
#       information on which files to process.
#
######################################################################

package EPrints::Plugin::Sword::Unpack::XML;

use Unicode::String qw( utf8 );

@ISA = ( "EPrints::Plugin::Convert" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "SWORD Unpacker - XML";
	$self->{visible} = "";
	$self->{accept} = "text/xml"; 
	
	return $self;
}


sub export
{
	my ( $plugin, %opts ) = @_;

	my $filename = $opts{filename};

	my @files;

	my $mime = EPrints::Sword::FileType::checktype_filename( $filename );

	if( $mime eq 'text/xml' )
	{
		push @files, $filename;
		return \@files;
	}

#	print STDERR "\n[SWORD] [XML-UNPACKER] wrong type or could not find the file ".$filename;

	return undef;		
}





1;
