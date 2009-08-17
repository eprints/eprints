package EPrints::Plugin::Export::XSLT;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

our %SETTINGS;

use strict;

our %TYPES = (
	csv => {
		suffix => ".txt",
		mimetype => "application/vnd.ms-excel",
	},
	html => {
		suffix => ".html",
		mimetype => "text/html",
	},
	text => {
		suffix => ".txt",
		mimetype => "text/plain",
	},
	xml => {
		suffix => ".xml",
		mimetype => "text/xml",
	},
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	my $path = $self->{path} = $EPrints::SystemSettings::conf->{base_path}."/lib/xslt/export";

	my $name = $self->{id};

	if( $name eq "Export::XSLT" )
	{
		$self->{name} = "XSLT";
		$self->{accept} = [];
		$self->{visible} = "";
		$self->{suffix} = "text";
		$self->{mimetype} = "text/plain";

		if( exists $EPrints::SystemSettings::conf->{executables}->{xsltproc} ) {
			$self->initialise( $path );
		}
	}
	elsif( $name =~ s/^Export::XSLT::// )
	{
		$self->{name} = munge_name($name);
		$self->{accept} = [ 'dataobj/eprint', 'list/eprint' ];
		$self->{visible} = "all";
		my $settings = $EPrints::Plugin::Export::XSLT::SETTINGS{$self->{id}};
		$self->{suffix} = $settings->{suffix};
		$self->{mimetype} = $settings->{mimetype};
		$self->{stylesheet} = $settings->{stylesheet};
	}

	return $self;
}

sub munge_name
{
	my( $name ) = @_;
	$name =~ s/_/ /g;
	return $name;
}

sub initialise
{
	my( $self, $path ) = @_;

	opendir(my $dir, $path) or return;
	my @stylesheets = grep { /\.xsl$/ } readdir($dir);
	closedir($dir);

	my $me = __PACKAGE__;

	foreach my $stylesheet (@stylesheets)
	{
		my $name = $stylesheet;
		next unless $name =~ s/^([a-zA-Z0-9_]+)(?:\.([^.]+))?\.xsl$/$1/;
		my $type = $2;

		my $suffix = $TYPES{text}->{suffix};
		my $mimetype = $TYPES{text}->{mimetype};

		if( defined $type )
		{
			if( exists($TYPES{$type}) )
			{
				$suffix = $TYPES{$type}->{suffix};
				$mimetype = $TYPES{$type}->{mimetype};
			}
			else
			{
				EPrints::abort ".$type.xsl is not a valid extension for xslt transforms - you must rename or remove $path/$stylesheet\n";
			}
		}

		my $class = __PACKAGE__ . "::$name";

		eval <<EOC;
package $class;

our \@ISA = qw( $me );

1;
EOC

		my $plugin = $class->new();
		$EPrints::Plugin::Export::XSLT::SETTINGS{$plugin->{id}} = {
			stylesheet => $stylesheet,
			suffix => $suffix,
			mimetype => $mimetype,
		};
		EPrints::PluginFactory->register_plugin( $plugin );
	}
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $r = "";

	my $handle = $plugin->{handle};

	my $path = $plugin->{path};
	my $stylesheet = $plugin->{stylesheet};

	my $xslt = "$path/$stylesheet";

	if( !-r $xslt )
	{
		delete $EPrints::Plugin::REGISTRY{$plugin->{id}};
		EPrints::abort "Oops! Looks like $xslt has disappeared\n";
	}

	my $xmlfile = File::Temp->new;
	my $tmpfile = File::Temp->new;

	my %args = (
		STYLESHEET => $xslt,
		SOURCE => "$xmlfile",
		TARGET => "$tmpfile",
	);

	unless( $handle->get_repository->can_invoke( "xsltproc", %args ) )
	{
		EPrints::abort "Can't invoke xsltproc\n";
	}

	my $xml_plugin = $handle->plugin( "Export::XML" );
	print $xmlfile $xml_plugin->output_dataobj( $dataobj );

	my $rc = EPrints::Platform::exec( $handle->get_repository, "xsltproc", %args );
	if( $rc )
	{
		EPrints::abort "Error invoking xsltproc (result = $rc)\n";
	}

	{
		use bytes;
		utf8::encode($r); # turn off utf8
		while(read($tmpfile,$r,4096,length($r)))
		{
		}
	}

	return $r;
}

1;
