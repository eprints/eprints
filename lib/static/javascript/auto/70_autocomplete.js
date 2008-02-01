

Ajax.Autocompleter.prototype.onKeyPress = function(event) {
	if(this.active)
		switch(event.keyCode) {
/*			case Event.KEY_TAB: */
			case Event.KEY_RETURN:
				this.selectEntry();
				Event.stop(event);
			case Event.KEY_ESC:
				this.hide();
				this.active = false;
				Event.stop(event);
				return;
			case Event.KEY_LEFT:
			case Event.KEY_RIGHT:
				return;
			case Event.KEY_UP:
				this.markPrevious();
				this.render();
				if(navigator.appVersion.indexOf('AppleWebKit')>0) Event.stop(event);
				return;
			case Event.KEY_DOWN:
				this.markNext();
				this.render();
				if(navigator.appVersion.indexOf('AppleWebKit')>0) Event.stop(event);
				return;
		}
	else
		if(event.keyCode==Event.KEY_TAB || event.keyCode==Event.KEY_RETURN)
			return;

	this.changed = true;
	this.hasFocus = true;
	this.options.change(this.element, this.options.container);
	if(this.observer) clearTimeout(this.observer);
	this.observer =
		setTimeout(this.onObserverEvent.bind(this), this.options.frequency*1000);

};

function ep_autocompleter( element, target, url, basenames, width_of_these, fields_to_send, extra_params )
{
  new Ajax.Autocompleter( element, target, url, {
    callback: function( el, entry ) { 
      var params = fields_to_send.inject( entry, function( acc, rel_id, index ) { 
        return acc + '&' + rel_id + '=' + $F(basenames.relative + rel_id); } );
      return params + extra_params;
    },
    paramName: 'q',
    onShow: function(element, update){
      var w = width_of_these.inject( 0, function( acc, cell, index ) { 
        return acc + Element.getDimensions(cell).width; } );
      update.style.position = 'absolute';
      Position.clone(element, update, {
        setWidth: false, 
        setHeight: false, 
        setLeft: false, 
        offsetTop: element.offsetHeight });
      update.style.width  = w + 'px';
      Effect.Appear(update,{duration:0.15});
    },
    updateElement: function( selected ) {
      var ul = $A(selected.getElementsByTagName( 'ul' )).first();
      var lis = $A(ul.getElementsByTagName( 'li' ));
      lis.each( function(li) { 
        var myid = li.getAttribute( 'id' );
        var attr = myid.split( /:/ );
        if( attr[0] != 'for' ) { alert( "Autocomplete id reference did not start with 'for': "+myid); return; }
        if( attr[1] != 'value' &&  attr[1] != 'block' ) { alert( "Autocomplete id reference did not contain 'block' or 'value': "+myid); return; }
        var id = attr[3];
	if( id == null ) { id = ''; }
        var prefix = basenames[attr[2]];
	if( prefix == null ) { prefix = ''; }
        var target = $(prefix+id);
        if( !target ) { return; }
	if( attr[1] == 'value' )
	{
		var newvalue = li.innerHTML;
		rExp = /&gt;/gi;
		newvalue = newvalue.replace(rExp, ">" );
		rExp = /&lt;/gi;
		newvalue = newvalue.replace(rExp, "<" );
		rExp = /&amp;/gi;
		newvalue = newvalue.replace(rExp, "&" );
        	target.value = newvalue;
	}
	else if( attr[1] == 'block' )
	{
		while( target.hasChildNodes() )
		{
			target.removeChild( target.firstChild );
		}
		while( li.hasChildNodes() )
		{
			target.appendChild( li.removeChild( li.firstChild ) );
		}
	}
	else
	{
		alert( "1st part of autocomplete id ref was: "+attr[1] );
	}

      } );
    }
  } );
}



