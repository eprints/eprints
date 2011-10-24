# set this to 1 if disk free doesn't work on your system
$c->{disable_df} = 0 if !defined $EPrints::SystemSettings::conf->{disable_df};
$c->{executables} ||= {};

# location of executables
{
use Config; # for perlpath
my %executables = (
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
	  'perl' => $Config{perlpath},
	  'pdftotext' => '/usr/bin/pdftotext',
	  'wget' => '/usr/bin/wget',
	  'antiword' => '/usr/bin/antiword',
	  'ffmpeg' => '/usr/bin/ffmpeg',
	  'file' => '/usr/bin/file',
	  'doc2txt' => "$c->{base_path}/tools/doc2txt",
	  'unoconv' => '/usr/bin/unoconv',
	  'txt2refs' => "$c->{base_path}/tools/txt2refs",
	);
while(my( $name, $path ) = each %executables)
{
	next if exists $c->{executables}->{$name};
	$c->{executables}->{$name} = $path if -x $path;
}
}
