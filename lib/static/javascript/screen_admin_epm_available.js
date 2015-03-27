Event.observe(window, 'load', function() {
	new PeriodicalExecuter(js_admin_epm_available_update, 2);
});
function js_admin_epm_available_update(pe)
{
	var screenid = 'Admin::EPM::Available';

	var input_q = $(screenid + '_q');
	var input_v = $(screenid + '_v');

	if( !input_q || !input_v)
		return;

	if( !input_q._pvalue )
		input_q._pvalue = '';

	if( !input_v._pvalue )
		input_v._pvalue = '';

	var input_v_value = input_v.options[input_v.selectedIndex].value; 

	if( input_q.value == input_q._pvalue &&
	    input_v_value == input_v._pvalue )
		return;

	if( input_q._inprogress )
		return;

	if( input_v._inprogress )
		return;
	
	input_q._inprogress = 1;
	input_v._inprogress = 1;
	var container = $(screenid + '_results');
	var loading = $('loading').cloneNode( 1 );

	container.insertBefore( loading, container.firstChild );
	loading.style.position = 'absolute';
	loading.clonePosition( container );
	loading.show();

	var qvalue = input_q.value;
	var vvalue = input_v_value;
	var params = {};
	params['screen'] = screenid;
	params['ajax'] = 1;
	params[screenid + '_q'] = qvalue;
	params[screenid + '_v'] = vvalue;
	new Ajax.Updater(container, eprints_http_cgiroot+'/users/home', {
		method: 'get',
		parameters: params,
		onComplete: function () {
			input_q._pvalue = qvalue;
			input_v._pvalue = vvalue;
			input_q._inprogress = 0;
			input_v._inprogress = 0;
		}
	});
}
