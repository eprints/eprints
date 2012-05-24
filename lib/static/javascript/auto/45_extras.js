/* serialise a form excluding all 'submit', 'image' and 'button' values */
function serialize_form(form) {
	var inputs = form.select ('input[type="image"]', 'input[type="button"]');
	inputs.invoke ('disable');

	var params = form.serialize({
		hash: true,
		submit: false
	});

	inputs.invoke ('enable');

	return params;
}

// http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript
function generate_uuid()
{
	var s = [];
	var hexDigits = "0123456789ABCDEF";
	for(var i = 0; i < 32; i++)
		s[i] = hexDigits.substr(Math.floor(Math.random() * 0x10), 1);
	s[12] = "4";
	s[16] = hexDigits.substr((s[16] & 0x3) | 0x8, 1);

	return s.join("");
}

Element.addMethods({
        attributesHash: function(element) {
                var attr = element.attributes;
                var h = {};
		// list of attributes that we want to be copied over to the hash
                var whitelist = { 'name': true, 'id':true, 'style':true, 'value':true };

                for (var i = 0; i < attr.length; ++i)
                {
                        var name = attr[i].name;
                        if( Prototype.Browser.IE && !attr[i].specified && !whitelist[attr[i].name])
                                continue;
                        h[name] = element.readAttribute (name);
                }

                return h;
        }
});

/*
 * Format @size as a friendly human-readable size
 */
function human_filesize(size_in_bytes)
{
	if( size_in_bytes < 4096 )
		return size_in_bytes + 'b';

	var size_in_k = Math.floor( size_in_bytes / 1024 );

	if( size_in_k < 4096 )
		return size_in_k + 'Kb';

	var size_in_meg = Math.floor( size_in_k / 1024 );

	if (size_in_meg < 4096)
		return size_in_meg + 'Mb';

	var size_in_gig = Math.floor( size_in_meg / 1024 );

	if (size_in_gig < 4096)
		return size_in_gig + 'Gb';

	var size_in_tb = Math.floor( size_in_gig / 1024 );

	return size_in_tb + 'Tb';
}

