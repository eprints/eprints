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

		this.format = '^' + this.prefix + '_doc([0-9]+)';
		this.initialize_sortable();

		// Lightbox options
		this.lightbox = $('lightbox');
		this.overlay = $('overlay');
		this.loading = $('loading');
		this.lightboxMovie = $('lightboxMovie');
		this.resizeDuration = LightboxOptions.animate ? ((11 - LightboxOptions.resizeSpeed) * 0.15) : 0;
		this.overlayDuration = LightboxOptions.animate ? 0.2 : 0;
		this.outerImageContainer = $('outerImageContainer');
	},
	initialize_sortable: function() {
		Sortable.create (this.panels.id, {
			tag: 'div',
			only: 'ep_upload_doc',
			format: this.format,
			onUpdate: this.drag.bindAsEventListener (this)
		});
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
			var attr = input.attributesHash ();
			attr['href'] = 'javascript:';
			var link = new Element ('a', attr);
			var img = new Element ('img', {
				src: attr['src']
			});
			link.appendChild (img);

			Event.observe( link, 'click', this.start.bindAsEventListener(this, link, docid, type ) );

			input.replace (link);
		}.bind(this));

		return docid;
	},
	find_document_div: function(docid) {
		return $(this.prefix + '_doc' + docid + '_block');
	},
	order: function() {
		var query = Sortable.serialize (this.panels, {
			tag: 'div',
			format: this.format
		});
		var parts = query.split ('&');
		var docids = Array();
		$A(parts).each(function(part) {
			docids.push (part.split ('=')[1]);
		});
		return docids;
	},
	drag: function(panels) {
		var url = eprints_http_cgiroot + '/users/home';

		var action = '_internal_' + this.prefix + '_reorder';

		var params = serialize_form (this.form);
		params['component'] = this.prefix;
		params[this.prefix + '_order'] = this.order();
		params[action] = 1;

		new Ajax.Request(url, {
			method: 'get',
			onException: function(req, e) {
				throw e;
			},
			onSuccess: (function(transport) {
			}).bind (this),
			parameters: params
		});
	},
	start: function(event, input, docid, type) {

		var component = this;

		var action = input.name;

		var url = eprints_http_cgiroot + '/users/home';

		var params = serialize_form( this.form );
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
						console.log ('Expected JSON but got: ' + transport.responseText);
						return;
					}
					this.update_documents (json.documents);
					this.update_messages (json.messages);
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
				this.loading.hide();
				$('lightboxMovie').update (transport.responseText);
			
				var boxWidth = this.lightboxMovie.getWidth();
				if( boxWidth == null || boxWidth < 640 )
					boxWidth = 640;
				this.resizeImageContainer ( boxWidth, this.lightboxMovie.getHeight());
				var form = $('lightboxMovie').down ('form');
				if (!form.onsubmit)
				{
					form.onsubmit = function() { return false; };
					form.select ('input[type="submit"]', 'input[type="image"]').each (function (input) {
						input.observe ('click',
							component.stop.bindAsEventListener (component, input)
						);
					});
				}
				$('lightboxMovie').show();
			}).bind (this),
			parameters: params
		});
	},
	stop: function(event, input) {

		var form = input.up ('form');
		var params = serialize_form( form );

		params[input.name] = 1;
		params['export'] = 1;

		this.lightboxMovie.hide();
		this.lightboxMovie.update ('');
		this.loading.show();

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
					console.log ('Expected JSON but got: ' + transport.responseText);
					return;
				}
				this.update_documents (json.documents);
				this.update_messages (json.messages);
			}).bind (this),
			parameters: params
		});
	},
	resizeImageContainer: function(imgWidth, imgHeight) {

        // get new width and height
        var widthNew  = (imgWidth  + LightboxOptions.borderSize * 2);
        var heightNew = (imgHeight + LightboxOptions.borderSize * 2);

	this.outerImageContainer.setStyle({ width: widthNew + 'px' });
	this.outerImageContainer.setStyle({ height: heightNew + 'px' });
	},
	update_messages: function(json) {
		var container = $('ep_messages');
		if (!container) return; // odd
		container.update ('');
		for(var i = 0; i < json.length; ++i)
			container.insert (json[i]);
	},
	remove_document: function(docid) {
		var doc_div = this.find_document_div (docid);
		if (!doc_div)
			return false;
		new Effect.SlideUp (doc_div, {
			duration: this.resizeDuration,
			afterFinish: (function() {
				doc_div.remove();
			}).bind (this)
		});
		return true;
	},
	update_documents: function(json) {
		var corder = this.order();
		var actions = Array();
		// remove any deleted
		for (var i = 0; i < corder.length; ++i)
			for (var j = 0; j <= json.length; ++j)
				if (j == json.length )
				{
					this.remove_document (corder[i]);
					corder.splice (i, 1);
					--i;
				}
				else if (corder[i] == json[j].id)
					break;
		// add any new or any forced-refreshes
		for (var i = 0; i < json.length; ++i)
			for (var j = 0; j <= corder.length; ++j)
				if (json[i].refresh)
				{
					this.refresh_document (json[i].id);
					break;
				}
				else if (j == corder.length)
				{
					this.refresh_document (json[i].id);
					corder.push (json[i].id);
					break;
				}
				else if (json[i].id == corder[j])
					break;
		// bubble-sort to reorder the documents in the order given in json
		var place = {};
		for (var i = 0; i < json.length; ++i)
			place[json[i].id] = parseInt (json[i].placement);
		var swapped;
		do {
			swapped = false;
			for (var i = 0; i < corder.length-1; ++i)
				if (place[corder[i]] > place[corder[i+1]])
				{
					this.swap_documents (corder[i], corder[i+1]);
					var t = corder[i];
					corder[i] = corder[i+1];
					corder[i+1] = t;
					swapped = true;
				}
		} while (swapped);
	},
	swap_documents: function(left, right) {
		left = this.find_document_div (left);
		right = this.find_document_div (right);
/*		left.parentNode.removeChild (left);
		right.parentNode.insertBefore (left, right.nextSibling);
		return; */
		new Effect.SlideUp(left, {
			duration: this.resizeDuration,
			queue: 'end',
			afterFinish: function() {
				left.remove();
				right.parentNode.insertBefore (left, right.nextSibling);
			}
		});
		new Effect.SlideDown(left, {
			duration: this.resizeDuration,
			queue: 'end',
			afterFinish: (function() {
				this.initialize_sortable();
			}).bind (this)
		});
	},
	refresh_document: function(docid) {
		var params = serialize_form (this.form);

		params['component'] = this.prefix;
		delete params[this.prefix + '_update_doc'];
		params[this.prefix + '_export'] = docid;

		/* create an empty div that will hold the document */
		var doc_div = this.find_document_div (docid);
		if (!doc_div)
		{
			doc_div = Builder.node ('div', {
				id: this.prefix + '_doc' + docid + '_block',
				'class': 'ep_upload_doc'
			});
			this.panels.appendChild (doc_div);
		}
		else
		{
			doc_div.insertBefore (new Element ('img', {
				src: eprints_http_root + '/style/images/lightbox/loading.gif',
				style: 'position: absolute;'
			}), doc_div.firstChild );
		}

		var url = eprints_http_cgiroot + '/users/home';
		new Ajax.Request(url, {
			method: this.form.method,
			onException: function(req, e) {
				throw e;
			},
			onSuccess: (function(transport) {
				var div = Builder.node ('div');
				div.update (transport.responseText);
				div = $(div.firstChild);

				div.hide();
				this.initialize_panel (div);

				if (doc_div.hasChildNodes)
				{
					div.show ();
					doc_div.replace (div);
					this.initialize_sortable ();
				}
				else
				{
					doc_div.replace (div);

					new Effect.SlideDown (div, {
						duration: this.resizeDuration,
						afterFinish: (function() {
							this.initialize_sortable();
						}).bind (this)
					});
				}
			}).bind (this),
			onFailure: (function(transport) {
				if (transport.status == 404)
					if (this.remove_document (docid))
						this.initialize_sortable();
			}).bind (this),
			parameters: params
		});
	}
});
Component_Documents.instances = $A(Array());
