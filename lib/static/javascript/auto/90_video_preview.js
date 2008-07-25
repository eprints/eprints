
/* Embed a flash video in element_id */
function EPJS_embed_preview_video(element_id, player_url, video_url)
{
	flashembed(element_id, player_url, {config: {
		videoFile: video_url,
		initialScale: 'orig',
		}});
}

/* Scroll-open element_id and embed the given flash video in it */
function EPJS_show_video_preview(element_id, player_url, video_url)
{
	var element_id_inner = element_id + "_inner";
	var element = $(element_id);
	var inner = $(element_id_inner);
	if( element.style.display != "block" )
	{
		element.style.height = "0px";
		element.style.display = "block";
		new Effect.Scale(element_id,
			100,
			{
				scaleX: false,
				scaleContent: false,
				scaleFrom: 0,
				duration: 0.3,
				transition: Effect.Transitions.linear,
				scaleMode: { originalHeight: inner.offsetHeight },
				afterFinish: function () {
					EPJS_embed_preview_video(element_id_inner, player_url, video_url);
				}
			} );
	}
	else
	{
		EPJS_embed_preview_video(element_id_inner, player_url, video_url);
	}
}
