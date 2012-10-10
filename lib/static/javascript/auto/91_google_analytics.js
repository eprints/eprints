
/* To enable Google analytics tracking of HTML page views and clicks on links 
 * to PDFs etc. create a new javascript file
 * eg. archives/ARCHIVEID/cfg/static/javascript/auto/ga_tracker_code.js
 * with the following content:
 *
 * var ga_tracker_code = 'UA-XXXXXXX-X';
 *
 * OR insert the following into your repository template(s):
 *
 * <script type="text/javascript">var ga_tracker_code = 'UA-XXXXXXX-X';</script>
 *
 *--------------------------------------------------------------------------*/

document.observe("dom:loaded",function(){
	if( typeof ga_tracker_code != "undefined" )
	{
		var _gaq = _gaq || [];
		_gaq.push(['_setAccount', ga_tracker_code]);
		_gaq.push(['_trackPageview']);

		var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
		ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
		var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);

		$$('a.ep_document_link').each( function(el){
			el.observe('click', function(event){
				_gaq.push(['_trackPageview', el.pathname]);
				return true;
			});
		});
	}
});
