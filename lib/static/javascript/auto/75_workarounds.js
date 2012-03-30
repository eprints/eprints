/* Fix file.slice() */
if (!Blob.prototype.slice)
	if (Blob.prototype.webkitSlice)
		Blob.prototype.slice = Blob.prototype.webkitSlice;
	else if (Blob.prototype.mozSlice)
		Blob.prototype.slice = function(start, end, contentType) { return this.mozSlice (start, end, contentType); };

// Fix for Opera
Ajax.Autocompleter.prototype.getEntry = function(index) {
    return this.update.down().childNodes[index];
  };

// Don't autocomplete on tab
Ajax.Autocompleter.prototype.onKeyPress = function(event) {
    if(this.active)
      switch(event.keyCode) {
/*       case Event.KEY_TAB: */
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
         Event.stop(event);
         return;
       case Event.KEY_DOWN:
         this.markNext();
         this.render();
         Event.stop(event);
         return;
      }
     else 
       if(event.keyCode==Event.KEY_TAB || event.keyCode==Event.KEY_RETURN || 
         (Prototype.Browser.WebKit > 0 && event.keyCode == 0)) return;

    this.changed = true;
    this.hasFocus = true;

    if(this.observer) clearTimeout(this.observer);
      this.observer = 
        setTimeout(this.onObserverEvent.bind(this), this.options.frequency*1000);
  };

/*
 * Block drag-and-drop onto the page, because we don't want to lose the page if
 * the user misses a hot-box
 */
Event.observe (window, 'load', function() {
	var body = document.getElementsByTagName ('body').item (0);
	Event.observe (body, 'dragenter', function(evt) { Event.stop (evt); });
	Event.observe (body, 'dragexit', function(evt) { Event.stop (evt); });
	Event.observe (body, 'dragover', function(evt) { Event.stop (evt); });
	Event.observe (body, 'drop', function(evt) { Event.stop (evt); });
});
