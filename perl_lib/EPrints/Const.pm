######################################################################
#
# EPrints::Const
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Const> - constants and enumerations

=head1 SYNOPSIS

	# don't import any constants
	use EPrints::Const qw();

	# import trigger and http constants
	use EPrints::Const qw( :trigger :http );

	# import only the OK DONE DECLINED constants
	use EPrints::Const qw( OK DONE DECLINED );

=head1 DESCRIPTION

This module contains EPrints constants and enumerations.

=head1 CONSTANTS

=head2 :namespace

=over 4

=item EP_NS_CITATION

http://eprints.org/ep3/citation

=item EP_NS_DATA

http://eprints.org/ep2/data/2.0

=item EP_NS_XSLT

http://eprints.org/ep2/xslt/1.0

=item EP_NS_OPENSEARCH

http://a9.com/-/spec/opensearch/1.1/

=back

=head2 :xml

=over 4

=item XML_ELEMENT_NODE

=item XML_ATTRIBUTE_NODE

=item XML_TEXT_NODE

=item XML_CDATA_SECTION_NODE

=item XML_ENTITY_REFERENCE_NODE

=item XML_ENTITY_NODE

=item XML_PROCESSING_INSTRUCTION_NODE

=item XML_COMMENT_NODE

=item XML_DOCUMENT_NODE

=item XML_DOCUMENT_TYPE_NODE

=item XML_DOCUMENT_FRAGMENT_NODE

=item XML_NOTATION_NODE

=back

=head2 :http

=over 4

=item DONE

=item DECLINED

=item NOT_FOUND

=item OK

=back

And all HTTP_* constants defined by L<Apache2::Const>.

=head2 :trigger

See L<EPrints::RepositoryConfig/add_trigger> and L<EPrints::RepositoryConfig/add_dataset_trigger>.

=over 4

=item EP_TRIGGER_DONE

Stop processing triggers immediately and return.

=item EP_TRIGGER_OK

Continue normal processing.

=item EP_TRIGGER_LOG

=item EP_TRIGGER_BOILERPLATE_RDF

=item EP_TRIGGER_REPOSITORY_RDF

=item EP_TRIGGER_BEGIN

=item EP_TRIGGER_BEGIN_REQUEST

Called after L<EPrints::Repository/init_from_request>.

=item EP_TRIGGER_END_REQUEST

Called just before L<EPrints::Repository/cleanup> in response to a mod_perl request.

=item EP_TRIGGER_END

=item EP_TRIGGER_URL_REWRITE

Called for every request that is within the repository's path. Use this to redirect the user to a different location. C<return_code> is a scalar reference, therefore you must deference when assigning a new value C<${$rc} = CODE>.

	request - mod_perl request object
	lang - current language id
	args - request arguments "?..."
	urlpath - EPrint's HTTP root
	cgipath - EPrints's HTTP cgi root
	uri - request uri "/eprints/12/"
	secure - whether under HTTPS
	return_code - reference to return code

=item EP_TRIGGER_DOC_URL_REWRITE

=item EP_TRIGGER_CREATED

Called after $dataset->create_dataobj( { ... } ).

	dataobj - the newly created dataobj

=item EP_TRIGGER_REMOVED

Called just before the object is removed from the database.

	dataobj - the object being removed

=item EP_TRIGGER_RDF

=item EP_TRIGGER_DEFAULTS

=item EP_TRIGGER_STATUS_CHANGE

=item EP_TRIGGER_BEFORE_COMMIT

=item EP_TRIGGER_AFTER_COMMIT

=item EP_TRIGGER_VALIDATE

=item EP_TRIGGER_VALIDATE_FIELD

Validate a field's value.

	field - field to validate
	value - value to validate
	dataobj - parent dataobj (if available)
	problems - ARRAYREF of DOM problems encountered

=item EP_TRIGGER_WARNINGS

=item EP_TRIGGER_FILES_MODIFIED

=item EP_TRIGGER_MEDIA_INFO

Populate a Document epdata structure with information about a file.

	epdata
	filename
	filepath

=item EP_TRIGGER_THUMBNAIL_TYPES

Manipulate the list of thumbnail types that will be generated for a given user-uploaded document.

	types - array reference of types (strings)
	dataobj - document object

=item EP_TRIGGER_INDEX_FIELDS

Add the changed fields for the given data object to the index engine(s).

	dataobj = EPrints::DataObj
	fields = ARRAYREF of field objects

=item EP_TRIGGER_INDEX_REMOVED

An object was removed and should now be removed from the index engine(s).

	dataset = EPrints::DataSet
	id = object id

=item EP_TRIGGER_DYNAMIC_TEMPLATE

Manipulate parts included in the template. These will be called for every page impression, so don't do anything heavyweight in here.

	pins - hash ref of template pins

=head2 :metafield

=item EP_PROPERTY_FROM_CONFIG

Get the default value from field defaults in the config.

=item EP_PROPERTY_NO_CHANGE

Don't use a default, the code may have already set this value. setting it to undef has no effect rather than setting it to default value.

=item EP_PROPERTY_REQUIRED

This field property must be explicitly set.

=item EP_PROPERTY_UNDEF

This field property defaults to undef.

=item EP_PROPERTY_TRUE

This field property defaults to true.

=item EP_PROPERTY_FALSE

This field property defaults to false.

=head2 :crypt

One-way encryption methods for passwords, see L<EPrints::Utils/crypt>.

=item EP_CRYPT_CRYPT

L<perlfunc/crypt>.

=item EP_CRYPT_SHA512

L<Digest::SHA> sha512 with 2-byte salt and 10000 rounds.

=item EP_CRYPT_BLOWFISH

L<Authen::Passphrase::BlowfishCrypt> with 16-byte salt and a cost factor of 12.

This requires the L<Authen::Passphrase::BlowfishCrypt> library.

=back

=cut

package EPrints::Const;

use Apache2::Const qw(:common :http);
use Exporter;
@ISA = qw( Exporter );

# Namespaces
use constant {
	EP_NS_XSLT => "http://eprints.org/ep2/xslt/1.0",
	EP_NS_CITATION => "http://eprints.org/ep3/citation",
	EP_NS_DATA => "http://eprints.org/ep2/data/2.0",
	EP_NS_OPENSEARCH => "http://a9.com/-/spec/opensearch/1.1/",
};

# XML Node Types
use constant {
	XML_ELEMENT_NODE => 1,
	XML_ATTRIBUTE_NODE => 2,
	XML_TEXT_NODE => 3,
	XML_CDATA_SECTION_NODE => 4,
	XML_ENTITY_REFERENCE_NODE => 5,
	XML_ENTITY_REF_NODE => 5, # synonym for XML::LibXML
	XML_ENTITY_NODE => 6,
	XML_PROCESSING_INSTRUCTION_NODE => 7,
	XML_COMMENT_NODE => 8,
	XML_DOCUMENT_NODE => 9,
	XML_DOCUMENT_TYPE_NODE => 10,
	XML_DOCUMENT_FRAGMENT_NODE => 11,
	XML_NOTATION_NODE => 12,
};

use constant {
	EP_TRIGGER_DONE => -2,
	EP_TRIGGER_OK => 0,
};

# Repository triggers
use constant {
	EP_TRIGGER_LOG => 2,
	EP_TRIGGER_BOILERPLATE_RDF => 3,
	EP_TRIGGER_REPOSITORY_RDF => 4,
	EP_TRIGGER_BEGIN => 5,
	EP_TRIGGER_BEGIN_REQUEST => 6,
	EP_TRIGGER_END_REQUEST => 7,
	EP_TRIGGER_END => 8,
	EP_TRIGGER_DOC_URL_REWRITE => 9,
	EP_TRIGGER_MEDIA_INFO => 10,
	EP_TRIGGER_INDEX_FIELDS => 11,
	EP_TRIGGER_INDEX_REMOVED => 12,
	EP_TRIGGER_URL_REWRITE => 13,
	EP_TRIGGER_VALIDATE_FIELD => 14,
	EP_TRIGGER_LOCAL_SITEMAP_URLS => 15,
	EP_TRIGGER_DYNAMIC_TEMPLATE => 16,
	EP_TRIGGER_THUMBNAIL_TYPES => 17,
};

# Dataset triggers
use constant {
	EP_TRIGGER_CREATED => 100,
	EP_TRIGGER_RDF => 101,
	EP_TRIGGER_DEFAULTS => 102,
	EP_TRIGGER_STATUS_CHANGE => 103,
	EP_TRIGGER_BEFORE_COMMIT => 104,
	EP_TRIGGER_AFTER_COMMIT => 105,
	EP_TRIGGER_VALIDATE => 106,
	EP_TRIGGER_WARNINGS => 107,
	EP_TRIGGER_FILES_MODIFIED => 108,
	EP_TRIGGER_REMOVED => 109,
};

# Field properties
use constant {
	EP_PROPERTY_FROM_CONFIG => "\0\1",
	EP_PROPERTY_NO_CHANGE => "\0\2",
	EP_PROPERTY_REQUIRED => "\0\3",
	EP_PROPERTY_UNDEF => "\0\4",

	EP_PROPERTY_TRUE => 1,
	EP_PROPERTY_FALSE => "\0\4", # don't set hash attribute
};

# Crypt methods

use constant {
	EP_CRYPT_CRYPT => 1,
	EP_CRYPT_SHA512 => 2,
	EP_CRYPT_BLOWFISH => 3,
};

@xml = qw(
	XML_ELEMENT_NODE
	XML_ATTRIBUTE_NODE
	XML_TEXT_NODE
	XML_CDATA_SECTION_NODE
	XML_ENTITY_REFERENCE_NODE
	XML_ENTITY_REF_NODE
	XML_ENTITY_NODE
	XML_PROCESSING_INSTRUCTION_NODE
	XML_COMMENT_NODE
	XML_DOCUMENT_NODE
	XML_DOCUMENT_TYPE_NODE
	XML_DOCUMENT_FRAGMENT_NODE
	XML_NOTATION_NODE
);

@namespace = qw(
	EP_NS_XSLT
	EP_NS_CITATION
	EP_NS_DATA
	EP_NS_OPENSEARCH
);

@http = qw(
	DONE
	DECLINED
	NOT_FOUND
	OK

	HTTP_ACCEPTED
	HTTP_BAD_GATEWAY
	HTTP_BAD_REQUEST
	HTTP_CONFLICT
	HTTP_CONTINUE
	HTTP_CREATED
	HTTP_EXPECTATION_FAILED
	HTTP_FAILED_DEPENDENCY
	HTTP_FORBIDDEN
	HTTP_GATEWAY_TIME_OUT
	HTTP_GONE
	HTTP_INSUFFICIENT_STORAGE
	HTTP_INTERNAL_SERVER_ERROR
	HTTP_LENGTH_REQUIRED
	HTTP_LOCKED
	HTTP_METHOD_NOT_ALLOWED
	HTTP_MOVED_PERMANENTLY
	HTTP_MOVED_TEMPORARILY
	HTTP_MULTIPLE_CHOICES
	HTTP_MULTI_STATUS
	HTTP_NON_AUTHORITATIVE
	HTTP_NOT_ACCEPTABLE
	HTTP_NOT_EXTENDED
	HTTP_NOT_FOUND
	HTTP_NOT_IMPLEMENTED
	HTTP_NOT_MODIFIED
	HTTP_NO_CONTENT
	HTTP_OK
	HTTP_PARTIAL_CONTENT
	HTTP_PAYMENT_REQUIRED
	HTTP_PRECONDITION_FAILED
	HTTP_PROCESSING
	HTTP_PROXY_AUTHENTICATION_REQUIRED
	HTTP_RANGE_NOT_SATISFIABLE
	HTTP_REQUEST_ENTITY_TOO_LARGE
	HTTP_REQUEST_TIME_OUT
	HTTP_REQUEST_URI_TOO_LARGE
	HTTP_RESET_CONTENT
	HTTP_SEE_OTHER
	HTTP_SERVICE_UNAVAILABLE
	HTTP_SWITCHING_PROTOCOLS
	HTTP_TEMPORARY_REDIRECT
	HTTP_UNAUTHORIZED
	HTTP_UNPROCESSABLE_ENTITY
	HTTP_UNSUPPORTED_MEDIA_TYPE
	HTTP_UPGRADE_REQUIRED
	HTTP_USE_PROXY
	HTTP_VARIANT_ALSO_VARIES
);

@trigger = qw(
	EP_TRIGGER_DONE
	EP_TRIGGER_OK

	EP_TRIGGER_LOG
	EP_TRIGGER_BOILERPLATE_RDF
	EP_TRIGGER_REPOSITORY_RDF
	EP_TRIGGER_BEGIN
	EP_TRIGGER_BEGIN_REQUEST
	EP_TRIGGER_END_REQUEST
	EP_TRIGGER_END
	EP_TRIGGER_URL_REWRITE
	EP_TRIGGER_DOC_URL_REWRITE
	EP_TRIGGER_MEDIA_INFO
	EP_TRIGGER_INDEX_FIELDS
	EP_TRIGGER_INDEX_REMOVED
	EP_TRIGGER_VALIDATE_FIELD
	EP_TRIGGER_LOCAL_SITEMAP_URLS
	EP_TRIGGER_DYNAMIC_TEMPLATE
	EP_TRIGGER_THUMBNAIL_TYPES

	EP_TRIGGER_CREATED
	EP_TRIGGER_RDF
	EP_TRIGGER_DEFAULTS
	EP_TRIGGER_STATUS_CHANGE
	EP_TRIGGER_BEFORE_COMMIT
	EP_TRIGGER_AFTER_COMMIT
	EP_TRIGGER_VALIDATE
	EP_TRIGGER_WARNINGS
	EP_TRIGGER_FILES_MODIFIED
	EP_TRIGGER_REMOVED
);

@metafield = qw(
	EP_PROPERTY_FROM_CONFIG
	EP_PROPERTY_NO_CHANGE
	EP_PROPERTY_REQUIRED
	EP_PROPERTY_UNDEF
	EP_PROPERTY_TRUE
	EP_PROPERTY_FALSE
);

@crypt = qw(
	EP_CRYPT_CRYPT
	EP_CRYPT_SHA512
	EP_CRYPT_BLOWFISH
);

@EXPORT_OK = (@xml, @namespace, @http, @trigger, @metafield, @crypt);
@EXPORT = ();
%EXPORT_TAGS = (
	xml => \@xml,
	namespace => \@namespace,
	http => \@http,
	trigger => \@trigger,
	metafield => \@metafield,
	crypt => \@crypt,
);

use strict;

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

