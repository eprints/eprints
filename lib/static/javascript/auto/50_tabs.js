

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

