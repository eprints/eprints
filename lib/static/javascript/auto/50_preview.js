
function EPJS_ShowPreview( e, preview_id ) 
{
	var box_w = 410;
	var box_h = 330;

 	var y = (document.documentElement.scrollTop || document.body.scrollTop);
	var screen_h = window.innerHeight ? window.innerHeight : 
			 (document.documentElement.clientHeight ? document.documentElement.clientHeight : document.body.clientHeight);
 	var x = (document.documentElement.scrollLeft || document.body.scrollLeft);
	var screen_w = window.innerWidth ? window.innerWidth : 
			 (document.documentElement.clientWidth ? document.documentElement.clientWidth : document.body.clientWidth);

	var box = $(preview_id);

	box.style.display = 'block';
	box.style.top = y+(screen_h/2)-(box_h/2)+"px";
	var midscreen = x+(screen_w/2);
	var x_cent;
	var x_pointer = Event.pointerX(e);
	if( x_pointer < midscreen )
	{
		box.style.left = midscreen +screen_w/4 - box_w/2+"px";
	}
	else
	{
		box.style.left = midscreen -screen_w/4 - box_w/2+"px";
	}
}

function EPJS_HidePreview( e, preview_id )
{
	$(preview_id).style.display = 'none';
}
	
