######################################################################
#
# EPrints::Apache::Template
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Apache::Template> - Template Applying Module

=head1 SYNOPSIS

	<?xml version="1.0" standalone="no"?>
	<!DOCTYPE html SYSTEM "entities.dtd">
	<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epc="http://eprints.org/ep3/control">
	  <head>
		  <title><epc:pin ref="title" textonly="yes"/> - <epc:phrase ref="archive_name"/></title>
    ...

=head1 DESCRIPTION

This module renders HTML page content using a template.

Templates are parsed and rendered at server start-up, expanding phrases and any EPC. If you need to include dynamic content in the page use use a pin generated via L</Dynamic Pins>.

The page title, content and other core page structures are supplied via L</Default Pins>.

=head2 Static HTML Pages

Static files with the F<.xpage> extension are rendered using templates:

	<?xml version="1.0" encoding="utf-8"  standalone="no"  ?>
	<!DOCTYPE page SYSTEM "entities.dtd" >
	<xpage:page xmlns="http://www.w3.org/1999/xhtml" xmlns:xpage="http://eprints.org/ep3/xpage" xmlns:epc="http://eprints.org/ep3/control">
		<xpage:template>default</xpage:template>
		<xpage:head>
			<style type="text/css">h1 { text-weight: bold }</style>
		</xpage:head>
		<xpage:title>My first XPage</xpage:title>
		<xpage:body>
			Writing XPages is easy.
		</xpage:body>
	</xpage:page>

C<< <xpage:template> >> is a special pin that, instead of supplying content to the template, changes the template used for rendering. The content is just the template name (without the F<.xml> extension).

=head2 Default Pins

=over 4

=item title

The title of the page.

=item page

The page content.

=item login_status_header

HTML <head> includes for the login status of the user - currently just some JavaScript variables.

=item head

Page-specific HTML <head> contents.

=item pagetop

(Unused?)

=item login_status

A menu containing L<EPrints::Plugin::Screen>s that appear in C<key_tools>. The content from each plugin's C<render_action_link> is rendered as a HTML <ul> list.

Historically this was the login/logout links plus C<key_tools> but since 3.3 login/logout are Screen plugins as well.

=item languages

The C<render_action_link> from L<EPrints::Plugin::Screen::SetLang>.

=back

=head2 Dynamic Pins

In C<cfg.d/dynamic_template.pl>:

	$c->{dynamic_template}->{function} = sub {
		my( $repo, $parts ) = @_;

		$parts->{mypin} = $repo->xml->create_text_node( "Hello, World!" );
	};

In C<archives/[archiveid]/cfg/templates/default.xml> (copy from C<lib/templates/default.xml> if not already exists):

	<epc:pin ref="mypin" />

Or, for just the text content of a pin:

	<epc:pin ref="mypin" textonly="yes" />

=head1 METHODS

=over 4

=cut

package EPrints::Apache::Template;

use EPrints::Apache::AnApache; # exports apache constants

use strict;



######################################################################
#
# EPrints::Apache::Template::handler( $r )
#
######################################################################

sub handler
{
	my( $r ) = @_;

	my $filename = $r->filename;

	return DECLINED unless( $filename =~ s/\.html$// );

	return DECLINED unless( -r $filename.".page" );

	my $repo = EPrints->new->current_repository;

	my $parts;
	foreach my $part ( "title", "title.textonly", "page", "head", "template" )
	{
		if( !-e $filename.".".$part )
		{
			$parts->{"utf-8.".$part} = "";
		}
		elsif( open( CACHE, $filename.".".$part ) ) 
		{
			binmode(CACHE,":utf8");
			$parts->{"utf-8.".$part} = join("",<CACHE>);
			close CACHE;
		}
		else
		{
			$parts->{"utf-8.".$part} = "";
			$repo->log( "Could not read ".$filename.".".$part.": $!" );
		}
	}

	local $repo->{preparing_static_page} = 1; 

	$parts->{login_status} = EPrints::ScreenProcessor->new(
		session => $repo,
	)->render_toolbar;
	
	my $template = delete $parts->{"utf-8.template"};
	chomp $template;
	$template = 'default' if $template eq "";
	my $page = $repo->prepare_page( $parts,
			page_id=>"static",
			template=>$template
		);
	$page->send;

	return OK;
}








1;

######################################################################
=pod

=back

=cut

=head1 SEE ALSO

The directories scanned for template sources are in L<EPrints::Repository/template_dirs>.

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

