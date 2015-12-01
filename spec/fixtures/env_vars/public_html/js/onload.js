$(document).ready(function() {
  $("#foo").text(window.__env.FOO);
  $("#bar").text(window.__env.BAR);
  $("#secret").text(window.__env.SECRET);
});
