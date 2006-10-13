
function EPJS_toggleSlide( element_id, start_visible )
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
/*
    		var x = element.x ? element.x : element.offsetLeft,
        		y = element.y ? element.y : element.offsetTop;
		window.scrollTo( x, y + inner.offsetHeight+50 );
*/
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
	}
}

function EPJS_toggle( element_id, start_visible )
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
	
	if( current_vis )
	{
		element.style.display = "none";
	}
	else
	{
		element.style.display = "block";
	}
}


function ep_gt( a, b ) { return a>b; }


function ep_lt( a, b ) { return a<b; }


window.ep_showTab = function( baseid, tabid )
{

	panels = document.getElementById( baseid+"_panels" );
	for( i=0; ep_lt(i,panels.childNodes.length); i++ )
	{
		child = panels.childNodes[i];
		child.style.display = "none";
	}

	tabs = document.getElementById( baseid+"_tabs" );
	for( i=0; ep_lt(i,tabs.childNodes.length); i++ )
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
	for( i=0; ep_lt(i,anchors.length); i++ )
	{
		anchors[i].blur();
	}

/*
	if( tabid == "history" )
	{
		return true;
	}
*/

	return false;
};

