=head1 NAME

EPrints::Plugin::Export::CSV

=cut

package EPrints::Plugin::Export::CSV;

use EPrints::Plugin::Export::TextFile;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Comma-Separated Values";
	$self->{accept} = [ 'dataobj/*', 'list/*' ];
	$self->{visible} = "all";
	$self->{suffix} = ".csv";
	$self->{mimetype} = "text/csv; charset=utf-8";
	
	return $self;
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $r = "";
	my $f = $opts{fh} ? sub { print {$opts{fh}} "$_[0]\n" } : sub { $r .= "$_[0]\r\n" };

	my @fields = $self->fields( $opts{list}->{dataset} );

	my $key_field = EPrints::MetaField->new(
			name => "_",
			type => "text",
			repository => $self->{repository},
		);

	&$f(
		join ',',
		map { csv_escape( $key_field, $_ ) }
		map { $self->{repository}->xhtml->to_text_dump( $_ ) }
		map { $_->render_name }
		@fields
	);

	$self->SUPER::output_list(
			%opts,
			fields => \@fields,
		);

	return $r;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $dataset = $dataobj->{dataset};

	my $fields = $opts{fields} || [$self->fields( $dataset )];

	my $r = "";
	my $f = $opts{fh} ? sub { print {$opts{fh}} "$_[0]\n" } : sub { $r .= "$_[0]\r\n" };

	my @rows = ([]);
	foreach my $field (@$fields)
	{
		my $i = @{$rows[0]};
		$rows[0][$i] = undef; # multiples won't fill out the column, so make sure it is done here

		my $value = $field->get_value( $dataobj );
		if( ref($value) eq "ARRAY" )
		{
			foreach my $j (0..$#$value) {
				$rows[$j][$i] = csv_escape( $field, $value->[$j] );
			}
		}
		else
		{
			$rows[0][$i] = csv_escape( $field, $value );
		}
	}

	# generate complete rows
	for(@rows) {
		$_->[$#{$rows[0]}] ||= undef;
	}

	{ # ignore undef warnings
		no warnings;
		&$f( join ',', @$_ ) for @rows;
	}

	return $r;
}

sub fields
{
	my( $self, $dataset ) = @_;

	return grep {
			$_->property( "export_as_xml" ) &&
			!$_->is_virtual &&
			!$_->isa( "EPrints::MetaField::Itemref" )
		} $dataset->fields;
}

sub csv_escape
{
	my( $field, $value ) = @_;

	return "" if !EPrints::Utils::is_set( $value );

	local $field->{multiple};
	$value = $field->render_value( $field->{repository}, $value );
	$value = $field->{repository}->xhtml->to_text_dump( $value );

	if( $field->isa( "EPrints::MetaField::Int" ) )
	{
	}
	else
	{
		$value =~ s/"/""/g;
		$value =~ s/\n/ /sg;
		$value = "\"$value\"";
	}

	return $value;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2012 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

