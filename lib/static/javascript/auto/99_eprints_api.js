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
				console.log (e.toString());
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

var eprints = new EPrints();
