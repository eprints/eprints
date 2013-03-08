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

EPrints.DragAndDrop = Class.create({
  /*
   *
   *
   * @owner - owning object
   * @container - container to turn into a hot-spot
   * @contents - hide these contents when dragging
   *
   */
  initialize: function(owner, container, contents) {
    this.owner = owner;
    this.container = container;
    this.contents = contents;

    var body = document.getElementsByTagName ('body').item (0);

    Event.observe (container, 'drop', (function(evt) {
        this.dragFinish (evt);
        this.drop (evt);
      }).bindAsEventListener(this));
    Event.observe (body, 'ep:dragcommence', (function(evt) {
        this.dragCommence (evt);
      }).bindAsEventListener(this));
    Event.observe (body, 'ep:dragfinish', (function(evt) {
        this.dragFinish (evt);
      }).bindAsEventListener(this));
  },

  dragCommence: function(evt) {
    this.container.addClassName ('ep_dropbox');
    if (this.contents)
      this.contents.hide ();
  },

  dragFinish: function(evt) {
		this.container.removeClassName ('ep_dropbox');
    if (this.contents)
      this.contents.show ();
  },

  drop: function(evt) {
    this.owner.drop(evt);
  }
});

EPrints.DragAndDrop.Files = Class.create(EPrints.DragAndDrop, {
  dragCommence: function(evt) {
		var event = evt.memo.event;
		if (event.dataTransfer.types[0] == 'Files' || event.dataTransfer.types[0] == 'application/x-moz-file')
		{
			this.container.addClassName ('ep_dropbox');
      this.contents.hide ();
		}
  },

	drop: function(evt) {
		var files = evt.dataTransfer.files;
		var count = files.length;

		if (count == 0)
			return;

		this.owner.drop (evt, files);
	}
});

EPrints.DataObj = Class.create({});

EPrints.DataObj.File = Class.create({
  initialize: function(fileid) {
    this.fileid = fileid;
  }
});

var eprints = new EPrints();
