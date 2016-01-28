function EPJS_ShowPreview( e, preview_id ) 
{
	var box = $(preview_id);

	box.style.display = 'block';
	box.style.zIndex = 1000;

	// Note can find triggering element using findElement
	var elt = Event.findElement( e );


//	Element.clonePosition( box, elt, { offsetLeft: (Element.getWidth( elt )) } );  //on the right
	Element.clonePosition( box, elt, { setWidth:false, offsetLeft: -(Element.getWidth( box )) }  );   //on the left
}

function EPJS_HidePreview( e, preview_id )
{
	$(preview_id).style.display = 'none';
}
