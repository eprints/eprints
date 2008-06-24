
package EPrints::Plugin::Screen::Import;

use EPrints::Plugin::Screen;

use Fcntl qw(:DEFAULT :seek);
use File::Temp;

our $MAX_ERR_LEN = 1024;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ test import /];

	$self->{appears} = [
		{
			place => "item_tools",
			position => 200,
		}
	];

	return $self;
}

sub properties_from
{

	my( $self ) = @_;
	
	$self->SUPER::properties_from;

	my $pluginid = $self->{session}->param( "pluginid" );

	my $import_documents = $self->{session}->param( "import_documents" );
	if( defined($import_documents) && $import_documents eq "yes" )
	{
		$import_documents = 1;
	}
	else
	{
		$import_documents = 0;
	}
	
	if( defined $pluginid )
	{
		my $plugin = $self->{session}->plugin(
			$pluginid,
			session => $self->{session},
			dataset => $self->{session}->get_repository->get_dataset( "inbox" ),
			processor => $self->{processor},
			import_documents => $import_documents,
		);
		if( !defined $plugin || $plugin->broken )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		my $req_plugin_type = "list/eprint";
		unless( $plugin->can_produce( $req_plugin_type ) )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		$self->{processor}->{plugin} = $plugin;

	}
}

sub can_be_viewed
{
	my( $self ) = @_;
	return $self->allow( "create_eprint" );
}

sub allow_test
{
	my( $self ) = @_;
	return $self->can_be_viewed;
}

sub allow_import
{
	my( $self ) = @_;
	return $self->allow_test;
}

sub action_test
{
	my ( $self ) = @_;

	my $tmp_file = $self->make_tmp_file;
	return if !defined $tmp_file;

	$self->_import( 1, 0, $tmp_file ); # dry run with messages

	undef $tmp_file;
}

sub action_import
{
	my ( $self ) = @_;

	my $tmp_file = $self->make_tmp_file;
	return if !defined $tmp_file;

	my $ok = $self->_import( 1, 1, $tmp_file ); # quiet dry run
	$self->_import( 0, 0, $tmp_file ) if $ok; # real run with messages

	undef $tmp_file;

	$self->{processor}->{screenid} = "Items";
}


sub make_tmp_file
{
	my ( $self ) = @_;

	my $tmp_file;

	my $import_fh = $self->{session}->{query}->upload( "import_filename" );
	my $import_data = $self->{session}->param( "import_data" );

	if( defined $import_fh )
	{
		$tmp_file = $import_fh;
	}
	elsif( defined $import_data && length($import_data) )
	{
		# Write import records to temp file
		$tmp_file = File::Temp->new;
		$tmp_file->autoflush;

		# Write a Byte Order Mark for utf-8
		# (the form is set to utf-8)
		binmode($tmp_file);
		print $tmp_file pack("CCC", 0xef, 0xbb, 0xbf);
		print $tmp_file $import_data;
	}
	else
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "nothing_to_import" ) );
	}

	return $tmp_file;
}

sub _import
{
	my( $self, $dryrun, $quiet, $tmp_file ) = @_;

	seek($tmp_file, 0, SEEK_SET);

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );
	my $user = $self->{processor}->{user};

	my $plugin = $self->{processor}->{plugin};

	my $handler = EPrints::Plugin::Screen::Import::Handler->new(
		processor => $self->{processor},
		user => $user,
		quiet => $quiet,
	);

	$plugin->{Handler} = $handler;
	$plugin->{parse_only} = $dryrun;

	my $err_file = File::Temp->new(
		UNLINK => 1
	);

	# We'll capture anything from STDERR that an import library may
	# spew out
	{
	# Perl complains about OLD_STDERR being used only once with warnings
	no warnings;
	open(OLD_STDERR, ">&STDERR") or die "Failed to save STDERR";
	}
	open(STDERR, ">$err_file") or die "Failed to redirect STDERR";

	my @problems;

	# Don't let an import plugin die() on us
	eval {
		$plugin->input_fh(
			dataset=>$ds,
			fh=>$tmp_file,
			user=>$user,
		);
	};
	push @problems, "Unhandled exception in ".$plugin->{id}.": $@" if $@;

	my $count = $dryrun ? $handler->{parsed} : $handler->{wrote};

	open(STDERR,">&OLD_STDERR") or die "Failed to restore STDERR";

	seek( $err_file, 0, SEEK_SET );

	my $err = "";

	while(<$err_file>)
	{
		$_ =~ s/\s+$//;
		next unless length($_);
		$err .= "$_\n";
		last if length($err) > $MAX_ERR_LEN;
	}

	if( length($err) )
	{
		push @problems, "Unhandled warning in ".$plugin->{id}.": $err";
	}

	for(@problems)
	{
		s/^(.{$MAX_ERR_LEN}).*$/$1 .../s;
		s/\t/        /g; # help _mktext out a bit
		my @lines = EPrints::DataObj::History::_mktext( $session, $_, 0, 0, 80 );
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( join( "\n", @lines )));
		$self->{processor}->add_message( "warning", $pre );
	}

	my $ok = (scalar(@problems) == 0 and $count > 0);

	if( $dryrun )
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $self->html_phrase(
				"test_completed", 
				count => $session->make_text( $count ) ) ) unless $quiet;
		}
		else
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( 
				"test_failed", 
				count => $session->make_text( $count ) ) );
		}
	}
	else
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $self->html_phrase( 
				"import_completed", 
				count => $session->make_text( $count ) ) );
		}
		else
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( 
				"import_failed", 
				count => $session->make_text( $count ) ) );
		}
	}

	return $ok;
}

sub redirect_to_me_url { }

sub render
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );

	my $page = $session->make_doc_fragment;

	# Preamble
	$page->appendChild( $self->html_phrase( "intro" ) );

	my $form =  $session->render_form( "post" );
	$form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$page->appendChild( $form );

	my $table = $session->make_element( "table", width=>"100%" );

	my $frag = $session->make_doc_fragment;
	my $textarea = $frag->appendChild( $session->make_element(
		"textarea",
		name => "import_data",
		rows => 10,
		cols => 50,
		wrap => "virtual" ) );
	if( defined(my $import_data = $session->param( "import_data" )) )
	{
		$textarea->appendChild( $session->make_text( $import_data ) );
	}
	$frag->appendChild( $session->make_element( "br" ) );
	$frag->appendChild( $session->make_element( "br" ) );
	$frag->appendChild( $session->render_upload_field( "import_filename" ) );

	$table->appendChild( $session->render_row_with_help(
		help => $session->make_doc_fragment,
		label => $self->html_phrase( "step1" ),
		class => "ep_first",
		field => $frag,
	));
	
	my @plugins = $session->plugin_list( 
			type=>"Import",
			is_advertised=>1,
			is_visible=>"all",
			can_produce=>"list/".$ds->confid );

	my $select = $session->make_element( "select", name => "pluginid" );
	$table->appendChild( $session->render_row_with_help(
		help => $session->make_doc_fragment,
		label => $self->html_phrase( "step2" ),
		field => $select,
	));
	
	for( @plugins )
	{
		my $plugin = $session->plugin( $_,
			processor => $self->{processor},
		);
		next if $plugin->broken;
		my $opt = $session->make_element( "option", value => $_  );
		$opt->setAttribute( "selected", "selected" ) if $self->{processor}->{plugin} && $_ eq $self->{processor}->{plugin}->get_id;
		$opt->appendChild( $plugin->render_name );
		$select->appendChild( $opt );
	}

	if( $session->get_repository->get_conf( "enable_web_imports" ) )
	{
		my $checkbox = $session->render_input_field( type=>"checkbox", name=>"import_documents", value=>"yes", class=>"ep_form_checkbox" );
		$table->appendChild( $session->render_row_with_help(
			help => $session->make_doc_fragment,
			label => $self->html_phrase( "import_documents" ),
			field => $checkbox,
		));
	}

	$form->appendChild( $session->render_toolbox( undef, $table ) );

	$form->appendChild( $session->render_action_buttons( 
		_class => "ep_form_button_bar",
		test => $self->phrase( "action:test:title" ), 
		import => $self->phrase( "action:import:title" ) ) );

	return $page;

}

package EPrints::Plugin::Screen::Import::Handler;

sub new
{
	my( $class, %self ) = @_;

	$self{wrote} = 0;
	$self{parsed} = 0;

	bless \%self, $class;
}

sub message
{
	my( $self, $type, $msg ) = @_;

	unless( $self->{quiet} )
	{
		$self->{processor}->add_message( $type, $msg );
	}
}

sub parsed
{
	my( $self, $epdata ) = @_;

	$self->{parsed}++;
}

sub object
{
	my( $self, $dataset, $dataobj ) = @_;

	$self->{wrote}++;

	if( $dataset->confid eq "eprint" )
	{
		$dataobj->set_value( "userid", $self->{user}->get_id );
		$dataobj->commit;
	}	
}

1;
