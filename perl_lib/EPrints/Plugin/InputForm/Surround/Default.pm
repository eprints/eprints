package EPrints::Plugin::InputForm::Surround::Default;

use strict;

our @ISA = qw/ EPrints::Plugin /;


sub render_title
{
	my( $self, $component ) = @_;

	my $title = $component->render_title( $self );

	if( $component->is_required )
	{
		$title = $self->{session}->html_phrase( 
			"sys:ep_form_required",
			label=>$title );
	}

	return $title;
}


sub render
{
	my( $self, $component ) = @_;

	my $help = $component->render_help( $self );
	my $comp_name = $component->get_name();
	my @problems = @{$component->get_problems()};

	my $surround = $self->{session}->make_element( "div", class => "ep_sr_component" );
	foreach my $field_id ( $component->get_fields_handled )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>$field_id ) );
	}
	if( $component->get_internal_button )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>"t" ) );
	}

	# Help rendering


	my $title_bar = $self->{session}->make_element( "div", class=>"ep_sr_title_bar" );

	my $help_prefix = $component->{prefix}."_help";

	my $help_table = $self->{session}->make_element( "table",cellpadding=>"0",border=>"0",cellspacing=>"0", width=>"100%" );
	my $help_table_tr = $self->{session}->make_element( "tr" );
	my $help_table_td1 = $self->{session}->make_element( "td" );
	my $help_table_td2 = $self->{session}->make_element( "td", align=>"right" );
	$help_table->appendChild( $help_table_tr );
	$help_table_tr->appendChild( $help_table_td1 );
	$help_table_tr->appendChild( $help_table_td2 );

	$title_bar->appendChild( $help_table );
	my $title_div = $self->{session}->make_element( "div", class=>"ep_sr_title" );
	$help_table_td1->appendChild( $title_div );

	my $show_help = $self->{session}->make_element( "div", class=>"ep_sr_show_help ep_only_js", id=>$help_prefix."_show" );
	my $helplink = $self->{session}->make_element( "a", onClick => "EPJS_toggle('$help_prefix',false,'block');EPJS_toggle('${help_prefix}_hide',false,'block');EPJS_toggle('${help_prefix}_show',true,'block');return false", href=>"#" );
	$show_help->appendChild( $self->html_phrase( "show_help",link=>$helplink ) );
	$help_table_td2->appendChild( $show_help );

	my $hide_help = $self->{session}->make_element( "div", class=>"ep_sr_hide_help ep_hide", id=>$help_prefix."_hide" );
	my $helplink2 = $self->{session}->make_element( "a", onClick => "EPJS_toggle('$help_prefix',false,'block');EPJS_toggle('${help_prefix}_hide',false,'block');EPJS_toggle('${help_prefix}_show',true,'block');return false", href=>"#" );
	$hide_help->appendChild( $self->html_phrase( "hide_help",link=>$helplink2 ) );
	$help_table_td2->appendChild( $hide_help );
	
	my $help_div = $self->{session}->make_element( "div", class => "ep_sr_help ep_no_js", id => $help_prefix );
	$help_div->appendChild( $help );

	$help_table_td2->appendChild( $help_div );

	# Problem rendering

	if( scalar @problems > 0 )
	{
		my $problem_div = $self->{session}->make_element( "div", class => "wf_problems" );
		foreach my $problem ( @problems )
		{
			$problem_div->appendChild( $problem );
		}
		$surround->appendChild( $problem_div );
	}

	# Finally add the content 
	my $input_div = $self->{session}->make_element( "div", class => "ep_sr_input" );

	$input_div->appendChild( $help_div );
	$input_div->appendChild( $component->render_content( $self ) );

	$surround->appendChild( $title_bar );
	$surround->appendChild( $input_div );

	if( $component->is_collapsed )
	{
		my $outer = $self->{session}->make_doc_fragment;
		my $col_prefix = $component->{prefix}."_help";
		my $col_div = $self->{session}->make_element( "div", class=>"ep_sr_collapse_bar ep_only_js", id => $col_prefix."_bar" );
		my $col_link =  $self->{session}->make_element( "a", onClick => "EPJS_toggle('${col_prefix}_bar',true,'block');EPJS_toggle('${col_prefix}_full',false,'block');return false", href=>"#" );
		$col_div->appendChild( $col_link );
		$col_link->appendChild( $self->{session}->make_element( "img", alt=>"+", src=>"/style/images/plus.png", border=>0 ) );
		$col_link->appendChild( $self->{session}->make_text( " " ) );
		$col_link->appendChild( $component->render_title( $self ) );
		$outer->appendChild( $col_div );
		my $inner = $self->{session}->make_element( "div", class=>"ep_no_js", id => $col_prefix."_full" );
		$inner->appendChild( $surround );
		$outer->appendChild( $inner );

		# alternate title to allow it to re-hide
		my $recol_link =  $self->{session}->make_element( "a", onClick => "EPJS_toggle('${col_prefix}_bar',true,'block');EPJS_toggle('${col_prefix}_full',false,'block');return false", href=>"#", class=>"ep_only_js" );
		$recol_link->appendChild( $self->{session}->make_element( "img", alt=>"-", src=>"/style/images/minus.png", border=>0 ) );
		$recol_link->appendChild( $self->{session}->make_text( " " ) );
		#nb. clone the title as we've already used it above.
		$recol_link->appendChild( $self->render_title( $component ) );
		$title_div->appendChild( $recol_link );

		my $nojstitle = $self->{session}->make_element( "div", class=>"ep_no_js" );
		$nojstitle->appendChild( $self->render_title( $component ) );
		$title_div->appendChild( $nojstitle );

		return $outer;
	}

	$title_div->appendChild( $self->render_title( $component ) );
	
	return $surround;
}

1;
