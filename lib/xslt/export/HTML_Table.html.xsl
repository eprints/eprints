<!--

Simple XSLT Example

Copyright 2008 Tim Brody <tdb01r@ecs.soton.ac.uk>

This file is distributed as part of GNU EPrints and is released under the same license.

-->

<!-- Note the ep namespace declaration, without which XPath won't match -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:ep="http://eprints.org/ep2/data/2.0">

<!-- General instructions to the XSLT processor -->
<xsl:output method="html" omit-xml-declaration="yes"/>

<!-- This suppresses the output of the ep namespace -->
<xsl:namespace-alias stylesheet-prefix="ep" result-prefix="#default"/>

<xsl:template match="/">
<!-- Start of output -->
<html>
<head>
<style>
html, body { font-family: sans-serif }
table { border: 1px outset #444; }
tr, td { border: 1px inset #444; }
table table { border-spacing: 0px; border-collapse: collapse; }
table table, table table tr, table table td { border: 0px; }
</style>
</head>
<body>
<h1>Eprint Objects</h1>

<!-- We can be called with a list or a single object, in list context eprints/ep:eprint will match, in single-object context ep:eprint will match -->
<xsl:for-each select="eprints/ep:eprint|ep:eprint">
<h2>Eprint <xsl:value-of select="ep:eprintid"/></h2>

<!-- here's a choose based on eprint status, but you could do one on 'type' -->
<xsl:choose>
<xsl:when test="ep:eprint_status = 'deletion'">
Deleted (this Export plugin won't expose deleted content).
</xsl:when>
<xsl:otherwise>
<table>
<!-- we'll just output the data in tables by using XSLT templates -->
<xsl:apply-templates select="*" />
</table>
</xsl:otherwise>
</xsl:choose>

</xsl:for-each>

</body>
</html>
<!-- End of output -->
</xsl:template>

<!-- handling a compound type with a name -->
<xsl:template match="ep:creators|ep:editors|ep:exhibitors|ep:producers|ep:lyricists|ep:conductors">
<tr><td style="font-weight: bold"><xsl:value-of select="name(.)"/></td><td>
<xsl:for-each select="ep:item">
<xsl:value-of select="./ep:name/ep:family"/>, <xsl:value-of select="./ep:name/ep:given"/><xsl:if test="position()!=last()"> and </xsl:if>
</xsl:for-each>
</td></tr>
</xsl:template>

<!-- handling the document object -->
<xsl:template match="ep:documents">
<tr><td style="font-weight: bold"><xsl:value-of select="name(.)"/></td><td>
<table>
<xsl:for-each select="ep:document/ep:files/ep:file[1]">
<tr><td><a><xsl:attribute name="href"><xsl:value-of select="ep:url"/></xsl:attribute><xsl:value-of select="ep:url"/></a> (<xsl:value-of select="ep:filesize"/> bytes)</td></tr>
</xsl:for-each>
</table>
</td></tr>
</xsl:template>

<!-- everything else (may be multiple) -->
<xsl:template match="*">
<tr><td style="font-weight: bold"><xsl:value-of select="name(.)"/></td><td>
<xsl:choose>
<xsl:when test="./ep:item[1]">
<table>
<xsl:for-each select="ep:item">
<tr><td><xsl:value-of select="."/></td></tr>
</xsl:for-each>
</table>
</xsl:when>
<xsl:otherwise>
<xsl:value-of select="."/>
</xsl:otherwise>
</xsl:choose>
</td></tr>
</xsl:template>

</xsl:stylesheet>
