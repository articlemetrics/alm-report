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
    showScale: true
  };

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


// Renders all charts on the page.
function drawReportGraphs() {
  drawArticleUsageCitationsAge();
  drawArticleUsageMendeleyAge();
  drawArticleUsageCitationSubjectArea();
  drawArticleLocation();
}

google.setOnLoadCallback(drawReportGraphs);
