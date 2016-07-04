
function ep_autocompleter( element, target, url, basenames, width_of_these, fields_to_send, extra_params )
{
  new Ajax.Autocompleter( element, target, url, {
    indicator: target+'_loading',
    callback: function( el, entry ) { 

      var w = width_of_these.inject( 0, function( acc, cell, index ) { 
        return acc + Element.getDimensions(cell).width; } );
      $(target).style.position = 'absolute';
	  element = $(element);
      Element.clonePosition(element, $(target), {
        setWidth: false, 
        setHeight: false, 
        setLeft: false, 
        offsetTop: element.offsetHeight });
      $(target).style.width  = w + 'px';
      $(target+"_loading").style.width  = w + 'px';

      var params = fields_to_send.inject( entry, function( acc, rel_id, index ) { 
        return acc + '&' + rel_id + '=' + $F(basenames.relative + rel_id); } );
      return params + extra_params;
    },
    paramName: 'q',
    onShow: function(element, update){
      Effect.Appear(update,{duration:0.15});
    },
    updateElement: function( selected ) {
      var ul = $A(selected.getElementsByTagName( 'ul' )).first();
      var lis = $A(ul.getElementsByTagName( 'li' ));
      lis.each( function(li) { 
        var myid = li.getAttribute( 'id' );
        if( myid == null || myid == '' ) { return; } 
        var attr = myid.split( /:/ );
        if( attr[0] != 'for' ) { console.log( "Autocomplete id reference did not start with 'for': "+myid); return; }
        var id = attr[3];
        if( id == null ) { id = ''; }
        var prefix = basenames[attr[2]];
        if( prefix == null ) { prefix = ''; }
        var target = $(prefix+id);
        if( attr[2] == 'row' )
        {
          var parts = basenames['relative'].match( /^(.*_)([0-9]+)$/ );
          var target_id = parts[1]+"cell_"+id+"_"+( parts[2]*2-2 );
          target = $(target_id);
        }
        if( !target ) { return; }

        if( attr[1] == 'hide' )
        {
          target.style.display = 'none';
        }
        else if( attr[1] == 'show' )
        {
          target.style.display = 'block';
        }
        else if( attr[1] == 'value' )
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
          console.log( "1st part of autocomplete id ref was: "+attr[1] );
        }

      } );
    }
  } );
}



