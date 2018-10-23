Event.observe(window,'load',function () {
	$$('.js_admin_storagemanager_show_stats').each(function(div) {
		js_admin_storagemanager_load_stats(div);
	});
});

function js_admin_storagemanager_load_stats(div)
{
	var pluginid = div.id.substring(6);

	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() {
				alert( "AJAX request failed..." );
			},
			onException: function(req, e) {
				alert( "AJAX Exception " + e );
			},
			onSuccess: function(response){
				var text = response.responseText;
				if( text.length == 0 )
				{
					alert( "No response from server..." );
				}
				else
				{
					div._original = div.innerHTML;
					Element.update( div, text );
				}
			},
			parameters: {
				ajax: "stats",
				screen: "Admin::StorageManager",
				store: pluginid
			}
		}
	);
}

function js_admin_storagemanager_migrate(button)
{
	Element.extend(button);

	var form = button.up('form');
	Element.extend(form);

	var ajax_parameters = form.serialize(1);
	ajax_parameters['ajax'] = 'migrate';

	form._original = form.innerHTML;
	form.update( $('ep_busy_fragment').innerHTML );

	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() {
				alert( "AJAX request failed..." );
				form.update( form._original );
			},
			onException: function(req, e) {
				alert( "AJAX Exception " + e );
				form.update( form._original );
			},
			onSuccess: function(response){
				var text = response.responseText;
				if( text.length == 0 )
				{
					alert( "No response from server..." );
				}
				else
				{
					// Element.update( div, text );
					var div = $('stats_'+ajax_parameters['target']);
					if( !div )
					{
						alert("Can't find stats_"+ajax_parameters['target']);
					}
					else
					{
						Element.update(div,div._original);
						js_admin_storagemanager_load_stats(div);
					}
				}
				form.update( form._original );
			},
			parameters: ajax_parameters
		}
	);

	return false;
}

function js_admin_storagemanager_delete(button)
{
	Element.extend(button);

	var form = button.up('form');
	Element.extend(form);

	var ajax_parameters = form.serialize(1);
	ajax_parameters['ajax'] = 'delete';

	form._original = form.innerHTML;
	form.update( $('ep_busy_fragment').innerHTML );

	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() {
				alert( "AJAX request failed..." );
				form.update( form._original );
			},
			onException: function(req, e) {
				alert( "AJAX Exception " + e );
				form.update( form._original );
			},
			onSuccess: function(response){
				var text = response.responseText;
				if( text.length == 0 )
				{
					alert( "No response from server..." );
				}
				else
				{
					// Element.update( div, text );
					div = $('stats_'+ajax_parameters['store']);
					if( !div )
					{
						alert("Can't find stats_"+ajax_parameters['target']);
					}
					else
					{
						Element.update(div,div._original);
						js_admin_storagemanager_load_stats(div);
					}
				}
				form.update( form._original );
			},
			parameters: ajax_parameters
		}
	);

	return false;
}


