//
// Sidebar
//

var Sidebar = function() {
};

Sidebar.prototype.refresh = function(context, revision) {
  var self = this;
  context.load('revs.json', {cache: false}).
          render('revision_sidebar.mustache').
          replace('#sidebar').then(function() {
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
  return $("#sidebar tr[data-revision=" + revision + "]");
};

//
// Builds
//

var Builds = function() {};
Builds.currentView = 'list';

Builds.prototype.load = function(context, params) {
  $("#content").html('');

  context.load("/builds/" + params.revision + ".json")
      .render("builds.mustache")
      .replace('#content')
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

var app = Sammy('#main', function() {
  this.use('Mustache');

  this.pages = {};
  this.pages.sidebar = new Sidebar();
  this.pages.builds = new Builds();

  $(document).ajaxStart(function() {
  });

  $(document).ajaxStop(function() {
  });

  this.get('#/', function(context) {
    app.pages.sidebar.refresh(this);
  });

  this.get('#/revision/:revision/:view', function(context) {
    app.pages.sidebar.refresh(this, this.params.revision);
    app.pages.builds.load(this, this.params)
  });

  this.get('#/revision/:revision', function(context) {
    this.redirect("#/revision/" + this.params.revision + "/" + Builds.currentView)
  });
});

$(document).ready(function() {
  app.run('#/');
});
