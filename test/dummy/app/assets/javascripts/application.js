// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//
// es5-shim is necessary for PhantomJS to pass tests. See https://github.com/facebook/react/issues/303
//
//= require turbolinks
//= require es5-shim/es5-shim
//= require react
//= require react_ujs
//= require_tree ./components
//= require ./store_initializers
//= require ./pages

// Stub a store in a way that we can test if it was called

window.onload = function() {
  urlDiv = document.getElementById('theUrlDiv');
  if (urlDiv) {
    (function callAjax(url) {
      var fixedUrl = url;
      var xmlhttp = new XMLHttpRequest();
      xmlhttp.onreadystatechange = function() {
        if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
          var scriptTag = document.createElement("script");
          scriptTag.text = xmlhttp.responseText.split(/<script.*>/)[2].split(/<\/script>/)[0];
          document.body.appendChild(scriptTag);
        }
      }
      xmlhttp.open("GET", fixedUrl, true);
      xmlhttp.send();
    }(urlDiv.innerText));
  }
};
