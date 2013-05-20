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

function drawArticleSocialScatter() {
  var data = google.visualization.arrayToDataTable(getSocialScatterData());

  var options = {
    backgroundColor: '#efefef',
    hAxis: {
      title: 'Months'
    },
    vAxis: {title: 'Activity'},
    legend: '',
    pointSize: 15
  };

// var options = {
//   chartArea: {height: '85%'},
// backgroundColor: '#efefef',
// hAxis: {title: 'Months', minValue: 0},
// vAxis: {title: 'Activity', minValue: 0},
// };
  var chart = new google.visualization.ScatterChart(document.getElementById('social_scatter_div'));
  chart.draw(data, options);
}

function drawArticleSocialScatterD3() {
var data = getSocialScatterDataD3();

  // var margin = {top: 20, right: 20, bottom: 50, left: 60},
  //   width = 510 - margin.left - margin.right,
  //   height = 300 - margin.top - margin.bottom;

  var margin = {top: 20, right: 150, bottom: 50, left: 60},
    width = 670 - margin.left - margin.right,
    height = 300 - margin.top - margin.bottom;


var x = d3.scale.linear().range([0, width]).domain([0, 100]);
var y = d3.scale.linear().range([height, 0]).domain([0, 800]);

var color = d3.scale.category10();

var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")
    .ticks(5)
    .tickSize(-height, 0, 0);

var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left")
    .ticks(5)
    .tickSize(-width, 0, 0);

var svg = d3.select("#social_scatter_d3_div").append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
  .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + height + ")")
      .call(xAxis)
    .append("text")
      .attr("class", "label")
      .attr("x", ((width / 2)+ 40))
      .attr("y", 45)
      .style("text-anchor", "end")
      .text("Months");

  svg.append("g")
      .attr("class", "y axis")
      .call(yAxis)
    .append("text")
      .attr("class", "label")
      .attr("transform", "rotate(-90)")
      .attr("y", -60)
      .attr("x", ((height / 2 * -1) + 40))
      .attr("dy", ".71em")
      .style("text-anchor", "end")
      .text("Activity")

  svg.selectAll(".dot")
      .data(data)
    .enter().append("circle")
      .attr("class", "dot")
      .attr("r", function(d) { 
        if (d[1] > 0) {
          return 9;
        } else {
          return 0;
        }
      })
      .attr("cx", function(d, i) { return x(d[0]); })
      .attr("cy", function(d, i) { return y(d[1]); })
      .style("fill", function(d) { return color(d[2]); });      

  var legend = svg.selectAll(".legend")
      .data(color.domain())
    .enter().append("g")
      .attr("class", "legend")
      .attr("transform", function(d, i) { return "translate(0," + i * 20 + ")"; });
  legend.append("rect")
      .attr("x", width + 15)
      .attr("width", 18)
      .attr("height", 18)
      .style("fill", color);

  legend.append("text")
      .attr("x", width + 40)
      .attr("y", 9)
      .attr("dy", ".35em")
      .style("text-anchor", "start")
      .text(function(d) { return d; });


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
      drawArticleMendeleyData();

      drawArticleSocialScatter();
      drawArticleSocialScatterD3();

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
