# set this to 1 if disk free doesn't work on your system
$c->{disable_df} = 0 if !defined $EPrints::SystemSettings::conf->{disable_df};

# location of executables
$c->{executables} = {
	  'convert' => '/usr/bin/convert',
	  'tar' => '/bin/tar',
	  'rm' => '/bin/rm',
	  'dvips' => '/usr/bin/dvips',
	  'gunzip' => '/bin/gunzip',
	  'sendmail' => '/usr/sbin/sendmail',
	  'unzip' => '/usr/bin/unzip',
	  'elinks' => '/usr/bin/elinks',
	  'cp' => '/bin/cp',
	  'latex' => '/usr/bin/latex',
	  'perl' => '/usr/bin/perl',
	  'pdftotext' => '/usr/bin/pdftotext',
	  'wget' => '/usr/bin/wget',
	  'antiword' => '/usr/bin/antiword',
	  'ffmpeg' => '/usr/bin/ffmpeg',
	};
