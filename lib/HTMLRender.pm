######################################################################
#
# EPrints HTML Renderer Module
#
#   Renders common HTML components
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

package EPrints::HTMLRender;

use EPrints::SubjectList;
use EPrints::Name;

use strict;

use CGI;

# Width of text fields
$EPrints::HTMLRender::form_width = 60;
$EPrints::HTMLRender::search_form_width = 40;

# Width of name fields
$EPrints::HTMLRender::form_name_width = 20;

# Width of username fields
$EPrints::HTMLRender::form_username_width = 10;

# Max number of chars in (single-line) text fields
$EPrints::HTMLRender::field_max = 255;

# Max height of scrolling list
$EPrints::HTMLRender::list_height_max = 20;

# Number of extra spaces for names to add when user clicks on "More Spaces"
$EPrints::HTMLRender::add_boxes = 3;

# Months
my @months = ( "00",
               "01",
               "02",
               "03",
               "04",
               "05",
               "06",
               "07",
               "08",
               "09",
               "10",
               "11",
               "12" );

# Month names
my %monthnames =
(
	"00"     => "Unspecified",
	"01"     => "January",
	"02"     => "February",
	"03"     => "March",
	"04"     => "April",
	"05"     => "May",
	"06"     => "June",
	"07"     => "July",
	"08"     => "August",
	"09"     => "September",
	"10"     => "October",
	"11"     => "November",
	"12"     => "December"
);


# These are the types of input for which adding a * for "required" fields
# is inappropriate.  E.g. it looks silly on a checkbox.

my %no_asterisk =
(
	"boolean" => 1
);


######################################################################
#
# new( $session, $offline)
#
#  Create an HTML Renderer. If $offline is true, won't try to read
#  form values.
#
######################################################################

sub new
{
	my( $class, $session, $offline, $query ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{offline} = $offline;
	$self->{query} = $query;

	$self->{session} = $session;

	# Get name boxcount stuff

	$self->{namebuttonpressed} = 0;

	$self->{nameinfo} = {};
	my @names = $self->{query}->param();
	my $n;

	foreach $n (@names)
	{
		$self->{nameinfo}->{$n} = $self->{query}->param( $n )
			if( substr($n, 0, 5) eq "name_" );
		
		$self->{namebuttonpressed} = 1 if( substr($n, 0, 10) eq "name_more_" );
	}
	# Get username boxcount stuff

	$self->{usernamebuttonpressed} = 0;

	$self->{usernameinfo} = {};
	my @usernames = $self->{query}->param();

	foreach $n (@usernames)
	{
		$self->{usernameinfo}->{$n} = $self->{query}->param( $n )
			if( substr($n, 0, 9) eq "username_" );
		
		$self->{usernamebuttonpressed} = 1 if( substr($n, 0, 14) eq "username_more_" );
	}
	
	

	return( $self );
}



######################################################################
#
# $url = absolute url()
#
#  Returns the absolute URL of the current script (no http:// or
#  query string)
#
######################################################################

sub absolute_url
{
	my( $self ) = @_;
	
	return( $self->{query}->url( -absolute=>1 ) );
}


######################################################################
#
# $consumed = internal_button_pressed()
#
#  Important function: if this returns true, then the button pressed on
#  the form was an internal form state button, so whatever form you
#  rendered should be re-rendered to show the updated state info.
#
######################################################################

sub internal_button_pressed
{
	my( $self ) = @_;
	
	return( $self->{namebuttonpressed} ||  $self->{usernamebuttonpressed} );
}


######################################################################
#
# render_error( $error_text, $back_to, $back_to_text )
#
#  Renders an error page with the given error text. A link, with the
#  text $back_to_text, is offered, the destination of this is $back_to,
#  which should take the user somewhere sensible.
#
######################################################################

sub render_error
{
	my( $self, $error_text, $back_to, $back_to_text ) = @_;

	if ( $self->{offline} )
	{
		print $self->{session}->phrase( 
			"A:some_error",
			sitename=>$self->{session}->{site}->{sitename} );
		print "\n\n";
		print "$error_text\n\n";
	} 
	else
	{
		print $self->start_html( 
			$self->{session}->phrase( "H:error_title" ) );

		print "<P>".$self->{session}->phrase( 
			"H:some_error",
			sitename=>$self->{session}->{site}->{sitename} )."</P>\n";
		print "<P>$error_text</P>\n";
		print "<P>".$self->{session}->phrase( 
			"H:contact",
			adminemail=>"<A HREF=\"mailto:$self->{session}->{site}->{admin}\">".$self->{session}->phrase( "H:sitename_admin" , sitename=>$self->{session}->{site}->{sitename} )."</A>"  )."</P>\n";
				
		print "<P><A HREF=\"$back_to\">$back_to_text</A></P>\n";
	
		print $self->end_html();
	}
}



######################################################################
#
# $html = input_field( $field, $value )
#
#  Returns the HTML to produce an input field. $field is a reference
#  to the usual metadata field, and $value is the initial value.
#
######################################################################

sub input_field
{
	my( $self, $field, $value ) = @_;
	
	my $type = $field->{type};

	my $html;

	if( $type eq "text" || $type eq "url" || $type eq "email" )
	{
		my $maxlength = ( defined $field->{maxlength} ? $field->{maxlength}
			: $EPrints::HTMLRender::field_max );
		my $size = ( $maxlength > $EPrints::HTMLRender::form_width ?
			$EPrints::HTMLRender::form_width : $maxlength );
	
		$html = $self->{query}->textfield(
			-name=>$field->{name},
			-default=>$value,
			-size=>$size,
			-maxlength=>$maxlength );
	}
	elsif( $type eq "date" )
	{
		my( $year, $month, $day ) = ("", "", "");
		if( defined $value && $value ne "" )
		{
			($year, $month, $day) = split /-/, $value;
			($year, $month, $day) = ("", "00", "") if( $month == 0 );
		}

		$html = $self->{session}->phrase( "H:year" );
		$html .= $self->{query}->textfield( -name=>"$field->{name}_year",
		                                    -default=>$year,
		                                    -size=>4,
		                                    -maxlength=>4 );
		$html .= " ".$self->{session}->phrase( "H:month" );
		$html .= $self->{query}->popup_menu( -name=>"$field->{name}_month",
		                                     -values=>\@months,
		                                     -default=>$month,
		                                     -labels=>\%monthnames );
		$html .= " ".$self->{session}->phrase( "H:day" );
		$html .= $self->{query}->textfield( -name=>"$field->{name}_day",
		                                    -default=>$day,
		                                    -size=>2,
		                                    -maxlength=>2 );
	}
	elsif( $type eq "int" )
	{
		$html = $self->{query}->textfield( -name=>$field->{name},
		                                   -default=>$value,
		                                   -size=>$field->{displaydigits},
		                                   -maxlength=>$field->{displaydigits} );
	}
	elsif( $type eq "boolean" )
	{
		$html = $self->{query}->checkbox(
			-name=>$field->{name},
			-checked=>( defined $value && $value eq "TRUE" ? "checked" : undef ),
			-value=>"TRUE",
			-label=>"" );
	}
	elsif( $type eq "longtext" )
	{
		$html = $self->{query}->textarea(
			-name=>$field->{name},
			-default=>$value,
			-rows=>$field->{displaylines},
			-columns=>$EPrints::HTMLRender::form_width,
			-wrap=>"soft" );
	}
	elsif( $type eq "set" )
	{
		my @actual;
		@actual = split /:/, $value if( defined $value );

		# Get rid of beginning and end empty values
		shift @actual if( defined $actual[0] && $actual[0] eq "" );
		pop @actual if( defined $actual[$#actual] && $actual[$#actual] eq "" );

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>$field->{tags},
			-default=>\@actual,
			-size=>( $field->{displaylines} ),
			-multiple=>( $field->{multiple} ? 'true' : undef ),
			-labels=>$field->{labels} );
	}
	elsif( $type eq "pagerange" )
	{
		my @pages;
		
		@pages = split /-/, $value if( defined $value );
		
		$html = $self->{query}->textfield( -name=>"$field->{name}_from",
		                                   -default=>$pages[0],
		                                   -size=>6,
		                                   -maxlength=>10 );

		$html .= "&nbsp;to&nbsp;";

		$html .= $self->{query}->textfield( -name=>"$field->{name}_to",
		                                    -default=>$pages[1],
		                                    -size=>6,
		                                    -maxlength=>10 );
	}
	elsif( $type eq "year" )
	{
		$html = $self->{query}->textfield( -name=>$field->{name},
		                                   -default=>$value,
		                                   -size=>4,
		                                   -maxlength=>4 );
	}
	elsif( $type eq "eprinttype" )
	{
		my @eprint_types = $self->{session}->{metainfo}->get_types( "eprint" );
		my $labels = $self->{session}->{metainfo}->get_type_names( $self->{session}, "eprint" );

		my $actual = [ ( !defined $value || $value eq "" ?
			$eprint_types[0] : $value ) ];
		my $height = ( $EPrints::HTMLRender::list_height_max < $#eprint_types+1 ?
		               $EPrints::HTMLRender::list_height_max : $#eprint_types+1 );

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>\@eprint_types,
			-default=>$actual,
			-size=>$height,
			-labels=>$labels );
	}
	elsif( $type eq "subject" )
	{
		my $subject_list = EPrints::SubjectList->new( $value );

		# If in the future more user-specific subject tuning is needed,
		# will need to put the current user in the place of undef.
		my( $sub_tags, $sub_labels );
		
		if( $field->{showall} )
		{
			( $sub_tags, $sub_labels ) = EPrints::Subject::all_subject_labels( 
				$self->{session} ); 
		}
		else
		{			
			( $sub_tags, $sub_labels ) = EPrints::Subject::get_postable( 
				$self->{session}, 
				EPrints::User::current_user( $self->{session} ) );
		}

		my $height = ( $EPrints::HTMLRender::list_height_max < $#{$sub_tags}+1 ?
		               $EPrints::HTMLRender::list_height_max : $#{$sub_tags}+1 );

		my @selected_tags = $subject_list->get_tags();

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>$sub_tags,
			-default=>\@selected_tags,
			-size=>$height,
			-multiple=>( $field->{multiple} ? "true" : undef ),
			-labels=>$sub_labels );
	}
	elsif( $type eq "name" )
	{
		# Get the names out
		my @names = EPrints::Name::extract( $value );

		my $boxcount = $self->{nameinfo}->{"name_boxes_$field->{name}"};

		if( defined $self->{nameinfo}->{"name_more_$field->{name}"} )
		{
			$boxcount += $EPrints::HTMLRender::add_boxes;
		}

		# Ensure at least 1...
		$boxcount = 1 if( !defined $boxcount );
		# And that there's enough to fit all the names in
		$boxcount = $#names+1 if( $boxcount < $#names+1 );

		# Render the boxes
		$html  = "<table border=0><tr><th>";
		$html .= $self->{session}->phrase( "H:surname" );
		$html .= "</th><th>";
		$html .= $self->{session}->phrase( "H:first_names" );
		$html .= "</th>";
		
		my $i;
		for( $i = 0; $i < $boxcount; $i++ )
		{
			my( $surname, $firstnames );
			
			if( $i <= $#names )
			{
				( $surname, $firstnames ) = @{$names[$i]};
			}
					
			$html .= "</tr>\n<tr><td>";
			$html .= $self->{query}->textfield(
				-name=>"name_surname_$i"."_$field->{name}",
				-default=>$surname,
				-size=>$EPrints::HTMLRender::form_name_width,
				-maxlength=>$EPrints::HTMLRender::field_max );
			$html .= "</td><td>";
			$html .= $self->{query}->textfield(
				-name=>"name_firstname_$i"."_$field->{name}",
				-default=>$firstnames,
				-size=>$EPrints::HTMLRender::form_name_width,
				-maxlength=>$EPrints::HTMLRender::field_max );
			$html .= "</td>";
		}
		
		if( $field->{multiple} )
		{
			$html .= "<td>".$self->named_submit_button( 
				"name_more_$field->{name}",
				$self->{session}->phrase( "F:more_spaces" ) );
			$html .= $self->hidden_field( "name_boxes_$field->{name}", $boxcount );
			$html .= "</td>";
		}
		
		$html .= "</tr>\n</table>\n";
	}
	elsif( $type eq "username" )
	{
		# Get the usernames out
		my @usernames = EPrints::User::extract( $value );

		my $boxcount = $self->{usernameinfo}->{"username_boxes_$field->{name}"};

		if( defined $self->{usernameinfo}->{"username_more_$field->{name}"} )
		{
			$boxcount += $EPrints::HTMLRender::add_boxes;
		}

		# Ensure at least 1...
		$boxcount = 1 if( !defined $boxcount );
		# And that there's enough to fit all the usernames in
		$boxcount = $#usernames+1 if( $boxcount < $#usernames+1 );

		# Render the boxes
		$html = "<table border=0><tr><th>";
		$html.= $self->{session}->phrase( "H:username_title" );
		$html.= "</th>";
		
		my $i;
		for( $i = 0; $i < $boxcount; $i++ )
		{
			my $username;	
			if( $i <= $#usernames )
			{
				( $username ) = $usernames[$i];
			}
					
			$html .= "</tr>\n<tr><td>";
			$html .= $self->{query}->textfield(
				-name=>"username_$i"."_$field->{name}",
				-default=>$username,
				-size=>$EPrints::HTMLRender::form_username_width,
				-maxlength=>$EPrints::HTMLRender::field_max );
			$html .= "</td>";
		}
		
		if( $field->{multiple} )
		{
			$html .= "<td>".$self->named_submit_button( 
				"username_more_$field->{name}",
				$self->{session}->phrase( "F:more_spaces" ) );
			$html .= $self->hidden_field( "username_boxes_$field->{name}", $boxcount );
			$html .= "</td>";
		}
		
		$html .= "</tr>\n</table>\n";
	}
	else
	{
		$html = "N/A";

		EPrints::Log::log_entry( "L:input_field_err" , { type=>$type } );
	}
	
	return( $html );
}


######################################################################
#
# render_form( $fields,              #array_ref
#              $values,              #hash_ref
#              $show_names,
#              $show_help,
#              $submit_buttons,      #array_ref
#              $hidden_fields,       #hash_ref
#              $dest
#
#  Renders an HTML form. $fields is a reference to metadata fields
#  in the usual format. $values should map field names to existing values.
#  This function also puts in a hidden parameter "seen" and sets it to
#  true. That way, a calling script can check the value of the parameter
#  "seen" to see if the users seen and responded to the form.
#
#  Submit buttons are specified in a reference to an array of names.
#  If $submit_buttons isn't passed in (or is undefined), a simple
#  default "Submit" button is slapped on.
#
#  $dest should contain the URL of the destination
#
######################################################################

sub render_form
{
	my( $self, $fields, $values, $show_names, $show_help, $submit_buttons,
	    $hidden_fields, $dest ) = @_;

	my $query = $self->{query};
	
	print $self->start_form( $dest );

	print "<CENTER><P><TABLE BORDER=0>\n";

	foreach (@$fields)
	{
		print $self->input_field_tr( $_,
		                             $values->{$_->{name}},
		                             $show_names,
		                             $show_help );
	}

	print "</TABLE></P></CENTER>\n";

	# Hidden field, so caller can tell whether or not anything's
	# been POSTed
	print $self->hidden_field( "seen", "true" );

	if( defined $hidden_fields )
	{
		foreach (keys %{$hidden_fields})
		{
			print $self->hidden_field( $_, $hidden_fields->{$_} );
		}
	}

	print "\n<CENTER>";

	print $self->submit_buttons( $submit_buttons );

	print "</CENTER>\n";
	print $self->end_form();
}


######################################################################
#
# $html = input_field_tr( $field, $value, $show_names, $show_help )
#
#  Write a table row with the given field and value.
#
######################################################################

sub input_field_tr
{
	my( $self, $field, $value, $show_names, $show_help ) = @_;
	
	my $html;

	# Field name should have a star next to it if it is required
	my $required_string = "";
	$required_string = "*"
		if( $field->{required} && !defined $no_asterisk{$field->{type}} );

	my $colspan = ($show_names ? " COLSPAN=2" : "" );
	my $align = ($show_names ? "" : " ALIGN=CENTER" );
	
	if( $show_help && defined $field->{help} )
	{
		$html .= "<TR><TD$colspan>&nbsp;</TD></TR>\n";
		$html .= "<TR><TD$colspan><CENTER><EM>$field->{help}</EM></CENTER>".
			"</TD></TR>\n";
	}

	$html .= "<TR><TD$align>";

	$html .= "<STRONG>".$field->displayname( $self->{session} )."$required_string</STRONG></TD><TD>" if( $show_names );

	$html .= $self->input_field( $field, $value );

	$html .= "</TD></TR>\n";

	return( $html );
}	

######################################################################
#
# $html = named_submit_button( $name, $value )
#
#  Returns HTML for a single submit button with a given name and value
#
######################################################################

sub named_submit_button
{
	my( $self, $name, $value ) = @_;
	
	return( $self->{query}->submit( -name=>$name, -value=>$value ) );
}


######################################################################
#
# $html = start_form( $dest )
#
#  Return (multipart) form preamble.
#
######################################################################

sub start_form
{
	my( $self, $dest ) = @_;
	
	if( defined $dest )
	{
		return( $self->{query}->start_multipart_form( -action=>$dest ) );
	}
	else
	{
		return( $self->{query}->start_multipart_form() );
	}
}




######################################################################
#
# $html = hidden_field( $name, $value )
#
#  Insert a hidden field, for passing around state information. If
#  $value is undefined, the hidden field will inherit the value from
#  the last script invocation.
#
######################################################################

sub hidden_field
{
	my( $self, $name, $value ) = @_;
die"nope";
	
	return( $self->{query}->hidden( -name=>$name,
	                                -default=>$value,
	                                -override=>1 ) ) if( defined $value );

	return( $self->{query}->hidden( -name=>$name ) );
}


######################################################################
#
# $html = upload_field( $name )
#
#  Return the HTML for a file upload field with the given name.
#
######################################################################

sub upload_field
{
	my( $self, $name ) = @_;
	
	return( $self->{query}->filefield(
		-name=>$name,
		-default=>"",
		-size=>$EPrints::HTMLRender::form_width,
		-maxlength=>$EPrints::HTMLRender::field_max ) );
}

######################################################################
#
# $seen = seen_form()
#
#  Returns 1 if form data has been posted; i.e. if the script has already
#  been called and the user has entered data and clicked "submit."
#
######################################################################

sub seen_form
{
	my( $self ) = @_;
	
	my $result = 0;

	$result = 1 if( defined $self->{query}->param( 'seen' ) &&
	                $self->{query}->param( 'seen' ) eq 'true' );

	return( $result );
}




######################################################################
#
# redirect( $url )
#
#  Redirects the browser to $url.
#
######################################################################

sub redirect
{
	my( $self, $url ) = @_;

	# Write HTTP headers if appropriate
	unless( $self->{offline} )
	{
		# For some reason, redirection doesn't work with CGI::Apache.
		# We have to use CGI.
		print $self->{query}->redirect( -uri=>$url );
	}

}




######################################################################
#
# set_param( $name, $value )
#
#  Set a query parameter, in case you want to change the default
#  for a form.
#
######################################################################

sub set_param
{
	my( $self, $name, $value ) = @_;

	$self->{query}->param( -name=>$name, -value=>$value );
}


######################################################################
#
# $value = form_value( $field )
#
#  A complement to param(). This reads in values from the form,
#  and puts them back into a value appropriate for the field type.
#
######################################################################

sub form_value
{
	my( $self, $field ) = @_;
	
	my $value = undef;
	
	if( $field->{type} eq "pagerange" )
	{
		my $from = $self->param( "$field->{name}_from" );
		my $to = $self->param( "$field->{name}_to" );

		if( !defined $to || $to eq "" )
		{
			$value = $from;
		}
		else
		{
			$value = $from . "-" . $to;
		}
	}
	elsif( $field->{type} eq "boolean" )
	{
		my $form_val = $self->param( $field->{name} );
		$value = ( defined $form_val ? "TRUE" : "FALSE" );
	}
	elsif( $field->{type} eq "date" )
	{
		my $day = $self->param( "$field->{name}_day" );
		my $month = $self->param( "$field->{name}_month" );
		my $year = $self->param( "$field->{name}_year" );

		if( defined $day && $month ne "00" && defined $year )
		{
			$value = $year."-".$month."-".$day;
		}
	}
	elsif( $field->{type} eq "set" )
	{
		my @tags = $self->{query}->param( $field->{name} );

		if( scalar @tags > 0 )
		{
			$value = join ",", @tags;
			$value = ":$value:";
		}
	}
	elsif( $field->{type} eq "subject" )
	{
		my $subject_list = EPrints::SubjectList->new();

		my @tags = $self->{query}->param( $field->{name} );
		
		if( scalar @tags > 0 )
		{
			$subject_list->set_tags( \@tags );

			$value = $subject_list->toString();
		}
		else
		{
			$value = undef;
		}
	}
	elsif( $field->{type} eq "name" )
	{
		my $i = 0;
		my $total = ( $field->{multiple} ? 
			$self->param( "name_boxes_$field->{name}" ) : 1 );
		
		for( $i=0; $i<$total; $i++ )
		{
			my $surname = $self->param( "name_surname_$i"."_$field->{name}" );
			if( defined $surname && $surname ne "" )
			{
				$value = EPrints::Name::add_name( $value,
					$surname,
					$self->param( "name_firstname_$i"."_$field->{name}" ) );
			}
		}
	}
	elsif( $field->{type} eq "username" )
	{
		my $i = 0;
		my $total = ( $field->{multiple} ? 
			$self->param( "username_boxes_$field->{name}" ) : 1 );
		$value = "";	
		for( $i=0; $i<$total; $i++ )
		{
			my $username = $self->param( "username_$i"."_$field->{name}" );
			if( defined $username && $username ne "" )
			{
				$value.= ":$username";
			}
		}
		$value .= ":" if ( $value ne "" );
	}
	else
	{
		$value = $self->param( $field->{name} );
		$value = undef if( defined $value && $value eq "" );
	}
	
	return( $value );
}


######################################################################
#
# clear()
#
#  Clears the form data.
#
######################################################################

sub clear
{
	my( $self ) = @_;
	
	$self->{query}->delete_all();
}



######################################################################
#
# $html = render_eprint_full( $eprint, $for_staff )
#
#  Return the EPrint, with all appropriate fields and formats
#  displayed.  Delegates to the site-specific routine to display the
#  record itself. If $for_staff is non-zero, then additional information
#  may be displayed, for instance the suggested new subject categories.
#
######################################################################

sub render_eprint_full
{
	my( $self, $eprint, $for_staff ) = @_;

	my $html = $self->{session}->{site}->eprint_render_full( $eprint,
	                                                         $for_staff );

	return( $html );
}


######################################################################
#
# $citation = render_eprint_citation( $eprint, $html, $linked )
#
#  Render a citation for the given EPrint. If $html is non-zero, the 
#  citation will be rendered in HTML, otherwise it will just be plain
#  text. If $linked and $html are non-zero, the citation will be
#  rendered as a link to the static page.
#
######################################################################

sub render_eprint_citation
{
	my( $self, $eprint, $html, $linked ) = @_;
$self->{session}->bomb();
	
	my $citation = $self->{session}->{site}->eprint_render_citation( $eprint,
	                                                                 $html );
	if( $html && $linked )
	{
		$citation = "<A HREF=\"".$eprint->static_page_url()."\">$citation</A>";
	}
	
	return( $citation );
}


######################################################################
#
# $html = render_user( $user, $public )
#
#  Render a user as HTML. if $public==1, only public fields
#  will be shown.
#
######################################################################

sub render_user
{
	my( $self, $user, $public ) = @_;

	return( $self->{session}->{site}->user_render_full( $user, $public ) );
}



######################################################################
#
#  $html = write_version_thread( $eprint, $field )
#
#   Returns HTML that writes a nice threaded display of previous versions
#   and future ones.
#
######################################################################

sub write_version_thread
{
	my( $self, $eprint, $field ) = @_;

	my $html;

	my $first_version = $eprint->first_in_thread( $field );
	
	$html .= "<UL>\n";
	$html .= $self->_write_version_thread_aux( $first_version, $field, $eprint );
	$html .= "</UL>\n";
	
	return( $html );
}

sub _write_version_thread_aux
{
	my( $self, $eprint, $field, $eprint_shown ) = @_;
	
	my $html = "<LI>";

	# Only write a link if this isn't the current
	$html .= "<A HREF=\"".$eprint->static_page_url()."\">"
		if( $eprint->{eprintid} ne $eprint_shown->{eprintid} );
	
	# Write the citation
	my $citation_spec =
		$self->{session}->{site}->{thread_citation_specs}->{$field->{name}};

	$html .= EPrints::Citation::render_citation( $eprint->{session},
	                                             $citation_spec,
	                                             $eprint,
	                                             1 );

	# End of the link if appropriate
	$html .= "</A>" if( $eprint->{eprintid} ne $eprint_shown->{eprintid} );

	# Show the current
	if( $eprint->{eprintid} eq $eprint_shown->{eprintid} ) 
	{
		$html .= " <strong>[";
		$html .= $self->{session}->phrase( "H:curr_disp" );
		$html .= "]</strong>";
	}
	
	# Are there any later versions in the thread?
	my @later = $eprint->later_in_thread( $field );
	if( scalar @later > 0 )
	{
		# if there are, start a new list
		$html .= "\n<UL>\n";
		foreach (@later)
		{
			$html .= $self->_write_version_thread_aux(
				$_,
				$field,
				$eprint_shown );
		}
		$html .= "</UL>\n";
	}
	$html .= "</LI>\n";
	
	return( $html );
}


######################################################################
#
# $html = render_deleted_eprint( $deletion_record )
#
#  Render an appropriate error saying that the eprint the user is
#  trying to access has been removed, and to point to the replacement
#  if one exists.
#
######################################################################

sub render_deleted_eprint
{
	my( $self, $deletion_record ) = @_;
	
	my $replacement_eprint;
	
	$replacement_eprint = new EPrints::EPrint(
		$self->{session},
		EPrints::Database::table_name( "archive" ),
		$deletion_record->{replacement} )
		if( defined $deletion_record->{replacement} );
	
	my $html = $self->start_html( 
		$self->{session}->phrase( "H:eprint_gone_title" ) );
	
	$html .= "<P>";
	$html .= $self->{session}->phrase( "H:eprint_gone" );
	$html .= "</P>\n";
	
	if( defined $replacement_eprint )
	{
		$html .= "<P>";
		$html .= $self->{session}->phrase( "H:later_version" );
		$html .= "</P>\n";
		$html .= "<P ALIGN=CENTER>";

		$html .= $self->render_eprint_citation(
			$replacement_eprint,
			1,
			1 );
		
		$html .= "</P>\n";
	}
	
	$html .= $self->end_html();

	return( $html );
}



1; # For use/require success
