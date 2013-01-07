=head1 NAME

B<EPrints::Template> - loading and rendering of templates

=head1 DESCRIPTION

=head1 SYNOPSIS

	my $template = $repo->template( "default" );
	
	$ok = $template->freshen();

	$template->write( $fh, $pins );

=head1 METHODS

=item $template = EPrints::Template->new( $filename, %opts )

Returns a new EPrints::Template object read from $filename.

Options:
	repository - repository this template belongs to

=cut

package EPrints::Template;

use EPrints::Const qw( :http );

use strict;

sub new
{
	my( $class, $filename, %self ) = @_;

	$self{filename} = $filename;

	my $self = bless \%self, $class;

	Scalar::Util::weaken($self{repository})
		if defined &Scalar::Util::weaken;

	return undef if !$self->freshen();

	return $self;
}

=item $ok = $template->freshen()

Attempts to reload the template source file.

Returns undef if the file could not be loaded.

=cut

sub freshen
{
	my( $self ) = @_;

	my $file = $self->{filename};
	my $mtime = EPrints::Utils::mtime( $file );
	my $old_mtime = $self->{mtime};

	if( defined $old_mtime && $old_mtime == $mtime )
	{
		return;
	}

	return $self->load_source();
}

=item $ok = $template->load_source()

Reads the source file.

=cut

sub load_source
{
	return undef;
}

=item $template->write_page( $fh, $page )

Writes the $page to $fh using this template.

=cut

sub write_page
{
	my( $self, $pins ) = @_;
}

=item STATUS = $template->send_page( $page )

Send the page via Apache, taking care of setting the correct Content-Type header, adding automatic pins etc.

Returns the HTTP status code.

=cut

sub send_page
{
	my( $self, $page ) = @_;

	my $repo = $self->{repository};

	local $repo->{preparing_static_page} = 1; 

	$repo->send_http_header;
	binmode(STDOUT, ":utf8");

	if( !defined $page->pins->{login_status} )
	{
		$page->pins->{login_status} = EPrints::ScreenProcessor->new(
			session => $repo,
		)->render_toolbar;
	}
	
	# languages pin
	if( defined(my $plugin = $repo->plugin( "Screen::SetLang" )) )
	{
		$page->pins->{languages} = $plugin->render_action_link;
	}
	
	$repo->run_trigger( EPrints::Const::EP_TRIGGER_DYNAMIC_TEMPLATE,
			pins => $page->pins,
		);

	# if mainonly=yes is in effect return the page content
	if( $repo->param( "mainonly" ) && $repo->param( "mainonly" ) eq "yes" )
	{
		my $cnt = $page->utf8_pin( "page" );
		if( $cnt ne "" )
		{
			print $cnt;
		}
		else
		{
			$repo->log( "Can't generate mainonly without page" );
			return HTTP_NOT_FOUND;
		}
		return HTTP_OK;
	}

	eval {
		$self->write_page( \*STDOUT, $page )
	};
	$repo->log( $@ ) if $@; # catch disconnects

	return OK;
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

