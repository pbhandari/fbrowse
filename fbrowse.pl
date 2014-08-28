#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;       # For Debugging purposes

use Curses::UI;
use Curses::UI::Common;
use Cwd qw/getcwd abs_path/;

my $cwd = abs_path($ARGV[0] || getcwd());
my $show_hidden = $ARGV[1] || 0;
my @files = &list_files($cwd);
my $cui = new Curses::UI( -color_support => 1 );

# Pane 1
my $pane1 = $cui->add(
    'pane1', 'Window',
    -y      => 1,
    -width  => $ENV{COLS} / 2,
);

# Pane 2
my $pane2 = $cui->add(
    'pane2', 'Window',
    -y      => 1,
    -x      => $ENV{COLS} / 2,
    -width  => $ENV{COLS} / 2,
);

my $files1 = $pane1->add("filelist", "Listbox",
    -values   => \@files,
    -onchange => sub {
        change_dir("$cwd/" . substr($_[0]->get(), 0, -1));
    },
);

# Show the files in the given directory, it automatically post-fixes a '/'
# next to a directory entry and a '@' next to a link entry.
#
# TODO: use colours
sub list_files($) {
    my $dir = abs_path($_[0]);

    opendir(DIR, $dir) or return ();

    my @file_list = ();
    while (my $file = readdir(DIR)) {
        # Don't add ./ and ../
        next if ($file =~ m/^\.(\.)?$/);

        # Don't add hidden files unless we want to
        # XXX: yeah, the !show_hidden is ugly.
        next if ($file =~ m/^\./ and !$show_hidden);

        # Postpend markers denoting the file type
        if    (-l "$dir/$file") { $file = "$file@"; }
        elsif (-d "$dir/$file") { $file = "$file/"; }
        elsif (-x "$dir/$file") { $file = "$file*"; }
        else                    { $file = "$file "; }

        push(@file_list, $file);
    }

    # XXX: There has to be a way to force Perl to loop in order
    @file_list = sort @file_list;

    unshift @file_list, "../"  unless $dir =~ m/^\/$/;

    return @file_list;
}

# Move back in the directory tree
# TODO:
# Currently, if you follow a link into a directory, and then move back, you
# are in a different directory then when you started, the intention behind this
# function is to mitigate that and fix the behaviour such that going back from
# a link takes you back to the directory that you followed the link from, and
# not the parent directory of the link's target.
sub go_back() {
    return if $cwd =~ m/^\/$/; # no-op if at root

    # Most-likely fix is instead of a $cwd/.. , I remove the last /*
    # from $cwd.
    change_dir("$cwd/..")
}

# Redraw the window with the contents of the new directory.
sub change_dir($) {

    # TODO: Don't do abs_path here.
    my $dir       = abs_path("$_[0]");
    my @file_list = list_files("$dir");
    return unless @file_list; # will only be empty if I can't cd there.

    $cwd   = $dir;
    @files = @file_list;

    $files1->{-ypos} = 0;
    redraw();
}

# Show hidden files in the directory
sub toggle_hidden() {
    $show_hidden = !$show_hidden;
    @files = list_files("$cwd");

    redraw();
}

# Open up a shell at the current directory
sub open_shell() {
    $cui->leave_curses();
    system "cd $cwd && $ENV{SHELL}";
    $cui->mainloop();
}

# Redraw the window
sub redraw() {
    foreach my $win ($files1) {
        $win->clear_selection();
        $win->root->draw();
    }
}

$cui->set_binding(sub { exit(0) },          "q");
$cui->set_binding(sub { open_shell() },     "s");
$cui->set_binding(sub { go_back() },        $cui->KEY_LEFT, "h");
$cui->set_binding(sub { toggle_hidden() },  "H");

$files1->focus();
$cui->mainloop();
