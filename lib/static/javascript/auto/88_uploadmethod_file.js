var Screen_EPrint_UploadMethod_File = Class.create({
	component: undefined,
	prefix: undefined,
	container: undefined,
	parameters: undefined,

	initialize: function(prefix, component, evt) {
		this.component = component;
		this.prefix = prefix;

		var div = $(prefix + '_dropbox');
		this.container = div;

		this.parameters = new Hash({
			screen: $F('screen'),
			eprintid: $F('eprintid'),
			stage: $F('stage'),
			component: component
		});

		// this.drop (evt);
	},
	dragCommence: function(evt) {
		var event = evt.memo.event;
		if (event.dataTransfer.types[0] == 'Files' || event.dataTransfer.types[0] == 'application/x-moz-file')
		{
			this.container.addClassName ('ep_dropbox');
			$(this.prefix + '_dropbox_help').show();
			$(this.prefix + '_file').hide();
		}
	},
	dragFinish: function(evt) {
		this.container.removeClassName ('ep_dropbox');
		$(this.prefix + '_dropbox_help').hide();
		$(this.prefix + '_file').show();
	},
	/*
	 * Handle a drop event on the HTML element
	 */
	drop: function(evt) {
		var files = evt.dataTransfer.files;
		var count = files.length;

		if (count == 0)
			return;

		this.handleFiles (files);
	},
	/*
	 * Handle a list of files dropped
	 */
	handleFiles: function(files) {
		// User dropped a lot of files, did they really mean to?
		if( files.length > 5 )
		{
			eprints.currentRepository().phrase (
				{
					'Plugin/Screen/EPrint/UploadMethod/File:confirm_bulk_upload': {
						'n': files.length
					}
				},
				(function(phrases) {
					if (confirm(phrases['Plugin/Screen/EPrint/UploadMethod/File:confirm_bulk_upload']))
						this.createFile (files, 0);
				}).bind (this)
			);
		}
		else
	    	this.createFile(files, 0);
	},
	/*
	 * Create a document/file on EPrints in preparation for upload
	 */
	createFile: function(files, i) {
        var file = files[i];
		// progress status
		var progress_row = new Element ('tr');
		file.progress_container = progress_row;

		// file name
		progress_row.insert (new Element ('td').update (file.name));

		// file size
		progress_row.insert (new Element ('td').update (human_filesize (file.size)));

		// progress bar
		var td = new Element ('td');
		progress_row.insert (td);
		file.progress_bar = new EPrintsProgressBar ({}, td);

		// progress text
		file.progress_info = new Element ('td');
		progress_row.insert (file.progress_info);

		// cancel button
		var button = new Element ('button', {
				'type': 'button',
				'class': 'ep_form_internal_button',
				'style': 'display: none'
			});
		Event.observe (button, 'click', (function (evt) {
				Event.stop (evt);
				this.abortFile (file);
			}).bind(this));
		file.progress_button = button;
		progress_row.insert (new Element ('td').update (button));

		$(this.prefix + '_progress_table').insert (progress_row);

		this.updateProgress (file, 0);

		var url = eprints_http_cgiroot + '/users/home';
		var params = this.parameters.clone();

		params.set ('filename', file.name);
		params.set ('filesize', file.size);
		params.set ('mime_type', file.type);

		params.set ('_internal_' + this.prefix + '_create_file', 1);

		new Ajax.Request(url + '?ajax=1', {
			method: 'post',
			onException: function(req, e) {
                // we've had an issue creating this doc record, but let's move on to the next one in the meantime
                i++;
                if( i < files.length )
                    this.createFile( files,  i );
				throw e;
			},
			onSuccess: (function(transport) {
				var json = transport.responseJSON;
				if (!json) {
					throw new Error('Expected JSON but got: ' + transport.responseText);
				}
				file.docid = json['docid'];
				file.fileid = json['fileid'];
				button.update (json['phrases']['abort']);
				button.show();
				this.postFile (file, 0);

                // we've create a new doc record for this file, move on to the next record
                i++;
                if( i < files.length )
                    this.createFile( files,  i );
			}).bind (this),
			parameters: params
		});
	},
	/*
	 * POST the content of the file to the server via CRUD
	 */
	postFile: function(file, offset) {
		var params = this.parameters.clone();
		var url = eprints_http_root + '/id/file/' + file.fileid;

		var bufsize = 1048576;
		var buffer = file.slice (offset, offset + bufsize);

		// finished
		if (buffer.size == 0)
		{
			this.finishFile (file);
			return;
		}

		new Ajax.Request(url, {
			method: 'put',
			onException: function(req, e) {
				throw e;
			},
			onFailure: function(transport) {
				throw new Error('Server reported failure: ' + transport.status);
			},
			onSuccess: (function(transport) {
				if (file.abort)
					return;
				this.updateProgress (file, offset);
				this.postFile (file, offset + bufsize);
			}).bind (this),
			requestHeaders: {
				'Content-Range': '' + offset + '-' + (offset + buffer.size) + '/' + file.size,
				'Content-Type': 'application/octet-stream',
				'X-Method': 'PUT'
			},
			postBody: buffer
		});
	},
	/*
	 * Tell the server we've finished updating the file e.g. perform file
	 * detection
	 */
	finishFile: function(file) {
		this.updateProgress (file, file.size);

		var url = eprints_http_cgiroot + '/users/home?ajax=1';
		var params = this.parameters.clone();

		params.set ('docid', file.docid);
		params.set ('fileid', file.fileid);

		params.set ('_internal_' + this.prefix + '_finish_file', 1);

		new Ajax.Request(url + '?ajax=1', {
			method: 'post',
			onException: function(req, e) {
				throw e;
			},
			onSuccess: (function(transport) {
				if (file.abort)
					return;
				file.progress_container.parentNode.removeChild (file.progress_container);
				Component_Documents.instances.invoke ('refresh_document', file.docid);
			}).bind (this),
			parameters: params
		});
	},
	/*
	 * Abort and clean-up the file upload
	 */
	abortFile: function(file) {
		file.abort = true;
		file.progress_button.hide();

		if (!file.docid)
			return;

		var url = eprints_http_root + '/id/document/' + file.docid;

		new Ajax.Request(url, {
			method: 'delete',
			onException: function(req, e) {
				throw e;
			},
			onFailure: function(transport) {
				throw new Error('Server reported failure: ' + transport.status);
			},
			onSuccess: (function(transport) {
				file.progress_container.parentNode.removeChild (file.progress_container);
			}).bind (this),
			requestHeaders: {
				'X-Method': 'DELETE'
			}
		});

		return false;
	},
	/*
	 * Update the progress bar + info for a single file
	 */
	updateProgress: function(file, n) {
		var percent = n / file.size;
		file.progress_bar.update (percent, Math.floor(percent*100) + '%');
		file.progress_info.update (Math.floor(percent*100) + '%');
	}
});

function UploadMethod_file_change(input,component,prefix)
{
	input = $(input.id);
	if(input.value){
	var container = input.parentNode;
	var uuid = generate_uuid();
	var iframe = uuid + "_iframe";
	var progress = uuid + "_progress";
	var filename = input.value;

	// progress status
	var progress_row = new Element ('tr', {
			'id': progress
		});
	var progress_container = progress_row;

	// file name
	progress_row.insert (new Element ('td').update (filename));

	// file size
	progress_container.progress_size = new Element ('td');
	progress_row.insert (progress_container.progress_size);

	// progress bar
	var td = new Element ('td');
	progress_row.insert (td);
	progress_container.progress_bar = new EPrintsProgressBar ({}, td);

	// progress text
	progress_container.progress_info = new Element ('td');
	progress_row.insert (progress_container.progress_info);

	var hidden_iframe;
	if( Prototype.Browser.IE6 || Prototype.Browser.IE7 )
	{	
		// IE doesn't support setAttribute('name') on <iframe>
		hidden_iframe = document.createElement( '<iframe name="'+iframe+'">' );
		Element.extend( hidden_iframe );
	}
	else
	{
		hidden_iframe = new Element( 'iframe' );
		hidden_iframe.setAttribute( 'name', iframe );
	}

	hidden_iframe.setAttribute( 'id', iframe );
	hidden_iframe.setAttribute( 'src', '#' );

	hidden_iframe.setStyle( {
		width:'0',
		height:'0',
		border:'0px'
	});

	progress_row.insert (hidden_iframe);

	/* cancel button */
	var cancel_button = new Element ('button');
	cancel_button.innerHTML = 'Cancel';
	cancel_button.setAttribute ('class', 'ep_form_action_button');
	Event.observe (cancel_button, 'click', function(evt) {
		Event.stop (evt);
		UploadMethod_cancel (uuid);
	});
	var td = new Element ('td');
	td.insert (cancel_button);
	progress_row.insert (td);
	eprints.currentRepository().phrase ({ 'lib/submissionform:action_cancel': {}}, function(phrases) {
			cancel_button.innerHTML = phrases['lib/submissionform:action_cancel'];
		});

	$(prefix + '_progress_table').insert (progress_row);

	var form = input.up('form');
	var orig_target = form.getAttribute( 'target' );
	form.setAttribute( 'target', iframe );
	var orig_action = form.getAttribute( 'action' );
	var action = orig_action.split('#', 2);
	action[0] += action[0].indexOf('?') == -1 ? '?' : '&';
	action[0] += 'progressid=' + uuid + '&ajax=add_format';
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

	UploadMethod_update_progress_bar(uuid, progress_container);
	progress_container.pe = new PeriodicalExecuter(function(pe) {
		UploadMethod_update_progress_bar(uuid, progress_container, pe);
	}, 3);
	}
}

function UploadMethod_update_progress_bar(uuid, container, pe)
{
	var url = eprints_http_cgiroot + '/users/ajax/upload_progress?progressid='+uuid;
	new Ajax.Request(url, {
		method: 'get',
		onException: function(req, e) {
			console.log('Error updating progress bar: ' + e);
		},
		onSuccess: function(transport) {
			var json = transport.responseJSON;
			if (!json) {
				pe.stop();
				console.log('Expected JSON but got: ' + transport.responseText);
			}
			var percent = json.received / json.size;
			container.progress_bar.update (percent, Math.floor(percent*100) + '%');
			container.progress_info.update (Math.floor(percent*100) + '%');
			container.progress_size.update (human_filesize (json.size));
			var offset = Math.floor(percent * 200 - 200);
			if (pe && json.received == json.size)
				pe.stop();
		},
		onFailure: function(transport) {
			console.log('Request for ' + url + ' failed: ' + transport.status + ' ' + transport.statusText);
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

function UploadMethod_cancel(uuid)
{
	var progress = $(uuid + '_progress');
	if (progress) {
		progress.pe.stop();
		progress.parentNode.removeChild (progress);
	}
}
