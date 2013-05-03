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
  var data = getArticleUsageCitationsAgeData();
  if (data.length > 1) {
    var chart = new google.visualization.BubbleChart(document.getElementById('article_usage_and_citations_age_div'));
    data = google.visualization.arrayToDataTable(data);
    chart.draw(data, getBubbleChartOptions());
  } else {
    $("#article_usage_and_citations_age_div")
      .append("<div class=\"metrics-no-data-para\">The data for the graph isn't available.  Please check back later.</div>");
  }
}

function drawArticleUsageMendeleyAge() {
  var data = getArticleUsageMendeleyAgeData();
  if (data.length > 1) {
    var chart = new google.visualization.BubbleChart(document.getElementById('article_usage_and_mendeley_age_div'));
    data = google.visualization.arrayToDataTable(data);
    chart.draw(data, getBubbleChartOptions());
  } else {
    $("#article_usage_and_mendeley_age_div")
      .append("<div class=\"metrics-no-data-para\">The data for the graph isn't available.  Please check back later.</div>");
  }
}

function drawArticleUsageCitationSubjectArea() {
  var options = {
    minColor: '#000000',
    midColor: '#088A08',
    maxColor: '#00FF40',
    fontColor: '#FFFFFF',
    headerHeight: 0,
    showScale: true
  };

  var chart = new google.visualization.TreeMap(document.getElementById('article_subject_div'));

  google.visualization.events.addListener(chart, 'onmouseover', function(e) {
    $(event.target).parent().children("text").attr("fill", "#FFFFFF");
  });

  var data = getArticleUsageCitationSubjectAreaData();
  if (data.length > 2) {
    data = google.visualization.arrayToDataTable(data);
    chart.draw(data, options);
  } else {
    $("#article_subject_div")
      .append("<div class=\"metrics-no-data-para\">The data for the graph isn't available.  Please check back later.</div>");
  }
}

function drawArticleLocation() {

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

  var data = getArticleLocationData();

  if (data.length > 1) {
    var chart = new google.visualization.GeoChart(document.getElementById('article_location_div'));
    data = google.visualization.arrayToDataTable(data);
    chart.draw(data, options);
  } else {
    $("#article_location_div")
      .append("<div class=\"metrics-no-data-para\">The data for the graph isn't available.  Please check back later.</div>");
  }
}


// Renders all charts on the page.
function drawReportGraphs() {
  drawArticleUsageCitationsAge();
  drawArticleUsageMendeleyAge();
  drawArticleUsageCitationSubjectArea();
  drawArticleLocation();
}

google.setOnLoadCallback(drawReportGraphs);
