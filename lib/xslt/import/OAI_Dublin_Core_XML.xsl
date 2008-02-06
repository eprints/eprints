<?xml version="1.0"?> 

<!-- dublin core import -->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:ep="http://eprints.org/ep2/data/2.0">

<xsl:output method="xml" encoding="utf-8"/>
<xsl:namespace-alias stylesheet-prefix="ep" result-prefix="#default"/>

<xsl:template match="/">
<ep:eprints ep:xmlns="http://eprints.org/ep2/data/2.0">
<xsl:apply-templates select="//oai_dc:dc"/>
</ep:eprints>
</xsl:template>

<xsl:template match="oai_dc:dc">
<ep:eprint>
<type>article</type>
<creators>
<xsl:for-each select="dc:creator">
<item>
<name>
<xsl:choose>
<xsl:when test="contains(.,',')">
<family><xsl:value-of select="normalize-space(substring-before(.,','))"/></family>
<given><xsl:value-of select="normalize-space(substring-after(.,','))"/></given>
</xsl:when>
<xsl:otherwise>
<family><xsl:value-of select="substring-before(.,' ')"/></family>
<given><xsl:value-of select="substring-after(.,' ')"/></given>
</xsl:otherwise>
</xsl:choose>
</name>
<id></id>
</item>
</xsl:for-each>
</creators>
<xsl:apply-templates match="dc:*"/>
</ep:eprint>
</xsl:template>

<xsl:template match="dc:title[1]">
<ep:title><xsl:value-of select="."/></ep:title>
</xsl:template>

<xsl:template match="dc:description[1]">
<ep:abstract><xsl:value-of select="."/></ep:abstract>
</xsl:template>

<xsl:template match="dc:date[1]">
<ep:date><xsl:value-of select="."/></ep:date>
</xsl:template>

<xsl:template match="dc:identifier[1]">
<ep:official_url><xsl:value-of select="."/></ep:official_url>
</xsl:template>

<xsl:template match="dc:*"/>

</xsl:stylesheet>
