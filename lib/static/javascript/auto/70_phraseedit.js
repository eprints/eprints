
function ep_decode_html_entities( str )
{
	str = str.replace( /\&quot;/g, "\"" );
	str = str.replace( /\&squot;/g, "'" );
	str = str.replace( /\&lt;/g, "<" );
	str = str.replace( /\&gt;/g, ">" );
	str = str.replace( /\&amp;/g, "&" );
	return str;
}
function ep_phraseedit_show( base_id )
{
	var v = $("ep_phrase_view_"+base_id).innerHTML; 
	ep_phraseedit_show_text( base_id, ep_decode_html_entities( v ) );
	var textarea = $("ep_phrase_textarea_"+base_id);
	textarea.focus();
	while(textarea.scrollHeight > textarea.clientHeight && !window.opera) { textarea.rows += 1; }
}

function ep_phraseedit_adjust_textarea( textarea )
{
	while(textarea.scrollHeight > textarea.clientHeight && !window.opera) { textarea.rows += 1; }
	return true;
}
	
function ep_phraseedit_show_text( base_id, text )
{
	$("ep_phrase_textarea_"+base_id).value = text;
	$("ep_phrase_view_"+base_id).style.display = "none"; 
	$("ep_phrase_edit_"+base_id).style.display = "block";
}


function ep_phraseedit_reset( event, base_id )
{
	var v = $("ep_phrase_view_"+base_id).innerHTML; 
	$("ep_phrase_textarea_"+base_id).value = ep_decode_html_entities( v );
	EPJS_blur( event );
	return false;	
}
function ep_phraseedit_cancel( event, base_id )
{
	$("ep_phrase_view_"+base_id).style.display = "block"; 
	$("ep_phrase_edit_"+base_id).style.display = "none";
	EPJS_blur( event );
	return false;	
}

function ep_phraseedit_addphrase( event, base_id )
{
	if( base_id == '' )
	{
		alert( "No phrase ID specified" );
		return false;
	}	
	if( $("ep_phrase_row_"+base_id) != null )
	{
		alert( "The phrase '"+base_id+"' already exists." );
		return false;
	}
	
	$("ep_phraseedit_add").disabled = true;
	$("ep_phraseedit_newid").disabled = true;
	var first_row = $(window.first_row);
	var tr = document.createElement( "tr" );
	tr.setAttribute( "id", "ep_phrase_row_"+base_id );
	first_row.parentNode.insertBefore( tr, first_row );
	window.first_row = "ep_phrase_row_"+base_id;
	ep_phraseedit_ajax_row( base_id, 'edit me!' );
	
	return false;
}

function ep_phraseedit_save( event, base_id )
{
	$("ep_phrase_save_"+base_id).disabled = true;
	$("ep_phrase_reset_"+base_id).disabled = true;
	$("ep_phrase_cancel_"+base_id).disabled = true;
	$("ep_phrase_textarea_"+base_id).disabled = true;
	$("ep_phrase_save_"+base_id).value = "Saving...";
	$("ep_phrase_save_"+base_id).blur();
	ep_phraseedit_ajax_row( 
		base_id, 
		$F("ep_phrase_textarea_"+base_id), 
		$("ep_phrase_textarea_"+base_id).getDimensions().width );

	return false;
}

function ep_phraseedit_ajax_row( base_id, phrase, width )
{
	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() { 
				ep_phraseedit_savefail(base_id);
				alert( "AJAX request failed.." ); 
				ep_phraseedit_after_ajax_row(base_id);
			},
			onException: function() { 
				ep_phraseedit_savefail(base_id);
				alert( "AJAX Exception.." ); 
				ep_phraseedit_after_ajax_row(base_id);
			},
			onSuccess: function(response){ 
				var text = response.responseText;
				if( text.length == 0 )
				{
					ep_phraseedit_savefail(base_id)
					alert( "No response from server." );
				}
				else
				{
					$("ep_phrase_row_"+base_id).update( text );
				}
				ep_phraseedit_after_ajax_row(base_id);
			},
			parameters: { 
				width: width,
				screen: "Admin::Phrases", 
				phrase_id: base_id, 
				phrase: phrase
			} 
		} 
	);
	return false;	
}

function ep_phraseedit_after_ajax_row(base_id)
{
	setTimeout( 'var t=$("ep_phrase_textarea_'+base_id+'"); t.focus(); ep_phraseedit_adjust_textarea( t );', 250 );

	var add_button = $("ep_phraseedit_add");
	if( add_button ) { 
		add_button.disabled = false; 
	}
	var newid = $("ep_phraseedit_newid");
	if( newid ) { 
		newid.disabled = false; 
		newid.value = "";
	}
}

function ep_phraseedit_savefail(base_id)
{
	$("ep_phrase_save_"+base_id).disabled = false;
	$("ep_phrase_reset_"+base_id).disabled = false;
	$("ep_phrase_cancel_"+base_id).disabled = false;
	$("ep_phrase_textarea_"+base_id).disabled = false;
	$("ep_phrase_save_"+base_id).value = "Save";
}
