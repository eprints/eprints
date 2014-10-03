var Metafield = Class.create({
	prefix: null,
	name: null,
	opts: {},
	input_bits: null,

	initialize: function(prefix, name, opts) {
		this.prefix = prefix;
		this.name = name;
		this.opts = opts ? opts : {};
		this.basename = prefix + '_' + name;

		/* ep_autocompleter doesn't check for definedness */
		if (this.opts['input_lookup_params'] == null)
			this.opts['input_lookup_params'] = '';

		this.root = $(this.prefix);
		/* 
		    for documents, the containing element has an id like 'c1_doc1_block'
		    if the above has failed, this check will enable lookups for document fields
		*/
		if(!this.root){
			this.root= $(this.prefix+'_block');
		}

		this.spaces = $(this.prefix + '_' + name + '_spaces');
		if (this.spaces)
			this.spaces = this.spaces.value;
		this.is_multiple = this.spaces != null;

		if (this.opts['input_lookup_url']) {
			if (this.is_multiple) {
				for (var i = 1; i <= this.spaces; ++i) {
					var basename = this.basename + '_' + i;
					this.initialize_input_bits (basename);
					this.initialize_row (basename);
				}
			}
			else {
				this.initialize_input_bits (this.basename);
				this.initialize_row (this.basename);
			}
		}
	},
	initialize_input_bits: function(basename) {
		this.input_bits = $A();
		var match = new RegExp ('^' + basename + '_');
		this.root.select ('input[type="text"]', 'textarea').each ((function(input) {
			if (input.id.match (match)) {
				var sub_name = input.id.substring (basename.length);
				if (sub_name.length)
					this.input_bits.push (sub_name);
			}
		}).bind (this));
	},
	initialize_row: function(basename) {
		var ep_drop_target = Builder.node ('div', {
			id: basename + '_drop',
			'class': 'ep_drop_target',
			style: 'position: absolute; display: none;'
		});
		var ep_drop_loading = Builder.node ('div', {
			id: basename + '_drop_loading',
			'class': 'ep_drop_loading',
			style: 'position: absolute; display: none;'
		});
		var inputs = $A ();
		if (this.input_bits.length) {
			this.input_bits.each ((function(bit) {
				var input = $(basename + bit);
				inputs.push (input);
			}).bind (this));
			inputs[0].parentNode.appendChild (ep_drop_target);
			inputs[0].parentNode.appendChild (ep_drop_loading);
		}
		else {
			var input = $(basename);
			input.parentNode.appendChild (ep_drop_target);
			input.parentNode.appendChild (ep_drop_loading);
			inputs.push (input);
		}
		this.initialize_row_inputs (basename, inputs, ep_drop_target.id);
	},
	initialize_row_inputs: function(basename, inputs, targetid) {
		inputs.each ((function(input) {
			ep_autocompleter (
				input,
				targetid,
				this.opts['input_lookup_url'],
				{
					relative: basename,
					component: this.prefix
				},
				inputs,
				this.input_bits,
				this.opts['input_lookup_params']
			);
		}).bind (this));
	}
});
