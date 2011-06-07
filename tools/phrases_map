#!/usr/bin/perl -w -I/opt/eprints3/perl_lib
use EPrints;

$delated = [
	"lib/extras:subject_browser",
	"lib/extras:subject_browser_none",
	"lib/extras:subject_browser_expandable",
	"lib/extras:subject_browser_search_results",
	
];


$renamed = {
	"cgi/users/edit_eprint:cant_find_it" 		=> "Screen/EPrint:cant_find_it", 
	"cgi/users/edit_eprint:view_as_either" 		=> "Screen/EPrint:view_as_either",
	"cgi/users/home:new_item_link" 				=> "Screen/EPrint:new_item_link",
	"cgi/users/home:new_item_info" 				=> "Screen/EPrint:new_item_info",
	"cgi/users/home:import_item_link" 			=> "Screen/EPrint:import_item_link",
	"cgi/users/home:import_item_info" 			=> "Screen/EPrint:import_item_info",
	"cgi/users/buffer:overview_title" 			=> "Screen/Review:overview_title",
	"cgi/users/buffer:no_entries" 				=> "Screen/Review:no_entries",
	"cgi/users/buffer:buffer_blurb" 			=> "Screen/Review:review_blurb",
	"cgi/users/buffer:title" 					=> "Screen/Review:title",
	"cgi/users/buffer:sub_by" 					=> "Screen/Review:sub_by",
	"cgi/users/buffer:sub_date" 				=> "Screen/Review:sub_date",
	"cgi/users/buffer:invalid" 					=> "Screen/Review:invalid",
	"cgi/users/status:release" 					=> "Screen/Status:release",
	"cgi/users/status:database" 				=> "Screen/Status:database",
	"cgi/users/status:usertitle" 				=> "Screen/Status:usertitle",
	"cgi/users/status:users" 					=> "Screen/Status:users",
	"cgi/users/status:articles" 				=> "Screen/Status:articles",
	"cgi/users/status:set_archive" 				=> "Screen/Status:set_archive",
	"cgi/users/status:set_buffer" 				=> "Screen/Status:set_buffer",
	"cgi/users/status:set_inbox" 				=> "Screen/Status:set_inbox",
	"cgi/users/status:set_deletion" 			=> "Screen/Status:set_deletion",
	"cgi/users/status:diskspace" 				=> "Screen/Status:diskspace",
	"cgi/users/status:diskfree" 				=> "Screen/Status:diskfree",
	"cgi/users/status:mbfree" 					=> "Screen/Status:mbfree",
	"cgi/users/status:out_of_space" 			=> "Screen/Status:out_of_space",
	"cgi/users/status:nearly_out_of_space" 		=> "Screen/Status:nearly_out_of_space",
	"cgi/users/status:subscriptions" 			=> "Screen/Status:subscriptions",
	"cgi/users/status:subcount" 				=> "Screen/Status:subcount",
	"cgi/users/status:subsent" 					=> "Screen/Status:subsent",
	"cgi/users/status:title" 					=> "Screen/Status:title",

	"lib/extras:subject_browser_search"			=> "Plugin/InputForm/Component/Field/Subject:search_bar",
	"lib/extras:subject_browser_search_button"	=> "Plugin/InputForm/Component/Field/Subject:search_button",
	"lib/extras:subject_browser_no_matches"		=> "Plugin/InputForm/Component/Field/Subject:search_no_matches",
	"lib/extras:subject_browser_remove"			=> "Plugin/InputForm/Component/Field/Subject:remove",
	"lib/extras:subject_browser_add"			=> "Plugin/InputForm/Component/Field/Subject:add",
	

#	"lib/submissionform:action_prev"			=> "Screen/EPrint/Edit:action_prev",
#	"lib/submissionform:action_save"			=> "Screen/EPrint/Edit:action_save",
#	"lib/submissionform:action_next"			=> "Screen/EPrint/Edit:action_next",
	
#	"cgi/users/edit_eprint:no_user" 			=> "Screen/EPrint/Move:no_user",
#	"cgi/users/edit_eprint:no_user" 			=> "Screen/EPrint/RejectWithEmail:no_user",
	"cgi/users/edit_eprint:title_bounce_form" 	=> "Screen/EPrint/RejectWithEmail:title_bounce_form",
	"cgi/users/edit_eprint:bounce_form_intro" 	=> "Screen/EPrint/RejectWithEmail:bounce_form_intro",
#	"cgi/users/edit_eprint:action_cancel" 		=> "Screen/EPrint/RejectWithEmail:action_cancel",
	"cgi/users/edit_eprint:bord_fail" 			=> "Screen/EPrint/RejectWithEmail:bord_fail",
	"cgi/users/edit_eprint:status_changed" 		=> "Screen/EPrint/RejectWithEmail:status_changed",
	"cgi/users/edit_eprint:subject_bounce" 		=> "Screen/EPrint/RejectWithEmail:subject_bounce",
	"cgi/users/edit_eprint:mail_fail" 			=> "Screen/EPrint/RejectWithEmail:mail_fail",
	"cgi/users/edit_eprint:mail_sent" 			=> "Screen/EPrint/RejectWithEmail:mail_sent",
	
#	"lib/submissionform:sure_delete" 			=> "Screen/EPrint/Remove:sure_delete",
#	"lib/submissionform:action_cancel"			=> "Screen/EPrint/Remove:action_cancel",
#	"lib/submissionform:action_confirm"			=> "Screen/EPrint/Remove:action_confirm",
	
	"cgi/users/edit_eprint:no_user" 			=> "Screen/EPrint/RemoveWithEmail:no_user",
	"cgi/users/edit_eprint:title_bounce_form" 	=> "Screen/EPrint/RemoveWithEmail:title_bounce_form",
	"cgi/users/edit_eprint:bounce_form_intro" 	=> "Screen/EPrint/RemoveWithEmail:bounce_form_intro",
#	"cgi/users/edit_eprint:action_cancel"		=> "Screen/EPrint/RemoveWithEmail:action_cancel",
	"cgi/users/edit_eprint:subject_bounce" 		=> "Screen/EPrint/RemoveWithEmail:subject_bounce",
	"cgi/users/edit_eprint:mail_sent" 			=> "Screen/EPrint/RemoveWithEmail:mail_sent",
	"cgi/users/edit_eprint:view_unavailable" 	=> "Screen/EPrint/View:view_unavailable",
	"cgi/users/edit_eprint:loading" 			=> "Screen/EPrint/View:loading",
	"cgi/users/edit_eprint:item_is_in_inbox" 	=> "Screen/EPrint:item_is_in_inbox",
	"cgi/users/edit_eprint:item_is_in_buffer" 	=> "Screen/EPrint:item_is_in_buffer",
	"cgi/users/edit_eprint:item_is_in_archive" 	=> "Screen/EPrint:item_is_in_archive",
	"cgi/users/edit_eprint:item_is_in_deletion" => "Screen/EPrint:item_is_in_deletion",
};


my $doc = EPrints::XML::parse_xml( "system.xml", "/opt/eprints3/lib/lang/en/phrases/", 0  );

if( !$doc )
{
	print "Eep!\n";
}

my $phrases = ($doc->getElementsByTagName( "phrases" ))[0];

foreach my $element ( $phrases->getChildNodes )
{
	my $name = $element->getNodeName;
	if( $name eq "phrase" || $name eq "ep:phrase" )
	{
		my $id = $element->getAttribute( "id" );
		if( defined $id )
		{
			if( $renamed->{$id} )
			{
				print "Renamed: $id\n";
			}
		}
	}
}

