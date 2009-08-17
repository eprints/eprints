package EPrints::Plugin::Import::XSLT;

use EPrints::Plugin::Import;

@ISA = ( "EPrints::Plugin::Import" );

our %SETTINGS;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	my $path = $self->{path} = $EPrints::SystemSettings::conf->{base_path}."/lib/xslt/import";

	my $name = $self->{id};

	if( $name eq "Import::XSLT" )
	{
		$self->{name} = "XSLT";
		$self->{visible} = "";
		$self->{produce} = [];
		$self->{suffix} = "text";
		$self->{mimetype} = "text/plain";

		if( exists $EPrints::SystemSettings::conf->{executables}->{xsltproc} ) {
			$self->initialise( $path );
		}
	}
	elsif( $name =~ s/^Import::XSLT::// )
	{
		$self->{name} = munge_name($name);
		$self->{visible} = "all";
		$self->{produce} = [ 'list/eprint' ];
		$self->{handle} ||= $self->{processor}->{handle};
		$self->{Handler} ||= EPrints::CLIProcessor->new(
			handle => $self->{handle}
		);
		my $settings = $EPrints::Plugin::Import::XSLT::SETTINGS{$self->{id}};
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

		my $class = __PACKAGE__ . "::$name";

		eval <<EOC;
package $class;

our \@ISA = qw( $me );

1;
EOC

		my $plugin = $class->new();
		$EPrints::Plugin::Import::XSLT::SETTINGS{$plugin->{id}} = {
			stylesheet => $stylesheet,
		};
		EPrints::PluginFactory->register_plugin( $plugin );
	}
}

sub input_fh
{
	my( $plugin, %opts ) = @_;

	my $fh = $opts{fh};
	my $handle = $plugin->{handle};

	my $xmlplugin = $handle->plugin( "Import::XML",
		Handler => $plugin->handler,
		parse_only => $plugin->{parse_only},
	);

	my $path = $plugin->{path};
	my $stylesheet = $plugin->{stylesheet};

	my $xslt = "$path/$stylesheet";

	if( !-r $xslt )
	{
		delete $EPrints::Plugin::REGISTRY{$plugin->{id}};
		EPrints::abort "Oops! Looks like $xslt has disappeared\n";
	}

	my $xmlfile = File::Temp->new;
	my $epfile = File::Temp->new;

	binmode($xmlfile);
	my $buffer;
	while(read($fh,$buffer,4096))
	{
		print $xmlfile $buffer;
	}

	my %args = (
		STYLESHEET => $xslt,
		SOURCE => "$xmlfile",
		TARGET => "$epfile",
	);

	unless( $handle->get_repository->can_invoke( "xsltproc", %args ) )
	{
		EPrints::abort "Can't invoke xsltproc\n";
	}

	my $rc = EPrints::Platform::exec( $handle->get_repository, "xsltproc", %args );
	if( $rc )
	{
		$plugin->handler->message( "error", $handle->make_text( "Error invoking xslt processor (result = $rc)" ) );
		return;
	}

	my $list = $xmlplugin->input_fh( %opts, fh => $epfile );

	return $list;
}

1;
