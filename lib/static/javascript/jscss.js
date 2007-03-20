
var styletag = document.createElement( "style" );
var head = document.getElementsByTagName("head")[0]
var css = "";
css += ".ep_no_js { display: none; }\n";
css += ".ep_no_js_inline { display: none; }\n";
css += ".ep_only_js { display: block; }\n";
css += ".ep_only_js_inline { display: none; }\n";
styletag.innerHTML = css;
head.appendChild( styletag );
