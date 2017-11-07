<?xml version="1.0"?> 

<!-- Atom transformation -->

<xsl:stylesheet
	version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	ept:name="Atom XML"
	ept:visible="all"
	ept:advertise="1"
	ept:sourceNamespace="http://www.w3.org/2005/Atom"
	ept:targetNamespace="http://eprints.org/ep2/data/2.0"
	ept:produce="dataobj/eprint"
	ept:accept="application/atom+xml; type=entry"
	ept:type="import"
	xmlns:ept="http://eprints.org/ep2/xslt/1.0"
	xmlns:atom="http://www.w3.org/2005/Atom"
	xmlns="http://eprints.org/ep2/data/2.0"
>

<xsl:output method="xml" indent="yes" encoding="utf-8"/>

<xsl:template match="/">
<eprints>
<eprint>

<xsl:if test="atom:entry/atom:author">
<creators>
<xsl:for-each select="atom:entry/atom:author">
<item>
<name>
	<xsl:call-template name="printname">
		<xsl:with-param name="fullname" select="normalize-space(./atom:name)"/>
		<xsl:with-param name="lastname" select="normalize-space(./atom:name)"/>
	</xsl:call-template>
</name>
<id><xsl:value-of select="./atom:email"/></id>
</item>
</xsl:for-each>
</creators>
</xsl:if>

<xsl:if test="atom:entry/atom:link">
<related_url>
<xsl:for-each select="atom:entry/atom:link">
<item>
<url><xsl:value-of select="@href"/></url>
</item>
</xsl:for-each>
</related_url>
</xsl:if>

<xsl:if test="atom:entry/atom:contributor or atom:entry/atom:rights">
<note>
<xsl:for-each select="atom:entry/atom:contributor">
<xsl:value-of select="./atom:name"/> &lt;<xsl:value-of select="./atom:email"/>&gt;<br/>
</xsl:for-each>
<xsl:if test="atom:entry/atom:rights">
Rights: <xsl:value-of select="atom:entry/atom:rights"/>
</xsl:if>
</note>
</xsl:if>

<xsl:apply-templates select="atom:entry/*" />

</eprint>
</eprints>
</xsl:template>

<!-- scheme from: EPrints::Const::EP_NS_DATA -->
<xsl:template match="atom:category">
<xsl:if test="@scheme='http://eprints.org/ep2/data/2.0/eprint/eprint_status'">
	<eprint_status><xsl:value-of select="@term" /></eprint_status>
</xsl:if>
</xsl:template>

<xsl:template match="atom:title">
<title><xsl:value-of select="." /></title>
</xsl:template>

<xsl:template match="atom:summary">
<abstract><xsl:value-of select="." /></abstract>
</xsl:template>

<xsl:template name="printname" mode="printname">
<xsl:param name="fullname" />
<xsl:param name="lastname" />
<xsl:choose>
	<xsl:when test="contains($lastname, ' ')">
		<xsl:call-template name="printname">
				<xsl:with-param name="fullname" select="$fullname"/>
				<xsl:with-param name="lastname" select="substring-after($lastname, ' ')"/>
		</xsl:call-template>
	</xsl:when>
	<xsl:otherwise>
		<given><xsl:value-of select="substring-before($fullname,concat(' ',$lastname))"/></given>
		<family><xsl:value-of select="$lastname"/></family>
	</xsl:otherwise>
</xsl:choose>
</xsl:template>

<!-- Ignored -->
<xsl:template match="atom:rights|atom:contributor|atom:author|atom:link" />

</xsl:stylesheet>
