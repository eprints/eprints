/** ep_js_init_dl
 * Add click-actions to DTs that open/close the related DD.
 *
 * @param root
 * @param className
 **/
function ep_js_init_dl(root, className)
{
	$(root).descendants().each(function(ele) {
		if( ele.nodeName != 'DT' ) return;
		ele.onclick = (function() {
			var dd = this.next('dd');
			if( !dd ) return;
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
}
