
function ep_decode_html_entities( str )
{
	str = str.replace( /\&quot;/g, "\"" );
	str = str.replace( /\&squot;/g, "'" );
	str = str.replace( /\&lt;/g, "<" );
	str = str.replace( /\&gt;/g, ">" );
	str = str.replace( /\&amp;/g, "&" );
	return str;
}

function ep_phraseedit_addphrase( event, base_id )
{
	if( base_id == '' )
	{
		alert( "No phrase ID specified" );
		return false;
	}	
	if( $("ep_phraseedit_"+base_id) != null )
	{
		alert( "The phrase '"+base_id+"' already exists." );
		return false;
	}
	
	$("ep_phraseedit_add").disabled = true;
	$("ep_phraseedit_newid").disabled = true;
	
	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() { 
				$("ep_phraseedit_add").disabled = false;
				$("ep_phraseedit_newid").disabled = false;
				alert( "AJAX request failed..." );
			},
			onException: function(req, e) { 
				$("ep_phraseedit_add").disabled = false;
				$("ep_phraseedit_newid").disabled = false;
				alert( "AJAX Exception " + e );
			},
			onSuccess: function(response){ 
				var text = response.responseText;
				$("ep_phraseedit_add").disabled = false;
				$("ep_phraseedit_newid").disabled = false;
				if( text.length == 0 )
				{
					alert( "No response from server..." );
				}
				else
				{
					$("ep_phraseedit_newid").value = "";

					var table = $('ep_phraseedit_table');
					var first_tr = Element.down(table, 'tr');
					/* first tr is the table header */
					first_tr = first_tr.nextSibling;

					/* parse the new row */
					var parser = document.createElement( 'table' );
					parser.update( text );
					var tr = Element.down(parser, 'tr');

					first_tr.parentNode.insertBefore( tr, first_tr );
				}
			},
			parameters: { 
				screen: "Admin::Phrases", 
				phraseid: base_id, 
				phrase: $('ep_phraseedit_newid').value
			} 
		} 
	);
	return false;
}

function ep_phraseedit_save(base_id, phrase)
{
	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() { 
				var form = $('ep_phraseedit_'+base_id);
				ep_phraseedit_enableform(form);
				alert( "AJAX request failed..." );
			},
			onException: function() { 
				var form = $('ep_phraseedit_'+base_id);
				ep_phraseedit_enableform(form);
				alert( "AJAX Exception..." );
			},
			onSuccess: function(response){ 
				var text = response.responseText;
				if( text.length == 0 )
				{
					ep_phraseedit_enableform(form);
					alert( "No response from server..." );
				}
				else
				{
					var form = $('ep_phraseedit_'+base_id);

					/* parse the new row */
					var parser = document.createElement( 'table' );
					parser.update( text );
					var new_tr = Element.down(parser, 'tr');

					var tr = form.up('tr');
					tr.parentNode.replaceChild( new_tr, tr );
				}
			},
			parameters: { 
				screen: "Admin::Phrases", 
				phraseid: base_id, 
				phrase: phrase
			} 
		} 
	);
}

function ep_phraseedit_disableform(form)
{
	for(var i = 0; i < form.childNodes.length; ++i)
	{
		var n = form.childNodes[i];
		n.disabled = true;
	}
}

function ep_phraseedit_enableform(form)
{
	for(var i = 0; i < form.childNodes.length; ++i)
	{
		var n = form.childNodes[i];
		n.disabled = false;
	}
}

function ep_phraseedit_edit(div, phrases)
{
	var container = div.parentNode;
	container.removeChild( div );

	/* less "ep_phraseedit_" */
	var base_id = div.id.replace( 'ep_phraseedit_', '' );

	var form = document.createElement( "form" );
	form.setAttribute( 'id', div.id );
	form._base_id = base_id;
	form._original = ep_decode_html_entities( div.innerHTML );
	form._widget = div;
	var textarea = document.createElement( 'textarea' );
	form.appendChild( textarea );
	textarea.value = form._original;
	textarea.setAttribute( 'rows', '2' );

	var input;
	/* save */
	input = document.createElement( 'input' );
	form.appendChild( input );
	input.setAttribute( 'type', 'button' );
	input.value = phrases['save'];
	Event.observe(input,'click',function(event) {
		var form = event.element().parentNode;
		ep_phraseedit_disableform(form);
		var textarea = form.firstChild;
		ep_phraseedit_save(form._base_id, textarea.value);
	});
	/* reset */
	input = document.createElement( 'input' );
	form.appendChild( input );
	input.setAttribute( 'type', 'button' );
	input.value = phrases['reset'];
	Event.observe(input,'click',function(event) {
		var form = event.element().parentNode;
		var textarea = form.firstChild;
		textarea.value = form._original;
	});
	/* cancel */
	input = document.createElement( 'input' );
	form.appendChild( input );
	input.setAttribute( 'type', 'button' );
	input.value = phrases['cancel'];
	Event.observe(input,'click',function(event) {
		var form = event.element().parentNode;
		var container = form.parentNode;
		container.removeChild( form );
		container.appendChild( form._widget );
	});

	container.appendChild( form );
	textarea.focus();
	while(textarea.scrollHeight > textarea.clientHeight && !window.opera)
	{
		textarea.rows += 1;
	}
}
