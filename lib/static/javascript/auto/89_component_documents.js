var Component_Documents = Class.create(Lightbox, {
	prefix: null,
	panels: null,
	documents: Array(),

	initialize: function(prefix) {
		this.prefix = prefix;
		this.panels = $(prefix + '_panels');
		Component_Documents.instances.push (this);

		var component = this;

		var form = this.panels.up('form');
		this.form = form;

		this.panels.select ('div.ep_upload_doc').each(function (doc_div) {
			var docid = component.initialize_panel (doc_div);

			component.documents.push ({
				id: docid,
				div: doc_div
			});
		});

		// Lightbox options
		this.lightbox = $('lightbox');
		this.overlay = $('overlay');
		this.lightboxMovie = $('lightboxMovie');
		this.resizeDuration = LightboxOptions.animate ? ((11 - LightboxOptions.resizeSpeed) * 0.15) : 0;
		this.overlayDuration = LightboxOptions.animate ? 0.2 : 0;
		this.outerImageContainer = $('outerImageContainer');
	},
	initialize_panel: function(panel) {
		var component = this;

		var exp = 'input[name="'+component.prefix+'_update_doc"]';
		var docid;
		panel.select (exp).each(function (input) {
			docid = input.value
		});

		panel.select ('input[rel="interactive"]', 'input[rel="automatic"]').each(function (input) {
			var type = input.getAttribute ('rel');
			var link = Builder.node ('a', {
				href: '#'
			});
			link.observe ('click',
				component.start.bindAsEventListener (component, docid, type)
			);

			var img = document.createElement ('img');
			Element.extend (img);
			for(var i = 0; i < input.attributes.length; ++i)
				img.setAttribute (
					input.attributes[i].name,
					input.attributes[i].value
				);
			link.appendChild (img);

			input.replace (link);
		});

		return docid;
	},
	start: function(event, docid, type) {
		var input = event.currentTarget.firstChild;

		var component = this;

		var action = input.name;

		var url = eprints_http_cgiroot + '/users/home';

		var params = this.serialize_form( this.form );
		params['component'] = this.prefix;
		params[this.prefix + '_update_doc'] = docid;
		params[this.prefix + '_export'] = docid;
		params[action] = 1;

		if (type == 'automatic')
		{
			new Ajax.Request(url, {
				method: 'post',
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
					this.update_documents (json);
				}).bind (this),
				parameters: params
			});
			return;
		}

        $$('select', 'object', 'embed').each(function(node){ node.style.visibility = 'hidden' });

        var arrayPageSize = this.getPageSize();
        this.overlay.setStyle({
			width: arrayPageSize[0] + 'px',
			height: arrayPageSize[1] + 'px'
		});

        new Effect.Appear(this.overlay, { duration: this.overlayDuration, from: 0.0, to: LightboxOptions.overlayOpacity });

        // calculate top and left offset for the lightbox 
        var arrayPageScroll = document.viewport.getScrollOffsets();
        var lightboxTop = arrayPageScroll[1] + (document.viewport.getHeight() / 10);
        var lightboxLeft = arrayPageScroll[0];
        $('lightboxImage').hide();
        this.lightboxMovie.hide();
		$('hoverNav').hide();
        $('prevLink').hide();
        $('nextLink').hide();
        $('imageDataContainer').setStyle({opacity: .0001});
		this.lightbox.setStyle({ top: lightboxTop + 'px', left: lightboxLeft + 'px' }).show();

		new Ajax.Request(url, {
			method: 'post',
			onException: function(req, e) {
				throw e;
			},
			onSuccess: (function(transport) {
				$('loading').hide();
				$('lightboxMovie').update (transport.responseText);
				this.resizeImageContainer (640, this.lightboxMovie.getHeight());
				var form = $('lightboxMovie').down ('form');
				if (!form.onsubmit)
				{
					form.onsubmit = function() { return false; };
					form.select ('input[type="submit"]', 'input[type="image"]').each (function (input) {
						input.observe ('click',
							component.stop.bindAsEventListener (component)
						);
					});
				}
				$('lightboxMovie').show();
			}).bind (this),
			parameters: params
		});
	},
	stop: function(event) {
		var input = event.currentTarget;

		var form = input.up ('form');
		var params = this.serialize_form( form );

		params[input.name] = 1;
		params['export'] = 1;

		this.lightboxMovie.hide();
		this.lightboxMovie.update ('');
		$('loading').show();

		var url = eprints_http_cgiroot + '/users/home';
		new Ajax.Request(url, {
			method: form.method,
			onException: function(req, e) {
				throw e;
			},
			onSuccess: (function(transport) {
				this.end();
				var json = transport.responseJSON;
				if (!json)
				{
					alert ('Expected JSON but got: ' + transport.responseText);
					return;
				}
				this.update_documents (json);
			}).bind (this),
			parameters: params
		});
	},
    resizeImageContainer: function(imgWidth, imgHeight) {

        // get current width and height
        var widthCurrent  = this.outerImageContainer.getWidth();
        var heightCurrent = this.outerImageContainer.getHeight();

        // get new width and height
        var widthNew  = (imgWidth  + LightboxOptions.borderSize * 2);
        var heightNew = (imgHeight + LightboxOptions.borderSize * 2);

        // scalars based on change from old to new
        var xScale = (widthNew  / widthCurrent)  * 100;
        var yScale = (heightNew / heightCurrent) * 100;

        // calculate size difference between new and old image, and resize if necessary
        var wDiff = widthCurrent - widthNew;
        var hDiff = heightCurrent - heightNew;

		this.outerImageContainer.setStyle({ width: widthNew + 'px' });
		this.outerImageContainer.setStyle({ height: heightNew + 'px' });
	},
	remove_document: function(i) {
		var doc_div = this.documents[i].div;
		this.documents.splice (i, 1);
		new Effect.SlideUp (doc_div, {
			duration: this.resizeDuration,
			afterFinish: (function() {
				this.panels.removeChild (doc_div);
			}).bind (this)
		});
	},
	update_documents: function(json) {
		// remove any deleted
		for (var i = 0; i < this.documents.length; ++i)
			for (var j = 0; j <= json.length; ++j)
				if (j == json.length )
					this.remove_document (i--);
				else if (this.documents[i].id == json[j].id)
					break;
		// add any new
		for (var i = 0; i < json.length; ++i)
			for (var j = 0; j <= this.documents.length; ++j)
				if (j == this.documents.length)
					this.refresh_document (json[i].id);
				else if (json[i].id == this.documents[j].id)
					break;
		// sanity check
		if (this.documents.length != json.length)
			throw 'Removing/adding documents resulted in length mismatch';
		// re-order if out of order
		for (var i = 0; i < json.length; ++i)
			for (var j = 0; j < this.documents.length; ++j)
				if (json[i].id == this.documents[j].id)
				{
					this.documents[j].placement = i;
					break;
				}
		for (var i = 0; i < this.documents.length; ++i)
			if (this.documents[i].placement > i)
			{
				var left = this.documents[i];
				var right = this.documents[left.placement];
				new Effect.SlideUp (left.div, {
					duration: this.resizeDuration,
					afterFinish: (function() {
						this.panels.removeChild (left.div);
						if (left.placement == this.documents.length-1)
							this.panels.appendChild (left.div);
						else
							this.panels.insertBefore (left.div, this.documents[left.placement+1].div);
						new Effect.SlideDown (left.div, {
							duration: this.resizeDuration
						});
					}).bind (this)
				});
				this.documents.splice (i, 1);
				this.documents.splice (left.placement, 0, left);
				--i;
			}
	},
	refresh_document: function(docid) {
		var params = this.serialize_form (this.form);

		params['component'] = this.prefix;
		delete params[this.prefix + '_update_doc'];
		params[this.prefix + '_export'] = docid;

		var url = eprints_http_cgiroot + '/users/home';
		new Ajax.Request(url, {
			method: this.form.method,
			onException: function(req, e) {
				throw e;
			},
			onSuccess: (function(transport) {
				var doc_div = document.createElement ('div');
				doc_div.update (transport.responseText);
				doc_div = doc_div.removeChild (doc_div.firstChild);
				this.initialize_panel (doc_div);
				var doc;
				for (var i = 0; i < this.documents.length; ++i)
					if (this.documents[i].id == docid)
					{
						doc = this.documents[i];
						break;
					}
				if (doc)
				{
					doc.div.replace (doc_div);
					doc.div = doc_div;
				}
				else
				{
					doc = {
						id: docid,
						div: doc_div
					};
					this.documents.push (doc);
					doc_div.hide();
					this.panels.appendChild (doc_div);
					new Effect.SlideDown (doc_div, {
						duration: this.resizeDuration
					});
				}
			}).bind (this),
			onFailure: (function(transport) {
				if (transport.status == 404)
					for (var i = 0; i < this.documents.length; ++i)
						if (this.documents[i].id == docid)
						{
							this.documents[i].div.remove();
							this.documents.splice (i, 1);
							return;
						}
			}).bind (this),
			parameters: params
		});
	},
	serialize_form: function(form) {
		// Prototype doesn't ignore image inputs which are equivalent to submit
		// buttons
		var images = form.select ('input[type="image"]');
		images.invoke ('disable');

		var params = form.serialize({
			hash: true,
			submit: false
		});

		images.invoke ('enable');

		return params;
	}
});
Component_Documents.instances = $A(Array());
