<?xml version="1.0"?> 

<!-- dublin core import -->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xxx="http://arxiv.org/OAI/arXiv/" xmlns:ep="http://eprints.org/ep2/data/2.0">

<xsl:output method="xml" encoding="utf-8"/>
<xsl:namespace-alias stylesheet-prefix="ep" result-prefix="#default"/>

<xsl:template match="/">
<ep:eprints ep:xmlns="http://eprints.org/ep2/data/2.0">
<xsl:apply-templates select="//xxx:arXiv"/>
</ep:eprints>
</xsl:template>

<xsl:template match="xxx:arXiv">
<ep:eprint>
<ep:type>article</ep:type>
<ep:official_url>http://arXiv.org/abs/<xsl:value-of select="xxx:id"/></ep:official_url>
<ep:documents>
<ep:document>
<ep:pos>1</ep:pos>
<ep:format>application/pdf</ep:format>
<ep:language>en</ep:language>
<ep:security>public</ep:security>
<ep:main>paper.pdf</ep:main>
<ep:files>
<ep:file>
<ep:filename>paper.pdf</ep:filename>
<ep:url>http://arXiv.org/pdf/<xsl:value-of select="xxx:id"/></ep:url>
</ep:file>
</ep:files>
</ep:document>
</ep:documents>
<ep:creators>
<xsl:for-each select="xxx:authors/xxx:author">
<ep:item>
<ep:name>
<ep:family><xsl:value-of select="xxx:keyname"/></ep:family>
<ep:given><xsl:value-of select="xxx:forenames"/></ep:given>
</ep:name>
<ep:id></ep:id>
</ep:item>
</xsl:for-each>
</ep:creators>
<ep:note>
<xsl:for-each select="xxx:comments|xxx:report-no">
<xsl:value-of select="."/>
<xsl:text>
</xsl:text>
</xsl:for-each>
</ep:note>
<xsl:apply-templates match="xxx:*"/>
</ep:eprint>
</xsl:template>

<xsl:template match="xxx:title[1]">
<ep:title><xsl:value-of select="."/></ep:title>
</xsl:template>

<xsl:template match="xxx:journal-ref[1]">
<ep:publication><xsl:value-of select="."/></ep:publication>
</xsl:template>

<xsl:template match="xxx:abstract[1]">
<ep:abstract><xsl:value-of select="."/></ep:abstract>
</xsl:template>

<xsl:template match="xxx:*"/>

</xsl:stylesheet>
