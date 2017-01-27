var DatePicker = Class.create({
	'input': undefined,
	'container': undefined,
	'date': undefined,
	'phrases': {},

	initialize: function(basename) {
		this.input = $(basename);

		this.date = new Date ();

		this.container = new Element ('div', {
				'class': 'ep_datepicker'
			});
		this.container.setStyle ('position: absolute;');
		this.container.hide ();
		this.input.parentNode.appendChild (this.container);

		eprints.currentRepository().phrase( {
					// months
					'lib/utils:month_01': {},
					'lib/utils:month_02': {},
					'lib/utils:month_03': {},
					'lib/utils:month_04': {},
					'lib/utils:month_05': {},
					'lib/utils:month_06': {},
					'lib/utils:month_07': {},
					'lib/utils:month_08': {},
					'lib/utils:month_09': {},
					'lib/utils:month_10': {},
					'lib/utils:month_11': {},
					'lib/utils:month_12': {},

					// days of the week
					'cgi/latest:day_0': {},
					'cgi/latest:day_1': {},
					'cgi/latest:day_2': {},
					'cgi/latest:day_3': {},
					'cgi/latest:day_4': {},
					'cgi/latest:day_5': {},
					'cgi/latest:day_6': {}
				},
				(function(phrases) {
					this.phrases = phrases;
					Event.observe (this.input, 'focus', this.show.bind (this));
					Event.observe (this.input, 'keyup', (function() {
							var d = new Date (this.date);
							this.setValue (this.input.value);
							if (d.toISOString() != this.date.toISOString())
								this.refresh ();
						}).bind (this));
				}).bind (this)
			);
	},
	show: function() {
		this._hide_function = (function(evt) {
				if (evt.target != this.input && !$(evt.target).descendantOf (this.container))
				{
					Event.stopObserving (document, 'click', this._hide_function);
					this.hide ();
				}
			}).bindAsEventListener (this);
		Event.observe (document, 'click', this._hide_function);

		this.container.clonePosition (this.input, {
//				offsetTop: this.input.getHeight () + 3,
				offsetTop: this.input.getHeight,
				setWidth: false,
				setHeight: false
			});

		this.setValue (this.input.value);
		this.refresh ();
		this.container.show ();
	},
	hide: function() {
		this.container.hide();
	},
	_render_year_div: function() {
		var year_div = new Element ('div', {
				'class': 'ep_dp_year'
			});

		var prev_link = new Element ('a', {
				'href': '#'
			}).update ('<<');
		Event.observe (prev_link, 'click', (function(evt) {
				evt.stop ();

				this.date.setDate (1);
				this.date.setFullYear (this.date.getFullYear() - 10);
				this.refresh();
			}).bindAsEventListener (this));
		year_div.insert (new Element ('span', {
				'class': 'ep_dp_previous'
			}).update (prev_link) );

		prev_link = new Element ('a', {
				'href': '#'
			}).update ('<');
		Event.observe (prev_link, 'click', (function(evt) {
				evt.stop ();

				this.date.setDate (1);
				this.date.setFullYear (this.date.getFullYear() - 1);
				this.refresh();
			}).bindAsEventListener (this));
		year_div.insert (new Element ('span', {
				'class': 'ep_dp_previous'
			}).update (prev_link) );

		var year_link = new Element ('a', {
				'href': '#'
			}).update (this.date.getFullYear ());
		Event.observe (year_link, 'click', (function(evt) {
				evt.stop ();
				this.hide ();

				this.input.value = this.getValue (4);
			}).bindAsEventListener (this));
		year_div.insert (year_link);

		var next_link = new Element ('a', {
				'href': '#'
			}).update ('>>');
		Event.observe (next_link, 'click', (function(evt) {
				evt.stop ();

				this.date.setDate (1);
				this.date.setFullYear (this.date.getFullYear() + 10);
				this.refresh();
				return false;
			}).bindAsEventListener (this));
		year_div.insert (new Element ('span', {
				'class': 'ep_dp_next'
			}).update (next_link) );

		next_link = new Element ('a', {
				'href': '#'
			}).update ('>');
		Event.observe (next_link, 'click', (function(evt) {
				evt.stop ();

				this.date.setDate (1);
				this.date.setFullYear (this.date.getFullYear() + 1);
				this.refresh();
				return false;
			}).bindAsEventListener (this));
		year_div.insert (new Element ('span', {
				'class': 'ep_dp_next'
			}).update (next_link) );

		return year_div;
	},
	_render_month_div: function() {
		var month_div = new Element ('div', {
				'class': 'ep_dp_month'
			});

		var prev_link = new Element ('a', {
				'href': '#'
			}).update ('<<');
		Event.observe (prev_link, 'click', (function(evt) {
				evt.stop ();

				this.date.setDate (1);
				this.date.setMonth (this.date.getMonth() - 1);
				this.refresh();
			}).bindAsEventListener (this));
		month_div.insert (new Element ('span', {
				'class': 'ep_dp_previous'
			}).update (prev_link) );

		var month_link = new Element ('a', {
				'href': '#'
			}).update (this.phrases['lib/utils:month_' + (this.date.getMonth () + 1).toPaddedString (2)]);
		Event.observe (month_link, 'click', (function(evt) {
				evt.stop ();
				this.hide ();

				this.input.value = this.getValue (7);
			}).bindAsEventListener (this));
		month_div.insert (month_link);

		var next_link = new Element ('a', {
				'href': '#'
			}).update ('>>');
		Event.observe (next_link, 'click', (function(evt) {
				evt.stop ();

				this.date.setDate (1);
				this.date.setMonth (this.date.getMonth() + 1);
				this.refresh();
				return false;
			}).bindAsEventListener (this));
		month_div.insert (new Element ('span', {
				'class': 'ep_dp_next'
			}).update (next_link) );

		return month_div;
	},
	refresh: function() {
		var container = this.container;
		container.update ('');

		container.insert (this._render_year_div ());
		container.insert (this._render_month_div ());

		var day_div = new Element ('div', {
				'class': 'ep_dp_day'
			});
		container.insert (day_div);
		var d2 = new Date (this.date);
		d2.setDate (1);
		var offset = d2.getDay();
		var day_table = new Element ('table');
		day_div.insert (day_table);

		var tr = new Element ('tr');
		day_table.insert (tr);

		for (var j = 0; j < 7; ++j)
		{
			var td = new Element ('th');
			tr.insert (td);

			td.insert (this.phrases['cgi/latest:day_' + j].substring (0,2));
		}
		for (var i = 0; i < 6 && this.date.getMonth() == d2.getMonth (); ++i)
		{
			var tr = new Element ('tr');
			day_table.insert (tr);

			for (var j = 0; j < 7; ++j)
			{
				var td = new Element ('td');
				tr.insert (td);

				var dom = i * 7 + j - offset + 1;
				if (dom <= 0)
					continue;

				d2.setDate (dom);
				if (d2.getMonth () != this.date.getMonth ())
					break;

				if (d2.getDate () == this.date.getDate ())
					td.addClassName ('ep_dp_selected');

				var link = new Element ('a', {
						'href': '#'
					}).update (dom);
				td.insert (link);
				Event.observe (link, 'click', (function(evt, dom) {
						evt.stop ();
						this.hide ();

						this.date.setDate (dom);
						this.input.value = this.getValue ();
					}).bindAsEventListener (this, dom));
			}
		}
	},
	getValue: function(res) {
		if (!res)
			res = 10;
		return this.date.toISOString ().substring (0, res);
	},
	setValue: function(v) {
		if (v.length >= 4 && !isNaN (Number (v.substring (0,4))) )
			this.date.setFullYear (Number (v.substring (0,4)));
		if (v.length >= 7 && !isNaN (Number (v.substring (5,7))) )
			this.date.setMonth (Number (v.substring (5,7) - 1));
		if (v.length >= 10 && !isNaN (Number (v.substring (8,10))) )
			this.date.setDate (Number (v.substring (8,10)));
	}
});
