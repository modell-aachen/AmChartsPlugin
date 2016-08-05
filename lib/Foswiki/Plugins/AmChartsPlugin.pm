package Foswiki::Plugins::AmChartsPlugin;

use strict;
use warnings;

use Foswiki::Func    ();
use Foswiki::Plugins ();
use Foswiki::Plugins::TasksAPIPlugin;

use JSON;

use version; our $VERSION = version->declare("v1.1.7");
#
our $RELEASE = "1.1";

our $SHORTDESCRIPTION = '';

our $NO_PREFS_IN_TOPIC = 1;

our %CATEGORY_MAP;


sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'AMCHART', \&_AMCHART );
    Foswiki::Func::registerRESTHandler( 'gantt', \&_gantt,
      http_allow => 'GET'
      );

    return 1;
}

sub _AMCHART {
  my($session, $params, $topic, $web, $topicObject) = @_;

  my $pluginURL = '%PUBURL%/%SYSTEMWEB%/AmChartsPlugin';
  my $scripts = <<SCRIPTS;
<script type='text/javascript' src='$pluginURL/amcharts/amcharts.js'></script>
<script type='text/javascript' src='$pluginURL/amcharts/serial.js'></script>
<script type='text/javascript' src='$pluginURL/amcharts/gantt.js'></script>
<script type='text/javascript' src='$pluginURL/amcharts/plugins/export/export.js'></script>
<script type='text/javascript' src='$pluginURL/amchartsplugin.js'></script>
<link rel='stylesheet' type='text/css' href='$pluginURL/amcharts/plugins/export/export.css' />
SCRIPTS

  Foswiki::Func::addToZone( 'script', 'AMCHARTSPLUGIN', $scripts);
  return "";
}

sub _gantt {
  my $session = shift;

   %CATEGORY_MAP = (
      0 => $session->i18n->maketext("Pre-Project phase"),
      1 => $session->i18n->maketext("Feasibility and planning"),
      2 => $session->i18n->maketext("Realisation product design"),
      3 => $session->i18n->maketext("Planning process design"),
      4 => $session->i18n->maketext("Realisation process design")
      );

  my $requestObject = Foswiki::Func::getRequestObject();
  my $projectId = $requestObject->param('projectId');
  my $ganttType = $requestObject->param('type');

  my ($web, $topic) = ($projectId =~ /^(.*)\.(.*)$/);
  my ($meta, undef) = Foswiki::Func::readTopic($web, $topic);


  my $dataProvider = [];

  #Iterate over phases
  for(my $i=0; $i < 5; $i++){
    my $category = {
      category => "$i $CATEGORY_MAP{$i}"
    };

    my $segments = [];
    push(@$segments, _phaseToSegment($meta, $i));

    #Special case for coarse: Milestones are shown as segments of phases
    if($ganttType eq 'coarse'){
      my $milestones = Foswiki::Plugins::TasksAPIPlugin::query( (query => {Context => "$projectId" . "M$i", Type => "Milestone"}) );
      foreach my $milestone (@{$milestones->{tasks}}){
        push(@$segments, _taskToSegment($milestone));
      }
    }

    $category->{segments} = $segments;
    push(@$dataProvider, $category);

    next unless $ganttType eq 'detailed' or $ganttType eq 'full';
    #Iterate over work packages (including milestones)
    my $workPackages = Foswiki::Plugins::TasksAPIPlugin::query( (query => {Context => "$projectId" . "M$i", Parent => ""}, order => "TaskNumber") );
    foreach my $package (@{$workPackages->{tasks}}){
      my $packageNumber = $package->{meta}->get('FIELD', "TaskNumber")->{value};
      my $packageTitle = $package->{meta}->get('FIELD', "Title")->{value};
      my $packageSegments = [];
      unless ($packageNumber){
        $packageNumber = 0;
      }
      my $packageCategory = {
        category => "$i.$packageNumber $packageTitle"
      };
      push(@$packageSegments, _taskToSegment($package));
      $packageCategory->{segments} = $packageSegments;
      push(@$dataProvider, $packageCategory);

      next unless $ganttType eq "full";

      #Iterate over tasks ()
      my $tasks = Foswiki::Plugins::TasksAPIPlugin::query( (query => {Context => "$projectId" . "M$i", Parent => $package->{id}}, order => "TaskNumber") );
      foreach my $task (@{$tasks->{tasks}}){
        my $taskTitle = $task->{meta}->get('FIELD', "Title")->{value};
        my $taskSegments = [];
        my $taskCategory = {
          category => $taskTitle
        };
        push(@$taskSegments, _taskToSegment($task));
        $taskCategory->{segments} = $taskSegments;
        push(@$dataProvider, $taskCategory);
      }
    }
  }

  my $result = to_json($dataProvider);
  return $result;
}

sub _phaseToSegment {
  my ($meta, $phase) = @_;

  my $result = {
    color => '#3288bd',
    type => 'Phase'
  };

  my $start = $meta->get('FIELD', 'M' . $phase . 'StartDate')->{value};
  my $end = $meta->get('FIELD', 'M' . $phase . 'DueDate')->{value};

  $result->{start} = Foswiki::Time::formatTime(Foswiki::Time::parseTime($start), "\$year-\$mo-\$day");
  $result->{end} = Foswiki::Time::formatTime(Foswiki::Time::parseTime($end), "\$year-\$mo-\$day");
  $result->{text} = "von - bis:<br></br>$start - $end";

  return $result;
}

sub _taskToSegment {
  my $task = shift;
  my $taskMeta = $task->{meta};
  my $type;
  if($taskMeta->get('FIELD', 'Parent')->{value} ne ''){
    $type = "task";
  }
  elsif($taskMeta->get('FIELD', 'Type')->{value} eq 'Milestone'){
    $type = 'milestone';
  }
  else {
    $type = 'workPackage';
  }

  my $result = {};

  my $start = $taskMeta->get('FIELD', 'StartDate')->{value};
  my $end = $taskMeta->get('FIELD', 'DueDate')->{value};

  $start = Foswiki::Time::formatTime($start, "\$year-\$mo-\$day");
  $end = Foswiki::Time::formatTime($end, "\$year-\$mo-\$day");

  if($type eq 'milestone'){
    $result->{bullet} = 'diamond';
    $result->{color}  = '#f46d43';
    $result->{type} = 'Meilenstein';
    $result->{start} = $end;
    my $title = $taskMeta->get('FIELD', 'Title')->{value};
    $result->{text} = "$title<br></br>Bis: $end";
  }
  elsif($type eq 'workPackage'){
    $result->{color}  = '#abdda4';
    $result->{type} = 'Aufgabenpaket';
    $result->{start} = $start;
    $result->{text} = "von - bis:<br></br>$start - $end";
  }
  elsif($type eq 'task'){
    $result->{color} = '#1a9850';
    $result->{bullet} = 'circle';
    $result->{type} = 'Aufgabe';
    $result->{start} = $end;
    $result->{text} = "Bis: $end";
  }

  $result->{end} = $end;

  return $result;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: %$AUTHOR%

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.