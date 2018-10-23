
function EPJS_toggleSlide( element_id, start_visible )
{
	return EPJS_toggleSlide_aux( element_id, start_visible, null );
}
function EPJS_toggleSlideScroll( element_id, start_visible, scroll_id )
{
	return EPJS_toggleSlide_aux( element_id, start_visible, scroll_id );
}
function EPJS_toggleSlide_aux( element_id, start_visible, scroll_id )
{
	var element = $(element_id);
	var current_vis = start_visible;

	if( element.style.display == "none" )
	{
		current_vis = false;
	}
	if( element.style.display == "block" )
	{
		current_vis = true;
	}


	element.style.overflow = 'hidden';
	if( current_vis )
	{
		var inner = $(element_id+"_inner");
  		new Effect.Scale(element_id,
			0,
    			{
				scaleX: false,
				scaleContent: false,
				scaleFrom: 100,
				duration: 0.3,
				transition: Effect.Transitions.linear,
				afterFinish: function () { $(element_id).style.display = "none"; },
				scaleMode: { originalHeight: inner.offsetHeight, originalWidth: inner.offsetWidth }
			} );
	}
	else
	{
		var inner = $(element_id+"_inner");
		w = inner.offsetWidth;
		var outer = $(element_id+"_outer");
		if( outer )
		{
			w = outer.getWidth();
			outer.style.width = w+'px';
		}
		element.style.height = "0px";
		element.style.display = "block";

  		new Effect.Scale(element_id,
			100,
    			{
				scaleX: false,
				scaleContent: false,
				scaleFrom: 0,
				duration: 0.3,
				transition: Effect.Transitions.linear,
				scaleMode: { originalHeight: inner.offsetHeight },
				afterFinish: function () {
					$(element_id).style.overflow = "visible";
					$(element_id).style.height = "";
				}
			} );
		if( scroll_id != null )
		{
//			new Effect.ScrollTo(scroll_id);
		}
	}
}

function EPJS_toggle( element_id, start_visible )
{
	EPJS_toggle_type( element_id, start_visible, 'block' );
}

function EPJS_toggle_type( element_id, start_visible, display_type )
{
	var element = $(element_id);

	var current_vis = start_visible;

	if( element.style.display == "none" )
	{
		current_vis = false;
	}
	if( element.style.display == display_type )
	{
		current_vis = true;
	}

	if( current_vis )
	{
		element.style.display = "none";
	}
	else
	{
		element.style.display = display_type;
	}

}
