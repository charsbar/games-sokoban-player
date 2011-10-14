package Games::Sokoban::Player;

use strict;
use warnings;
use Games::Sokoban::Controller;
use SDL;
use SDL::Event;
use SDL::Events;
use SDLx::App;
use SDLx::Sprite;
use SDLx::Layer;
use SDLx::LayerManager;
use SDL::GFX::Rotozoom;

our $VERSION = '0.01';

sub new {
  my ($class, %args) = @_;

  $args{map_size} = [960, 640];

  bless \%args, $class
}

sub run {
  my ($self, %opts) = @_;

  if ($opts{levels} && ref $opts{levels} eq 'ARRAY') {
    $self->{levels} = $opts{levels};
  }
  elsif ($opts{levels} && !ref $opts{levels}) {
    $opts{levels} =~ s/\r\n/\n/gs;
    $opts{levels} =~ s/^;.+$//gm;
    $opts{levels} =~ s/^\n+//gs;
    $opts{levels} =~ s/\n+$//gs;
    $self->{levels} = [split /\n\n+/s, $opts{levels}];
  }
  else {
    # just to test; this should show usage later
    my $data = <<'LEVEL';
#######
#@ .  #
#  $  #
#     #
#######
LEVEL
    $self->{levels} = [$data, $data];
  }

  my $app = $self->prepare or return;

  $app->run;
}

sub current { shift->{current} || 0 }

sub _adjust_size {
  my ($self, $w, $h) = @_;

  for my $size ([15, 10], [30, 20], [60, 40]) {
    if ($w < $size->[0] and $h < $size->[1]) {
      $self->_prepare_sprites(
        $self->{map_size}->[0] / $size->[0],
        $self->{map_size}->[1] / $size->[1],
      );
      $self->{top_margin} = int(($size->[0] - $h) / 2);
      $self->{left_margin}  = int(($size->[1] - $w) / 2);
      return;
    }
  }
  die "the puzzle is too large ($w, $h)\n";
}

sub _prepare {
  my $self = shift;
  my $c = $self->{c};
  $c->set_data($self->{levels}[$self->current]);
  $self->{size} = [$c->size];
  $self->_adjust_size($c->size);
}

sub prepare {
  my $self = shift;

  $self->{c} = my $c = Games::Sokoban::Controller->new;

  $self->{app} = my $app = SDLx::App->new(
    width =>  $self->{map_size}->[0],
    height => $self->{map_size}->[1],
    title => 'Sokoban',
    exit_on_quit => 1,
  );

  $self->_prepare;
  $app->update;

  my %methods = map {$_ => "go_$_"} qw/left right up down/;
  $app->add_event_handler(sub {
    my ($ev, $ctrl) = @_;
    if ($ev->type == SDL_QUIT) { $app->stop; return }
    if ($ev->type == SDL_KEYDOWN) {
      my $key = SDL::Events::get_key_name($ev->key_sym);
      if ($key eq 'q' or $key eq 'escape') { $app->stop; return }

      my @replaced;
      if ($key eq 'left')  { @replaced = $c->go_left(@_) }
      if ($key eq 'right') { @replaced = $c->go_right(@_) }
      if ($key eq 'up')    { @replaced = $c->go_up(@_) }
      if ($key eq 'down')  { @replaced = $c->go_down(@_) }
      if ($key eq 'r') {
        $self->_prepare;
        $self->redraw;
      }

      if (@replaced) {
        for my $pos (@replaced) {
          my $char = $c->get($pos);
          $self->set($pos => $char);
        }
        $app->update;
      }
      if ($c->solved) {
        my $image = SDLx::Sprite->new(image => 'images/clear.gif');
        $image->draw_xy(
          $self->{app},
          ($self->{app}->w - $image->w) / 2,
          ($self->{app}->h - $image->h) / 2,
        );

        $app->update;
        if ($key eq 'return') {
          $self->clear;
          if ($self->{levels}[++$self->{current}]) {
            $self->_prepare;
            $self->redraw;
          } else {
            print "ALL CLEAR!";
            $app->stop;
            return;
          }
        }
      }
    }
  });

  $self->redraw;

  $app;
}

sub redraw {
  my $self = shift;
  my $c = $self->{c};
  my ($w, $h) = @{ $self->{size} };

  for my $x (0 .. $w - 1) {
    for my $y (0 .. $h - 1) {
      $self->set([$x, $y], $c->get([$x, $y]));
    }
  }
  $self->{app}->update;

}

sub clear {
  my $self = shift;
  my $s = $self->{app}->surface;
  $s->draw_rect([0,0,$s->w,$s->h], 0);
}

sub set {
  my ($self, $pos, $char) = @_;

  my $sprite = $self->{sprites}{$char};

  $sprite->draw_xy(
    $self->{app},
    ($pos->[0] + $self->{top_margin})  * $sprite->w,
    ($pos->[1] + $self->{left_margin}) * $sprite->h,
  );
}

sub _prepare_sprites {
  my ($self, $w, $h) = @_;

  my %images = (
    '@' => 'images/player.gif',
    '+' => 'images/player.gif',
    ' ' => 'images/floor.gif',
    '.' => 'images/goal.gif',
    '$' => 'images/box.gif',
    '*' => 'images/box2.gif',
    '#' => 'images/wall.gif',
  );

  for my $c (keys %images) {
    my $s = $self->{sprites}{$c} = SDLx::Sprite->new(
      width => $w,
      height => $h,
      image => $images{$c},
    );
    $s->surface(
      SDL::GFX::Rotozoom::zoom_surface(
        $s->surface,
        $w / $s->w,
        $h / $s->h,
        SMOOTHING_ON,
      ),
    );
  }
}

1;

__END__

=head1 NAME

Games::Sokoban::Player - Sokoban

=head1 SYNOPSIS

    use Games::Sokoban::Player;

    Games::Sokoban::Player->new->run;

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=head1 AUTHOR

Kenichi Ishigaki, E<lt>ishigaki@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Kenichi Ishigaki.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
