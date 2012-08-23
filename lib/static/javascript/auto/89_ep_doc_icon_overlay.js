/*
	Adds an overlay (a pad-lock) on top of restricted documents' icons
*/

document.observe('dom:loaded', function () { 

	var imgs = $$( 'img.ep_doc_icon_validuser', 'img.ep_doc_icon_staffonly' ).each( function(el) {

		var pNode = el.up();
		if( pNode == null )
			return;

		var elCopy = el.remove();

		// create a container at the same position of the <img> we just removed:
		var container = new Element( 'div', { 'class': 'div.ep_doc_overlay_container' } );
		pNode.insert( container, { 'position': 'end' } );


		container.insert( elCopy, { 'position': 'end' } );
		container.insert( new Element( 'div', { 'style': 'clear:both' } ), { 'position': 'end' } );
	
		// this will position the overlay at a position that doesn't require us to use the broken getHeight() / getWidth() methods	
		var overlay = new Element( 'div', { 'class': 'ep_doc_restricted' } );
		container.insert( overlay, { 'position': 'end' } );

		// a little fine-tuning
		overlay.setStyle( { left: '3px', top: '-20px' } );
		return;

	});
});

