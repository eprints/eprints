package EPrints::Plugin::Screen::Subject::Check;

@ISA = ( 'EPrints::Plugin::Screen::Subject' );

use strict;
use warnings;

use List::Util qw( first minstr );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

#	$self->{actions} = [qw/ save add /];

	$self->{appears} = [
		{
			place => "admin_actions_config",
			position => 2100,
		},
	];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "subject/edit" );
}


sub render
{
	my( $self ) = @_;

	my $handle = $self->{handle};
	my $subject = $self->{processor}->{subject};

	my $page = $handle->make_doc_fragment;

	my @errors = check_subjects( $handle );

	if( @errors )
	{
		my $ul = $handle->make_element( "ul" );
		for(@errors)
		{
			my $li = $handle->make_element( "li" );
			$ul->appendChild( $li );
			$li->appendChild( $_ );
		}
		$page->appendChild( $self->html_phrase( "found_errors",
			errors => $ul,
		) );
	}
	else
	{
		$page->appendChild( $self->html_phrase( "no_errors" ) );
	}

	return $page;
}

######################################################################
=pod

=item @errors = check_subjects( $handle )

Perform some checks on the Subjects tree, returns a list of errors.

=cut
######################################################################

sub check_subjects
{
	my( $handle ) = @_;

	my @errors;

	my $dataset = $handle->get_repository->get_dataset( "subject" );

	my %subjects = (
		ROOT => {
			subjectid => "ROOT",
			parents => [],
		},
	);

	foreach my $subject ($handle->get_database->get_all( $dataset ))
	{
		$subjects{$subject->get_id} = {
			subjectid => $subject->get_id,
			parents => $subject->get_value( "parents" ),
		};
	}

	if( scalar(keys %subjects) == 0 )
	{
		push @errors, $handle->html_phrase( "Plugin/Screen/Subject/Check:no_subjects" );
	}

	# Check for invalid parent ids
	while(my( $subjectid, $subject ) = each %subjects)
	{
		if( $subjectid ne "ROOT" &&
			!EPrints::Utils::is_set($subject->{ "parents" }) )
		{
			push @errors, $handle->html_phrase( "Plugin/Screen/Subject/Check:orphaned",
				subjectid => $handle->make_text( $subjectid ),
			);
		}
		for(@{$subject->{ "parents" }})
		{
			if( exists($subjects{$_}) )
			{
				$_ = $subjects{$_};
			}
			else
			{
				push @errors, $handle->html_phrase( "Plugin/Screen/Subject/Check:no_such_parent",
					subjectid => $handle->make_text( $subjectid ),
					parentid => $handle->make_text( $_ ),
				);
				$_ = {};
			}
		}
	}

	my %loops;

	foreach my $subject (values %subjects)
	{
		%loops = (%loops, _check_recursion( $handle, $subject ));
	}

	while(my( $path, $subjects ) = each %loops)
	{
		push @errors, $handle->html_phrase( "Plugin/Screen/Subject/Check:loop",
			path => $handle->make_text( $path ),
		);
	}

	# Break circular references
	for(values %subjects)
	{
		$_->{parents} = [];
	}

	return @errors;
}

sub _check_recursion
{
	my( $handle, @path ) = @_;

	my %loops;

	foreach my $parent (@{$path[-1]->{parents}})
	{
		# Found a loop back to ourselves
		if( $parent eq $path[0] )
		{
			$loops{_loop_path_id(@path)} = [@path,$parent];
		}
		# Found a loop within our path, don't follow it!
		elsif( first { $_ eq $parent } @path )
		{
		}
		# Otherwise, continue on to this parent
		else
		{
			%loops = (%loops, _check_recursion( $handle, @path, $parent ));
		}
	}

	return %loops;
}

# Return a unique identifier for this circular path
sub _loop_path_id
{
	my( @path ) = @_;

	@path = map { $_->{subjectid} } @path;

	my $first = minstr @path;

	while( $path[0] ne $first )
	{
		push @path, shift @path;
	}

	return join "->", @path, $path[0];
}

1;
