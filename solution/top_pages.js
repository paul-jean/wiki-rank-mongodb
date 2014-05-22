var conn = new Mongo();
var db = conn.getDB("wiki");

var map = function() {
  // remove the project identifier after the dot from the language
  // e.g. en.q -> en
  var lang = this.lang.split(".")[0];
  var page = this.page.toString();
  var key = {lang: lang, page: page};
  var val = this.views;
  if (!page.match(/:/)) {
    emit(key, val);
  }
};

var reduce = function(lang_page, views) {
  var totalViews = 0;
  views.forEach(function(v) { totalViews += v; });
  return totalViews;
};

if (db.lang_page_views) {
  db.lang_page_views.remove({});
  db.lang_page_views.drop();
}
db.pageviews.mapReduce(map, reduce, {out: 'lang_page_views'});

var map2 = function() {
  var lang = this._id.lang;
  var page = this._id.page;
  var totalViews = this.value;
  var key = {lang: lang, totalViews: -1*totalViews};
  var val = page;
  emit(key, val);
};

var reduce2 = function(lang_views, pages) {
  return pages[0];
};

if (db.lang_views_page) {
  db.lang_views_page.remove({});
  db.lang_views_page.drop();
}
db.lang_page_views.mapReduce(map2, reduce2, {out: "lang_views_page"});
