
function EPJS_toggleSlide( element_id, start_visible )
{
	return EPJS_toggleSlide_aux( element_id, start_visible, false );
}
function EPJS_toggleSlideScroll( element_id, start_visible )
{
	return EPJS_toggleSlide_aux( element_id, start_visible, true );
}
function EPJS_toggleSlide_aux( element_id, start_visible, scroll )
{
	element = $(element_id);
	current_vis = start_visible;

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
		inner = $(element_id+"_inner");
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
        	element.style.height = "0px";
		element.style.display = "block";
		inner = $(element_id+"_inner");

  		new Effect.Scale(element_id,
			100,
    			{ 
				scaleX: false,
				scaleContent: false,
				scaleFrom: 0,
				duration: 0.3,
				transition: Effect.Transitions.linear,
				scaleMode: { originalHeight: inner.offsetHeight, originalWidth: inner.offsetWidth },
				afterFinish: function () { 
					$(element_id).style.overflow = "visible"; 
					$(element_id).style.height = ""; 
				}
			} ); 
		if( scroll )	
		{
			new Effect.ScrollTo(element_id, {offset: inner.offsetHeight});
		}
	}
}

function EPJS_blur( event )
{
	if( event )
	{
		if( event.target )
		{
			if( event.target.blur )
			{
				event.target.blur();
			}
		}
	}
}

function EPJS_toggle( element_id, start_visible )
{
	EPJS_toggle_type( element_id, start_visible, 'block' );
}

function EPJS_toggle_type( element_id, start_visible, display_type )
{
	element = $(element_id);

	current_vis = start_visible;

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



window.ep_showTab = function( baseid, tabid )
{

	panels = document.getElementById( baseid+"_panels" );
	for( i=0; i<panels.childNodes.length; i++ )
	{
		child = panels.childNodes[i];
		if( child.style ) { child.style.display = "none"; }
	}

	tabs = document.getElementById( baseid+"_tabs" );
	for( i=0; i<tabs.childNodes.length; i++ )
	{
		child = tabs.childNodes[i];
		if( child.className == "ep_tab_selected" )
		{
			child.className = "ep_tab";
		}
	}

	panel = document.getElementById( baseid+"_panel_"+tabid );

	panel.style.display = "block";

	tab = document.getElementById( baseid+"_tab_"+tabid );
	tab.style.font_size = "30px";
	tab.className = "ep_tab_selected";
	anchors = tab.getElementsByTagName('a');
	for( i=0; i<anchors.length; i++ )
	{
		anchors[i].blur();
	}

	return false;
};

