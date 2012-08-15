var EPrints = Class.create({
	_currentRepository: undefined,

	initialize: function() {
		this._currentRepository = new EPrints.Repository();
	},
	currentRepository: function() {
		return this._currentRepository;
	}
});

EPrints.Repository = Class.create({
	initialize: function() {
	},
	/*
	 * Retrieve one or more phrases from the server
	 * @input associative array where the keys are phrase ids and the values
	 * are pins
	 * @f function to call with the resulting phrases
	 * @textonly retrieve phrase text content only (defaults to false)
	 */
	phrase: function(phrases, f, textonly)
	{
		var url = eprints_http_cgiroot + '/ajax/phrase?';
		if (textonly)
			url += 'textonly=1';
		new Ajax.Request(url, {
			method: 'post',
			onException: function(req, e) {
				alert (e.toString());
			},
			onFailure: function(transport) {
				throw new Error ('Error ' + transport.status + ' requesting phrases (check server log for details)');
			},
			onSuccess: function(transport) {
				if (!transport.responseJSON)
					throw new Error ('Failed to get JSON from phrases callback');
				f (transport.responseJSON);
			},
			postBody: Object.toJSON (phrases)
		});
	}
});

EPrints.XHTML = Class.create({
	initialize: function() {
	}
});

EPrints.XHTML.Box = Class.create({
	initialize: function(basename) {
		this.basename = basename;

		this.show_link = $(basename + "_show_link");
		this.hide_link = $(basename + "_hide_link");
		this.content = $(basename + "_content");

		this.show_link.observe ('click', this.show.bindAsEventListener (this));
		this.hide_link.observe ('click', this.hide.bindAsEventListener (this));

		if (this.content.hasClassName ('ep_no_js'))
		{
			/* clear the no-javascript class */
			this.content.removeClassName ('ep_no_js');

			/* calculate the height of the content, using the visibility hack */
			this.content.style.visibility = 'hidden';
			this.content.show();

			this.height = this.content.getHeight();

			this.content.hide();
			this.content.style.visibility = 'visible';
		}
		else
		{
			this.height = this.content.getHeight();
		}
	},
	show: function(e) {
		this.show_link.hide();
		this.hide_link.style.display = 'block';

		this.content.style.overflow = 'hidden';

		this.content.style.height = '0px';

		this.content.show();

		new Effect.Scale (this.content,
				100,
				{
					scaleX: false,
					scaleContent: false,
					scaleFrom: 0,
					duration: 0.3,
					transition: Effect.Transitions.linear,
					scaleMode: {
						originalHeight: this.height
					},
					afterFinish: (function () { 
						this.content.style.overflow = 'visible'; 
						this.content.style.height = ''; 
					}).bind (this)
				}
			);
	},
	hide: function(e) {
		this.hide_link.hide();
		this.show_link.style.display = 'block';

		this.content.style.overflow = 'hidden';

  		new Effect.Scale(this.content,
				0,
    			{ 
					scaleX: false,
					scaleContent: false,
					scaleFrom: 100,
					duration: 0.3,
					transition: Effect.Transitions.linear,
					afterFinish: (function () {
						this.content.hide();
						this.content.style.height = '';
					}).bind (this),
					scaleMode: {
						originalHeight: this.content.getHeight()
					}
				}
			);
	}
});

var eprints = new EPrints();
