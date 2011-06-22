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
	
	$f->appendChild( $repo->make_javascript( <<EOJ
Event.observe(window, 'load', function() {
	\$('$self->{prefix}').descendants().each(function(ele) {
		if( ele.nodeName != 'DT' ) return;
		ele.onclick = (function() {
			var dd = this.next('dd');
			if( !dd ) return;
			if( dd.visible() ) {
				new Effect.SlideUp(dd, {
					duration: 0.5,
					afterFinish: (function () {
						this.descendants().each(function(ele) {
							if( ele.nodeName == 'DD' )
								ele.hide();
						});
					}).bind(dd)
				});
			} else
				new Effect.SlideDown(dd);
		}).bind(ele);
	});
});
EOJ
	) );

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

	my %tree;
	my @filenames = map { $_->value( "filename" ) } @{$doc->value( "files" )};
	foreach my $filename (@filenames)
	{
		my $c = \%tree;
		for(split '/', $filename)
		{
			$c->{$_} ||= {};
			$c = $c->{$_};
		}
	}

	my %exclude = (
		defaultcfg => {},
		'syscfg.d' => {},
		'entities.dtd' => {},
		'mime.types' => {},
	);

	$f->appendChild( $repo->xml->create_data_element( 'div', $self->_render_tree(
			$self->{config}->{path},
			\%tree,
			\%exclude,
		),
		class => "ep_fileselector",
	) );

	return $f;
}

sub _render_tree
{
	my( $self, $root, $tree, $exclude, @path ) = @_;

	my $xml = $self->{repository}->xml;
	my $xhtml = $self->{repository}->xhtml;

	my $filepath = $root . join('/', '', @path);
	if( -d $filepath )
	{
		my $dl = $xml->create_element( "dl" );
		opendir(my $dh, $filepath);
		my @filenames = sort grep {
				$_ !~ /^\./ &&
				!exists $exclude->{$_}
			} readdir($dh);
		closedir($dh);
		$dl->appendChild( $xml->create_data_element( "dt", ($path[$#path] || '') . '/' ) );
		my $dd = $dl->appendChild( $xml->create_element( "dd" ) );
		if( !defined $tree )
		{
			$dd->setAttribute( style => "display: none" );
		}
		my $ul = $dd->appendChild( $xml->create_element( "ul" ) );
		foreach my $filename (@filenames)
		{
			my $filepath = $root . join('/', '', @path, $filename);
			if( -d $filepath )
			{
				$dd->insertBefore( $self->_render_tree(
					$root,
					$tree->{$filename},
					$exclude->{$filename},
					@path,
					$filename
				), $ul );
			}
			else
			{
				$ul->appendChild( $self->_render_tree(
					$root,
					$tree->{$filename},
					$exclude->{$filename},
					@path,
					$filename
				) );
			}
		}
		return $dl;
	}
	else
	{
		my $id = $self->{prefix} . ':' . join('/',@path);
		my $li = $xml->create_element( "li" );
		my $input = $li->appendChild(
			$xhtml->input_field( $self->{prefix}, join('/',@path),
				type => "checkbox",
				(defined $tree ? (checked => "checked") : ())
		) );
		$input->setAttribute( id => $id );
		$li->appendChild( $xml->create_data_element( "label", join('/',@path),
			for => $id
		) );
		return $li;
	}
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

