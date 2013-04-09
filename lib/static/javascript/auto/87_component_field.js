var Component_Field = Class.create({
	prefix: null,
	handlers: [],

	initialize: function(prefix) {
		this.prefix = prefix;
		this.root = $(this.prefix);
		this.form = this.root.up ('form');
		this.url = eprints_http_cgiroot + '/users/home';

		this.root.eprints = this;

		this.initialize_internal( this.root );
	},

	// initialises 'click' event handlers to process internal actions (within this component)
	initialize_internal: function( root ) {
		root.select ('input.epjs_ajax').each ((function(input) {
			if (input.type == 'image' ) {
				var attr = input.attributesHash ();
				attr['href'] = 'javascript:';
				var link = new Element ('a', attr);
				link.appendChild ( new Element ('img', { src: attr['src'] } ) );
				input.replace (link);
				input = link;
			}
			else {
				var attr = input.attributesHash();
				attr['type'] = 'button';

				var button = new Element ('input', attr );
				input.replace (button);
				input = button;
			}
			
			input.stopObserving( 'click' );

			var rel = input.getAttribute( 'rel' );

			if( rel != null && rel == 'interactive' )
				input.observe( 'click', this.modal.bindAsEventListener( this, input ) );	// opens a modal box
			else
				input.observe( 'click', this.internal.bindAsEventListener(this, input) );	// processes an internal action


		}).bind (this));

	},

	// initialises event handlers within the potential modal box
	initialize_modal: function() {

		if( this.modal == null )
			return;

		this.modal.reposition();

		var form = this.modal.get_content().down( 'form' );
		if (form != null )
		{
			form.select( '.ep_component_action' ).each( (function (el) {

				this.initialize_modal_action( el );

			}).bind(this));
		}
		
		this.initialize_internal( this.modal.get_content() );
	},

	initialize_modal_action: function( el ) {

		var action = el.getAttribute( 'data-internal' );
		var param = el.getAttribute( 'data-internal-param' );
		var extra_elid = el.getAttribute( 'data-internal-element' );
		var ievent = el.getAttribute( 'data-internal-event' );

		if( ievent == null )
			ievent = 'click';

		if( action != null )
		{
			el.stopObserving( ievent );
			var extra_el = $( extra_elid );

			var param_el = el;
			if( extra_el != null )
				param_el = extra_el;

			el.observe( ievent, this.modal_internal.bindAsEventListener(this, el, action, param, param_el ) );
		}
	},

	get_params: function( form ) {

		var params = serialize_form ( form );

		params['component'] = this.prefix;
		params[this.prefix + '_export'] = 1;

		return params;
	},

	// opens the optional modal box
	modal: function(e, input) {
		
		var params = this.get_params( this.form );
		params[input.name] = input.value;
		
		new Ajax.Request( this.url, {
			method: 'post',
			onException: function(req, e) {
				throw e;
			},
			onSuccess: (function(transport) {
				this.modal = new EPJS_Modal( {
					'content': transport.responseText,
					'min_width': 750
				});

				this.initialize_modal();

			}).bind (this),
			parameters: params,
			evalScripts: true
		});

		return false;
	},

	// processes internal actions to the modal box
	// potential race condition here...
	modal_internal: function(event) {

		if( event != null )
			Event.stop( event );

		var args = $A(arguments);

		var el = args[1];		// the element that triggered the action
		var action = args[2];		// the name of the action
		var action_param = args[3];	// potential extra parameter required to perform the above action
		var action_element = args[4];	// potential element to send to the ActionHandler - if null, send 'el' instead
		
		var eprints_action = '_internal_' + this.prefix + '_' + action;
		if( action_param != null )
			eprints_action += '_' + action_param;
		
		var form = el.up( 'form' );

		// the params that will be sent to the Modal plugin
		var params = this.get_params( form );
		params[eprints_action] = 1;
		params['modal'] = 1;
		params['export'] = 1;

                new Ajax.Request( this.url, {
                        method: form.method,
                        onException: function(req, e) {
                                throw e;
                        },
                        onSuccess: (function(transport) {
                                
				var json = transport.responseJSON;
                                if (!json)
                                {
                                        alert ('Expected JSON but got: ' + transport.responseText);
                                        return;
                                }

				// do we need to insert some HTML on the page?
				if( json.insert != null )
				{
					var targetElId = json.insert_to;
					if( targetElId != null )
					{
						$( targetElId ).update( json.insert );
						$( targetElId ).show();
			
						// TODO - necessary?
						this.initialize_internal( $( targetElId ) );
					}
				}

				if( json.stop != null && json.stop )		// stop = closes the modal box
					 this.modal.hide();
				else
					this.initialize_modal();		// (re-) initialises the 'click' Event handlers 

				if( json.reload != null && json.reload )	// reloads the component on the submission form
					this.reload_component();


                        }).bind (this),
                        parameters: params,
			evalScripts: true
                });

		if( action_element == null )
			action_element = el;

		// any handlers?
		this.callActionHandler( action, action_element );
		
		return false;
	},

	// processes internal actions to the Component (NOT the modal)
	internal: function(e, input) {

		var params = this.get_params( this.form );

		// the action name
		params[input.name] = 1;		//input.value;
		
		// alert( 'internal action = ' + input.name );

		var container = $(this.prefix + '_content');
		this.loading( container );

		// this will send the action to the Component, this will also refresh the Component's content upon success
		new Ajax.Updater(container, this.url, {
			method: this.form.method,
			onComplete: (function() {
				this.initialize_internal( this.root );
			}).bind (this),
			parameters: params,
			evalScripts: true
		});
	},

	// shows the loading swirl
	loading: function( container ) {

		if( container == null || container.firstDescendant() == null )
			return;

		var el = new Element( 'img', {
                        src: eprints_http_root + '/style/images/loading.gif',
                        style: 'position: absolute;'
                } );

		if( container.firstDescendant() == null )
			container.update( el );
		else
			container.firstDescendant().insert( { 'before': el } );
	},

	// a handler which is executed if 'action' occurs
	registerActionHandler: function( action, handler ) {
		
		// a handler to call when 'action' is performed
		if( action != null && handler != null )
			this.handlers[action] = handler;

	},

	callActionHandler: function( action, el ) {

		if( this.handlers[action] != null )
			this.handlers[action](this, el);

	},

	// generic methods accessible via:
	// $( 'c4' ).eprints.{method_name}();
	//
	// If used in PERL, within a Component plugin, it will look like:
	// \$( $self->{prefix} ).eprints.{method_name}();
	
	reload: function() { this.reload_component() },
	reload_component: function() {
		this.internal( null, { name: '_action_null' } );
	},

	save: function() {
		this.internal( null, { name: '_internal_save' } );
	},

	hide: function() {
		this.root.hide();
	},
	
	show: function() {
		this.root.show();
	}
});

