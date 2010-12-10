######################################################################
#
# EPrints::NamedSet
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2010 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::NamedSet> - Repository Configuration

=head1 SYNOPSIS

	$namedset = EPrints::NamedSet->new( "eprint",
		repository => $repository
	);
	
	$namedset->add_option( "performance" );
	$namedset->remove_option( "thesis" );
	
	$namedset->write;

=head1 DESCRIPTION

A utility class to manipulate named sets. 

=head1 METHODS

=over 4

=cut

package EPrints::NamedSet;

use strict;
use File::Copy;;

=item $namedset = EPrints::NamedSet->new( $id, %opts )

=cut

sub new
{
	my( $class, $id, %self ) = @_;

	$self{id} = $id;
	@{$self{options}} = $self{repository}->get_types( $id );

	my $self = bless \%self, $class;

	return $self;
}

=item $nameset->add_option( $option, $package_name [, $index] )

Add an option to the named set. 

If the option already exists and is not core or already beloning to this package then a required_by field is added to the file. 

If it already exists, index is ignored.

=cut 

sub add_option
{
	my ( $self, $option, $package_name, $index) = @_;

	for(@{$self->{options}})
	{
		if ($_ eq $option) {
			$self->_add_required_by($option,$package_name,0);
			return 1;
		}
	}
		
	if( @_ == 3 )
	{
		push @{$self->{options}}, $option;
		$index = scalar(@{$self->{options}});
		print STDERR "ADDING AT END = $index\n\n";
	}
	else
	{
		splice(@{$self->{options}}, $index, 0, $option);
	}

	return $self->_add_required_by($option,$package_name,$index);
}

sub _add_required_by
{
	my ( $self, $option, $package_name, $index ) = @_;

	my $tempfile = File::Temp->new;
	
	open(my $fh, ">", $tempfile) or return 0;

	my $file = $self->{repository}->config( "config_path" )."/namedsets/" . $self->{id};
	open( FILE, $file ) || return 0;

	if ($index > 0) {
		my $count = 1;
		my $myline = $option . ' required_by="' . $package_name . '"' . "\n";
		my $done_flag=0;
		foreach my $line (<FILE>) {
			if ($count eq $index) {
				print $fh $myline;
				$done_flag = 1;
				$count++;
			} 
			$line =~ s/\015?\012?$//s;
			$line =~ s/#.*$//;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line = $line . "\n";
			print $fh $line;
			$count++;
		}
		#Add it to the end of the file
		if ($done_flag < 1) {
			print $fh $myline;
		}
		close FILE;
		close $fh;
		copy($tempfile,$file);
		return 1;	
	}

	foreach my $line (<FILE>)
	{
		$line =~ s/\015?\012?$//s;
		$line =~ s/#.*$//;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		my @values = split(' ',$line);
		$line = @values[0];
		next if $line eq "";
		if ($line eq $option) {
			foreach my $value(@values) {
				if ((substr($value, 0, 11)) eq "required_by") {	
					$line .= ' required_by="';
					my $package_line = substr $value, 13, -1;
					my @packages = split(',',$package_line);
					my $flag = 0;
					foreach my $package(@packages) 
					{
						$line .= $package . ",";
						if ($package eq $package_name) { $flag = 1; }
					}
					unless ($flag > 0) {
						$line .= $package_name . ",";
					}
					$line = substr($line,0,length($line)-1);
					$line .= '"';
				} elsif (!($value eq $option)) {
					$line .= " " . $value;
				}
			}
		}
		$line .= "\n";
		print $fh $line;
	}
	close FILE;
	close $fh;
	copy($tempfile,$file);

}

=item $namedset->remove_option( $option, $package_name )

Remove an option from the named set.

=cut

sub remove_option
{
	my( $self, $option, $package_name ) = @_;

	my $tempfile = File::Temp->new;
	
	open(my $fh, ">", $tempfile) or return 0;

	my $file = $self->{repository}->config( "config_path" )."/namedsets/" . $self->{id};
	open( FILE, $file ) || return 0;

	foreach my $line (<FILE>)
	{
		$line =~ s/\015?\012?$//s;
		$line =~ s/#.*$//;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		my @values = split(' ',$line);
		my $line_option = @values[0];
		next if $line_option eq "";
		my $print_flag = 1;
		if ($line_option eq $option) {
			$line = $option;
			foreach my $value(@values) {
				if ((substr ($value, 0, 11)) eq "required_by") {
					$value =~ s/^\s+//;
					$value =~ s/\s+$//;
					$line .= ' required_by="';
					my $package_line = substr($value, 13, length($value));
					$package_line = substr($package_line, 0, length($package_line)-1);
					my @packages = split(',',$package_line);
					my @out;
					foreach my $package(@packages) 
					{
						unless ($package eq $package_name) {
							push (@out,$package);
						}
					}
					if (scalar @out < 1) {
						$print_flag = 0;
					} 
					foreach my $package(@out) {
						$line .= $package . ",";
					}
					$line = substr($line,0,length($line)-1);
					$line .= '"';
				} elsif (!($value eq $option)) {
					$line .= " " . $value;
				}
			}
		}
		$line .= "\n";
		if  ($print_flag < 1) {
			@{$self->{options}} = grep { $_ ne $option } @{$self->{options}};
		} else {
			print $fh $line;
		}
	}
	close FILE;
	close $fh;
	copy($tempfile,$file);

}

=item $ok = $namedset->remove

Remove the namedset from the file system.

=cut

sub remove
{
	my( $self ) = @_;

	my $dir = $self->{repository}->config( "config_path" )."/namedsets";

	my $path = $dir . "/" . $self->{id};
        
	return unlink( $path );
}

1;
