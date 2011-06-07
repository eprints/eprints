

window.ep_showTab = function( baseid, tabid, expensive )
{
	panels = $(baseid + "_panels");
	for( i=0; i < panels.childNodes.length; ++i)
		Element.hide( panels.childNodes[i] );

	tabs = $(baseid + "_tabs");
	for( i=0; i<tabs.childNodes.length; i++ )
	{
		child = tabs.childNodes[i];
		if( child.className == "ep_tab_selected" )
			child.className = "ep_tab";
	}

	panel = $(baseid+"_panel_"+tabid);

	panel.style.display = "block";

	tab = $(baseid+"_tab_"+tabid);
	tab.className = "ep_tab_selected";
	anchors = tab.getElementsByTagName('a');
	for( i=0; i<anchors.length; i++ )
	{
		anchors[i].blur();
	}

	if(expensive && !panel.loaded)
	{
		var link = tab.down('a');
		link = link.href.split('?');
		new Ajax.Updater(panel, link[0], {
			onComplete: function() {
				panel.loaded = 1;
			},
			method: "get",
			parameters: 'ajax=1&' + link[1]
		});
	}

//	window.location.hash = baseid + '_current_' + tabid;

	return false;
};

