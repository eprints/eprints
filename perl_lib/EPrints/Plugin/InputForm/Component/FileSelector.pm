=head1 NAME

EPrints::Plugin::InputForm::Component::FileSelector

=cut

package EPrints::Plugin::InputForm::Component::FileSelector;

use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "FileSelector";
	$self->{visible} = "all";
#	$self->{surround} = "None" unless defined $self->{surround};

	return $self;
}

sub wishes_to_export
{
	my( $self ) = @_;

	return $self->{session}->param( $self->{prefix} . "_export" );
}

# only returns a value if it belongs to this component
sub update_from_form
{
	my( $self, $processor ) = @_;

	my $repo = $self->{repository};
	my $epm = $self->{workflow}->{item};

	my @filenames = sort grep {
			EPrints::Utils::is_set( $_ ) &&
			$_ !~ m#^(?:/|\.)# &&
			$_ !~ m#/\.#
		} $repo->param( $self->{prefix} );

	my $doc;
	for(@{$epm->value( "documents" )})
	{
		$doc = $_, last
			if $_->value( "content" ) eq $self->{config}->{document};
	}
	if( !defined $doc )
	{
		$doc = $repo->dataset( "document" )->make_dataobj( {
			content => $self->{config}->{document},
			files => [],
		} );
	}

	foreach my $file (@filenames)
	{
		$file = $repo->dataset( "file" )->make_dataobj({
			filename => $file,
		});
	}

	$doc->set_value( "files", \@filenames );
	$epm->set_value( "documents", [$doc] );

	$epm->rebuild;

	return;
}

# hmmm. May not be true!
sub is_required { 0 }

sub get_fields_handled { qw( documents ) }

sub render_content
{
	my( $self, $surround ) = @_;
	
	my $repo = $self->{repository};
	my $epm = $self->{workflow}->{item};

	my $f = $repo->xml->create_document_fragment;

	my $epmid = $epm->id;
	my @exclude = split /\s+/, <<"EOE";
		^defaultcfg
		^syscfg\\.d
		^entities\\.dtd\$
		^mime\\.types\$
		^epm/$epmid/$epmid\\.epm\$
		^epm/$epmid/$epmid\\.epmi\$
EOE
	@exclude = grep { $_ =~ /\S/ } @exclude;
	my $exclude_re = join '|', map { "(?:$_)" } @exclude;
	$exclude_re = qr/$exclude_re/;

	my $doc;
	for(@{$epm->value( "documents" )})
	{
		$doc = $_, last
			if $_->value( "content" ) eq $self->{config}->{document};
	}
	if( !defined $doc )
	{
		$doc = $repo->dataset( "document" )->make_dataobj( {
			content => $self->{config}->{document},
			files => [],
		} );
	}
	my %selected;
	my @filenames = map { $_->value( "filename" ) } @{$doc->value( "files" )};
	foreach my $filename (@filenames)
	{
		my @parts = split '/', $filename;
		foreach my $i (0..$#parts)
		{
			$selected{join('/',@parts[0..$i])} = 1;
		}
	}

	my $tree = [ undef, [] ];
	my @stack = ($tree);

	my $path = $self->{config}->{path};
	$path =~ s! /*$ !/!x;

	File::Find::find({
		no_chdir => 1,
		preprocess => sub {
			my $filename = $File::Find::dir;
			$filename =~ s/^.*\///;
			my $rel = substr($File::Find::dir, length($path));
			my $node = [ $filename, [],
				show => $selected{$rel}
			];
			push @{$stack[-1][1]}, $node;
			push @stack, $node;
			return sort { $a cmp $b } grep { $_ !~ /^\./ } @_;
		},
		wanted => sub {
			return if -d $File::Find::name;
			my $rel = substr($File::Find::name, length($path));
			return if $rel =~ $exclude_re;
			push @{$stack[-1][1]}, $rel;
		},
		postprocess => sub { pop @stack; }
	}, $path );

	$tree = $tree->[1];

	push @{$tree->[0]}, show => 1;

	$f->appendChild( $repo->xhtml->tree( $tree,
		prefix => "ep_fileselector",
		render_value => sub { $self->_render_value( \%selected, @_ ) },
	) );

	return $f;
}

sub _render_value
{
	my( $self, $selected, $ctx, $children ) = @_;

	return $ctx if defined $children;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;
	my $frag = $xml->create_document_fragment;

	my @path = split '/', $ctx;

	my $id = $self->{prefix} . ':' . join('/',@path);
	my $input = $frag->appendChild(
		$xhtml->input_field( $self->{prefix}, join('/',@path),
			type => "checkbox",
			($selected->{$ctx} ? (checked => "checked") : ())
	) );
	$input->setAttribute( id => $id );
	$frag->appendChild( $xml->create_data_element( "label", $path[-1],
		for => $id
	) );

	return $frag;
}

sub export_mimetype
{
	my( $self ) = @_;

	my $plugin = $self->note( "action" );
	if( defined($plugin) && $plugin->param( "ajax" ) eq "automatic" )
	{
		return $plugin->export_mimetype;
	}

	return $self->SUPER::export_mimetype();
}

sub validate
{
	my( $self ) = @_;
	
	my @problems = ();

	return @problems;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;

	$self->{config}->{path} = $config_dom->getAttribute( "path" );
	$self->{config}->{document} = $config_dom->getAttribute( "document" );
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

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

