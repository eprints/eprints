
function EPJS_toggle( element_id, start_visible, display )
{
	element = document.getElementById( element_id );

	current_vis = false;
	if( start_visible )
	{
		current_vis = (element.style.display != "none" );
	}
	else
	{
		current_vis = (element.style.display == display );
	}

	if( current_vis )
	{
		element.style.display = "none";
	}
	else
	{
		element.style.display = display;
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

