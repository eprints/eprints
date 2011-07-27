Event.observe(window, 'load', function() {
	new PeriodicalExecuter(js_admin_epm_available_update, 2);
});
function js_admin_epm_available_update(pe)
{
	var screenid = 'Admin::EPM::Available';

	var input = $(screenid + '_q');
	if( !input )
		return;

	if( !input._pvalue )
		input._pvalue = '';

	if( input.value == input._pvalue )
		return;

	if( input._inprogress )
		return;
	
	input._inprogress = 1;

	var container = $(screenid + '_results');
	var loading = $('loading').cloneNode( 1 );

	container.insertBefore( loading, container.firstChild );
	loading.style.position = 'absolute';
	loading.clonePosition( container );
	loading.show();

	var qvalue = input.value;
	var params = {};
	params['screen'] = screenid;
	params['ajax'] = 1;
	params[screenid + '_q'] = qvalue;
	new Ajax.Updater(container, eprints_http_cgiroot+'/users/home', {
		method: 'get',
		parameters: params,
		onComplete: function () {
			input._pvalue = qvalue;
			input._inprogress = 0;
		}
	});
}
