#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: Dispatch.pm (Beta 1.0)
#
# Description:
#       Code for defining and calling Dienst handlers.
#
#############################################################################
# Copyright (C) 2000, Cornell University, Xerox Incorporated                #
#                                                                           #
# This software is copyrighted by Cornell University (CU), and ownership of #
# this software remains with CU.                                            #
#                                                                           #
# This software was written as part of research work by:                    #
#   Cornell Digital Library Research Group                                  #
#   Department of Computer Science                                          #
#   Upson Hall                                                              #
#   Ithaca, NY 14853                                                        #
#   USA                                                                     #
#   email: info@prism.cornell.edu                                           #
# 									    #
# Pursuant to government funding guidelines, CU grants you a noncommercial, #
# nonexclusive license to use this software for academic, research, and	    #
# internal business purposes only.  There is no fee for this license.	    #
# You may distribute binary and source code to third parties provided	    #
# that this copyright notice is included with all copies and that no	    #
# charge is made for such distribution.					    #
# 									    #
# You may make and distribute derivative works providing that: 1) You	    #
# notify the Project at the above address of your intention to do so; and   #
# 2) You clearly notify those receiving the distribution that this is a	    #
# modified work and not the original version as distributed by the Cornell  #
# Digital Library Research Group.					    #
# 									    #
# Anyone wishing to make commercial use of this software should contact	    #
# the Cornell Digital Library Rsearch Group at the above address.	    #
# 									    #
# This software was created as part of an ongoing research project and is   #
# made available strictly on an "AS IS" basis.  NEITHER CORNELL UNIVERSITY  #
# NOR ANY OTHER MEMBERS OF THE CS-TR PROJECT MAKE ANY WARRANTIES, EXPRESSED #
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY IMPLIED WARRANTY OF	    #
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.  NEITHER CORNELL	    #
# NOR ANY OTHER MEMBERS OF THE CS-TR PROJECT SHALL BE LIABLE TO USERS OF    #
# THIS SOFTWARE FOR ANY INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES OR    #
# LOSS, EVEN IF ADVISED OF THE POSSIBILITY THEREOF.			    #
# 									    #
# This work was supported in part by the Defense Advanced Research Projects #
# Agency under Grant No. MDA972-92-J-1029 and Grant No. N66001-98-1-8908    #
# with the Corporation for National Research Initiatives (CNRI).  Support   #
# was also provided by the National Science Foundation under Grant No.      #
# IIS-9817416. Its content does not necessarily reflect                     #
# the position or the policy of the Government or CNRI, and no official	    #
# endorsement should be inferred.					    #
#############################################################################

package Dispatch;

use strict;

sub new {
    my $class = shift;
    my %params = @_;
    my $self = {};

    bless $self, $class;

    return $self;
}

# Methods for registering services, verbs, and verb versions

sub Register_Service_Class {
    my ($self, $service_info) = @_;

    return 0 if (! ref $self);
    
    if (!defined %{$self->{'service-classes'}}) {
  	%{$self->{'service-classes'}} = ();
    }

    if (!grep /$service_info->{'name'}/, keys %{$self->{'service-classes'}}) {
	$self->{'service-classes'}{$service_info->{'name'}} = $service_info;
    }
}

sub list_services {
    my ($self) = @_;
    keys %{$self->{'service-classes'}};
}

sub get_service_info {
    my ($self, $service_name) = @_;

    $self->{'service-classes'}{"$service_name"};
}

sub get_class_for_service {
    my ($self, $service) = @_;

    $self->{'service-to-class-map'}{$service};
}     
sub get_class_for_verb {
    my ($self, $verb) = @_;

    $self->{'verb-to-class-map'}{$verb};
}     
sub is_service_class_validp {
    my ($self, $class) = @_;
    $self->{'service-classes'}{$class} ? 1 : 0;
}

# Is this a valid service?
sub is_service_validp {
    my ($self, $service) = @_;
    get_class_for_service ($self, $service);
}


# The assoc array %Dispatch tells us how to handle a request.

# Establishes a binding for a verb.  
sub Register {
    my ($self, $specification) = @_;
    my $k;

    if (! $specification) {
	print "Null Spec\n";
	return 0;
    }
    if (!defined $specification->{'osyntax'}) {
	$specification->{'osyntax'} = "Keyword";}

    if (&dienst::list_position (\@dienst::supported_optional_syntaxes, 
			$specification->{'osyntax'}) < 0) {
	print "Error: OS Syntax\n";
	return 0;
    }	
    if (!$self->is_service_class_validp ($specification->{'service-class'})) {
	print "Error: invalid service: $specification->{'service-class'}".
	    "$specification->{'verb-class'}\n";
	return 0;
    }

    # Create the data structure
    my $service_class = $specification->{'service-class'}; # String
    my $verb_class = $specification->{'verb-class'}; # String
    my $versions = $specification->{'versions'}; # Hash Reference

    if (! $self->{'dispatch'}) {
	$self->{'dispatch'} = {};
    }

    # If service class exists, then replace/add data to structure
     if ($self->{$service_class, $verb_class} && 
	$self->{$service_class, $verb_class}{'versions'}) {
	# Do we want to allow description updates after the first?
	my %vers = %{$versions};
	foreach $k (keys %vers) {
	    print "Adding $k ($service_class, $verb_class)\n";
	    $self->{$service_class, $verb_class}{'versions'}{$k} = $vers{$k};
	    my $iservice = $vers{$k}->{'service'};
	    my $iverb = $vers{$k}->{'verb'};
	    my $iversion = $vers{$k}->{'version'};
	    if ($vers{$k}->{'handler'}) {
		$self->{'dispatch'}{$iservice, $iverb, $iversion} = $vers{$k};
		$self->{'verb-to-class-map'}{$iverb} = $verb_class;
		$self->{'service-to-class-map'}{$iservice} = $service_class;
	    }
	}

    } else {
	if ($specification->{'description'}) {
	    $self->{$service_class, $verb_class}{'description'} = $specification->{'description'};
	} else {
               # Should we issue a warning?
               # print "Description not defined for $service_class, $verb_class\n";
	}
	$self->{$service_class, $verb_class} = $specification;
	my %vers = %{$specification->{'versions'}}; # 
	foreach $k (keys %vers) {
	    my $iservice = $vers{$k}->{'service'};
	    my $iverb = $vers{$k}->{'verb'};
	    my $iversion = $vers{$k}->{'version'}; # 
	    if ($vers{$k}->{'handler'}) {
		$self->{'dispatch'}{$iservice, $iverb, $iversion} = $vers{$k};
		$self->{'verb-to-class-map'}{$iverb} = $verb_class;
		$self->{'service-to-class-map'}{$iservice} = $service_class;
	    }
	}
    }
}

sub Print_Class {
    my ($self, $service, $class) = @_;

    print "Service: $service\nClass: $class\n";
    print "Description: $self->{$service, $class}{'description'}\n";
    print "Implementations:\n";
    my (%versions) = %{$self->{$service, $class}{'versions'}};

    my ($v, $k);
    foreach $v (sort keys %versions) {
	my %info = %{$versions{$v}};
	print "\tImp: $v\n";
	foreach $k (keys %info) {
	    print "\t\tKey: $k Value: $info{$k}\n";
	}
    }
    print "End Print\n";
    print "\nDispatch Implementations:\n";
    foreach $k (keys %{$self->{'dispatch'}}) {
	print "Dispatch: $k\n";
    }
}


# A service/verb is valid if there's at least one supported version.
sub is_verb_validp {
    my ($self, $service, $verb) = @_;
    my (@list) = &implementation_verb_versions ($self, $service, $verb);
    ($#list > -1);
}

# Returns a list of verbs implemented by specified service
sub Dispatch_service_verbs {
    my ($self, $service) = @_;
    my (%verbs) = ();
    my ($info);
    foreach $info (keys %{$self->{'dispatch'}}) {
	my ($aservice, $averb, $version) = split ($;, $info);
	if ($service eq $aservice) {
	    $verbs{$averb} = 1;}}
    return keys %verbs;
}

sub list_verb_class_versions {
    my ($self, $service_class, $verb_class) = @_;
    my (@results, $v);
    foreach $v (keys %{$self->{$service_class, $verb_class}->{'versions'}}) {
	if (defined $self->{$service_class, $verb_class}{'versions'}->{$v}->{'handler'}) {
	    push @results, $v;
	}
    }
    @results;
}

sub list_all_verb_class_versions {
    my ($self, $service_class, $verb_class) = @_;
    my (@results, $v);
    foreach $v (keys %{$self->{$service_class, $verb_class}->{'versions'}}) {
	    push @results, $v;
    }
    @results;
}

# New 8/10/99 DLF
# Return hash with verb as key and $; separated versions as value
sub service_verb_versions {
    my ($self, $service, $verbs) = @_;
    my ($info);

    foreach $info (keys %{$self->{'dispatch'}}) {
	my ($aservice, $averb, $version) = split ($;, $info);
	if ($service eq $aservice) {
	    if (defined $$verbs{$averb}) {
		$$verbs{$averb} = 
		    join ($;, sort (split ($;, $$verbs{$averb}), $version));
	    } else {
		$$verbs{$averb} = $version;
	    }
	}
    }
}

# Return list of all versions of verb for which handlers exist.
sub implementation_verb_versions {
    my ($self, $service, $verb) = @_;
    my ($version, @list, $info);
    foreach $info (keys %{$self->{'dispatch'}}) {
	my ($aservice, $averb, $version) = split ($;, $info);
	if (($service eq $aservice) &&
	    ($verb eq $averb)) {
	    push (@list, $version);
	}
    }
    sort @list;
}

sub get_dispatch_info {
    my ($self) = @_;
    return %{$self->{'dispatch'}};
}

sub get_implementation_info {
    my ($self, $service, $verb, $version) = @_;

    if (defined ($self->{'dispatch'}{$service, $verb, $version})) {
	return %{$self->{'dispatch'}{$service, $verb, $version}};
    } else {
	return;
    }
}
sub get_service_verb_class_field {
    my ($self, $service_class, $verb_class, $field) = @_;

    return $self->{$service_class, $verb_class}{$field};
}
# Parse the path, separating the verb from the args.  Separate
# optional from required args.  Find the handler for the verb, and
# call it with the args plus an assoc array of the optional args.
sub dispatch_exists_p {
    my ($self, $path, $Context) = @_;
    my ($service, $version, $verb);

    if ($path =~ /\/Dienst\/([^\/?]+)\/([0-9]+\.[0-9]+)\/([^\/?]+)\/?(.*)$/) {
	$service = $1;
	$version = $2;
	$verb = $3;

	my %info = $self->get_implementation_info ($service, $verb, $version);

	if (! keys %info) {
	    return 0;
	} else {
	    return 1;
	}
    }
	0;
}

sub do_Dispatch_URL {
    my ($self, $path, $Context) = @_;
    my ($service, $version, $verb, $argsS, $info, $message); 
    my (@argsA) = ();
    
    my($Current_URL) = $path; # for bug messages

    if ($path =~ /\/Dienst\/([^\/?]+)\/([0-9]+\.[0-9]+)\/([^\/?]+)\/?(.*)$/) {
	$service = $1;
	$version = $2;
	$verb = $3;
	$argsS = $4;		# "/ncstrl.cornell/TR94-1418?abstract=Dienst"

	$Context->{'service'} = $service;
	$Context->{'version'} = $version;
	$Context->{'verb'} = $verb;

	my %info = $self->get_implementation_info ($service, $verb, $version);

	if (! %info) {
	    # implementaion not defined, try to return useful diagnostic
	    if ($self->is_service_validp ($service)) {
		if ($self->is_verb_validp ($service, $verb)) {
		    $message =
			"Bad version for $service/$verb: $version." 
			    . "  Valid versions are: " 
				. &dienst::NameList (&implementation_verb_versions ($self, $service, $verb)) . ".";
		} else {
		    $message = 
			"The $service service does not implement verb $verb";}}
	    else {
		$message = "Invalid service: $service";
	    }
	    return (501, $message);
	} else {

	    # Get the fixed arg list, the subroutine, and the method
	    # for parsing optional arguments
	    my $arglist = $info{'fixed'};
	    my $subr = $info{'handler'};
	    my $osyntax;
	    if (!$info{'osyntax'}) {
		my $service_class = $self->get_class_for_service ($info{'service'});
		my $verb_class = $self->get_class_for_verb ($info{'verb'});

		my $parent_osyntax = $self->get_service_verb_class_field 
		    ($service_class, $verb_class, "osyntax");
		if ($parent_osyntax) {
		    $osyntax = $parent_osyntax;
		} else {$osyntax = "Keyword";}
	    } else {
		$osyntax = $info{'osyntax'};
	    }

	    # Optional args are passed either as an assoc array or as
	    # list.  If the routine uses Keyword (or Multiple) osyntax,
	    # this is an assoc array.  If it specified "Positional"
	    # then it is a list.
	    my (@optionsA, %optionsH);	# passed to the subroutine
	    my ($optionsS);	# temp
	    # If there are optional args strip them off
	    if ($argsS =~ /^(.*)\?(.*)$/) {
		$optionsS = $2;
		$argsS = $1;

		# Parse them in the proper way.
		if ($osyntax eq "Keyword") {
		    %optionsH = &dienst::parse_options ($optionsS);}
		elsif ($osyntax eq "Multiple") {
		    %optionsH = &dienst::parse_options ($optionsS, $dienst::rs);}
		elsif ($osyntax eq "Positional") {
		    @optionsA = split (",", $optionsS);}
		else {
		    return (400, "Illegal argument syntax");
		}
	    }
	    else {
		@optionsA = ();
		%optionsH = ();}

	    # Parse the fixed arguments. This is a kludge and here's why:
	    # Dienst protocoll arguments are separated by a slash.  You might
	    # think then that we could `split' with slash to get the list of
	    # arguments, but unfortunately handles contain a slash.  separating
	    # naming authority from name.  Now you might think that the slashes
	    # would be encoded (as %2F) as per the HTTP spec, but there are two
	    # problems with this.  First, plenty of people are going to type in
	    # the URL without encoding the slash.  Now I would probably blow
	    # them off as losers for not reading the documentation, except that
	    # I would only do that if I could issue a reasonable error message,
	    # cause otherwise they'll just think Dienst sucks.  And it's almost
	    # as easy to just "handle" [sic] the problem as to make an error
	    # message.  But the second reason is even stronger: since Dienst is
	    # called via the CGI mechanism, the HTTP daemon has already decoded
	    # the escaped slashes anyway.  Now all this would not be so bad,
	    # since we could just take two args for the two parts of the
	    # handle, except that MIT (my beloved alma mater) has handles where
	    # the names themselves include slashes, so an MIT handle has an
	    # arbitrary number of parts.  Foo.  So therefore we have the
	    # following kludge, which will persist until the time when we stop
	    # using CGI as the mechanism for invoking Dienst.  (May that day
	    # come soon!) - Jim Davis, Nov 3 1995 

	    $message = "";

	  getargs: {
	    my (@arg_names) = split (":", $arglist);
	    my ($handle) = 0;
	    my (@fixed_args) = split ("/", $argsS);
	    my (@rargs) = ();
	    my ($arg_name);

	    # Process fixed arguments up to any handle, if present
	    # then skip to kludge below...

	    while  ($arg_name = shift @arg_names) {
		if ($arg_name eq "handle") {
		    $handle = 1;
		    last;}
		else {
		    if ($#fixed_args < 0) {
			$message = "Missing argument for $arg_name";
			last getargs;}
		    else {
			push (@argsA, shift @fixed_args);
		    }
		}
	    }

	    if ($handle) {

		# The handle has an unpredictable number of parts.  So
		# work backwards from the end, taking the remaining normal args,
		# and then whatever is left is the handle.

		# This while loop processes all arguments left after the
		# handle, in reverse order

		while  ($arg_name = pop @arg_names) {
		    if ($#fixed_args < 0) {
			$message = "Missing argument for handle";
			last getargs;}
		    else {
			push (@rargs, pop @fixed_args);}}


		# An identifier may or may not have a '/' in it.  In the case
		# where there is just one part then it defacto becomes the
		# the identifier argument.
		if ($#fixed_args == 0) {
		    push(@argsA, $fixed_args[0]);
		}
		# otherwise the identifier has at least one '/' in it so assume
		# that everything we have at this point is the identifier.
		else {
		    push (@argsA, join ("/", @fixed_args));
		}
		
		# Now put the post-handle args (which we collected in reverse order)
		# into the args list

		my ($arg);
		while ($arg = pop @rargs) {
		    push (@argsA, $arg);
		}
	    }
	    else {
		if ($#fixed_args > -1) {
		    # No handle, so anything left over is truly extra.
		    $message = "Dienst request has " . ($#fixed_args + 1).
			" extra ". 
			    &dienst::string_pluralize ("argument", ($#fixed_args + 1));
		    last getargs;
		}
	    }
	}			# end of get args

	    # At this point we have completed %optionsH and @argsA

	    if ($message) {
		return (400, $message);
	    } else {
		# Each handler gets two additional arguments, the
		# optional args and the Context.  The "Context"
		# includes info from HTTP headers.  If you need to use
		# anything from Context it's a bad sign, cause we
		# don't want any dependencies on HTTP.  Looking at the
		# remote host id is probably okay, cause that would
		# make sense even if we used different protocol.

		push (@argsA, \%optionsH);
		push (@argsA, $Context);

		# Call the subr.
		eval "&$subr(\@argsA);";

		if ($@ ne "") {	# error occurred
		    &dienst::program_error("Error while evaluating $subr $@");
		}
	    }
	}
    }
    else {
	return (400, "Unsupported or malformed request");}

    return (0,"");
}

# Create a protocol request
#
# Arguments:
#    1) Verb class version 
#    2) Service class
#    3) Verb class
#    4) Fixed Args
#    5) Optional Args
#    6) Positional Args
#
sub protocol_request {
    my ($self, $info) = @_;

    my $service_class = $info->{'service-class'};
    my $verb_class = $info->{'verb-class'};
    my $class_version = $info->{'class-version'};    
    my %vinfo;
    my %arguments;
    %arguments = %{$info->{'fixed'}} if ($info->{'fixed'});

    my $first_time = 1;

    my $arg;
    foreach $arg (keys %{$info->{'optional'}}) {
	if (!defined $arguments{$arg}) {
	    $arguments{$arg} = $info->{'optional'}{$arg};
	} else {
	    print "Argument is already defined: $arg\n";
	    return 0;
	}
    }

    if (!defined $self->is_service_class_validp ($service_class)) {
	print "Service does not exist\n";
    } 

    if (! defined %{$self->{$service_class, $verb_class}}) {
	print "ERROR: $service_class, $verb_class : Not defined\n";
	print "Service/Verb/Version not defined: trying autoload\n";
	my $mes = &Dispatch::load_protocol_for_service ($service_class);
	if ($mes) {print "$mes\n";}
	%vinfo = %{$self->{$service_class, $verb_class}{'versions'}};
	if (!defined $self->{$service_class, $verb_class}) {
	    return 0;
	}
    }

    %vinfo = %{$self->{$service_class, $verb_class}{'versions'}};
    if (!defined $vinfo{$class_version}) {
	if (defined $self->{$service_class, $verb_class}) {
	    my $msg = "Version not defined for $service_class, $verb_class : $class_version\n";
	    return (0, $msg);
	}
    }

    my %prot_spec = %{$vinfo{$class_version}};

    if (! defined $prot_spec{'request'} && defined $prot_spec{'conversion'}) {
	my $conv_sub = $prot_spec{'conversion'};
	my $func = "\&$conv_sub\(\$class_version, \\\%prot_spec,
                           \\\%arguments\)";
	my $status = eval $func; #XXX
	$first_time = 0;
    }

    # Now create protocol request
    my $base = $prot_spec{'request'};
    
    # Add fixed arguments 
    if ($prot_spec{'fixed'}) {
	my @fixed_arg_list = split (/:/, $prot_spec{'fixed'});
	my (@fixed_args, $error);
	foreach $a (@fixed_arg_list) {
	    # The argument exists
	    if ($arguments{"$a"}) {
		push @fixed_args, $arguments{"$a"};
	    # The argument requires a docid
	    } elsif ($a eq "docid" &&  !$arguments{'docid'} 
		     && $arguments{'handle'}) {
		# Need a better way to handle this
		$Dispatch::Publishers = new Publishers 
		    ('meta_file'=>'/tmp/meta_Dispatch_Pubs',
		     'log_file'=>"/tmp/meta_update_log",
                                'meta_server_host'=>'cs-tr',
                                'meta_server_port'=>80,
                                'meta_server_protocol'=>5.0);

		$arguments{'docid'} = $Dispatch::Publishers->handle_to_docid 
		    ("$arguments{'handle'}");
		push @fixed_args, $arguments{"$a"};

            # Conversion utility provided for generating missing arguments
	    } elsif ($prot_spec{'conversion'} && $first_time) {
		# pass the routine the class_version and arguments
		my $conv_sub = $prot_spec{'conversion'};
		my $func = "\&$conv_sub\(\$class_version, \\\%prot_spec,
                           \\\%arguments\)";
		my $status = eval $func; # XXX
		$first_time = 0;

		if ($arguments{"$a"}) {
		    push @fixed_args, $arguments{"$a"};
		} else {
		    $error .= "$a ";
		}

	    } else {
		$error .= "$a ";
	    }
	}
	if ($error) {
	    return (0, "Missing required fixed arguments: $error\n");
	}
	$base = sprintf $base, @fixed_args;
    }
    # Before we process optional arguments we must execute any conversion
    # subroutine to define possible missing options
    if ($prot_spec{'conversion'} && $first_time) {
	my $conv_sub = $prot_spec{'conversion'};
	my $func = "\&$conv_sub\(\$class_version, \\\%arguments\)";
	my $status = eval $func;
    }
    
    if ($prot_spec{'optional'}) {
	my @supported_options = split (/:/, $prot_spec{'optional'});
	my $option_string = add_options 
	    (\@supported_options, \%arguments);
	$base .= "?" . $option_string if ($option_string);
    }
    ($base, "", $prot_spec{'returns'});
}

sub load_protocol_for_service {
    my ($service) = @_;

    # Generate path to service
    my $path = $dienst::source_dir . "/" . "Services" . "/" . $service;
    if (! -e $path) {
	return ("Service not found on this system");
    }
    $path .= "/" . "$service" . "_protocol.pl";
    if (! -e $path) {
	print "Protocol specification missing for service $service at $path\n";
    }
    if (!do "$path") {
	print "Service protocol definition not found";
    }
    "";
}

sub add_options {
    my ($supported_options, $supplied_options) = @_;

    my ($string, $attr, $o);
    foreach $o (@$supported_options) {
	my $multi = ref $supplied_options->{$o};
	if (!$multi && $supplied_options->{$o}) {
	    $string .= "$o\=$supplied_options->{$o}\&";
	} elsif ($multi eq "ARRAY" && $supplied_options->{$o}) {
	    foreach $attr ( @{$supplied_options->{$o}} ) {
		$string .= "$o\=$attr\&";
	    }
	}
    }
    if ($string =~ /(\&)$/) {$string = $`;};
    $string;
}

sub contentType_to_format {
    my ($content_type, $version) = @_;
    my %MIME_to_Format = (
	'image/gif' => 'inline',
	'image/tiff' => 'scanned',
	'application/postscript' => 'postscript',
	'text/html' => 'html',
	'text/plain' => 'text'
    );
    if ($content_type =~ /^dienst\/(\w+)/) {
	$content_type = $1;
    }
    if ($version < 5.0 && defined $MIME_to_Format{$content_type}) {
	$content_type = $MIME_to_Format{$content_type};
    }
    $content_type;
}

## This is for the status request, for debugging
# Display all the available dispatch handlers
# Is this still used?
sub List_all_handlers {
    my ($self, $pattern, @list);
    my ($service, $verb, $version, $arglist, $subr, $prev_service);

    foreach $pattern (keys %{$self->{'dispatch'}}) {
	push (@list, $pattern);}

    print "<TABLE border>\n";
    print "<TR><TH>Verb<TH>Version and args<TH>Handler\n";
    foreach $pattern (sort @list) {
 	($service, $verb, $version) = split ($;, $pattern);
	($arglist, $subr) = split ($;, ${$self->{'dispatch'}}{$pattern});

	if ($service ne $prev_service) {
	    $prev_service = $service;
	    print "<TR><TH colspan=3>$service\n";

	}

	print "<TR>";
	print "<TD>", $verb, "<TD>", $version;
	print " (";
	my ($i) = 0;
	my ($arg);
	foreach $arg (split (":", $arglist)) {
	    if ($i > 0) {print ", ";}
	    print $arg;
	    $i++;}
	print ")";
	print "<TD><TT>", $subr, "</TT>\n";}
	print "</TABLE>";}

1;




