<?xml version="1.0"?> 

<!-- identity transformation -->

<xsl:stylesheet
	version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	ept:name="OpenXML Bibliography"
	ept:visible="all"
	ept:advertise="1"
	ept:sourceNamespace="http://schemas.openxmlformats.org/officeDocument/2006/bibliography"
	ept:targetNamespace="http://eprints.org/ep2/data/2.0"
	ept:produce="list/eprint"
	xmlns:ept="http://eprints.org/ep2/xslt/1.0"
	xmlns:b="http://schemas.openxmlformats.org/officeDocument/2006/bibliography"
	xmlns="http://eprints.org/ep2/data/2.0"
>

<xsl:output method="xml" indent="yes" encoding="utf-8"/>

<xsl:template match="/">
<eprints>
<xsl:apply-templates select="b:Sources/b:Source" />
</eprints>
</xsl:template>

<xsl:template match="b:Source">
<eprint>
<eprint_status>inbox</eprint_status>
<xsl:apply-templates select="./*" />
</eprint>
</xsl:template>

<xsl:template match="b:SourceType|b:ThesisType">
<type>
<xsl:choose>
<xsl:when test=".='Art'">artefact</xsl:when>
<xsl:when test=".='ArticleInAPeriodical'">article</xsl:when>
<xsl:when test=".='Book'">book</xsl:when>
<xsl:when test=".='BookSection'">book_section</xsl:when>
<xsl:when test=".='Case'">other</xsl:when>
<xsl:when test=".='Conference'">conference_item</xsl:when>
<xsl:when test=".='DocumentFromInternetSite'">monograph</xsl:when>
<xsl:when test=".='ElectronicSource'">other</xsl:when>
<xsl:when test=".='Film'">video</xsl:when>
<xsl:when test=".='InternetSite'">other</xsl:when>
<xsl:when test=".='Interview'">other</xsl:when>
<xsl:when test=".='JournalArticle'">article</xsl:when>
<xsl:when test=".='Report'">monograph</xsl:when>
<xsl:when test=".='Misc'">other</xsl:when>
<xsl:when test=".='Patent'">patent</xsl:when>
<xsl:when test=".='Performance'">performance</xsl:when>
<xsl:when test=".='Proceedings'">book</xsl:when>
<xsl:when test=".='SoundRecording'">audio</xsl:when>
<xsl:when test=".='Ph.D. Thesis'">thesis</xsl:when>
<xsl:when test=".='Masters Thesis'">thesis</xsl:when>
<xsl:otherwise>other</xsl:otherwise>
</xsl:choose>
</type>
<xsl:choose>
<xsl:when test=".='Ph.D. Thesis'"><thesis_type>phd</thesis_type></xsl:when>
<xsl:when test=".='Masters Thesis'"><thesis_type>masters</thesis_type></xsl:when>
<xsl:otherwise />
</xsl:choose>
</xsl:template>

<xsl:template match="b:Title">
<title><xsl:value-of select="." /></title>
</xsl:template>

<xsl:template match="b:Year">
<date>
<xsl:value-of select="." />
<xsl:if test="../b:Month">
-<xsl:value-of select="../b:Month" />
<xsl:if test="../b:Day">
-<xsl:value-of select="../b:Day" />
</xsl:if>
</xsl:if>
</date>
</xsl:template>

<xsl:template match="b:Publisher">
<publisher><xsl:value-of select="." /></publisher>
</xsl:template>

<xsl:template match="b:Pages">
<page_range><xsl:value-of select="." /></page_range>
</xsl:template>

<xsl:template match="b:JournalName">
<publication><xsl:value-of select="." /></publication>
</xsl:template>

<xsl:template match="b:BookTitle">
<book_title><xsl:value-of select="." /></book_title>
</xsl:template>

<xsl:template match="b:City">
<place_of_pub>
<xsl:value-of select="." />
<xsl:if test="../b:CountryRegion">
, <xsl:value-of select="../b:CountryRegion" />
</xsl:if>
</place_of_pub>
</xsl:template>

<xsl:template match="b:Source/b:Author">
<xsl:apply-templates select="./*" />
</xsl:template>

<xsl:template match="b:Author">
<creators>
<xsl:for-each select="./b:NameList/b:Person">
<item><xsl:apply-templates select="." /></item>
</xsl:for-each>
</creators>
<corp_authors>
<xsl:for-each select="./b:Corporate">
<item><xsl:apply-templates select="." /></item>
</xsl:for-each>
</corp_authors>
</xsl:template>

<xsl:template match="b:Editor">
<editors>
<xsl:for-each select="./b:NameList/b:Person">
<item><xsl:apply-templates select="." /></item>
</xsl:for-each>
</editors>
</xsl:template>

<xsl:template match="b:Person">
<name>
<family><xsl:value-of select="./b:Last" /></family>
<given>
<xsl:value-of select="./b:First" />
<xsl:if test="./b:Middle">
<xsl:text> </xsl:text><xsl:value-of select="./b:Middle" />
</xsl:if>
</given>
</name>
</xsl:template>

<xsl:template match="b:Corporate">
<xsl:value-of select="." />
</xsl:template>

<!-- Ignored -->
<xsl:template match="b:Tag|b:Guid|b:LCID|b:RefOrder|b:Month|b:Day" />

</xsl:stylesheet>
