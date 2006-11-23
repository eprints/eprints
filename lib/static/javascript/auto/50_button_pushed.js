
var epjs_button_code = {};

function EPJS_register_button_code( buttonid, coderef )
{
	if( epjs_button_code[buttonid] == null )
	{
		epjs_button_code[buttonid] = new Array;
	}

	epjs_button_code[buttonid].push( coderef );	
}

function EPJS_button_pushed( buttonid )
{
	if( epjs_button_code[buttonid] == null )
	{
		return true;
	}

	var ok = true;
	epjs_button_code[buttonid].each( 
		function( coderef ) {
			ok = ok && coderef();
		} );
	return ok;
}

/*
EPJS_register_button_code( "_action_next", function() { alert( "test1" ); return true; } );
EPJS_register_button_code( "_action_next", function() { return confirm( "check" ); } );
*/
