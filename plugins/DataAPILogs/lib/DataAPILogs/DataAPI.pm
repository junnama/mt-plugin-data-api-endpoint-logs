package DataAPILogs::DataAPI;

use strict;
use warnings;

use MT::DataAPI::Endpoint::Common;
use MT::DataAPI::Resource;

sub _handler_data_api_get_logs {
    my ( $app, $endpoint ) = @_;
    my ( $blog ) = context_objects( @_ );
    if ( $endpoint->{ requires_login } ) {
        my $user = $app->user;
        if (! $user || $user->is_anonymous ) {
            return $app->print_error( 'Unauthorized', 401 );
        } else {
            my $perm = $user->is_superuser;
            if (! $perm ) {
                if ( $blog ) {
                    my $admin = 'can_administer_blog';
                    $perm = $user->permissions( $blog->id )->$admin;
                    $perm = $user->permissions( $blog->id )->view_blog_log unless $perm;
                } else {
                    $perm = $user->permissions()->view_log;
                }
            }
            if (! $perm ) {
                return $app->print_error( 'Permission denied.', 401 );
            }
        }
    }
    my $terms = _data_api_setup_terms( $app, $endpoint, 'log' );
    my $count = MT->model( 'log' )->count( $terms );
    my $args = _data_api_setup_args( $app, $endpoint, 'log' );
    my @logs = MT->model( 'log' )->load( $terms, $args );
    if (! $app->param( 'fields' ) ) {
        my $fields = 'id,message,created_on,category,lebel,ip,author_id,metadata';
        $app->param( 'fields', $fields );
    }
    my @result_objects;
    for my $log ( @logs ) {
        $log->class( undef );
        push( @result_objects, $log );
    }
    return {
        totalResults => $count,
        items => \@result_objects,
    };
    return 1;
}

sub _data_api_setup_terms {
    my ( $app, $endpoint, $model ) = @_;
    my $terms = {};
    if ( MT->model( $model )->has_column( 'blog_id' ) ) {
        if ( my $blog = $app->blog ) {
            $terms->{ blog_id } = $blog->id;
        }
    }
    if ( MT->model( $model )->has_column( 'class' ) ) {
        $terms->{ class } = '*';
    }
    my $filter_cols = MT->model( $model )->column_names;
    for my $col ( @$filter_cols ) {
        if ( $app->param( $col ) ) {
            $terms->{ $col } = $app->param( $col );
        }
    }
    if ( my $level = $app->param( 'level' ) ) {
        if ( $level =~ /[^0-9]/ ) {
            $level = uc( $level );
            $terms->{ level } = _str_to_level( $level );
        }
    }
    return $terms;
}

sub _data_api_setup_args {
    my ( $app, $endpoint, $model ) = @_;
    my $args;
    my $params = $endpoint->{ default_params } || {};
    my $sort_order = $params->{ sortOrder } || 'descend';
    my $sort_by = $params->{ sortBy } || 'id';
    my $sort_cols = MT->model( $model )->column_names;
    if ( my $sortBy = $app->param( 'sortBy' ) ) {
        if ( defined $sort_cols ) {
            if ( grep( /^$sortBy$/, @$sort_cols ) ) {
                $sort_by = $sortBy;
            }
        }
    }
    if ( my $sortOrder = $app->param( 'sortOrder' ) ) {
        if ( $sortOrder eq 'ascend' ) {
            $sort_order = $sortOrder;
        }
    }
    $args->{ sort_by } = $sort_by;
    $args->{ direction } = $sort_order;
    my $limit = $params->{ limit } || MT->config( 'DataAPIDefaultLimit' ) || 25;
    if ( $app->param( 'limit' ) ) {
        $limit = $app->param( 'limit' ) + 0;
    }
    my $offset = $params->{ offset } || 0;
    if ( $app->param( 'offset' ) ) {
        $offset = $app->param( 'offset' ) + 0;
    }
    $args->{ limit } = $limit;
    $args->{ offset } = $offset;
    return $args;
}

sub _str_to_level {
    my $level = shift;
    if ( $level eq 'INFO' ) {
        return 1;
    } elsif ( $level eq 'WARNING' ) {
        return 2;
    } elsif ( $level eq 'ERROR' ) {
        return 4;
    } elsif ( $level eq 'SECURITY' ) {
        return 8;
    } elsif ( $level eq 'DEBUG' ) {
        return 16;
    }
    return 1; # INFO
}

1;