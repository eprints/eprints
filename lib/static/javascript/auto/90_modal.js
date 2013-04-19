// Creates a Dialog Box with overlay.
// 
// Input params: 
//	EITHER an "id" (the "id" of the element which will be the content of the popup), 
//	OR raw HTML passed through 'content'
//
//	Optional:
//	- 'show' (true/false): show dialog box upon creation
//	- 'callback' (function): a function to call upon deletion of the dialog box
//	- 'style' (true/false, default true): tells to re-use EPrints default Workflow CSS

var EPJS_Modal = Class.create( {

	overlay: null,
	offset_top: null,

	width: 600,
	height: 500,

	// for caching - screen dimensions
	hscreen: 0,
	wscreen: 0,
	
	initialize: function( params ) {

		this.content = new Element( 'div' );
		this.content.update( params.content );

		this.body = this.getBody();
		if( this.body == null )
		{
			alert( "Failed to retrieve the <body> tag." );
			return false;
		}
		
		this.hscreen = document.viewport.getHeight() || 0;
		this.wscreen = document.viewport.getWidth() || 0;

		if( params.height != null )
			this.height = params.height;

		if( params.width != null )
			this.width = params.width;

		if( params.callback != null )
			this.callback = params.callback;
	
		if( params.offset_top != null )
			this.offset_top = params.offset_top;

		this.initialize_overlay();

		if( params.show == null || params.show )
			this.show();

		return false;
	},

	initialize_overlay: function() {
	
		this.overlay = new Element( 'div', { 'class': 'ep_overlay', 'style': 'display:none' } );
		Element.insert( this.body, { 'top': this.overlay } );

		// need to compute the height for the overlay so that the entire screen is covered
		var overlay_h = 0;

		var screen = document.viewport.getDimensions();
		if( screen != null && screen.height != null )
			overlay_h = screen.height;
		else
		{
			// using a marker div at the end to find the page's height
			if( $( 'ep_modal_overlay_marker' ) == null )
			{
				this.marker = new Element( 'div', { 'id': 'ep_modal_overlay_marker' } );
				Element.insert( this.body, { 'bottom': this.marker } );
			}

			overlay_h =  $( 'ep_modal_overlay_marker' ).offsetTop + 100;
		}

		if( overlay_h == null || overlay_h < 0 )
			overlay_h = 1000;

		this.overlay.setStyle( { height: overlay_h + 'px' } );

		this.body.addClassName( 'ep_overlay' );

		// this extra CSS class attempts to loss of the window scroll-bar on the right-side by setting a margin
		// this will prevent the page from flickering when the overlay is shown
		if( this.body.getHeight() > this.hscreen ) 
			this.body.addClassName( 'ep_overlay_padding' );
		
		// if the user clicks on the overlay, we close the modal box
		this.overlay.observe( 'click', this.hide.bindAsEventListener(this) );

		// (we need to cache the handler, in order to be able to remove it later - see http://prototypejs.org/api/event/stopobserving)
		this.eventHandler = this.keyPressed.bindAsEventListener(this);

		// if the user presses 'Esc'
		Event.observe( document, 'keypress', this.eventHandler );
	},
	
	keyPressed: function(event) {

                if( Event.KEY_RETURN == event.keyCode )
                {
			// ignore 'Enter/Return' being pressed
                        Event.stop( event );
                        return true;
                }
		else if( Event.KEY_ESC == event.keyCode )
		{
			// sf2 - doesn't seem to work
			Event.stop( event );
			this.overlay.click();
			return true;
		}
		return false;
	},
	
	initialize_modal: function() {

		this.content.setStyle( {
			'width': this.width+'px'
		} );

		Element.insert( this.body, { 'top': this.content } );

		this.content.hide();
		this.content.show = this.show.bind(this);
		this.content.style.position = "fixed";
		this.content.addClassName( 'ep_modal_box' );
	},
 
	getBody: function() {
	
		var zbody = document.getElementsByTagName( 'body' );
		if( zbody != null && zbody.length > 0 )
			return zbody[0];

		return null;
	},
 
	reposition: function() {

		var h = this.hscreen;
		var w = this.wscreen;

		var ideal_top = this.offset_top;

		if( ideal_top == null || ideal_top < 0 )
		{	
			ideal_top = ( h / 2 - this.content.getHeight() / 2 );
			if( ideal_top < 0 )
				ideal_top = 0;
		}

		this.content.style.left = ( w / 2 - this.content.getWidth() / 2 ) + 'px';
		this.content.style.top = ideal_top + 'px';
		
		// if the user's screen is too small to display the modal box, let's resize it
		// if( h < this.content.getHeight() )
		//	this.content.setStyle( { 'height': h+'px', 'overflow': 'scroll' } );

	},

	get_content: function() {
		return this.content;
	},

	show: function() {
		
		this.initialize_modal();

		this.reposition();

		new Effect.Appear(this.overlay, {duration: 0.1, from: 0.0, to: 0.5});
		this.content.style.display = 'block';
	},

	hide: function() {

		// remove the overlay		
		Event.stopObserving( document, 'keypress', this.eventHandler );
			
		this.body.removeClassName( 'ep_overlay' );
		this.body.removeClassName( 'ep_overlay_padding' );

		new Effect.Fade( this.overlay, {duration: 0.1});
		this.overlay.remove();

		// run the optional callback
		if( this.callback )
			this.callback( this );

		// remove the modal box
		if( this.content && this.content.parentNode )
		{
			this.content.hide();
			this.content.remove();
			this.content = null;
		}

		if( $( 'ep_modal_overlay_marker' ) != null )
			$( 'ep_modal_overlay_marker' ).remove();
	}
	
}); 

