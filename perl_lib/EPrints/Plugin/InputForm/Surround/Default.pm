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

	my $surround = $self->{session}->make_element( "div",
		class => "ep_sr_component",
		id => $component->{prefix} );


	foreach my $field_id ( $component->get_fields_handled )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>$field_id ) );
	}

	my $barid = $component->{prefix}."_titlebar";
	my $title_bar_class="";
	my $content_class="";
	if( $component->is_collapsed )
	{
		$title_bar_class = "ep_no_js";
		$content_class = "ep_no_js";
	}
		
	my $title_bar = $self->{session}->make_element( "div", class=>"ep_sr_title_bar $title_bar_class", id=>$barid );
	my $title_div = $self->{session}->make_element( "div", class=>"ep_sr_title" );

	my $content = $self->{session}->make_element( "div", id => $component->{prefix}."_content", class=>"$content_class ep_sr_content" );
	my $content_inner = $self->{session}->make_element( "div", id => $component->{prefix}."_content_inner" );
	$surround->appendChild( $title_bar );

	$content->appendChild( $content_inner );

	# Help rendering
	if( $component->has_help )
	{
		my $help_prefix = $component->{prefix}."_help";
	
		my $help_table = $self->{session}->make_element( "table",cellpadding=>"0",border=>"0",cellspacing=>"0", width=>"100%" );
		my $help_table_tr = $self->{session}->make_element( "tr" );
		my $help_table_td1 = $self->{session}->make_element( "td" );
		my $help_table_td2 = $self->{session}->make_element( "td", align=>"right" );
		$help_table->appendChild( $help_table_tr );
		$help_table_tr->appendChild( $help_table_td1 );
		$help_table_tr->appendChild( $help_table_td2 );
		$help_table_td1->appendChild( $title_div );
	
		my $show_help = $self->{session}->make_element( "div", class=>"ep_sr_show_help ep_only_js ep_toggle", id=>$help_prefix."_show" );
		my $helplink = $self->{session}->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlide('$help_prefix',false);EPJS_toggle('${help_prefix}_hide',false);EPJS_toggle('${help_prefix}_show',true);return false", href=>"#" );
		$show_help->appendChild( $self->html_phrase( "show_help",link=>$helplink ) );
		$help_table_td2->appendChild( $show_help );
	
		my $hide_help = $self->{session}->make_element( "div", class=>"ep_sr_hide_help ep_hide ep_toggle", id=>$help_prefix."_hide" );
		my $helplink2 = $self->{session}->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlide('$help_prefix',false);EPJS_toggle('${help_prefix}_hide',false);EPJS_toggle('${help_prefix}_show',true);return false", href=>"#" );
		$hide_help->appendChild( $self->html_phrase( "hide_help",link=>$helplink2 ) );
		$help_table_td2->appendChild( $hide_help );
		
		my $help_div = $self->{session}->make_element( "div", class => "ep_sr_help ep_no_js", id => $help_prefix );
		my $help_div_inner = $self->{session}->make_element( "div", id => $help_prefix."_inner" );
		$help_div_inner->appendChild( $help );
		$help_div->appendChild( $help_div_inner );
		$content_inner->appendChild( $help_div );

		$title_bar->appendChild( $help_table );
	}
	else
	{
		$title_bar->appendChild( $title_div );
	}

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

	my $imagesurl = $self->{session}->get_repository->get_conf( "rel_path" );

	$content_inner->appendChild( $component->render_content( $self ) );

	if( $component->is_collapsed )
	{
		my $colbarid = $component->{prefix}."_col";
		my $col_div = $self->{session}->make_element( "div", class=>"ep_sr_collapse_bar ep_only_js ep_toggle", id => $colbarid );

		my $contentid = $component->{prefix}."_content";
		my $main_id = $component->{prefix};
		my $col_link =  $self->{session}->make_element( "a", class=>"ep_sr_collapse_link", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${contentid}',false,'${main_id}');EPJS_toggle('${colbarid}',true);EPJS_toggle('${barid}',false);return false", href=>"#" );

		$col_div->appendChild( $col_link );
		$col_link->appendChild( $self->{session}->make_element( "img", alt=>"+", src=>"$imagesurl/style/images/plus.png", border=>0 ) );
		$col_link->appendChild( $self->{session}->make_text( " " ) );
		$col_link->appendChild( $component->render_title( $self ) );
		$surround->appendChild( $col_div );

		# alternate title to allow it to re-hide
		my $recol_link =  $self->{session}->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${contentid}',false,'${main_id}');EPJS_toggle('${colbarid}',true);EPJS_toggle('${barid}',false);return false", href=>"#", class=>"ep_only_js ep_toggle ep_sr_collapse_link" );
		$recol_link->appendChild( $self->{session}->make_element( "img", alt=>"-", src=>"$imagesurl/style/images/minus.png", border=>0 ) );
		$recol_link->appendChild( $self->{session}->make_text( " " ) );
		#nb. clone the title as we've already used it above.
		$recol_link->appendChild( $self->render_title( $component ) );
		$title_div->appendChild( $recol_link );

		my $nojstitle = $self->{session}->make_element( "div", class=>"ep_no_js" );
		$nojstitle->appendChild( $self->render_title( $component ) );
		$title_div->appendChild( $nojstitle );

	}
	else
	{
		$title_div->appendChild( $self->render_title( $component ) );
	}
	
	$surround->appendChild( $content );
	return $surround;
}

1;
