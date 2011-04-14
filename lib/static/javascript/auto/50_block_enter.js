function EPJS_block_enter( event )
{
	var key;

	// This handles NN4.0 which retrieves
	// the keycode differently.
	if( event && event.which )
	{
		key = event.which;
	}
	else
	{
		key = event.keyCode;
	}
	return( key != 13 );
}

Event.observe (window, 'load', function() {
	$$('.epjs_block_enter').each(function(input) {
		input.onkeypress = EPJS_block_enter;
	});
});
