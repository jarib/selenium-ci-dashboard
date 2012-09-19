//
// Sidebar
//

var Sidebar = function() {
  this.selector = '#sidebar';
};

Sidebar.prototype.refresh = function(context, revision) {
  this.show();
  var self = this;
  context.load('revs.json', {cache: false}).
          render('revision_sidebar.mustache').
          replace(this.selector).then(function() {
            var rows = $("#sidebar tr");
            rows.click(function() {
              context.redirect($(this).find("a").attr("href"));
            })

            if(revision) {
              Sammy.log("selected revision:" + revision);
              self.rowForRevision(revision).addClass("active");
            }
          });
};

Sidebar.prototype.rowForRevision = function(revision) {
  return $(this.selector + " tr[data-revision=" + revision + "]");
};

Sidebar.prototype.hide = function() {
  $("#menu-item-builds").removeClass('active');
  $(this.selector).hide();
};

Sidebar.prototype.show = function() {
  $("#menu-item-builds").addClass('active');

  var e = $(this.selector);
  if (!e.is(":visible"))
    e.show();
};

//
// Builds
//

var Builds = function() {
  this.selector = '#content';

};
Builds.currentView = 'list';

Builds.prototype.load = function(context, params) {
  this.show();

  context.load("/builds/" + params.revision + ".json")
      .render("builds.mustache")
      .replace(this.selector)
      .then(function() {
        $("#list").tablesorter();

        if(params.view == "list") {
          Builds.currentView = "list";

          $("#matrix-tab").removeClass("active")
          $("#list-tab").addClass("active")

          $("#matrix").hide();
          $("#list").show();
        } else {
          Builds.currentView = "matrix";

          $("#list-tab").removeClass("active")
          $("#matrix-tab").addClass("active")

          $("#list").hide();
          $("#matrix").show();
        }

      });
};

Builds.prototype.hide = function() {
  $(this.selector).hide();
  $("#menu-item-builds").removeClass('active');
};

Builds.prototype.show = function() {
  $(this.selector).show();
};

var Graphs = function() {
  this.selector = '#graphs';
};

Graphs.prototype.load = function(context) {
  this.show();

  var self = this;
  context.load('/graphs.json').then(function(data) {
    self.renderGraph("#area-graph",data);
  });
};

Graphs.prototype.hide = function() {
  $("#menu-item-graphs").removeClass('active');
  $(this.selector).hide();
};

Graphs.prototype.show = function() {
  $("#menu-item-graphs").addClass('active');
  $(this.selector).show();
};

Graphs.prototype.renderGraph = function(selector, data) {
  this.chart = new Highcharts.Chart({
    chart: {
        renderTo: document.querySelector(selector),
        type: 'area'
    },
    title: {
        text: 'Builds'
    },
    credits: { enabled: false },
    subtitle: {
        text: ''
    },
    xAxis: {
        categories: data.categories,
        tickmarkPlacement: 'off',
        title: {
            enabled: false
        },
        labels: {
          formatter: function() { return '<a href="#/revision/' + this.value + '">r' + this.value + '</a>'; }
        }

    },
    yAxis: {
        title: {
            text: 'Count'
        }
    },
    tooltip: {
        formatter: function() {
          // console.log(this);
            return 'r'+
                this.x +': '+ Highcharts.numberFormat(this.y, 0, ',') + ' build' + (this.y != 1 ? 's' : '');
        }
    },
    plotOptions: {
        area: {
            stacking: 'normal',
            lineColor: '#666666',
            lineWidth: 1,
            marker: {
                lineWidth: 1,
                lineColor: '#666666'
            }
        }
    },
    series: data.series
  });
};

var app = Sammy('#main', function() {
  this.use('Mustache');

  this.pages = {};
  this.pages.sidebar = new Sidebar();
  this.pages.builds = new Builds();
  this.pages.graphs = new Graphs();

  $(document).ajaxStart(function() {
    $("#loading").show();
  });

  $(document).ajaxStop(function() {
    $("#loading").hide();
  });

  this.get('#/', function(context) {
    app.pages.graphs.hide();
    app.pages.builds.show();
    app.pages.sidebar.refresh(this);
  });

  this.get('#/revision/:revision/:view', function(context) {
    app.pages.sidebar.refresh(this, this.params.revision);
    app.pages.builds.load(this, this.params)
  });

  this.get('#/revision/:revision', function(context) {
    this.redirect("#/revision/" + this.params.revision + "/" + Builds.currentView)
  });

  this.get('#/graphs', function(context) {
    app.pages.sidebar.hide();
    app.pages.builds.hide();
    app.pages.graphs.load(this);
  })
});

$(document).ready(function() {
  app.run('#/');
});
