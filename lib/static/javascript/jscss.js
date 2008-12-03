/*
 * IE compatibility based on a information given here:
 * http://www.mapbender.org/index.php/Add_styles_via_DOM_in_IE_and_FF
 *
 */

var css = {
	".ep_no_js" : "display: none",
	".ep_no_js_inline" : "display: none",
	".ep_no_js_table_cell" : "display: none",
	".ep_only_js" : "display: block",
	".ep_only_js_inline" : "display: inline",
	".ep_only_js_table_cell" : "display: table-cell"
};

if( document.createStyleSheet )
{
	// Internet Explorer
	var styleSheetObj = document.createStyleSheet();
	var styleObj = styleSheetObj.owningElement || styleSheetObj.ownerNode;
	styleObj.setAttribute( "type", "text/css" );
	for (tag in css)
	{
		styleSheetObj.addRule(tag,css[tag]);
	}
}
else
{
	// Firefox
	var styleObj = document.createElement("style");
	styleObj.setAttribute( "type", "text/css" );

	document.getElementsByTagName("head")[0].appendChild( styleObj );

	var css_string = "";
	for (tag in css)
	{
		css_string += tag + " { " + css[tag] + "}\n";
	}
	styleObj.appendChild(document.createTextNode( css_string ));
}
