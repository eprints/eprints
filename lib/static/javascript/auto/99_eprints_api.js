var EPrints = Class.create({
	initialize: function() {
		this.currentRepository = new EPrints.Repository();
	},
	CurrentRepository: function() {
		return this.currentRepository;
	}
});

EPrints.Repository = Class.create({
	initialize: function() {
	},
	/*
	 * Retrieve phrase(s) from the server
	 * @phraseid id of phrase to retrieve
	 * @pins an associative array of pin values
	 * @f function callback once the phrases have been retrieved
	 */
	phrase: function(phraseid, pins, f)
	{
		var url = eprints_http_cgiroot + "/ajax/phrase";
		var params = Array();
		params['textonly'] = 1;
		params['phraseid'] = phraseid;
		for (var key in pins)
			params['pin.' + key] = pins[key];
		new Ajax.Request(url, {
			method: 'post',
			onException: function(req, e) {
				f (e.toString());
			},
			onFailure: function(transport) {
				throw new Error ('[Error ' + transport.status + ' requesting phrase "' + phraseid + '"]');
			},
			onSuccess: function(transport) {
				f (transport.responseText);
			},
			parameters: params
		});
	}
});

var eprints = new EPrints();
