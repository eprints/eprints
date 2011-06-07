function UploadMethod_file_change(input,component,prefix)
{
	input = $(input.id);

	var container = input.parentNode;
	var uuid = generate_uuid();
	var iframe = uuid + "_iframe";
	var progress = uuid + "_progress";
	var filename = input.value;

	var progress_div = document.createElement('div');
	progress_div.setAttribute('id', progress);
	progress_div.setAttribute('class', 'UploadMethod_file_progress');

	var progress_bar = document.createElement('div');
	progress_bar.setAttribute('class', 'UploadMethod_file_progress_bar');
	progress_div.appendChild(progress_bar);

	var progress_info = document.createElement('div');
	progress_info.setAttribute('class', 'UploadMethod_file_progress_info');
	progress_info.filename = filename;
	progress_div.appendChild(progress_info);

	var hidden_iframe = document.createElement( 'iframe' );
	hidden_iframe.setAttribute( 'id', iframe );
	hidden_iframe.setAttribute( 'name', iframe );
	hidden_iframe.setAttribute( 'src', '#' );
	hidden_iframe.setAttribute( 'style', 'width:0;height:0;border:0px solid #fff' );
	progress_div.appendChild(hidden_iframe);

	container.parentNode.appendChild (progress_div);

	var form = input.up('form');
	var orig_target = form.getAttribute( 'target' );
	form.setAttribute( 'target', iframe );
	var orig_action = form.getAttribute( 'action' );
	var action = orig_action.split('#', 2);
	action[0] += action[0].indexOf('?') == -1 ? '?' : '&';
	action[0] += 'progress_id=' + uuid;
	action = action.join('#');
	form.setAttribute('action', action);

	// only process this component
	var input_component = document.createElement ('input');
		input_component.setAttribute ('type', 'hidden');
		input_component.setAttribute ('name', 'component');
		input_component.setAttribute ('value', component);
	form.appendChild (input_component);

	$('_internal_'+prefix+'_add_format').click();

	input.value = null;
	form.removeAttribute( 'target' );
	form.setAttribute( 'action', orig_action );
	form.removeChild (input_component);

	UploadMethod_update_progress_bar(uuid, progress_bar, progress_info);
	progress_div.pe = new PeriodicalExecuter(function(pe) {
		UploadMethod_update_progress_bar(uuid, progress_bar, progress_info, pe);
	}, 3);
}

function UploadMethod_update_progress_bar(uuid, progress_bar, progress_info, pe)
{
	var url = eprints_http_cgiroot + '/users/ajax/upload_progress?progress_id='+uuid;
	var base_style = 'width:200px;height:15px;border:1px solid #000;background-image:url(\'' + eprints_http_root + '/style/images/progress_bar_orange.png' + '\');background-repeat:no-repeat;';
	if (!progress_bar.getAttribute ('style') )
		progress_bar.setAttribute ('style', base_style + 'background-position:-200px 0px;');
	new Ajax.Request(url, {
		method: 'get',
		onException: function(req, e) {
			alert('Error updating progress bar: ' + e);
		},
		onSuccess: function(transport) {
			var json = transport.responseJSON;
			if (!json) {
				pe.stop();
				alert('Expected JSON but got: ' + transport.responseText);
			}
			var percent = json.received / json.size;
			progress_info.innerHTML = Math.floor(percent*100) + '% ' + progress_info.filename + ' [' + json.size + ' bytes]';
			var offset = Math.floor(percent * 200 - 200);
			progress_bar.setAttribute ('style', base_style + 'background-position:'+offset+'px 0px;');
			if (pe && json.received == json.size)
				pe.stop();
		},
		onFailure: function(transport) {
			alert('Request for ' + url + ' failed: ' + transport.status + ' ' + transport.statusText);
		}
	});
}

function UploadMethod_file_stop(uuid, docid)
{
	var progress = $(uuid + '_progress');
	if (progress) {
		progress.pe.stop();
		progress.parentNode.removeChild (progress);
	}
	if (docid) {
		Component_Documents.instances.invoke('refresh_document', docid);
	} else {
	}
}
