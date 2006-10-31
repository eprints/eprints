


function ep_autocompleter( element, target, url, basenames, width_of_these )
{
  new Ajax.Autocompleter( element, target, url, {
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
        if( attr[0] != 'for' ) { return; }
        if( attr[1] != 'value' ) { return; }
        var id = attr[3];
        var prefix = basenames[attr[2]];
        var field = $(prefix+id);
        if( !field ) { return; }
        field.value = li.innerHTML;
      } );
    }
  } );
}



