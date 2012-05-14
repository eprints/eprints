var Screen_BatchEdit = Class.create({}, {
	prefix: null,
	actions: Array(),

	initialize: function(prefix) {
		this.prefix = prefix;

		Event.observe (this.prefix + '_action_add_change', 'click',
				this.action_add_change.bindAsEventListener (this)
			);

		Event.observe (this.prefix + '_action_edit', 'click',
				this.action_edit.bindAsEventListener (this)
			);

		Event.observe (this.prefix + '_action_remove', 'click',
				this.action_remove.bindAsEventListener (this)
			);

		Event.observe (this.prefix + '_iframe', 'load',
				this.finished.bindAsEventListener (this)
			);

		this.refresh();
	},

	refresh: function() {
		var container = $(this.prefix + '_sample');
		if( !container )
			return;

		container.update( '<img src="' + eprints_http_root + '/style/images/lightbox/loading.gif" />' );

		var ajax_parameters = {};
		ajax_parameters['screen'] = $F('screen');
		ajax_parameters['cache'] = $F('cache');
		ajax_parameters['ajax'] = 1;
		ajax_parameters['_action_list'] = 1;

		new Ajax.Updater(
			container,
			eprints_http_cgiroot+'/users/home',
			{
				method: "get",
				parameters: ajax_parameters
			} 
		);
	},

	begin: function() {
		var container = $(this.prefix + '_progress');
		var uuid = $F('progressid');

		$(this.prefix + '_form').hide ();

		if (container.pe)
			container.pe.stop();

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
	},

	finished: function(evt) {
		var iframe = $(this.prefix + '_iframe');
		var container = $(this.prefix + '_progress');
		container.pe.stop();
		container.update( iframe.contentWindow.document.body.innerHTML );

		$(this.prefix + '_changes').update ('');
		$(this.prefix + '_form').show ();

		this.refresh ();
	},

	action_add_change: function(evt) {
		var ajax_parameters = {};
		ajax_parameters['screen'] = $F('screen');
		ajax_parameters['cache'] = $F('cache');
		ajax_parameters['ajax'] = 1;
		ajax_parameters['_action_add_change'] = 1;
		ajax_parameters['field_name'] = $F(this.prefix + '_field_name');

		new Ajax.Updater(this.prefix + '_changes', eprints_http_cgiroot+"/users/home",
			{
				method: "get",
				onFailure: function(transport) {
					throw new Error ("Error in AJAX request: " + transport.responseText);
				},
				onException: function(transport, e) {
					throw e;
				},
				parameters: ajax_parameters,
				insertion: Insertion.Bottom
			} 
		);

		Event.stop (evt);
	},

	action_edit: function(evt) {
		this.begin ();
	},

	action_remove: function(evt) {
		var message = Event.element (evt).getAttribute ('_phrase');

		if( confirm( message ) != true )
		{
			Event.stop (evt);
			return false;
		}

		this.begin ();
	}
});
