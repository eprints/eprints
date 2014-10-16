=head1 NAME

EPrints::Plugin::InputForm::Component::Upload

=cut

package EPrints::Plugin::InputForm::Component::Upload;

use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Upload";
	$self->{visible} = "all";
	# a list of documents to unroll when rendering, 
	# this is used by the POST processing, not GET

	return $self;
}

sub wishes_to_export
{
	my( $self ) = @_;

	my $plugin = $self->{processor}->{notes}->{upload_plugin}->{plugin};
	
	return $plugin ? $plugin->wishes_to_export : $self->SUPER::wishes_to_export;
}

sub export_mimetype
{
	my( $self ) = @_;

	my $plugin = $self->{processor}->{notes}->{upload_plugin}->{plugin};
	
	return $plugin ? $plugin->export_mimetype : $self->SUPER::export_mimetype;
}

sub export
{
	my( $self ) = @_;

	my $plugin = $self->{processor}->{notes}->{upload_plugin}->{plugin};
	
	return $plugin ? $plugin->export : $self->SUPER::export;
}


# only returns a value if it belongs to this component
sub update_from_form
{
	my( $self, $processor ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{workflow}->{item};

	if( $session->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;
		my @screen_opts = $self->{processor}->list_items(
			"upload_methods",
			params => {
				processor => $self->{processor},
				parent => $self,
			},
		);
		my @methods = map { $_->{screen} } @screen_opts;
		my $method_ok = 0;
		foreach my $plugin (@methods)
		{
			my $method = $plugin->get_id;
			next if $internal !~ /^$method\_([^:]+)$/;
			my $action = $1;
			$method_ok = 1;
			local $self->{processor}->{action} = $action;
			$plugin->{prefix} = join '_', $self->{prefix}, $plugin->get_id;
			$plugin->from();
			$self->{processor}->{notes}->{upload_plugin}->{plugin} = $plugin;
			$self->{processor}->{notes}->{upload_plugin}->{ctab} = $method;
			$self->{processor}->{notes}->{upload_plugin}->{state_params} = $plugin->get_state_params;
			last;
		}
	}

	return;
}

sub get_state_params
{
	my( $self, $processor ) = @_;

	my @params;

	my $tounroll = {};
	if( $processor->{notes}->{upload_plugin}->{to_unroll} )
	{
		$tounroll = $processor->{notes}->{upload_plugin}->{to_unroll};
	}
	if( $self->{session}->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;
		# modifying existing document
		if( $internal && $internal =~ m/^doc(\d+)_(.*)$/ )
		{
			$tounroll->{$1} = 1;
		}
	}
	my $ctab = $processor->{notes}->{upload_plugin}->{ctab};
	if( $ctab )
	{
		push @params, $self->{prefix}."_tab", $ctab;
	}

	my $uri = URI->new( 'http:' );
	$uri->query_form( @params );

	my $params = $uri->query ? '&' . $uri->query : '';
	if( $processor->{notes}->{upload_plugin}->{state_params} )
	{
		$params .= $processor->{notes}->{upload_plugin}->{state_params};
	}

	return $params;
}

sub has_help
{
	my( $self, $surround ) = @_;
	return $self->{session}->get_lang->has_phrase( $self->html_phrase_id( "help" ) );
}

sub render_help
{
	my( $self, $surround ) = @_;
	return $self->html_phrase( "help" );
}

sub render_title
{
	my( $self, $surround ) = @_;
	return $self->html_phrase( "title" );
}

# hmmm. May not be true!
sub is_required
{
	my( $self ) = @_;
	return 0;
}

sub get_fields_handled
{
	my( $self ) = @_;

	return ( "documents" );
}

sub render_content
{
	my( $self, $surround ) = @_;
	
	my $session = $self->{session};

	my @screen_opts = $self->{processor}->list_items( 
			"upload_methods",
			params => {
				processor => $self->{processor},
				parent => $self,
			},
		);
	my @methods = map { $_->{screen} } @screen_opts;

	my $html = $session->make_doc_fragment;

	# no upload methods so don't do anything
	return $html if @screen_opts == 0;

	my $ctab = $self->{session}->param( $self->{prefix} . "_tab" );
	$ctab = '' if !defined $ctab;

	my @labels;
	my @tabs;
	my $current;
	for(my $i = 0; $i < @methods; ++$i)
	{
		my $plugin = $methods[$i];
		$plugin->{prefix} = join '_', $self->{prefix}, $plugin->get_id;
		push @labels, $plugin->render_title();
		my $div = $session->make_element( "div", class => "ep_block" );
		push @tabs, $div;
		$div->appendChild( $plugin->render( $self->{prefix} ) );
		$current = $i if $ctab eq $plugin->get_id;
	}

	$html->appendChild( $self->{session}->xhtml->tabs( \@labels, \@tabs,
		basename => $self->{prefix},
		current => $current,
	) );

	return $html;
}

sub doc_fields
{
	my( $self, $document ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset('document');
	my @fields = @{$self->{config}->{doc_fields}};

	my %files = $document->files;
	if( scalar keys %files > 1 )
	{
		push @fields, $ds->get_field( "main" );
	}
	
	return @fields;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;

	$self->SUPER::parse_config( $config_dom );

	my @uploadmethods = $config_dom->getElementsByTagName( "upload-methods" );
	if( defined $uploadmethods[0] )
	{
		$self->{config}->{methods} = [];

		my @methods = $uploadmethods[0]->getElementsByTagName( "method" );
	
		foreach my $method_tag ( @methods )
		{	
			my $method = EPrints::XML::to_string( EPrints::XML::contents_of( $method_tag ) );
			push @{$self->{config}->{methods}}, $method;
		}
	}
}

sub problems
{
	my( $self ) = @_;

	if( $self->{xml_config}->getElementsByTagName( "field" )->length > 0 )
	{
		return $self->html_phrase( "error:fields" );
	}
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

