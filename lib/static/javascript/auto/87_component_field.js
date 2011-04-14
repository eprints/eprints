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
				var link = Builder.node ('a');
				for (var i = 0; i < input.attributes.length; ++i)
					link.setAttribute (
						input.attributes[i].name,
						input.attributes[i].value
					);
				link.setAttribute ('href', 'javascript:');
				var img = Builder.node ('img', {
					src: input.getAttribute ('src')
				});
				link.appendChild (img);
				input.replace (link);
				input = link;
			}
			else
				input.setAttribute ('type', 'button');
			input.onclick = this.internal.bindAsEventListener (this, input);
		}).bind (this));
	},
	internal: function(e, input) {
		var params = serialize_form (this.form);

		params['component'] = this.prefix;
		params[input.name] = input.value;
		params[this.prefix + '_export'] = 1;

		var container = $(this.prefix + '_content');

		container.insertBefore (Builder.node ('img', {
			src: eprints_http_root + '/style/images/loading.gif',
			style: 'position: absolute;'
		}), container.firstChild);

		var url = eprints_http_cgiroot + '/users/home';
		new Ajax.Updater(container, url, {
			method: this.form.method,
			onComplete: (function() {
				this.initialize_internal();
			}).bind (this),
			parameters: params
		});
	}
});
