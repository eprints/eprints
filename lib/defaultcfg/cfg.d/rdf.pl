

use Digest::MD5 qw(md5 md5_hex md5_base64);

$c->{rdf}->{xmlns}->{dc}   = 'http://purl.org/dc/elements/1.1/';
$c->{rdf}->{xmlns}->{dct}  = 'http://purl.org/dc/terms/';
$c->{rdf}->{xmlns}->{foaf} = 'http://xmlns.com/foaf/0.1/';
$c->{rdf}->{xmlns}->{owl}  = 'http://www.w3.org/2002/07/owl#';
$c->{rdf}->{xmlns}->{rdf}  = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
$c->{rdf}->{xmlns}->{rdfs} = 'http://www.w3.org/2000/01/rdf-schema#';
$c->{rdf}->{xmlns}->{xsd}  = 'http://www.w3.org/2001/XMLSchema#';
$c->{rdf}->{xmlns}->{bibo} = 'http://purl.org/ontology/bibo/';

$c->{rdf}->{xmlns}->{epx} = $c->{base_url}."/id/x-";
$c->{rdf}->{xmlns}->{epid} = $c->{base_url}."/id/";

