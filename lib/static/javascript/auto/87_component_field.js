var Component_Field = Class.create({
	prefix: null,

	initialize: function(prefix) {
		this.prefix = prefix;
		this.root = $(this.prefix);
		this.form = this.root.up ('form');

		this.initialize_internal();
	},
	initialize_internal: function() {
		this.root.select ('input.epjs_ajax').each ((function(input) {
			if (input.type == 'image' ) {
				var attr = input.attributesHash ();
				attr['href'] = 'javascript:';
				var link = new Element ('a', attr);
				var img = new Element ('img', {
					src: attr['src']
				});
				link.appendChild (img);
				input.replace (link);
				input = link;
			}
			else {
				var attr = input.attributesHash();
				attr['type'] = 'button';
				var button = new Element ('input', attr);
				input.replace (button);
				input = button;
			}
			input.onclick = this.internal.bindAsEventListener (this, input);
		}).bind (this));
	},
	internal: function(e, input) {
		var params = serialize_form (this.form);

		params['component'] = this.prefix;
		params[input.name] = input.value;
		params[this.prefix + '_export'] = 1;

		this.loading();

		var url = eprints_http_cgiroot + '/users/home';
		new Ajax.Updater( this.root, url, {
			method: this.form.method,
			onComplete: (function() {
				this.initialize_internal();
			}).bind (this),
			parameters: params,
			evalScripts: true
		});
	},

        // shows the loading swirl
        loading: function() {

		var container = $( this.prefix + '_content' );

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
        }

});
