
/* sneaky little thing which forces the scroll bar to always appear, solving javascript 
   jitters.
*/

window.document.write( '<style>body { height: '+(window.innerHeight+1)+'px; }</style>' );
