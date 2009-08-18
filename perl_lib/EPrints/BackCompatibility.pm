######################################################################
#
# EPrints::BackCompatibility
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


=pod

=head1 NAME

B<EPrints::BackCompatibility> - Provide compatibility for older versions of the API.

=head1 DESCRIPTION

A number of EPrints packages have been moved or renamed. This module
provides stub versions of these packages under there old names so that
existing code will require few or no changes.

It also sets a flag in PERL to think the packages have been loaded from
their original locations. This causes calls such as:

 use EPrints::Document;

to do nothing as they know the module is already loaded.

=over 4

=cut

use EPrints;

use strict;

######################################################################
=pod

=back

=cut

######################################################################

package EPrints::Document;

our @ISA = qw/ EPrints::DataObj::Document /;

$INC{"EPrints/Document.pm"} = "EPrints/BackCompatibility.pm";

sub create { EPrints::deprecated(); return EPrints::DataObj::Document::create( @_ ); }

sub docid_to_path { EPrints::deprecated(); return EPrints::DataObj::Document::docid_to_path( @_ ); }

######################################################################

package EPrints::EPrint;

our @ISA = qw/ EPrints::DataObj::EPrint /;

$INC{"EPrints/EPrint.pm"} = "EPrints/BackCompatibility.pm";

sub create { EPrints::deprecated(); return EPrints::DataObj::EPrint::create( @_ ); }
sub eprintid_to_path { EPrints::deprecated(); return EPrints::DataObj::EPrint::eprintid_to_path( @_ ); }

######################################################################

package EPrints::Subject;

our @ISA = qw/ EPrints::DataObj::Subject /;

$INC{"EPrints/Subject.pm"} = "EPrints/BackCompatibility.pm";

$EPrints::Subject::root_subject = "ROOT";
sub remove_all { EPrints::deprecated(); return EPrints::DataObj::Subject::remove_all( @_ ); }
sub create { EPrints::deprecated(); return EPrints::DataObj::Subject::create( @_ ); }
sub subject_label { EPrints::deprecated(); return EPrints::DataObj::Subject::subject_label( @_ ); }
sub get_all { EPrints::deprecated(); return EPrints::DataObj::Subject::get_all( @_ ); }
sub valid_id { EPrints::deprecated(); return EPrints::DataObj::Subject::valid_id( @_ ); }
sub children { EPrints::deprecated(); return EPrints::DataObj::Subject::get_children( $_[0] ); }

######################################################################

package EPrints::Subscription;

our @ISA = qw/ EPrints::DataObj::SavedSearch /;

$INC{"EPrints/Subscription.pm"} = "EPrints/BackCompatibility.pm";

sub process_set { EPrints::deprecated(); return EPrints::DataObj::SavedSearch::process_set( @_ ); }
sub get_last_timestamp { EPrints::deprecated(); return EPrints::DataObj::SavedSearch::get_last_timestamp( @_ ); }

######################################################################

package EPrints::User;

our @ISA = qw/ EPrints::DataObj::User /;

$INC{"EPrints/User.pm"} = "EPrints/BackCompatibility.pm";

sub create { EPrints::deprecated(); return EPrints::DataObj::User::create( @_ ); }
sub user_with_email { EPrints::deprecated(); return EPrints::DataObj::User::user_with_email( @_ ); }
sub user_with_username { EPrints::deprecated(); return EPrints::DataObj::User::user_with_username( @_ ); }
sub process_editor_alerts { EPrints::deprecated(); return EPrints::DataObj::User::process_editor_alerts( @_ ); }
sub create_user { EPrints::deprecated(); return EPrints::DataObj::User::create( @_ ); }

package EPrints::DataObj::User;
sub can_edit { EPrints::deprecated(); return $_->in_editorial_scope_of( $_[0] ); }

######################################################################

package EPrints::Utils;

sub send_mail { EPrints::deprecated(); return EPrints::Email::send_mail( @_ ); }
sub send_mail_via_smtp { EPrints::deprecated(); return EPrints::Email::send_mail_via_smtp( @_ ); }
sub send_mail_via_sendmail { EPrints::deprecated(); return EPrints::Email::send_mail_via_sendmail( @_ ); }
sub collapse_conditions { EPrints::deprecated(); return EPrints::XML::EPC::process( @_ ); }
sub render_date { EPrints::deprecated(); return EPrints::Time::render_date( @_ ); }
sub render_short_date { EPrints::deprecated(); return EPrints::Time::render_short_date( @_ ); }
sub datestring_to_timet { EPrints::deprecated(); return EPrints::Time::datestring_to_timet( @_ ); }
sub gmt_off { EPrints::deprecated(); return EPrints::Time::gmt_off( @_ ); }
sub get_month_label { EPrints::deprecated(); return EPrints::Time::get_month_label( @_ ); }
sub get_month_label_short { EPrints::deprecated(); return EPrints::Time::get_month_label_short( @_ ); }
sub get_date { EPrints::deprecated(); return EPrints::Time::get_date( @_ ); }
sub get_date_array { EPrints::deprecated(); return EPrints::Time::get_date_array( @_ ); }
sub get_datestamp { EPrints::deprecated(); return EPrints::Time::get_iso_date( @_ ); }
sub get_iso_date { EPrints::deprecated(); return EPrints::Time::get_iso_date( @_ ); }
sub get_timestamp { EPrints::deprecated(); return EPrints::Time::human_time( @_ ); }
sub human_time { EPrints::deprecated(); return EPrints::Time::human_time( @_ ); }
sub human_delay { EPrints::deprecated(); return EPrints::Time::human_delay( @_ ); }
sub get_iso_timestamp { EPrints::deprecated(); return EPrints::Time::get_iso_timestamp( @_ ); }


######################################################################

package EPrints::Archive;

our @ISA = qw/ EPrints::Repository /;

$INC{"EPrints/Archive.pm"} = "EPrints/BackCompatibility.pm";

######################################################################

package EPrints::Repository;

sub new_archive_by_id { EPrints::deprecated(); my $class= shift; return $class->new( @_ ); }

######################################################################

package EPrints::SearchExpression;

our @ISA = qw/ EPrints::Search /;

@EPrints::SearchExpression::OPTS = (
	"session", 	"dataset", 	"allow_blank", 	"satisfy_all", 	
	"fieldnames", 	"staff", 	"order", 	"custom_order",
	"keep_cache", 	"cache_id", 	"prefix", 	"defaults",
	"citation", 	"page_size", 	"filters", 	"default_order",
	"preamble_phrase", 		"title_phrase", "search_fields",
	"controls" );

$EPrints::SearchExpression::CustomOrder = "_CUSTOM_";

$INC{"EPrints/SearchExpression.pm"} = "EPrints/BackCompatibility.pm";

######################################################################

package EPrints::SearchField;

our @ISA = qw/ EPrints::Search::Field /;

$INC{"EPrints/SearchField.pm"} = "EPrints/BackCompatibility.pm";

######################################################################

package EPrints::SearchCondition;

our @ISA = qw/ EPrints::Search::Condition /;

$EPrints::SearchCondition::operators = {
	'CANPASS'=>0, 'PASS'=>0, 'TRUE'=>0, 'FALSE'=>0,
	'index'=>1, 'index_start'=>1,
	'='=>2, 'name_match'=>2, 'AND'=>3, 'OR'=>3,
	'is_null'=>4, '>'=>4, '<'=>4, '>='=>4, '<='=>4, 'in_subject'=>4,
	'grep'=>4	};

$INC{"EPrints/SearchCondition.pm"} = "EPrints/BackCompatibility.pm";

######################################################################

package EPrints::AnApache;

sub upload_doc_file { EPrints::deprecated(); return EPrints::Apache::AnApache::upload_doc_file( @_ ); }
sub upload_doc_archive { EPrints::deprecated(); return EPrints::Apache::AnApache::upload_doc_archive( @_ ); }
sub send_http_header { EPrints::deprecated(); return EPrints::Apache::AnApache::send_http_header( @_ ); }
sub header_out { EPrints::deprecated(); return EPrints::Apache::AnApache::header_out( @_ ); }
sub header_in { EPrints::deprecated(); return EPrints::Apache::AnApache::header_in( @_ ); }
sub get_request { EPrints::deprecated(); return EPrints::Apache::AnApache::get_request( @_ ); }
sub cookie { EPrints::deprecated(); return EPrints::Apache::AnApache::cookie( @_ ); }

$INC{"EPrints/AnApache.pm"} = "EPrints/BackCompatibility.pm";

######################################################################

package EPrints::Auth;

sub authz { EPrints::deprecated(); return EPrints::Apache::Auth::authz( @_ ); }
sub authen { EPrints::deprecated(); return EPrints::Apache::Auth::authen( @_ ); }

$INC{"EPrints/Auth.pm"} = "EPrints/BackCompatibility.pm";

######################################################################

package EPrints::DataObj;

sub get_session { EPrints::deprecated(); return $_[0]->get_handle; }

######################################################################

package EPrints::Session;

sub new { EPrints::deprecated(); return EPrints::Handle::new( @_ ); }

our @ISA = qw/ EPrints::Handle /;

######################################################################

package EPrints::Handle;

sub get_archive { EPrints::deprecated(); return $_[0]->get_repository; }
sub get_session_language { EPrints::deprecated(); return $_[0]->get_language; }
sub get_db { EPrints::deprecated(); return $_[0]->get_database; }
# move to compat module?
sub build_page
{
	my( $self, $title, $mainbit, $page_id, $links, $template ) = @_;
  EPrints::deprecated();
	$self->prepare_page( { title=>$title, page=>$mainbit, pagetop=>undef,head=>$links}, page_id=>$page_id, template=>$template );
}

######################################################################

package EPrints::DataSet;

sub get_archive { EPrints::deprecated(); return $_[0]->get_repository; }

sub get_page_fields
{
	my( $self, $type, $page, $staff ) = @_;

	EPrints::deprecated();

	$self->load_workflows();

	my $mode = "normal";
	$mode = "staff" if $staff;

	my $fields = $self->{types}->{$type}->{pages}->{$page}->{$mode};
	if( !defined $fields )
	{
		$self->{repository}->log( "No fields found in get_page_fields ($type,$page)" );
		return ();
	}
	return @{$fields};
}

sub get_type_pages
{
	my( $self, $type ) = @_;

	EPrints::deprecated();

	$self->load_workflows();

	my $l = $self->{types}->{$type}->{page_order};

	return () unless( defined $l );

	return @{$l};
}

sub get_type_fields
{
	my( $self, $type, $staff ) = @_;

	EPrints::deprecated();

	$self->load_workflows();

	my $mode = "normal";
	$mode = "staff" if $staff;

	my $fields = $self->{types}->{$type}->{fields}->{$mode};
	if( !defined $fields )
	{
		$self->{repository}->log( "Unknown type in get_type_fields ($type)" );
		return ();
	}
	return @{$fields};
}

sub get_required_type_fields
{
	my( $self, $type ) = @_;
	# Can't do this any more without loading lots of workflow gubbins
	EPrints::deprecated();

	return(); 


}

sub is_valid_type
{
	my( $self, $type ) = @_;
	EPrints::deprecated();
	return( defined $self->{repository}->{types}->{$self->confid}->{$type} );
}

sub get_types
{
	my( $self ) = @_;

	EPrints::deprecated();

	return( $self->{repository}->{types}->{$self->confid} );
}

sub get_type_names
{
	my( $self, $handle ) = @_;
		
	EPrints::deprecated();

	my %names = ();
	foreach( @{$self->get_types} )
	{
		$names{$_} = $self->get_type_name( $handle, $_ );
	}
	return( \%names );
}

sub get_type_name
{
	my( $self, $handle, $type ) = @_;

	EPrints::deprecated();

        return $handle->phrase( $self->confid()."_typename_".$type );
}

sub render_type_name
{
	my( $self, $handle, $type ) = @_;
	
	EPrints::deprecated();

	if( $self->{confid} eq "language"  || $self->{confid} eq "arclanguage" )
	{
		return $handle->make_text( $self->get_type_name( $handle, $type ) );
	}
        return $handle->html_phrase( $self->confid()."_typename_".$type );
}

sub load_workflows
{
	my( $self ) = @_;

	return if $self->{workflows_loaded};

	my $mini_session = EPrints::Handle->new( 1, $self->{repository}->get_id );
	foreach my $typeid ( @{$self->{type_order}} )
	{
		my $tdata = {};
		my $data = {};
		if( $self->{confid} eq "user" ) 
		{
			$data = {usertype=>$typeid};
		}
		if( $self->{confid} eq "eprint" ) 
		{
			$data = {type=>$typeid,eprint_status=>"buffer"};
		}
		my $item = $self->make_object( $mini_session, $data );
		my $workflow = EPrints::Workflow->new( $mini_session, "default", item=> $item );
		my $s_workflow = EPrints::Workflow->new( $mini_session, "default", item=> $item, "STAFF_ONLY"=>["TRUE","BOOLEAN"] );
		$tdata->{page_order} = [$workflow->get_stage_ids];
		$tdata->{fields} = { staff=>[], normal=>[] };
		$tdata->{req_field_map} = {};
		$tdata->{req_fields} = [];
		foreach my $page_id ( @{$tdata->{page_order}} )
		{
			my $stage = $workflow->get_stage( $page_id );
			my @components = $stage->get_components;
			foreach my $component ( @components )
			{
				next unless ref( $component ) eq "EPrints::Plugin::InputForm::Component::Field";
				my $field = $component->get_field;
				push @{$tdata->{fields}->{normal}}, $field;	
				push @{$tdata->{pages}->{$page_id}->{normal}}, $field;
				if( $field->get_property( "required" ) )
				{
					push @{$tdata->{req_fields}}, $field;	
					$tdata->{req_field_map}->{$field->get_name} = 1;
				}
			}

			my $s_stage = $s_workflow->get_stage( $page_id );
			my @s_components = $s_stage->get_components;
			foreach my $s_component ( @s_components )
			{
				next unless ref( $s_component ) eq "EPrints::Plugin::InputForm::Component::Field";
				my $field = $s_component->get_field;
				push @{$tdata->{pages}->{$page_id}->{staff}}, $field;
				push @{$tdata->{fields}->{staff}}, $field;
			}
		}
		$self->{types}->{$typeid} = $tdata;


	}
	$mini_session->terminate;

	$self->{workflows_loaded} = 1;
}

package EPrints::Index;

sub split_words { &EPrints::Index::Tokenizer::split_words }
sub apply_mapping { &EPrints::Index::Tokenizer::apply_mapping }

package EPrints::MetaField;

sub display_name
{
	my( $self, $handle ) = @_;

	EPrints::deprecated();

	my $phrasename = $self->{confid}."_fieldname_".$self->{name};

	return $handle->phrase( $phrasename );
}



1;
