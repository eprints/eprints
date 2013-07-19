<?xml version="1.0"?> 

<!-- identity transformation -->

<xsl:stylesheet
	version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	ept:name="EP3 XML"
	ept:visible="all"
	ept:advertise="0"
	ept:sourceNamespace="http://eprints.org/ep2/data/2.0"
	ept:targetNamespace="http://eprints.org/ep2/data/2.0"
	ept:accept="list/eprint"
	ept:mimetype="text/xml; charset=UTF-8"
	ept:qs="0.1"
	xmlns:ept="http://eprints.org/ep2/xslt/1.0"
	xmlns:ep="http://eprints.org/ep2/data/2.0"
>

<xsl:output method="xml" indent="yes" encoding="utf-8"/>

<xsl:template match="ept:template">
<xsl:element name="{$dataset}s" namespace="http://eprints.org/ep2/data/2.0">
<xsl:value-of select="$results"/>
</xsl:element>
</xsl:template>

<xsl:template match="ep:*/ep:*">
  <xsl:copy>
    <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
