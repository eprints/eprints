/*
 *
 * Simple Progress Bar Widget
 *
 * Usage:
 *
 * var epb = new EPrintsProgressBar({}, container);
 *
 * epb.update( .3, '30%' );
 */

var EPrintsProgressBar = Class.create({
	initialize: function(opts, container) {
		this.opts = {};
		this.container = container;
		this.img_path = eprints_http_root + '/style/images/';

		this.current = 0;
		this.progress = 0;

		this.opts.bar = opts.bar == null ? 'progress_bar.png' : opts.bar;
		this.opts.border = opts.border == null ? 'progress_border.png' : opts.border;
		this.opts.show_text = opts.show_text == null ? 0 : opts.show_text;

		this.img = document.createElement( 'img' );
		Element.extend( this.img );
		this.container.appendChild( this.img );

		this.img.observe('load', this.onload.bind(this));
		this.img.src = this.img_path + this.opts.border;
		this.img.addClassName( 'ep_progress_bar' );
	},
	onload: function() {
		this.img.setStyle({
			background: 'url(' + this.img_path + this.opts.bar + ') top left no-repeat'
		});
		this.update( this.progress, '' );
	},
	update: function(progress, alt) {
		if( progress == null || progress < 0 || progress > 1 )
			return;

		this.progress = progress;

		this.img.setAttribute( 'alt', alt );

		if( this.timer )
			this.timer.stop();
		this.timer = new PeriodicalExecuter(this._update.bind(this), .1);
		this._update();
	},
	_update: function() {
		var width = this.img.getWidth();
		if( !width )
			return;

		var x_offset = Math.round( this.progress * width );
		if( x_offset == this.current )
			this.timer.stop();
		else
			this.current = x_offset;
		this.img.setStyle({
			backgroundPosition: (this.current-width) + 'px 0px'
		});
	}
});
