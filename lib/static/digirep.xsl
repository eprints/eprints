<?xml version="1.0" encoding="utf-8"?>

<!--

  XSL Transform to convert this protocol thing responses into XHTML

  By Christopher Gutteridge, University of Southampton

  v1.0

  for protocol version v0.1

-->

<!-- 
  
Copyright (c) 2006 University of Southampton, UK. SO17 1BJ.

EPrints 3 is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

EPrints 3 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with EPrints 3; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

-->

   
<!--
  
  All the elements really needed for EPrints are done but if
  you want to use this XSL for other OAI archive you may want
  to make some minor changes or additions.

  Not Done
    The 'about' section of 'record'
    The 'compession' part of 'identify'
    The optional attributes of 'resumptionToken'
    The optional 'setDescription' container of 'set'

  All the links just link to oai_dc versions of records.

-->
<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:oai="http://www.openarchives.org/OAI/2.0/"
>

<xsl:output method="html"/>



<xsl:template name="style">
/* style */
<xsl:call-template name='xmlstyle' />
</xsl:template>

<xsl:template match="/">
<html>
  <head>
    <title>WarwickAPI HTTP Request Results</title>
    <style><xsl:call-template name="style"/></style>
  </head>
  <body>
    <h1>WarwickAPI HTTP Request Results</h1>
    <xsl:call-template name="quicklinks"/>
    <p class="intro">You are viewing an HTML rendering of an XML document.</p>
    <xsl:apply-templates select="/response" />
    <xsl:call-template name="quicklinks"/>
    <h2><a name="moreinfo">About the XSLT</a></h2>
    <p>An XSLT file has converted the response into XHTML which looks nice in a browser which supports XSLT such as Mozilla, Firebird and Internet Explorer. The XSLT file was created by <a href="http://www.ecs.soton.ac.uk/people/cjg">Christopher Gutteridge</a> at the University of Southampton as part of the <a href="http://www.eprints.org/software/">GNU EPrints system</a>, and is freely redistributable under the <a href="http://www.gnu.org">GPL</a>.</p><p>If you want to use the XSL file on your own OAI interface you may but due to the way XSLT works you must install the XSL file on the same server as the OAI script, you can't just link to this copy.</p>

  </body>
</html>
</xsl:template>

<xsl:template name="quicklinks">
    <ul class="quicklinks">
      <li><a href="?verb=Identify">Identify</a> | </li> 
      <li><a href="?verb=ListRecords&amp;metadataPrefix=oai_dc">ListRecords</a> | </li>
      <li><a href="?verb=ListSets">ListSets</a> | </li>
      <li><a href="?verb=ListMetadataFormats">ListMetadataFormats</a> | </li>
      <li><a href="?verb=ListIdentifiers&amp;metadataPrefix=oai_dc">ListIdentifiers</a></li>
    </ul>
</xsl:template>

<xsl:template match="/response">
  
  <div class="xmlSource">
    <xsl:apply-templates select="." mode='xmlMarkup' />
  </div>
</xsl:template>




<!--
   Identify / Unsupported Description
-->

<xsl:template match="oai:description/*" priority="-100">
  <h2>Unsupported Description Type</h2>
  <p>The XSL currently does not support this type of description.</p>
  <div class="xmlSource">
    <xsl:apply-templates select="." mode='xmlMarkup' />
  </div>
</xsl:template>


<!--
   Identify / OAI-Identifier
-->

<xsl:template match="id:oai-identifier" xmlns:id="http://www.openarchives.org/OAI/2.0/oai-identifier">
  <h2>OAI-Identifier</h2>
  <table class="values">
    <tr><td class="key">Scheme</td>
    <td class="value"><xsl:value-of select="id:scheme"/></td></tr>
    <tr><td class="key">Repository Identifier</td>
    <td class="value"><xsl:value-of select="id:repositoryIdentifier"/></td></tr>
    <tr><td class="key">Delimiter</td>
    <td class="value"><xsl:value-of select="id:delimiter"/></td></tr>
    <tr><td class="key">Sample OAI Identifier</td>
    <td class="value"><xsl:value-of select="id:sampleIdentifier"/></td></tr>
  </table>
</xsl:template>


<!--
   Identify / EPrints
-->

<xsl:template match="ep:eprints" xmlns:ep="http://www.openarchives.org/OAI/1.1/eprints">
  <h2>EPrints Description</h2>
  <xsl:if test="ep:content">
    <h3>Content</h3>
    <xsl:apply-templates select="ep:content"/>
  </xsl:if>
  <xsl:if test="ep:submissionPolicy">
    <h3>Submission Policy</h3>
    <xsl:apply-templates select="ep:submissionPolicy"/>
  </xsl:if>
  <h3>Metadata Policy</h3>
  <xsl:apply-templates select="ep:metadataPolicy"/>
  <h3>Data Policy</h3>
  <xsl:apply-templates select="ep:dataPolicy"/>
  <xsl:apply-templates select="ep:comment"/>
</xsl:template>

<xsl:template match="ep:content|ep:dataPolicy|ep:metadataPolicy|ep:submissionPolicy" xmlns:ep="http://www.openarchives.org/OAI/1.1/eprints">
  <xsl:if test="ep:text">
    <p><xsl:value-of select="ep:text" /></p>
  </xsl:if>
  <xsl:if test="ep:URL">
    <div><a href="{ep:URL}"><xsl:value-of select="ep:URL" /></a></div>
  </xsl:if>
</xsl:template>

<xsl:template match="ep:comment" xmlns:ep="http://www.openarchives.org/OAI/1.1/eprints">
  <h3>Comment</h3>
  <div><xsl:value-of select="."/></div>
</xsl:template>


<!--
   Identify / Friends
-->

<xsl:template match="fr:friends" xmlns:fr="http://www.openarchives.org/OAI/2.0/friends/">
  <h2>Friends</h2>
  <ul>
    <xsl:apply-templates select="fr:baseURL"/>
  </ul>
</xsl:template>

<xsl:template match="fr:baseURL" xmlns:fr="http://www.openarchives.org/OAI/2.0/friends/">
  <li><xsl:value-of select="."/> 
<xsl:text> </xsl:text>
<a class="link" href="{.}?verb=Identify">Identify</a></li>
</xsl:template>


<!--
   Identify / Branding
-->

<xsl:template match="br:branding" xmlns:br="http://www.openarchives.org/OAI/2.0/branding/">
  <h2>Branding</h2>
  <xsl:apply-templates select="br:collectionIcon"/>
  <xsl:apply-templates select="br:metadataRendering"/>
</xsl:template>

<xsl:template match="br:collectionIcon" xmlns:br="http://www.openarchives.org/OAI/2.0/branding/">
  <h3>Icon</h3>
  <xsl:choose>
    <xsl:when test="link!=''">
      <a href="{br:link}"><img src="{br:url}" alt="{br:title}" width="{br:width}" height="{br:height}" border="0" /></a>
    </xsl:when>
    <xsl:otherwise>
      <img src="{br:url}" alt="{br:title}" width="{br:width}" height="{br:height}" border="0" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="br:metadataRendering" xmlns:br="http://www.openarchives.org/OAI/2.0/branding/">
  <h3>Metadata Rendering Rule</h3>
  <table class="values">
    <tr><td class="key">URL</td>
    <td class="value"><xsl:value-of select="."/></td></tr>
    <tr><td class="key">Namespace</td>
    <td class="value"><xsl:value-of select="@metadataNamespace"/></td></tr>
    <tr><td class="key">Mime Type</td>
    <td class="value"><xsl:value-of select="@mimetype"/></td></tr>
  </table>
</xsl:template>



<!--
   Identify / Gateway
-->

<xsl:template match="gw:gateway" xmlns:gw="http://www.openarchives.org/OAI/2.0/gateway/x">
  <h2>Gateway Information</h2>
  <table class="values">
    <tr><td class="key">Source</td>
    <td class="value"><xsl:value-of select="gw:source"/></td></tr>
    <tr><td class="key">Description</td>
    <td class="value"><xsl:value-of select="gw:gatewayDescription"/></td></tr>
    <xsl:apply-templates select="gw:gatewayAdmin"/>
    <xsl:if test="gw:gatewayURL">
      <tr><td class="key">URL</td>
      <td class="value"><xsl:value-of select="gw:gatewayURL"/></td></tr>
    </xsl:if>
    <xsl:if test="gw:gatewayNotes">
      <tr><td class="key">Notes</td>
      <td class="value"><xsl:value-of select="gw:gatewayNotes"/></td></tr>
    </xsl:if>
  </table>
</xsl:template>

<xsl:template match="gw:gatewayAdmin" xmlns:gw="http://www.openarchives.org/OAI/2.0/gateway/">
  <tr><td class="key">Admin</td>
  <td class="value"><xsl:value-of select="."/></td></tr>
</xsl:template>


<!-- GetRecord -->

<xsl:template match="oai:GetRecord">
  <xsl:apply-templates select="oai:record" />
</xsl:template>

<!-- ListRecords -->

<xsl:template match="oai:ListRecords">
  <xsl:apply-templates select="oai:record" />
  <xsl:apply-templates select="oai:resumptionToken" />
</xsl:template>

<!-- ListIdentifiers -->

<xsl:template match="oai:ListIdentifiers">
  <xsl:apply-templates select="oai:header" />
  <xsl:apply-templates select="oai:resumptionToken" />
</xsl:template>

<!-- ListSets -->

<xsl:template match="oai:ListSets">
  <xsl:apply-templates select="oai:set" />
  <xsl:apply-templates select="oai:resumptionToken" />
</xsl:template>

<xsl:template match="oai:set">
  <h2>Set</h2>
  <table class="values">
    <tr><td class="key">setName</td>
    <td class="value"><xsl:value-of select="oai:setName"/></td></tr>
    <xsl:apply-templates select="oai:setSpec" />
  </table>
</xsl:template>

<!-- ListMetadataFormats -->

<xsl:template match="oai:ListMetadataFormats">
  <xsl:choose>
    <xsl:when test="$identifier">
      <p>This is a list of metadata formats available for the record "<xsl:value-of select='$identifier' />". Use these links to view the metadata: <xsl:apply-templates select="oai:metadataFormat/oai:metadataPrefix" /></p>
    </xsl:when>
    <xsl:otherwise>
      <p>This is a list of metadata formats available from this archive.</p>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:apply-templates select="oai:metadataFormat" />
</xsl:template>

<xsl:template match="oai:metadataFormat">
  <h2>Metadata Format</h2>
  <table class="values">
    <tr><td class="key">metadataPrefix</td>
    <td class="value"><xsl:value-of select="oai:metadataPrefix"/></td></tr>
    <tr><td class="key">metadataNamespace</td>
    <td class="value"><xsl:value-of select="oai:metadataNamespace"/></td></tr>
    <tr><td class="key">schema</td>
    <td class="value"><a href="{oai:schema}"><xsl:value-of select="oai:schema"/></a></td></tr>
  </table>
</xsl:template>

<xsl:template match="oai:metadataPrefix">
      <xsl:text> </xsl:text><a class="link" href="?verb=GetRecord&amp;metadataPrefix={.}&amp;identifier={$identifier}"><xsl:value-of select='.' /></a>
</xsl:template>

<!-- record object -->

<xsl:template match="oai:record">
  <h2 class="oaiRecordTitle">OAI Record: <xsl:value-of select="oai:header/oai:identifier"/></h2>
  <div class="oaiRecord">
    <xsl:apply-templates select="oai:header" />
    <xsl:apply-templates select="oai:metadata" />
    <xsl:apply-templates select="oai:about" />
  </div>
</xsl:template>

<xsl:template match="oai:header">
  <h3>OAI Record Header</h3>
  <table class="values">
    <tr><td class="key">OAI Identifier</td>
    <td class="value">
      <xsl:value-of select="oai:identifier"/>
      <xsl:text> </xsl:text><a class="link" href="?verb=GetRecord&amp;metadataPrefix=oai_dc&amp;identifier={oai:identifier}">oai_dc</a>
      <xsl:text> </xsl:text><a class="link" href="?verb=ListMetadataFormats&amp;identifier={oai:identifier}">formats</a>
    </td></tr>
    <tr><td class="key">Datestamp</td>
    <td class="value"><xsl:value-of select="oai:datestamp"/></td></tr>
  <xsl:apply-templates select="oai:setSpec" />
  </table>
  <xsl:if test="@status='deleted'">
    <p>This record has been deleted.</p>
  </xsl:if>
</xsl:template>


<xsl:template match="oai:about">
  <p>"about" part of record container not supported by the XSL</p>
</xsl:template>

<xsl:template match="oai:metadata">
  &#160;
  <div class="metadata">
    <xsl:apply-templates select="*" />
  </div>
</xsl:template>




<!-- oai setSpec object -->

<xsl:template match="oai:setSpec">
  <tr><td class="key">setSpec</td>
  <td class="value"><xsl:value-of select="."/>
    <xsl:text> </xsl:text><a class="link" href="?verb=ListIdentifiers&amp;metadataPrefix=oai_dc&amp;set={.}">Identifiers</a>
    <xsl:text> </xsl:text><a class="link" href="?verb=ListRecords&amp;metadataPrefix=oai_dc&amp;set={.}">Records</a>
  </td></tr>
</xsl:template>



<!-- oai resumptionToken -->

<xsl:template match="oai:resumptionToken">
   <p>There are more results.</p>
   <table class="values">
     <tr><td class="key">resumptionToken:</td>
     <td class="value"><xsl:value-of select="."/>
<xsl:text> </xsl:text>
<a class="link" href="?verb={/oai:OAI-PMH/oai:request/@verb}&amp;resumptionToken={.}">Resume</a></td></tr>
   </table>
</xsl:template>

<!-- unknown metadata format -->

<xsl:template match="response/*" priority='-100'>
  <h3>Unknown Metadata Format</h3>
  <div class="xmlSource">
    <xsl:apply-templates select="." mode='xmlMarkup' />
  </div>
</xsl:template>

<!-- oai_dc record -->

<xsl:template match="oai_dc:dc"  xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" >
  <div class="dcdata">
    <h3>Dublin Core Metadata (oai_dc)</h3>
    <table class="dcdata">
      <xsl:apply-templates select="*" />
    </table>
  </div>
</xsl:template>

<xsl:template match="dc:title" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Title</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:creator" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Author or Creator</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:subject" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Subject and Keywords</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:description" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Description</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:publisher" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Publisher</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:contributor" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Other Contributor</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:date" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Date</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:type" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Resource Type</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:format" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Format</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:identifier" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Resource Identifier</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:source" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Source</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:language" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Language</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:relation" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Relation</td><td class="value">
  <xsl:choose>
    <xsl:when test='starts-with(.,"http" )'>
      <xsl:choose>
        <xsl:when test='string-length(.) &gt; 50'>
          <a class="link" href="{.}">URL</a>
          <i> URL not shown as it is very long.</i>
        </xsl:when>
        <xsl:otherwise>
          <a href="{.}"><xsl:value-of select="."/></a>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="."/>
    </xsl:otherwise>
  </xsl:choose>
</td></tr></xsl:template>

<xsl:template match="dc:coverage" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Coverage</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<xsl:template match="dc:rights" xmlns:dc="http://purl.org/dc/terms/">
<tr><td class="key">Rights Management</td><td class="value"><xsl:value-of select="."/></td></tr></xsl:template>

<!-- XML Pretty Maker -->

<xsl:template match="node()" mode='xmlMarkup'>
  <div class="xmlBlock">
    &lt;<span class="xmlTagName"><xsl:value-of select='name(.)' /></span><xsl:apply-templates select="@*" mode='xmlMarkup'/>&gt;<xsl:apply-templates select="node()" mode='xmlMarkup' />&lt;/<span class="xmlTagName"><xsl:value-of select='name(.)' /></span>&gt;
  </div>
</xsl:template>

<xsl:template match="text()" mode='xmlMarkup'><span class="xmlText"><xsl:value-of select='.' /></span></xsl:template>

<xsl:template match="@*" mode='xmlMarkup'>
  <xsl:text> </xsl:text><span class="xmlAttrName"><xsl:value-of select='name()' /></span>="<span class="xmlAttrValue"><xsl:value-of select='.' /></span>"
</xsl:template>

<xsl:template name="xmlstyle">
.xmlSource {
	font-size: 70%;
	border: solid #c0c0a0 1px;
	background-color: #ffffe0;
	padding: 2em 2em 2em 0em;
}
.xmlBlock {
	padding-left: 2em;
}
.xmlTagName {
	color: #800000;
	font-weight: bold;
}
.xmlAttrName {
	font-weight: bold;
}
.xmlAttrValue {
	color: #0000c0;
}
</xsl:template>

</xsl:stylesheet>

