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

    // TODO: confirm colors with product.  The mockups only show 3 max.
    colors: ['fda328', '1ebd21', 'b526fb', '3366cc', 'dc3912'],
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
  var data = google.visualization.arrayToDataTable(getArticleLocationData());

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
    legend: 'none'
  };

  var chart = new google.visualization.GeoChart(document.getElementById('article_location_div'));
  chart.draw(data, options);
}

function drawArticleUsageAge() {
  var data = google.visualization.arrayToDataTable(getArticleUsageData());

  var options = {
    backgroundColor: '#efefef',
    vAxis: {
      title: 'Total Views'
    },
    hAxis: {
      title: 'Months'
    }

  };

  var chart = new google.visualization.LineChart(document.getElementById('article_usage_div'));
  chart.draw(data, options);
}

function drawArticleCitationAge() {
  var data = google.visualization.arrayToDataTable(getArticleCitationData());

  var options = {
    backgroundColor: '#efefef',
    vAxis: {
      title: 'Citations'
    },
    hAxis: {
      title: 'Months'
    }

  };

  var chart = new google.visualization.LineChart(document.getElementById('article_citation_div'));
  chart.draw(data, options);
}

function drawArticleSocialHeatMap() {
        var data = google.visualization.arrayToDataTable(getSocialHeatMapData());


        var options = {
          title: 'Social Activity vs. Publication Months',
          hAxis: {title: 'Months'},
          vAxis: {title: 'Activity'},
          legend: ''
        };

        var chart = new google.visualization.ScatterChart(document.getElementById('social_heatmap_div'));
        chart.draw(data, options);
}

// Renders all charts on the page.
function drawReportGraphs() {
  if (haveDataToDrawViz()) {
    if (drawVizForOne()) {
      drawArticleUsageAge();
      drawArticleCitationAge();
      drawArticleSocialHeatMap();

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
