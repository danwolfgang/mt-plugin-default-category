# Default Category
# by Dan Wolfgang
# http://uinnovations.com

package MT::Plugin::DefaultCategory;

use strict;
use warnings;
use MT 4.2;
use base qw(MT::Plugin);

our $VERSION = '1.0';

my $plugin = __PACKAGE__->new({
    key             => 'defaultcategory',
    id              => 'defaultcategory',
    name            => 'Default Category',
    description     => 'Specify a default category for all entries.',
    author_name     => 'Dan Wolfgang, uiNNOVATIONS',
    author_link     => 'http://uinnovations.com/',
    version         => $VERSION,
    blog_config_template => \&_config_template,
    settings        => new MT::PluginSettings([
        ['default_category', { Default => '', }],
    ]),
});

MT->add_plugin($plugin);

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        callbacks => {
            'api_post_save.entry' => {
                handler => \&api_post_save,
            },
            'cms_post_save.entry' => {
                handler => \&cms_post_save,
            },
        },
    });
}

sub instance { $plugin; }

sub _config_template {
    my ($plugin, $param, $scope) = @_;
    
    my $app = MT->instance;

    # Create a list of the categories, to populate the Select dropdown.
    use MT::Blog;
    use MT::Category;
    my @categories = MT::Category->load({ blog_id => $app->blog->id,
                                          class   => 'category', },
                                        { sort      => 'label',
                                          direction => 'ascend', },
                                       );
    my $default = $plugin->get_config_value('default_category', $scope);
    my ($selected, @cats);
    foreach my $c (@categories) {
        if ($default eq $c->id) {
            $selected = 1;
        }
        else {
            $selected = 0;
        }
        push @cats, { id       => $c->id,
                      label    => $c->label,
                      selected => $selected,
                    };
    }

    $param->{cats} = \@cats;
    
    my $form = <<HTML;
<mtapp:setting
    id="default_category"
    label="Choose a default category"
    hint="The selected category will be attached to any entry that does <em>not</em> have any other category placement. The number present in parenthesis is the category ID."
    show_hint="1">
    <select name="default_category">
        <option>None</option>
    <mt:Loop name="cats">
        <option value="<mt:Var name="id">"<mt:If name="selected"> selected="selected"</mt:If>><mt:Var name="label"> (<mt:Var name="id">)</option>
    </mt:Loop>
    </select>
</mtapp:setting>
HTML
    return $form;
}

sub cms_post_save {
    my ($cb, $app, $obj, $original) = @_;

    if ( !$app->param('category_ids') ) { # No category was selected
        _default_category($app, $obj);
    }
    1;
}

sub api_post_save {
    my ($cb, $app, $obj, $original) = @_;

    if ( !$obj->category_id ) { # No category was selected
        _default_category($app, $obj);
    }
    1;
}

sub _default_category {
    my ($app, $obj) = @_;
    my $plugin = MT::Plugin::DefaultCategory->instance();
    my $default = $plugin->get_config_value('default_category', 'blog:'.$obj->blog_id);

    if ( $default ) { # Only save if a default category was selected for this blog.
        $obj->category_id($default);
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
        $place->category_id( $default ); # The default category ID
        $place->save
            or die $place->errstr;
    }
}

1;

__END__