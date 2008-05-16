#!/usr/bin/perl -w
use strict;

# usage:
# for i in `perl icons.svg.perl`; do perl icons.svg.perl $i | rsvg-convert -o out/$i.png ; done

if (defined $ARGV[0]) {
	while (<DATA>) {
		if (s/^([A-Za-z0-9]*)://) {
			print if $1 eq $ARGV[0];
		} else {
			print;
		}
	}
} else {
	my %types = ();
	while (<DATA>) {
		if (/^([A-Za-z0-9]*):/) { $types{$1} = 1; }
	}
	print join " ", keys %types;
}
__DATA__
<?xml version="1.0" ?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
	"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">

<!--

File format icons for GNU EPrints by Harry Mason (hjm200@zepler.net)
Copyright (c) 2003,2008 University of Southampton

version 1.1: 2008-03-27

-->

<svg
	xmlns="http://www.w3.org/2000/svg" version="1.0"
	xmlns:xlink="http://www.w3.org/1999/xlink"
	
	width="48" height="48"
	viewBox="-100 -100 1200 1200">

	<defs>
		<linearGradient id="paperedge"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#505050" />
			<stop offset="90%" stop-color="#202020" />
		</linearGradient>
		<linearGradient id="paper"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#ffffff" />
			<stop offset="90%" stop-color="#f0f0f0" />
		</linearGradient>
		<linearGradient id="paperfold"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#e0e0e0" />
			<stop offset="90%" stop-color="#d0d0d0" />
		</linearGradient>
		<linearGradient id="redtint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#c02020" />
			<stop offset="90%" stop-color="#a00000" />
		</linearGradient>
		<linearGradient id="bluetint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#2030b0" />
			<stop offset="90%" stop-color="#001090" />
		</linearGradient>
		<linearGradient id="greentint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#30a030" />
			<stop offset="90%" stop-color="#108010" />
		</linearGradient>
		<linearGradient id="purpletint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#902080" />
			<stop offset="90%" stop-color="#700060" />
		</linearGradient>
		<linearGradient id="blacktint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#202020" />
			<stop offset="90%" stop-color="#000000" />
		</linearGradient>
		<linearGradient id="yellowtint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#a09010" />
			<stop offset="90%" stop-color="#807000" />
		</linearGradient>
		<linearGradient id="orangetint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#b05010" />
			<stop offset="90%" stop-color="#903000" />
		</linearGradient>
		<linearGradient id="cyantint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#2080c0" />
			<stop offset="90%" stop-color="#0060a0" />
		</linearGradient>
		<linearGradient id="silvertint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#80a0c0" />
			<stop offset="90%" stop-color="#6080a0" />
		</linearGradient>
		<linearGradient id="graytint"
				x1="300" y1="100" x2="700" y2="900" gradientUnits="userSpaceOnUse">
			<stop offset="10%" stop-color="#a0a0a0" />
			<stop offset="90%" stop-color="#808080" />
		</linearGradient>

		<filter id="3d" filterUnits="userSpaceOnUse">
			<feGaussianBlur in="SourceAlpha" stdDeviation="4" result="blur"/>
			<feOffset in="blur" dx="4" dy="4" result="offsetBlur"/>
			<feSpecularLighting in="blur" surfaceScale="5" specularConstant=".5" 
					specularExponent="20" lighting-color="#bbbbbb"  
					result="specOut">
				<fePointLight x="-5000" y="-10000" z="20000"/>
			</feSpecularLighting>
			<feComposite in="specOut" in2="SourceAlpha" operator="in" result="specOut"/>
			<feComposite in="SourceGraphic" in2="specOut" operator="arithmetic" 
					k1="0" k2="1" k3="1" k4="0" result="litPaint"/>
			<feMerge>
				<feMergeNode in="offsetBlur"/>
				<feMergeNode in="litPaint"/>
			</feMerge>
		</filter>

		<filter id="shadow" filterUnits="userSpaceOnUse">
			<feGaussianBlur in="SourceAlpha" stdDeviation="20" result="blur"/>
			<feOffset in="blur" dx="75" dy="75" result="offsetBlur"/>
			<feComponentTransfer in="offsetBlur" result="colouredBlur">
				<feFuncR type="identity" />
				<feFuncG type="identity" />
				<feFuncB type="identity" />
				<feFuncA type="linear" slope="0.6" />
			</feComponentTransfer>
		
			<feMerge>
				<feMergeNode in="colouredBlur"/>
				<feMergeNode in="SourceGraphic"/>
			</feMerge>
		</filter>
		
		<font-face font-family="Mono">
			<font-face-src>
				<font-face-uri xlink:href="font/vera-mono.xml#font" />
			</font-face-src>
		</font-face>
	</defs>
	
	<style type="text/css">
		.paper {
			stroke: url(#paperedge);
			stroke-width: 25;
			stroke-linejoin: round;
		}
		.mono {
			font-family: 'Mono';
			font-size: 250;
		}
		
		text {
			/* text-anchor: end; */
			fill: #004080;
		}
		.shape {
			stroke-width: 35;
			fill: none;
			filter: url(#3d);
		}

	</style>

	<!-- <rect x="-200" y="-200" width="1400" height="1400" fill="white" /> -->
	
	<g filter="url(#shadow)">
		<polygon class="paper front" points="100,0 700,0 700,200 900,200 900,1000 100,1000"
			stroke="url(#paperedge)"
			fill="url(#paper)"
		 />
		<polygon class="paper back" points="700,0 700,200 900,200"
			stroke="url(#paperedge)"
			fill="url(#paperfold)"
		/>
	</g>
	<g class="greektext">
		<line x1="200" y1="550" x2="800" y2="550"
			style="stroke-dashoffset: 0;
			stroke: black;
			stroke-width: 20;
			stroke-dasharray: 70,20,30,20,50,20,50,20,30,20,80,20,60,20;
			"/>
		<line x1="200" y1="625" x2="800" y2="625"
			style="stroke-dashoffset: 220;
			stroke: black;
			stroke-width: 20;
			stroke-dasharray: 70,20,30,20,50,20,50,20,30,20,80,20,60,20;
			"/>
	</g>
	<g class="format">
word:		<g class="word">
word:			<rect class="shape" x="250" y="150" width="300" height="300"
word:				stroke="url(#bluetint)"
word:				filter="url(#3d)"
word:			/>
word:			<g transform="translate(200,900)">
word:			<text class="mono">doc</text>
word:			</g>
word:		</g>
rtf:		<g class="rtf">
rtf:			<rect class="shape" x="250" y="150" width="300" height="300"
rtf:				stroke="url(#bluetint)"
rtf:				filter="url(#3d)"
rtf:			/>
rtf:			<g transform="translate(200,900)">
rtf:			<text class="mono">RTF</text>
rtf:			</g>
rtf:		</g>
latex:		<g class="latex">
latex:			<path class="shape" d="
latex:					M 350 150
latex:					C 250 150 350 300 250 300
latex:					C 350 300 250 450 350 450
latex:					M 450 150
latex:					C 550 150 450 300 550 300
latex:					C 450 300 550 450 450 450"
latex:				filter="url(#3d)"
latex:				stroke="url(#purpletint)"
latex:			/>
latex:			<g transform="scale(0.8,1) translate(250,900)">
latex:			<text class="mono">LaTeX</text>
latex:			</g>
latex:		</g>
ascii:		<g class="plain">
ascii:			<path class="shape" d="
ascii:					M 350 150
ascii:					L 350 375
ascii:					C 350 425 450 425 450 375
ascii:					M 300 250
ascii:					L 450 250"
ascii:				filter="url(#3d)"
ascii:				stroke="url(#blacktint)"
ascii:			/>
ascii:			<g transform="translate(200,900)">
ascii:			<text class="mono">Text</text>
ascii:			</g>
ascii:		</g>
html:		<g class="html">
html:			<path class="shape" d="
html:					M 350 150
html:					L 250 300
html:					L 350 450
html:					M 450 150
html:					L 550 300
html:					L 450 450"
html:				filter="url(#3d)"
html:				stroke="url(#greentint)"
html:			/>
html:			<g transform="scale(0.8,1) translate(250,900)">
html:			<text class="mono">HTML</text>
html:			</g>
html:		</g>
ppt:		<g class="ppt">
ppt:			<g class="shape" filter="url(#3d)">
ppt:				<ellipse cx="275" cy="200" rx="25" ry="25"
ppt:					fill="url(#bluetint)"
ppt:				/>
ppt:				<ellipse cx="275" cy="300" rx="25" ry="25"
ppt:					fill="url(#bluetint)"
ppt:				/>
ppt:				<ellipse cx="275" cy="400" rx="25" ry="25"
ppt:					fill="url(#bluetint)"
ppt:				/>
ppt:				<path d="
ppt:						M 350 200
ppt:						L 550 200
ppt:						M 350 300
ppt:						L 550 300
ppt:						M 350 400
ppt:						L 550 400
ppt:						"
ppt:				stroke="url(#bluetint)"
ppt:				/>
ppt:			</g>
ppt:			<g transform="translate(200,900)">
ppt:			<text class="mono">ppt</text>
ppt:			</g>
ppt:		</g>
ps:		<g class="ps">
ps:			<path class="shape" d="
ps:					M 250 425
ps:					L 250 275
ps:					L 550 275
ps:					L 550 425
ps:					Z
ps:					M 300 275
ps:					L 300 175
ps:					L 500 175
ps:					L 500 275
ps:					"
ps:				filter="url(#3d)"
ps:				stroke="url(#orangetint)"
ps:				/>
ps:			<g transform="translate(200,900)">
ps:			<text class="mono">PS</text>
ps:			</g>
ps:		</g>
pdf:		<g class="pdf">
pdf:			<ellipse class="shape" cx="400" cy="300" rx="150" ry="150"
pdf:			filter="url(#3d)"
pdf:			stroke="url(#redtint)"/>
pdf:			<g transform="translate(200,900)">
pdf:			<text class="mono">PDF</text>
pdf:			</g>
pdf:		</g>
image:		<g class="image">
image:			<g class="shape" filter="url(#3d)" stroke="url(#cyantint)">
image:				<ellipse cx="400" cy="350" rx="25" ry="25" />
image:				<path d="
image:						M 250 425
image:						L 250 275
image:						L 550 275
image:						L 550 425
image:						Z
image:						M 350 275
image:						L 350 175
image:						L 450 175
image:						L 450 275
image:						"/>
image:			</g>
image:			<g transform="scale(0.8,1) translate(250,900)">
image:			<text class="mono">Image</text>
image:			</g>
image:		</g>
unknown:		<g class="unknown">
unknown:			<path class="shape" d="
unknown:					M 250 300
unknown:					L 550 300
unknown:					M 325 175
unknown:					L 475 425
unknown:					M 475 175
unknown:					L 325 425
unknown:					"
unknown:				filter="url(#3d)"
unknown:				stroke="url(#graytint)"
unknown:				/>
unknown:			<g transform="translate(200,900)">
unknown:			<text class="mono">?</text>
unknown:			</g>
unknown:		</g>
xls:		<g class="xls">
xls:			<path class="shape" d="
xls:					M 550 150
xls:					L 250 150
xls:					L 250 450
xls:					L 550 450
xls:					Z
xls:					M 250 250
xls:					L 550 250
xls:					M 250 350
xls:					L 550 350
xls:					M 400 150
xls:					L 400 450
xls:
xls:					"
xls:				stroke="url(#bluetint)"
xls:				filter="url(#3d)"/>
xls:			<g transform="translate(200,900)">
xls:			<text class="mono">xls</text>
xls:			</g>
xls:		</g>
audio:		<g class="video">
audio:			<g class="shape" filter="url(#3d)">
audio:				<path d="
audio:
audio:					M 250 250
audio:					L 325 250
audio:					L 325 350
audio:					L 250 350
audio:					z
audio:					M 325 250
audio:					L 425 150
audio:					L 425 450
audio:					L 325 350
audio:					M 550 250
audio:					L 550 350
audio:					M 500 200
audio:					A 50 100 0 0 1 500 400
audio:				" stroke="url(#cyantint)" />
audio:			</g>
audio:
audio:			<g transform="scale(0.8,1) translate(250,900)">
audio:			<text class="mono">Audio</text>
audio:			</g>
audio:		</g>
video:		<g class="video">
video:			<g class="shape" filter="url(#3d)">
video:				<rect x="250" y="175" width="300" height="250"
video:				stroke="url(#cyantint)"
video:				/>
video:				<path d="
video:
video:					M 480 300
video:					L 320 220
video:					L 320 380
video:					z
video:				" fill="url(#cyantint)" />
video:			</g>
video:
video:			<g transform="scale(0.8,1) translate(250,900)">
video:			<text class="mono">Video</text>
video:			</g>
video:		</g>
bz2:		<g class="bz2">
bz2:			<g class="shape" filter="url(#3d)">
bz2:				<path d="
bz2:					M 250 450
bz2:					L 450 450
bz2:					L 550 350
bz2:					L 550 150
bz2:					L 350 150
bz2:					L 250 250
bz2:					z
bz2:
bz2:					M 450 250
bz2:					L 250 250
bz2:
bz2:					M 450 250
bz2:					L 450 450
bz2:
bz2:					M 450 250
bz2:					L 550 150
bz2:
bz2:				" stroke="url(#yellowtint)" />
bz2:			</g>
bz2:
bz2:			<g transform="translate(200,900)">
bz2:			<text class="mono">bz2</text>
bz2:			</g>
bz2:		</g>
tgz:		<g class="tgz">
tgz:			<g class="shape" filter="url(#3d)">
tgz:				<path d="
tgz:					M 250 450
tgz:					L 450 450
tgz:					L 550 350
tgz:					L 550 150
tgz:					L 350 150
tgz:					L 250 250
tgz:					z
tgz:
tgz:					M 450 250
tgz:					L 250 250
tgz:
tgz:					M 450 250
tgz:					L 450 450
tgz:
tgz:					M 450 250
tgz:					L 550 150
tgz:
tgz:				" stroke="url(#yellowtint)" />
tgz:			</g>
tgz:
tgz:			<g transform="translate(200,900)">
tgz:			<text class="mono">tgz</text>
tgz:			</g>
tgz:		</g>
zip:		<g class="zip">
zip:			<g class="shape" filter="url(#3d)">
zip:				<path d="
zip:					M 250 450
zip:					L 450 450
zip:					L 550 350
zip:					L 550 150
zip:					L 350 150
zip:					L 250 250
zip:					z
zip:
zip:					M 450 250
zip:					L 250 250
zip:
zip:					M 450 250
zip:					L 450 450
zip:
zip:					M 450 250
zip:					L 550 150
zip:
zip:				" stroke="url(#yellowtint)" />
zip:			</g>
zip:
zip:			<g transform="translate(200,900)">
zip:			<text class="mono">Zip</text>
zip:			</g>
zip:		</g>
xml:		<g class="xml">
xml:			<g class="shape"
xml:				filter="url(#3d)"
xml:				>
xml:				<path class="shape" d="
xml:						M 350 150
xml:						L 250 300
xml:						L 350 450
xml:
xml:						M 500 350
xml:						C 500,300 550,250 550,200
xml:						A 50,50 0 1 0 450,200
xml:						"
xml:				stroke="url(#greentint)"
xml:				/>
xml:				<ellipse cx="500" cy="425" rx="25" ry="25"
xml:				fill="url(#greentint)"
xml:				/>
xml:			</g>
xml:
xml:			<g transform="translate(200,900)">
xml:			<text class="mono">XML</text>
xml:			</g>
xml:		</g>
	</g>
</svg>
