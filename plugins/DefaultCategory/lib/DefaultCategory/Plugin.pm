package DefaultCategory::Plugin;

use strict;
use warnings;

sub blog_config_template {
    my ($plugin, $param, $scope) = @_;
    my $app = MT->instance;

    # Create a list of categories, to populate the Select dropdown.
    use MT::Category;
    my @categories = MT::Category->load(
        { blog_id => $app->blog->id,
          class   => 'category', },
        { sort      => 'label',
          direction => 'ascend', },
    );

    # Grab the previously-saved settings, then generate a list of categories
    # for the dropdown.
    my $cms_default = $plugin->get_config_value('cms_default_category', $scope);
    my @cms_cats = _generate_category_list($cms_default, @categories);
    $param->{cms_cats} = \@cms_cats;

    my $api_default = $plugin->get_config_value('api_default_category', $scope);
    my @api_cats = _generate_category_list($api_default, @categories);
    $param->{api_cats} = \@api_cats;
    
    my $form = <<HTML;
<div id="field-default-category" class="field field-top-label pkg">
    <div class="field-content">
        <div>The selected category will be attached to any entry that does <em>not</em> have any other category placement. The value in parenthesis is the category basename.</div>
    </div>
</div>

<mtapp:setting
    id="cms_default_category"
    label="CMS"
    hint="This field affects any entries edited through the CMS."
    show_hint="1">
    <select name="cms_default_category">
        <option value="">None</option>
    <mt:Loop name="cms_cats">
        <option value="<mt:Var name="basename">"<mt:If name="selected"> selected="selected"</mt:If>><mt:Var name="label"> (<mt:Var name="basename">)</option>
    </mt:Loop>
    </select>
</mtapp:setting>
<mtapp:setting
    id="api_default_category"
    label="API"
    hint="This field affects any entries edited through the XML-RPC or Atom API."
    show_hint="1">
    <select name="api_default_category">
        <option value="">None</option>
    <mt:Loop name="api_cats">
        <option value="<mt:Var name="basename">"<mt:If name="selected"> selected="selected"</mt:If>><mt:Var name="label"> (<mt:Var name="basename">)</option>
    </mt:Loop>
    </select>
</mtapp:setting>
HTML

    return $form;
}

sub _generate_category_list {
    my $default = shift;
    my (@categories) = @_;
    my ($selected, @cats);

    foreach my $c (@categories) {
        if ($default eq $c->basename) {
            $selected = 1;
        }
        else {
            $selected = 0;
        }
        push @cats, { basename => $c->basename,
                      label    => $c->label,
                      selected => $selected,
                    };
    }
    return @cats;
}

sub cms_post_save {
    my ($cb, $app, $obj, $original) = @_;

    # Check if a category is assigned to this entry. A category must *not*
    # be assigned for us to continue.
    if ( !$app->param('category_ids') ) {
        my $plugin = MT->component('defaultcategory');
        my $default = $plugin->get_config_value('cms_default_category', 'blog:'.$obj->blog_id);

        # Only save if a default category was selected for this blog.
        if ($default) {
            # $default is the category basename. Use the basename to load
            # the category, so we can get at the category ID, which is what
            # is used to set the default category.
            use MT::Category;
            my $cat = MT::Category->load(
                { blog_id  => $obj->blog_id,
                  class    => 'category',
                  basename => $default },
            );
            
            # Give up if no category could be loaded. The likely case is
            # that the "None" category (the default option) was saved, and
            # since there is no category by that name it doesn't load
            # anything.
            return 1 unless $cat;

            # Finally, go set the default category for this entry.
            _default_category($app, $obj, $cat->id);
        }
    }
    1;
}

sub api_post_save {
    my ($cb, $app, $obj, $original) = @_;

    # Check if a category is assigned to this entry. A category must *not*
    # be assigned for us to continue.
    if ( !$obj->category_id ) {
        my $plugin = MT->component('defaultcategory');
        my $default = $plugin->get_config_value('api_default_category', 'blog:'.$obj->blog_id);

        # Only save if a default category was selected for this blog.
        if ($default) {
            # $default is the category basename. Use the basename to load
            # the category, so we can get at the category ID, which is what
            # is used to set the default category.
            use MT::Category;
            my $cat = MT::Category->load(
                { blog_id  => $obj->blog_id,
                  class    => 'category',
                  basename => $default },
            );
            
            # Give up if no category could be loaded. The likely case is
            # that the "None" category (the default option) was saved, and
            # since there is no category by that name it doesn't load
            # anything.
            return 1 unless $cat;

            # Finally, go set the default category for this entry.
            _default_category($app, $obj, $cat->id);
        }
    }
    1;
}

sub _default_category {
    my ($app, $obj, $cat_id) = @_;

    $obj->category_id($cat_id);
    $obj->save; # Must save the category_id change for it to work, duh.

    use MT::Placement;
    my $place = MT::Placement->load( { entry_id   => $obj->id, 
                                       is_primary => 1, }
                                   );
    unless ( $place ) { # No placement record found; start a new one!
        $place = MT::Placement->new;
        $place->entry_id( $obj->id );
        $place->blog_id( $obj->blog_id );
        $place->is_primary(1); # Make it the primary category, because it's the *only* category!
    }
    $place->category_id( $cat_id );
    $place->save
        or die $place->errstr;
}

1;

__END__
