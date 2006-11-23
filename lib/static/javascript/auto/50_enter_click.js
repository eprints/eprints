function EPJS_enter_click( event, buttonid )
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

	if( key == 13 )
	{
		$(buttonid).click();
	}
	return( key != 13 );
}
