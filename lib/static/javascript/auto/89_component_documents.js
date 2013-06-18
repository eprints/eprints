var Component_Documents = Class.create({
	prefix: null,
	container: null,
	documents: {},

	initialize: function(prefix) {
		this.prefix = prefix;
		this.container = $(prefix + '_panel');
		this.form = this.container.up('form');

		this.resizeDuration = LightboxOptions.animate ? ((11 - LightboxOptions.resizeSpeed) * 0.15) : 0;

		this.container.select ('div.ep_upload_doc').each((function (doc_div) {
      var doc = new Component_Documents.Document (this, doc_div.id);
      this.documents[doc.docid] = doc;
		}).bind(this));

		this.format = '^' + this.prefix + '_doc([0-9]+)';
		this.initialize_sortable();

		Component_Documents.instances.push (this);
	},

	initialize_sortable: function() {
		Sortable.create (this.container, {
			tag: 'div',
			only: 'ep_upload_doc',
			format: this.format,
			onUpdate: this.drag.bindAsEventListener (this)
		});
	},

  /* calculate the order of the documents according to Sortable */
	order: function() {
		var query = Sortable.serialize (this.container, {
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

  /* drag-end for Sortable */
	drag: function(container) {
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

	update_messages: function(json) {
		var container = $('ep_messages');
    if (!container) {
      throw new Error ('ep_messages container missing');
    }
		container.update ('');
		for(var i = 0; i < json.length; ++i)
			container.insert (json[i]);
	},

	remove_document: function(docid) {
    var doc = this.documents[docid];
    this.documents[docid] = undefined;
		if (!doc)
			return false;
    doc.remove ();
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
		left = this.documents[left].container;
		right = this.documents[right].container;
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
    var doc = this.documents[docid];

    if (doc) {
      doc.refresh ();
    }
    else {
      this.addDocument (docid);
    }
  },

  addDocument: function(docid) {
    var params = serialize_form (this.form);

    params['component'] = this.prefix;
    params[this.prefix + '_export'] = docid;

    var url = eprints_http_cgiroot + '/users/home';
    new Ajax.Request(url, {
      method: this.form.method,
      onException: function(req, e) {
        throw e;
      },
      onSuccess: (function(transport) {
        var prefix = this.prefix + '_doc' + docid;
        var div = new Element ('div', {
          id: prefix,
          'class': 'ep_upload_doc'
        });
        div.hide ();
        this.container.appendChild (div);

        div.update (transport.responseText);
        this.documents[docid] = new Component_Documents.Document (this, prefix);

        new Effect.SlideDown (div, {
          duration: this.resizeDuration,
          afterFinish: (function() {
            this.initialize_sortable();
          }).bind (this)
        });
      }).bind (this),
      parameters: params
    });
	}
});
Component_Documents.instances = $A(Array());

Component_Documents.Document = Class.create({
  initialize: function(component, prefix) {
    this.component = component;
    this.prefix = prefix;
    this.container = $(prefix);
    this.docid = $F(prefix + '_docid');
		this.progress_table = $(this.prefix + '_progress_table');

    this.initialize_panel();

		this.parameters = new Hash({
			screen: $F('screen'),
			eprintid: $F('eprintid'),
			stage: $F('stage'),
			component: this.component.prefix,
      _CSRF_Token: $F('_CSRF_Token')
		});
  },

  /* replace inputs with javascript widgets */
	initialize_panel: function() {
    this.container.select ('input[rel="automatic"]').each (function (input) {
      input.observe ('click', this.openAutomatic.bindAsEventListener (this, input));
    }.bind (this));

    this.container.select ('input[rel="interactive"]').each (function (input) {
      input.observe ('click', this.openInteractive.bindAsEventListener (this, input));
    }.bind (this));

    new EPrints.DragAndDrop.Files (this, $(this.prefix + '_dropbox'), $(this.prefix + '_content'));
	},

  openAutomatic: function(event, input) {
    var docid = this.docid;
    var component = this.component;

    event.stop();

		var url = eprints_http_cgiroot + '/users/home';

    var params = serialize_form (this.component.form);

		params['component'] = component.prefix;
		params[component.prefix + '_update'] = docid;
		params[component.prefix + '_export'] = docid;
		params[input.name] = 1;

    new Ajax.Request(url, {
      method: 'post',
      onException: function(req, e) {
        throw e;
      },
      onSuccess: (function(transport) {
        var json = transport.responseJSON;
        if (!json) {
          throw new Error ('Expected JSON but got: ' + transport.responseText);
        }
        component.update_documents (json.documents);
        component.update_messages (json.messages);
      }).bind (this),
      parameters: params
    });
  },

	openInteractive: function(event, input) {
    var docid = this.docid;
    var component = this.component;

    event.stop();

		var url = eprints_http_cgiroot + '/users/home';

		var params = serialize_form( this.component.form );

		params['component'] = component.prefix;
		params[component.prefix + '_update'] = docid;
		params[component.prefix + '_export'] = docid;
		params[input.name] = 1;

    new Lightbox.Dialog ({
      onShow: (function(dialog) {
        new Ajax.Request(url, {
          method: 'post',
          onException: function(req, e) {
            throw e;
          },
          onSuccess: (function(transport) {
            dialog.update (transport.responseText);
          
            var form = dialog.content.down ('form');
            if (form && !form.onsubmit)
            {
              form.onsubmit = function() { return false; };
              form.select ('input[type="submit"]', 'input[type="image"]').each (function (input) {
                input.observe ('click', this.closeInteractive.bindAsEventListener (this, dialog, input));
              }.bind (this));
            }
          }).bind (this),
          parameters: params
        });
      }).bind (this)
    });
	},

	closeInteractive: function(event, dialog, input) {
    var component = this.component;

		var form = input.up ('form');
		var params = serialize_form( form );

		params[input.name] = 1;
		params['export'] = 1;

    dialog.update ('');

		var url = eprints_http_cgiroot + '/users/home';

		new Ajax.Request(url, {
			method: form.method,
			onException: function(req, e) {
				throw e;
			},
			onSuccess: (function(transport) {
				dialog.end();

				var json = transport.responseJSON;
				if (!json) {
          throw new Error ('Expected JSON but got: ' + transport.responseText);
        }

				component.update_documents (json.documents);
				component.update_messages (json.messages);
			}).bind (this),
			parameters: params
		});
	},

  drop: function(evt, files) {
    if (files.length == 0)
      return;

    this.handleFiles (files);
  },

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
						for(var i = 0; i < files.length; ++i)
							this.createFile (files[i]);
				}).bind (this)
			);
		}
		else
			for(var i = 0; i < files.length; ++i)
				this.createFile (files[i]);
	},
	createFile: function(file) {
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

		this.progress_table.insert (progress_row);

		this.updateProgress (file, 0);

    var url = eprints_http_root + '/id/document/' + this.docid;

    new Ajax.Request(url, {
      method: 'get',
      requestHeaders: {
        'Accept': 'application/json'
      },
			onException: function(req, e) {
				throw e;
			},
      onSuccess: (function(transport) {
        var json = transport.responseJSON;
        if (!json) {
          throw new Error('Expected JSON but got: ' + transport.responseText);
        }

        // does this file already exist?
        var epdata;
        if (json.files) {
          for(var i = 0; i < json.files.length; ++i)
          {
            if (json.files[i].filename == file.name) {
              epdata = json.files[i];
              break;
            }
          }
        }

        if (epdata) {
          file.docid = this.docid;
          file.fileid = epdata.fileid;
          this.postFile (file, epdata.filesize);
        }
        else {
          var url = eprints_http_root + '/id/document/' + this.docid + '/contents';
          var params = this.parameters.clone();

          var bufsize = 1048576;
          var buffer = file.slice (0, bufsize);

          new Ajax.Request(url, {
            method: 'post',
            contentType: file.type,
            requestHeaders: {
              'Content-Range': '0-' + (buffer.size-1) + '/' + file.size,
              'Content-Disposition': 'attachment; filename=' + file.name,
              'Accept': 'application/json'
            },
            onException: function(req, e) {
              throw e;
            },
            onSuccess: (function(transport) {
              var json = transport.responseJSON;
              if (!json) {
                throw new Error('Expected JSON but got: ' + transport.responseText);
              }
              file.docid = json['objectid'];
              file.fileid = json['fileid'];
              /* button.update (json['phrases']['abort']);
              button.show(); */
              this.postFile (file, buffer.size);
            }).bind (this),
            parameters: params,
            postBody: buffer
          });
        }
      }).bind (this)
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
      contentType: file.type,
			requestHeaders: {
				'Content-Range': '' + offset + '-' + (offset + buffer.size) + '/' + file.size,
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

    file.progress_container.parentNode.removeChild (file.progress_container);
    this.component.refresh_document (file.docid);
	},
	/*
	 * Abort and clean-up the file upload
	 */
	abortFile: function(file) {
		file.abort = true;
		file.progress_button.hide();

		if (!file.docid)
			return;

		var url = eprints_http_root + '/id/file/' + file.fileid;

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
	},

  refresh: function() {
		var params = serialize_form (this.component.form);

		params['component'] = this.component.prefix;
		params[this.component.prefix + '_export'] = this.docid;

    var url = eprints_http_cgiroot + '/users/home';
    new Ajax.Request(url, {
      method: this.component.form.method,
      onException: function(req, e) {
        throw e;
      },
      onFailure: (function(transport) {
        if (transport.status == 404) {
          this.component.remove_document (this.docid);
          this.component.initialize_sortable();
        }
      }).bind (this),
      onSuccess: (function(transport) {
        var progress_table = this.progress_table;
        progress_table.parentNode.removeChild (progress_table);

        this.container.update (transport.responseText);
        $(this.prefix + '_progress_table').replace (progress_table);

        this.initialize_panel();
      }).bind (this),
      parameters: params
    });
  },

  remove: function() {
		new Effect.SlideUp (this.container, {
			duration: this.component.resizeDuration,
			afterFinish: (function() {
				this.container.remove();
			}).bind (this)
		});
  }
});
