// Javascript used to generate the charts on the report visualizations page.

google.load('visualization', '1', {packages: ['corechart', 'geochart', 'treemap']});

// Returns the options for the first two bubble charts.
function getBubbleChartOptions() {
  return {
    hAxis: {
      title: 'Months',
      baselineColor: 'b4b4b4',
      gridlines: {
        color: '#efefef'
      },
      titleTextStyle: {color: '838383'}
    },
    vAxis: {
      title: 'Total Views',
      maxValue: 12000,
      baselineColor: 'b4b4b4',
      gridlines: {
        color: '#efefef'
      },
      titleTextStyle: {color: '838383'}
    },
    bubble: {textStyle: {color: 'none'}},
    backgroundColor: '#efefef',
    chartArea: {left: 75, top: 20, width: "80%", height: "80%"},
    series: {
      'PLOS ONE': {color: 'fda328'},                    // Orange
      'PLOS Biology': {color: '1ebd21'},                // Green
      'PLOS Computational Biology': {color: '1ebd21'},  // Green
      'PLOS Genetics': {color: '1ebd21'}                // Green
      
      // All other journals get the default color specified below.
    },
    colors: ['b526fb'],  // Purple
    legend: {position: 'none'},
    titlePosition: 'none'
  };
}

function drawArticleUsageCitationsAge() {
  var chart = new google.visualization.BubbleChart(document.getElementById('article_usage_and_citations_age_div'));
  var data = google.visualization.arrayToDataTable(getArticleUsageCitationsAgeData());
  chart.draw(data, getBubbleChartOptions());
}

function drawArticleUsageMendeleyAge() {
  var chart = new google.visualization.BubbleChart(document.getElementById('article_usage_and_mendeley_age_div'));
  var data = google.visualization.arrayToDataTable(getArticleUsageMendeleyAgeData());
  chart.draw(data, getBubbleChartOptions());
}

function drawArticleUsageCitationSubjectArea() {
  var chart = new google.visualization.TreeMap(document.getElementById('article_subject_div'));
  var data = google.visualization.arrayToDataTable(getArticleUsageCitationSubjectAreaData());

  var options = {
    minColor: '#000000',
    midColor: '#088A08',
    maxColor: '#00FF40',
    fontColor: '#FFFFFF',
    headerHeight: 0,
    showScale: true
  };

  google.visualization.events.addListener(chart, 'onmouseover', function(e) {
    $(event.target).parent().children("text").attr("fill", "#FFFFFF");
  });

  chart.draw(data, options);
}

function drawArticleLocation() {
  var raw_data = getArticleLocationData();
  var data = new google.visualization.DataTable();
  
  // Determine if we're in lat/lng mode, or just getting addresses passed to us.
  if (raw_data[0].length == 6) {
    data.addColumn('number', 'latitude', 'latitude');
    data.addColumn('number', 'longitude', 'longitude');
    data.addColumn('string', 'description', 'description');
  } else {
    data.addColumn('string', 'location', 'location');
  }
  data.addColumn('number', 'color', 'color');
  data.addColumn('number', 'size', 'size');
  data.addColumn({type:'string', role:'tooltip'});
  data.addRows(raw_data);

  // sizeAxis is a hack to make the marker smaller
  var options = {
    displayMode: 'markers',
    sizeAxis: {
      minSize: 3,
      maxValue: 2
    },
    tooltip: {
      trigger: 'none'
    },
    legend: 'none',
    colorAxis: {colors: ['#033703', '#00ff40']},
    magnifyingGlass: {
      enable: true,
      zoomFactor: 2.5
    },
    tooltip: {
      trigger: 'focus'
    },
    enableRegionInteractivity: true
  };

  var chart = new google.visualization.GeoChart(document.getElementById('article_location_div'));
  chart.draw(data, options);
}

function drawArticleUsageAge() {

  var data = new google.visualization.DataTable();
  data.addColumn('number', 'Months');
  data.addColumn('number', 'Html Views');
  data.addColumn({type: 'string', role: 'tooltip'});
  data.addColumn('number', 'PDF Views');
  data.addColumn({type: 'string', role: 'tooltip'});
  data.addColumn('number', 'XML Views');
  data.addColumn({type: 'string', role: 'tooltip'});
  data.addRows(getArticleUsageData());

  var options = {
    backgroundColor: '#efefef',
    vAxis: {
      title: 'Total Views'
    },
    hAxis: {
      title: 'Months'
    },
    chartArea: {
      top: 40,
      height: "70%"
    }
  };

  var chart = new google.visualization.LineChart(document.getElementById('article_usage_div'));
  chart.draw(data, options);
}

function drawArticleCitationAge() {
  var data = new google.visualization.DataTable();
  data.addColumn('number', 'Months');
  data.addColumn('number', 'CrossRef');
  data.addColumn({type: 'string', role: 'tooltip'});
  data.addColumn('number', 'PubMed');
  data.addColumn({type: 'string', role: 'tooltip'});
  data.addColumn('number', 'Scopus');
  data.addColumn({type: 'string', role: 'tooltip'});
  data.addRows(getArticleCitationData());

  var options = {
    backgroundColor: '#efefef',
    vAxis: {
      title: 'Citations'
    },
    hAxis: {
      title: 'Months'
    },
    chartArea: {
      top: 40,
      height: "70%"
    }
  };

  var chart = new google.visualization.LineChart(document.getElementById('article_citation_div'));
  chart.draw(data, options);
}

function drawArticleSocialScatter() {

  var header = getSocialScatterHeader();
  var data = new google.visualization.DataTable();

  data.addColumn('number', 'Months');

  for (var i = 0; i < header.length; i++) {
    data.addColumn('number', header[i]);
    data.addColumn({type: 'string', role: 'tooltip'});
  }

  data.addRows(getSocialScatterData());

  var options = {
    backgroundColor: '#efefef',
    hAxis: {
      title: 'Months'
    },
    vAxis: {title: 'Activity'},
    legend: '',
    pointSize: 15,
    chartArea: {
      top: 40,
      height: "70%"
    }    
  };

  var chart = new google.visualization.ScatterChart(document.getElementById('social_scatter_div'));
  chart.draw(data, options);
}


function drawArticleMendeleyData() {
  var data = google.visualization.arrayToDataTable(getMendeleyReaderData());
  var options = {};
  var chart = new google.visualization.GeoChart(document.getElementById('article_mendeley_readers_div'));
  chart.draw(data, options);
}


// Renders all charts on the page.
function drawReportGraphs() {
  if (haveDataToDrawViz()) {
    if (drawVizForOne()) {
      drawArticleUsageAge();
      drawArticleCitationAge();
      drawArticleSocialScatter();
      drawArticleMendeleyData();

    } else {
      drawArticleUsageCitationsAge();
      drawArticleUsageMendeleyAge();
      drawArticleUsageCitationSubjectArea();
      drawArticleLocation();      
    }

  } else {
    $("#error-message-div").append("<div>The metrics for one or more of the articles requested are not available at this time. Please check back later.</div>")
      .show();
  }
}

google.setOnLoadCallback(drawReportGraphs);
