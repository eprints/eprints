/*
 *
 * Lightbox.Dialog
 *
 * Use the Lightbox overlay as a dialog box.
 *
 */

Lightbox.Dialog = Class.create(Lightbox, {
  initialize: function(params) {
    this.lightboxMovie = this.content = $('lightboxMovie');

		// Lightbox options
		this.lightbox = $('lightbox');
		this.overlay = $('overlay');
		this.resizeDuration = LightboxOptions.animate ? ((11 - LightboxOptions.resizeSpeed) * 0.15) : 0;
		this.overlayDuration = LightboxOptions.animate ? 0.2 : 0;

    $$('select', 'object', 'embed').each(function(node){ node.style.visibility = 'hidden' });

    var arrayPageSize = this.getPageSize();
    this.overlay.setStyle({
      width: arrayPageSize[0] + 'px',
      height: arrayPageSize[1] + 'px'
    });

    new Effect.Appear(this.overlay, {
      duration: this.overlayDuration,
      from: 0.0,
      to: LightboxOptions.overlayOpacity
    });

    // calculate top and left offset for the lightbox 
    var arrayPageScroll = document.viewport.getScrollOffsets();
    var lightboxTop = arrayPageScroll[1] + (document.viewport.getHeight() / 10);
    var lightboxLeft = arrayPageScroll[0];
    $('lightboxImage').hide();
    this.content.hide();
    $('hoverNav').hide();
    $('prevLink').hide();
    $('nextLink').hide();
    $('imageDataContainer').setStyle({opacity: .0001});
		this.lightbox.setStyle({
      top: lightboxTop + 'px',
      left: lightboxLeft + 'px' }
    ).show();

    if (params.onShow) {
      params.onShow (this);
    }
  },

	resizeImageContainer: function(imgWidth, imgHeight) {
    // get new width and height
    var widthNew  = (imgWidth  + LightboxOptions.borderSize * 2);
    var heightNew = (imgHeight + LightboxOptions.borderSize * 2);

		var outerImageContainer = $('outerImageContainer');

    outerImageContainer.setStyle({ width: widthNew + 'px' });
    outerImageContainer.setStyle({ height: heightNew + 'px' });
	},

  /*
   * update
   * @param content
   *
   * Update the dialog box's content with @content.
   *
   * If @content is empty string, replaces the content with a busy-loading
   * image.
   */
  update: function(content) {
    this.content.update (content);

    if (content != '') {
      var boxWidth = this.content.getWidth();
      if( boxWidth == null || boxWidth < 640 )
        boxWidth = 640;

      this.resizeImageContainer ( boxWidth, this.content.getHeight());

      $('loading').hide();
      this.content.show ();
    }
    else {
      this.content.hide();
      $('loading').show();
    }
  }

});
