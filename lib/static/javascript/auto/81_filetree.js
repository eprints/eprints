/** ep_js_init_dl_tree
 * Add click-actions to DTs that open/close the related DD.
 *
 * @param root
 * @param className
 **/
function ep_js_init_dl_tree(root, className)
{
	$(root).descendants().each(function(ele) {
		// ep_no_js won't be overridden by show()
		if( ele.nodeName == 'DD' && ele.hasClassName( 'ep_no_js' ) )
		{
			ele.hide();
			ele.removeClassName( 'ep_no_js' );
		}
		if( ele.nodeName != 'DT' ) return;
		ele.onclick = (function() {
			var dd = this.next('dd');
			if( !dd || !dd.hasChildNodes() ) return;
			if( dd.visible() ) {
				this.removeClassName( className );
				new Effect.SlideUp(dd, {
					duration: 0.2,
					afterFinish: (function () {
						this.descendants().each(function(ele) {
							if( ele.nodeName == 'DT' )
								ele.removeClassName( className );
							if( ele.nodeName == 'DD' )
								ele.hide();
						});
					}).bind(dd)
				});
			}
			else {
				this.addClassName( className );
				new Effect.SlideDown(dd, {
					duration: 0.2
				});
			}
		}).bind(ele);
	});
	/* Stop input event bubbling up to DT node and opening children at the same time */
	$(root).select('input').invoke('observe','click', function(e) {
		if (e.stopPropagation){
			e.stopPropagation();
		}else{
			e.cancelBubble = true;
		}
	});
}
