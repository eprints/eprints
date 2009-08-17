######################################################################
#
# EPrints::Handle::Page
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

=head1 NAME

B<EPrints::Handle:::Page> - :Page methods for EPrins::Session

=head1 DESCRIPTION

This module provides additional methods to EPrints::Handle and is not
an object in it's own right.

=over 4

=cut

use strict;

package EPrints::Handle;


######################################################################
=pod

=item $handle->write_static_page( $filebase, $parts, [$page_id], [$wrote_files] )

Write an .html file plus a set of files describing the parts of the
page for use with the dynamic template option.

File base is the name of the page without the .html suffix.

parts is a reference to a hash containing DOM trees.

If $wrote_files is defined then any filenames written are logged in it as keys.

=cut
######################################################################

sub write_static_page
{
	my( $self, $filebase, $parts, $page_id, $wrote_files ) = @_;

	print "Writing: $filebase\n" if( $self->{noise} > 1 );
	
	my $dir = $filebase;
	$dir =~ s/\/[^\/]*$//;

	if( !-d $dir ) { EPrints::Platform::mkdir( $dir ); }
	if( !defined $parts->{template} && -e "$filebase.template" )
	{
		unlink( "$filebase.template" );
	}
	foreach my $part_id ( keys %{$parts} )
	{
		my $file = $filebase.".".$part_id;
		if( open( CACHE, ">$file" ) )
		{
			binmode(CACHE,":utf8");
			print CACHE EPrints::XML::to_string( $parts->{$part_id}, undef, 1 );
			close CACHE;
			if( defined $wrote_files )
			{
				$wrote_files->{$file} = 1;
			}
		}
		else
		{
			$self->{repository}->log( "Could not write to file $file" );
		}
	}


	my $title_textonly_file = $filebase.".title.textonly";
	if( open( CACHE, ">$title_textonly_file" ) )
	{
		binmode(CACHE,":utf8");
		print CACHE EPrints::Utils::tree_to_utf8( $parts->{title}, undef, undef, undef, 1 ); # don't convert href's to <http://...>'s
		close CACHE;
		if( defined $wrote_files )
		{
			$wrote_files->{$title_textonly_file} = 1;
		}
	}
	else
	{
		$self->{repository}->log( "Could not write to file $title_textonly_file" );
	}

	my $html_file = $filebase.".html";
	$self->prepare_page( $parts, page_id=>$page_id );
	$self->page_to_file( $html_file, $wrote_files );
}

######################################################################
=pod

=item $handle->prepare_page( $parts, %options )

Create an XHTML page for this session. 

$parts is a hash of XHTML elements to insert into the pins in the
template. Usually: title, page. Maybe pagetop and head.

If template is set then an alternate template file is used.

This function only builds the page it does not output it any way, see
the methods below for that.

Options include:

page_id=>"id to put in body tag"
template=>"The template to use instead of default."

=cut
######################################################################
# move to compat module?
sub build_page
{
	my( $self, $title, $mainbit, $page_id, $links, $template ) = @_;
	$self->prepare_page( { title=>$title, page=>$mainbit, pagetop=>undef,head=>$links}, page_id=>$page_id, template=>$template );
}


sub prepare_page
{
	my( $self, $map, %options ) = @_;

	unless( $self->{offline} || !defined $self->{query} )
	{
		my $mo = $self->param( "mainonly" );
		if( defined $mo && $mo eq "yes" )
		{
			$self->{page} = $map->{page};
			return;
		}

		my $dp = $self->param( "edit_phrases" );
		# phrase debugging code.

		if( defined $dp && $dp eq "yes" )
		{
			my $current_user = $self->current_user;	
			if( defined $current_user && $current_user->allow( "config/edit/phrase" ) )
			{
				my $phrase_screen = $self->plugin( "Screen::Admin::Phrases",
		  			phrase_ids => [ sort keys %{$self->{used_phrases}} ] );
				$map->{page} = $self->make_doc_fragment;
				my $url = $self->get_full_url;
				my( $a, $b ) = split( /\?/, $url );
				my @parts = ();
				foreach my $part ( split( "&", $b ) )	
				{
					next if( $part =~ m/^edit(_|\%5F)phrases=yes$/ );
					push @parts, $part;
				}
				$url = $a."?".join( "&", @parts );
				my $div = $self->make_element( "div", style=>"margin-bottom: 1em" );
				$map->{page}->appendChild( $div );
				$div->appendChild( $self->html_phrase( "lib/session:phrase_edit_back",
					link => $self->render_link( $url ),
					page_title => $self->clone_for_me( $map->{title},1 ) ) );
				$map->{page}->appendChild( $phrase_screen->render );
				$map->{title} = $self->html_phrase( "lib/session:phrase_edit_title",
					page_title => $map->{title} );
			}
		}
	}
	
	if( $self->get_repository->get_conf( "dynamic_template","enable" ) )
	{
		if( $self->get_repository->can_call( "dynamic_template", "function" ) )
		{
			$self->get_repository->call( [ "dynamic_template", "function" ],
				$self,
				$map );
		}
	}

	my $pagehooks = $self->get_repository->get_conf( "pagehooks" );
	$pagehooks = {} if !defined $pagehooks;
	my $ph = $pagehooks->{$options{page_id}} if defined $options{page_id};
	$ph = {} if !defined $ph;
	if( defined $options{page_id} )
	{
		$ph->{bodyattr}->{id} = "page_".$options{page_id};
	}

	# only really useful for head & pagetop, but it might as
	# well support the others

	foreach( keys %{$map} )
	{
		next if( !defined $ph->{$_} );

		my $pt = $self->make_doc_fragment;
		$pt->appendChild( $map->{$_} );
		my $ptnew = $self->clone_for_me(
			$ph->{$_},
			1 );
		$pt->appendChild( $ptnew );
		$map->{$_} = $pt;
	}

	if( !defined $options{template} )
	{
		if( $self->get_secure )
		{
			$options{template} = "secure";
		}
		else
		{
			$options{template} = "default";
		}
	}

	my $parts = $self->get_repository->get_template_parts( 
				$self->get_langid, 
				$options{template} );
	my @output = ();
	my $is_html = 0;

	foreach my $bit ( @{$parts} )
	{
		$is_html = !$is_html;

		if( $is_html )
		{
			push @output, $bit;
			next;
		}

		# either 
		#  print:epscript-expr
		#  pin:id-of-a-pin
		#  pin:id-of-a-pin.textonly
		#  phrase:id-of-a-phrase
		my( @parts ) = split( ":", $bit );
		my $type = shift @parts;

		if( $type eq "print" )
		{
			my $expr = join "", @parts;
			my $result = EPrints::XML::to_string( EPrints::Script::print( $expr, { handle =>$self } ), undef, 1 );
			push @output, $result;
			next;
		}

		if( $type eq "phrase" )
		{	
			my $phraseid = join "", @parts;
			push @output, EPrints::XML::to_string( $self->html_phrase( $phraseid ), undef, 1 );
			next;
		}

		if( $type eq "pin" )
		{	
			my $pinid = shift @parts;
			my $modifier = shift @parts;
			if( defined $modifier && $modifier eq "textonly" )
			{
				my $text;
				if( defined $map->{"utf-8.".$pinid.".textonly"} )
				{
					$text = $map->{"utf-8.".$pinid.".textonly"};
				}
				elsif( defined $map->{$pinid} )
				{
					# don't convert href's to <http://...>'s
					$text = EPrints::Utils::tree_to_utf8( $map->{$pinid}, undef, undef, undef, 1 ); 
				}

				# else no title
				next unless defined $text;

				# escape any entities in the text (<>&" etc.)
				my $xml = $self->make_text( $text );
				push @output, EPrints::XML::to_string( $xml, undef, 1 );
				EPrints::XML::dispose( $xml );
				next;
			}
	
			if( defined $map->{"utf-8.".$pinid} )
			{
				push @output, $map->{"utf-8.".$pinid};
			}
			elsif( defined $map->{$pinid} )
			{
#EPrints::XML::tidy( $map->{$pinid} );
				push @output, EPrints::XML::to_string( $map->{$pinid}, undef, 1 );
			}
		}

		# otherwise this element is missing. Leave it blank.
	
	}
	$self->{text_page} = join( "", @output );

	return;
}


######################################################################
=pod

=item $handle->send_page( %httpopts )

Send a web page out by HTTP. Only relevant if this is a CGI script.
build_page must have been called first.

See send_http_header for an explanation of %httpopts

Dispose of the XML once it's sent out.

=cut
######################################################################

sub send_page
{
	my( $self, %httpopts ) = @_;
	$self->send_http_header( %httpopts );
	print <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END
	if( defined $self->{text_page} )
	{
		binmode(STDOUT,":utf8");
		print $self->{text_page};
	}
	else
	{
		binmode(STDOUT,":utf8");
		print EPrints::XML::to_string( $self->{page}, undef, 1 );
		EPrints::XML::dispose( $self->{page} );
		delete $self->{page};
	}
	delete $self->{text_page};
}


######################################################################
=pod

=item $handle->page_to_file( $filename, [$wrote_files] )

Write out the current webpage to the given filename.

build_page must have been called first.

Dispose of the XML once it's sent out.

If $wrote_files is set then keys are created in it for each file
created.

=cut
######################################################################

sub page_to_file
{
	my( $self , $filename, $wrote_files ) = @_;
	
	if( defined $self->{text_page} )
	{
		unless( open( XMLFILE, ">$filename" ) )
		{
			EPrints::abort( <<END );
Can't open to write to XML file: $filename
END
		}
		if( defined $wrote_files )
		{
			$wrote_files->{$filename} = 1;
		}
		binmode(XMLFILE,":utf8");
		print XMLFILE $self->{text_page};
		close XMLFILE;
	}
	else
	{
		EPrints::XML::write_xhtml_file( $self->{page}, $filename );
		if( defined $wrote_files )
		{
			$wrote_files->{$filename} = 1;
		}
		EPrints::XML::dispose( $self->{page} );
	}
	delete $self->{page};
	delete $self->{text_page};
}


######################################################################
=pod

=item $handle->set_page( $newhtml )

Erase the current page for this session, if any, and replace it with
the XML DOM structure described by $newhtml.

This page is what is output by page_to_file or send_page.

$newhtml is a normal DOM Element, not a document object.

=cut
######################################################################

sub set_page
{
	my( $self, $newhtml ) = @_;
	
	if( defined $self->{page} )
	{
		EPrints::XML::dispose( $self->{page} );
	}
	$self->{page} = $newhtml;
}

1;
