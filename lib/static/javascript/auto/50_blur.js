
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
