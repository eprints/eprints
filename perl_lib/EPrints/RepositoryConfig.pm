######################################################################
#
# EPrints::RepositoryConfig
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::RepositoryConfig> - Repository Configuration

=head1 SYNOPSIS

	$c->add_dataset_field( "eprint", {
		name => "title",
		type => "longtext",
	}, reuse => 1 );

=head1 DESCRIPTION

This provides methods for reading and setting a repository configuration.
Setter methods may only be used in the configuration.

=head1 METHODS

=head2 Setter Methods

=over 4

=cut

package EPrints::RepositoryConfig;

use strict;

=item $c->add_dataset_trigger( $datasetid, TRIGGER_ID, $f, %opts )

Register a function reference $f to be called when the TRIGGER_ID event happens on $datasetid.

See L<EPrints::Const> for available triggers.

See L</add_trigger> for %opts.

=cut

sub add_dataset_trigger
{
	my( $self, $datasetid, $type, $f, %opts ) = @_;

	if( $self->read_only ) { EPrints::abort( "Configuration is read-only." ); }

	if( ref($f) ne "CODEREF" && ref($f) ne "CODE" )
	{
		EPrints->abort( "add_dataset_trigger expected a CODEREF but got '$f'" );
	}

	my $priority = exists $opts{priority} ? $opts{priority} : 0;

	push @{$self->{datasets}->{$datasetid}->{triggers}->{$type}->{$priority}}, $f;
}

=item $c->add_trigger( TRIGGER_ID, $f, %opts )

Register a function reference $f to be called when the TRIGGER_ID event happens.

See L<EPrints::Const> for available triggers.

Options:

	priority - used to determine the order triggers are executed in (defaults to 0).

=cut

sub add_trigger
{
	my( $self, $type, $f, %opts ) = @_;

	if( $self->read_only ) { EPrints::abort( "Configuration is read-only." ); }

	if( ref($f) ne "CODEREF" && ref($f) ne "CODE" )
	{
		EPrints->abort( "add_trigger expected a CODEREF but got '$f'" );
	}

	my $priority = exists $opts{priority} ? $opts{priority} : 0;

	push @{$self->{triggers}->{$type}->{$priority}}, $f;
}

=item $repository->add_nameset_field( $namesetid, $nameset_name, %opts )

Add a value $nameset_name to nameset $namesetid.

=cut

sub add_namedset_field
{
	my( $repository, $namesetid, $nameset_name, %opts ) = @_;

	my $reuse = $opts{reuse};

	my $dir = $repository->get_repository->get_conf( "config_path" )."/namedsets";
        
	my $dh;
        opendir( $dh, $dir );
        my @type_files = ();
        while( my $fn = readdir( $dh ) )
        {
                next if $fn=~m/^\./;
                push @type_files, $fn;
        }
        closedir( $dh );

        foreach my $tfile ( @type_files )
        {
		if ($tfile eq $namesetid) 
		{
                	my $file = $dir."/".$tfile;
                	open( FILE, $file ) || EPrints::abort( "Could not read $file" );
			my $flag = 0;
	                foreach my $line (<FILE>)
        	        {
                	        $line =~ s/\015?\012?$//s;
	                        $line =~ s/#.*$//;
        	                $line =~ s/^\s+//;
                	        $line =~ s/\s+$//;
	                        next if $line eq "";
				if ($line eq $nameset_name)
				{
					$flag = 1;	
				}
        	        }
			close FILE;
			if (!$flag) {
				open ( FILE, ">>$file" );
				print FILE $nameset_name."\n";
				close FILE;
			}
			close FILE
		}
        }
}

=item $repository->remove_nameset_field( $namesetid, $nameset_name, %opts )

Remove a value $nameset_name from nameset $namesetid.

=cut

sub remove_namedset_field
{
	my( $repository, $namesetid, $nameset_name, %opts ) = @_;
	
	my $dir = $repository->get_repository->get_conf( "config_path" )."/namedsets";

        my $dh;
        opendir( $dh, $dir );
        my @type_files = ();
        while( my $fn = readdir( $dh ) )
        {
                next if $fn=~m/^\./;
                push @type_files, $fn;
        }
        closedir( $dh );

        foreach my $tfile ( @type_files )
        {
		if ($tfile eq $namesetid) 
		{
                	my $file = $dir."/".$tfile;
                	my $out;
			my $flag = 0;
			open( FILE, $file ) || EPrints::abort( "Could not read $file" );
	                foreach my $line (<FILE>)
        	        {
                	        $line =~ s/\015?\012?$//s;
				if (!($line eq $nameset_name))
				{
					$out .= $line . "\n";
				} else {
					$flag = 1;
				}
				
        	        }
			close FILE;
			if ($flag) {
				open ( FILE, ">$file" );
				print FILE $out."\n";
				close FILE;
			}
		}
        }
}

=item $c->add_dataset_field( $datasetid, $fielddata, %opts )

Add a field spec $fielddata to dataset $datasetid.

This method will abort if the field already exists and 'reuse' is unspecified.

Options:
	reuse - re-use an existing field if it exists (must be same type)

=cut

sub add_dataset_field
{
	my( $c, $datasetid, $fielddata, %opts ) = @_;

	$c->{fields}->{$datasetid} = [] if !exists $c->{fields}->{$datasetid};

	my $reuse = $opts{reuse};

	for(@{$c->{fields}->{$datasetid}})
	{
		if( $_->{name} eq $fielddata->{name} )
		{
			if( !$reuse )
			{
				EPrints->abort( "Duplicate field name encountered in configuration: $datasetid.$_->{name}" );
			}
			elsif( $_->{type} ne $fielddata->{type} )
			{
				EPrints->abort( "Attempt to reuse field $datasetid.$_->{name} but it is a different type: $_->{type} != $fielddata->{type}" );
			}
			else
			{
				return;
			}
		}
	}

	push @{$c->{fields}->{$datasetid}}, $fielddata;
}

=pod

=back

=cut 

# Non advertised methods!

sub set_read_only
{
	my( $self ) = @_;
	$self->{".read_only"} = 1;	
}

sub unset_read_only
{
	my( $self ) = @_;
	$self->{".read_only"} = 0;	
}

sub read_only
{
	my( $self ) = @_;

	return( defined $self->{".read_only"} && $self->{".read_only"} );
}

1;
