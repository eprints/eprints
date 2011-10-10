/* EPrints::Plugin::Screen::BatchEdit */

Event.observe(window, 'load', ep_batchedit_update_list);

function ep_batchedit_update_list()
{
	var container = $('ep_batchedit_sample');
	if( !container )
		return;

	container.update( '<img src="' + eprints_http_root + '/style/images/lightbox/loading.gif" />' );

	var ajax_parameters = {};
	ajax_parameters['screen'] = $F('screen');
	ajax_parameters['cache'] = $F('cache');
	ajax_parameters['ajax'] = 'list';

	new Ajax.Updater(
		container,
		eprints_http_cgiroot+'/users/home',
		{
			method: "get",
			onFailure: function() { 
				alert( "AJAX request failed..." );
			},
			onException: function(req, e) { 
				alert( "AJAX Exception " + e );
			},
			parameters: ajax_parameters
		} 
	);
}

var ep_batchedit_c = 1;

/* the user clicked to add an action */
function ep_batchedit_add_action()
{
	var name = $('ep_batchedit_field_name').value;

	var form = $('ep_batchedit_form');
	Element.extend(form);

	var ajax_parameters = {};
	ajax_parameters['screen'] = $F('screen');
	ajax_parameters['cache'] = $F('cache');
	ajax_parameters['ajax'] = 'new_field';
	ajax_parameters['field_name'] = name;
	ajax_parameters['c'] = ep_batchedit_c++;

	$('max_action').value = ep_batchedit_c;

	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "get",
			onFailure: function(res) { 
				alert( "AJAX request failed: " + res.responseText );
			},
			onException: function(req, e) { 
				alert( "AJAX Exception " + e );
			},
			onSuccess: function(response){ 
				var xml = response.responseText;
				if( !xml )
				{
					alert( "No response from server: "+response.responseText );
				}
				else
				{
					$('ep_batchedit_actions').insert( xml );
				}
			},
			parameters: ajax_parameters
		} 
	);
}

/* the user clicked to remove an action */
function ep_batchedit_remove_action(idx)
{
	var action = $('action_' + idx);
	if( action != null )
		action.parentNode.removeChild( action );
}

function ep_batchedit_progress(container, uuid)
{
	var progress = new EPrintsProgressBar({bar: 'progress_bar_orange.png'}, container);

	container.pe = new PeriodicalExecuter(function(pe) {
		var url = eprints_http_cgiroot + '/users/ajax/upload_progress?progressid='+uuid;
		new Ajax.Request(url, {
			method: 'get',
			onSuccess: function(transport) {
				var json = transport.responseJSON;
				if( !json ) {
					pe.stop();
					return;
				}
				var percent = json.received / json.size;
				progress.update( percent, Math.round(percent*100)+'%' );
			}
		});
	}, .2);
}

/* the user submitted the changes form */
function ep_batchedit_submitted()
{
	var container = $('ep_progress_container');

	$('ep_batchedit_inputs').hide();

	var uuid = generate_uuid();
	$('progressid').value = uuid;

	ep_batchedit_progress( container, uuid );

	return true;
}

function ep_batchedit_remove_submitted( message )
{
	var container = $('ep_progress_container');

	if( confirm( message ) != true )
		return false;

	$('ep_batchedit_inputs').hide();

	var uuid = generate_uuid();
	$('progressid').value = uuid;

	ep_batchedit_progress( container, uuid );

	return true;
}

function ep_batchedit_finished()
{
	var iframe = $('ep_batchedit_iframe');
	var container = $('ep_progress_container');

	container.pe.stop();
	container.update( iframe.contentWindow.document.body.innerHTML );

	ep_batchedit_update_list();

	var max_action = $F('max_action');
	for(var i = 0; i < max_action; ++i)
		ep_batchedit_remove_action( i );

	$('ep_batchedit_inputs').show();
}

