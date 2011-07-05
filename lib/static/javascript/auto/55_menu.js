// EPJS_Menus - inspired from http://javascript-array.com/scripts/simple_drop_down_menu/
// 
// To create a menu, simply add the attribute "menu = 'some_id'" to the anchor that will trigger the menu, and create a div:
//	<div id="some_id" style="display:none;">
//                <a>Some links</a> etc...
//	</div>

var EPJS_Menus = Class.create({

  anchors: null,
  anchor_timer_id: null,
  timer_id: null,
  current_menu: null,
  default_timeout: 0.1,

  initialize: function(params) {
		
	this.anchors = new Hash();

	$$( 'a[menu]' ).each( function(el) {

		var menu_id = el.getAttribute( 'menu' );
		if( menu_id == null )
			return false;

		var menu = $( menu_id );
		if( menu == null )
			return false;
		
		menu.hide();

		var anchor_id = el.getAttribute( 'id' );
		if( anchor_id == null || anchor_id == "" )
		{
			anchor_id = 'anchor_' + Math.floor(Math.random()*12345);
			el.id =  anchor_id;
		}
		
		// store a mapping menu_id => anchor_id (anchor_id is the id of the element being hover-ed)
		this.anchors.set( menu_id, anchor_id );

		// Event handlers
		Event.observe( el, 'mouseover', this.open.bindAsEventListener( this, menu_id ) );
		Event.observe( el, 'mouseout', this.close_timeout.bindAsEventListener( this, menu_id ) );

		Event.observe( menu, 'mouseover', this.cancel_timeout.bindAsEventListener( this, menu_id ) );
		Event.observe( menu, 'mouseout', this.close_timeout.bindAsEventListener( this, menu_id ) );

	}.bind(this));

	Event.observe( document, 'click', this.close.bindAsEventListener(this) );
  },

  open: function(event) {

	Event.stop(event);	// needed?
	
	var args = arguments;
	var menu_id = args[1];

	// cancel close timer
	this.cancel_timeout();

	// close current menu
	if( this.current_menu != null )
	{
		this.current_menu.hide();
		$( this.anchors.get( this.current_menu.id ) ).removeClassName( 'ep_tm_menu_selected' );
	}

	// show newly selected menu
	this.current_menu = $( menu_id );
	this.current_menu.style.zIndex = 1;
	this.current_menu.show();

	$( this.anchors.get( menu_id ) ).addClassName( 'ep_tm_menu_selected' );
  },

  close: function(event) {
	
	if( this.current_menu != null )
	{
		this.current_menu.hide();
		$( this.anchors.get( this.current_menu.id ) ).removeClassName( 'ep_tm_menu_selected' );
	}

	return false;
  },

  close_timeout: function(event) {

	this.timer_id = Element.hide.delay(this.default_timeout, this.current_menu.id);
	this.anchor_timer_id = Element.removeClassName.delay( this.default_timeout, this.anchors.get( this.current_menu.id ), 'ep_tm_menu_selected' );
  },
  cancel_timeout: function(event) {

	if(this.timer_id)
	{
		window.clearTimeout(this.timer_id);
		this.timer_id = null;
	}
	if(this.anchor_timer_id)
	{
		window.clearTimeout(this.anchor_timer_id);
		this.anchor_timer_id = null;
	}
  }

});

var EPJS_menu_template;
document.observe("dom:loaded",function(){
	EPJS_menu_template = new EPJS_Menus();
});


